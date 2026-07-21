#ifndef __TSP4_PANEL_MQH__
#define __TSP4_PANEL_MQH__

class CTSP4Panel
{
public:
   void Init()
   {
   }

   void Render(STSP4_Signal &signal,
               string stage,
               string signalReason,
               string entryReason,
               string tradeReason)
   {
      string text =
         "TSP Infinity EA v" +
         TSP_VERSION +
         "\n" +
         "Symbol: " +
         Symbol() +
         "\n" +
         "Signal: " +
         TSP4_SignalText(signal.type) +
         " " +
         TSP4_DirectionText(signal.direction) +
         "\n" +
         "Core: Central D1 Regime Engine\n" +
         "Stage: " +
         stage +
         "\n" +
         "Signal: " +
         signalReason +
         "\n" +
         "Entry: " +
         entryReason +
         "\n" +
         "Trade: " +
         tradeReason +
         "\n" +
         "Spread: " +
         IntegerToString((int)MarketInfo(Symbol(),
                                         MODE_SPREAD)) +
         " points";

      Comment(text);
   }
};

#endif
