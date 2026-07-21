#ifndef __TSP4_D1_ENGINE_MQH__
#define __TSP4_D1_ENGINE_MQH__

class CTSP4D1Engine
{
private:
   int m_maxBars;
   int m_confirmBars;
   int m_crossDays;
   int m_regimeLookback;
   bool m_enableDivergence;

   bool IsLocalHigh(string symbol, int shift)
   {
      double value=iHigh(symbol,PERIOD_D1,shift);
      return(value>=iHigh(symbol,PERIOD_D1,shift-1) &&
             value> iHigh(symbol,PERIOD_D1,shift+1));
   }

   bool IsLocalLow(string symbol, int shift)
   {
      double value=iLow(symbol,PERIOD_D1,shift);
      return(value<=iLow(symbol,PERIOD_D1,shift-1) &&
             value< iLow(symbol,PERIOD_D1,shift+1));
   }

   bool ConfirmedHigh(string symbol, CTSP4Indicators &ind, int shift)
   {
      if(shift<3) return(false);
      return(IsLocalHigh(symbol,shift) && ind.TwoFalling(symbol,PERIOD_D1,shift-2));
   }

   bool ConfirmedLow(string symbol, CTSP4Indicators &ind, int shift)
   {
      if(shift<3) return(false);
      return(IsLocalLow(symbol,shift) && ind.TwoRising(symbol,PERIOD_D1,shift-2));
   }

   void FindHighs(string symbol, CTSP4Indicators &ind,
                  STSP4_Pivot &last, STSP4_Pivot &previous)
   {
      last.valid=false; previous.valid=false;
      for(int shift=3; shift<=m_maxBars; shift++)
      {
         if(!ConfirmedHigh(symbol,ind,shift)) continue;
         STSP4_Pivot p;
         p.valid=true; p.shift=shift; p.time=iTime(symbol,PERIOD_D1,shift);
         p.price=iHigh(symbol,PERIOD_D1,shift); p.macd=ind.Hist(symbol,PERIOD_D1,shift);
         if(!last.valid) last=p; else { previous=p; break; }
      }
   }

   void FindLows(string symbol, CTSP4Indicators &ind,
                 STSP4_Pivot &last, STSP4_Pivot &previous)
   {
      last.valid=false; previous.valid=false;
      for(int shift=3; shift<=m_maxBars; shift++)
      {
         if(!ConfirmedLow(symbol,ind,shift)) continue;
         STSP4_Pivot p;
         p.valid=true; p.shift=shift; p.time=iTime(symbol,PERIOD_D1,shift);
         p.price=iLow(symbol,PERIOD_D1,shift); p.macd=ind.Hist(symbol,PERIOD_D1,shift);
         if(!last.valid) last=p; else { previous=p; break; }
      }
   }

   int DetectLatestRegime(string symbol, CTSP4Indicators &ind,
                          datetime &crossTime, int &crossShift)
   {
      crossTime=0; crossShift=-1;
      int bars=iBars(symbol,PERIOD_D1);
      int limit=MathMin(m_regimeLookback,bars-2);

      // Scan newest closed pair first. The first crossing found is the active regime.
      for(int shift=1; shift<=limit; shift++)
      {
         double newer=ind.Hist(symbol,PERIOD_D1,shift);
         double older=ind.Hist(symbol,PERIOD_D1,shift+1);

         if(older<=0.0 && newer>0.0)
         {
            crossTime=iTime(symbol,PERIOD_D1,shift);
            crossShift=shift;
            return(TSP4_REGIME_GOLDEN);
         }

         if(older>=0.0 && newer<0.0)
         {
            crossTime=iTime(symbol,PERIOD_D1,shift);
            crossShift=shift;
            return(TSP4_REGIME_BLACK);
         }
      }

      // Fallback only when historical scan cannot find a crossing.
      double h1=ind.Hist(symbol,PERIOD_D1,1);
      if(h1>0.0) return(TSP4_REGIME_GOLDEN);
      if(h1<0.0) return(TSP4_REGIME_BLACK);
      return(TSP4_REGIME_NONE);
   }

public:
   void Init(int maxBars, int confirmBars, int crossDays,
             bool enableDivergence)
   {
      m_maxBars=maxBars;
      m_confirmBars=confirmBars;
      m_crossDays=crossDays;
      m_regimeLookback=MathMax(300,maxBars*2);
      m_enableDivergence=enableDivergence;
   }

   void Evaluate(string symbol, CTSP4Indicators &ind, STSP4_D1Snapshot &out)
   {
      out.barTime=iTime(symbol,PERIOD_D1,0);
      out.hist1=ind.Hist(symbol,PERIOD_D1,1);
      out.hist2=ind.Hist(symbol,PERIOD_D1,2);

      // Cross events use CLOSED D1 bars only.
      out.goldenCross=(out.hist2<=0.0 && out.hist1>0.0);
      out.blackCross =(out.hist2>=0.0 && out.hist1<0.0);

      int crossShift=-1;
      out.regime=DetectLatestRegime(symbol,ind,out.regimeCrossTime,crossShift);
      out.trend=(out.regime==TSP4_REGIME_BLACK ? TSP4_DIR_SELL :
                 out.regime==TSP4_REGIME_GOLDEN ? TSP4_DIR_BUY : TSP4_DIR_NONE);

      out.lastHigh.valid=false;
      out.previousHigh.valid=false;
      out.lastLow.valid=false;
      out.previousLow.valid=false;

      out.confirmedBearDiv=false;
      out.confirmedBullDiv=false;
      out.formingBearDiv=false;
      out.formingBullDiv=false;

      // v4.1.3 isolation test:
      // When disabled, divergence pivots are not scanned and no divergence
      // state is calculated. Cross/regime detection remains unchanged.
      if(m_enableDivergence)
      {
         FindHighs(symbol,ind,out.lastHigh,out.previousHigh);
         FindLows(symbol,ind,out.lastLow,out.previousLow);

         if(out.lastHigh.valid && out.previousHigh.valid)
         {
            out.confirmedBearDiv=(out.lastHigh.price>out.previousHigh.price &&
                                  out.lastHigh.macd<out.previousHigh.macd);
            double currentPriceHigh=iHigh(symbol,PERIOD_D1,0);
            double formingMacdHigh=MathMax(ind.Hist(symbol,PERIOD_D1,0),
                                           ind.Hist(symbol,PERIOD_D1,1));
            bool notConfirmedYet=!ind.TwoFalling(symbol,PERIOD_D1,0);
            out.formingBearDiv=(currentPriceHigh>out.lastHigh.price &&
                                formingMacdHigh<out.lastHigh.macd &&
                                notConfirmedYet);
         }

         if(out.lastLow.valid && out.previousLow.valid)
         {
            out.confirmedBullDiv=(out.lastLow.price<out.previousLow.price &&
                                  out.lastLow.macd>out.previousLow.macd);
            double currentPriceLow=iLow(symbol,PERIOD_D1,0);
            double formingMacdLow=MathMin(ind.Hist(symbol,PERIOD_D1,0),
                                          ind.Hist(symbol,PERIOD_D1,1));
            bool notConfirmedYet=!ind.TwoRising(symbol,PERIOD_D1,0);
            out.formingBullDiv=(currentPriceLow<out.lastLow.price &&
                                formingMacdLow>out.lastLow.macd &&
                                notConfirmedYet);
         }
      }

      out.reason="D1 regime="+TSP4_RegimeText(out.regime)+
                 " hist1="+DoubleToString(out.hist1,6)+
                 " hist2="+DoubleToString(out.hist2,6)+
                 " crossShift="+IntegerToString(crossShift)+
                 " divergence="+(m_enableDivergence ? "ON" : "OFF");
   }
};

#endif
