-- Japan macro transmission analysis
-- Nikkei 225, USD/JPY, BoJ overnight call rate | 1990-2026
-- Sam Brewer

-- check that the date joins work
SELECT 
    n.Date,
    n.Close AS nikkei_close,
    u.Close AS usdjpy_close
FROM nikkei n
JOIN usdjpy u ON n.Date = u.Date
ORDER BY n.Date DESC
LIMIT 20;


-- 30-day rolling average to smooth out daily noise
SELECT
    Date,
    Close AS nikkei_close,
    AVG(Close) OVER (
        ORDER BY Date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) AS nikkei_30day_avg
FROM nikkei
ORDER BY Date DESC
LIMIT 50;


-- find every month where BoJ moved rates
-- LAG() pulls the prior month's rate so we can diff them
WITH rate_changes AS (
    SELECT
        observation_date,
        IRSTCI01JPM156N AS rate,
        LAG(IRSTCI01JPM156N) OVER (ORDER BY observation_date) AS prev_rate,
        IRSTCI01JPM156N - LAG(IRSTCI01JPM156N) OVER (ORDER BY observation_date) AS rate_change
    FROM boj_rate
)
SELECT *
FROM rate_changes
WHERE rate_change != 0
ORDER BY observation_date;


-- how did Nikkei and USD/JPY move in the 10 days after each decision?
-- JULIANDAY lets us do the date range join cleanly
WITH rate_changes AS (
    SELECT
        observation_date,
        IRSTCI01JPM156N - LAG(IRSTCI01JPM156N) OVER (ORDER BY observation_date) AS rate_change
    FROM boj_rate
),
filtered_changes AS (
    SELECT * FROM rate_changes WHERE rate_change != 0
),
market_response AS (
    SELECT
        r.observation_date AS boj_date,
        r.rate_change,
        n.Date AS market_date,
        n.Close AS nikkei_close,
        u.Close AS usdjpy_close,
        JULIANDAY(n.Date) - JULIANDAY(r.observation_date) AS days_after
    FROM filtered_changes r
    JOIN nikkei n ON JULIANDAY(n.Date) BETWEEN JULIANDAY(r.observation_date) AND JULIANDAY(r.observation_date) + 10
    JOIN usdjpy u ON u.Date = n.Date
),
baseline AS (
    SELECT boj_date, rate_change,
        FIRST_VALUE(nikkei_close) OVER (PARTITION BY boj_date ORDER BY days_after) AS nikkei_base,
        FIRST_VALUE(usdjpy_close) OVER (PARTITION BY boj_date ORDER BY days_after) AS usdjpy_base,
        nikkei_close, usdjpy_close, days_after
    FROM market_response
)
SELECT
    boj_date,
    ROUND(rate_change, 4) AS rate_change,
    ROUND(AVG((nikkei_close - nikkei_base) / nikkei_base * 100), 2) AS avg_nikkei_pct_change,
    ROUND(AVG((usdjpy_close - usdjpy_base) / usdjpy_base * 100), 2) AS avg_usdjpy_pct_change
FROM baseline
GROUP BY boj_date
ORDER BY boj_date;


-- pearson correlation between rate changes and market response
-- SQLite doesn't have CORR() so built it manually
-- filtering to >=25bps only — smaller moves are noise
WITH rate_changes AS (
    SELECT
        observation_date,
        IRSTCI01JPM156N - LAG(IRSTCI01JPM156N) OVER (ORDER BY observation_date) AS rate_change
    FROM boj_rate
),
filtered_changes AS (
    SELECT * FROM rate_changes WHERE ABS(rate_change) >= 0.25
),
market_response AS (
    SELECT
        r.observation_date,
        r.rate_change,
        AVG(n.Close) AS avg_nikkei,
        AVG(u.Close) AS avg_usdjpy
    FROM filtered_changes r
    JOIN nikkei n ON JULIANDAY(n.Date) BETWEEN JULIANDAY(r.observation_date) AND JULIANDAY(r.observation_date) + 10
    JOIN usdjpy u ON u.Date = n.Date
    GROUP BY r.observation_date, r.rate_change
),
stats AS (
    SELECT
        AVG(rate_change) AS avg_r,
        AVG(avg_nikkei) AS avg_n,
        AVG(avg_usdjpy) AS avg_u,
        AVG(rate_change * avg_nikkei) AS avg_rn,
        AVG(rate_change * avg_usdjpy) AS avg_ru,
        AVG(rate_change * rate_change) AS avg_r2,
        AVG(avg_nikkei * avg_nikkei) AS avg_n2,
        AVG(avg_usdjpy * avg_usdjpy) AS avg_u2
    FROM market_response
)
SELECT
    ROUND((avg_rn - avg_r * avg_n) / (SQRT(avg_r2 - avg_r*avg_r) * SQRT(avg_n2 - avg_n*avg_n)), 4) AS corr_rate_vs_nikkei,
    ROUND((avg_ru - avg_r * avg_u) / (SQRT(avg_r2 - avg_r*avg_r) * SQRT(avg_u2 - avg_u*avg_u)), 4) AS corr_rate_vs_usdjpy
FROM stats;