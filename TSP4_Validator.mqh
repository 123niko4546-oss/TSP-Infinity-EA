#ifndef __TSP4_VALIDATOR_MQH__
#define __TSP4_VALIDATOR_MQH__

class CTSP4Validator
{
private:
   string m_reason;

public:
   void Init()
   {
      m_reason = "";
   }

   string LastReason()
   {
      return(m_reason);
   }

   bool ValidateSignal(STSP4_Signal &signal)
   {
      if(signal.key <= 0)
      {
         m_reason = "Invalid signal key";
         return(false);
      }

      if(signal.type < TSP4_SIGNAL_CONFIRMED_DIV ||
         signal.type > TSP4_SIGNAL_COUNTER_N)
      {
         m_reason = "Unknown signal type";
         return(false);
      }

      if(signal.direction != TSP4_DIR_BUY &&
         signal.direction != TSP4_DIR_SELL)
      {
         m_reason = "Invalid signal direction";
         return(false);
      }

      if(signal.validUntil > 0 &&
         TimeCurrent() > signal.validUntil)
      {
         m_reason = "Signal expired";
         return(false);
      }

      m_reason = "Signal valid";
      return(true);
   }

   bool ValidatePlan(STSP4_TradePlan &plan)
   {
      if(plan.entry <= 0.0 ||
         plan.stopLoss <= 0.0 ||
         plan.gap <= Point)
      {
         m_reason = "Invalid plan prices";
         return(false);
      }

      if(plan.direction == TSP4_DIR_BUY)
      {
         if(!(plan.stopLoss < plan.entry &&
              plan.tp1 > plan.entry &&
              plan.tp2 > plan.tp1))
         {
            m_reason = "Invalid BUY plan geometry";
            return(false);
         }
      }
      else if(plan.direction == TSP4_DIR_SELL)
      {
         if(!(plan.stopLoss > plan.entry &&
              plan.tp1 < plan.entry &&
              plan.tp2 < plan.tp1))
         {
            m_reason = "Invalid SELL plan geometry";
            return(false);
         }
      }
      else
      {
         m_reason = "Invalid plan direction";
         return(false);
      }

      m_reason = "Plan valid";
      return(true);
   }
};

#endif
