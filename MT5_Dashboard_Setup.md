# Configuration du Dashboard dans MT5

## ✅ État actuel

Le robot communique parfaitement avec le serveur AI :
- ✅ **Serveur local** : Échec normal (pas démarré)
- ✅ **Serveur distant** : Communication réussie
- ✅ **Données envoyées** : JSON correct
- ✅ **Réponses reçues** : Signaux IA valides

## 🖥️ Problème d'affichage du dashboard

Le dashboard ne s'affiche pas sur le graphique. Voici les solutions :

### 🔧 Solution 1: Vérifier les paramètres du graphique

1. **Clic droit sur le graphique** → **Propriétés**
2. **Onglet "Affichage"** :
   - ✅ Cocher "Afficher les objets graphiques"
   - ✅ Cocher "Afficher les libellés"
   - ✅ Cocher "Afficher le texte"

3. **Onglet "Général"** :
   - ✅ Vérifier que "Afficher l'ask" et "Afficher le bid" sont cochés

### 🔧 Solution 2: Activer les experts et autoriser les DLL

1. **Outils** → **Options** → **Experts**
2. **Cocher** :
   - ✅ "Autoriser le trading automatique"
   - ✅ "Autoriser l'importation de DLL"
   - ✅ "Autoriser les experts pour trader"

3. **Bouton "AutoTrading"** dans la barre d'outils MT5 doit être **VERT**

### 🔧 Solution 3: Vérifier les objets créés

1. **Clic droit sur le graphique** → **Liste des objets**
2. **Chercher** "Dashboard" dans la liste
3. **Si trouvé** : Clic droit → **Propriétés** → Vérifier la position
4. **Si non trouvé** : Le robot ne crée pas l'objet

### 🔧 Solution 4: Forcer l'affichage manuel

Dans le robot, ajoutez ce code de test dans `OnTick()` :

```mql5
// Test d'affichage du dashboard
static bool testCreated = false;
if(!testCreated)
{
   if(ObjectCreate(0, "TestDashboard", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "TestDashboard", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "TestDashboard", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, "TestDashboard", OBJPROP_YDISTANCE, 10);
      ObjectSetInteger(0, "TestDashboard", OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, "TestDashboard", OBJPROP_COLOR, clrYellow);
      ObjectSetString(0, "TestDashboard", OBJPROP_TEXT, "🤖 TEST DASHBOARD ACTIF");
      testCreated = true;
      Print("✅ Dashboard de test créé avec succès");
   }
   else
   {
      Print("❌ Erreur création dashboard test: ", GetLastError());
   }
}
```

### 🔧 Solution 5: Vérifier les logs d'erreurs

1. **Onglet "Experts"** dans MT5
2. **Chercher** les messages :
   - "Erreur lors de la création de l'objet Dashboard"
   - "Dashboard créé avec succès"

### 🔧 Solution 6: Réinitialiser le graphique

1. **Fermer MT5**
2. **Supprimer les fichiers de cache** :
   - `C:\Users\VOTRE_NOM\AppData\Roaming\MetaQuotes\Terminal\[ID]\history`
3. **Redémarrer MT5**
4. **Attacher le robot** à un nouveau graphique

## 📋 Étapes de diagnostic

1. **Vérifiez que le robot est bien attaché** :
   - Nom du robot visible en haut du graphique
   - Icône "sourire" verte

2. **Vérifiez les logs Experts** :
   - Messages de création du dashboard
   - Messages d'erreur éventuels

3. **Testez avec un graphique vierge** :
   - Nouveau graphique EURUSD M1
   - Attachez le robot
   - Attendez 1-2 minutes

## 🚀 Si rien ne fonctionne

Créez un indicateur simple pour tester :

```mql5
//+------------------------------------------------------------------+
//|                                    TestDisplay.mq5 |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_plots 0

int OnInit()
{
   ObjectCreate(0, "TestLabel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "TestLabel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "TestLabel", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "TestLabel", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "TestLabel", OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, "TestLabel", OBJPROP_COLOR, clrRed);
   ObjectSetString(0, "TestLabel", OBJPROP_TEXT, "TEST AFFICHAGE ACTIF");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectDelete(0, "TestLabel");
}

int OnCalculate(const int rates_total,
              const int prev_calculated,
              const datetime &time[],
              const double &open[],
              const double &high[],
              const double &low[],
              const double &close[])
{
   return(rates_total);
}
```

## 📞 Support

Si le dashboard ne s'affiche toujours pas :
1. Vérifiez la version de MT5 (doit être récente)
2. Testez sur un autre ordinateur
3. Contactez le support MT5

Le robot fonctionne parfaitement, seul l'affichage visuel pose problème !
