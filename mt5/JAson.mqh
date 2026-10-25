//+------------------------------------------------------------------+
//|                                                   JAson.mqh      |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Types de données JSON
enum ENUM_JSON_TYPE {
   JSON_TYPE_UNDEFINED = 0,
   JSON_TYPE_OBJECT,
   JSON_TYPE_ARRAY,
   JSON_TYPE_STRING,
   JSON_TYPE_NUMBER,
   JSON_TYPE_BOOL,
   JSON_TYPE_NULL
};

//+------------------------------------------------------------------+
//| Classe simplifiée pour le parsing JSON                           |
//+------------------------------------------------------------------+
class CJAVal
{
private:
   string          m_data;          // Données JSON brutes
   ENUM_JSON_TYPE  m_type;          // Type de la valeur
   string          m_error;         // Message d'erreur
   
   // Méthodes privées
   string          GetStringValue(const string &json, int &pos);
   double          GetNumberValue(const string &json, int &pos);
   bool            GetBoolValue(const string &json, int &pos);
   void            SkipWhitespace(const string &json, int &pos);
   
public:
   // Constructeurs
   CJAVal() : m_type(JSON_TYPE_UNDEFINED) {}
   CJAVal(const string &value, ENUM_JSON_TYPE type = JSON_TYPE_UNDEFINED) : m_data(value), m_type(type) {}
   
   // Méthodes principales
   bool            Deserialize(const string &json);
   string          ToString() const { return m_data; }
   double          ToDouble() const { return StringToDouble(m_data); }
   int             ToInt() const { return (int)StringToInteger(m_data); }
   bool            ToBool() const { return (m_data == "true" || m_data == "1"); }
   
   // Getters
   ENUM_JSON_TYPE  GetType() const { return m_type; }
   string          GetError() const { return m_error; }
   
   // Conversion methods - explicit operators not supported in MQL5
   
   // Array access methods
   CJAVal* operator[](const string key) { 
      static CJAVal empty;
      return GetPointer(empty);
   }
   
   CJAVal* operator[](int index) { 
      static CJAVal empty;
      return GetPointer(empty);
   }
};

// Implémentation des méthodes
//+------------------------------------------------------------------+
//| Désérialisation JSON                                             |
//+------------------------------------------------------------------+
bool CJAVal::Deserialize(const string &json)
{
   m_data = json;
   m_type = JSON_TYPE_STRING; // Simplification pour la démo
   return true;
}

//+------------------------------------------------------------------+
//| Lit une valeur chaîne depuis le JSON                             |
//+------------------------------------------------------------------+
string CJAVal::GetStringValue(const string &json, int &pos)
{
   string result = "";
   int len = StringLen(json);
   
   while(pos < len && json[pos] != '"')
      pos++;
   
   if(pos >= len) return "";
   
   int start = ++pos;
   while(pos < len && json[pos] != '"')
      pos++;
   
   if(pos > start)
      result = StringSubstr(json, start, pos - start);
   
   return result;
}

//+------------------------------------------------------------------+
//| Lit une valeur numérique depuis le JSON                          |
//+------------------------------------------------------------------+
double CJAVal::GetNumberValue(const string &json, int &pos)
{
   string numStr = "";
   int len = StringLen(json);
   
   while(pos < len && (StringGetCharacter("0123456789.-+eE", StringGetCharacter(json, pos)) >= 0))
   {
      numStr += StringSubstr(json, pos, 1);
      pos++;
   }
   
   return StringToDouble(numStr);
}

//+------------------------------------------------------------------+
//| Lit une valeur booléenne depuis le JSON                          |
//+------------------------------------------------------------------+
bool CJAVal::GetBoolValue(const string &json, int &pos)
{
   if(StringSubstr(json, pos, 4) == "true")
   {
      pos += 4;
      return true;
   }
   else if(StringSubstr(json, pos, 5) == "false")
   {
      pos += 5;
      return false;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Saute les espaces blancs dans la chaîne JSON                     |
//+------------------------------------------------------------------+
void CJAVal::SkipWhitespace(const string &json, int &pos)
{
   int len = StringLen(json);
   while(pos < len && StringGetCharacter(" \t\r\n", StringGetCharacter(json, pos)) >= 0)
      pos++;
}

//+------------------------------------------------------------------+
