-- Create Players table
CREATE TABLE betmatrix.players (
    player_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Transactions table
CREATE TABLE betmatrix.bet_transactions (
    transaction_id SERIAL PRIMARY KEY,
    player_id INTEGER REFERENCES betmatrix.players(player_id),
    game_type VARCHAR(50) NOT NULL, -- e.g., 'Poker', 'Slots', 'Blackjack'
    bet_amount DECIMAL(12, 2) NOT NULL,
    bet_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for performance on the CTE's WHERE and GROUP BY clauses
CREATE INDEX idx_bet_timestamp_type ON betmatrix.transactions (bet_timestamp, game_type);