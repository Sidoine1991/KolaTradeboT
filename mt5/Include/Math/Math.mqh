//+------------------------------------------------------------------+
//|                                                Math.mqh           |
//|                        Copyright 2023, MetaQuotes Software Corp.  |
//|                                             https://www.mql5.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Fonctions mathématiques de base                                  |
//+------------------------------------------------------------------+
//--- Valeur absolue
#define  MathAbs(x)            ((x)<0.0?-(x):(x))

//--- Valeur maximale entre deux valeurs
#define  MathMax(a,b)          ((a)>(b)?(a):(b))

//--- Valeur minimale entre deux valeurs
#define  MathMin(a,b)          ((a)<(b)?(a):(b))

//--- Arrondi à l'entier le plus proche
double MathRound(double value);

//--- Troncature vers zéro
double MathFloor(double value);

//--- Arrondi à l'entier supérieur
double MathCeil(double value);

//--- Puissance
double MathPow(double base, double exponent);

//--- Racine carrée
double MathSqrt(double value);

//--- Logarithme naturel
double MathLog(double value);

//--- Exponentielle
double MathExp(double value);

//--- Sinus
double MathSin(double value);

//--- Cosinus
double MathCos(double value);

//--- Tangente
double MathTan(double value);

//--- Arc sinus
double MathArcsin(double x);

//--- Arc cosinus
double MathArccos(double x);

//--- Arc tangente
double MathArctan(double x);

//--- Conversion degrés -> radians
double MathDegreeToRadians(double degrees);

//--- Conversion radians -> degrés
double MathRadiansToDegrees(double radians);

//--- Génération d'un nombre aléatoire entre min et max
int MathRand(int min=0, int max=32767);

//--- Initialisation du générateur de nombres aléatoires
void MathSrand(int seed);

//--- Vérification si un nombre est fini
bool MathIsValidNumber(double number);

//--- Vérification si un nombre est infini
bool MathIsInfinite(double number);

//--- Vérification si un nombre n'est pas un nombre (NaN)
bool MathIsNaN(double value);

//--- Valeur absolue d'un nombre entier
#define  MathAbsInt(x)         ((x)<0?-(x):(x))

//--- Valeur maximale entre deux entiers
#define  MathMaxInt(a,b)       ((a)>(b)?(a):(b))

//--- Valeur minimale entre deux entiers
#define  MathMinInt(a,b)       ((a)<(b)?(a):(b))
