#ifndef __TSP4_DEEP_DIAGNOSTICS_MQH__
#define __TSP4_DEEP_DIAGNOSTICS_MQH__

class CTSP4DeepDiagnostics
{
private:
   bool     m_enabled;
   int      m_throttleSeconds;
   datetime m_lastPrint;

   string m_macdName;
   int    m_macdFast;
   int    m_macdSlow;
   int    m_macdSignal;

   int    m_stochK;
   int    m_stochD;
   int    m_stochSlowing;
   int    m_stochPriceField;
   double m_overbought;
   double m_oversold;

   double m_sarStep;
   double m_sarMaximum;

   string ZoneText(double k)
   {
      if(k < m_oversold)   return("OVERSOLD");
      if(k > m_overbought) return("OVERBOUGHT");
      return("NEUTRAL");
   }

public:
   void Init(bool enabled,
             int throttleSeconds,
             string macdName,
             int macdFast,
             int macdSlow,
             int macdSignal,
             int stochK,
             int stochD,
             int stochSlowing,
             int stochPriceField,
             double overbought,
             double oversold,
             double sarStep,
             double sarMaximum)
   {
      m_enabled = enabled;
      m_throttleSeconds = MathMax(1, throttleSeconds);
      m_lastPrint = 0;

      m_macdName = macdName;
      m_macdFast = macdFast;
      m_macdSlow = macdSlow;
      m_macdSignal = macdSignal;

      m_stochK = stochK;
      m_stochD = stochD;
      m_stochSlowing = stochSlowing;
      m_stochPriceField = stochPriceField;
      m_overbought = overbought;
      m_oversold = oversold;

      m_sarStep = sarStep;
      m_sarMaximum = sarMaximum;
   }

   void Snapshot(string symbol, CTSP4Indicators &ind)
   {
      if(!m_enabled)
         return;

      datetime now = TimeCurrent();
      if(m_lastPrint > 0 && now - m_lastPrint < m_throttleSeconds)
         return;

      m_lastPrint = now;

      // Direct MACD2 reads. Buffers 2 and 3 are also printed separately
      // so we can verify whether histogram = raw - signal is correct.
      double macdRaw0 =
         iCustom(symbol, PERIOD_D1, m_macdName,
                 m_macdFast, m_macdSlow, m_macdSignal,
                 2, 0);

      double macdRaw1 =
         iCustom(symbol, PERIOD_D1, m_macdName,
                 m_macdFast, m_macdSlow, m_macdSignal,
                 2, 1);

      double macdSignal0 =
         iCustom(symbol, PERIOD_D1, m_macdName,
                 m_macdFast, m_macdSlow, m_macdSignal,
                 3, 0);

      double macdSignal1 =
         iCustom(symbol, PERIOD_D1, m_macdName,
                 m_macdFast, m_macdSlow, m_macdSignal,
                 3, 1);

      double hist0 = macdRaw0 - macdSignal0;
      double hist1 = macdRaw1 - macdSignal1;

      bool golden =
         (hist1 <= 0.0 && hist0 > 0.0);

      bool black =
         (hist1 >= 0.0 && hist0 < 0.0);

      // Direct H4 Stochastic reads.
      double stochMain0 =
         iStochastic(symbol, PERIOD_H4,
                     m_stochK, m_stochD, m_stochSlowing,
                     MODE_SMA, m_stochPriceField, MODE_MAIN, 0);

      double stochSignal0 =
         iStochastic(symbol, PERIOD_H4,
                     m_stochK, m_stochD, m_stochSlowing,
                     MODE_SMA, m_stochPriceField, MODE_SIGNAL, 0);

      double stochMain1 =
         iStochastic(symbol, PERIOD_H4,
                     m_stochK, m_stochD, m_stochSlowing,
                     MODE_SMA, m_stochPriceField, MODE_MAIN, 1);

      double stochSignal1 =
         iStochastic(symbol, PERIOD_H4,
                     m_stochK, m_stochD, m_stochSlowing,
                     MODE_SMA, m_stochPriceField, MODE_SIGNAL, 1);

      // H1 SAR telemetry.
      double sar0 =
         iSAR(symbol, PERIOD_H1, m_sarStep, m_sarMaximum, 0);

      double sar1 =
         iSAR(symbol, PERIOD_H1, m_sarStep, m_sarMaximum, 1);

      Print("[TSP4][DIAG][D1] time0=",
            TimeToString(iTime(symbol, PERIOD_D1, 0), TIME_DATE|TIME_MINUTES),
            " raw0=", DoubleToString(macdRaw0, 6),
            " sig0=", DoubleToString(macdSignal0, 6),
            " hist0=", DoubleToString(hist0, 6),
            " raw1=", DoubleToString(macdRaw1, 6),
            " sig1=", DoubleToString(macdSignal1, 6),
            " hist1=", DoubleToString(hist1, 6),
            " golden=", golden,
            " black=", black);

      Print("[TSP4][DIAG][H4] time0=",
            TimeToString(iTime(symbol, PERIOD_H4, 0), TIME_DATE|TIME_MINUTES),
            " params=",
            IntegerToString(m_stochK), ",",
            IntegerToString(m_stochD), ",",
            IntegerToString(m_stochSlowing),
            " priceField=",
            IntegerToString(m_stochPriceField),
            " main0=", DoubleToString(stochMain0, 2),
            " signal0=", DoubleToString(stochSignal0, 2),
            " zone0=", ZoneText(stochMain0),
            " main1=", DoubleToString(stochMain1, 2),
            " signal1=", DoubleToString(stochSignal1, 2),
            " zone1=", ZoneText(stochMain1));

      Print("[TSP4][DIAG][H1] time0=",
            TimeToString(iTime(symbol, PERIOD_H1, 0), TIME_DATE|TIME_MINUTES),
            " Bid=", DoubleToString(Bid, Digits),
            " Ask=", DoubleToString(Ask, Digits),
            " SAR0=", DoubleToString(sar0, Digits),
            " SAR1=", DoubleToString(sar1, Digits),
            " High0=", DoubleToString(iHigh(symbol, PERIOD_H1, 0), Digits),
            " Low0=", DoubleToString(iLow(symbol, PERIOD_H1, 0), Digits));
   }
};

#endif
