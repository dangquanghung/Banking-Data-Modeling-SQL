# Banking-Data-Modeling-SQL

Star schema design for a banking transaction data mart on MS SQL Server, plus query tuning notes. Mock data only.

## Purpose

Transactional (OLTP) systems are normalized for writes. Reporting queries on them need many joins and are slow. A star schema separates:

- **Fact table** (`Fact_Transactions`): one row per transaction, numeric measures (amount) and foreign keys.
- **Dimensions** (`Dim_Customer`, `Dim_Date`): descriptive attributes used to filter and group.

Benefits: fewer joins, predictable query patterns, easy indexing, simple for BI tools.

## Model

```
Dim_Customer ──┐
               ├──< Fact_Transactions
Dim_Date ──────┘
```

Grain: one row per transaction.

## Design decisions

- Surrogate integer keys on dimensions (`CustomerKey`, `DateKey` as `YYYYMMDD`).
- `Dim_Customer` carries `EffectiveFrom / EffectiveTo / IsCurrent` for SCD Type 2.
- `Amount` stored as `DECIMAL(18,2)`, never float.
- Foreign keys enforced; non-clustered indexes on FK columns for join and filter performance.

## Files

| File | Description |
|---|---|
| `schema_star.sql` | DDL for fact and dimension tables |
| `query_optimization.md` | Indexing, execution plan analysis, window function example |

## Run

```sql
-- SQL Server 2019+
:r schema_star.sql
```
or open it in SSMS / Azure Data Studio and execute.

