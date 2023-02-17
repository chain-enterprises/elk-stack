with captured_transactions AS (
    SELECT calendar_dates.date
        , coalesce(sum(t.amount_cents) / 100, 0) 'amount'
        , coalesce(sum(if(t.id is not null, 1, 0)),0)  'total'
        , coalesce(SUM(CASE
            WHEN cc_type = "Visa" THEN (30 + (amount_cents * 0.0374))
            WHEN cc_type = "MasterCard" THEN (35 + (amount_cents * 0.0389))
            WHEN cc_type = "Discover" THEN (30 + (amount_cents * 0.0504))
            WHEN cc_type = "American Express" THEN (10 + (amount_cents * 0.0264))
        END), 0) / 100  'card_fees'
    FROM calendar_dates
    LEFT JOIN nmi_transactions t
    ON calendar_dates.date = date(t.captured_at)
    AND t.status IN ('complete','pendingsettlement')
    AND t.reference_transaction_id <> ''
    GROUP BY calendar_dates.date WITH ROLLUP)
, settled_transactions AS (
    SELECT calendar_dates.date
        , coalesce(coalesce(sum(t.amount_cents) / 100, 0), 0) 'amount'
        , coalesce(sum(if(t.id is not null, 1, 0)), 0) 'total'
        , coalesce(sum(CASE
            WHEN cc_type = "Visa" THEN (30 + (amount_cents * 0.0374))
            WHEN cc_type = "MasterCard" THEN (35 + (amount_cents * 0.0389))
            WHEN cc_type = "Discover" THEN (30 + (amount_cents * 0.0504))
            WHEN cc_type = "American Express" THEN (10 + (amount_cents * 0.0264))
        END) / 100, 0)  'card_fees'
    FROM calendar_dates
    LEFT JOIN nmi_transactions t
    ON calendar_dates.date = date(t.settled_at)
    AND t.status IN ('complete','pendingsettlement')
    AND t.reference_transaction_id <> ''
    GROUP BY calendar_dates.date WITH ROLLUP
)
SELECT coalesce(captured_transactions.date, 'TOTAL') 'date'
, sum(captured_transactions.amount) 'captured_amount'
, sum(captured_transactions.total) 'captured_count'
, sum(captured_transactions.card_fees) 'captured_card_fees'
, sum(settled_transactions.amount) 'settled_amount'
, sum(settled_transactions.total) 'settled_count'
, sum(settled_transactions.card_fees) 'settled_card_fees'

FROM calendar_dates
JOIN captured_transactions
ON calendar_dates.date = captured_transactions.date
JOIN settled_transactions
ON settled_transactions.date = captured_transactions.date
WHERE calendar_dates.date BETWEEN '2023-02-01 00:00:00' AND "2023-02-28 23:59:59"
GROUP BY captured_transactions.date WITH ROLLUP
