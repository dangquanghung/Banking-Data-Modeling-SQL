/* Star schema for banking transactions - MS SQL Server */

IF DB_ID('BankingDW') IS NULL
    CREATE DATABASE BankingDW;
GO
USE BankingDW;
GO

/* ---------- Dim_Customer (SCD Type 2) ---------- */
CREATE TABLE dbo.Dim_Customer (
    CustomerKey     INT IDENTITY(1,1) NOT NULL,
    CustomerID      INT               NOT NULL,   -- business key from source
    FullName        NVARCHAR(200)     NOT NULL,
    Segment         NVARCHAR(50)      NULL,       -- Retail, SME, Corporate
    City            NVARCHAR(100)     NULL,
    OpenDate        DATE              NULL,
    EffectiveFrom   DATE              NOT NULL,
    EffectiveTo     DATE              NULL,
    IsCurrent       BIT               NOT NULL CONSTRAINT DF_DimCustomer_IsCurrent DEFAULT (1),
    CONSTRAINT PK_Dim_Customer PRIMARY KEY CLUSTERED (CustomerKey)
);
GO

CREATE INDEX IX_Dim_Customer_CustomerID
    ON dbo.Dim_Customer (CustomerID, IsCurrent);
GO

/* ---------- Dim_Date ---------- */
CREATE TABLE dbo.Dim_Date (
    DateKey         INT          NOT NULL,        -- YYYYMMDD
    FullDate        DATE         NOT NULL,
    [Year]          SMALLINT     NOT NULL,
    [Quarter]       TINYINT      NOT NULL,
    [Month]         TINYINT      NOT NULL,
    MonthName       NVARCHAR(20) NOT NULL,
    [Day]           TINYINT      NOT NULL,
    DayOfWeek       TINYINT      NOT NULL,
    IsWeekend       BIT          NOT NULL,
    CONSTRAINT PK_Dim_Date PRIMARY KEY CLUSTERED (DateKey),
    CONSTRAINT UQ_Dim_Date_FullDate UNIQUE (FullDate)
);
GO

/* ---------- Fact_Transactions ---------- */
CREATE TABLE dbo.Fact_Transactions (
    TransactionKey  BIGINT IDENTITY(1,1) NOT NULL,
    TransactionID   VARCHAR(30)    NOT NULL,      -- business key
    CustomerKey     INT            NOT NULL,
    DateKey         INT            NOT NULL,
    TxnType         VARCHAR(20)    NOT NULL,      -- DEPOSIT, WITHDRAWAL, TRANSFER
    Currency        CHAR(3)        NOT NULL,
    Amount          DECIMAL(18,2)  NOT NULL,
    TxnTimestamp    DATETIME2(0)   NOT NULL,
    CONSTRAINT PK_Fact_Transactions PRIMARY KEY CLUSTERED (TransactionKey),
    CONSTRAINT UQ_Fact_Transactions_TxnID UNIQUE (TransactionID),
    CONSTRAINT FK_Fact_Txn_Customer FOREIGN KEY (CustomerKey)
        REFERENCES dbo.Dim_Customer (CustomerKey),
    CONSTRAINT FK_Fact_Txn_Date FOREIGN KEY (DateKey)
        REFERENCES dbo.Dim_Date (DateKey),
    CONSTRAINT CK_Fact_Txn_Amount CHECK (Amount >= 0)
);
GO

CREATE INDEX IX_Fact_Txn_CustomerKey_DateKey
    ON dbo.Fact_Transactions (CustomerKey, DateKey)
    INCLUDE (Amount);
GO

CREATE INDEX IX_Fact_Txn_DateKey
    ON dbo.Fact_Transactions (DateKey);
GO

