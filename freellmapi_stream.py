from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:31415/v1",
    api_key="freellmapi-ee2177cc1f92c31997c828332be96478db4bb74d12646b4f",
)

stream = client.chat.completions.create(
    model="auto",
    messages=[
        {"role": "user", "content": "Explique-moi ce qu'est FreeLLMAPI en 3 phrases."}
    ],
    stream=True,
)

print("Réponse :\n")
for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)

print("\n")
