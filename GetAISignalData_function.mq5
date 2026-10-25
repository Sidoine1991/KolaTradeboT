//+------------------------------------------------------------------+
//| Récupérer les données de l'endpoint Decision                        |
//+------------------------------------------------------------------+
bool GetAISignalData()
{
   static datetime lastAPICall = 0;
   static string lastCachedResponse = "";
   
   datetime currentTime = TimeCurrent();
   
   // Cache API: éviter les appels trop fréquents (toutes les 30 secondes)
   if((currentTime - lastAPICall) < 30 && lastCachedResponse != "")
   {
      // Utiliser la réponse en cache
      if(StringFind(lastCachedResponse, "\"action\":") >= 0)
      {
         int actionStart = StringFind(lastCachedResponse, "\"action\":");
         actionStart = StringFind(lastCachedResponse, "\"", actionStart + 9) + 1;
         int actionEnd = StringFind(lastCachedResponse, "\"", actionStart);
         if(actionEnd > actionStart)
         {
            g_lastAIAction = StringSubstr(lastCachedResponse, actionStart, actionEnd - actionStart);
            return true;
         }
      }
   }
   
   string url = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
   string headers = "Content-Type: application/json\r\n";
   char post[];
   uchar response[];
   
   // Préparer les données de marché
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr = iATR(_Symbol, LTF, 14);
   
   string jsonRequest = StringFormat("{\"symbol\":\"%s\",\"bid\":%.5f,\"ask\":%.5f,\"atr\":%.5f,\"timestamp\":\"%s\"}",
      _Symbol, bid, ask, atr, TimeToString(TimeCurrent()));
   
   Print("📦 ENVOI IA: ", jsonRequest);
   
   StringToCharArray(jsonRequest, post);
   
   int res = WebRequest("POST", url, headers, 10000, post, response, headers);
   
   if(res == 200)
   {
      string jsonResponse = CharArrayToString(response);
      Print("📥 RÉPONSE IA: ", jsonResponse);
      
      // Mettre à jour le cache
      lastAPICall = currentTime;
      lastCachedResponse = jsonResponse;
      
      // Parser la réponse JSON
      int actionStart = StringFind(jsonResponse, "\"action\":");
      if(actionStart >= 0)
      {
         actionStart = StringFind(jsonResponse, "\"", actionStart + 9) + 1;
         int actionEnd = StringFind(jsonResponse, "\"", actionStart);
         if(actionEnd > actionStart)
         {
            g_lastAIAction = StringSubstr(jsonResponse, actionStart, actionEnd - actionStart);
            
            int confStart = StringFind(jsonResponse, "\"confidence\":");
            if(confStart >= 0)
            {
               confStart = StringFind(jsonResponse, ":", confStart) + 1;
               int confEnd = StringFind(jsonResponse, ",", confStart);
               if(confEnd < 0) confEnd = StringFind(jsonResponse, "}", confStart);
               if(confEnd > confStart)
               {
                  string confStr = StringSubstr(jsonResponse, confStart, confEnd - confStart);
                  g_lastAIConfidence = StringToDouble(confStr);
               }
            }
            
            // Extraire alignement et cohérence
            int alignStart = StringFind(jsonResponse, "\"alignment\":");
            if(alignStart >= 0)
            {
               alignStart = StringFind(jsonResponse, "\"", alignStart + 12) + 1;
               int alignEnd = StringFind(jsonResponse, "\"", alignStart);
               if(alignEnd > alignStart)
               {
                  g_lastAIAlignment = StringSubstr(jsonResponse, alignStart, alignEnd - alignStart);
               }
            }
            
            int cohStart = StringFind(jsonResponse, "\"coherence\":");
            if(cohStart >= 0)
            {
               cohStart = StringFind(jsonResponse, "\"", cohStart + 13) + 1;
               int cohEnd = StringFind(jsonResponse, "\"", cohStart);
               if(cohEnd > cohStart)
               {
                  g_lastAICoherence = StringSubstr(jsonResponse, cohStart, cohEnd - cohStart);
               }
            }
            
            g_lastAIUpdate = TimeCurrent();
            g_aiConnected = true;
            
            Print("✅ IA MISE À JOUR: ", g_lastAIAction, " | ", DoubleToString(g_lastAIConfidence*100,1), "% | ", g_lastAIAlignment, " | ", g_lastAICoherence);
            
            return true;
         }
      }
   }
   else
   {
      Print("❌ ERREUR IA: HTTP ", res);
      g_aiConnected = false;
   }
   
   return false;
}
