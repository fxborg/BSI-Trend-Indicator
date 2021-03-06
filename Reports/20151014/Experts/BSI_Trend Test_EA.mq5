//+------------------------------------------------------------------+
//|                                            BSI_Trend_Test_EA.mq5 |
//|                                           Copyright 2015, fxborg |
//|                                  http://blog.livedoor.jp/fxborg/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, fxborg"
#property link      "http://blog.livedoor.jp/fxborg/"
#property version   "1.00"
#property strict


#include <Trade\Trade.mqh>


//---

#define PIP      ((_Digits <= 3) ? 0.01 : 0.0001)

//---
input ENUM_TIMEFRAMES  Timeframe_Bar = PERIOD_M5;
input ENUM_TIMEFRAMES  Timeframe_BSI = PERIOD_H1;
input ENUM_TIMEFRAMES  Timeframe_Slow= PERIOD_D1;
//---

//---
input string  Order_Settings=" Trade Settings: ";
input double  Lot         = 0.1;
input int     SL          = 200;
input int     TP          = 200;
//---
input double  Slippage    = 3.0;
input ulong   Magic       = 6516001;
input int     SpreadLimit=10;
input double  MaxSpread=10;
input bool    AutoLots=false;
//---

//---
input string  StartTime   = "10:00";
input string  EndTime     = "02:00";
input int     PositionExpire=60;
input int     Friday_CloseTime=2200;
input bool    LunchTimeTrade=false;

input string Description2="--- BSI Settings---";

input int    InpBSIPeriod=5;           // BSI_CalcBars
input int    InpFastPeriod=10;             // Fast Period
input int    InpSlowPeriod=7;            //  Slow Period
input bool   InpUsingVolumeWeight=true;  // Using TickVolume
input int    InpLwMaPeriod=30;         //  LWMA Period

//---
ENUM_SYMBOL_TRADE_EXECUTION execution;
int Slippage_P;
double  NormLot,SL_P,TP_P,StepTrail_P,SpreadLimit_P,BrakeEven_P;
double  STOP_LEVEL,FREEZE_LEVEL,VOL_STEP,VOL_MIN,VOL_MAX;
//---

// Globals variables
CTrade  trade;
MqlTick tick;

int BSI_Handle;
int SlowTrend_Handle;
int StartTimeInt,EndTimeInt;
int PositionExpireSec;
int min_rates_total;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

//---
   StartTimeInt=TimeHour(StringToTime(StartTime))*100+TimeMinute(StringToTime(StartTime));
   EndTimeInt=TimeHour(StringToTime(EndTime))*100+TimeMinute(StringToTime(EndTime));
//---

//---
   PositionExpireSec=PositionExpire*3600;
//---

//---
   SpreadLimit_P=NormalizeDouble(SpreadLimit*PIP/_Point,0);
   Slippage_P=(int)NormalizeDouble(Slippage*PIP/_Point,0);
//---
   execution=(ENUM_SYMBOL_TRADE_EXECUTION) SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE);
//---

//---
   STOP_LEVEL       = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * PIP;
   FREEZE_LEVEL     = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * PIP;
   VOL_STEP         = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   VOL_MIN          = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   VOL_MAX          = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
//---

//---
   SL_P=NormDbl(SL * (PIP/_Point) * _Point);
   TP_P=NormDbl(TP * (PIP/_Point) * _Point);
//---

//---
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(Slippage_P);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   trade.SetAsyncMode(true);
//---

//---
   min_rates_total=100;

//---
   BSI_Handle=iCustom(NULL,Timeframe_BSI,"BSI_Trend_Indicator"
                      ,InpBSIPeriod,InpFastPeriod,InpSlowPeriod,InpUsingVolumeWeight,InpLwMaPeriod);

//---
   if(BSI_Handle==INVALID_HANDLE)
     {
      Alert("Error in loading of FastCCIHandle. Error = ",GetLastError());
      return(INIT_FAILED);
     }
//---

   SlowTrend_Handle=iCustom(NULL,Timeframe_Slow,"BSI_Trend_Indicator"
                            ,InpBSIPeriod,InpFastPeriod,InpSlowPeriod,InpUsingVolumeWeight,InpLwMaPeriod);

//---
   if(SlowTrend_Handle==INVALID_HANDLE)
     {
      Alert("Error in loading of FastCCIHandle. Error = ",GetLastError());
      return(INIT_FAILED);
     }
//---

//---
   ChartIndicatorAdd(ChartID(),0,BSI_Handle);
   ChartIndicatorAdd(ChartID(),1,SlowTrend_Handle);
//---

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   static datetime LastTime;

//---
   if(Bars(_Symbol, Timeframe_BSI) <=  min_rates_total) return;
//---

//---
   datetime now[1];
   if(CopyTime(_Symbol,Timeframe_Bar,0,1,now) != 1 ) return;
//---

//---
   if(!SymbolInfoTick(_Symbol, tick)) return;
//---

//---
   if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC)==Magic)
     {
      datetime openTime=(datetime)PositionGetInteger(POSITION_TIME);
      CheckClose(openTime,(ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE));
     }
//---

//---
   if(LastTime!=now[0])
     {
      LastTime=now[0];
      //---
      int allow_open=false;
      //---
      if(DayOfWeek()!=5)
        {
         if((StartTimeInt<=EndTimeInt) && (now[0]>=StartTimeInt && now[0]<EndTimeInt))
            allow_open=true;
         if((StartTimeInt>EndTimeInt) && (now[0]>=StartTimeInt || now[0]<EndTimeInt))
            allow_open=true;
        }
      //---
      if(!LunchTimeTrade && now[0]==12) allow_open=false;
      if(!allow_open)return;

      //---
      if(( tick.ask-tick.bid) > SpreadLimit_P) return;

      //---

      //---
      ENUM_POSITION_TYPE position_type=NULL;
      double position_volume=0.0;
      double autolot=(AutoLots==false)? Lot:(MathRound(AccountInfoDouble(ACCOUNT_BALANCE)/100)/100);
      //---
      if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC)==Magic)
        {
         position_type=(ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
         position_volume=PositionGetDouble(POSITION_VOLUME);
        }
      else
        {
         position_type=NULL;
         position_volume=0;
        }
      //---
      //AccountBalance 200%  < position volume return 
      if((autolot * 2) < position_volume) return;
      //---

      //---

      int sig=0;
      sig=CheckSignal();
      //---

      if(sig==1)
         //--- BUY
        {
         //--- every buy deals check ( close sell too) 
         if(hasDeal(12,DEAL_TYPE_BUY))return;
         if(position_volume==0.0)
            //--- Probing Buy
           {
            OpenOrder(ORDER_TYPE_BUY,autolot,SL,TP,"Probing Buy");
            return;

           }
         else if(position_type==POSITION_TYPE_BUY)
         //--- Retracement Buy
           {
            OpenOrder(ORDER_TYPE_BUY,autolot*0.5,SL,TP,"Retracement Buy");
            return;
           }

        }

      else if(sig==-1)
      //--- SELL
        {
         //--- every sell deals check ( close buy too) 
         if(hasDeal(12,DEAL_TYPE_SELL))return;

         if(position_volume==0)
           {
            OpenOrder(ORDER_TYPE_SELL,autolot,SL,TP,"Probing Sell");
            return;
           }

         else if(position_type==POSITION_TYPE_SELL)
         //--- Retracement Sell
           {
            OpenOrder(ORDER_TYPE_SELL,autolot*0.5,SL,TP,"Retracement Sell");
            return;
           }

        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CheckSignal()
  {
//---
   double Median1st_Buffer[];
   double Trend_Buffer[];
   double VolatBuffer[];
   double BSIBuffer[];
   double SlowTrendBuffer[];

//---

//---
   ArraySetAsSeries(Median1st_Buffer,true);
   ArraySetAsSeries(Trend_Buffer,true);
   ArraySetAsSeries(VolatBuffer,true);
   ArraySetAsSeries(BSIBuffer,true);
   ArraySetAsSeries(SlowTrendBuffer,true);

//---

//---
   if(CopyBuffer(BSI_Handle   , 0, 1, 3, Median1st_Buffer) == -1)   return 0;
   if(CopyBuffer(BSI_Handle   , 3, 1, 9, Trend_Buffer) == -1)   return 0;
   if(CopyBuffer(BSI_Handle   , 5, 1, 5, VolatBuffer) == -1)     return 0;
   if(CopyBuffer(BSI_Handle   , 4, 1, 6, BSIBuffer) == -1)     return 0;
   if(CopyBuffer(SlowTrend_Handle,3, 1,2, SlowTrendBuffer) == -1)   return 0;


//---
   double maxv= MathMax(MathMax(VolatBuffer[4] , VolatBuffer[3]),VolatBuffer[2]);
   double minv= MathMin(MathMin(VolatBuffer[4] , VolatBuffer[3]),VolatBuffer[2]);


//---

//---

//--- check buy or sell 
   int sig=0;
//---

   double avg_bsi=(BSIBuffer[3]+BSIBuffer[2]+BSIBuffer[1])/3;
   double max_bsi=MathMax(MathMax(BSIBuffer[3],BSIBuffer[2]),BSIBuffer[1]);
   double min_bsi=MathMin(MathMin(BSIBuffer[3],BSIBuffer[2]),BSIBuffer[1]);

   double avg1_trend=(Trend_Buffer[4]+Trend_Buffer[3]+Trend_Buffer[2])/3;
   double avg2_trend=(Trend_Buffer[2]+Trend_Buffer[1]+Trend_Buffer[0])/3;
   double avg_trend=(Trend_Buffer[4]+Trend_Buffer[3]+Trend_Buffer[2]+Trend_Buffer[1]+Trend_Buffer[0])/5;

// day trend -> UP
   if(SlowTrendBuffer[1]==4 && SlowTrendBuffer[0]==4)
     {
      if(avg_trend>=1.5 && avg_trend<=2.5 && avg_bsi<BSIBuffer[0] && max_bsi<0)
         sig=1;

      if(avg_trend>=0.5 && avg_trend<=2.2 && (avg1_trend<avg2_trend) && avg_bsi>BSIBuffer[0])
         sig=1;

     }
// day trend -> down
   else if(SlowTrendBuffer[1]==0 && SlowTrendBuffer[0]==0)
     {
      if(avg_trend<=2.5 && avg_trend>=1.5 && avg_bsi>BSIBuffer[0] && min_bsi>0)
         sig=-1;

      if(avg_trend<=3.5 && avg_trend>=1.8 && (avg1_trend>avg2_trend) && avg_bsi<BSIBuffer[0])
         sig=-1;

     }
   else
     {
      if(avg_trend>=1.5 && avg_trend<=2.5 && (avg1_trend<avg2_trend) && avg_bsi<BSIBuffer[0] && max_bsi>0)
         sig=1;
      if(avg_trend<=2.5 && avg_trend>=1.5 && (avg1_trend>avg2_trend) && avg_bsi>BSIBuffer[0] && min_bsi<0)
         sig=-1;
     }


//---
   return(sig);
//---

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizeLots(double __lots)
  {
//---
   int _lotsteps   = (int)(__lots / VOL_STEP);
   double _Nlots   = _lotsteps * VOL_STEP;
//---
   if(_Nlots < VOL_MIN) _Nlots = VOL_MIN;
   if(_Nlots > VOL_MAX) _Nlots = VOL_MAX;
//---

   return(_Nlots);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeHour(datetime date)
  {
   MqlDateTime tm;
   TimeToStruct(date,tm);
   return(tm.hour);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeMinute(datetime date)
  {
   MqlDateTime tm;
   TimeToStruct(date,tm);
   return(tm.min);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormDbl(double value)
  {
   return NormalizeDouble(value, _Digits);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckClose(datetime ordertime,ENUM_POSITION_TYPE pos_type)
  {
//---
   bool is_stop=false;
   int now=TimeHour(TimeCurrent())*100+TimeMinute(TimeCurrent());
//---

//---
   if(PositionExpire>0 && (TimeCurrent()-PositionExpireSec)>ordertime) is_stop=true;
   if(Friday_CloseTime>=0 && DayOfWeek()==5 && now>Friday_CloseTime) is_stop=true;

//---

//---

/*
   double Trend_Buffer[];
   ArraySetAsSeries(Trend_Buffer,true);
   if(CopyBuffer(BSI_Handle   , 3, 1, 3, Trend_Buffer) != -1)
    {
    
      if(pos_type==POSITION_TYPE_BUY &&
         Trend_Buffer[2]==0 &&
         Trend_Buffer[1]==0 &&
         Trend_Buffer[0]==0)
         {
         is_stop=true;
         }
      if(pos_type==POSITION_TYPE_SELL &&
         Trend_Buffer[2]==4 &&
         Trend_Buffer[1]==4 &&
         Trend_Buffer[0]==4)
         {
          is_stop=true;
         }
    }
*/

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(is_stop)
     {
      trade.PositionClose(_Symbol);
     }

   return is_stop;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int DayOfWeek()
  {
   MqlDateTime tm;
   TimeCurrent(tm);
   return(tm.day_of_week);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool _OrderSend(ENUM_ORDER_TYPE type,double lots,double price,double stoploss,double takeprofit,string comment)
  {
   bool isECN=(execution == SYMBOL_TRADE_EXECUTION_MARKET);
   double sl = isECN ? 0.0: stoploss;
   double tp = isECN ? 0.0: takeprofit;

   trade.PositionOpen(_Symbol,type,lots,price,sl,tp,comment);

   if(trade.ResultRetcode()!=TRADE_RETCODE_DONE)
     {
      Print("PositionOpen Error: ",trade.ResultRetcodeDescription());
      return false;

     }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(isECN && (stoploss>0 || takeprofit>0))
     {
      Sleep(100);
      trade.PositionModify(_Symbol,stoploss,stoploss);
      if(trade.ResultRetcode()!=TRADE_RETCODE_DONE)
        {
         Print("PositionModify Error: ",trade.ResultRetcodeDescription());
         return false;
        }

     }
   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenOrder(ENUM_ORDER_TYPE cmd,double lot,int stop_loss,int take_profit,string comment)
  {
//---
   double sl = 0;
   double tp = 0;
   double price=0.0;
//---
   if(cmd==ORDER_TYPE_SELL)
     {
      sl=(SL==0) ? 0.0: NormDbl(tick.bid  + SL * PIP);
      tp=(TP==0) ? 0.0: NormDbl(tick.bid  - TP * PIP);
      price=tick.bid;
     }
//---
   else if(cmd==ORDER_TYPE_BUY)
     {
      sl=(SL==0) ? 0.0: NormDbl(tick.ask - SL * PIP);
      tp=(TP==0) ? 0.0: NormDbl(tick.ask + TP * PIP);
      price=tick.ask;
     }
   else
      return;

   _OrderSend(cmd,NormalizeLots(lot),price,sl,tp,comment);

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool hasDeal(int barCount,ENUM_DEAL_TYPE type)
  {
//---
   datetime from=(TimeCurrent() -(barCount*PeriodSeconds(Timeframe_BSI)));
   HistorySelect(from,TimeCurrent());
//---
   for(int k=HistoryDealsTotal()-1; k>=0; k--)
     {
      //---
      ulong ticket=HistoryDealGetTicket(k);
      if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=_Symbol) continue;
      long hist_magic=HistoryDealGetInteger(ticket,DEAL_MAGIC);
      ENUM_DEAL_TYPE hist_order_type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket,DEAL_TYPE);
      //---
      if(hist_magic == Magic && hist_order_type == type)   return true;
      //---
     }

//---
   return false;
//---
  }
//+------------------------------------------------------------------+
