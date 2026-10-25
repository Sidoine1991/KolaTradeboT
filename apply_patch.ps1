param(
    [string]$filePath
)

$fileContent = Get-Content $filePath -Raw -Encoding UTF8

# --- Bloc 1: Canal de prédiction M5 ---
$anchor1 = "        components = []"
$code1 = @"
        # Canal de prédiction M5 (pente normalisée)
        channel_slope = 0.0
        try:
            rates_chan = mt5.copy_rates_from_pos(request.symbol, mt5.TIMEFRAME_M5, 0, 80)
            if rates_chan is not None and len(rates_chan) >= 30:
                df_chan = pd.DataFrame(rates_chan)
                closes_chan = df_chan['close'].tail(50)
                x_idx = np.arange(len(closes_chan))
                coeff = np.polyfit(x_idx, closes_chan.values, 1)
                last_price = float(closes_chan.iloc[-1]) if len(closes_chan) > 0 else 0.0
                if last_price > 0:
                    channel_slope = float(coeff[0]) / last_price
                if channel_slope > 0:
                    components.append("ChUp")
                elif channel_slope < 0:
                    components.append("ChDown")
        except Exception:
            pass
"@

# --- Bloc 2: Override Anti-HOLD ---
$anchor2 = "        elif action != \"hold\" and (m5_bearish and h1_bearish) and not (h4_bearish or d1_bearish):\n            confidence = max(confidence, 0.55)"
$code2 = @"

        # 8.b OVERRIDE EMA/CHANNEL: éviter HOLD contre une tendance claire M5/H1 avec canal aligné
        if action == "hold":
            if (m5_bullish and (h1_bullish or not h1_bearish)) and channel_slope > 0:
                action = "buy"
                confidence = max(confidence, 0.55)
                components.append("EMA+Channel↑")
            elif (m5_bearish and (h1_bearish or not h1_bearish)) and channel_slope < 0:
                action = "sell"
                confidence = max(confidence, 0.55)
                components.append("EMA+Channel↓")
"@

# Application des patchs
$newContent = $fileContent.Replace($anchor1, "$anchor1`n$code1")
$newContent = $newContent.Replace($anchor2, "$anchor2`n$code2")

# Sauvegarde du fichier modifié
Set-Content -Path $filePath -Value $newContent -Encoding UTF8 -NoNewline

Write-Host "Patch appliqué avec succès sur $filePath"
