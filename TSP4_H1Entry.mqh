#ifndef __TSP4_H1_ENTRY_MQH__
#define __TSP4_H1_ENTRY_MQH__

// TSP Infinity EA v5.4
// H1 SAR entry state machine.
//
// Core rules:
// 1. A new signal starts a new state machine.
// 2. SAR[1] is locked once, only when it is on the valid entry side.
// 3. The locked SAR[1] is never refreshed while the signal remains active.
// 4. A detected touch remains latched.
// 5. After the touch, the engine waits only for protective SAR[0] geometry.
// 6. BUY requires SAR[0] < locked SAR[1].
// 7. SELL requires SAR[0] > locked SAR[1].
// 8. Entry = locked SAR[1], SL = protective SAR[0].
// 9. Gap = absolute distance between locked SAR[1] and protective SAR[0].

enum ETSP54H1State
{
   TSP54_H1_IDLE = 0,
   TSP54_H1_WAIT_LOCK,
   TSP54_H1_WAIT_TOUCH,
   TSP54_H1_TOUCH_LATCHED,
   TSP54_H1_WAIT_PROTECTIVE_SAR0,
   TSP54_H1_ENTRY_READY,
   TSP54_H1_CONSUMED
};

class CTSP4H1Entry
{
private:
   int      m_lookback;
   int      m_tolerancePoints;
   string   m_reason;

   long     m_signalKey;
   int      m_direction;
   int      m_state;

   double   m_lockedSAR1;
   double   m_previousBid;
   double   m_previousAsk;

   datetime m_lockH1BarTime;
   datetime m_touchTime;

   bool     m_consumed;

   string StateText(const int state)
   {
      switch(state)
      {
         case TSP54_H1_IDLE:                 return("IDLE");
         case TSP54_H1_WAIT_LOCK:            return("WAIT_LOCK");
         case TSP54_H1_WAIT_TOUCH:           return("WAIT_TOUCH");
         case TSP54_H1_TOUCH_LATCHED:        return("TOUCH_LATCHED");
         case TSP54_H1_WAIT_PROTECTIVE_SAR0: return("WAIT_PROTECTIVE_SAR0");
         case TSP54_H1_ENTRY_READY:          return("ENTRY_READY");
         case TSP54_H1_CONSUMED:             return("CONSUMED");
      }

      return("UNKNOWN");
   }

   void SetState(const int newState, const string reason)
   {
      bool changed = (m_state != newState);

      m_state  = newState;
      m_reason = reason;

      if(changed)
      {
         Print("[TSP5.4][H1_STATE] key=", m_signalKey,
               " direction=", TSP4_DirectionText(m_direction),
               " state=", StateText(m_state),
               " reason=", m_reason);
      }
   }

   void ResetForSignal(const long signalKey,
                       const int direction,
                       const double currentBid,
                       const double currentAsk)
   {
      m_signalKey    = signalKey;
      m_direction    = direction;
      m_state        = TSP54_H1_WAIT_LOCK;
      m_lockedSAR1   = 0.0;
      m_previousBid  = currentBid;
      m_previousAsk  = currentAsk;
      m_lockH1BarTime = 0;
      m_touchTime    = 0;
      m_consumed     = false;

      m_reason = "New signal; waiting valid SAR[1] lock";

      Print("[TSP5.4][H1_RESET] key=", m_signalKey,
            " direction=", TSP4_DirectionText(m_direction),
            " Bid=", DoubleToString(currentBid, Digits),
            " Ask=", DoubleToString(currentAsk, Digits));
   }

   bool DirectionIsValid(const int direction)
   {
      return(direction == TSP4_DIR_BUY ||
             direction == TSP4_DIR_SELL);
   }

   bool CandidateSAR1OnEntrySide(const double sar1,
                                 const double currentBid,
                                 const double currentAsk)
   {
      if(m_direction == TSP4_DIR_BUY)
         return(sar1 < currentBid);

      if(m_direction == TSP4_DIR_SELL)
         return(sar1 > currentAsk);

      return(false);
   }

   bool LockSAR1(const string symbol,
                 CTSP4Indicators &ind,
                 const double currentBid,
                 const double currentAsk)
   {
      double candidateSAR1 = ind.Sar(symbol, PERIOD_H1, 1);

      if(candidateSAR1 <= 0.0)
      {
         SetState(TSP54_H1_WAIT_LOCK,
                  "Waiting valid H1 SAR[1]");
         return(false);
      }

      candidateSAR1 = NormalizeDouble(candidateSAR1, Digits);

      if(!CandidateSAR1OnEntrySide(candidateSAR1,
                                   currentBid,
                                   currentAsk))
      {
         SetState(
            TSP54_H1_WAIT_LOCK,
            "Waiting SAR[1] on entry side direction=" +
            TSP4_DirectionText(m_direction) +
            " SAR1=" + DoubleToString(candidateSAR1, Digits) +
            " Bid=" + DoubleToString(currentBid, Digits) +
            " Ask=" + DoubleToString(currentAsk, Digits)
         );
         return(false);
      }

      m_lockedSAR1    = candidateSAR1;
      m_lockH1BarTime = iTime(symbol, PERIOD_H1, 0);
      m_previousBid   = currentBid;
      m_previousAsk   = currentAsk;

      SetState(
         TSP54_H1_WAIT_TOUCH,
         "SAR[1] locked once at " +
         DoubleToString(m_lockedSAR1, Digits)
      );

      Print("[TSP5.4][SAR1_LOCKED] key=", m_signalKey,
            " direction=", TSP4_DirectionText(m_direction),
            " SAR1=", DoubleToString(m_lockedSAR1, Digits),
            " H1Bar=", TimeToString(m_lockH1BarTime,
                                    TIME_DATE|TIME_MINUTES),
            " Bid=", DoubleToString(currentBid, Digits),
            " Ask=", DoubleToString(currentAsk, Digits));

      return(true);
   }

   bool DetectTouch(const double currentBid,
                    const double currentAsk)
   {
      double tolerance =
         MathMax(1, m_tolerancePoints) * Point;

      bool touched = false;

      if(m_direction == TSP4_DIR_BUY)
      {
         touched =
            (m_previousBid > m_lockedSAR1 + tolerance &&
             currentBid <= m_lockedSAR1 + tolerance);
      }
      else if(m_direction == TSP4_DIR_SELL)
      {
         touched =
            (m_previousAsk < m_lockedSAR1 - tolerance &&
             currentAsk >= m_lockedSAR1 - tolerance);
      }

      m_previousBid = currentBid;
      m_previousAsk = currentAsk;

      if(!touched)
      {
         SetState(
            TSP54_H1_WAIT_TOUCH,
            "Waiting locked SAR[1] touch direction=" +
            TSP4_DirectionText(m_direction) +
            " LockedSAR1=" +
            DoubleToString(m_lockedSAR1, Digits) +
            " Bid=" + DoubleToString(currentBid, Digits) +
            " Ask=" + DoubleToString(currentAsk, Digits)
         );
         return(false);
      }

      m_touchTime = TimeCurrent();

      SetState(
         TSP54_H1_TOUCH_LATCHED,
         "SAR[1] touch latched at " +
         DoubleToString(m_lockedSAR1, Digits)
      );

      Print("[TSP5.4][SAR1_TOUCH_LATCHED] key=", m_signalKey,
            " direction=", TSP4_DirectionText(m_direction),
            " SAR1=", DoubleToString(m_lockedSAR1, Digits),
            " Bid=", DoubleToString(currentBid, Digits),
            " Ask=", DoubleToString(currentAsk, Digits),
            " Time=", TimeToString(m_touchTime,
                                   TIME_DATE|TIME_SECONDS));

      return(true);
   }

   bool ProtectiveSAR0Ready(const string symbol,
                            CTSP4Indicators &ind,
                            double &sar0,
                            double &gap)
   {
      sar0 = ind.Sar(symbol, PERIOD_H1, 0);

      if(sar0 <= 0.0)
      {
         SetState(TSP54_H1_WAIT_PROTECTIVE_SAR0,
                  "Touch latched; waiting valid protective SAR[0]");
         return(false);
      }

      sar0 = NormalizeDouble(sar0, Digits);

      bool geometryOk = false;

      // Protective reversal geometry:
      // BUY  -> current SAR[0] must be below locked SAR[1].
      // SELL -> current SAR[0] must be above locked SAR[1].
      if(m_direction == TSP4_DIR_BUY)
         geometryOk = (sar0 < m_lockedSAR1);

      if(m_direction == TSP4_DIR_SELL)
         geometryOk = (sar0 > m_lockedSAR1);

      if(!geometryOk)
      {
         SetState(
            TSP54_H1_WAIT_PROTECTIVE_SAR0,
            "Touch latched; waiting protective SAR[0] flip direction=" +
            TSP4_DirectionText(m_direction) +
            " LockedSAR1=" +
            DoubleToString(m_lockedSAR1, Digits) +
            " SAR0=" + DoubleToString(sar0, Digits)
         );
         return(false);
      }

      gap = MathAbs(m_lockedSAR1 - sar0);
      gap = NormalizeDouble(gap, Digits);

      if(gap <= Point)
      {
         SetState(
            TSP54_H1_WAIT_PROTECTIVE_SAR0,
            "Invalid SAR reversal gap; waiting direction=" +
            TSP4_DirectionText(m_direction) +
            " LockedSAR1=" +
            DoubleToString(m_lockedSAR1, Digits) +
            " SAR0=" + DoubleToString(sar0, Digits) +
            " Gap=" + DoubleToString(gap, Digits)
         );
         return(false);
      }

      return(true);
   }

   void FillPlan(const string symbol,
                 STSP4_Signal &signal,
                 const double entry,
                 const double stop,
                 const double gap,
                 STSP4_TradePlan &plan)
   {
      plan.symbol      = symbol;
      plan.signalKey   = signal.key;
      plan.signalType  = signal.type;
      plan.direction   = signal.direction;
      plan.entry       = NormalizeDouble(entry, Digits);
      plan.stopLoss    = NormalizeDouble(stop, Digits);
      plan.gap         = NormalizeDouble(gap, Digits);
      plan.tp3         = 0.0;
      plan.commentBase = "TSP4 S" + IntegerToString(signal.type);

      if(signal.direction == TSP4_DIR_BUY)
      {
         plan.tp1 =
            NormalizeDouble(plan.entry + 0.50 * plan.gap, Digits);
         plan.tp2 =
            NormalizeDouble(plan.entry + 1.00 * plan.gap, Digits);
      }
      else
      {
         plan.tp1 =
            NormalizeDouble(plan.entry - 0.50 * plan.gap, Digits);
         plan.tp2 =
            NormalizeDouble(plan.entry - 1.00 * plan.gap, Digits);
      }
   }

public:
   void Init(const int lookback,
             const int tolerancePoints)
   {
      m_lookback         = lookback;
      m_tolerancePoints  = MathMax(1, tolerancePoints);
      m_reason           = "";
      m_signalKey        = 0;
      m_direction        = TSP4_DIR_NONE;
      m_state            = TSP54_H1_IDLE;
      m_lockedSAR1       = 0.0;
      m_previousBid      = 0.0;
      m_previousAsk      = 0.0;
      m_lockH1BarTime    = 0;
      m_touchTime        = 0;
      m_consumed         = false;
   }

   string LastReason()
   {
      return(m_reason);
   }

   string StateName()
   {
      return(StateText(m_state));
   }

   int State()
   {
      return(m_state);
   }

   double LockedSAR1()
   {
      return(m_lockedSAR1);
   }

   bool TouchLatched()
   {
      return(m_state == TSP54_H1_TOUCH_LATCHED ||
             m_state == TSP54_H1_WAIT_PROTECTIVE_SAR0 ||
             m_state == TSP54_H1_ENTRY_READY ||
             m_state == TSP54_H1_CONSUMED);
   }

   void MarkConsumed(const long key)
   {
      if(m_signalKey != key)
         return;

      m_consumed = true;

      SetState(TSP54_H1_CONSUMED,
               "Signal entry consumed");

      Print("[TSP5.4][H1_CONSUMED] key=", m_signalKey,
            " direction=", TSP4_DirectionText(m_direction),
            " LockedSAR1=",
            DoubleToString(m_lockedSAR1, Digits));
   }

   bool BuildPlanOnTouch(const string symbol,
                         STSP4_Signal &signal,
                         CTSP4Indicators &ind,
                         STSP4_TradePlan &plan)
   {
      if(signal.key <= 0)
      {
         m_reason = "Invalid signal key";
         return(false);
      }

      if(!DirectionIsValid(signal.direction))
      {
         m_reason = "Invalid signal direction";
         return(false);
      }

      RefreshRates();

      double currentBid = Bid;
      double currentAsk = Ask;

      if(currentBid <= 0.0 || currentAsk <= 0.0)
      {
         m_reason = "Invalid Bid/Ask";
         return(false);
      }

      // A changed key or direction creates a completely new machine.
      if(m_signalKey != signal.key ||
         m_direction != signal.direction)
      {
         ResetForSignal(signal.key,
                        signal.direction,
                        currentBid,
                        currentAsk);
      }

      if(m_consumed ||
         m_state == TSP54_H1_CONSUMED)
      {
         m_reason = "Signal entry already consumed";
         return(false);
      }

      // Lock once. Never overwrite m_lockedSAR1 for this signal.
      if(m_state == TSP54_H1_WAIT_LOCK)
      {
         if(!LockSAR1(symbol,
                      ind,
                      currentBid,
                      currentAsk))
         {
            return(false);
         }

         // Touch detection starts from the next tick after locking.
         return(false);
      }

      if(m_state == TSP54_H1_WAIT_TOUCH)
      {
         if(!DetectTouch(currentBid,
                         currentAsk))
         {
            return(false);
         }
      }

      // TOUCH_LATCHED intentionally falls through on the same tick.
      if(m_state == TSP54_H1_TOUCH_LATCHED)
      {
         SetState(TSP54_H1_WAIT_PROTECTIVE_SAR0,
                  "Touch latched; checking protective SAR[0]");
      }

      if(m_state == TSP54_H1_WAIT_PROTECTIVE_SAR0)
      {
         double sar0 = 0.0;
         double gap  = 0.0;

         if(!ProtectiveSAR0Ready(symbol,
                                 ind,
                                 sar0,
                                 gap))
         {
            return(false);
         }

         FillPlan(symbol,
                  signal,
                  m_lockedSAR1,
                  sar0,
                  gap,
                  plan);

         SetState(
            TSP54_H1_ENTRY_READY,
            "Entry ready Entry=" +
            DoubleToString(plan.entry, Digits) +
            " SL=" + DoubleToString(plan.stopLoss, Digits) +
            " Gap=" + DoubleToString(plan.gap, Digits)
         );

         Print("[TSP5.4][H1_ENTRY_READY] key=", signal.key,
               " direction=",
               TSP4_DirectionText(signal.direction),
               " Entry=", DoubleToString(plan.entry, Digits),
               " SL=", DoubleToString(plan.stopLoss, Digits),
               " TP1=", DoubleToString(plan.tp1, Digits),
               " TP2=", DoubleToString(plan.tp2, Digits),
               " Gap=", DoubleToString(plan.gap, Digits));

         return(true);
      }

      if(m_state == TSP54_H1_ENTRY_READY)
      {
         // Rebuild the same deterministic plan until the caller confirms
         // successful execution through MarkConsumed().
         double sar0 = ind.Sar(symbol, PERIOD_H1, 0);

         if(sar0 <= 0.0)
         {
            m_reason =
               "Entry ready but protective SAR[0] is unavailable";
            return(false);
         }

         sar0 = NormalizeDouble(sar0, Digits);

         bool geometryOk = false;

         if(m_direction == TSP4_DIR_BUY)
            geometryOk = (sar0 < m_lockedSAR1);

         if(m_direction == TSP4_DIR_SELL)
            geometryOk = (sar0 > m_lockedSAR1);

         if(!geometryOk)
         {
            SetState(
               TSP54_H1_WAIT_PROTECTIVE_SAR0,
               "Entry geometry changed; waiting protective SAR[0]"
            );
            return(false);
         }

         double gap =
            NormalizeDouble(MathAbs(m_lockedSAR1 - sar0),
                            Digits);

         if(gap <= Point)
         {
            SetState(
               TSP54_H1_WAIT_PROTECTIVE_SAR0,
               "Entry gap became invalid; waiting protective SAR[0]"
            );
            return(false);
         }

         FillPlan(symbol,
                  signal,
                  m_lockedSAR1,
                  sar0,
                  gap,
                  plan);

         m_reason =
            "Entry ready; waiting order execution confirmation";

         return(true);
      }

      m_reason =
         "H1 state not ready: " + StateText(m_state);

      return(false);
   }
};

#endif
