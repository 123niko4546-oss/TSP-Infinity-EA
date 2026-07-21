#ifndef __TSP4_INDICATORS_MQH__
#define __TSP4_INDICATORS_MQH__

class CTSP4Indicators
{
private:
   string m_macdName;
   int m_fast;
   int m_slow;
   int m_signal;
   int m_histBuffer;
   int m_stochK;
   int m_stochD;
   int m_stochSlowing;
   int m_stochPriceField;
   double m_sarStep;
   double m_sarMax;

public:
   void Init(string macdName,
             int fast,
             int slow,
             int signal,
             int histBuffer,
             int stochK,
             int stochD,
             int stochSlowing,
             int stochPriceField,
             double sarStep,
             double sarMax)
   {
      m_macdName = macdName;
      m_fast = fast;
      m_slow = slow;
      m_signal = signal;
      m_histBuffer = histBuffer;
      m_stochK = stochK;
      m_stochD = stochD;
      m_stochSlowing = stochSlowing;
      m_stochPriceField = stochPriceField;
      m_sarStep = sarStep;
      m_sarMax = sarMax;
   }

   double Hist(string symbol, int timeframe, int shift)
   {
      // MACD-2 does NOT expose the complete histogram in one buffer.
      // Buffer 0 contains only rising/green histogram bars.
      // Buffer 1 contains only falling/red histogram bars.
      // Buffer 2 is the raw MACD line and buffer 3 is its signal line.
      // The true histogram used for Golden/Black zero crossings is:
      // raw MACD - signal line.
      double rawMacd = iCustom(symbol,
                               timeframe,
                               m_macdName,
                               m_fast,
                               m_slow,
                               m_signal,
                               2,
                               shift);

      double signalLine = iCustom(symbol,
                                  timeframe,
                                  m_macdName,
                                  m_fast,
                                  m_slow,
                                  m_signal,
                                  3,
                                  shift);

      if(rawMacd == EMPTY_VALUE || signalLine == EMPTY_VALUE)
         return(0.0);

      return(rawMacd - signalLine);
   }

   bool Rising(string symbol, int timeframe, int shift)
   {
      return(Hist(symbol, timeframe, shift) >
             Hist(symbol, timeframe, shift + 1));
   }

   bool Falling(string symbol, int timeframe, int shift)
   {
      return(Hist(symbol, timeframe, shift) <
             Hist(symbol, timeframe, shift + 1));
   }

   bool TwoRising(string symbol, int timeframe, int shift)
   {
      return(Rising(symbol, timeframe, shift) &&
             Rising(symbol, timeframe, shift + 1));
   }

   bool TwoFalling(string symbol, int timeframe, int shift)
   {
      return(Falling(symbol, timeframe, shift) &&
             Falling(symbol, timeframe, shift + 1));
   }

   double StochK(string symbol, int timeframe, int shift)
   {
      return(iStochastic(symbol,
                         timeframe,
                         m_stochK,
                         m_stochD,
                         m_stochSlowing,
                         MODE_SMA,
                         m_stochPriceField,
                         MODE_MAIN,
                         shift));
   }

   double Sar(string symbol, int timeframe, int shift)
   {
      return(iSAR(symbol,
                  timeframe,
                  m_sarStep,
                  m_sarMax,
                  shift));
   }
};

#endif
