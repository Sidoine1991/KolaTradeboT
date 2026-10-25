import streamlit as st
import json
from pathlib import Path
import time

st.header("📲 Messagerie WhatsApp")
messages_file = Path("messages_whatsapp.json")
all_messages = []
if messages_file.exists():
    with messages_file.open("r", encoding="utf-8") as f:
        lines = f.readlines()
        for line in lines:
            all_messages.append(json.loads(line))
else:
    st.write("Aucun message reçu pour l'instant.")

# Filtres
exp_list = sorted(set(msg['from'] for msg in all_messages)) if all_messages else []
selected_exp = st.selectbox("Filtrer par expéditeur", ["Tous"] + exp_list, key="wa_exp_select")
keyword = st.text_input("Filtrer par mot-clé (contenu du message)", key="wa_keyword_input")

filtered = all_messages
if selected_exp != "Tous":
    filtered = [msg for msg in filtered if msg['from'] == selected_exp]
if keyword:
    filtered = [msg for msg in filtered if keyword.lower() in msg['body'].lower()]

# Affichage tableau
if filtered:
    st.dataframe([
        {"Expéditeur": msg['from'], "Message": msg['body'], "Date": time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(msg['timestamp']))}
        for msg in reversed(filtered[-50:])
    ], key="wa_df")
else:
    st.write("Aucun message à afficher avec ce filtre.")

# Action automatique sur 'Menu'
if filtered and filtered[-1]['body'].strip().lower() == "menu":
    st.success("Affichage du menu spécial car 'Menu' a été reçu sur WhatsApp !")
    st.markdown("""
    ### Menu spécial WhatsApp
    - Option 1 : ...
    - Option 2 : ...
    - Option 3 : ...
    """)
    if st.button("Répondre automatiquement au dernier 'Menu'", key="wa_auto_reply_btn"):
        from frontend.whatsapp_notify import send_whatsapp_message
        ok = send_whatsapp_message("Voici le menu demandé !", filtered[-1]['from'])
        if ok:
            st.success("Réponse automatique envoyée !")
        else:
            st.error("Erreur lors de l'envoi.")

st.subheader("✉️ Répondre à un message WhatsApp")
last_sender = filtered[-1]['from'] if filtered else ""
to_number = st.text_input(
    "Numéro WhatsApp du destinataire (format: whatsapp:+33XXXXXXXXX)",
    value=last_sender or "",
    key="wa_destinataire_input_whatsapp"
)
reply_text = st.text_area("Votre message à envoyer", key="wa_reply_text_whatsapp")
if st.button("Envoyer la réponse WhatsApp", key="wa_send_btn_whatsapp"):
    if to_number and reply_text:
        from frontend.whatsapp_notify import send_whatsapp_message
        ok = send_whatsapp_message(reply_text, to_number)
        if ok:
            st.success("Message WhatsApp envoyé !")
        else:
            st.error("Erreur lors de l'envoi du message WhatsApp.")
    else:
        st.warning("Veuillez remplir le numéro et le message.")

refresh = st.checkbox("🔄 Rafraîchir automatiquement toutes les 10s", value=False, key="wa_refresh_auto_whatsapp")
if refresh:
    time.sleep(10)
    st.rerun()

if st.button("🔄 Rafraîchir maintenant", key="wa_refresh_btn_whatsapp"):
    st.rerun() 