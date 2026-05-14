-- 1. Write a SQL query to find the top 5 players by total bet amount in the past 30 days, broken down by game type.

WITH player_totals AS (
    SELECT
        player_id,
        game_type,
        SUM(bet_amount) AS total_bet_amount
    FROM betmatrix.bet_transactions
    WHERE bet_timestamp >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY player_id, game_type
),
ranked_players AS (
    SELECT
        player_id,
        game_type,
        total_bet_amount,
        RANK() OVER (PARTITION BY game_type ORDER BY total_bet_amount DESC) AS player_position
    FROM player_totals
)
SELECT
    r.player_position,
    r.game_type,
    p.username,
    r.total_bet_amount
FROM ranked_players AS r
JOIN betmatrix.players AS p
    ON p.player_id = r.player_id
WHERE r.player_position <= 5
ORDER BY r.game_type,
         r.player_position ASC;

-- 2. Table Expressions (CTEs) to identify players who exhibit potential problem gambling behavior by:
--    * Finding players whose daily betting amount has increased by at least 50% for three consecutive days
--    * Showing their average bet amount before and during this pattern
--    * Sorting results by the percentage increase in betting amount

WITH bets_by_day AS (
    SELECT
        player_id,
        CAST(bet_timestamp AS DATE) AS bet_date,
        SUM(bet_amount) AS daily_total
    FROM betmatrix.bet_transactions
    GROUP BY player_id, CAST(bet_timestamp AS DATE)
),
bets_over_3_days AS (
    SELECT
        player_id,
        bet_date,
        daily_total,
        LAG(daily_total, 1) OVER (PARTITION BY player_id ORDER BY bet_date) AS prev_day_1,
        LAG(daily_total, 2) OVER (PARTITION BY player_id ORDER BY bet_date) AS prev_day_2,
        LAG(daily_total, 3) OVER (PARTITION BY player_id ORDER BY bet_date) AS prev_day_3
    FROM bets_by_day
),
player_pattern_over_3_days AS (
    SELECT
        player_id,
        bet_date AS pattern_end_date
    FROM bets_over_3_days
    WHERE daily_total >= prev_day_1 * 1.5
      AND prev_day_1 >= prev_day_2 * 1.5
      AND prev_day_2 >= prev_day_3 * 1.5
)
SELECT
    p.player_id,
    AVG(CASE
            WHEN d.bet_date BETWEEN p.pattern_end_date - INTERVAL '2 days' AND p.pattern_end_date
            THEN d.daily_total
        END) AS avg_during_pattern,
    AVG(CASE
            WHEN d.bet_date < p.pattern_end_date - INTERVAL '2 days'
            THEN d.daily_total
        END) AS avg_before_pattern,
    ((AVG(CASE
               WHEN d.bet_date BETWEEN p.pattern_end_date - INTERVAL '2 days' AND p.pattern_end_date
               THEN d.daily_total
           END) /
      NULLIF(AVG(CASE
               WHEN d.bet_date < p.pattern_end_date - INTERVAL '2 days'
               THEN d.daily_total
           END), 0)) - 1) * 100 AS pct_increase
FROM player_pattern_over_3_days AS p
JOIN bets_by_day AS d
    ON p.player_id = d.player_id
GROUP BY p.player_id
ORDER BY pct_increase DESC;
 