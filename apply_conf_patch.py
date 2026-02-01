import io
import os

FILE_PATH = r'd:\Dev\TradBOT\ai_server.py'

anchor = "        # 10. S'assurer que la confiance est dans les limites raisonnables"

code = (
"\n"
"        # Harmonisation de la confiance avec l'alignement (M1/M5/H1) et la décision finale\n"
"        try:\n"
"            core_bullish_count = int(m1_bullish) + int(m5_bullish) + int(h1_bullish)\n"
"            core_bearish_count = int(m1_bearish) + int(m5_bearish) + int(h1_bearish)\n"
"            if action in (\"buy\", \"sell\"):\n"
"                core_count = core_bullish_count if action == \"buy\" else core_bearish_count\n"
"                # Carte des seuils cibles selon l'alignement coeur (3 TF)\n"
"                if core_count >= 3:\n"
"                    target_min = 0.90\n"
"                elif core_count == 2:\n"
"                    target_min = 0.75\n"
"                elif core_count == 1:\n"
"                    target_min = 0.60\n"
"                else:\n"
"                    target_min = 0.0\n"
"                # Bonus canal si aligné avec l'action\n"
"                if (action == \"buy\" and channel_slope > 0) or (action == \"sell\" and channel_slope < 0):\n"
"                    target_min = min(MAX_CONF, target_min + 0.05)\n"
"                # Bonus fort si mouvement temps réel confirme et alignement 3/3\n"
"                if core_count >= 3 and realtime_movement.get(\"trend_consistent\") and realtime_movement.get(\"strength\", 0.0) > 0.5:\n"
"                    target_min = min(MAX_CONF, max(target_min, 0.90) + 0.03)\n"
"                confidence = max(confidence, target_min)\n"
"                components.append(f\"Core{('B' if action=='buy' else 'S')}:{core_count}/3\")\n"
"        except Exception as _conf_ex:\n"
"            logger.debug(f\"Align/Conf harmonization skipped: {_conf_ex}\")\n"
)

with open(FILE_PATH, 'r', encoding='utf-8') as f:
    content = f.read()

if anchor not in content:
    raise SystemExit("Anchor not found; aborting patch.")

new_content = content.replace(anchor, code + anchor)

with open(FILE_PATH, 'w', encoding='utf-8', newline='') as f:
    f.write(new_content)

print("Confidence harmonization patch applied.")
