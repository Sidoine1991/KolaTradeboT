"""
Claude via NVIDIA NIM Client
Uses Anthropic Claude models through NVIDIA NIM API
For: Job description analysis, matching reasoning, digest enhancement
"""

import os
import json
import httpx
from pathlib import Path
from typing import Optional
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent.parent / ".env")

NVIDIA_NIM_API_KEY = os.getenv("NVIDIA_NIM_API_KEY", "REMOVED_NVIDIA_KEY_1")
NVIDIA_NIM_BASE = "https://integrate.api.nvidia.com/v1"
CLAUDE_MODEL = "claude-3-5-sonnet"  # Available via NIM

# See: https://docs.nvidia.com/nim/large-language-models/latest/getting-started.html


class ClaudeNIMClient:
    """Claude via NVIDIA NIM for intelligent job analysis"""

    def __init__(self, model: str = CLAUDE_MODEL):
        self.model = model
        self.base_url = NVIDIA_NIM_BASE
        self.api_key = NVIDIA_NIM_API_KEY
        self.timeout = 60

    async def analyze_job_description(self, job_title: str, description: str) -> dict:
        """
        Use Claude to extract key insights from job description
        Returns: skills, seniority_indicators, culture_fit, red_flags
        """

        prompt = f"""Analyze this job posting and extract key information:

Title: {job_title}
Description: {description}

Provide JSON response with:
{{
  "extracted_skills": ["skill1", "skill2"],
  "seniority_level": "junior|mid|senior",
  "remote_flexibility": "fully_remote|hybrid|onsite",
  "company_culture": "summary",
  "red_flags": ["flag1", "flag2"],
  "opportunities": ["opportunity1", "opportunity2"]
}}"""

        return await self._call_claude(prompt)

    async def score_profile_fit(self, profile_name: str, profile_skills: list, job_title: str, job_description: str) -> dict:
        """
        Use Claude to provide contextual scoring reasoning
        """

        prompt = f"""Given:
Profile: {profile_name}
Skills: {', '.join(profile_skills)}

Job: {job_title}
Description: {job_description}

Provide JSON with:
{{
  "fit_score": 0-100,
  "key_matches": ["match1", "match2"],
  "skill_gaps": ["gap1", "gap2"],
  "growth_opportunity": "assessment",
  "recommendation": "strong_match|good_match|consider|skip"
}}"""

        return await self._call_claude(prompt)

    async def generate_personalized_message(self, job_title: str, company: str, skills_match: list) -> str:
        """
        Generate personalized application message
        """

        prompt = f"""Generate a brief professional WhatsApp-friendly message about this opportunity:

Job: {job_title} at {company}
Matched Skills: {', '.join(skills_match)}

Keep it:
- Professional but friendly (50-100 words)
- Mobile-friendly (no long paragraphs)
- Action-oriented

Response format: Plain text, no JSON"""

        result = await self._call_claude(prompt, json_response=False)
        return result

    async def _call_claude(self, prompt: str, json_response: bool = True) -> dict | str:
        """
        Make API call to Claude via NVIDIA NIM
        """

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    json={
                        "model": self.model,
                        "messages": [
                            {
                                "role": "user",
                                "content": prompt,
                            }
                        ],
                        "temperature": 0.3 if json_response else 0.7,
                        "max_tokens": 1024,
                        "stream": False,
                    },
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                )

                if response.status_code == 200:
                    data = response.json()
                    content = data["choices"][0]["message"]["content"]

                    if json_response:
                        # Extract JSON from response
                        try:
                            return json.loads(content)
                        except:
                            # Try to extract JSON from markdown code blocks
                            if "```json" in content:
                                json_str = content.split("```json")[1].split("```")[0]
                                return json.loads(json_str)
                            elif "```" in content:
                                json_str = content.split("```")[1].split("```")[0]
                                return json.loads(json_str)
                            else:
                                return {"error": "Invalid JSON response", "raw": content}
                    else:
                        return content

                else:
                    print(f"[ERROR] NIM returned {response.status_code}: {response.text[:200]}")
                    return {} if json_response else ""

        except Exception as e:
            print(f"[ERROR] Claude NIM call failed: {str(e)[:100]}")
            return {} if json_response else ""


async def analyze_job_with_claude(job_title: str, description: str) -> dict:
    """Convenience function"""
    client = ClaudeNIMClient()
    return await client.analyze_job_description(job_title, description)


async def score_fit_with_claude(profile: str, skills: list, job_title: str, job_desc: str) -> dict:
    """Convenience function"""
    client = ClaudeNIMClient()
    return await client.score_profile_fit(profile, skills, job_title, job_desc)


if __name__ == "__main__":
    import asyncio

    async def test():
        client = ClaudeNIMClient()

        # Test 1: Analyze job
        print("[Test] Analyzing job description...")
        result = await client.analyze_job_description(
            "Senior Python Developer",
            """We're looking for a Senior Python Developer to join our team.
            Requirements: 5+ years Python, FastAPI, PostgreSQL, Docker, AWS.
            Nice to have: Kubernetes, ML experience.
            Fully remote, competitive salary.""",
        )
        print(f"Result: {json.dumps(result, indent=2)}")

    asyncio.run(test())
