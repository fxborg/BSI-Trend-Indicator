//+------------------------------------------------------------------+
//|                                               Swing Strength.mq5 |
//| Swing Strength v1.00                      Copyright 2015, fxborg |
//|                                   http://fxborg-labo.hateblo.jp/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, fxborg"
#property link      "http://fxborg-labo.hateblo.jp/"
#property version   "1.00"
#include <MovingAverages.mqh>

#property indicator_separate_window
#property indicator_buffers 7
#property indicator_plots   4

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSilver
#property indicator_type2   DRAW_COLOR_HISTOGRAM
#property indicator_color2  DodgerBlue,Red,SkyBlue,Gold
#property indicator_type3   DRAW_FILLING
#property indicator_color3  DarkSlateGray
#property indicator_width1 1
#property indicator_width2 3 
#property indicator_width3 1 
#property indicator_style1 STYLE_DOT
#property indicator_style3 STYLE_DOT
//--- input parameters
input int Inp1stPeriod=7; // 1st Period 
input int Inp2ndPeriod=14;// 2nd Period 
input int Inp3rdPeriod=28;// 3rd Period 
input int Inp1stK=4;// 1st K 
input int Inp2ndK=2;// 2nd K 
input int Inp3rdK=1;// 3rd K 
input int InpSlowPeriod=7;// Avg Period 

input int InpThresholdPeriod=120;// ThreshHold Period 
input double InpThreshold=0.3;// Threshold Level

//---- will be used as indicator buffers
double UpBuffer[];
double DnBuffer[];
double UpperLvBuffer[];
double LowerLvBuffer[];
double MainBuffer[];
double SlowBuffer[];
double ColorBuffer[];
double SigBuffer[];
//---- declaration of global variables
int min_rates_total;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//---- Initialization of variables of data calculation starting point
   min_rates_total=InpThresholdPeriod+MathMax(MathMax(Inp1stPeriod,Inp2ndPeriod),Inp3rdPeriod);
//--- indicator buffers mapping

   SetIndexBuffer(0,SlowBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,MainBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3,UpperLvBuffer,INDICATOR_DATA);
   SetIndexBuffer(4,LowerLvBuffer,INDICATOR_DATA);
   SetIndexBuffer(5,SigBuffer,INDICATOR_CALCULATIONS);
//---
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(5,PLOT_EMPTY_VALUE,EMPTY_VALUE);
//---
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,min_rates_total);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,min_rates_total);
//---

   string short_name="Swing Strength v1.00";

   IndicatorSetString(INDICATOR_SHORTNAME,short_name);

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
   int i,first;
   if(rates_total<=min_rates_total)
      return(0);
//---

//+----------------------------------------------------+
//|Set Median Buffeer                                |
//+----------------------------------------------------+
   int begin_pos=min_rates_total;

   first=begin_pos;
   if(first+1<prev_calculated) first=prev_calculated-2;

//---
   for(i=first; i<rates_total && !IsStopped(); i++)
     {
      int i1st=begin_pos+10;
      if(i<=i1st)continue;
      double maH=(high[i-2] +close[i-2] + high[i-1] +close[i-1])/4;
      double maL=( low[i-2] +close[i-2] +  low[i-1] +close[i-1])/4;
      //---
      double dup=MathMax(0,   (  (high[i] + close[i])/2  - maL)  );
      double ddn=MathMax(0,   (maH -(low[i]+close[i ])/2      )  );      
      if((dup+ddn)==0)
         SigBuffer[i] =0;
      else
         SigBuffer[i] = (dup-ddn)*MathAbs((dup-ddn)/(dup+ddn));
      
      int i2nd=i1st+MathMax(MathMax(Inp1stPeriod,Inp2ndPeriod),Inp3rdPeriod);
      if(i<=i2nd) continue;
      double sig1=0.0;
      double sig2=0.0;
      double sig3=0.0;
      for(int j=0; j<Inp1stPeriod; j++) sig1+=SigBuffer[i-j];
      for(int j=0; j<Inp2ndPeriod; j++) sig2+=SigBuffer[i-j];
      for(int j=0; j<Inp3rdPeriod; j++) sig3+=SigBuffer[i-j];
      sig1/=Inp1stPeriod;
      sig2/=Inp2ndPeriod;
      sig3/=Inp3rdPeriod;
      double w=Inp1stK+Inp2ndK+Inp3rdK;
      MainBuffer[i]=(sig1*Inp1stK+sig2*Inp2ndK+sig3*Inp3rdK)/w;
      int i3rd=i2nd+InpSlowPeriod;
      if(i<=i3rd) continue;
            
      SlowBuffer[i]=SimpleMA(i,InpSlowPeriod,MainBuffer);
      if(MainBuffer[i]>=0)
         ColorBuffer[i]=(SlowBuffer[i]>MainBuffer[i]) ? 2 : 0;
      else        
         ColorBuffer[i]=(SlowBuffer[i]<MainBuffer[i]) ? 3 : 1;

      int i4th=i3rd+InpThresholdPeriod;
      if(i<=i4th) continue;
      double stddev=0;
      for(int j=0;j<InpThresholdPeriod;j++)
         stddev+=MathPow(0-MainBuffer[i-j],2);
      //---
      stddev=MathSqrt(stddev/(InpThresholdPeriod));
      UpperLvBuffer[i]=stddev*InpThreshold;
      LowerLvBuffer[i]=-stddev*InpThreshold;

      

     }
//----    

   return(rates_total);
  }
//+------------------------------------------------------------------+
