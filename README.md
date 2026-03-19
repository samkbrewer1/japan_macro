# Japan Macro Transmission Analysis

SQL analysis of Bank of Japan monetary policy and its transmission effects 
across Japanese equity and FX markets using 36 years of daily data (1990–2026).

## Data Sources
- Nikkei 225 daily prices (Stooq)
- USD/JPY daily spot rate (Stooq)
- BoJ overnight call rate, monthly (FRED: IRSTCI01JPM156N)

## What the analysis does
- Identifies all BoJ rate change events using LAG() window function
- Computes 30-day rolling average on Nikkei to smooth daily noise
- Measures Nikkei and USD/JPY % moves in 10 trading days following each decision
- Calculates Pearson correlation between significant rate changes (>=25bps) and market response

## Key findings
- August 2024 BoJ rate hike of 15bps produced an 8.16% Nikkei decline and 
  1.94% USD/JPY drop in the subsequent 10 trading days
- Across 14 significant policy decisions since 1990, correlation between rate 
  changes and Nikkei movements was 0.51 — positive because most major decisions 
  were cuts during stimulus periods that coincided with equity rallies
- The 2024 hike suggests an asymmetric relationship between rate hikes and cuts

## Tools
SQLite, DB Browser for SQLite
