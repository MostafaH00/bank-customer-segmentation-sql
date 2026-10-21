-- =====================================================
-- DATA CLEANING AND VALIDATION
-- =====================================================

-- Preserve raw tables and create working clean tables

DROP TABLE IF EXISTS transactions_clean;
DROP TABLE IF EXISTS loans_clean;
DROP TABLE IF EXISTS accounts_clean;
DROP TABLE IF EXISTS customers_clean;
DROP TABLE IF EXISTS branches_clean;


CREATE TABLE branches_clean AS
SELECT *
FROM branches_raw;


CREATE TABLE customers_clean AS
SELECT *
FROM customers_raw;


CREATE TABLE accounts_clean AS
SELECT *
FROM accounts_raw;


CREATE TABLE transactions_clean AS
SELECT *
FROM transactions_raw;


CREATE TABLE loans_clean AS
SELECT *
FROM loans_raw;


SELECT COUNT(*) FROM branches_clean;
SELECT COUNT(*) FROM customers_clean;
SELECT COUNT(*) FROM accounts_clean;
SELECT COUNT(*) FROM transactions_clean;
SELECT COUNT(*) FROM loans_clean;


---------------------------------
-- branches_clean
---------------------------------

-- The audit found no missing values, duplicate rows, duplicate branch IDs,
-- malformed dates, impossible dates, or future opening dates.
-- Cleaning is therefore limited to text standardization
-- and data type conversion.

BEGIN;


-- Standardize branch IDs
UPDATE branches_clean
SET branch_id = UPPER(TRIM(branch_id));


-- Standardize branch names
UPDATE branches_clean
SET branch_name = INITCAP(TRIM(branch_name));


-- Standardize city names
UPDATE branches_clean
SET city = INITCAP(TRIM(city));


-- Remove surrounding spaces from region values
UPDATE branches_clean
SET region = TRIM(region);


-- Convert branch_id from TEXT to VARCHAR(4)
-- The audit found a maximum branch_id length of 4 characters.
ALTER TABLE branches_clean
ALTER COLUMN branch_id TYPE VARCHAR(4);


-- Convert opened_date from TEXT to DATE
-- The audit confirmed that all dates are valid and non-future.
ALTER TABLE branches_clean
ALTER COLUMN opened_date TYPE DATE
USING opened_date::DATE;


-- =====================================================
-- Validation after cleaning
-- =====================================================

-- Verify row count was preserved
SELECT COUNT(*) AS total_rows
FROM branches_clean;


-- Verify branch IDs remain unique
SELECT branch_id,
       COUNT(*) AS occurrence_count
FROM branches_clean
GROUP BY branch_id
HAVING COUNT(*) > 1;


-- Verify no missing values were introduced
SELECT
    COUNT(*) FILTER (WHERE branch_id IS NULL) AS branch_id_missing,
    COUNT(*) FILTER (WHERE branch_name IS NULL) AS branch_name_missing,
    COUNT(*) FILTER (WHERE city IS NULL) AS city_missing,
    COUNT(*) FILTER (WHERE region IS NULL) AS region_missing,
    COUNT(*) FILTER (WHERE opened_date IS NULL) AS opened_date_missing
FROM branches_clean;


-- Verify final data types
SELECT column_name,
       data_type,
       character_maximum_length
FROM information_schema.columns
WHERE table_name = 'branches_clean'
ORDER BY ordinal_position;


COMMIT;


---------------------------------
-- customers_clean
---------------------------------

-- The audit identified inconsistent text formatting, missing values,
-- duplicated customer IDs, malformed and invalid birth dates,
-- non-standard signup dates, invalid annual_income values,
-- and one invalid branch reference.
-- Cleaning is therefore based only on these observed issues.

BEGIN;


-- =====================================================
-- 1. TEXT STANDARDIZATION
-- =====================================================

-- Standardize customer IDs
UPDATE customers_clean
SET customer_id = UPPER(TRIM(customer_id));


-- Standardize first names
UPDATE customers_clean
SET first_name = INITCAP(TRIM(first_name));


-- Standardize last names
UPDATE customers_clean
SET last_name = INITCAP(TRIM(last_name));


-- Standardize city names.
-- The audit found inconsistent capitalization such as
-- Grenoble/GRENOBLE and Marseille/MARSEILLE.
UPDATE customers_clean
SET city = INITCAP(TRIM(city));


-- Remove surrounding spaces from profession values
UPDATE customers_clean
SET profession = TRIM(profession);


-- Standardize branch IDs
UPDATE customers_clean
SET branch_id = UPPER(TRIM(branch_id));


-- Convert empty strings to NULL
UPDATE customers_clean
SET customer_id = NULLIF(customer_id, ''),
    first_name   = NULLIF(first_name, ''),
    last_name    = NULLIF(last_name, ''),
    city         = NULLIF(city, ''),
    profession   = NULLIF(profession, ''),
    branch_id    = NULLIF(branch_id, '');



-- =====================================================
-- 2. ID DATA TYPES
-- =====================================================

-- The audit found a maximum customer_id length of 5 characters
ALTER TABLE customers_clean
ALTER COLUMN customer_id TYPE VARCHAR(5);


-- The audit found a maximum branch_id length of 4 characters
ALTER TABLE customers_clean
ALTER COLUMN branch_id TYPE VARCHAR(4);



-- =====================================================
-- 3. BRANCH REFERENTIAL CONSISTENCY
-- =====================================================

-- The audit found branch IDs that do not exist in branches_raw,
-- including B999. Since the correct branch is unknown,
-- invalid references are set to NULL rather than guessed.
UPDATE customers_clean c
SET branch_id = NULL
WHERE c.branch_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM branches_clean b
      WHERE b.branch_id = c.branch_id
  );



-- =====================================================
-- 4. ANNUAL INCOME CLEANING
-- =====================================================

-- Convert empty annual_income values to NULL
UPDATE customers_clean
SET annual_income = NULL
WHERE annual_income IS NOT NULL
  AND TRIM(annual_income) = '';


-- The audit found valid thousands separators such as 45,000.
-- Remove commas only when the complete value follows
-- a valid thousands-separator pattern.
UPDATE customers_clean
SET annual_income = REPLACE(TRIM(annual_income), ',', '')
WHERE annual_income IS NOT NULL
  AND TRIM(annual_income)
      ~ '^-?[0-9]{1,3}(,[0-9]{3})+(\.[0-9]+)?$';


-- Values such as 'unknown' and 'N/A' cannot be recovered
-- as numeric income values and are therefore set to NULL.
UPDATE customers_clean
SET annual_income = NULL
WHERE annual_income IS NOT NULL
  AND TRIM(annual_income) !~ '^-?[0-9]+(\.[0-9]+)?$';


-- The audit found negative annual incomes (-5000).
-- Negative annual income is considered invalid for this dataset.
UPDATE customers_clean
SET annual_income = NULL
WHERE annual_income IS NOT NULL
  AND annual_income::NUMERIC < 0;


-- Verify all remaining non-null values are numeric
SELECT annual_income
FROM customers_clean
WHERE annual_income IS NOT NULL
  AND TRIM(annual_income) !~ '^[0-9]+(\.[0-9]+)?$';


-- Convert annual_income to NUMERIC
ALTER TABLE customers_clean
ALTER COLUMN annual_income TYPE NUMERIC(12,2)
USING annual_income::NUMERIC;



-- =====================================================
-- 5. BIRTH DATE CLEANING
-- =====================================================

-- Convert empty birth_date values to NULL
UPDATE customers_clean
SET birth_date = NULL
WHERE birth_date IS NOT NULL
  AND TRIM(birth_date) = '';


-- Standardize "/" separators.
-- Example: 31/02/1994 -> 31-02-1994
UPDATE customers_clean
SET birth_date = REPLACE(TRIM(birth_date), '/', '-')
WHERE birth_date IS NOT NULL;


-- Set impossible DD-MM-YYYY dates to NULL.
-- Example: 31-02-1994 is correctly formatted but
-- does not represent a valid calendar date.
UPDATE customers_clean
SET birth_date = NULL
WHERE birth_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
  AND NOT pg_input_is_valid(
        SUBSTRING(birth_date, 7, 4) || '-' ||
        SUBSTRING(birth_date, 4, 2) || '-' ||
        SUBSTRING(birth_date, 1, 2),
        'date'
      );


-- Convert valid DD-MM-YYYY dates to YYYY-MM-DD
UPDATE customers_clean
SET birth_date =
      SUBSTRING(birth_date, 7, 4) || '-' ||
      SUBSTRING(birth_date, 4, 2) || '-' ||
      SUBSTRING(birth_date, 1, 2)
WHERE birth_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$';


-- Set remaining malformed or impossible values to NULL.
-- This handles values such as 199x-07-10.
UPDATE customers_clean
SET birth_date = NULL
WHERE birth_date IS NOT NULL
  AND NOT pg_input_is_valid(TRIM(birth_date), 'date');


-- The audit found a future birth date (2032-04-18).
-- Future birth dates are impossible and are set to NULL.
UPDATE customers_clean
SET birth_date = NULL
WHERE birth_date IS NOT NULL
  AND birth_date::DATE > CURRENT_DATE;


-- Convert birth_date from TEXT to DATE
ALTER TABLE customers_clean
ALTER COLUMN birth_date TYPE DATE
USING birth_date::DATE;



-- =====================================================
-- 6. SIGNUP DATE CLEANING
-- =====================================================

-- Convert empty signup_date values to NULL
UPDATE customers_clean
SET signup_date = NULL
WHERE signup_date IS NOT NULL
  AND TRIM(signup_date) = '';


-- Standardize "/" separators if present
UPDATE customers_clean
SET signup_date = REPLACE(TRIM(signup_date), '/', '-')
WHERE signup_date IS NOT NULL;


-- Check DD-MM-YYYY values before conversion
UPDATE customers_clean
SET signup_date = NULL
WHERE signup_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
  AND NOT pg_input_is_valid(
        SUBSTRING(signup_date, 7, 4) || '-' ||
        SUBSTRING(signup_date, 4, 2) || '-' ||
        SUBSTRING(signup_date, 1, 2),
        'date'
      );


-- Convert valid DD-MM-YYYY values such as 11-04-2024
-- to YYYY-MM-DD
UPDATE customers_clean
SET signup_date =
      SUBSTRING(signup_date, 7, 4) || '-' ||
      SUBSTRING(signup_date, 4, 2) || '-' ||
      SUBSTRING(signup_date, 1, 2)
WHERE signup_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$';


-- Values such as 'not_a_date' cannot be recovered
-- and are therefore set to NULL.
UPDATE customers_clean
SET signup_date = NULL
WHERE signup_date IS NOT NULL
  AND NOT pg_input_is_valid(TRIM(signup_date), 'date');


-- Safety check for future signup dates
UPDATE customers_clean
SET signup_date = NULL
WHERE signup_date IS NOT NULL
  AND signup_date::DATE > CURRENT_DATE;


-- Convert signup_date from TEXT to DATE
ALTER TABLE customers_clean
ALTER COLUMN signup_date TYPE DATE
USING signup_date::DATE;



-- =====================================================
-- 7. CROSS-COLUMN DATE CONSISTENCY
-- =====================================================

-- Verify that no valid signup date precedes a valid birth date.
-- The raw audit identified C0452 because its birth date was 2032-04-18.
-- That invalid future birth date has already been converted to NULL.
SELECT customer_id,
       birth_date,
       signup_date
FROM customers_clean
WHERE birth_date IS NOT NULL
  AND signup_date IS NOT NULL
  AND signup_date < birth_date;



-- =====================================================
-- 8. COMPLETE DUPLICATE REMOVAL
-- =====================================================

-- Remove only complete duplicate rows while keeping one copy.
-- Duplicate customer IDs are not deleted unless the complete rows
-- are identical after cleaning.
DELETE FROM customers_clean
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM customers_clean
    GROUP BY customer_id,
             first_name,
             last_name,
             birth_date,
             city,
             profession,
             annual_income,
             signup_date,
             branch_id
);



-- =====================================================
-- 9. VALIDATION AFTER CLEANING
-- =====================================================

-- Verify final row count
SELECT COUNT(*) AS total_rows
FROM customers_clean;


-- Verify whether duplicated customer IDs remain after cleaning
SELECT customer_id,
       COUNT(*) AS occurrence_count
FROM customers_clean
WHERE customer_id IS NOT NULL
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;

-- Inspect duplicated customer records
SELECT *
FROM customers_clean
WHERE customer_id IN (
    SELECT customer_id
    FROM customers_clean
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
    HAVING COUNT(*) > 1
)
ORDER BY customer_id;


-- Verify no complete duplicate rows remain
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
FROM customers_clean
GROUP BY customer_id,
         first_name,
         last_name,
         birth_date,
         city,
         profession,
         annual_income,
         signup_date,
         branch_id
HAVING COUNT(*) > 1;


-- Inspect missing values after cleaning
SELECT
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_missing,
    COUNT(*) FILTER (WHERE first_name IS NULL) AS first_name_missing,
    COUNT(*) FILTER (WHERE last_name IS NULL) AS last_name_missing,
    COUNT(*) FILTER (WHERE birth_date IS NULL) AS birth_date_missing,
    COUNT(*) FILTER (WHERE city IS NULL) AS city_missing,
    COUNT(*) FILTER (WHERE profession IS NULL) AS profession_missing,
    COUNT(*) FILTER (WHERE annual_income IS NULL) AS annual_income_missing,
    COUNT(*) FILTER (WHERE signup_date IS NULL) AS signup_date_missing,
    COUNT(*) FILTER (WHERE branch_id IS NULL) AS branch_id_missing
FROM customers_clean;


-- Verify no negative annual income remains
SELECT customer_id,
       annual_income
FROM customers_clean
WHERE annual_income < 0;


-- Inspect final annual_income range
SELECT
    MIN(annual_income) AS min_annual_income,
    MAX(annual_income) AS max_annual_income
FROM customers_clean;


-- Verify no future dates remain
SELECT customer_id,
       birth_date,
       signup_date
FROM customers_clean
WHERE birth_date > CURRENT_DATE
   OR signup_date > CURRENT_DATE;


-- Verify date consistency
SELECT customer_id,
       birth_date,
       signup_date
FROM customers_clean
WHERE birth_date IS NOT NULL
  AND signup_date IS NOT NULL
  AND signup_date < birth_date;


-- Verify all remaining branch IDs exist in branches_clean
SELECT c.customer_id,
       c.branch_id
FROM customers_clean c
LEFT JOIN branches_clean b
    ON c.branch_id = b.branch_id
WHERE c.branch_id IS NOT NULL
  AND b.branch_id IS NULL;


-- Verify final data types
SELECT column_name,
       data_type,
       character_maximum_length,
       numeric_precision,
       numeric_scale
FROM information_schema.columns
WHERE table_name = 'customers_clean'
ORDER BY ordinal_position;


-- Final visual inspection
SELECT *
FROM customers_clean
ORDER BY customer_id;


COMMIT;

---------------------------------
-- accounts_clean
---------------------------------

-- The audit identified missing values, complete duplicate rows,
-- invalid customer references, non-numeric balance values,
-- valid thousands separators, and non-standard or impossible opening dates.
-- Negative balances are considered valid because they may represent overdrafts.

BEGIN;


-- =====================================================
-- 1. TEXT STANDARDIZATION
-- =====================================================

-- Standardize account IDs
UPDATE accounts_clean
SET account_id = UPPER(TRIM(account_id));


-- Standardize customer IDs
UPDATE accounts_clean
SET customer_id = UPPER(TRIM(customer_id));


-- Standardize account types
UPDATE accounts_clean
SET account_type = INITCAP(TRIM(account_type));


-- Normalize confirmed account type naming variants.
-- The audit showed that 'Save' is an inconsistent naming variant
-- of the existing 'Savings' account type.
UPDATE accounts_clean
SET account_type = 'Savings'
WHERE LOWER(TRIM(account_type)) = 'save';


-- Standardize status values
UPDATE accounts_clean
SET status = INITCAP(TRIM(status));


-- Standardize branch IDs
UPDATE accounts_clean
SET branch_id = UPPER(TRIM(branch_id));


-- Convert empty strings to NULL
UPDATE accounts_clean
SET account_id   = NULLIF(account_id, ''),
    customer_id  = NULLIF(customer_id, ''),
    account_type = NULLIF(account_type, ''),
    status       = NULLIF(status, ''),
    branch_id    = NULLIF(branch_id, '');



-- =====================================================
-- 2. ID DATA TYPES
-- =====================================================

-- Maximum account_id length found by the audit: 6
ALTER TABLE accounts_clean
ALTER COLUMN account_id TYPE VARCHAR(6);


-- customer_id uses the same identifier format as customers_clean
ALTER TABLE accounts_clean
ALTER COLUMN customer_id TYPE VARCHAR(5);


-- branch_id uses the same identifier format as branches_clean
ALTER TABLE accounts_clean
ALTER COLUMN branch_id TYPE VARCHAR(4);



-- =====================================================
-- 3. CUSTOMER REFERENTIAL CONSISTENCY
-- =====================================================

-- The audit found invalid customer references such as C9999.
-- Since the correct customer is unknown, invalid references
-- are set to NULL rather than guessed.
UPDATE accounts_clean a
SET customer_id = NULL
WHERE a.customer_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM customers_clean c
      WHERE c.customer_id = a.customer_id
  );



-- =====================================================
-- 4. BALANCE CLEANING
-- =====================================================

-- Convert empty balance values to NULL
UPDATE accounts_clean
SET balance = NULL
WHERE balance IS NOT NULL
  AND TRIM(balance) = '';


-- The audit found valid thousands-separated values such as 12,500.50.
-- Remove commas only when the entire value follows a valid numeric pattern.
UPDATE accounts_clean
SET balance = REPLACE(TRIM(balance), ',', '')
WHERE balance IS NOT NULL
  AND TRIM(balance)
      ~ '^-?[0-9]{1,3}(,[0-9]{3})+(\.[0-9]+)?$';


-- Values such as 'abc' and 'N/A' cannot be interpreted reliably
-- as balances and are therefore set to NULL.
UPDATE accounts_clean
SET balance = NULL
WHERE balance IS NOT NULL
  AND TRIM(balance) !~ '^-?[0-9]+(\.[0-9]+)?$';


-- Negative balances are intentionally preserved because they may
-- represent valid overdrafts.


-- Verify that all remaining non-null balances are numeric
SELECT balance
FROM accounts_clean
WHERE balance IS NOT NULL
  AND TRIM(balance) !~ '^-?[0-9]+(\.[0-9]+)?$';


-- Convert balance from TEXT to NUMERIC
ALTER TABLE accounts_clean
ALTER COLUMN balance TYPE NUMERIC(12,2)
USING balance::NUMERIC;



-- =====================================================
-- 5. OPENING DATE CLEANING
-- =====================================================

-- Convert empty opening_date values to NULL
UPDATE accounts_clean
SET opening_date = NULL
WHERE opening_date IS NOT NULL
  AND TRIM(opening_date) = '';


-- Standardize "/" separators.
-- Example: 2024/05/10 -> 2024-05-10
UPDATE accounts_clean
SET opening_date = REPLACE(TRIM(opening_date), '/', '-')
WHERE opening_date IS NOT NULL;


-- Set impossible DD-MM-YYYY dates to NULL before conversion
UPDATE accounts_clean
SET opening_date = NULL
WHERE opening_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
  AND NOT pg_input_is_valid(
        SUBSTRING(opening_date, 7, 4) || '-' ||
        SUBSTRING(opening_date, 4, 2) || '-' ||
        SUBSTRING(opening_date, 1, 2),
        'date'
      );


-- Convert valid DD-MM-YYYY dates to YYYY-MM-DD.
-- Example: 10-01-2025 -> 2025-01-10
UPDATE accounts_clean
SET opening_date =
      SUBSTRING(opening_date, 7, 4) || '-' ||
      SUBSTRING(opening_date, 4, 2) || '-' ||
      SUBSTRING(opening_date, 1, 2)
WHERE opening_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$';


-- Set remaining malformed or impossible dates to NULL.
-- This handles values such as 2026-15-02.
UPDATE accounts_clean
SET opening_date = NULL
WHERE opening_date IS NOT NULL
  AND NOT pg_input_is_valid(TRIM(opening_date), 'date');


-- Safety check for future opening dates
UPDATE accounts_clean
SET opening_date = NULL
WHERE opening_date IS NOT NULL
  AND opening_date::DATE > CURRENT_DATE;


-- Convert opening_date from TEXT to DATE
ALTER TABLE accounts_clean
ALTER COLUMN opening_date TYPE DATE
USING opening_date::DATE;



-- =====================================================
-- 6. COMPLETE DUPLICATE REMOVAL
-- =====================================================

-- The audit found five complete duplicate rows.
-- Keep one copy of each duplicated row.
DELETE FROM accounts_clean
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM accounts_clean
    GROUP BY account_id,
             customer_id,
             account_type,
             balance,
             opening_date,
             status,
             branch_id
);



-- =====================================================
-- 7. VALIDATION AFTER CLEANING
-- =====================================================

-- Expected final row count:
-- 855 raw rows - 5 duplicate copies = 850 rows
SELECT COUNT(*) AS total_rows
FROM accounts_clean;


-- Verify account IDs remain unique
SELECT account_id,
       COUNT(*) AS occurrence_count
FROM accounts_clean
WHERE account_id IS NOT NULL
GROUP BY account_id
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;


-- Verify no complete duplicate rows remain
SELECT account_id,
       customer_id,
       account_type,
       balance,
       opening_date,
       status,
       branch_id,
       COUNT(*) AS duplicate_count
FROM accounts_clean
GROUP BY account_id,
         customer_id,
         account_type,
         balance,
         opening_date,
         status,
         branch_id
HAVING COUNT(*) > 1;


-- Inspect missing values after cleaning
SELECT
    COUNT(*) FILTER (WHERE account_id IS NULL) AS account_id_missing,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_missing,
    COUNT(*) FILTER (WHERE account_type IS NULL) AS account_type_missing,
    COUNT(*) FILTER (WHERE balance IS NULL) AS balance_missing,
    COUNT(*) FILTER (WHERE opening_date IS NULL) AS opening_date_missing,
    COUNT(*) FILTER (WHERE status IS NULL) AS status_missing,
    COUNT(*) FILTER (WHERE branch_id IS NULL) AS branch_id_missing
FROM accounts_clean;

-- Verify standardized account types and their frequencies
SELECT account_type,
       COUNT(*) AS account_count
FROM accounts_clean
GROUP BY account_type
ORDER BY account_count DESC;

-- Inspect final balance range.
-- Negative balances are allowed.
SELECT
    MIN(balance) AS min_balance,
    MAX(balance) AS max_balance
FROM accounts_clean;


-- Verify no future opening dates remain
SELECT account_id,
       opening_date
FROM accounts_clean
WHERE opening_date > CURRENT_DATE;


-- Inspect final opening-date range
SELECT
    MIN(opening_date) AS earliest_opening_date,
    MAX(opening_date) AS latest_opening_date
FROM accounts_clean;


-- Verify all remaining customer IDs exist in customers_clean
SELECT a.account_id,
       a.customer_id
FROM accounts_clean a
LEFT JOIN customers_clean c
    ON a.customer_id = c.customer_id
WHERE a.customer_id IS NOT NULL
  AND c.customer_id IS NULL;


-- Verify all remaining branch IDs exist in branches_clean
SELECT a.account_id,
       a.branch_id
FROM accounts_clean a
LEFT JOIN branches_clean b
    ON a.branch_id = b.branch_id
WHERE a.branch_id IS NOT NULL
  AND b.branch_id IS NULL;


-- Verify final data types
SELECT column_name,
       data_type,
       character_maximum_length,
       numeric_precision,
       numeric_scale
FROM information_schema.columns
WHERE table_name = 'accounts_clean'
ORDER BY ordinal_position;


-- Final visual inspection
SELECT *
FROM accounts_clean
ORDER BY account_id;


COMMIT;


---------------------------------
-- loans_clean
---------------------------------

-- The audit identified missing values, complete duplicate rows,
-- an invalid customer reference, inconsistent categorical formatting,
-- recoverable and invalid numeric values, and impossible start dates.
-- Cleaning is limited to issues confirmed by the audit.

BEGIN;


-- =====================================================
-- 1. TEXT STANDARDIZATION
-- =====================================================

-- Standardize loan IDs
UPDATE loans_clean
SET loan_id = UPPER(TRIM(loan_id));


-- Standardize customer IDs
UPDATE loans_clean
SET customer_id = UPPER(TRIM(customer_id));


-- Standardize loan type capitalization
UPDATE loans_clean
SET loan_type = INITCAP(TRIM(loan_type));


-- Standardize status capitalization
UPDATE loans_clean
SET status = INITCAP(TRIM(status));


-- Convert empty strings to NULL
UPDATE loans_clean
SET loan_id     = NULLIF(loan_id, ''),
    customer_id = NULLIF(customer_id, ''),
    loan_type   = NULLIF(loan_type, ''),
    status      = NULLIF(status, '');



-- =====================================================
-- 2. ID DATA TYPES
-- =====================================================

-- The audit found a maximum loan_id length of 5 characters
ALTER TABLE loans_clean
ALTER COLUMN loan_id TYPE VARCHAR(5);


-- customer_id follows customers_clean identifier format
ALTER TABLE loans_clean
ALTER COLUMN customer_id TYPE VARCHAR(5);



-- =====================================================
-- 3. CUSTOMER REFERENTIAL CONSISTENCY
-- =====================================================

-- The audit found an invalid customer reference (C9999).
-- Since the correct customer is unknown, invalid references
-- are set to NULL rather than guessed.
UPDATE loans_clean l
SET customer_id = NULL
WHERE l.customer_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM customers_clean c
      WHERE c.customer_id = l.customer_id
  );



-- =====================================================
-- 4. LOAN AMOUNT CLEANING
-- =====================================================

-- Convert empty loan_amount values to NULL
UPDATE loans_clean
SET loan_amount = NULL
WHERE loan_amount IS NOT NULL
  AND TRIM(loan_amount) = '';


-- The audit found valid thousands-separated values such as 125,000.
-- Remove commas only when they represent valid thousands separators.
UPDATE loans_clean
SET loan_amount = REPLACE(TRIM(loan_amount), ',', '')
WHERE loan_amount IS NOT NULL
  AND TRIM(loan_amount)
      ~ '^-?[0-9]{1,3}(,[0-9]{3})+(\.[0-9]+)?$';


-- Values such as N/A cannot be interpreted as loan amounts
UPDATE loans_clean
SET loan_amount = NULL
WHERE loan_amount IS NOT NULL
  AND TRIM(loan_amount) !~ '^-?[0-9]+(\.[0-9]+)?$';


-- A loan amount must be strictly positive.
-- Zero and negative values are therefore set to NULL.
UPDATE loans_clean
SET loan_amount = NULL
WHERE loan_amount IS NOT NULL
  AND loan_amount::NUMERIC <= 0;


-- Verify all remaining values are valid positive numbers
SELECT loan_amount
FROM loans_clean
WHERE loan_amount IS NOT NULL
  AND (
      TRIM(loan_amount) !~ '^[0-9]+(\.[0-9]+)?$'
      OR loan_amount::NUMERIC <= 0
  );


-- Convert loan_amount to NUMERIC
ALTER TABLE loans_clean
ALTER COLUMN loan_amount TYPE NUMERIC(12,2)
USING loan_amount::NUMERIC;



-- =====================================================
-- 5. INTEREST RATE CLEANING
-- =====================================================

-- Convert empty interest_rate values to NULL
UPDATE loans_clean
SET interest_rate = NULL
WHERE interest_rate IS NOT NULL
  AND TRIM(interest_rate) = '';


-- The audit found percentage-formatted values such as 4.5%.
-- Remove the percentage sign when the underlying value is numeric.
UPDATE loans_clean
SET interest_rate =
    REPLACE(TRIM(interest_rate), '%', '')
WHERE interest_rate IS NOT NULL
  AND TRIM(interest_rate) ~ '^-?[0-9]+(\.[0-9]+)?%$';


-- Values such as N/A cannot be interpreted as interest rates
UPDATE loans_clean
SET interest_rate = NULL
WHERE interest_rate IS NOT NULL
  AND TRIM(interest_rate) !~ '^-?[0-9]+(\.[0-9]+)?$';


-- Negative interest rates are considered invalid for this dataset
UPDATE loans_clean
SET interest_rate = NULL
WHERE interest_rate IS NOT NULL
  AND interest_rate::NUMERIC < 0;


-- Verify all remaining interest rates are valid
SELECT interest_rate
FROM loans_clean
WHERE interest_rate IS NOT NULL
  AND (
      TRIM(interest_rate) !~ '^[0-9]+(\.[0-9]+)?$'
      OR interest_rate::NUMERIC < 0
  );


-- Convert interest_rate to NUMERIC
ALTER TABLE loans_clean
ALTER COLUMN interest_rate TYPE NUMERIC(5,2)
USING interest_rate::NUMERIC;


-- =====================================================
-- 6. START DATE CLEANING
-- =====================================================

-- Convert empty start_date values to NULL
UPDATE loans_clean
SET start_date = NULL
WHERE start_date IS NOT NULL
  AND TRIM(start_date) = '';


-- Standardize YYYY/MM/DD dates to YYYY-MM-DD
-- Example: 2025/06/01 -> 2025-06-01
UPDATE loans_clean
SET start_date = REPLACE(TRIM(start_date), '/', '-')
WHERE start_date ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2}$';


-- Set impossible DD-MM-YYYY dates to NULL before conversion
UPDATE loans_clean
SET start_date = NULL
WHERE start_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
  AND NOT pg_input_is_valid(
        SUBSTRING(start_date, 7, 4) || '-' ||
        SUBSTRING(start_date, 4, 2) || '-' ||
        SUBSTRING(start_date, 1, 2),
        'date'
      );


-- Convert valid DD-MM-YYYY dates to YYYY-MM-DD
-- Example: 01-03-2024 -> 2024-03-01
UPDATE loans_clean
SET start_date =
      SUBSTRING(start_date, 7, 4) || '-' ||
      SUBSTRING(start_date, 4, 2) || '-' ||
      SUBSTRING(start_date, 1, 2)
WHERE start_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$';


-- Set remaining malformed or impossible dates to NULL
-- Example: 2026-14-03
UPDATE loans_clean
SET start_date = NULL
WHERE start_date IS NOT NULL
  AND NOT pg_input_is_valid(TRIM(start_date), 'date');


-- Set valid future dates to NULL
UPDATE loans_clean
SET start_date = NULL
WHERE start_date IS NOT NULL
  AND start_date::DATE > CURRENT_DATE;


-- Convert start_date from TEXT to DATE
ALTER TABLE loans_clean
ALTER COLUMN start_date TYPE DATE
USING start_date::DATE;

-- =====================================================
-- 7. COMPLETE DUPLICATE REMOVAL
-- =====================================================

-- The audit found four complete duplicated rows.
-- Keep one copy of each duplicated record.
DELETE FROM loans_clean
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM loans_clean
    GROUP BY loan_id,
             customer_id,
             loan_type,
             loan_amount,
             interest_rate,
             start_date,
             status
);



-- =====================================================
-- 8. VALIDATION AFTER CLEANING
-- =====================================================

-- Expected final row count:
-- 224 raw rows - 4 duplicate copies = 220 rows
SELECT COUNT(*) AS total_rows
FROM loans_clean;


-- Verify loan IDs remain unique
SELECT loan_id,
       COUNT(*) AS occurrence_count
FROM loans_clean
WHERE loan_id IS NOT NULL
GROUP BY loan_id
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;


-- Verify no complete duplicate rows remain
SELECT loan_id,
       customer_id,
       loan_type,
       loan_amount,
       interest_rate,
       start_date,
       status,
       COUNT(*) AS duplicate_count
FROM loans_clean
GROUP BY loan_id,
         customer_id,
         loan_type,
         loan_amount,
         interest_rate,
         start_date,
         status
HAVING COUNT(*) > 1;


-- Inspect missing values after cleaning
SELECT
    COUNT(*) FILTER (WHERE loan_id IS NULL) AS loan_id_missing,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_missing,
    COUNT(*) FILTER (WHERE loan_type IS NULL) AS loan_type_missing,
    COUNT(*) FILTER (WHERE loan_amount IS NULL) AS loan_amount_missing,
    COUNT(*) FILTER (WHERE interest_rate IS NULL) AS interest_rate_missing,
    COUNT(*) FILTER (WHERE start_date IS NULL) AS start_date_missing,
    COUNT(*) FILTER (WHERE status IS NULL) AS status_missing
FROM loans_clean;


-- Verify loan amounts are strictly positive
SELECT loan_id,
       loan_amount
FROM loans_clean
WHERE loan_amount <= 0;


-- Inspect final loan amount range
SELECT
    MIN(loan_amount) AS min_loan_amount,
    MAX(loan_amount) AS max_loan_amount
FROM loans_clean;


-- Verify interest rates are non-negative
SELECT loan_id,
       interest_rate
FROM loans_clean
WHERE interest_rate < 0;


-- Inspect final interest rate range
SELECT
    MIN(interest_rate) AS min_interest_rate,
    MAX(interest_rate) AS max_interest_rate
FROM loans_clean;


-- Verify no future start dates remain
SELECT loan_id,
       start_date
FROM loans_clean
WHERE start_date > CURRENT_DATE;


-- Inspect final start-date range
SELECT
    MIN(start_date) AS earliest_start_date,
    MAX(start_date) AS latest_start_date
FROM loans_clean;


-- Verify all remaining customer IDs exist in customers_clean
SELECT l.loan_id,
       l.customer_id
FROM loans_clean l
LEFT JOIN customers_clean c
    ON l.customer_id = c.customer_id
WHERE l.customer_id IS NOT NULL
  AND c.customer_id IS NULL;


-- Inspect standardized loan types
SELECT DISTINCT loan_type
FROM loans_clean
ORDER BY loan_type;


-- Inspect standardized status values
SELECT DISTINCT status
FROM loans_clean
ORDER BY status;


-- Verify final data types
SELECT column_name,
       data_type,
       character_maximum_length,
       numeric_precision,
       numeric_scale
FROM information_schema.columns
WHERE table_name = 'loans_clean'
ORDER BY ordinal_position;


-- Final visual inspection
SELECT *
FROM loans_clean
ORDER BY loan_id;


COMMIT;


---------------------------------
-- transactions_clean
---------------------------------

-- The audit identified missing values, complete duplicate rows,
-- invalid account references, recoverable and invalid amount values,
-- zero and negative transaction amounts, and non-standard or impossible dates.
-- Negative amounts are treated as anomalous because transaction direction
-- is already represented by transaction_type in this dataset.
BEGIN;


-- =====================================================
-- 1. TEXT STANDARDIZATION
-- =====================================================

-- Standardize transaction IDs
UPDATE transactions_clean
SET transaction_id = UPPER(TRIM(transaction_id));


-- Standardize account IDs
UPDATE transactions_clean
SET account_id = UPPER(TRIM(account_id));


-- Standardize transaction type capitalization
UPDATE transactions_clean
SET transaction_type = INITCAP(TRIM(transaction_type));


-- Normalize confirmed transaction type naming variants.
-- 'TransferIn' is a formatting variant of 'Transfer In'.
-- 'Withdraw' is standardized to the existing 'Cash Withdrawal' category.
-- 'Card' is intentionally kept separate from 'Card Payment'
-- because the available data does not provide enough evidence
-- to confirm that both labels represent the same operation.
UPDATE transactions_clean
SET transaction_type = CASE
    WHEN LOWER(REPLACE(TRIM(transaction_type), ' ', '')) = 'transferin'
        THEN 'Transfer In'
    WHEN LOWER(TRIM(transaction_type)) = 'withdraw'
        THEN 'Cash Withdrawal'
    ELSE transaction_type
END;


-- Standardize channel values
UPDATE transactions_clean
SET channel = CASE
    WHEN UPPER(TRIM(channel)) = 'ATM' THEN 'ATM'
    ELSE INITCAP(TRIM(channel))
END;

UPDATE transactions_clean
SET merchant_category =
    NULLIF(INITCAP(TRIM(merchant_category)), '');

  

-- Convert empty strings to NULL
UPDATE transactions_clean
SET transaction_id   = NULLIF(transaction_id, ''),
    account_id       = NULLIF(account_id, ''),
    transaction_type = NULLIF(transaction_type, ''),
    channel          = NULLIF(channel, '');



-- =====================================================
-- 2. ID DATA TYPES
-- =====================================================

-- The audit found a maximum transaction_id length of 7 characters
ALTER TABLE transactions_clean
ALTER COLUMN transaction_id TYPE VARCHAR(7);


-- account_id follows the identifier format used in accounts_clean
ALTER TABLE transactions_clean
ALTER COLUMN account_id TYPE VARCHAR(6);



-- =====================================================
-- 3. ACCOUNT REFERENTIAL CONSISTENCY
-- =====================================================

-- Invalid account references such as A99999 cannot be corrected
-- reliably, so they are set to NULL rather than guessed.
UPDATE transactions_clean t
SET account_id = NULL
WHERE t.account_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM accounts_clean a
      WHERE a.account_id = t.account_id
  );



-- =====================================================
-- 4. AMOUNT CLEANING
-- =====================================================

-- Convert empty amount values to NULL
UPDATE transactions_clean
SET amount = NULL
WHERE amount IS NOT NULL
  AND TRIM(amount) = '';


-- The audit found valid thousands-separated values
-- such as 1,250.00.
UPDATE transactions_clean
SET amount = REPLACE(TRIM(amount), ',', '')
WHERE amount IS NOT NULL
  AND TRIM(amount)
      ~ '^-?[0-9]{1,3}(,[0-9]{3})+(\.[0-9]+)?$';


-- Values such as N/A and abc cannot be interpreted
-- reliably as transaction amounts.
UPDATE transactions_clean
SET amount = NULL
WHERE amount IS NOT NULL
  AND TRIM(amount) !~ '^-?[0-9]+(\.[0-9]+)?$';


-- The audit found zero-value transactions.
-- A transaction with no monetary movement is considered invalid
-- for this analytical dataset.
UPDATE transactions_clean
SET amount = NULL
WHERE amount IS NOT NULL
  AND amount::NUMERIC = 0;



-- Verify all remaining non-null amounts are numeric
SELECT amount
FROM transactions_clean
WHERE amount IS NOT NULL
  AND TRIM(amount) !~ '^-?[0-9]+(\.[0-9]+)?$';


-- The audit showed that transaction direction is represented by transaction_type
-- and that nearly all transaction amounts are positive.
-- Negative amounts are therefore treated as anomalous values.
UPDATE transactions_clean
SET amount = NULL
WHERE amount IS NOT NULL
  AND amount::NUMERIC < 0;

-- Convert amount from TEXT to NUMERIC
ALTER TABLE transactions_clean
ALTER COLUMN amount TYPE NUMERIC(12,2)
USING amount::NUMERIC;



-- =====================================================
-- 5. TRANSACTION DATE CLEANING
-- =====================================================

-- Convert empty transaction_date values to NULL
UPDATE transactions_clean
SET transaction_date = NULL
WHERE transaction_date IS NOT NULL
  AND TRIM(transaction_date) = '';


-- Standardize "/" separators.
-- Example: 2025/04/09 -> 2025-04-09
UPDATE transactions_clean
SET transaction_date = REPLACE(TRIM(transaction_date), '/', '-')
WHERE transaction_date IS NOT NULL;


-- Set impossible DD-MM-YYYY dates to NULL before conversion
UPDATE transactions_clean
SET transaction_date = NULL
WHERE transaction_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
  AND NOT pg_input_is_valid(
        SUBSTRING(transaction_date, 7, 4) || '-' ||
        SUBSTRING(transaction_date, 4, 2) || '-' ||
        SUBSTRING(transaction_date, 1, 2),
        'date'
      );


-- Convert valid DD-MM-YYYY values to YYYY-MM-DD.
-- Example: 09-05-2026 -> 2026-05-09
UPDATE transactions_clean
SET transaction_date =
      SUBSTRING(transaction_date, 7, 4) || '-' ||
      SUBSTRING(transaction_date, 4, 2) || '-' ||
      SUBSTRING(transaction_date, 1, 2)
WHERE transaction_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$';


-- Set malformed or impossible remaining dates to NULL.
-- This handles values such as not_a_date and 2026-13-02.
UPDATE transactions_clean
SET transaction_date = NULL
WHERE transaction_date IS NOT NULL
  AND NOT pg_input_is_valid(TRIM(transaction_date), 'date');


-- Safety check for future transaction dates
UPDATE transactions_clean
SET transaction_date = NULL
WHERE transaction_date IS NOT NULL
  AND transaction_date::DATE > CURRENT_DATE;


-- Convert transaction_date from TEXT to DATE
ALTER TABLE transactions_clean
ALTER COLUMN transaction_date TYPE DATE
USING transaction_date::DATE;





-- =====================================================
-- 6. COMPLETE DUPLICATE REMOVAL
-- =====================================================

-- The audit found 18 complete duplicate records.
-- Keep one copy of each duplicated transaction.
DELETE FROM transactions_clean
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM transactions_clean
    GROUP BY transaction_id,
             account_id,
             transaction_type,
             channel,
             amount,
             transaction_date,
             merchant_category
);



-- =====================================================
-- 7. VALIDATION AFTER CLEANING
-- =====================================================

-- Expected final row count:
-- 8018 raw rows - 18 duplicate copies = 8000 rows
SELECT COUNT(*) AS total_rows
FROM transactions_clean;


-- Verify transaction IDs remain unique
SELECT transaction_id,
       COUNT(*) AS occurrence_count
FROM transactions_clean
WHERE transaction_id IS NOT NULL
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;


-- Verify no complete duplicate rows remain
SELECT transaction_id,
       account_id,
       transaction_type,
       channel,
       amount,
       transaction_date,
       COUNT(*) AS duplicate_count
FROM transactions_clean
GROUP BY transaction_id,
         account_id,
         transaction_type,
         channel,
         amount,
         transaction_date
HAVING COUNT(*) > 1;


-- Inspect missing values after cleaning
SELECT
    COUNT(*) FILTER (WHERE transaction_id IS NULL) AS transaction_id_missing,
    COUNT(*) FILTER (WHERE account_id IS NULL) AS account_id_missing,
    COUNT(*) FILTER (WHERE transaction_type IS NULL) AS transaction_type_missing,
    COUNT(*) FILTER (WHERE channel IS NULL) AS channel_missing,
    COUNT(*) FILTER (WHERE amount IS NULL) AS amount_missing,
    COUNT(*) FILTER (WHERE transaction_date IS NULL) AS transaction_date_missing
FROM transactions_clean;




-- Verify no zero transaction amounts remain
SELECT transaction_id,
       amount
FROM transactions_clean
WHERE amount = 0;

-- Verify no negative transaction amounts remain
SELECT transaction_id,
       transaction_type,
       amount
FROM transactions_clean
WHERE amount < 0;

-- Inspect final amount range.
SELECT
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount
FROM transactions_clean;


-- Verify no future transaction dates remain
SELECT transaction_id,
       transaction_date
FROM transactions_clean
WHERE transaction_date > CURRENT_DATE;


-- Inspect final transaction-date range
SELECT
    MIN(transaction_date) AS earliest_transaction_date,
    MAX(transaction_date) AS latest_transaction_date
FROM transactions_clean;


-- Verify all remaining account IDs exist in accounts_clean
SELECT t.transaction_id,
       t.account_id
FROM transactions_clean t
LEFT JOIN accounts_clean a
    ON t.account_id = a.account_id
WHERE t.account_id IS NOT NULL
  AND a.account_id IS NULL;


-- Verify standardized transaction types and their frequencies
SELECT transaction_type,
       COUNT(*) AS transaction_count
FROM transactions_clean
GROUP BY transaction_type
ORDER BY transaction_count DESC;


-- Inspect standardized channels
SELECT DISTINCT channel
FROM transactions_clean
ORDER BY channel;

-- Inspect merchant category distribution after cleaning
SELECT
    merchant_category,
    COUNT(*) AS transaction_count
FROM transactions_clean
GROUP BY merchant_category
ORDER BY transaction_count DESC;

-- Verify merchant categories contain no surrounding spaces or empty strings
SELECT transaction_id, merchant_category
FROM transactions_clean
WHERE merchant_category IS NOT NULL
  AND (
      merchant_category <> TRIM(merchant_category)
      OR merchant_category = ''
  );

-- Verify final data types
SELECT column_name,
       data_type,
       character_maximum_length,
       numeric_precision,
       numeric_scale
FROM information_schema.columns
WHERE table_name = 'transactions_clean'
ORDER BY ordinal_position;

-- Identify transactions dated before account opening
SELECT
    COUNT(*) AS transactions_before_account_opening
FROM transactions_clean t
JOIN accounts_clean a
    ON t.account_id = a.account_id
WHERE t.transaction_date < a.opening_date;

-- Count accounts opened before customer signup
SELECT
    COUNT(*) AS accounts_before_customer_signup
FROM accounts_clean a
JOIN customers_clean c
    ON a.customer_id = c.customer_id
WHERE a.opening_date < c.signup_date;

-- Count loans started before customer signup
SELECT
    COUNT(*) AS loans_before_customer_signup
FROM loans_clean l
JOIN customers_clean c
    ON l.customer_id = c.customer_id
WHERE l.start_date < c.signup_date;

-- Final visual inspection
SELECT *
FROM transactions_clean
ORDER BY transaction_id;



COMMIT;


-- =====================================================
-- SCHEMA CONSTRAINTS
-- =====================================================

-- Primary keys
ALTER TABLE branches_clean
ADD PRIMARY KEY (branch_id);

ALTER TABLE customers_clean
ADD PRIMARY KEY (customer_id);

ALTER TABLE accounts_clean
ADD PRIMARY KEY (account_id);

ALTER TABLE loans_clean
ADD PRIMARY KEY (loan_id);

ALTER TABLE transactions_clean
ADD PRIMARY KEY (transaction_id);


-- Foreign keys
ALTER TABLE customers_clean
ADD CONSTRAINT fk_customers_branch
FOREIGN KEY (branch_id)
REFERENCES branches_clean(branch_id);

ALTER TABLE accounts_clean
ADD CONSTRAINT fk_accounts_customer
FOREIGN KEY (customer_id)
REFERENCES customers_clean(customer_id);

ALTER TABLE accounts_clean
ADD CONSTRAINT fk_accounts_branch
FOREIGN KEY (branch_id)
REFERENCES branches_clean(branch_id);

ALTER TABLE loans_clean
ADD CONSTRAINT fk_loans_customer
FOREIGN KEY (customer_id)
REFERENCES customers_clean(customer_id);

ALTER TABLE transactions_clean
ADD CONSTRAINT fk_transactions_account
FOREIGN KEY (account_id)
REFERENCES accounts_clean(account_id);
