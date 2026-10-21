# Data Quality Audit Checklist

This checklist defines the data quality controls applied before and after cleaning.

The objective is to identify issues through SQL rather than assuming which records are incorrect.

## Before Cleaning

Check each table for:

- `NULL` values and empty strings
- Exact duplicate rows
- Duplicate IDs
- Leading and trailing whitespace
- Inconsistent capitalization
- Unexpected categorical values
- Invalid numeric formats
- Impossible or suspicious numeric values
- Invalid date formats
- Future or impossible dates
- Broken customer, account, or branch references
- Orphan records
- Referential-integrity issues

## After Cleaning

Validate that:

- Primary keys are unique and non-null
- Foreign keys reference existing parent records
- Numeric columns can be safely cast
- Date columns can be safely cast
- Categorical values belong to the accepted domain
- Confirmed duplicate rows have been removed
- Invalid references have been resolved or set to `NULL`
- Final row counts are consistent with the cleaning decisions