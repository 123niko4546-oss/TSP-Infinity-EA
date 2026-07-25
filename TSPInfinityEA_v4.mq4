//+------------------------------------------------------------------+
//| TSP Infinity EA v4.0 Core Engine                                             |
//| Clean MT4 architecture                                           |
//+------------------------------------------------------------------+
#property strict
#property version   "5.300"
#property description "TSP Infinity EA v5.3 Live SAR[1] Entry Engine."

#define TSP_VERSION "5.3 Live SAR[1] Entry Engine"

#include "TSP4_Types.mqh"
#include "TSP4_Indicators.mqh"
#include "TSP4_D1Engine.mqh"
#include "TSP4_H4Engine.mqh"
#include "TSP4_SignalEngine.mqh"
#include "TSP4_H1Entry.mqh"
#include "TSP4_Money.mqh"
#include "TSP4_Trade.mqh"
#include "TSP4_Panel.mqh"
#include "TSP4_Validator.mqh"
#include "TSP4_Diagnostics.mqh"
#include "TSP4_DeepDiagnostics.mqh"
#include "TSP5_DebugTrace.mqh"

// General
input bool   Inp_EnableTrading               = false; // DEBUG safety: analysis only by default
input double Inp_TotalRiskPercent            = 1.0;
input bool   Inp_UseEquity                   = true;
input int    Inp_BaseMagic                   = 820000;
input int    Inp_SlippagePoints              = 30;
input int    Inp_MaxSpreadPoints             = 100;
input bool   Inp_OneActiveSeriesPerSymbol    = true;
input bool   Inp_Debug                       = true;
input bool   Inp_EnableProfessionalDiagnostics = true;
input bool   Inp_DiagnosticEveryTick         = false;
input int    Inp_DiagnosticThrottleSeconds    = 1;
input bool   Inp_BlockExpiredSignals           = true;
input bool   Inp_V5DecisionTrace               = true;
input bool   Inp_V5TraceEveryTick               = false;
input bool   Inp_V5WriteCsv                     = true;
input string Inp_V5CsvFile                      = "TSP_Infinity_v5_3_Live_SAR_Trace.csv";

// MACD2
input string Inp_MACD2_Name                  = "MACD2";
input int    Inp_MACD_Fast                   = 50;
input int    Inp_MACD_Slow                   = 150;
input int    Inp_MACD_Signal                 = 15;
input int    Inp_MACD_HistogramBuffer        = 2;

// Stochastic
input int    Inp_Stoch_K                     = 50;
input int    Inp_Stoch_D                     = 10;
input int    Inp_Stoch_Slowing               = 25;
input int    Inp_StochPriceField             = 1; // 0=Low/High, 1=Close/Close
input double Inp_Stoch_Overbought            = 80.0;
input double Inp_Stoch_Oversold              = 20.0;
input bool   Inp_LiveH4Stochastic            = true;

// Parabolic SAR
input double Inp_SAR_Step                    = 0.002;
input double Inp_SAR_Maximum                 = 0.2;
input int    Inp_SarGapLookbackBars          = 500;
input int    Inp_EntryTolerancePoints        = 20;

// Divergence
input bool   Inp_EnableDivergenceModule        = false; // v4.1.3 test: keep FALSE
input int    Inp_DivMaxBars                  = 150;
input int    Inp_PivotConfirmBars            = 2;

// Cross
input int    Inp_CrossValidityDays           = 5;

// Signals
input bool Inp_EnableSignal1 = true;
input bool Inp_EnableSignal2 = true;
input bool Inp_EnableSignal3 = true;
input bool Inp_EnableSignal4 = true;
input bool Inp_EnableSignal5 = true;
input bool Inp_EnableSignal6 = true;

CTSP4Indicators  g_ind;
CTSP4D1Engine    g_d1;
CTSP4H4Engine    g_h4;
CTSP4SignalEngine g_signal;
CTSP4H1Entry     g_entry;
CTSP4Money       g_money;
CTSP4Trade       g_trade;
CTSP4Panel       g_panel;
CTSP4Validator   g_validator;
CTSP4Diagnostics g_diagnostics;
CTSP4DeepDiagnostics g_deepDiagnostics;
CTSP5DebugTrace g_v5Trace;

datetime g_lastD1 = 0;
datetime g_lastH4 = 0;

bool SignalEnabled(int type)
{
   if(type == TSP4_SIGNAL_CONFIRMED_DIV) return(Inp_EnableDivergenceModule && Inp_EnableSignal1);
   if(type == TSP4_SIGNAL_FORMING_DIV)   return(Inp_EnableDivergenceModule && Inp_EnableSignal2);
   if(type == TSP4_SIGNAL_CROSS)         return(Inp_EnableSignal3);
   if(type == TSP4_SIGNAL_DEEP_N)        return(Inp_EnableSignal4);
   if(type == TSP4_SIGNAL_NORMAL_N)      return(Inp_EnableSignal5);
   if(type == TSP4_SIGNAL_COUNTER_N)     return(Inp_EnableSignal6);
   return(false);
}

int OnInit()
{
   g_ind.Init(Inp_MACD2_Name,
              Inp_MACD_Fast,
              Inp_MACD_Slow,
              Inp_MACD_Signal,
              Inp_MACD_HistogramBuffer,
              Inp_Stoch_K,
              Inp_Stoch_D,
              Inp_Stoch_Slowing,
              Inp_StochPriceField,
              Inp_SAR_Step,
              Inp_SAR_Maximum);

   g_d1.Init(Inp_DivMaxBars,
             Inp_PivotConfirmBars,
             Inp_CrossValidityDays,
             Inp_EnableDivergenceModule);

   g_h4.Init(Inp_Stoch_Overbought,
             Inp_Stoch_Oversold);

   g_signal.Init(Inp_EnableDivergenceModule);
   g_entry.Init(Inp_SarGapLookbackBars,
                Inp_EntryTolerancePoints);

   g_money.Init(Inp_TotalRiskPercent,
                Inp_UseEquity);

   g_trade.Init(Inp_BaseMagic,
                Inp_SlippagePoints,
                Inp_MaxSpreadPoints,
                Inp_OneActiveSeriesPerSymbol);

   g_panel.Init();
   g_validator.Init();
   g_diagnostics.Init(Inp_EnableProfessionalDiagnostics);
   g_deepDiagnostics.Init(Inp_DiagnosticEveryTick,
                          Inp_DiagnosticThrottleSeconds,
                          Inp_MACD2_Name,
                          Inp_MACD_Fast,
                          Inp_MACD_Slow,
                          Inp_MACD_Signal,
                          Inp_Stoch_K,
                          Inp_Stoch_D,
                          Inp_Stoch_Slowing,
                          Inp_StochPriceField,
                          Inp_Stoch_Overbought,
                          Inp_Stoch_Oversold,
                          Inp_SAR_Step,
                          Inp_SAR_Maximum);

   g_v5Trace.Init(Inp_V5DecisionTrace,
                  Inp_V5TraceEveryTick,
                  Inp_V5WriteCsv,
                  Inp_V5CsvFile);

   Print("[TSP5] Initialized v", TSP_VERSION,
         " | D1 regime active | divergence module=",
         Inp_EnableDivergenceModule ? "ON" : "OFF");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   g_v5Trace.Deinit();
   Comment("");
}

void OnTick()
{
   if(iBars(Symbol(), PERIOD_D1) < 250 ||
      iBars(Symbol(), PERIOD_H4) < 250 ||
      iBars(Symbol(), PERIOD_H1) < 500)
      return;

   g_deepDiagnostics.Snapshot(Symbol(), g_ind);

   g_trade.Manage(Symbol(), g_ind);

   datetime d1Now = iTime(Symbol(), PERIOD_D1, 0);
   datetime h4Now = iTime(Symbol(), PERIOD_H4, 0);

   if(d1Now != g_lastD1)
   {
      g_lastD1 = d1Now;

      STSP4_D1Snapshot d1;
      g_d1.Evaluate(Symbol(), g_ind, d1);
      g_v5Trace.D1(d1);
      g_signal.OnNewD1(d1);
   }

   // H4 regime filter is live.
   // The current H4 Stochastic is evaluated on every tick so transitions
   // between oversold / neutral / overbought are applied immediately.
   STSP4_H4Snapshot h4;
   g_h4.Evaluate(Symbol(), g_ind, h4);

   if(Inp_LiveH4Stochastic)
   {
      g_signal.OnLiveH4(h4);
   }
   else if(h4Now != g_lastH4)
   {
      g_lastH4 = h4Now;
      g_signal.OnNewH4(h4);
   }

   STSP4_Signal signal;
   if(!g_signal.GetCurrent(signal))
   {
      g_panel.Render(signal, "NO_SIGNAL", g_signal.LastReason(), g_entry.LastReason(), g_trade.LastReason());
      return;
   }

   g_v5Trace.H4(h4,
                g_signal.Regime(),
                signal,
                g_signal.FilterPass(),
                g_signal.LastReason());

   g_diagnostics.ObserveSignal(signal);

   if(!g_validator.ValidateSignal(signal))
   {
      g_v5Trace.Pipeline(signal, "SIGNAL_BLOCK", g_validator.LastReason());
      g_diagnostics.Stage(signal, "SIGNAL_BLOCK", g_validator.LastReason());
      g_panel.Render(signal, "SIGNAL_BLOCK", g_validator.LastReason(), g_entry.LastReason(), g_trade.LastReason());
      return;
   }

   if(!SignalEnabled(signal.type))
   {
      g_v5Trace.Pipeline(signal, "SIGNAL_DISABLED", g_signal.LastReason());
      g_diagnostics.Stage(signal, "SIGNAL_DISABLED", g_signal.LastReason());
      g_panel.Render(signal, "SIGNAL_DISABLED", g_signal.LastReason(), g_entry.LastReason(), g_trade.LastReason());
      return;
   }

   if(g_trade.WasExecuted(signal.key))
   {
      g_signal.MarkFinished(signal.key);
      g_v5Trace.Pipeline(signal, "DUPLICATE_BLOCK", "Signal already executed");
      g_diagnostics.Stage(signal, "DUPLICATE_BLOCK", "Signal already executed");
      g_panel.Render(signal, "DUPLICATE_BLOCK", "Signal already executed", g_entry.LastReason(), g_trade.LastReason());
      return;
   }

   if(!g_signal.FilterPass())
   {
      g_v5Trace.Pipeline(signal, "H4_WAIT", g_signal.LastReason());
      g_diagnostics.Stage(signal, "H4_WAIT", g_signal.LastReason());
      g_panel.Render(signal, "H4_WAIT", g_signal.LastReason(), g_entry.LastReason(), g_trade.LastReason());
      return;
   }

   STSP4_TradePlan plan;
   if(!g_entry.BuildPlanOnTouch(Symbol(), signal, g_ind, plan))
   {
      g_v5Trace.H1(signal, "WAIT", g_entry.LastReason());
      g_v5Trace.Pipeline(signal, "WAIT_H1", g_entry.LastReason());
      g_diagnostics.Stage(signal, "WAIT_H1", g_entry.LastReason());
      g_diagnostics.EntrySnapshot(signal, g_entry.LastReason());
      g_panel.Render(signal, "WAIT_H1", g_signal.LastReason(), g_entry.LastReason(), g_trade.LastReason());
      return;
   }

   g_v5Trace.H1(signal, "READY", g_entry.LastReason());
   g_v5Trace.Pipeline(signal, "PLAN_READY", g_entry.LastReason());

   if(!g_money.ApplyEqualLots(Symbol(), plan))
   {
      g_v5Trace.Plan(plan, "MONEY_BLOCK", g_money.LastReason());
      g_v5Trace.Pipeline(signal, "MONEY_BLOCK", g_money.LastReason());
      g_diagnostics.Stage(signal, "MONEY_BLOCK", g_money.LastReason());
      g_panel.Render(signal, "MONEY_BLOCK", g_signal.LastReason(), g_entry.LastReason(), g_money.LastReason());
      return;
   }

   if(!g_validator.ValidatePlan(plan))
   {
      g_v5Trace.Plan(plan, "VALIDATOR_BLOCK", g_validator.LastReason());
      g_v5Trace.Pipeline(signal, "PLAN_BLOCK", g_validator.LastReason());
      g_diagnostics.Stage(signal, "PLAN_BLOCK", g_validator.LastReason());
      g_panel.Render(signal, "PLAN_BLOCK", g_signal.LastReason(), g_entry.LastReason(), g_validator.LastReason());
      return;
   }

   if(!g_trade.Validate(plan))
   {
      g_v5Trace.Plan(plan, "TRADE_VALIDATE_BLOCK", g_trade.LastReason());
      g_v5Trace.Pipeline(signal, "PLAN_BLOCK", g_trade.LastReason());
      g_diagnostics.Stage(signal, "PLAN_BLOCK", g_trade.LastReason());
      g_panel.Render(signal, "PLAN_BLOCK", g_signal.LastReason(), g_entry.LastReason(), g_trade.LastReason());
      return;
   }

   g_v5Trace.Plan(plan, "ORDER_REQUEST", Inp_EnableTrading ? "live OrderSend enabled" : "DEBUG mode: OrderSend disabled");
   bool opened = g_trade.Open(plan, Inp_EnableTrading);

   if(opened)
   {
      g_trade.MarkExecuted(signal.key);
      g_signal.MarkExecuted(signal.key);
      g_entry.MarkConsumed(signal.key);
   }

   g_v5Trace.Pipeline(signal,
                      "ORDER_RESULT",
                      (opened ? "OPENED | " : "NOT_OPENED | ") + g_trade.LastReason());

   g_diagnostics.Stage(signal,
                       opened ? "EXECUTED" : "ORDER_BLOCK",
                       g_trade.LastReason());

   g_diagnostics.EntrySnapshot(signal, g_entry.LastReason());

   g_panel.Render(signal,
                  opened ? "EXECUTED" : "ORDER_BLOCK",
                  g_signal.LastReason(),
                  g_entry.LastReason(),
                  g_trade.LastReason());
}
