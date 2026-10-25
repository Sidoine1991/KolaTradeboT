import os
from dotenv import load_dotenv
load_dotenv()

try:
    from google.generativeai.client import configure
    from google.generativeai.generative_models import GenerativeModel
except ImportError:
    configure = None
    GenerativeModel = None

import importlib

def analyze_with_gemini(prompt):
    """
    Appelle l'API Google Gemini Flash 2.0 pour analyse IA.
    prompt : texte à analyser.
    """
    api_key = os.getenv('GEMINI_API_KEY')
    if not api_key:
        return "[Erreur Gemini] Clé API manquante. Ajoutez GEMINI_API_KEY dans votre .env."
    if configure is None or GenerativeModel is None:
        return "[Erreur Gemini] Le package google-generativeai n'est pas installé."
    try:
        configure(api_key=api_key)
        model = GenerativeModel('gemini-1.5-flash')
        response = model.generate_content(prompt)
        if hasattr(response, 'text'):
            return response.text
        elif hasattr(response, 'candidates') and response.candidates:
            return response.candidates[0].text
        else:
            return "[Erreur Gemini] Réponse inattendue de l'API."
    except Exception as e:
        return f"[Erreur Gemini] {e}"

def analyze_with_openai(prompt, model="gpt-3.5-turbo", temperature=0.2, max_tokens=512):
    """
    Appelle l'API OpenAI (ChatCompletion) pour analyse IA.
    Nécessite OPENAI_API_KEY dans l'env.
    """
    api_key = os.getenv('OPENAI_API_KEY')
    if not api_key:
        return "[Erreur OpenAI] Clé API manquante. Ajoutez OPENAI_API_KEY dans votre .env."
    try:
        openai = importlib.import_module("openai")
        response = openai.ChatCompletion.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            temperature=temperature,
            max_tokens=max_tokens,
            api_key=api_key
        )
        if hasattr(response, 'choices') and response.choices:
            return response.choices[0].message.content.strip()
        else:
            return "[Erreur OpenAI] Réponse inattendue de l'API."
    except Exception as e:
        return f"[Erreur OpenAI] {e}"

def analyze_with_ai_fallback(prompt, model="gpt-3.5-turbo", temperature=0.2, max_tokens=512):
    """
    Tente d'abord OpenAI, puis Gemini en cas d'échec ou de rate limit.
    """
    openai_result = analyze_with_openai(prompt, model=model, temperature=temperature, max_tokens=max_tokens)
    if openai_result and not openai_result.startswith("[Erreur OpenAI]"):
        return openai_result
    # Si OpenAI échoue, fallback Gemini
    gemini_result = analyze_with_gemini(prompt)
    return gemini_result