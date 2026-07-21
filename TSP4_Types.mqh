#ifndef __TSP4_TYPES_MQH__
#define __TSP4_TYPES_MQH__

enum ENUM_TSP4_DIRECTION
{
   TSP4_DIR_NONE = 0,
   TSP4_DIR_BUY  = 1,
   TSP4_DIR_SELL = -1
};

enum ENUM_TSP4_MARKET_REGIME
{
   TSP4_REGIME_NONE   = 0,
   TSP4_REGIME_GOLDEN = 1,
   TSP4_REGIME_BLACK  = -1
};

enum ENUM_TSP4_SIGNAL_TYPE
{
   TSP4_SIGNAL_NONE          = 0,
   TSP4_SIGNAL_CONFIRMED_DIV = 1,
   TSP4_SIGNAL_FORMING_DIV   = 2,
   TSP4_SIGNAL_CROSS         = 3,
   TSP4_SIGNAL_DEEP_N        = 4,
   TSP4_SIGNAL_NORMAL_N      = 5,
   TSP4_SIGNAL_COUNTER_N     = 6
};

enum ENUM_TSP4_SIGNAL_STATE
{
   TSP4_STATE_NONE      = 0,
   TSP4_STATE_NEW       = 1,
   TSP4_STATE_FILTER_OK = 2,
   TSP4_STATE_WAIT_H1   = 3,
   TSP4_STATE_EXECUTED  = 4,
   TSP4_STATE_FINISHED  = 5
};

struct STSP4_Pivot
{
   bool valid;
   int shift;
   datetime time;
   double price;
   double macd;
};

struct STSP4_D1Snapshot
{
   datetime barTime;
   int trend;
   int regime;
   datetime regimeCrossTime;
   bool goldenCross;
   bool blackCross;
   bool confirmedBearDiv;
   bool confirmedBullDiv;
   bool formingBearDiv;
   bool formingBullDiv;
   STSP4_Pivot lastHigh;
   STSP4_Pivot previousHigh;
   STSP4_Pivot lastLow;
   STSP4_Pivot previousLow;
   double hist1;
   double hist2;
   string reason;
};

struct STSP4_H4Snapshot
{
   datetime barTime;
   double stochK;
   int zone;
   string reason;
};

struct STSP4_Signal
{
   long key;
   int type;
   int direction;
   int state;
   datetime created;
   datetime validUntil;
   string reason;
};

struct STSP4_SarGap
{
   bool valid;
   int oldSide;
   int newSide;
   int oldShift;
   int newShift;
   double oldSar;
   double newSar;
   double upper;
   double lower;
   double distance;
   datetime reversalTime;
};

struct STSP4_TradePlan
{
   string symbol;
   long signalKey;
   int signalType;
   int direction;
   double entry;
   double stopLoss;
   double tp1;
   double tp2;
   double tp3;
   double gap;
   double lot1;
   double lot2;
   double lot3;
   string commentBase;
};

long TSP4_MakeSignalKey(int type, int direction, datetime created)
{
   return((long)created * (long)1000 +
          (long)type * (long)10 +
          (long)(direction + 2));
}

string TSP4_RegimeText(int regime)
{
   if(regime == TSP4_REGIME_GOLDEN) return("GOLDEN");
   if(regime == TSP4_REGIME_BLACK) return("BLACK");
   return("NONE");
}

string TSP4_DirectionText(int direction)
{
   if(direction == TSP4_DIR_BUY) return("BUY");
   if(direction == TSP4_DIR_SELL) return("SELL");
   return("NONE");
}

string TSP4_SignalText(int type)
{
   if(type == TSP4_SIGNAL_CONFIRMED_DIV) return("Signal 1 Confirmed Divergence");
   if(type == TSP4_SIGNAL_FORMING_DIV)   return("Signal 2 Forming Divergence");
   if(type == TSP4_SIGNAL_CROSS)         return("Signal 3 Cross");
   if(type == TSP4_SIGNAL_DEEP_N)        return("Signal 4 Deep N");
   if(type == TSP4_SIGNAL_NORMAL_N)      return("Signal 5 Normal N");
   if(type == TSP4_SIGNAL_COUNTER_N)     return("Signal 6 Counter N");
   return("No signal");
}

#endif
