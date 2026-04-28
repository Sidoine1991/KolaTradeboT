from pathlib import Path


def extract_function(text: str, name: str) -> str:
    sig = "void " + name + "("
    i = text.find(sig)
    if i < 0:
        raise SystemExit(f"{name} not found")
    j = text.find("{", i)
    if j < 0:
        raise SystemExit("opening brace not found")
    depth = 0
    for k in range(j, len(text)):
        ch = text[k]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[i : k + 1]
    raise SystemExit("unterminated function")


def main() -> None:
    p = Path(__file__).resolve().parent.parent / "SMC_Universal.mq5"
    text = p.read_text(encoding="utf-8")
    fn = extract_function(text, "DrawOTESetup")
    lines = fn.splitlines()
    for idx, line in enumerate(lines[-25:], start=len(lines) - 25):
        print(idx, ascii(line))


if __name__ == "__main__":
    main()
