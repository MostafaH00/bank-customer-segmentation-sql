-- ============================================================
-- BANK CUSTOMER ANALYTICS - SQL ANALYSIS
-- ============================================================
-- This file contains business-oriented SQL analyses performed
-- on the cleaned banking dataset.
--
-- Main SQL concepts demonstrated:
--   - Aggregations
--   - GROUP BY / HAVING
--   - INNER JOIN / LEFT JOIN
--   - Subqueries
--   - Common Table Expressions (CTEs)
--   - CASE WHEN
--   - COALESCE
--   - DATE_TRUNC
--   - Percentiles
--   - Window functions
--   - RANK
--   - LAG
--
-- All analyses are performed on the cleaned tables.
-- ============================================================



-- ============================================================
-- 1. GLOBAL BANK KPIs
-- ============================================================
-- Business question:
-- How many customers, accounts, loans, transactions and branches
-- are present in the cleaned banking dataset?
--
-- Scalar subqueries are used to return all KPIs in a single row.

SELECT
    (SELECT COUNT(*) FROM customers_clean)    AS customers_count,
    (SELECT COUNT(*) FROM accounts_clean)     AS accounts_count,
    (SELECT COUNT(*) FROM loans_clean)        AS loans_count,
    (SELECT COUNT(*) FROM transactions_clean) AS transactions_count,
    (SELECT COUNT(*) FROM branches_clean)     AS branches_count;



-- ============================================================
-- 2. CUSTOMER DISTRIBUTION BY BRANCH
-- ============================================================
-- Business question:
-- How many customers are associated with each branch?
--
-- LEFT JOIN is used so that branches with no customers would
-- still appear with a customer count of zero.

SELECT
    b.branch_id,
    b.branch_name,
    COUNT(c.customer_id) AS customers_count
FROM branches_clean b
LEFT JOIN customers_clean c
    ON c.branch_id = b.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY
    b.branch_id;



-- ============================================================
-- 3. ACCOUNT BALANCES BY BRANCH
-- ============================================================
-- Business question:
-- What are the total and average account balances for each branch?
--
-- SUM measures the total balance managed by the branch,
-- while AVG gives the average balance per account.

SELECT
    b.branch_id,
    b.branch_name,
    SUM(a.balance) AS total_balance,
    ROUND(AVG(a.balance), 2) AS avg_balance
FROM branches_clean b
LEFT JOIN accounts_clean a
    ON a.branch_id = b.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY
    b.branch_id;



-- ============================================================
-- 4. ACCOUNT TYPE DISTRIBUTION
-- ============================================================
-- Business question:
-- Which types of bank accounts are the most common?
--
-- Accounts are grouped by account_type and ranked by frequency.

SELECT
    account_type,
    COUNT(*) AS account_count
FROM accounts_clean
GROUP BY
    account_type
ORDER BY
    account_count DESC;



-- ============================================================
-- 5. TRANSACTION VOLUME BY TYPE
-- ============================================================
-- Business question:
-- Which transaction types generate the most activity?
--
-- Two measures are considered:
--   1. Number of transactions
--   2. Total monetary amount

SELECT
    transaction_type,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_amount
FROM transactions_clean
GROUP BY
    transaction_type
ORDER BY
    transaction_count DESC;



-- ============================================================
-- 6. TRANSACTION CHANNEL USAGE
-- ============================================================
-- Business question:
-- Which transaction channels are used most frequently?
--
-- This can help identify whether customers primarily use
-- digital, ATM or other banking channels.

SELECT
    channel,
    COUNT(*) AS transaction_count
FROM transactions_clean
GROUP BY
    channel
ORDER BY
    transaction_count DESC;



-- ============================================================
-- 7. TOP 10 CUSTOMERS BY TOTAL BALANCE
-- ============================================================
-- Business question:
-- Which customers hold the highest total balance across all
-- of their accounts?
--
-- Balances from multiple accounts belonging to the same customer
-- are aggregated before ranking the customers.

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    SUM(a.balance) AS total_balance
FROM customers_clean c
JOIN accounts_clean a
    ON c.customer_id = a.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
HAVING SUM(a.balance) IS NOT NULL
ORDER BY total_balance DESC
LIMIT 10;


-- ============================================================
-- 8. CUSTOMERS WITH MULTIPLE ACCOUNTS
-- ============================================================
-- Business question:
-- Which customers hold more than one bank account?
--
-- HAVING is used because the filtering condition depends on
-- an aggregated value: the number of accounts per customer.

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(a.account_id) AS account_count
FROM customers_clean c
JOIN accounts_clean a
    ON c.customer_id = a.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
HAVING
    COUNT(a.account_id) > 1
ORDER BY
    account_count DESC;



-- ============================================================
-- 9. AVERAGE LOAN AMOUNT BY LOAN TYPE
-- ============================================================
-- Business question:
-- Which types of loans have the highest average loan amounts?
--
-- NULL loan amounts are automatically ignored by AVG.

SELECT
    loan_type,
    ROUND(AVG(loan_amount), 2) AS avg_loan_amount
FROM loans_clean
GROUP BY
    loan_type
ORDER BY
    avg_loan_amount DESC;



-- ============================================================
-- 10. TOTAL LOAN AMOUNT BY BRANCH
-- ============================================================
-- Business question:
-- Which branches are associated with the largest total amount
-- of loans granted to their customers?
--
-- The CTE first associates customers with their branches.
-- Loans are then joined to those customers and aggregated
-- at branch level.

WITH customers_branches AS (
    SELECT
        b.branch_id,
        b.branch_name,
        c.customer_id
    FROM branches_clean b
    JOIN customers_clean c
        ON b.branch_id = c.branch_id
)
SELECT
    cb.branch_id,
    cb.branch_name,
    SUM(l.loan_amount) AS total_loan_amount
FROM loans_clean l
JOIN customers_branches cb
    ON l.customer_id = cb.customer_id
GROUP BY
    cb.branch_id,
    cb.branch_name
ORDER BY
    total_loan_amount DESC;



-- ============================================================
-- 11. MONTHLY TRANSACTION ACTIVITY
-- ============================================================
-- Business question:
-- How does transaction activity evolve over time?
--
-- DATE_TRUNC('month', ...) groups individual dates into months.
-- For each month, both transaction frequency and monetary volume
-- are calculated.

SELECT
    DATE_TRUNC('month', transaction_date) AS month,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_amount
FROM transactions_clean
WHERE
    transaction_date IS NOT NULL
GROUP BY
    DATE_TRUNC('month', transaction_date)
ORDER BY
    month;



-- ============================================================
-- 12. MOST ACTIVE ACCOUNTS
-- ============================================================
-- Business question:
-- Which accounts generate the highest transaction activity?
--
-- Accounts are primarily ranked by transaction frequency.
-- Total amount is used as a secondary ordering criterion.

SELECT
    account_id,
    COUNT(transaction_id) AS transaction_count,
    SUM(amount) AS total_amount
FROM transactions_clean
WHERE
    account_id IS NOT NULL
GROUP BY
    account_id
ORDER BY
    transaction_count DESC,
    total_amount DESC;



-- ============================================================
-- 13. HIGHEST-BALANCE CUSTOMER WITHIN EACH BRANCH
-- ============================================================
-- Business question:
-- Who is the highest-value customer in each branch based on
-- total account balance?
--
-- Step 1:
-- Aggregate account balances by customer and branch.
--
-- Step 2:
-- Use RANK() with PARTITION BY to independently rank customers
-- inside each branch.
--
-- NULLS LAST prevents customers with unknown total balances
-- from being ranked ahead of customers with valid balances.

WITH customer_balance AS (
    SELECT
        customer_id,
        branch_id,
        SUM(balance) AS total_balance
    FROM accounts_clean
    WHERE
        customer_id IS NOT NULL
        AND branch_id IS NOT NULL
    GROUP BY
        customer_id,
        branch_id
),
ranked_customers AS (
    SELECT
        customer_id,
        branch_id,
        total_balance,
        RANK() OVER (
            PARTITION BY branch_id
            ORDER BY total_balance DESC NULLS LAST
        ) AS balance_rank
    FROM customer_balance
)
SELECT
    customer_id,
    branch_id,
    total_balance,
    balance_rank
FROM ranked_customers
WHERE
    balance_rank = 1
ORDER BY
    branch_id;



-- ============================================================
-- 14. CUSTOMER VALUE SEGMENTATION
-- ============================================================
-- Business question:
-- How can customers be segmented according to their total
-- account balance?
--
-- Instead of choosing arbitrary thresholds, the balance
-- distribution is first analysed using quartiles.
--
-- Q1  = bottom 25%
-- Q2  = median
-- Q3  = top 25% threshold



-- ------------------------------------------------------------
-- 14.1 Determine balance quartiles
-- ------------------------------------------------------------

WITH customer_balance AS (
    SELECT
        customer_id,
        SUM(balance) AS total_balance
    FROM accounts_clean
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
)
SELECT
    PERCENTILE_CONT(0.25)
        WITHIN GROUP (ORDER BY total_balance) AS q1,

    PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY total_balance) AS median,

    PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY total_balance) AS q3
FROM customer_balance
WHERE
    total_balance IS NOT NULL;



-- ------------------------------------------------------------
-- 14.2 Segment customers using data-driven thresholds
-- ------------------------------------------------------------

WITH customer_balance AS (
    SELECT
        customer_id,
        SUM(balance) AS total_balance
    FROM accounts_clean
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),
balance_thresholds AS (
    SELECT
        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY total_balance) AS q1,
        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY total_balance) AS q3
    FROM customer_balance
    WHERE total_balance IS NOT NULL
)
SELECT
    cb.customer_id,
    cb.total_balance,
    CASE
        WHEN cb.total_balance IS NULL THEN 'Unknown'
        WHEN cb.total_balance >= bt.q3 THEN 'High Value'
        WHEN cb.total_balance >= bt.q1 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_segment
FROM customer_balance cb
CROSS JOIN balance_thresholds bt
ORDER BY
    cb.total_balance DESC NULLS LAST,
    cb.customer_id;



-- ============================================================
-- 15. HIGH-VALUE CUSTOMERS WITH LOW TRANSACTION ACTIVITY
-- ============================================================
-- Business question:
-- Which high-value customers hold significant balances but show
-- relatively low transaction activity?
--
-- This type of customer could be relevant for CRM campaigns,
-- engagement strategies or cross-selling opportunities.
--
-- Thresholds are based on the observed data distribution:
--
-- High Value:
--     total_balance >= dynamically calculated balance Q3
--
-- Low Activity:
--     transaction_count <= dynamically calculated activity Q1



-- ------------------------------------------------------------
-- 15.1 Determine transaction-frequency quartiles
-- ------------------------------------------------------------
-- COALESCE converts a missing transaction count to zero.
WITH customer_transactions AS (
    SELECT
        a.customer_id,
        COUNT(t.transaction_id) AS transaction_count
    FROM accounts_clean a
    LEFT JOIN transactions_clean t
        ON a.account_id = t.account_id
    WHERE
        a.customer_id IS NOT NULL
    GROUP BY
        a.customer_id
)
SELECT
    PERCENTILE_CONT(0.25)
        WITHIN GROUP (ORDER BY transaction_count) AS q1,

    PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY transaction_count) AS median,

    PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY transaction_count) AS q3
FROM customer_transactions;



-- ------------------------------------------------------------
-- 15.2 Identify high-value, low-activity customers
-- ------------------------------------------------------------
-- customer_balance calculates the total account balance per customer.
--
-- customer_transactions counts all transactions made through all
-- accounts belonging to the customer.
--
-- COALESCE converts a missing transaction count to zero.
WITH customer_balance AS (
    SELECT
        customer_id,
        SUM(balance) AS total_balance
    FROM accounts_clean
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),
customer_transactions AS (
    SELECT
        a.customer_id,
        COUNT(t.transaction_id) AS transaction_count
    FROM accounts_clean a
    LEFT JOIN transactions_clean t
        ON a.account_id = t.account_id
    WHERE a.customer_id IS NOT NULL
    GROUP BY a.customer_id
),
balance_threshold AS (
    SELECT
        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY total_balance) AS q3_balance
    FROM customer_balance
    WHERE total_balance IS NOT NULL
),
activity_threshold AS (
    SELECT
        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY transaction_count) AS q1_activity
    FROM customer_transactions
)
SELECT
    cb.customer_id,
    cb.total_balance,
    ct.transaction_count
FROM customer_balance cb
JOIN customer_transactions ct
    ON cb.customer_id = ct.customer_id
CROSS JOIN balance_threshold bt
CROSS JOIN activity_threshold at
WHERE cb.total_balance >= bt.q3_balance
  AND ct.transaction_count <= at.q1_activity
ORDER BY
    cb.total_balance DESC,
    ct.transaction_count ASC,
    cb.customer_id;



-- ============================================================
-- 16. ACCOUNT BALANCE RANKING WITHIN EACH BRANCH
-- ============================================================
-- Business question:
-- How does each account rank compared with other accounts
-- belonging to the same branch?
--
-- RANK() is a window function.
--
-- PARTITION BY branch_id creates an independent ranking for
-- each branch without collapsing the account-level rows.

SELECT
    account_id,
    branch_id,
    balance,
    RANK() OVER (
        PARTITION BY branch_id
        ORDER BY balance DESC NULLS LAST
    ) AS balance_rank
FROM accounts_clean
WHERE
    branch_id IS NOT NULL
ORDER BY
    branch_id,
    balance_rank;



-- ============================================================
-- 17. MONTH-OVER-MONTH TRANSACTION AMOUNT CHANGE
-- ============================================================
-- Business question:
-- How does total transaction volume change compared with the
-- previous month?
--
-- Step 1:
-- Aggregate transactions by month.
--
-- Step 2:
-- LAG() retrieves the previous month's total amount while
-- preserving the current month's row.
--
-- The difference between the current and previous month is then
-- calculated.

WITH monthly_transactions AS (
    SELECT
        DATE_TRUNC('month', transaction_date) AS month,
        COUNT(*) AS transaction_count,
        SUM(amount) AS monthly_amount
    FROM transactions_clean
    WHERE
        transaction_date IS NOT NULL
    GROUP BY
        DATE_TRUNC('month', transaction_date)
)
SELECT
    month,
    transaction_count,
    monthly_amount,

    LAG(monthly_amount) OVER (
        ORDER BY month
    ) AS previous_month_amount,

    monthly_amount
        - LAG(monthly_amount) OVER (
            ORDER BY month
        ) AS amount_change

FROM monthly_transactions
ORDER BY
    month;