-- Bank Customer Segmentation
-- Raw staging tables: all columns are TEXT on purpose.
-- Goal: audit, clean, validate, then create typed clean tables.

DROP TABLE IF EXISTS transactions_raw;
DROP TABLE IF EXISTS loans_raw;
DROP TABLE IF EXISTS accounts_raw;
DROP TABLE IF EXISTS customers_raw;
DROP TABLE IF EXISTS branches_raw;

CREATE TABLE branches_raw (
    branch_id TEXT,
    branch_name TEXT,
    city TEXT,
    region TEXT,
    opened_date TEXT
);

CREATE TABLE customers_raw (
    customer_id TEXT,
    first_name TEXT,
    last_name TEXT,
    birth_date TEXT,
    city TEXT,
    profession TEXT,
    annual_income TEXT,
    signup_date TEXT,
    branch_id TEXT
);

CREATE TABLE accounts_raw (
    account_id TEXT,
    customer_id TEXT,
    account_type TEXT,
    balance TEXT,
    opening_date TEXT,
    status TEXT,
    branch_id TEXT
);

CREATE TABLE transactions_raw (
    transaction_id TEXT,
    account_id TEXT,
    transaction_date TEXT,
    transaction_type TEXT,
    channel TEXT,
    amount TEXT,
    merchant_category TEXT
);

CREATE TABLE loans_raw (
    loan_id TEXT,
    customer_id TEXT,
    loan_type TEXT,
    loan_amount TEXT,
    interest_rate TEXT,
    start_date TEXT,
    status TEXT
);

-- Import the five CSV files after creating these tables.
-- In DBeaver: right-click table -> Import Data -> CSV.
-- Keep the raw tables unchanged; perform cleaning into separate clean tables.


SELECT COUNT(*) FROM branches_raw;
SELECT COUNT(*) FROM customers_raw;
SELECT COUNT(*) FROM accounts_raw;
SELECT COUNT(*) FROM transactions_raw;
SELECT COUNT(*) FROM loans_raw;