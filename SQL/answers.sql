--1. Write a SQL query to find the top 5 players by total bet amount in the past 30 days, broken down by game type. 

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
        RANK() OVER (PARTITION BY game_type ORDER BY total_bet_amount DESC) as player_position
    FROM player_totals 
)
SELECT player_position,game_type , username,total_bet_amount
FROM ranked_players r
join betmatrix.players p on p.player_id = r.player_id
WHERE player_position <= 5
order by game_type, player_position asc;

--- 2. Table Expressions (CTEs) to identify players who exhibit potential problem gambling behavior by: 
-- * Finding players whose daily betting amount has increased by at least 50% for three consecutive days 
-- * Showing their average bet amount before and during this pattern
-- * Sorting results by the percentage increase in betting amount 

WITH bets_by_day AS ( 
    SELECT  
        player_id,  
        CAST(bet_timestamp AS DATE) as bet_date, 
        SUM(bet_amount) as daily_total 
    FROM betmatrix.bet_transactions 
    GROUP BY player_id, CAST(bet_timestamp AS DATE) 
), 
bets_over_3_days AS ( 
    SELECT  
        player_id, 
        bet_date, 
        daily_total, 
        LAG(daily_total, 1) OVER (PARTITION BY player_id ORDER BY bet_date) as prev_day_1, 
        LAG(daily_total, 2) OVER (PARTITION BY player_id ORDER BY bet_date) as prev_day_2, 
        LAG(daily_total, 3) OVER (PARTITION BY player_id ORDER BY bet_date) as prev_day_3 
    FROM bets_by_day  
), 
player_pattern_over_3_days AS ( 
    SELECT player_id, bet_date as pattern_end_date 
    FROM bets_over_3_days  
    WHERE daily_total >= prev_day_1 * 1.5 
      AND prev_day_1 >= prev_day_2 * 1.5 
      AND prev_day_2 >= prev_day_3 * 1.5 
) 
 
SELECT  
    p.player_id, 
    AVG(CASE WHEN d.bet_date BETWEEN p.pattern_end_date - INTERVAL '2 days' AND 
p.pattern_end_date  
             THEN d.daily_total END) as avg_during_pattern, 
    AVG(CASE WHEN d.bet_date < p.pattern_end_date - INTERVAL '2 days'  
             THEN d.daily_total END) as avg_before_pattern, 
    ((AVG(CASE WHEN d.bet_date BETWEEN p.pattern_end_date - INTERVAL '2 days' AND 
p.pattern_end_date THEN d.daily_total END) /  
      NULLIF(AVG(CASE WHEN d.bet_date < p.pattern_end_date - INTERVAL '2 days' THEN 
d.daily_total END), 0)) - 1) * 100 as pct_increase 
FROM player_pattern_over_3_days p 
JOIN bets_by_day d ON p.player_id = d.player_id 
GROUP BY p.player_id 
ORDER BY pct_increase DESC; 