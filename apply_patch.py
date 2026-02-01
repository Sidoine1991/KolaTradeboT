import re

def main():
    file_path = r'd:\\Dev\\TradBOT\\ai_server.py'
    
    # Lire le contenu du fichier
    with open(file_path, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # Patch 1: Ajout du calcul du canal après components = []
    patch1 = r'\n        # Canal de prédiction M5 (pente normalisée)\n        channel_slope = 0.0\n        try:\n            rates_chan = mt5.copy_rates_from_pos(request.symbol, mt5.TIMEFRAME_M5, 0, 80)\n            if rates_chan is not None and len(rates_chan) >= 30:\n                df_chan = pd.DataFrame(rates_chan)\n                closes_chan = df_chan[\'close\'].tail(50)\n                x_idx = np.arange(len(closes_chan))\n                coeff = np.polyfit(x_idx, closes_chan.values, 1)\n                last_price = float(closes_chan.iloc[-1]) if len(closes_chan) > 0 else 0.0\n                if last_price > 0:\n                    channel_slope = float(coeff[0]) / last_price\n                if channel_slope > 0:\n                    components.append(\"ChUp\")\n                elif channel_slope < 0:\n                    components.append(\"ChDown\")\n        except Exception:\n            pass\n'
    # Patch 2: Ajout de l'override EMA/Channel
    patch2 = r'\n\n        # 8.b OVERRIDE EMA/CHANNEL: éviter HOLD contre une tendance claire M5/H1 avec canal aligné\n        if action == "hold":\n            if (m5_bullish and (h1_bullish or not h1_bearish)) and channel_slope > 0:\n                action = "buy"\n                confidence = max(confidence, 0.55)\n                components.append("EMA+Channel↑")\n            elif (m5_bearish and (h1_bearish or not h1_bullish)) and channel_slope < 0:\n                action = "sell"\n                confidence = max(confidence, 0.55)\n                components.append("EMA+Channel↓")\n'
    # Appliquer le premier patch
    content = content.replace("components = []\n", "components = []" + patch1)
    
    # Appliquer le deuxième patch
    target_str = "# 8. BONUS FINAL : Si M5+H1 alignés (sans H4/D1), confiance minimale 0.55\n        if action != \"hold\" and (m5_bullish and h1_bullish) and not (h4_bullish or d1_bullish):\n            confidence = max(confidence, 0.55)\n        elif action != \"hold\" and (m5_bearish and h1_bearish) and not (h4_bearish or d1_bearish):\n            confidence = max(confidence, 0.55)"
    
    if target_str in content:
        content = content.replace(target_str, target_str + patch2)
        
        # Écrire les modifications dans le fichier
        with open(file_path, 'w', encoding='utf-8') as file:
            file.write(content)
        print("Les modifications ont été appliquées avec succès!")
    else:
        print("Impossible de trouver l'emplacement pour appliquer le patch 2.")
        print("Veuillez vérifier manuellement le fichier.")

if __name__ == "__main__":
    main()
