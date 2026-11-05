# SQL Server Query Optimization Notes

Based on `Fact_Transactions` / `Dim_Customer` from `schema_star.sql`.

## 1. Indexing: clustered vs. non-clustered (covering)

A clustered index defines the physical order of the table. One per table. Choose a narrow, ever-increasing, unique key to avoid page splits and keep non-clustered indexes small. Here: `TransactionKey BIGINT IDENTITY`.

Without a useful index, this query scans the whole fact table:

```sql
SELECT CustomerKey, SUM(Amount) AS TotalAmount
FROM dbo.Fact_Transactions
WHERE DateKey BETWEEN 20260101 AND 20260131
GROUP BY CustomerKey;
```

Add a non-clustered index that covers the filter and the selected columns:

```sql
CREATE INDEX IX_Fact_Txn_DateKey_Customer
    ON dbo.Fact_Transactions (DateKey, CustomerKey)
    INCLUDE (Amount);
```

Result: the plan changes from *Clustered Index Scan* to *Index Seek* with no Key Lookup, because `INCLUDE (Amount)` makes the index covering.

Notes:
- More indexes slow down INSERT/UPDATE. For bulk loads, consider loading then rebuilding indexes.
- For very large fact tables, consider a clustered columnstore index (analytical scans, high compression).

## 2. Execution plan analysis

Enable statistics and the actual plan (SSMS: Ctrl+M):

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
```

What to check:

| Signal | Meaning | Typical fix |
|---|---|---|
| Clustered Index / Table Scan on large table | No usable index or non-sargable predicate | Add index, rewrite predicate |
| Key Lookup (high count) | Index not covering | Add `INCLUDE` columns |
| Estimated vs. actual rows far apart | Stale statistics / parameter sniffing | `UPDATE STATISTICS`, `OPTION (RECOMPILE)` |
| Sort / Hash Match spilling to tempdb (warning icon) | Insufficient memory grant | Index to provide order, reduce rows earlier |
| High logical reads | Too much data touched | Index, filter earlier |

Non-sargable example:

```sql
-- Bad: function on column prevents index seek
WHERE YEAR(TxnTimestamp) = 2026

-- Good: range predicate
WHERE TxnTimestamp >= '2026-01-01' AND TxnTimestamp < '2027-01-01'
```

Compare `logical reads` before and after each change to confirm the improvement.

## 3. Window function: largest transaction per customer

```sql
WITH Ranked AS (
    SELECT
        f.CustomerKey,
        c.FullName,
        f.TransactionID,
        f.Amount,
        f.TxnTimestamp,
        RANK() OVER (
            PARTITION BY f.CustomerKey
            ORDER BY f.Amount DESC
        ) AS AmountRank
    FROM dbo.Fact_Transactions AS f
    JOIN dbo.Dim_Customer      AS c
        ON c.CustomerKey = f.CustomerKey
)
SELECT CustomerKey, FullName, TransactionID, Amount, TxnTimestamp
FROM Ranked
WHERE AmountRank = 1;
```

- `RANK()` returns ties (several transactions with the same max amount). Use `ROW_NUMBER()` for exactly one row per customer.
- Supporting index to avoid a large Sort:

```sql
CREATE INDEX IX_Fact_Txn_Customer_Amount
    ON dbo.Fact_Transactions (CustomerKey, Amount DESC)
    INCLUDE (TransactionID, TxnTimestamp);
```

