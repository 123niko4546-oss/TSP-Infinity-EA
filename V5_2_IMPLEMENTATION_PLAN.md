# TSP Infinity EA v5.2 — Implementation Plan

## Goal

Replace noisy tick-dependent diagnostics with event-based diagnostics while
preserving all v5.1 trading behavior.

## Files expected to change

- `TSPInfinityEA_v4.mq4`
- `TSP5_DebugTrace.mqh`
- `TSP4_Diagnostics.mqh`
- optionally `TSP4_Types.mqh` for shared diagnostic enums/constants
- `ARCHITECTURE.md`
- `CHANGELOG.md`

## Phase 1 — Stable event identity

Create stable machine-readable pipeline stages and reject codes.

The logger must compare stable fields, not full messages containing Bid, Ask,
High0, Low0 or current stochastic decimals.

## Phase 2 — Event-based CSV

CSV fields:

```text
terminal_time
bar_time
symbol
signal_key
signal_type
direction
pipeline_state
reject_code
h4_zone
detail
```

Mandatory events bypass duplicate suppression:

- signal created;
- plan ready;
- order request;
- order result;
- signal finished;
- deinitialization summary.

## Phase 3 — New-bar snapshots

D1 snapshot: once per new D1 bar.

H4 snapshot: once per new H4 bar, while the H4 engine may still update live.

H1 snapshot: once per new H1 bar, plus mandatory entry events.

## Phase 4 — Counters

Per signal type:

- detected;
- selected;
- traded;
- blocked;
- expired.

Per reject code:

- total count.

Print and write a final summary in `OnDeinit()`.

## Phase 5 — Regression test

Run v5.1 and v5.2 with identical:

- symbol;
- timeframe;
- dates;
- model;
- spread;
- inputs.

Required result:

- identical trade count;
- identical entries and exits;
- identical lot sizes;
- identical net result;
- dramatically smaller diagnostic files.

## Non-goals

v5.2 must not change:

- signal rules;
- SAR entry rules;
- signal priority;
- lot calculation;
- SL/TP;
- trailing logic;
- order-management behavior.
