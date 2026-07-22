# TSP Infinity EA — Architecture

## 1. Purpose

TSP Infinity EA is a MetaTrader 4 Expert Advisor implementing the user's
"Three Screens Pro" trading method.

The current repository version is identified in the source as:

- EA property version: `5.010`
- Display version: `5.1 Debug Signal Priority + SAR Direction Fix`
- Main file: `TSPInfinityEA_v4.mq4`

The main file name is historical and does not represent the current release number.

---

## 2. Design principle

The system is divided into independent modules. Each module has one primary
responsibility:

1. D1 determines the market regime and creates high-level conditions.
2. H4 applies the live stochastic regime filter.
3. The signal engine chooses the active strategy signal.
4. H1 waits for the Parabolic SAR entry condition.
5. The money module calculates equal position sizes.
6. The validator verifies signal and trade-plan consistency.
7. The trade module validates, opens and manages positions.
8. The diagnostics modules observe the complete decision pipeline.
9. The panel displays the current state.

Trading logic and diagnostics must remain separate. A diagnostic change must
not change entry, exit, lot, signal-priority or order-management behavior.

---

## 3. Module map

### `TSPInfinityEA_v4.mq4`

Main controller and lifecycle manager.

Responsibilities:

- declares inputs;
- initializes all modules in `OnInit()`;
- executes the pipeline in `OnTick()`;
- updates D1 state only on a new D1 bar;
- evaluates H4 stochastic live on every tick when enabled;
- obtains the current selected signal;
- validates the signal;
- blocks disabled, duplicate or filtered signals;
- requests an H1 trade plan;
- applies money management;
- validates and opens the order series;
- updates diagnostics and the panel.

Current pipeline:

```text
OnTick
  |
  +-- Deep diagnostic snapshot
  |
  +-- Manage open trades
  |
  +-- New D1 bar?
  |     |
  |     +-- D1 evaluation
  |     +-- D1 trace
  |     +-- Signal engine update
  |
  +-- H4 evaluation
  |     |
  |     +-- Live H4 update, or new-H4 update
  |
  +-- Current signal exists?
  |     |
  |     +-- No -> panel: NO_SIGNAL -> return
  |
  +-- H4 trace
  +-- Observe signal
  |
  +-- Validate signal
  |     |
  |     +-- Fail -> SIGNAL_BLOCK -> return
  |
  +-- Signal enabled?
  |     |
  |     +-- No -> SIGNAL_DISABLED -> return
  |
  +-- Signal already executed?
  |     |
  |     +-- Yes -> DUPLICATE_BLOCK -> return
  |
  +-- H4 filter passed?
  |     |
  |     +-- No -> H4_WAIT -> return
  |
  +-- Build H1 plan on SAR touch
  |     |
  |     +-- Fail -> WAIT_H1 -> return
  |
  +-- Apply equal lots
  |     |
  |     +-- Fail -> MONEY_BLOCK -> return
  |
  +-- Validate plan
  |     |
  |     +-- Fail -> PLAN_BLOCK -> return
  |
  +-- Trade validation
  |     |
  |     +-- Fail -> PLAN_BLOCK -> return
  |
  +-- Open order series
        |
        +-- Mark signal and entry as consumed
        +-- ORDER_RESULT
```

---

### `TSP4_Types.mqh`

Shared structures, enums and text conversion helpers.

Expected content includes:

- D1 snapshot structure;
- H4 snapshot structure;
- signal structure;
- trade-plan structure;
- signal types;
- direction values;
- regime values;
- signal-state values;
- helper functions such as:
  - `TSP4_SignalText()`
  - `TSP4_DirectionText()`
  - `TSP4_RegimeText()`

This file is the common contract between all modules.

---

### `TSP4_Indicators.mqh`

Central indicator access layer.

Configured indicators:

- D1 MACD2: `50, 150, 15`;
- H4 Stochastic: `50, 10, 25`;
- Stochastic MA method: Simple;
- Stochastic price field: Close/Close;
- H1 Parabolic SAR:
  - step `0.002`;
  - maximum `0.2`.

Other modules should obtain indicator values through this module whenever
possible instead of duplicating indicator calls.

---

### `TSP4_D1Engine.mqh`

D1 market-regime engine.

Responsibilities:

- evaluate MACD2;
- detect Golden Cross;
- detect Black Cross;
- maintain cross validity;
- evaluate confirmed divergence when the divergence module is enabled;
- evaluate forming divergence when the divergence module is enabled;
- produce `STSP4_D1Snapshot`.

Current divergence module default:

```text
Inp_EnableDivergenceModule = false
```

Signal 3 cross validity:

```text
Inp_CrossValidityDays = 5
```

---

### `TSP4_H4Engine.mqh`

H4 stochastic classification.

Responsibilities:

- read H4 stochastic;
- classify the current zone:
  - oversold;
  - neutral;
  - overbought;
- produce `STSP4_H4Snapshot`.

Current thresholds:

```text
Oversold   < 20
Neutral    20–80
Overbought > 80
```

The main EA can apply H4 values live on every tick using
`Inp_LiveH4Stochastic`.

---

### `TSP4_SignalEngine.mqh`

Signal selection and priority engine.

Responsibilities:

- receive D1 events;
- receive live or new-bar H4 updates;
- create and maintain signals;
- select the current active signal;
- expose the current regime and filter result;
- provide the last decision reason;
- mark signals executed or finished.

Signal types:

1. Confirmed divergence.
2. Forming divergence.
3. Golden/Black Cross.
4. Deep/Normal N with stochastic extreme.
5. Normal n with neutral stochastic.
6. Counter move with opposite stochastic extreme.

Important current rule:

- Signal 3 has priority.
- H4 replacement is bypassed while Signal 3 remains valid.
- Signal 3 expires after five days.

---

### `TSP4_H1Entry.mqh`

H1 Parabolic SAR entry engine.

Responsibilities:

- wait for the required H1 SAR condition;
- lock the relevant penultimate SAR point;
- verify direction;
- create the three-position trade plan;
- prevent reuse of a consumed entry.

Direction rule:

```text
BUY  -> SAR below price
SELL -> SAR above price
```

Entry concept:

- price touches the locked penultimate H1 SAR point;
- the protective SAR point must be on the correct side;
- the plan uses the SAR gap for stop and target construction.

Trade targets:

- TP1 = 50% of the SAR gap;
- TP2 = 100% of the SAR gap;
- the third position is managed by SAR.

The entry engine must expose a precise `LastReason()` for every wait or block.

---

### `TSP4_Money.mqh`

Money-management module.

Responsibilities:

- calculate risk-based volume;
- use balance or equity according to configuration;
- divide the total position into three equal lots;
- normalize volume to broker constraints.

Current input:

```text
Inp_TotalRiskPercent = 1.0
Inp_UseEquity = true
```

The three positions must have equal volume.

---

### `TSP4_Validator.mqh`

Consistency and safety validation.

Responsibilities:

- validate signal fields;
- validate direction and state;
- validate trade-plan prices;
- reject invalid stop/target placement;
- expose the exact failure reason.

The validator must not silently repair a malformed plan. It should reject it
and report why.

---

### `TSP4_Trade.mqh`

Order validation, execution and management.

Responsibilities:

- spread validation;
- duplicate-series protection;
- one-active-series-per-symbol protection;
- three-order execution;
- mark signal keys as executed;
- manage existing orders;
- update stops using the penultimate SAR point;
- manage TP1, TP2 and SAR exit.

Current safety input:

```text
Inp_EnableTrading = false
```

When false, the EA performs analysis without sending real/tester orders.

---

### `TSP4_Panel.mqh`

Visual status panel.

Expected information:

- balance/equity;
- lot and risk;
- active trend/regime;
- active signal;
- spread;
- pipeline stage;
- last signal reason;
- last entry reason;
- last trade reason.

The panel is informational only and must not control strategy behavior.

---

### `TSP4_Diagnostics.mqh`

High-level pipeline diagnostics.

Current responsibilities:

- detect a newly observed signal;
- track first-seen time;
- calculate H1 bars spent waiting;
- print state changes;
- print entry snapshots.

Current issue:

`EntrySnapshot()` can be called repeatedly from the `WAIT_H1` branch in
`OnTick()`, so terminal logs can grow rapidly even when the stage has not
changed.

---

### `TSP4_DeepDiagnostics.mqh`

Raw-indicator telemetry.

Current behavior:

- called at the beginning of every `OnTick()`;
- throttled by seconds;
- prints direct D1 MACD2 values;
- prints direct H4 stochastic values;
- prints H1 SAR and price values.

Current default configuration:

```text
Inp_DiagnosticEveryTick = true
Inp_DiagnosticThrottleSeconds = 1
```

Despite the input name, the module receives the value as an enable flag.
With one-second throttling, a long tick-model backtest can still produce a very
large terminal log.

This module is intended for short diagnostic tests only.

---

### `TSP5_DebugTrace.mqh`

CSV decision trace.

Current CSV file:

```text
TSP_Infinity_v5_Debug_Trace.csv
```

Current columns:

```text
terminal_time;symbol;stage;signal_key;detail
```

Current trace categories:

- `D1_DECISION`
- `H4_DECISION`
- `H1_DECISION`
- `PIPELINE`
- `TRADE_PLAN`

The class already suppresses identical strings with:

- `m_lastD1`
- `m_lastH4`
- `m_lastPipeline`
- `m_lastH1`

However, several values in the constructed strings change continuously:

- Bid;
- Ask;
- current H1 high;
- current H1 low;
- stochastic value;
- reason text in some states.

Therefore a state can remain logically unchanged while the detail string
changes on nearly every tick. This defeats duplicate suppression and creates
very large CSV files.

`FileFlush()` is also called after every row. This is safe for crash recovery,
but expensive during long backtests.

---

## 4. Signal rules

### Signal 1 — Confirmed divergence

- Disabled when the divergence module is off.
- D1 confirmed bearish divergence -> SELL search.
- D1 confirmed bullish divergence -> BUY search.
- One entry per divergence.
- H4 is bypassed in the D1-to-H1 variant.

### Signal 2 — Forming divergence

- Disabled when the divergence module is off.
- Forming bearish divergence requires H4 stochastic overbought.
- Forming bullish divergence requires H4 stochastic oversold.
- Entry occurs through the H1 SAR module.

### Signal 3 — Golden/Black Cross

- Golden Cross -> BUY regime.
- Black Cross -> SELL regime.
- H4 is bypassed.
- Valid for five days.
- Has priority over lower-priority N signals.

### Signal 4 — Deep/Normal N

- After Golden Cross:
  - BUY when H4 stochastic is oversold.
- After Black Cross:
  - SELL when H4 stochastic is overbought.
- Signal is cancelled when stochastic leaves the required extreme zone.

### Signal 5 — Normal n

- After Golden Cross:
  - BUY when H4 stochastic is neutral.
- After Black Cross:
  - SELL when H4 stochastic is neutral.
- Multiple trades may be allowed while the regime remains valid.
- The signal pauses or cancels according to the MACD2 histogram-color rule.

### Signal 6 — Counter move

- After Golden Cross:
  - SELL while H4 stochastic is overbought.
  - BUY signals are temporarily invalid.
- After Black Cross:
  - BUY while H4 stochastic is oversold.
  - SELL signals are temporarily invalid.
- The original-direction signals resume when stochastic leaves the extreme.

---

## 5. State model for v5.2 diagnostics

The diagnostic state model should describe the pipeline without altering it.

Recommended states:

```text
IDLE
SIGNAL_DETECTED
SIGNAL_BLOCKED
SIGNAL_DISABLED
DUPLICATE_BLOCKED
WAIT_H4
WAIT_H1
ENTRY_READY
MONEY_BLOCKED
PLAN_BLOCKED
ORDER_REQUESTED
ORDER_OPENED
ORDER_BLOCKED
SIGNAL_FINISHED
```

Recommended reject codes:

```text
NONE
NO_SIGNAL
INVALID_SIGNAL
SIGNAL_DISABLED
SIGNAL_EXPIRED
ALREADY_EXECUTED
H4_FILTER_WAIT
SAR_TOUCH_WAIT
SAR_DIRECTION_INVALID
SAR_PROTECTIVE_FLIP_WAIT
SPREAD_TOO_HIGH
ACTIVE_SERIES_EXISTS
MONEY_CALCULATION_FAILED
INVALID_STOP
INVALID_TARGET
INVALID_VOLUME
ORDER_SEND_FAILED
TRADING_DISABLED
```

Reject codes should be stable machine-readable values. Human-readable detail
can be stored in a separate field.

---

## 6. Logging policy for v5.2

### Event log

Write only when at least one of these changes:

- signal key;
- selected signal type;
- direction;
- pipeline state;
- reject code;
- H4 zone;
- locked SAR reference;
- order result.

### Bar snapshot log

Write at most once per:

- new D1 bar;
- new H4 bar;
- new H1 bar.

### Tick telemetry

Tick telemetry must be optional and disabled by default.

Recommended input:

```text
Inp_V52TickTelemetry = false
```

It should be used only for short targeted tests.

### File flushing

Recommended behavior:

- flush on order request/result;
- flush on deinitialization;
- optional periodic flush;
- do not flush after every ordinary wait-state row.

### File naming

Recommended default:

```text
TSP_Infinity_v5_2_Event_Trace.csv
```

This prevents accidental mixing with old v5.1 data.

---

## 7. v5.2 scope

v5.2 is a diagnostics-only release.

Allowed changes:

- event-based logging;
- new-bar snapshots;
- stable reject codes;
- per-signal counters;
- final diagnostic summary;
- safer CSV flushing;
- new diagnostic inputs;
- updated version text.

Not allowed in v5.2:

- changes to signal priority;
- changes to D1/H4/H1 rules;
- changes to SAR touch logic;
- changes to stop or target formulas;
- changes to lot calculation;
- changes to trade management;
- changes to order timing.

This separation is essential so that v5.2 backtest trading results remain
comparable with v5.1.

---

## 8. Test acceptance criteria

A v5.2 build is accepted only when:

1. MetaEditor reports zero compilation errors.
2. Any warnings are documented and reviewed.
3. The same test period and inputs produce the same trades as v5.1.
4. Net profit, trade count and trade timestamps match v5.1, except for
   differences caused solely by explicit tester settings.
5. The CSV contains no repeated identical wait-state events.
6. A multi-year test does not create a multi-gigabyte CSV.
7. Every blocked plan has a stable reject code.
8. The final summary totals match the event rows.
9. Trading remains disabled by default.
10. Old v5.1 CSV files are not appended to or reused.

---

## 9. Version workflow

### `main`

Contains only tested stable versions.

### Development branch

Recommended branch:

```text
feature/v5.2-debug-engine
```

### Suggested commit sequence

```text
docs: add EA architecture and v5.2 scope
refactor: add event-based trace state
feat: add stable reject codes
feat: add signal and reject counters
perf: reduce CSV flush frequency
chore: update version to 5.2
```

Each commit should be independently understandable and should not combine
diagnostic changes with trading-rule changes.

---

## 10. Known current risks

1. `TSP4_DeepDiagnostics.Snapshot()` runs from `OnTick()` and can produce
   extensive terminal output.
2. H4 is intentionally evaluated live on every tick. Diagnostic suppression
   must not stop that strategy update.
3. H1 trace strings contain live prices and therefore change frequently even
   while the logical state remains `WAIT`.
4. Pipeline trace suppression compares the complete detail string rather than
   a stable state key.
5. `FileFlush()` after every CSV row can slow long backtests.
6. The main source file has a historical v4 name while the actual source
   version is v5.1. This can confuse release tracking.
7. The repository currently has no architecture or release documentation.

---

## 11. Next implementation task

Implement a diagnostic event key composed of:

```text
signal_key
pipeline_state
reject_code
signal_type
direction
H4_zone
locked_SAR_reference
```

Write a CSV row only when this key changes, or when a mandatory event occurs:

- signal created;
- plan ready;
- order requested;
- order result;
- signal cancelled/finished;
- EA deinitialization summary.

This is the first code change for v5.2.
