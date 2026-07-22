#ifndef __TSP4_DIAGNOSTICS_MQH__
#define __TSP4_DIAGNOSTICS_MQH__

// TSP Infinity EA v5.2
// Professional terminal diagnostics with duplicate suppression.

class CTSP4Diagnostics
{
private:
   bool     m_enabled;
   long     m_lastSignalKey;
   datetime m_signalFirstSeen;
   int      m_waitingH1Bars;
   string   m_lastStageKey;
   string   m_lastEntrySnapshotKey;

public:
   void Init(bool enabled)
   {
      m_enabled = enabled;
      m_lastSignalKey = 0;
      m_signalFirstSeen = 0;
      m_waitingH1Bars = 0;
      m_lastStageKey = "";
      m_lastEntrySnapshotKey = "";
   }

   int WaitingH1Bars()
   {
      return(m_waitingH1Bars);
   }

   string LastStage()
   {
      return(m_lastStageKey);
   }

   void ObserveSignal(STSP4_Signal &signal)
   {
      if(signal.key <= 0)
         return;

      if(signal.key != m_lastSignalKey)
      {
         m_lastSignalKey = signal.key;
         m_signalFirstSeen = TimeCurrent();
         m_waitingH1Bars = 0;
         m_lastStageKey = "";
         m_lastEntrySnapshotKey = "";

         if(m_enabled)
         {
            Print(
               "[TSP4][SIGNAL_NEW] key=", signal.key,
               " type=", TSP4_SignalText(signal.type),
               " direction=", TSP4_DirectionText(signal.direction),
               " created=", TimeToString(signal.created, TIME_DATE|TIME_MINUTES)
            );
         }
      }
   }

   void Stage(STSP4_Signal &signal, string stage, string reason)
   {
      ObserveSignal(signal);

      if(stage == "WAIT_H1" && m_signalFirstSeen > 0)
      {
         int bars = iBarShift(
            Symbol(),
            PERIOD_H1,
            m_signalFirstSeen,
            false
         );

         if(bars >= 0)
            m_waitingH1Bars = bars;
      }

      string stageKey =
         IntegerToString((int)signal.key) + "|" +
         stage + "|" +
         reason + "|" +
         IntegerToString(m_waitingH1Bars);

      if(!m_enabled)
      {
         m_lastStageKey = stageKey;
         return;
      }

      bool mandatory =
         stage == "EXECUTED" ||
         stage == "PLAN_BLOCK" ||
         stage == "ORDER_BLOCK";

      if(mandatory || stageKey != m_lastStageKey)
      {
         Print(
            "[TSP4][STAGE] key=", signal.key,
            " stage=", stage,
            " waitedH1Bars=", m_waitingH1Bars,
            " reason=", reason
         );
      }

      m_lastStageKey = stageKey;
   }

   void EntrySnapshot(STSP4_Signal &signal, string entryReason)
   {
      if(!m_enabled)
         return;

      datetime h1Bar = iTime(Symbol(), PERIOD_H1, 0);

      // Only one identical entry snapshot per H1 bar.
      string snapshotKey =
         IntegerToString((int)signal.key) + "|" +
         IntegerToString((int)h1Bar) + "|" +
         entryReason;

      if(snapshotKey == m_lastEntrySnapshotKey)
         return;

      double sar0 = iSAR(Symbol(), PERIOD_H1, 0.002, 0.2, 0);
      double sar1 = iSAR(Symbol(), PERIOD_H1, 0.002, 0.2, 1);

      Print(
         "[TSP4][ENTRY_SNAPSHOT] key=", signal.key,
         " direction=", TSP4_DirectionText(signal.direction),
         " H1Time=", TimeToString(h1Bar, TIME_DATE|TIME_MINUTES),
         " Bid=", DoubleToString(Bid, Digits),
         " Ask=", DoubleToString(Ask, Digits),
         " SAR0=", DoubleToString(sar0, Digits),
         " SAR1=", DoubleToString(sar1, Digits),
         " High0=", DoubleToString(iHigh(Symbol(), PERIOD_H1, 0), Digits),
         " Low0=", DoubleToString(iLow(Symbol(), PERIOD_H1, 0), Digits),
         " detail=", entryReason
      );

      m_lastEntrySnapshotKey = snapshotKey;
   }
};

#endif
