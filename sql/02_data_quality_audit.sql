-- =====================================================
-- 1. DATA QUALITY AUDIT 
-- =====================================================


-- List all tables available in the public schema
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

------------------------------------------------
-- branches_raw
------------------------------------------------

-- Inspect the structure and data types of branches_raw
SELECT column_name,
       data_type
FROM information_schema.columns
WHERE table_name = 'branches_raw'
ORDER BY ordinal_position;


-- Count the total number of rows
SELECT COUNT(*) AS total_rows
FROM branches_raw;

-- Count missing values in each column
SELECT
    COUNT(*) FILTER (WHERE branch_id IS NULL OR TRIM(branch_id) = '') AS branch_id_missing,
    COUNT(*) FILTER (WHERE branch_name IS NULL OR TRIM(branch_name) = '') AS branch_name_missing,
    COUNT(*) FILTER (WHERE city IS NULL OR TRIM(city) = '') AS city_missing,
    COUNT(*) FILTER (WHERE region IS NULL OR TRIM(region) = '') AS region_missing,
    COUNT(*) FILTER (WHERE opened_date IS NULL OR TRIM(opened_date) = '') AS opened_date_missing
FROM branches_raw;


-- Count distinct branch IDs
SELECT COUNT(DISTINCT branch_id) AS distinct_branch_ids
FROM branches_raw;

-- Inspect maximum branch ID length
SELECT MAX(LENGTH(TRIM(branch_id))) AS max_branch_id_length
FROM branches_raw;

-- Identify branch IDs that appear more than once
SELECT branch_id,
       COUNT(*) AS occurrence_count
FROM branches_raw
WHERE branch_id IS NOT NULL
  AND TRIM(branch_id) <> ''
GROUP BY branch_id
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;


-- Count duplicated branch IDs
WITH duplicated_branch_ids AS (
    SELECT branch_id
    FROM branches_raw
    WHERE branch_id IS NOT NULL
      AND TRIM(branch_id) <> ''
    GROUP BY branch_id
    HAVING COUNT(*) > 1
)
SELECT COUNT(*) AS duplicated_branch_id_count
FROM duplicated_branch_ids;


-- Identify complete duplicate rows and count their occurrences
SELECT branch_id,
       branch_name,
       city,
       region,
       opened_date,
       COUNT(*) AS duplicate_count
FROM branches_raw
GROUP BY branch_id,
         branch_name,
         city,
         region,
         opened_date
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Inspect distinct branch names for formatting inconsistencies
SELECT DISTINCT branch_name
FROM branches_raw
ORDER BY branch_name;

-- Inspect distinct city values for formatting inconsistencies
SELECT DISTINCT city
FROM branches_raw
ORDER BY city;

-- Inspect distinct region values for formatting inconsistencies
SELECT DISTINCT region
FROM branches_raw
ORDER BY region;

-- Identify opened_date values not following YYYY-MM-DD format
SELECT opened_date
FROM branches_raw
WHERE opened_date IS NOT NULL
  AND TRIM(opened_date) <> ''
  AND TRIM(opened_date) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';


-- Identify impossible calendar dates
SELECT opened_date
FROM branches_raw
WHERE opened_date IS NOT NULL
  AND TRIM(opened_date) <> ''
  AND TRIM(opened_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND NOT pg_input_is_valid(TRIM(opened_date), 'date');


-- Identify valid dates that are in the future
SELECT opened_date
FROM branches_raw
WHERE opened_date IS NOT NULL
  AND TRIM(opened_date) <> ''
  AND TRIM(opened_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(opened_date), 'date')
  AND TRIM(opened_date)::DATE > CURRENT_DATE;


-- Inspect the valid opened_date range
SELECT
    MIN(TRIM(opened_date)::DATE) AS earliest_opening_date,
    MAX(TRIM(opened_date)::DATE) AS latest_opening_date
FROM branches_raw
WHERE opened_date IS NOT NULL
  AND TRIM(opened_date) <> ''
  AND TRIM(opened_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(opened_date), 'date');
------------------------------------------------
--customers_raw:
------------------------------------------------

-- Inspect the structure and data types of customers_raw
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'customers_raw'
ORDER BY ordinal_position;


-- Count the total number of rows
SELECT COUNT(*) as total_rows
FROM customers_raw;


-- Count missing values in each column
SELECT
    COUNT(*) FILTER (WHERE customer_id IS NULL OR TRIM(customer_id) = '') AS customer_id_missing,
    COUNT(*) FILTER (WHERE first_name IS NULL OR TRIM(first_name) = '') AS customer_first_name_missing,
    COUNT(*) FILTER (WHERE last_name IS NULL OR TRIM(last_name) = '') AS customer_last_name_missing,
    COUNT(*) FILTER (WHERE birth_date IS NULL OR TRIM(birth_date) = '') AS birth_date_missing,
    COUNT(*) FILTER (WHERE city IS NULL OR TRIM(city) = '') AS city_missing,
    COUNT(*) FILTER (WHERE profession IS NULL OR TRIM(profession) = '') AS profession_missing,
    COUNT(*) FILTER (WHERE annual_income IS NULL OR TRIM(annual_income) = '') AS annual_income_missing,
    COUNT(*) FILTER (WHERE signup_date IS NULL OR TRIM(signup_date) = '') AS signup_date_missing,
    COUNT(*) FILTER (WHERE branch_id IS NULL OR TRIM(branch_id) = '') AS branch_id_missing
FROM customers_raw;

-- Count distinct customer IDs
SELECT COUNT(DISTINCT customer_id) AS distinct_customer_ids
FROM customers_raw;

-- Inspect maximum customer ID length
SELECT MAX(LENGTH(TRIM(customer_id))) AS max_customer_id_length,
       MAX(LENGTH(TRIM(branch_id))) AS max_branch_id_length
FROM customers_raw;

-- Identify customer IDs that appear more than once
SELECT customer_id,
       COUNT(*) AS occurrence_count
FROM customers_raw
WHERE customer_id IS NOT NULL
  AND TRIM(customer_id) <> ''
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;

-- Count customer IDs that appear more than once
WITH duplicates_customer_id AS (
    SELECT customer_id
    FROM customers_raw
    WHERE customer_id IS NOT NULL
    AND TRIM(customer_id) <> ''
    GROUP BY customer_id
    HAVING COUNT(*) > 1
)
SELECT COUNT(*) AS duplicated_customer_id_count
FROM duplicates_customer_id;


-- Identify complete duplicate rows and count their occurrences
SELECT customer_id,
       first_name,
       last_name,
       birth_date,
       city,
       profession,
       annual_income,
       signup_date,
       branch_id,
       COUNT(*) AS duplicate_count
FROM customers_raw
GROUP BY customer_id,
         first_name,
         last_name,
         birth_date,
         city,
         profession,
         annual_income,
         signup_date,
         branch_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


-- Inspect distinct city values to detect formatting inconsistencies
SELECT DISTINCT city
FROM customers_raw
ORDER BY city;


-- Inspect distinct first names for formatting inconsistencies
SELECT DISTINCT first_name
FROM customers_raw
ORDER BY first_name;

-- Inspect distinct last names for formatting inconsistencies
SELECT DISTINCT last_name
FROM customers_raw
ORDER BY last_name;


-- Inspect distinct profession values
SELECT DISTINCT profession
FROM customers_raw
ORDER BY profession;


-- Identify birth_date values not following YYYY-MM-DD format
SELECT birth_date
FROM customers_raw
WHERE birth_date IS NOT NULL
  AND TRIM(birth_date) <> ''
  AND TRIM(birth_date) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';


-- Identify impossible calendar dates
SELECT birth_date
FROM customers_raw
WHERE birth_date IS NOT NULL
  AND TRIM(birth_date) <> ''
  AND TRIM(birth_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND NOT pg_input_is_valid(TRIM(birth_date), 'date');


-- Identify valid dates that are in the future
SELECT birth_date
FROM customers_raw
WHERE birth_date IS NOT NULL
  AND TRIM(birth_date) <> ''
  AND TRIM(birth_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(birth_date), 'date')
  AND TRIM(birth_date)::DATE > CURRENT_DATE;

-- Inspect the valid birth_date range
SELECT
    MIN(TRIM(birth_date)::DATE) AS earliest_birth_date,
    MAX(TRIM(birth_date)::DATE) AS latest_birth_date
FROM customers_raw
WHERE birth_date IS NOT NULL
  AND TRIM(birth_date) <> ''
  AND TRIM(birth_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(birth_date), 'date');


-- Identify annual_income values that are not in a valid numeric format
SELECT annual_income
FROM customers_raw
WHERE TRIM(annual_income) !~ '^-?[0-9]+(\.[0-9]+)?$';



-- Identify negative annual_income 
SELECT annual_income
FROM customers_raw
WHERE TRIM(annual_income) ~ '^-[0-9]+(\.[0-9]+)?$';


-- Inspect the valid annual_income range
SELECT
    MIN(TRIM(annual_income)::NUMERIC) AS min_annual_income,
    MAX(TRIM(annual_income)::NUMERIC) AS max_annual_income
FROM customers_raw
WHERE annual_income IS NOT NULL
  AND TRIM(annual_income) <> ''
  AND TRIM(annual_income) ~ '^-?[0-9]+(\.[0-9]+)?$';

-- Identify signup_date values not following YYYY-MM-DD format
SELECT signup_date
FROM customers_raw
WHERE signup_date IS NOT NULL
  AND TRIM(signup_date) <> ''
  AND TRIM(signup_date) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';


-- Identify impossible calendar dates
SELECT signup_date
FROM customers_raw
WHERE signup_date IS NOT NULL
  AND TRIM(signup_date) <> ''
  AND TRIM(signup_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND NOT pg_input_is_valid(TRIM(signup_date), 'date');


-- Identify valid dates that are in the future
SELECT signup_date
FROM customers_raw
WHERE signup_date IS NOT NULL
  AND TRIM(signup_date) <> ''
  AND TRIM(signup_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(signup_date), 'date')
  AND TRIM(signup_date)::DATE > CURRENT_DATE;

-- Inspect the valid signup_date range
SELECT
    MIN(TRIM(signup_date)::DATE) AS earliest_signup_date,
    MAX(TRIM(signup_date)::DATE) AS latest_signup_date
FROM customers_raw
WHERE signup_date IS NOT NULL
  AND TRIM(signup_date) <> ''
  AND TRIM(signup_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(signup_date), 'date');

-- Identify customers with signup_date earlier than birth_date
SELECT customer_id,
       birth_date,
       signup_date
FROM customers_raw
WHERE birth_date IS NOT NULL
  AND signup_date IS NOT NULL
  AND TRIM(birth_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND TRIM(signup_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(birth_date), 'date')
  AND pg_input_is_valid(TRIM(signup_date), 'date')
  AND TRIM(signup_date)::DATE < TRIM(birth_date)::DATE;

-- Identify non-empty branch IDs that do not exist in branches_raw
SELECT c.customer_id,
       c.branch_id
FROM customers_raw c
LEFT JOIN branches_raw b
    ON UPPER(TRIM(c.branch_id)) = UPPER(TRIM(b.branch_id))
WHERE c.branch_id IS NOT NULL
  AND TRIM(c.branch_id) <> ''
  AND b.branch_id IS NULL;

------------------------------------------------
-- accounts_raw
------------------------------------------------

-- Inspect the structure and data types of accounts_raw
SELECT column_name,
       data_type
FROM information_schema.columns
WHERE table_name = 'accounts_raw'
ORDER BY ordinal_position;


-- Count the total number of rows
SELECT COUNT(*) AS total_rows
FROM accounts_raw;


-- Count missing values in each column
SELECT
    COUNT(*) FILTER (WHERE account_id IS NULL OR TRIM(account_id) = '') AS account_id_missing,
    COUNT(*) FILTER (WHERE customer_id IS NULL OR TRIM(customer_id) = '') AS customer_id_missing,
    COUNT(*) FILTER (WHERE account_type IS NULL OR TRIM(account_type) = '') AS account_type_missing,
    COUNT(*) FILTER (WHERE balance IS NULL OR TRIM(balance) = '') AS balance_missing,
    COUNT(*) FILTER (WHERE opening_date IS NULL OR TRIM(opening_date) = '') AS opening_date_missing,
    COUNT(*) FILTER (WHERE status IS NULL OR TRIM(status) = '') AS status_missing,
    COUNT(*) FILTER (WHERE branch_id IS NULL OR TRIM(branch_id) = '') AS branch_id_missing
FROM accounts_raw;


-- Count distinct account IDs
SELECT COUNT(DISTINCT account_id) AS distinct_account_ids
FROM accounts_raw;


-- Inspect maximum account ID length
SELECT MAX(LENGTH(TRIM(account_id))) AS max_account_id_length
FROM accounts_raw;


-- Identify account IDs that appear more than once
SELECT account_id,
       COUNT(*) AS occurrence_count
FROM accounts_raw
WHERE account_id IS NOT NULL
  AND TRIM(account_id) <> ''
GROUP BY account_id
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;


-- Count duplicated account IDs
WITH duplicates_account_id AS (
    SELECT account_id
    FROM accounts_raw
    WHERE account_id IS NOT NULL
      AND TRIM(account_id) <> ''
    GROUP BY account_id
    HAVING COUNT(*) > 1
)
SELECT COUNT(*) AS duplicated_account_id_count
FROM duplicates_account_id;


-- Identify complete duplicate rows and count their occurrences
SELECT account_id,
       customer_id,
       account_type,
       balance,
       opening_date,
       status,
       branch_id,
       COUNT(*) AS duplicate_count
FROM accounts_raw
GROUP BY account_id,
         customer_id,
         account_type,
         balance,
         opening_date,
         status,
         branch_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


-- Identify non-empty customer IDs that do not exist in customers_raw
SELECT a.account_id,
       a.customer_id
FROM accounts_raw a
LEFT JOIN customers_raw c
    ON UPPER(TRIM(a.customer_id)) = UPPER(TRIM(c.customer_id))
WHERE a.customer_id IS NOT NULL
  AND TRIM(a.customer_id) <> ''
  AND c.customer_id IS NULL;


-- Inspect distinct account_type values for formatting inconsistencies
SELECT DISTINCT account_type
FROM accounts_raw
ORDER BY account_type;

-- Inspect suspicious account type variants
-- to determine whether they represent the same business category
SELECT account_type,
       COUNT(*) AS account_count
FROM accounts_raw
WHERE LOWER(TRIM(account_type)) IN (
    'save',
    'savings'
)
GROUP BY account_type
ORDER BY account_type;

-- Identify balance values that are not in a valid numeric format
SELECT balance
FROM accounts_raw
WHERE balance IS NOT NULL
  AND TRIM(balance) <> ''
  AND TRIM(balance) !~ '^-?[0-9]+(\.[0-9]+)?$';


-- Inspect the valid balance range
SELECT
    MIN(TRIM(balance)::NUMERIC) AS min_balance,
    MAX(TRIM(balance)::NUMERIC) AS max_balance
FROM accounts_raw
WHERE balance IS NOT NULL
  AND TRIM(balance) <> ''
  AND TRIM(balance) ~ '^-?[0-9]+(\.[0-9]+)?$';


-- Identify opening_date values not following YYYY-MM-DD format
SELECT opening_date
FROM accounts_raw
WHERE opening_date IS NOT NULL
  AND TRIM(opening_date) <> ''
  AND TRIM(opening_date) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';


-- Identify impossible calendar dates
SELECT opening_date
FROM accounts_raw
WHERE opening_date IS NOT NULL
  AND TRIM(opening_date) <> ''
  AND TRIM(opening_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND NOT pg_input_is_valid(TRIM(opening_date), 'date');


-- Identify valid opening dates that are in the future
SELECT opening_date
FROM accounts_raw
WHERE opening_date IS NOT NULL
  AND TRIM(opening_date) <> ''
  AND TRIM(opening_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(opening_date), 'date')
  AND TRIM(opening_date)::DATE > CURRENT_DATE;


-- Inspect the valid opening_date range
SELECT
    MIN(TRIM(opening_date)::DATE) AS earliest_opening_date,
    MAX(TRIM(opening_date)::DATE) AS latest_opening_date
FROM accounts_raw
WHERE opening_date IS NOT NULL
  AND TRIM(opening_date) <> ''
  AND TRIM(opening_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(opening_date), 'date');


-- Inspect distinct status values for formatting inconsistencies
SELECT DISTINCT status
FROM accounts_raw
ORDER BY status;


-- Identify non-empty branch IDs that do not exist in branches_raw
SELECT a.account_id,
       a.branch_id
FROM accounts_raw a
LEFT JOIN branches_raw b
    ON UPPER(TRIM(a.branch_id)) = UPPER(TRIM(b.branch_id))
WHERE a.branch_id IS NOT NULL
  AND TRIM(a.branch_id) <> ''
  AND b.branch_id IS NULL;
------------------------------------------------
-- transactions_raw
------------------------------------------------

-- Inspect the structure and data types of transactions_raw
SELECT column_name,
       data_type
FROM information_schema.columns
WHERE table_name = 'transactions_raw'
ORDER BY ordinal_position;


-- Count the total number of rows
SELECT COUNT(*) AS total_rows
FROM transactions_raw;


-- Count missing values in each column
SELECT
    COUNT(*) FILTER (WHERE transaction_id IS NULL OR TRIM(transaction_id) = '') AS transaction_id_missing,
    COUNT(*) FILTER (WHERE account_id IS NULL OR TRIM(account_id) = '') AS account_id_missing,
    COUNT(*) FILTER (WHERE transaction_type IS NULL OR TRIM(transaction_type) = '') AS transaction_type_missing,
    COUNT(*) FILTER (WHERE channel IS NULL OR TRIM(channel) = '') AS channel_missing,
    COUNT(*) FILTER (WHERE amount IS NULL OR TRIM(amount) = '') AS amount_missing,
    COUNT(*) FILTER (WHERE transaction_date IS NULL OR TRIM(transaction_date) = '') AS transaction_date_missing
FROM transactions_raw;


-- Count distinct transaction IDs
SELECT COUNT(DISTINCT transaction_id) AS distinct_transaction_ids
FROM transactions_raw;


-- Inspect maximum transaction ID length
SELECT MAX(LENGTH(TRIM(transaction_id))) AS max_transaction_id_length
FROM transactions_raw;


-- Identify transaction IDs that appear more than once
SELECT transaction_id,
       COUNT(*) AS occurrence_count
FROM transactions_raw
WHERE transaction_id IS NOT NULL
  AND TRIM(transaction_id) <> ''
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;


-- Count duplicated transaction IDs
WITH duplicated_transaction_ids AS (
    SELECT transaction_id
    FROM transactions_raw
    WHERE transaction_id IS NOT NULL
      AND TRIM(transaction_id) <> ''
    GROUP BY transaction_id
    HAVING COUNT(*) > 1
)
SELECT COUNT(*) AS duplicated_transaction_id_count
FROM duplicated_transaction_ids;


-- Identify complete duplicate rows
SELECT transaction_id,
       account_id,
       transaction_type,
       channel,
       amount,
       transaction_date,
       merchant_category,
       COUNT(*) AS duplicate_count
FROM transactions_raw
GROUP BY transaction_id,
         account_id,
         transaction_type,
         channel,
         amount,
         transaction_date,
         merchant_category
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


-- Identify account IDs that do not exist in accounts_raw
SELECT t.transaction_id,
       t.account_id
FROM transactions_raw t
LEFT JOIN accounts_raw a
    ON UPPER(TRIM(t.account_id)) = UPPER(TRIM(a.account_id))
WHERE t.account_id IS NOT NULL
  AND TRIM(t.account_id) <> ''
  AND a.account_id IS NULL;


-- Inspect distinct transaction_type values
SELECT DISTINCT transaction_type
FROM transactions_raw
ORDER BY transaction_type;

-- Inspect suspicious transaction type variants
-- to identify likely formatting or naming inconsistencies
SELECT transaction_type,
       COUNT(*) AS transaction_count
FROM transactions_raw
WHERE LOWER(TRIM(transaction_type)) IN (
    'transferin',
    'transfer in',
    'withdraw',
    'cash withdrawal',
    'card',
    'card payment'
)
GROUP BY transaction_type
ORDER BY transaction_type;


-- Inspect raw merchant categories and their frequencies
SELECT
    merchant_category,
    COUNT(*) AS transaction_count
FROM transactions_raw
GROUP BY merchant_category
ORDER BY transaction_count DESC;

-- Count missing merchant categories
SELECT
    COUNT(*) FILTER (
        WHERE merchant_category IS NULL
           OR TRIM(merchant_category) = ''
    ) AS merchant_category_missing
FROM transactions_raw;

-- Inspect distinct channel values
SELECT DISTINCT channel
FROM transactions_raw
ORDER BY channel;


-- Compare suspicious transaction type variants by channel
SELECT transaction_type,
       channel,
       COUNT(*) AS transaction_count
FROM transactions_raw
WHERE LOWER(TRIM(transaction_type)) IN (
    'transferin',
    'transfer in',
    'withdraw',
    'cash withdrawal',
    'card',
    'card payment'
)
GROUP BY transaction_type, channel
ORDER BY transaction_type, transaction_count DESC;

-- Identify amount values that are not valid numeric values
SELECT DISTINCT amount
FROM transactions_raw
WHERE amount IS NOT NULL
  AND TRIM(amount) <> ''
  AND TRIM(amount) !~ '^-?[0-9]+(\.[0-9]+)?$';


-- Identify zero transaction amounts
SELECT amount
FROM transactions_raw
WHERE amount IS NOT NULL
  AND TRIM(amount) ~ '^-?[0-9]+(\.[0-9]+)?$'
  AND TRIM(amount)::NUMERIC = 0;


-- Inspect valid transaction amount range
SELECT
    MIN(TRIM(amount)::NUMERIC) AS min_amount,
    MAX(TRIM(amount)::NUMERIC) AS max_amount
FROM transactions_raw
WHERE amount IS NOT NULL
  AND TRIM(amount) <> ''
  AND TRIM(amount) ~ '^-?[0-9]+(\.[0-9]+)?$';

-- Analyze transaction amount signs by transaction type
-- to determine whether negative amounts represent transaction direction
SELECT transaction_type,
       COUNT(*) AS transaction_count,
       COUNT(*) FILTER (WHERE TRIM(amount)::NUMERIC < 0) AS negative_count,
       COUNT(*) FILTER (WHERE TRIM(amount)::NUMERIC = 0) AS zero_count,
       COUNT(*) FILTER (WHERE TRIM(amount)::NUMERIC > 0) AS positive_count
FROM transactions_raw
WHERE amount IS NOT NULL
  AND TRIM(amount) <> ''
  AND TRIM(amount) ~ '^-?[0-9]+(\.[0-9]+)?$'
GROUP BY transaction_type
ORDER BY transaction_type;

-- Identify transaction_date values not following YYYY-MM-DD format
SELECT transaction_date
FROM transactions_raw
WHERE transaction_date IS NOT NULL
  AND TRIM(transaction_date) <> ''
  AND TRIM(transaction_date) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';


-- Identify impossible calendar dates
SELECT transaction_date
FROM transactions_raw
WHERE transaction_date IS NOT NULL
  AND TRIM(transaction_date) <> ''
  AND TRIM(transaction_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND NOT pg_input_is_valid(TRIM(transaction_date), 'date');


-- Identify valid transaction dates in the future
SELECT transaction_date
FROM transactions_raw
WHERE transaction_date IS NOT NULL
  AND TRIM(transaction_date) <> ''
  AND TRIM(transaction_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(transaction_date), 'date')
  AND TRIM(transaction_date)::DATE > CURRENT_DATE;


-- Inspect valid transaction_date range
SELECT
    MIN(TRIM(transaction_date)::DATE) AS earliest_transaction_date,
    MAX(TRIM(transaction_date)::DATE) AS latest_transaction_date
FROM transactions_raw
WHERE transaction_date IS NOT NULL
  AND TRIM(transaction_date) <> ''
  AND TRIM(transaction_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(transaction_date), 'date');

------------------------------------------------
-- loans_raw
------------------------------------------------

-- Inspect the structure and data types of loans_raw
SELECT column_name,
       data_type
FROM information_schema.columns
WHERE table_name = 'loans_raw'
ORDER BY ordinal_position;


-- Count the total number of rows
SELECT COUNT(*) AS total_rows
FROM loans_raw;


-- Count missing values in each column
SELECT
    COUNT(*) FILTER (WHERE loan_id IS NULL OR TRIM(loan_id) = '') AS loan_id_missing,
    COUNT(*) FILTER (WHERE customer_id IS NULL OR TRIM(customer_id) = '') AS customer_id_missing,
    COUNT(*) FILTER (WHERE loan_type IS NULL OR TRIM(loan_type) = '') AS loan_type_missing,
    COUNT(*) FILTER (WHERE loan_amount IS NULL OR TRIM(loan_amount) = '') AS loan_amount_missing,
    COUNT(*) FILTER (WHERE interest_rate IS NULL OR TRIM(interest_rate) = '') AS interest_rate_missing,
    COUNT(*) FILTER (WHERE start_date IS NULL OR TRIM(start_date) = '') AS start_date_missing,
    COUNT(*) FILTER (WHERE status IS NULL OR TRIM(status) = '') AS status_missing
FROM loans_raw;


-- Count distinct loan IDs
SELECT COUNT(DISTINCT loan_id) AS distinct_loan_ids
FROM loans_raw;


-- Inspect maximum loan ID length
SELECT MAX(LENGTH(TRIM(loan_id))) AS max_loan_id_length
FROM loans_raw;


-- Identify loan IDs that appear more than once
SELECT loan_id,
       COUNT(*) AS occurrence_count
FROM loans_raw
WHERE loan_id IS NOT NULL
  AND TRIM(loan_id) <> ''
GROUP BY loan_id
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;


-- Count duplicated loan IDs
WITH duplicated_loan_ids AS (
    SELECT loan_id
    FROM loans_raw
    WHERE loan_id IS NOT NULL
      AND TRIM(loan_id) <> ''
    GROUP BY loan_id
    HAVING COUNT(*) > 1
)
SELECT COUNT(*) AS duplicated_loan_id_count
FROM duplicated_loan_ids;


-- Identify complete duplicate rows
SELECT loan_id,
       customer_id,
       loan_type,
       loan_amount,
       interest_rate,
       start_date,
       status,
       COUNT(*) AS duplicate_count
FROM loans_raw
GROUP BY loan_id,
         customer_id,
         loan_type,
         loan_amount,
         interest_rate,
         start_date,
         status
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


-- Identify customer IDs that do not exist in customers_raw
SELECT l.loan_id,
       l.customer_id
FROM loans_raw l
LEFT JOIN customers_raw c
    ON UPPER(TRIM(l.customer_id)) = UPPER(TRIM(c.customer_id))
WHERE l.customer_id IS NOT NULL
  AND TRIM(l.customer_id) <> ''
  AND c.customer_id IS NULL;


-- Inspect distinct loan types for formatting inconsistencies
SELECT DISTINCT loan_type
FROM loans_raw
ORDER BY loan_type;


-- Identify loan_amount values that are not valid numeric values
SELECT loan_amount
FROM loans_raw
WHERE loan_amount IS NOT NULL
  AND TRIM(loan_amount) <> ''
  AND TRIM(loan_amount) !~ '^-?[0-9]+(\.[0-9]+)?$';


-- Identify negative or zero loan amounts
SELECT loan_amount
FROM loans_raw
WHERE loan_amount IS NOT NULL
  AND TRIM(loan_amount) ~ '^-?[0-9]+(\.[0-9]+)?$'
  AND TRIM(loan_amount)::NUMERIC <= 0;



-- Inspect valid loan_amount range
SELECT
    MIN(TRIM(loan_amount)::NUMERIC) AS min_loan_amount,
    MAX(TRIM(loan_amount)::NUMERIC) AS max_loan_amount
FROM loans_raw
WHERE loan_amount IS NOT NULL
  AND TRIM(loan_amount) <> ''
  AND TRIM(loan_amount) ~ '^-?[0-9]+(\.[0-9]+)?$';


-- Identify interest_rate values that are not valid numeric values
SELECT interest_rate
FROM loans_raw
WHERE interest_rate IS NOT NULL
  AND TRIM(interest_rate) <> ''
  AND TRIM(interest_rate) !~ '^-?[0-9]+(\.[0-9]+)?$';


-- Identify invalid negative interest rates
SELECT interest_rate
FROM loans_raw
WHERE interest_rate IS NOT NULL
  AND TRIM(interest_rate) ~ '^-?[0-9]+(\.[0-9]+)?$'
  AND TRIM(interest_rate)::NUMERIC < 0;


-- Inspect valid interest_rate range
SELECT
    MIN(TRIM(interest_rate)::NUMERIC) AS min_interest_rate,
    MAX(TRIM(interest_rate)::NUMERIC) AS max_interest_rate
FROM loans_raw
WHERE interest_rate IS NOT NULL
  AND TRIM(interest_rate) <> ''
  AND TRIM(interest_rate) ~ '^-?[0-9]+(\.[0-9]+)?$';


-- Identify start_date values not following YYYY-MM-DD format
SELECT start_date
FROM loans_raw
WHERE start_date IS NOT NULL
  AND TRIM(start_date) <> ''
  AND TRIM(start_date) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';


-- Identify impossible calendar dates
SELECT start_date
FROM loans_raw
WHERE start_date IS NOT NULL
  AND TRIM(start_date) <> ''
  AND TRIM(start_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND NOT pg_input_is_valid(TRIM(start_date), 'date');


-- Identify valid start dates that are in the future
SELECT start_date
FROM loans_raw
WHERE start_date IS NOT NULL
  AND TRIM(start_date) <> ''
  AND TRIM(start_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(start_date), 'date')
  AND TRIM(start_date)::DATE > CURRENT_DATE;


-- Inspect valid start_date range
SELECT
    MIN(TRIM(start_date)::DATE) AS earliest_start_date,
    MAX(TRIM(start_date)::DATE) AS latest_start_date
FROM loans_raw
WHERE start_date IS NOT NULL
  AND TRIM(start_date) <> ''
  AND TRIM(start_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND pg_input_is_valid(TRIM(start_date), 'date');


-- Inspect distinct loan status values
SELECT DISTINCT status
FROM loans_raw
ORDER BY status;


