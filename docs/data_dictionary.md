# Data Dictionary

## branches_raw
- branch_id: branch identifier
- branch_name: branch name
- city: branch city
- region: French region
- opened_date: branch opening date

## customers_raw
- customer_id: customer identifier
- first_name, last_name: synthetic customer name
- birth_date: date of birth
- city: city of residence
- profession: occupation
- annual_income: annual income in EUR
- signup_date: customer registration date
- branch_id: home branch

## accounts_raw
- account_id: bank account identifier
- customer_id: owner
- account_type: Checking / Savings / Business
- balance: current account balance in EUR
- opening_date: account opening date
- status: Active / Dormant / Closed
- branch_id: account branch

## transactions_raw
- transaction_id: transaction identifier
- account_id: related account
- transaction_date: transaction date
- transaction_type: type of transaction
- channel: Card / Mobile / Web / ATM / Branch
- amount: transaction amount in EUR
- merchant_category: spending category

## loans_raw
- loan_id: loan identifier
- customer_id: borrower
- loan_type: Personal / Auto / Mortgage / Student
- loan_amount: original loan amount in EUR
- interest_rate: annual interest rate
- start_date: loan start date
- status: Active / Paid / Late / Defaulted
