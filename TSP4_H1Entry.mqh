#ifndef __TSP4_H1_ENTRY_MQH__
#define __TSP4_H1_ENTRY_MQH__

class CTSP4H1Entry
{
private:
   int    m_lookback;
   int    m_tolerancePoints;
   string m_reason;

   long   m_signalKey;
   int    m_direction;
   double m_lockedSAR1;
   double m_previousBid;
   double m_previousAsk;
   bool   m_armed;
   bool   m_touchDetected;
   bool   m_consumed;

   void ResetForSignal(long signalKey,
                       int direction,
                       double currentBid,
                       double currentAsk)
   {
      m_signalKey = signalKey;
      m_direction = direction;
      m_lockedSAR1 = 0.0;
      m_previousBid = currentBid;
      m_previousAsk = currentAsk;
      m_armed = false;
      m_touchDetected = false;
      m_consumed = false;

      Print("[TSP5][H1_TRACKER_RESET] key=",m_signalKey,
            " direction=",TSP4_DirectionText(m_direction),
            " Bid=",DoubleToString(currentBid,Digits),
            " Ask=",DoubleToString(currentAsk,Digits));
   }

   void ArmLevel(double sar1,
                 double currentBid,
                 double currentAsk)
   {
      // The exact penultimate point is locked once and is never moved
      // while the same signal remains active.
      m_lockedSAR1 = NormalizeDouble(sar1, Digits);
      m_previousBid = currentBid;
      m_previousAsk = currentAsk;
      m_armed = true;
      m_touchDetected = false;

      Print("[TSP4][SAR1_LOCK] key=", m_signalKey,
            " direction=", TSP4_DirectionText(m_direction),
            " lockedSAR1=", DoubleToString(m_lockedSAR1, Digits),
            " Bid=", DoubleToString(currentBid, Digits),
            " Ask=", DoubleToString(currentAsk, Digits));
   }

   void FillPlan(string symbol,
                 STSP4_Signal &signal,
                 double entry,
                 double stop,
                 double gap,
                 STSP4_TradePlan &plan)
   {
      plan.symbol = symbol;
      plan.signalKey = signal.key;
      plan.signalType = signal.type;
      plan.direction = signal.direction;
      plan.entry = NormalizeDouble(entry, Digits);
      plan.stopLoss = NormalizeDouble(stop, Digits);
      plan.gap = NormalizeDouble(gap, Digits);
      plan.tp3 = 0.0;
      plan.commentBase = "TSP4 S" + IntegerToString(signal.type);

      if(signal.direction == TSP4_DIR_BUY)
      {
         plan.tp1 = NormalizeDouble(plan.entry + 0.50 * plan.gap, Digits);
         plan.tp2 = NormalizeDouble(plan.entry + 1.00 * plan.gap, Digits);
      }
      else
      {
         plan.tp1 = NormalizeDouble(plan.entry - 0.50 * plan.gap, Digits);
         plan.tp2 = NormalizeDouble(plan.entry - 1.00 * plan.gap, Digits);
      }
   }

public:
   void Init(int lookback, int tolerancePoints)
   {
      m_lookback = lookback;
      m_tolerancePoints = MathMax(1, tolerancePoints);
      m_reason = "";
      m_signalKey = 0;
      m_direction = TSP4_DIR_NONE;
      m_lockedSAR1 = 0.0;
      m_previousBid = 0.0;
      m_previousAsk = 0.0;
      m_armed = false;
      m_touchDetected = false;
      m_consumed = false;
   }

   string LastReason()
   {
      return(m_reason);
   }

   void MarkConsumed(long key)
   {
      if(m_signalKey == key)
         m_consumed = true;
   }

   bool BuildPlanOnTouch(string symbol,
                         STSP4_Signal &signal,
                         CTSP4Indicators &ind,
                         STSP4_TradePlan &plan)
   {
      if(signal.key <= 0)
      {
         m_reason = "Invalid signal key";
         return(false);
      }

      RefreshRates();

      double currentBid = Bid;
      double currentAsk = Ask;

      // A new signal starts a completely new tracker.
      if(m_signalKey != signal.key ||
         m_direction != signal.direction)
      {
         ResetForSignal(signal.key,
                        signal.direction,
                        currentBid,
                        currentAsk);
      }

      if(m_consumed)
      {
         m_reason = "Signal entry already consumed";
         return(false);
      }

      // Until armed, inspect the current penultimate H1 SAR point.
      // Once armed, the selected SAR[1] is locked and never replaced
      // by later SAR points for this signal.
      if(!m_armed)
      {
         double candidateSAR1 = ind.Sar(symbol, PERIOD_H1, 1);

         if(candidateSAR1 <= 0.0)
         {
            m_reason = "Invalid H1 SAR[1]";
            return(false);
         }

         bool correctSide = false;

         // BUY: the penultimate SAR point must be below price.
         // Price approaches it from above.
         if(signal.direction == TSP4_DIR_BUY)
            correctSide = (candidateSAR1 < currentBid);

         // SELL: the penultimate SAR point must be above price.
         // Price approaches it from below.
         if(signal.direction == TSP4_DIR_SELL)
            correctSide = (candidateSAR1 > currentAsk);

         if(!correctSide)
         {
            m_reason =
               "Waiting SAR[1] on entry side direction=" +
               TSP4_DirectionText(signal.direction) +
               " SAR1=" + DoubleToString(candidateSAR1, Digits) +
               " Bid=" + DoubleToString(currentBid, Digits) +
               " Ask=" + DoubleToString(currentAsk, Digits);
            return(false);
         }

         ArmLevel(candidateSAR1,
                  currentBid,
                  currentAsk);

         m_reason =
            "Locked penultimate SAR[1]=" +
            DoubleToString(m_lockedSAR1, Digits) +
            " direction=" +
            TSP4_DirectionText(signal.direction);

         return(false);
      }

      // Detect the first crossing of the LOCKED penultimate SAR point.
      if(!m_touchDetected)
      {
         if(signal.direction == TSP4_DIR_BUY)
         {
            // BUY SAR is below price: detect the first downward touch.
            m_touchDetected =
               (m_previousBid > m_lockedSAR1 &&
                currentBid <= m_lockedSAR1);
         }

         if(signal.direction == TSP4_DIR_SELL)
         {
            // SELL SAR is above price: detect the first upward touch.
            m_touchDetected =
               (m_previousAsk < m_lockedSAR1 &&
                currentAsk >= m_lockedSAR1);
         }

         m_previousBid = currentBid;
         m_previousAsk = currentAsk;

         if(!m_touchDetected)
         {
            m_reason =
               "Waiting locked SAR[1] touch direction=" +
               TSP4_DirectionText(signal.direction) +
               " LockedSAR1=" + DoubleToString(m_lockedSAR1, Digits) +
               " Bid=" + DoubleToString(currentBid, Digits) +
               " Ask=" + DoubleToString(currentAsk, Digits);
            return(false);
         }

         Print("[TSP4][SAR1_TOUCH] key=", signal.key,
               " direction=", TSP4_DirectionText(signal.direction),
               " lockedSAR1=", DoubleToString(m_lockedSAR1, Digits),
               " Bid=", DoubleToString(currentBid, Digits),
               " Ask=", DoubleToString(currentAsk, Digits));
      }

      // Final H1 direction confirmation. A BUY is valid only while the
      // current SAR[0] is below price; a SELL only while SAR[0] is above price.
      // The touch remains latched, so the order is not lost while waiting for
      // valid protective geometry.
      double sar0 = ind.Sar(symbol, PERIOD_H1, 0);

      if(sar0 <= 0.0)
      {
         m_reason = "Touch latched; waiting valid H1 SAR[0]";
         return(false);
      }

      bool sarDirectionOk = false;

      if(signal.direction == TSP4_DIR_BUY)
         sarDirectionOk = (sar0 < currentBid);

      if(signal.direction == TSP4_DIR_SELL)
         sarDirectionOk = (sar0 > currentAsk);

      if(!sarDirectionOk)
      {
         m_reason =
            "Touch latched; H1 SAR direction blocked direction=" +
            TSP4_DirectionText(signal.direction) +
            " SAR0=" + DoubleToString(sar0, Digits) +
            " Bid=" + DoubleToString(currentBid, Digits) +
            " Ask=" + DoubleToString(currentAsk, Digits);

         Print("[TSP5][H1_SAR_DIRECTION_BLOCK] key=", signal.key,
               " direction=", TSP4_DirectionText(signal.direction),
               " SAR0=", DoubleToString(sar0, Digits),
               " Bid=", DoubleToString(currentBid, Digits),
               " Ask=", DoubleToString(currentAsk, Digits));
         return(false);
      }

      // Build the initial protective geometry from the valid current SAR[0].

      double brokerMinGap =
         (MarketInfo(symbol, MODE_STOPLEVEL) + 2.0) * Point;

      if(brokerMinGap < Point * 2.0)
         brokerMinGap = Point * 2.0;

      double gap = 0.0;

      if(sar0 > 0.0)
         gap = MathAbs(m_lockedSAR1 - sar0);

      if(gap < brokerMinGap)
         gap = brokerMinGap;

      gap = NormalizeDouble(gap, Digits);

      double stop = 0.0;

      if(signal.direction == TSP4_DIR_BUY)
         stop = NormalizeDouble(m_lockedSAR1 - gap, Digits);

      if(signal.direction == TSP4_DIR_SELL)
         stop = NormalizeDouble(m_lockedSAR1 + gap, Digits);

      if(stop <= 0.0 || gap <= Point)
      {
         m_reason = "Invalid immediate-entry emergency SL geometry";
         return(false);
      }

      Print("[TSP4][INITIAL_EMERGENCY_SL] key=", signal.key,
            " direction=", TSP4_DirectionText(signal.direction),
            " Entry=", DoubleToString(m_lockedSAR1, Digits),
            " SAR0=", DoubleToString(sar0, Digits),
            " EmergencySL=", DoubleToString(stop, Digits),
            " Gap=", DoubleToString(gap, Digits));

      FillPlan(symbol,
               signal,
               m_lockedSAR1,
               stop,
               gap,
               plan);

      m_reason =
         "Immediate locked SAR[1] touch entry ready Entry=" +
         DoubleToString(plan.entry, Digits) +
         " SL=" + DoubleToString(plan.stopLoss, Digits) +
         " Gap=" + DoubleToString(plan.gap, Digits);

      Print("[TSP4][SAR1_IMMEDIATE_ENTRY_READY] key=", signal.key,
            " direction=", TSP4_DirectionText(signal.direction),
            " Entry=", DoubleToString(plan.entry, Digits),
            " SL=", DoubleToString(plan.stopLoss, Digits),
            " Gap=", DoubleToString(plan.gap, Digits));

      return(true);
   }
};

#endif
