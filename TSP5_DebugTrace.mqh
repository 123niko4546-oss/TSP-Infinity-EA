#ifndef __TSP5_DEBUG_TRACE_MQH__
#define __TSP5_DEBUG_TRACE_MQH__

// TSP Infinity EA v5.2
// Event-based diagnostic trace.
// Trading logic is intentionally untouched.

class CTSP5DebugTrace
{
private:
   bool   m_enabled;
   bool   m_everyTick;
   bool   m_writeCsv;
   string m_fileName;
   int    m_handle;

   string m_lastD1Key;
   string m_lastH4Key;
   string m_lastPipelineKey;
   string m_lastH1Key;

   long   m_rowsWritten;
   long   m_d1Rows;
   long   m_h4Rows;
   long   m_h1Rows;
   long   m_pipelineRows;
   long   m_planRows;

   void WriteLine(string stage, long signalKey, string detail, bool flushNow=false)
   {
      if(!m_enabled)
         return;

      Print("[TSP5.2][TRACE][", stage, "] key=", signalKey, " ", detail);

      if(m_writeCsv && m_handle != INVALID_HANDLE)
      {
         FileWrite(
            m_handle,
            TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
            Symbol(),
            stage,
            signalKey,
            detail
         );

         m_rowsWritten++;

         if(stage == "D1_DECISION") m_d1Rows++;
         else if(stage == "H4_DECISION") m_h4Rows++;
         else if(stage == "H1_DECISION") m_h1Rows++;
         else if(stage == "PIPELINE") m_pipelineRows++;
         else if(stage == "TRADE_PLAN") m_planRows++;

         // Ordinary wait-state rows are not flushed one by one.
         // Mandatory trade events and shutdown are flushed immediately.
         if(flushNow)
            FileFlush(m_handle);
      }
   }

   string BoolText(bool value)
   {
      return(value ? "true" : "false");
   }

public:
   void Init(bool enabled, bool everyTick, bool writeCsv, string fileName)
   {
      m_enabled   = enabled;
      m_everyTick = everyTick;
      m_writeCsv  = writeCsv;
      m_fileName  = fileName;
      m_handle    = INVALID_HANDLE;

      m_lastD1Key       = "";
      m_lastH4Key       = "";
      m_lastPipelineKey = "";
      m_lastH1Key       = "";

      m_rowsWritten = 0;
      m_d1Rows = 0;
      m_h4Rows = 0;
      m_h1Rows = 0;
      m_pipelineRows = 0;
      m_planRows = 0;

      if(m_enabled && m_writeCsv)
      {
         m_handle = FileOpen(
            m_fileName,
            FILE_CSV|FILE_WRITE|FILE_SHARE_READ,
            ';'
         );

         if(m_handle != INVALID_HANDLE)
         {
            FileWrite(
               m_handle,
               "terminal_time",
               "symbol",
               "stage",
               "signal_key",
               "detail"
            );
            FileFlush(m_handle);
         }
         else
         {
            Print(
               "[TSP5.2][TRACE][FILE_ERROR] file=",
               m_fileName,
               " error=",
               GetLastError()
            );
         }
      }
   }

   void Deinit()
   {
      if(m_enabled)
      {
         string summary =
            "rows=" + IntegerToString((int)m_rowsWritten) +
            " D1=" + IntegerToString((int)m_d1Rows) +
            " H4=" + IntegerToString((int)m_h4Rows) +
            " H1=" + IntegerToString((int)m_h1Rows) +
            " PIPELINE=" + IntegerToString((int)m_pipelineRows) +
            " PLAN=" + IntegerToString((int)m_planRows);

         WriteLine("SUMMARY", 0, summary, true);
      }

      if(m_handle != INVALID_HANDLE)
      {
         FileFlush(m_handle);
         FileClose(m_handle);
         m_handle = INVALID_HANDLE;
      }
   }

   void D1(STSP4_D1Snapshot &d1)
   {
      // Stable event key: one decision per D1 bar/regime/cross/divergence state.
      // Histogram decimals and free-form reason are deliberately excluded.
      string eventKey =
         IntegerToString((int)d1.barTime) + "|" +
         IntegerToString(d1.regime) + "|" +
         BoolText(d1.goldenCross) + "|" +
         BoolText(d1.blackCross) + "|" +
         BoolText(d1.confirmedBearDiv) + "|" +
         BoolText(d1.confirmedBullDiv) + "|" +
         BoolText(d1.formingBearDiv) + "|" +
         BoolText(d1.formingBullDiv);

      if(!m_everyTick && eventKey == m_lastD1Key)
         return;

      string detail =
         "bar=" + TimeToString(d1.barTime, TIME_DATE|TIME_MINUTES) +
         " regime=" + TSP4_RegimeText(d1.regime) +
         " hist1=" + DoubleToString(d1.hist1, 6) +
         " hist2=" + DoubleToString(d1.hist2, 6) +
         " golden=" + BoolText(d1.goldenCross) +
         " black=" + BoolText(d1.blackCross) +
         " bearDiv=" + BoolText(d1.confirmedBearDiv) +
         " bullDiv=" + BoolText(d1.confirmedBullDiv) +
         " formingBear=" + BoolText(d1.formingBearDiv) +
         " formingBull=" + BoolText(d1.formingBullDiv) +
         " reason=" + d1.reason;

      WriteLine("D1_DECISION", 0, detail);
      m_lastD1Key = eventKey;
   }

   void H4(
      STSP4_H4Snapshot &h4,
      int regime,
      STSP4_Signal &signal,
      bool filterPass,
      string reason
   )
   {
      // Stable event key: log only when bar, zone, regime, selected signal,
      // direction or filter result changes. Live K decimals are not part of it.
      string eventKey =
         IntegerToString((int)h4.barTime) + "|" +
         IntegerToString(h4.zone) + "|" +
         IntegerToString(regime) + "|" +
         IntegerToString((int)signal.key) + "|" +
         IntegerToString(signal.type) + "|" +
         IntegerToString(signal.direction) + "|" +
         BoolText(filterPass);

      if(!m_everyTick && eventKey == m_lastH4Key)
         return;

      string detail =
         "bar=" + TimeToString(h4.barTime, TIME_DATE|TIME_MINUTES) +
         " K=" + DoubleToString(h4.stochK, 2) +
         " zone=" + IntegerToString(h4.zone) +
         " regime=" + TSP4_RegimeText(regime) +
         " selected=" + TSP4_SignalText(signal.type) +
         " direction=" + TSP4_DirectionText(signal.direction) +
         " filter=" + (filterPass ? "PASS" : "WAIT") +
         " reason=" + reason;

      WriteLine("H4_DECISION", signal.key, detail);
      m_lastH4Key = eventKey;
   }

   void Pipeline(STSP4_Signal &signal, string stage, string reason)
   {
      // Stable key intentionally excludes created/validUntil display strings
      // and any prices that could change on every tick.
      string eventKey =
         IntegerToString((int)signal.key) + "|" +
         stage + "|" +
         IntegerToString(signal.type) + "|" +
         IntegerToString(signal.direction) + "|" +
         IntegerToString(signal.state) + "|" +
         reason;

      bool mandatory =
         stage == "PLAN_READY" ||
         stage == "ORDER_RESULT";

      if(!m_everyTick && !mandatory && eventKey == m_lastPipelineKey)
         return;

      string detail =
         "stage=" + stage +
         " type=" + TSP4_SignalText(signal.type) +
         " direction=" + TSP4_DirectionText(signal.direction) +
         " state=" + IntegerToString(signal.state) +
         " created=" + TimeToString(signal.created, TIME_DATE|TIME_MINUTES) +
         " validUntil=" + TimeToString(signal.validUntil, TIME_DATE|TIME_MINUTES) +
         " reason=" + reason;

      WriteLine("PIPELINE", signal.key, detail, mandatory);
      m_lastPipelineKey = eventKey;
   }

   void H1(STSP4_Signal &signal, string result, string reason)
   {
      datetime h1Bar = iTime(Symbol(), PERIOD_H1, 0);

      // At most one WAIT record per H1 bar for the same signal and reason.
      // READY remains a mandatory event.
      string eventKey =
         IntegerToString((int)signal.key) + "|" +
         result + "|" +
         reason + "|" +
         IntegerToString((int)h1Bar);

      bool mandatory = (result == "READY");

      if(!m_everyTick && !mandatory && eventKey == m_lastH1Key)
         return;

      double sar0 = iSAR(Symbol(), PERIOD_H1, 0.002, 0.2, 0);
      double sar1 = iSAR(Symbol(), PERIOD_H1, 0.002, 0.2, 1);

      string detail =
         "result=" + result +
         " direction=" + TSP4_DirectionText(signal.direction) +
         " H1=" + TimeToString(h1Bar, TIME_DATE|TIME_MINUTES) +
         " Bid=" + DoubleToString(Bid, Digits) +
         " Ask=" + DoubleToString(Ask, Digits) +
         " SAR0=" + DoubleToString(sar0, Digits) +
         " SAR1=" + DoubleToString(sar1, Digits) +
         " High0=" + DoubleToString(iHigh(Symbol(), PERIOD_H1, 0), Digits) +
         " Low0=" + DoubleToString(iLow(Symbol(), PERIOD_H1, 0), Digits) +
         " reason=" + reason;

      WriteLine("H1_DECISION", signal.key, detail, mandatory);
      m_lastH1Key = eventKey;
   }

   void Plan(STSP4_TradePlan &plan, string stage, string reason)
   {
      string detail =
         "stage=" + stage +
         " type=" + TSP4_SignalText(plan.signalType) +
         " direction=" + TSP4_DirectionText(plan.direction) +
         " entry=" + DoubleToString(plan.entry, Digits) +
         " SL=" + DoubleToString(plan.stopLoss, Digits) +
         " TP1=" + DoubleToString(plan.tp1, Digits) +
         " TP2=" + DoubleToString(plan.tp2, Digits) +
         " gap=" + DoubleToString(plan.gap, Digits) +
         " lots=" + DoubleToString(plan.lot1, 2) + "," +
                    DoubleToString(plan.lot2, 2) + "," +
                    DoubleToString(plan.lot3, 2) +
         " reason=" + reason;

      // Trade-plan events are rare and important, so always write and flush.
      WriteLine("TRADE_PLAN", plan.signalKey, detail, true);
   }
};

#endif
