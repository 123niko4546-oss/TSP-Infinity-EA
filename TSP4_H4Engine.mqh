#ifndef __TSP4_H4_ENGINE_MQH__
#define __TSP4_H4_ENGINE_MQH__

class CTSP4H4Engine
{
private:
   double m_overbought;
   double m_oversold;

public:
   void Init(double overbought, double oversold)
   {
      m_overbought = overbought;
      m_oversold = oversold;
   }

   void Evaluate(string symbol,
                 CTSP4Indicators &ind,
                 STSP4_H4Snapshot &out)
   {
      out.barTime = iTime(symbol, PERIOD_H4, 0);
      out.stochK = ind.StochK(symbol, PERIOD_H4, 0);

      if(out.stochK >= m_overbought)
         out.zone = 1;
      else if(out.stochK <= m_oversold)
         out.zone = -1;
      else
         out.zone = 0;

      string zoneText = "NEUTRAL";
      if(out.zone == 1)  zoneText = "OVERBOUGHT";
      if(out.zone == -1) zoneText = "OVERSOLD";

      out.reason =
         "H4 Stochastic K=" +
         DoubleToString(out.stochK, 2) +
         " zone=" +
         zoneText;
   }
};

#endif
