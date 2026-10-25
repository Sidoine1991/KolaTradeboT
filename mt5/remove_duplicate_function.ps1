$filePath = 'D:\Dev\TradBOT\mt5\AngelOfSpike.mq5'
$content = Get-Content -Path $filePath -Raw

# Trouver le début de la deuxième occurrence de la fonction
$functionStart = '//+------------------------------------------------------------------+
//| Analyse des indicateurs de trading modernes 2025                |
//+------------------------------------------------------------------+
void AnalyzeModernIndicators(const string symbol)
{
    if(!InpShowModernIndicators) return;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(currentPrice <= 0) return;'

$startIndex = $content.IndexOf($functionStart, [System.StringComparison]::OrdinalIgnoreCase)

if ($startIndex -ne -1) {
    # Trouver la fin de la fonction (la prochaine occurrence de '}' après le début de la fonction)
    $endIndex = $content.IndexOf('    IndicatorRelease(adxHandle);
    IndicatorRelease(obvHandle);
}', $startIndex)
    
    if ($endIndex -ne -1) {
        # Ajouter la longueur de la chaîne de fin pour tout inclure
        $endIndex += '    IndicatorRelease(adxHandle);
    IndicatorRelease(obvHandle);
}'.Length
        
        # Supprimer la fonction en double
        $newContent = $content.Remove($startIndex, $endIndex - $startIndex)
        
        # Écrire le nouveau contenu dans le fichier
        Set-Content -Path $filePath -Value $newContent -NoNewline
        Write-Host "La fonction en double a été supprimée avec succès."
    } else {
        Write-Host "Impossible de trouver la fin de la fonction en double."
    }
} else {
    Write-Host "Aucune fonction en double trouvée."
}
