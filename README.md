# Bank Customer Analytics & Segmentation — SQL Portfolio Project

## Project Overview

An end-to-end PostgreSQL project analyzing a synthetic banking dataset containing customers, accounts, transactions, loans, and branches.

**Workflow:** Raw Data → Data Quality Audit → Data Cleaning → Validation → Business Analysis → Customer Segmentation

**Technologies:** PostgreSQL, SQL, DBeaver, VS Code, Git/GitHub

---

## Dataset

The synthetic dataset was created specifically for this project and includes missing values, duplicates, inconsistent categories, invalid numeric values, malformed dates, and broken references.

| Entity | Raw Records | Cleaned Records |
|---|---:|---:|
| Customers | 606 | 600 |
| Accounts | 855 | 850 |
| Transactions | 8,018 | 8,000 |
| Loans | 224 | 220 |
| Branches | 10 | 10 |
| **Total** | **9,713** | **9,680** |

## Repository Structure
```text
bank_customer_segmentation_sql/
├── data/
│   ├── accounts_raw.csv
│   ├── branches_raw.csv
│   ├── customers_raw.csv
│   ├── loans_raw.csv
│   └── transactions_raw.csv
├── docs/
│   ├── data_dictionary.md
│   └── data_quality_checklist.md
├── sql/
│   ├── 01_create_raw_tables.sql
│   ├── 02_data_quality_audit.sql
│   ├── 03_data_cleaning.sql
│   └── 04_analysis.sql
└── README.md
```


## 1. Data Quality Audit

**File:** `02_data_quality_audit.sql`

The raw tables were systematically audited for:

- Missing values and duplicates
- Invalid foreign-key references
- Inconsistent text and categories
- Invalid or impossible numeric values
- Malformed, impossible, and future dates

Every cleaning decision was based on an identified data quality issue.

## 2. Data Cleaning

**File:** `03_data_cleaning.sql`

The original raw tables were preserved, and separate `_clean` tables were created.

The cleaning process included text standardization, numeric and date validation, handling missing values, duplicate removal, and relational integrity checks.

### Key Cleaning Decisions

| Issue | Treatment |
|---|---|
| `Save` | Standardized to `Savings` |
| `TransferIn` | Standardized to `Transfer In` |
| `Withdraw` | Standardized to `Cash Withdrawal` |
| `Card` vs. `Card Payment` | Kept separate due to ambiguous meaning |
| `12,500.50` | Converted to `12500.50` |
| Recoverable date formats | Converted to PostgreSQL `DATE` |
| Invalid unrecoverable values | Converted to `NULL` |
| Negative account balances | Preserved as potentially valid overdrafts |
| Complete duplicate records | Removed while preserving one copy |

Only confirmed duplicate rows were automatically removed. Primary-key and foreign-key constraints were added after cleaning to enforce relational integrity.

## 3. Business Analysis

**File:** `04_analysis.sql`

The project includes 17 SQL analyses covering branch performance, account balances, transaction activity, loans, customer segmentation, rankings and month-over-month changes.

## 4. Key Insights

### Branch Performance

| Metric | Leading Branch | Value |
|---|---|---:|
| Highest total account balance | Marseille Vieux-Port | 795,121.46 |
| Highest average account balance | Paris République | 8,324.32 |
| Highest total loan amount | Toulouse Capitole | 5,162,037.03 |

All monetary values are expressed in EUR.
Toulouse Capitole also has the largest customer base. However, Marseille leads in total account balances, illustrating that customer count and financial holdings do not necessarily follow the same pattern.

### Account Portfolio

Checking and Savings accounts dominate the portfolio.

### Transaction Activity

- **Card Payment** is the most frequent transaction type, followed by Direct Debit and Transfer In.
- Transaction activity is relatively evenly distributed across Web, Mobile, Card, ATM, and Branch channels.

### Customer Segmentation

| Percentile | Balance (EUR) |
|---|---:|
| Q1 (25%) | 3,964.19 |
| Median (50%) | 11,515.93 |
| Q3 (75%) | 20,678.79 |

Quartiles are calculated for identified customers with at least one known account balance. Customers without linked accounts are excluded. For customers with missing account balances, totals reflect known balances only. Segmentation thresholds are calculated dynamically in SQL.

The project also combines account balances and transaction frequency to identify **high-value customers with relatively low activity**, a potentially useful segment for customer engagement and targeted CRM initiatives.

These segments are descriptive and should not be interpreted as customer profitability or creditworthiness.

## 5. SQL Skills Demonstrated

**Data Cleaning:** `CREATE TABLE AS SELECT`, `UPDATE`, `DELETE`, `ALTER TABLE`, `CASE`, `TRIM`, `NULLIF`, regex, type conversion, date validation, primary and foreign keys.

**Data Analysis:** `JOIN`, `GROUP BY`, `HAVING`, aggregate functions, subqueries, CTEs, `COALESCE`, `DATE_TRUNC`, `PERCENTILE_CONT`, window functions, `RANK`, `PARTITION BY`, `LAG`.

## 6. How to Run

Prerequisites: PostgreSQL with support for pg_input_is_valid, and DBeaver for the CSV import procedure described below.

### 1. Create and connect to the database

Create a PostgreSQL database:

```sql
CREATE DATABASE bank_segmentation;
```

In DBeaver, connect to the `bank_segmentation` database before continuing.

### 2. Create the raw tables

Execute:

`sql/01_create_raw_tables.sql`

### 3. Import the CSV files

In DBeaver, right-click each raw table and select **Import Data → CSV**.

Import each file into its corresponding table:

| CSV file | Target table |
|---|---|
| data/branches_raw.csv | branches_raw |
| data/customers_raw.csv | customers_raw |
| data/accounts_raw.csv | accounts_raw |
| data/loans_raw.csv | loans_raw |
| data/transactions_raw.csv | transactions_raw |

Use UTF-8 encoding, a comma separator, double quotes as the quote character, and the first row as column headers. Import empty fields as NULL.

### 4. Run the audit, cleaning and analysis

Execute these scripts in order:

1. `sql/02_data_quality_audit.sql`
2. `sql/03_data_cleaning.sql`
3. `sql/04_analysis.sql`

## 7. Limitations & Future Improvements

The dataset is synthetic. The analysis and customer segmentation are descriptive rather than predictive and do not establish customer profitability or creditworthiness.

Some invalid values were converted to NULL, and ambiguous categories were preserved. Missing balances may result in incomplete customer totals. Loan amounts represent original loan amounts rather than outstanding debt.

Cross-table validation identified:

- **1,241 transactions** dated before the opening date of their associated account.
- **443 accounts** opened before their owner's signup date.
- **97 loans** starting before their borrower's signup date.

These records were retained because the correct dates could not be established. The meaning of `signup_date` also requires clarification: it may represent the beginning of the banking relationship or registration for a digital service.

These issues limit time-based analysis. They must be resolved or handled through explicit exclusion rules before constructing temporal features in Bank360.

Future improvements include automated validation checks, a documented data contract for Bank360, Python-based customer analysis, and an interactive dashboard.
---

## Author
**Mostafa Harmoush**  
