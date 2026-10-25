import os
import google.generativeai as genai

# Configure avec ta clé API stockée dans la variable d'environnement
genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))

# Initialise le modèle Gemini
model = genai.GenerativeModel("gemini-1.5-flash")

# Boucle interactive type "gemini chat"
print("=== Gemini Chat === (tape 'exit' pour quitter)")
while True:
    prompt = input("Vous: ")
    if prompt.lower() in ["exit", "quit", "q"]:
        print("Fin de la session.")
        break
    
    try:
        response = model.generate_content(prompt)
        print("Gemini:", response.text)
    except Exception as e:
        print("Erreur:", e)
