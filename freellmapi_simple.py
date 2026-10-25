from openai import OpenAI

# Configuration FreeLLMAPI
client = OpenAI(
    base_url="http://127.0.0.1:31415/v1",
    api_key="freellmapi-ee2177cc1f92c31997c828332be96478db4bb74d12646b4f",
)

# Exemple simple
response = client.chat.completions.create(
    model="auto",  # laisse FreeLLMAPI choisir le meilleur modèle free
    messages=[
        {"role": "system", "content": "Tu es un assistant utile."},
        {"role": "user", "content": "Bonjour, présente-toi brièvement."}
    ],
    temperature=0.7,
)

print(response.choices[0].message.content)
print("\nModèle utilisé :", response.model)
