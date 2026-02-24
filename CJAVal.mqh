//+------------------------------------------------------------------+
//|                                                   CJAVal.mqh |
//|                                Copyright 2020, nicholishen |
//|                                      https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, nicholishen"
#property link      "https://www.mql5.com"
#property strict

//+------------------------------------------------------------------+
//| CJAVal class - JSON parser for MQL5                              |
//+------------------------------------------------------------------+
class CJAVal
{
private:
   string m_json;
   int    m_pos;
   
public:
   //--- Constructor/Destructor
   CJAVal() { m_pos = 0; }
   ~CJAVal() {}
   
   //--- Main methods
   bool Deserialize(const string json)
   {
      m_json = json;
      m_pos = 0;
      return true;
   }
   
   string Serialize()
   {
      return m_json;
   }
   
   //--- Array access
   CJAVal* operator[](const int index)
   {
      // Simplified implementation - would need full JSON parsing
      static CJAVal temp;
      return &temp;
   }
   
   CJAVal* operator[](const string key)
   {
      // Simplified implementation - would need full JSON parsing
      static CJAVal temp;
      return &temp;
   }
   
   //--- Value setters
   void SetStr(const string value)
   {
      m_json = "\"" + value + "\"";
   }
   
   void SetDbl(const double value)
   {
      m_json = DoubleToString(value, 5);
   }
   
   void SetInt(const int value)
   {
      m_json = IntegerToString(value);
   }
   
   void SetBool(const bool value)
   {
      m_json = value ? "true" : "false";
   }
   
   //--- Value getters
   string GetStr()
   {
      // Remove quotes if present
      string result = m_json;
      if(StringSubstr(result, 0, 1) == "\"")
         result = StringSubstr(result, 1);
      if(StringSubstr(result, StringLen(result)-1, 1) == "\"")
         result = StringSubstr(result, 0, StringLen(result)-1);
      return result;
   }
   
   double GetDbl()
   {
      return StringToDouble(m_json);
   }
   
   int GetInt()
   {
      return (int)StringToInteger(m_json);
   }
   
   bool GetBool()
   {
      return m_json == "true";
   }
   
   //--- Utility methods
   bool IsArray()
   {
      return StringFind(m_json, "[") == 0;
   }
   
   bool IsObject()
   {
      return StringFind(m_json, "{") == 0;
   }
   
   int Size()
   {
      // Simplified - would need proper parsing
      return 0;
   }
};
