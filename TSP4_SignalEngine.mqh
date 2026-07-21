#ifndef __TSP4_SIGNAL_ENGINE_MQH__
#define __TSP4_SIGNAL_ENGINE_MQH__

class CTSP4SignalEngine
{
private:
   STSP4_D1Snapshot m_d1;
   STSP4_H4Snapshot m_h4;
   STSP4_Signal m_signal;
   bool m_hasSignal;
   bool m_filterPass;
   string m_reason;

   int m_lastH4Zone;
   int m_lastH4SignalType;
   int m_lastH4Direction;
   int m_regime;
   datetime m_regimeCrossTime;
   bool m_enableDivergence;

   void ClearSignal(string reason)
   {
      m_hasSignal=false;
      m_filterPass=false;
      m_signal.key=0;
      m_signal.type=TSP4_SIGNAL_NONE;
      m_signal.direction=TSP4_DIR_NONE;
      m_signal.state=TSP4_STATE_NONE;
      m_reason=reason;
   }

   void SetSignal(int type, int direction, datetime created,
                  int validityDays, string reason)
   {
      m_signal.type=type;
      m_signal.direction=direction;
      m_signal.created=created;
      m_signal.validUntil=created+validityDays*86400;
      m_signal.state=TSP4_STATE_NEW;
      m_signal.reason=reason;
      m_signal.key=TSP4_MakeSignalKey(type,direction,created);
      m_hasSignal=true;
      m_filterPass=false;
      m_reason=reason;
   }

   bool RegimeDirectionValid(int direction)
   {
      if(m_regime==TSP4_REGIME_GOLDEN) return(direction==TSP4_DIR_BUY);
      if(m_regime==TSP4_REGIME_BLACK)  return(direction==TSP4_DIR_SELL);
      return(false);
   }

   void SetRegimeBaseSignal()
   {
      if(m_regime==TSP4_REGIME_GOLDEN)
      {
         SetSignal(TSP4_SIGNAL_NORMAL_N,TSP4_DIR_BUY,m_d1.barTime,30,
                   "GOLDEN regime base signal");
         return;
      }
      if(m_regime==TSP4_REGIME_BLACK)
      {
         SetSignal(TSP4_SIGNAL_NORMAL_N,TSP4_DIR_SELL,m_d1.barTime,30,
                   "BLACK regime base signal");
         return;
      }
      ClearSignal("No active D1 regime");
   }

public:
   void Init(bool enableDivergence)
   {
      m_regime=TSP4_REGIME_NONE;
      m_regimeCrossTime=0;
      m_enableDivergence=enableDivergence;
      ClearSignal("Not initialized");
   }

   string LastReason(){ return(m_reason); }
   bool FilterPass(){ return(m_filterPass); }
   int Regime(){ return(m_regime); }
   string RegimeText(){ return(TSP4_RegimeText(m_regime)); }

   void OnNewD1(STSP4_D1Snapshot &d1)
   {
      int oldRegime=m_regime;
      m_d1=d1;
      m_regime=d1.regime;
      m_regimeCrossTime=d1.regimeCrossTime;

      // A regime switch is authoritative: all prior incompatible signal state dies here.
      if(oldRegime!=m_regime)
      {
         ClearSignal("Regime switched "+TSP4_RegimeText(oldRegime)+
                     " -> "+TSP4_RegimeText(m_regime));
         Print("[TSP4][REGIME_SWITCH] old=",TSP4_RegimeText(oldRegime),
               " new=",TSP4_RegimeText(m_regime),
               " hist1=",DoubleToString(d1.hist1,6),
               " hist2=",DoubleToString(d1.hist2,6),
               " crossTime=",TimeToString(d1.regimeCrossTime,TIME_DATE|TIME_MINUTES));
      }
      else
      {
         // Signal 3 has locked priority for its full five-day validity.
         // A routine D1 refresh must not replace it with the regime base
         // signal, otherwise the next H4 update can incorrectly route to
         // Signals 4-6.
         if(m_hasSignal &&
            m_signal.type==TSP4_SIGNAL_CROSS &&
            TimeCurrent()<=m_signal.validUntil &&
            RegimeDirectionValid(m_signal.direction))
         {
            m_filterPass=true;
            m_signal.state=TSP4_STATE_FILTER_OK;
            m_reason=m_signal.reason+" | Signal 3 locked priority; D1 refresh ignored";

            Print("[TSP5][SIGNAL3_PRIORITY_LOCK] key=",m_signal.key,
                  " direction=",TSP4_DirectionText(m_signal.direction),
                  " created=",TimeToString(m_signal.created,TIME_DATE|TIME_MINUTES),
                  " validUntil=",TimeToString(m_signal.validUntil,TIME_DATE|TIME_MINUTES),
                  " regime=",TSP4_RegimeText(m_regime));
            return;
         }

         ClearSignal("D1 refresh in "+TSP4_RegimeText(m_regime)+" regime");
      }

      // Divergence signals are completely bypassed in the v4.1.3
      // No Divergence Test when the master module switch is false.
      if(m_enableDivergence)
      {
         if(d1.confirmedBearDiv)
         {
            SetSignal(TSP4_SIGNAL_CONFIRMED_DIV,TSP4_DIR_SELL,d1.barTime,30,
                      "Confirmed bearish divergence"); return;
         }
         if(d1.confirmedBullDiv)
         {
            SetSignal(TSP4_SIGNAL_CONFIRMED_DIV,TSP4_DIR_BUY,d1.barTime,30,
                      "Confirmed bullish divergence"); return;
         }
         if(d1.formingBearDiv)
         {
            SetSignal(TSP4_SIGNAL_FORMING_DIV,TSP4_DIR_SELL,d1.barTime,30,
                      "Forming bearish divergence"); return;
         }
         if(d1.formingBullDiv)
         {
            SetSignal(TSP4_SIGNAL_FORMING_DIV,TSP4_DIR_BUY,d1.barTime,30,
                      "Forming bullish divergence"); return;
         }
      }

      // Signal 3 is emitted only by the matching CLOSED-BAR cross.
      if(d1.goldenCross && m_regime==TSP4_REGIME_GOLDEN)
      {
         SetSignal(TSP4_SIGNAL_CROSS,TSP4_DIR_BUY,d1.barTime,5,
                   "Golden Cross confirmed; regime=GOLDEN"); return;
      }
      if(d1.blackCross && m_regime==TSP4_REGIME_BLACK)
      {
         SetSignal(TSP4_SIGNAL_CROSS,TSP4_DIR_SELL,d1.barTime,5,
                   "Black Cross confirmed; regime=BLACK"); return;
      }

      SetRegimeBaseSignal();
   }

   void OnNewH4(STSP4_H4Snapshot &h4)
   {
      m_h4=h4;
      if(!m_hasSignal) return;

      if(TimeCurrent()>m_signal.validUntil)
      {
         m_signal.state=TSP4_STATE_FINISHED;
         m_filterPass=false;
         m_reason="Signal expired";
         return;
      }

      int type=m_signal.type;
      int direction=m_signal.direction;

      if(type==TSP4_SIGNAL_CONFIRMED_DIV && !m_enableDivergence)
      {
         ClearSignal("Confirmed divergence blocked: module OFF");
         return;
      }

      if(type==TSP4_SIGNAL_FORMING_DIV && !m_enableDivergence)
      {
         ClearSignal("Forming divergence blocked: module OFF");
         return;
      }

      if(type==TSP4_SIGNAL_CONFIRMED_DIV || type==TSP4_SIGNAL_CROSS)
      {
         m_filterPass=true;
         m_signal.state=TSP4_STATE_FILTER_OK;
         m_reason=m_signal.reason+
                  (type==TSP4_SIGNAL_CROSS
                   ? " | Signal 3 locked priority; H4 ignored"
                   : " | no H4 filter");

         if(type==TSP4_SIGNAL_CROSS)
            Print("[TSP5][SIGNAL3_H4_BYPASS] key=",m_signal.key,
                  " direction=",TSP4_DirectionText(m_signal.direction),
                  " H4K=",DoubleToString(h4.stochK,2),
                  " zone=",h4.zone);
         return;
      }

      if(type==TSP4_SIGNAL_FORMING_DIV)
      {
         if(direction==TSP4_DIR_SELL && h4.zone==1)
         {
            m_filterPass=true; m_signal.state=TSP4_STATE_FILTER_OK;
            m_reason="Forming bear div + H4 Stoch >= 80";
         }
         else if(direction==TSP4_DIR_BUY && h4.zone==-1)
         {
            m_filterPass=true; m_signal.state=TSP4_STATE_FILTER_OK;
            m_reason="Forming bull div + H4 Stoch <= 20";
         }
         else
         {
            m_filterPass=false;
            m_reason="Forming divergence H4 filter not met";
         }
         return;
      }

      // S4-S6 are generated only from the central active regime.
      if(m_regime==TSP4_REGIME_GOLDEN)
      {
         if(h4.zone==-1)
            SetSignal(TSP4_SIGNAL_DEEP_N,TSP4_DIR_BUY,m_d1.barTime,30,
                      "GOLDEN regime + H4 Stoch < 20");
         else if(h4.zone==1)
            SetSignal(TSP4_SIGNAL_COUNTER_N,TSP4_DIR_SELL,m_d1.barTime,30,
                      "GOLDEN regime + H4 Stoch > 80");
         else
            SetSignal(TSP4_SIGNAL_NORMAL_N,TSP4_DIR_BUY,m_d1.barTime,30,
                      "GOLDEN regime + neutral H4 Stoch");
      }
      else if(m_regime==TSP4_REGIME_BLACK)
      {
         if(h4.zone==1)
            SetSignal(TSP4_SIGNAL_DEEP_N,TSP4_DIR_SELL,m_d1.barTime,30,
                      "BLACK regime + H4 Stoch > 80");
         else if(h4.zone==-1)
            SetSignal(TSP4_SIGNAL_COUNTER_N,TSP4_DIR_BUY,m_d1.barTime,30,
                      "BLACK regime + H4 Stoch < 20");
         else
            SetSignal(TSP4_SIGNAL_NORMAL_N,TSP4_DIR_SELL,m_d1.barTime,30,
                      "BLACK regime + neutral H4 Stoch");
      }
      else
      {
         ClearSignal("No active regime for S4-S6");
         return;
      }

      m_filterPass=true;
      m_signal.state=TSP4_STATE_FILTER_OK;
      m_reason=m_signal.reason+" | H4 K="+DoubleToString(h4.stochK,2)+
               " | regime="+TSP4_RegimeText(m_regime);
   }

   void OnLiveH4(STSP4_H4Snapshot &h4)
   {
      int previousZone = m_lastH4Zone;
      int previousType = m_signal.type;
      int previousDirection = m_signal.direction;

      OnNewH4(h4);

      bool changed =
         (h4.zone != previousZone ||
          m_signal.type != previousType ||
          m_signal.direction != previousDirection);

      if(changed)
      {
         Print("[TSP5][SIGNAL_ROUTE] regime=",TSP4_RegimeText(m_regime),
               " K=",DoubleToString(h4.stochK,2),
               " zone=",h4.zone,
               " oldSignal=",TSP4_SignalText(previousType),
               " oldDirection=",TSP4_DirectionText(previousDirection),
               " newSignal=",TSP4_SignalText(m_signal.type),
               " newDirection=",TSP4_DirectionText(m_signal.direction),
               " reason=",m_reason);

         Print("[TSP4][H4_SWITCH] K=",
               DoubleToString(h4.stochK, 2),
               " oldZone=",
               previousZone,
               " newZone=",
               h4.zone,
               " oldSignal=",
               TSP4_SignalText(previousType),
               " oldDirection=",
               TSP4_DirectionText(previousDirection),
               " newSignal=",
               TSP4_SignalText(m_signal.type),
               " newDirection=",
               TSP4_DirectionText(m_signal.direction));
      }

      m_lastH4Zone = h4.zone;
      m_lastH4SignalType = m_signal.type;
      m_lastH4Direction = m_signal.direction;
   }

   bool GetCurrent(STSP4_Signal &out){ out=m_signal; return(m_hasSignal); }
   void MarkExecuted(long key)
   {
      if(m_hasSignal && m_signal.key==key) m_signal.state=TSP4_STATE_EXECUTED;
   }
   void MarkFinished(long key)
   {
      if(m_hasSignal && m_signal.key==key) m_signal.state=TSP4_STATE_FINISHED;
   }
};

#endif
