#ifndef __TSP4_TRADE_MQH__
#define __TSP4_TRADE_MQH__

class CTSP4Trade
{
private:
   int m_magic;
   int m_slippage;
   int m_maxSpread;
   bool m_oneSeries;
   string m_reason;

   long m_executed[512];
   int m_executedCount;

   int Magic(int leg)
   {
      return(m_magic + leg);
   }

   bool IsOurOrder()
   {
      int magic = OrderMagicNumber();
      return(magic >= m_magic &&
             magic < m_magic + 100);
   }

   int CountOpen(string symbol)
   {
      int count = 0;

      for(int i = OrdersTotal() - 1;
          i >= 0;
          i--)
      {
         if(!OrderSelect(i,
                         SELECT_BY_POS,
                         MODE_TRADES))
            continue;

         if(OrderSymbol() == symbol &&
            IsOurOrder())
            count++;
      }

      return(count);
   }

   int SendLeg(STSP4_TradePlan &plan,
               int leg,
               double lot)
   {
      RefreshRates();

      int type =
         (plan.direction == TSP4_DIR_BUY ?
          OP_BUY :
          OP_SELL);

      double price =
         (type == OP_BUY ?
          Ask :
          Bid);

      double takeProfit = 0.0;

      if(leg == 1)
         takeProfit = plan.tp1;

      if(leg == 2)
         takeProfit = plan.tp2;

      ResetLastError();

      int ticket =
         OrderSend(plan.symbol,
                   type,
                   lot,
                   price,
                   m_slippage,
                   plan.stopLoss,
                   takeProfit,
                   plan.commentBase +
                   " L" +
                   IntegerToString(leg),
                   Magic(leg),
                   0,
                   clrNONE);

      if(ticket < 0)
      {
         m_reason =
            "OrderSend leg " +
            IntegerToString(leg) +
            " error " +
            IntegerToString(GetLastError());
      }

      return(ticket);
   }

   void Rollback(int ticket)
   {
      if(ticket < 0)
         return;

      if(!OrderSelect(ticket,
                      SELECT_BY_TICKET))
         return;

      if(OrderCloseTime() > 0)
         return;

      RefreshRates();

      double price =
         (OrderType() == OP_BUY ?
          Bid :
          Ask);

      ResetLastError();

      bool closed =
         OrderClose(ticket,
                    OrderLots(),
                    price,
                    m_slippage,
                    clrNONE);

      if(!closed)
      {
         Print("[TSP4][ROLLBACK] ticket=",
               ticket,
               " error=",
               GetLastError());
      }
   }

public:
   void Init(int magic,
             int slippage,
             int maxSpread,
             bool oneSeries)
   {
      m_magic = magic;
      m_slippage = slippage;
      m_maxSpread = maxSpread;
      m_oneSeries = oneSeries;
      m_reason = "";
      m_executedCount = 0;
   }

   string LastReason()
   {
      return(m_reason);
   }

   bool WasExecuted(long key)
   {
      for(int i = 0;
          i < m_executedCount;
          i++)
      {
         if(m_executed[i] == key)
            return(true);
      }

      return(false);
   }

   void MarkExecuted(long key)
   {
      if(WasExecuted(key))
         return;

      if(m_executedCount < 512)
      {
         m_executed[m_executedCount] = key;
         m_executedCount++;
      }
   }

   bool Validate(STSP4_TradePlan &plan)
   {
      if(plan.direction == TSP4_DIR_BUY)
      {
         if(!(plan.stopLoss < plan.entry &&
              plan.tp1 > plan.entry &&
              plan.tp2 > plan.tp1))
         {
            m_reason = "Invalid BUY geometry";
            return(false);
         }
      }
      else
      {
         if(!(plan.stopLoss > plan.entry &&
              plan.tp1 < plan.entry &&
              plan.tp2 < plan.tp1))
         {
            m_reason = "Invalid SELL geometry";
            return(false);
         }
      }

      if(MathAbs(plan.lot1 - plan.lot2) > 0.000001 ||
         MathAbs(plan.lot1 - plan.lot3) > 0.000001)
      {
         m_reason = "Equal lot assertion failed";
         return(false);
      }

      return(true);
   }

   bool Open(STSP4_TradePlan &plan,
             bool tradingEnabled)
   {
      if(!tradingEnabled)
      {
         m_reason = "Trading disabled";
         return(false);
      }

      if((int)MarketInfo(plan.symbol,
                         MODE_SPREAD) >
         m_maxSpread)
      {
         m_reason = "Spread too high";
         return(false);
      }

      if(m_oneSeries &&
         CountOpen(plan.symbol) > 0)
      {
         m_reason = "Existing active series";
         return(false);
      }

      int ticket1 =
         SendLeg(plan, 1, plan.lot1);

      if(ticket1 < 0)
         return(false);

      int ticket2 =
         SendLeg(plan, 2, plan.lot2);

      if(ticket2 < 0)
      {
         Rollback(ticket1);
         return(false);
      }

      int ticket3 =
         SendLeg(plan, 3, plan.lot3);

      if(ticket3 < 0)
      {
         Rollback(ticket2);
         Rollback(ticket1);
         return(false);
      }

      m_reason = "Opened 3 equal-lot trades";
      return(true);
   }

   void Manage(string symbol,
               CTSP4Indicators &ind)
   {
      double sar = ind.Sar(symbol, PERIOD_H1, 1);
      datetime sarBarTime = iTime(symbol, PERIOD_H1, 1);

      if(sar <= 0.0 || sarBarTime <= 0)
         return;

      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

         if(OrderSymbol() != symbol || !IsOurOrder())
            continue;

         // The trailing point must come from a fully completed H1 bar
         // that formed after the trade was opened.
         if(sarBarTime <= OrderOpenTime())
            continue;

         double currentStop = OrderStopLoss();
         double newStop = currentStop;
         bool modify = false;

         if(OrderType() == OP_BUY)
         {
            // Move SL with every newer penultimate SAR point that improves it.
            // The new SL may still be below Entry; it does not have to be in profit.
            bool improvesStop =
               (currentStop == 0.0 || sar > currentStop + Point);

            bool validMarketSide =
               (sar < Bid);

            if(improvesStop && validMarketSide)
            {
               newStop = NormalizeDouble(sar, Digits);
               modify = true;
            }
         }

         if(OrderType() == OP_SELL)
         {
            // Mirror logic for SELL.
            bool improvesStop =
               (currentStop == 0.0 || sar < currentStop - Point);

            bool validMarketSide =
               (sar > Ask);

            if(improvesStop && validMarketSide)
            {
               newStop = NormalizeDouble(sar, Digits);
               modify = true;
            }
         }

         if(!modify)
            continue;

         ResetLastError();

         bool modified =
            OrderModify(OrderTicket(),
                        OrderOpenPrice(),
                        newStop,
                        OrderTakeProfit(),
                        0,
                        clrNONE);

         if(!modified)
         {
            Print("[TSP4][TRAIL] ticket=",
                  OrderTicket(),
                  " error=",
                  GetLastError(),
                  " oldSL=",
                  DoubleToString(currentStop, Digits),
                  " candidateSAR=",
                  DoubleToString(sar, Digits));
         }
         else
         {
            Print("[TSP4][TRAIL] ticket=",
                  OrderTicket(),
                  " oldSL=",
                  DoubleToString(currentStop, Digits),
                  " newSL=",
                  DoubleToString(newStop, Digits));
         }
      }
   }

};

#endif
