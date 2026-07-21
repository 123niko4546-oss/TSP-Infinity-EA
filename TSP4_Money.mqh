#ifndef __TSP4_MONEY_MQH__
#define __TSP4_MONEY_MQH__

class CTSP4Money
{
private:
   double m_riskPercent;
   bool m_useEquity;
   string m_reason;

   double NormalizeLots(string symbol, double lots)
   {
      double minLot = MarketInfo(symbol, MODE_MINLOT);
      double maxLot = MarketInfo(symbol, MODE_MAXLOT);
      double lotStep = MarketInfo(symbol, MODE_LOTSTEP);

      if(lotStep <= 0.0)
         lotStep = 0.01;

      lots = MathFloor(lots / lotStep) * lotStep;
      lots = MathMax(minLot, MathMin(maxLot, lots));

      int digits = 2;
      if(lotStep >= 1.0) digits = 0;
      else if(lotStep >= 0.1) digits = 1;
      else if(lotStep >= 0.01) digits = 2;
      else digits = 3;

      return(NormalizeDouble(lots, digits));
   }

public:
   void Init(double riskPercent, bool useEquity)
   {
      m_riskPercent = riskPercent;
      m_useEquity = useEquity;
      m_reason = "";
   }

   string LastReason()
   {
      return(m_reason);
   }

   bool ApplyEqualLots(string symbol,
                       STSP4_TradePlan &plan)
   {
      double capital =
         (m_useEquity ?
          AccountEquity() :
          AccountBalance());

      double totalRiskMoney =
         capital * m_riskPercent / 100.0;

      double eachTradeRisk =
         totalRiskMoney / 3.0;

      double distance =
         MathAbs(plan.entry - plan.stopLoss);

      double tickValue =
         MarketInfo(symbol, MODE_TICKVALUE);

      double tickSize =
         MarketInfo(symbol, MODE_TICKSIZE);

      if(distance <= 0.0 ||
         tickValue <= 0.0 ||
         tickSize <= 0.0)
      {
         m_reason = "Invalid lot calculation inputs";
         return(false);
      }

      double moneyPerLot =
         (distance / tickSize) * tickValue;

      if(moneyPerLot <= 0.0)
      {
         m_reason = "moneyPerLot <= 0";
         return(false);
      }

      double lot =
         NormalizeLots(symbol,
                       eachTradeRisk / moneyPerLot);

      if(lot <= 0.0)
      {
         m_reason = "Calculated lot <= 0";
         return(false);
      }

      plan.lot1 = lot;
      plan.lot2 = lot;
      plan.lot3 = lot;

      m_reason =
         "Equal lots " +
         DoubleToString(lot, 2);

      return(true);
   }
};

#endif
