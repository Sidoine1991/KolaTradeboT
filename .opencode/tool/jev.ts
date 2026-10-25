import { tool } from "@opencode-ai/plugin"
import { readFileSync } from "node:fs"
import { join } from "node:path"

const DEFAULT_BASE_URL = "https://thejevai.com/v1"
const DEFAULT_MODEL = "jev-latest"
const RETRYABLE = new Set([408, 425, 429, 500, 502, 503, 504])

const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

type QuestionType = "choice" | "score" | "noul"

interface Question {
  type: QuestionType
  instructions: string | Record<string, unknown> | unknown[]
  criteria?: unknown
}

/**
 * Jev ne doit jamais recevoir une cle en dur. On lit process.env, avec un
 * repli sur le .env du projet au cas ou le runtime ne l'aurait pas charge.
 */
function apiKey(): string | undefined {
  const fromEnv = process.env.JEV_API_KEY?.trim()
  if (fromEnv) return fromEnv
  try {
    const raw = readFileSync(join(process.cwd(), ".env"), "utf8")
    const match = raw.match(/^\s*JEV_API_KEY\s*=\s*(.+?)\s*$/m)
    return match?.[1]?.trim().replace(/^["']|["']$/g, "") || undefined
  } catch {
    return undefined
  }
}

function env(name: string, fallback: string): string {
  const v = process.env[name]
  return v && v.trim() ? v.trim() : fallback
}

function numEnv(name: string, fallback: number): number {
  const raw = process.env[name]
  const parsed = raw ? Number(raw) : NaN
  return Number.isFinite(parsed) ? parsed : fallback
}

function validate(questions: Record<string, Question>): string[] {
  const errors: string[] = []
  for (const [key, q] of Object.entries(questions)) {
    if (!q || typeof q !== "object") {
      errors.push(`questions.${key}: must be an object`)
      continue
    }
    if (q.type !== "choice" && q.type !== "score" && q.type !== "noul") {
      errors.push(`questions.${key}.type: must be one of choice | score | noul`)
    }
    if (!q.instructions) {
      errors.push(`questions.${key}.instructions: required`)
    }
    if (q.type === "choice") {
      const c = q.criteria as Record<string, unknown> | undefined
      if (!c || typeof c !== "object" || Array.isArray(c) || Object.keys(c).length === 0) {
        errors.push(`questions.${key}.criteria: required map of option -> description (choice)`)
      } else if (Object.keys(c).length > 255) {
        errors.push(`questions.${key}.criteria: choice accepts at most 255 options`)
      }
    }
    if (q.type === "score") {
      if (!Array.isArray(q.criteria) || q.criteria.length === 0) {
        errors.push(`questions.${key}.criteria: required array of {score, description} (score)`)
      }
    }
  }
  return errors
}

export default tool({
  description: `Bounded decision API (Jev AI / TypeSafe). Not a chat model.

Evaluates a "state" (text, JSON object, or array) against typed questions and returns one
structured answer per question with calibrated probabilities and a confidence value.

Question types:
  - choice : criteria = map of option -> description (up to 255 options) -> returns choice, probabilities, confidence
  - score  : criteria = array of {score, description}        -> returns score, legend, probabilities, confidence
  - noul   : criteria = optional {true, false}               -> returns noul (0..1 probability of "yes")

Use this for classification, routing, rubrics and yes/no judgements. It cannot write free
text and it has no tool access — keep execution and permissions in application code.`,
  args: {
    state: tool.schema
      .string()
      .describe("Context every question reads: plain text, a JSON object, or an array of text items."),
    questions: tool.schema
      .record(tool.schema.string(), tool.schema.any())
      .describe(
        'Map of question id -> question. Each question: {"type":"choice"|"score"|"noul","instructions":"...","criteria":...}. Ids are echoed back in the response.',
      ),
    model: tool.schema
      .string()
      .optional()
      .describe(`Model alias handling the request. Default: ${DEFAULT_MODEL}.`),
  },
  async execute(args, context) {
    const key = apiKey()
    if (!key) {
      return JSON.stringify({
        ok: false,
        error: "JEV_API_KEY is not set. Add it to .env (create a key at https://thejevai.com/settings/apikeys).",
      })
    }

    const questions = (args.questions ?? {}) as Record<string, Question>
    if (Object.keys(questions).length === 0) {
      return JSON.stringify({ ok: false, error: "questions must contain at least one question" })
    }

    const errors = validate(questions)
    if (errors.length) {
      return JSON.stringify({ ok: false, error: "invalid questions", details: errors })
    }

    const baseUrl = env("JEV_BASE_URL", DEFAULT_BASE_URL).replace(/\/+$/, "")
    const model = args.model?.trim() || env("JEV_MODEL", DEFAULT_MODEL)
    const timeoutMs = numEnv("JEV_TIMEOUT", 30) * 1000
    const maxRetries = Math.max(0, Math.floor(numEnv("JEV_MAX_RETRIES", 2)))
    const endpoint = `${baseUrl}/systemone`

    context.metadata({ title: `Jev: ${Object.keys(questions).join(", ")}` })

    const payload = JSON.stringify({ model, state: args.state, questions })

    let lastError = "unknown error"
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        const backoff = Math.min(2 ** attempt * 1000, 8000)
        await new Promise((r) => setTimeout(r, backoff))
      }

      const controller = new AbortController()
      const timer = setTimeout(() => controller.abort(), timeoutMs)

      try {
        const res = await fetch(endpoint, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${key}`,
            "Content-Type": "application/json",
            Accept: "application/json",
            "User-Agent": UA,
          },
          body: payload,
          signal: controller.signal,
        })

        const text = await res.text()

        if (!res.ok) {
          lastError = `HTTP ${res.status}: ${text.slice(0, 400)}`
          if (!RETRYABLE.has(res.status)) {
            return JSON.stringify({ ok: false, status: res.status, error: lastError, endpoint })
          }
          continue
        }

        let data: any
        try {
          data = JSON.parse(text)
        } catch {
          return JSON.stringify({ ok: false, error: `non-JSON response: ${text.slice(0, 400)}` })
        }

        if (data?.code !== 0 && data?.code !== undefined && data?.code !== null) {
          return JSON.stringify({ ok: false, error: `code=${data.code} message=${data.message}` })
        }

        const result = data?.data?.result ?? {}
        return JSON.stringify(
          {
            ok: true,
            model,
            endpoint,
            answers: result.answers ?? {},
            usage: result.usage ?? null,
            elapsed_ms: result.elapsedMs ?? null,
            credits_used: data?.data?.creditsUsed ?? null,
          },
          null,
          2,
        )
      } catch (err: any) {
        lastError = err?.name === "AbortError" ? `timeout after ${timeoutMs}ms` : `${err?.message ?? err}`
      } finally {
        clearTimeout(timer)
      }
    }

    return JSON.stringify({ ok: false, endpoint, error: lastError })
  },
})
