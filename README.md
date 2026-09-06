# slowagent (cloud runner)

Paper-trading agent for slow Polymarket markets. This repo holds the **code only**; the ledger state lives in a
Cloudflare D1 database and is fetched/written by the daily scheduled run.

Files:
- `slowagent.pyz` — the agent as a single-file Python zipapp (`python3 slowagent.pyz --help`). Built from the `slowagent/` package.
- `config.yaml` — all strategy thresholds (engines A/B/C, sizing, regime gate, liquidity floors).
- `cloud_cycle.sh` — stateless daily cycle: import `state.json` → settle → run → digest → export `handoff.json`.

Daily loop (run by a scheduled cloud task, no local machine involved):
1. fetch these three files from raw.githubusercontent.com
2. read the `ledger` row from D1 → `state.json` (sha256-verified on import)
3. `bash cloud_cycle.sh`
4. write `handoff.json` → D1 (`state` row + a `runs` row with the digest and the day's scan rows)
5. push a short summary notification

Engines (from the 2024–2026 backtest): A = crypto upside-longshot NO (~+14%/trade, regime-gated on BTC 30d momentum);
B = fresh-listing NO at day 2–5 (~+11%/trade, ~52d hold, decaying); C = geo/finance/tech longshot NO (+3–5%).
Paper mode only; the live broker is a stub that raises.
