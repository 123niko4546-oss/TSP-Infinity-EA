#ifndef __TSP5_DEBUG_TRACE_MQH__
#define __TSP5_DEBUG_TRACE_MQH__

class CTSP5DebugTrace
{
private:
   bool   m_enabled;
   bool   m_everyTick;
   bool   m_writeCsv;
   string m_fileName;
   int    m_handle;
   string m_lastD1;
   string m_lastH4;
   string m_lastPipeline;
   string m_lastH1;

   void WriteLine(string stage,
                  long key,
                  string detail)
   {
      if(!m_enabled) return;

      Print("[TSP5][TRACE][",stage,"] key=",key," ",detail);

      if(m_writeCsv && m_handle!=INVALID_HANDLE)
      {
         FileWrite(m_handle,
                   TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
                   Symbol(),
                   stage,
                   key,
                   detail);
         FileFlush(m_handle);
      }
   }

public:
   void Init(bool enabled,
             bool everyTick,
             bool writeCsv,
             string fileName)
   {
      m_enabled=enabled;
      m_everyTick=everyTick;
      m_writeCsv=writeCsv;
      m_fileName=fileName;
      m_handle=INVALID_HANDLE;
      m_lastD1="";
      m_lastH4="";
      m_lastPipeline="";
      m_lastH1="";

      if(m_enabled && m_writeCsv)
      {
         m_handle=FileOpen(m_fileName,
                           FILE_CSV|FILE_WRITE|FILE_SHARE_READ,
                           ';');
         if(m_handle!=INVALID_HANDLE)
            FileWrite(m_handle,"terminal_time","symbol","stage","signal_key","detail");
         else
            Print("[TSP5][TRACE][FILE_ERROR] file=",m_fileName," error=",GetLastError());
      }
   }

   void Deinit()
   {
      if(m_handle!=INVALID_HANDLE)
      {
         FileFlush(m_handle);
         FileClose(m_handle);
         m_handle=INVALID_HANDLE;
      }
   }

   void D1(STSP4_D1Snapshot &d1)
   {
      string s="bar="+TimeToString(d1.barTime,TIME_DATE|TIME_MINUTES)+
               " regime="+TSP4_RegimeText(d1.regime)+
               " hist1="+DoubleToString(d1.hist1,6)+
               " hist2="+DoubleToString(d1.hist2,6)+
               " golden="+(d1.goldenCross?"true":"false")+
               " black="+(d1.blackCross?"true":"false")+
               " bearDiv="+(d1.confirmedBearDiv?"true":"false")+
               " bullDiv="+(d1.confirmedBullDiv?"true":"false")+
               " formingBear="+(d1.formingBearDiv?"true":"false")+
               " formingBull="+(d1.formingBullDiv?"true":"false")+
               " reason="+d1.reason;
      if(m_everyTick || s!=m_lastD1) WriteLine("D1_DECISION",0,s);
      m_lastD1=s;
   }

   void H4(STSP4_H4Snapshot &h4,
           int regime,
           STSP4_Signal &signal,
           bool filterPass,
           string reason)
   {
      string s="bar="+TimeToString(h4.barTime,TIME_DATE|TIME_MINUTES)+
               " K="+DoubleToString(h4.stochK,2)+
               " zone="+IntegerToString(h4.zone)+
               " regime="+TSP4_RegimeText(regime)+
               " selected="+TSP4_SignalText(signal.type)+
               " direction="+TSP4_DirectionText(signal.direction)+
               " filter="+(filterPass?"PASS":"WAIT")+
               " reason="+reason;
      if(m_everyTick || s!=m_lastH4) WriteLine("H4_DECISION",signal.key,s);
      m_lastH4=s;
   }

   void Pipeline(STSP4_Signal &signal,
                 string stage,
                 string reason)
   {
      string s="stage="+stage+
               " type="+TSP4_SignalText(signal.type)+
               " direction="+TSP4_DirectionText(signal.direction)+
               " state="+IntegerToString(signal.state)+
               " created="+TimeToString(signal.created,TIME_DATE|TIME_MINUTES)+
               " validUntil="+TimeToString(signal.validUntil,TIME_DATE|TIME_MINUTES)+
               " reason="+reason;
      if(m_everyTick || s!=m_lastPipeline || stage=="PLAN_READY" || stage=="ORDER_RESULT")
         WriteLine("PIPELINE",signal.key,s);
      m_lastPipeline=s;
   }

   void H1(STSP4_Signal &signal,
           string result,
           string reason)
   {
      double sar0=iSAR(Symbol(),PERIOD_H1,0.002,0.2,0);
      double sar1=iSAR(Symbol(),PERIOD_H1,0.002,0.2,1);
      string s="result="+result+
               " direction="+TSP4_DirectionText(signal.direction)+
               " H1="+TimeToString(iTime(Symbol(),PERIOD_H1,0),TIME_DATE|TIME_MINUTES)+
               " Bid="+DoubleToString(Bid,Digits)+
               " Ask="+DoubleToString(Ask,Digits)+
               " SAR0="+DoubleToString(sar0,Digits)+
               " SAR1="+DoubleToString(sar1,Digits)+
               " High0="+DoubleToString(iHigh(Symbol(),PERIOD_H1,0),Digits)+
               " Low0="+DoubleToString(iLow(Symbol(),PERIOD_H1,0),Digits)+
               " reason="+reason;
      if(m_everyTick || s!=m_lastH1 || result=="READY") WriteLine("H1_DECISION",signal.key,s);
      m_lastH1=s;
   }

   void Plan(STSP4_TradePlan &plan,
             string stage,
             string reason)
   {
      string s="stage="+stage+
               " type="+TSP4_SignalText(plan.signalType)+
               " direction="+TSP4_DirectionText(plan.direction)+
               " entry="+DoubleToString(plan.entry,Digits)+
               " SL="+DoubleToString(plan.stopLoss,Digits)+
               " TP1="+DoubleToString(plan.tp1,Digits)+
               " TP2="+DoubleToString(plan.tp2,Digits)+
               " gap="+DoubleToString(plan.gap,Digits)+
               " lots="+DoubleToString(plan.lot1,2)+","+
                         DoubleToString(plan.lot2,2)+","+
                         DoubleToString(plan.lot3,2)+
               " reason="+reason;
      WriteLine("TRADE_PLAN",plan.signalKey,s);
   }
};

#endif
