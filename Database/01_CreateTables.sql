/* ============================================================================
   Project      : MobileCare ERP & POS System
   Database     : MobileCareDB (Microsoft SQL Server 2019+)
   Script       : 01_CreateTables.sql
   Architecture : Two-Branch (Repair Tickets + POS Sales) + Shared Inventory & Treasury
   Tables Count : 16 Tables
   ============================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF DB_ID(N'MobileCareDB') IS NULL
BEGIN
    CREATE DATABASE [MobileCareDB];
END
GO

USE [MobileCareDB];
GO

/* ============================================================================
   1. CORE SYSTEM & LOOKUPS (4 Tables)
   ============================================================================ */

-- 1.1 Roles
CREATE TABLE dbo.Roles (
    RoleID          INT IDENTITY(1,1)   NOT NULL,
    RoleName        NVARCHAR(50)        NOT NULL,
    Description     NVARCHAR(200)       NULL,
    IsActive        BIT                 NOT NULL CONSTRAINT DF_Roles_IsActive DEFAULT (1),

    CONSTRAINT PK_Roles PRIMARY KEY CLUSTERED (RoleID),
    CONSTRAINT UQ_Roles_RoleName UNIQUE (RoleName)
);
GO

-- 1.2 PaymentMethods
CREATE TABLE dbo.PaymentMethods (
    PaymentMethodID INT IDENTITY(1,1)   NOT NULL,
    MethodName      NVARCHAR(50)        NOT NULL,
    IsActive        BIT                 NOT NULL CONSTRAINT DF_PaymentMethods_IsActive DEFAULT (1),

    CONSTRAINT PK_PaymentMethods PRIMARY KEY CLUSTERED (PaymentMethodID),
    CONSTRAINT UQ_PaymentMethods_MethodName UNIQUE (MethodName)
);
GO

-- 1.3 Users (Includes separate Profit Commission Rate & Damage Liability Rate)
CREATE TABLE dbo.Users (
    UserID              INT IDENTITY(1,1)   NOT NULL,
    FullName            NVARCHAR(100)       NOT NULL,
    Username            NVARCHAR(50)        NOT NULL,
    PasswordHash        NVARCHAR(255)       NOT NULL,
    RoleID              INT                 NOT NULL,
    CommissionRate      DECIMAL(5,2)        NOT NULL CONSTRAINT DF_Users_CommissionRate DEFAULT (0.00),
    DamageLiabilityRate DECIMAL(5,2)        NOT NULL CONSTRAINT DF_Users_DamageLiabilityRate DEFAULT (0.00),
    IsActive            BIT                 NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
    CreatedAt           DATETIME2(0)        NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (GETDATE()),

    CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (UserID),
    CONSTRAINT UQ_Users_Username UNIQUE (Username),
    CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleID)
        REFERENCES dbo.Roles(RoleID) ON DELETE NO ACTION,
    CONSTRAINT CK_Users_CommissionRate CHECK (CommissionRate BETWEEN 0.00 AND 100.00),
    CONSTRAINT CK_Users_DamageLiabilityRate CHECK (DamageLiabilityRate BETWEEN 0.00 AND 100.00)
);
GO

-- 1.4 Customers
CREATE TABLE dbo.Customers (
    CustomerID      INT IDENTITY(1,1)   NOT NULL,
    FullName        NVARCHAR(100)       NOT NULL,
    Phone           NVARCHAR(20)        NOT NULL,
    Notes           NVARCHAR(500)       NULL,
    CreatedAt       DATETIME2(0)        NOT NULL CONSTRAINT DF_Customers_CreatedAt DEFAULT (GETDATE()),

    CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED (CustomerID),
    CONSTRAINT UQ_Customers_Phone UNIQUE (Phone)
);
GO

/* ============================================================================
   2. SHARED INVENTORY & COMPATIBILITY (4 Tables)
   ============================================================================ */

-- 2.1 Categories
CREATE TABLE dbo.Categories (
    CategoryID      INT IDENTITY(1,1)   NOT NULL,
    CategoryName    NVARCHAR(100)       NOT NULL,
    IsActive        BIT                 NOT NULL CONSTRAINT DF_Categories_IsActive DEFAULT (1),

    CONSTRAINT PK_Categories PRIMARY KEY CLUSTERED (CategoryID),
    CONSTRAINT UQ_Categories_CategoryName UNIQUE (CategoryName)
);
GO

-- 2.2 PhoneModels
CREATE TABLE dbo.PhoneModels (
    PhoneModelID    INT IDENTITY(1,1)   NOT NULL,
    Brand           NVARCHAR(50)        NOT NULL,
    ModelName       NVARCHAR(100)       NOT NULL,

    CONSTRAINT PK_PhoneModels PRIMARY KEY CLUSTERED (PhoneModelID),
    CONSTRAINT UQ_PhoneModels_Brand_ModelName UNIQUE (Brand, ModelName)
);
GO

-- 2.3 Items (1 = SparePart, 2 = Accessory)
CREATE TABLE dbo.Items (
    ItemID          INT IDENTITY(1,1)   NOT NULL,
    CategoryID      INT                 NOT NULL,
    Barcode         NVARCHAR(50)        NULL,
    ItemName        NVARCHAR(150)       NOT NULL,
    ItemType        TINYINT             NOT NULL,
    QualityGrade    NVARCHAR(50)        NULL,
    PurchasePrice   DECIMAL(18,2)       NOT NULL,
    SellingPrice    DECIMAL(18,2)       NOT NULL,
    StockQty        INT                 NOT NULL CONSTRAINT DF_Items_StockQty DEFAULT (0),
    MinStockLevel   INT                 NULL,
    IsActive        BIT                 NOT NULL CONSTRAINT DF_Items_IsActive DEFAULT (1),
    CreatedAt       DATETIME2(0)        NOT NULL CONSTRAINT DF_Items_CreatedAt DEFAULT (GETDATE()),

    CONSTRAINT PK_Items PRIMARY KEY CLUSTERED (ItemID),
    CONSTRAINT FK_Items_Categories FOREIGN KEY (CategoryID)
        REFERENCES dbo.Categories(CategoryID) ON DELETE NO ACTION,
    CONSTRAINT UQ_Items_ItemName_QualityGrade UNIQUE (ItemName, QualityGrade),
    CONSTRAINT CK_Items_ItemType CHECK (ItemType IN (1, 2)),
    CONSTRAINT CK_Items_PurchasePrice CHECK (PurchasePrice >= 0.00),
    CONSTRAINT CK_Items_SellingPrice CHECK (SellingPrice >= 0.00),
    CONSTRAINT CK_Items_StockQty CHECK (StockQty >= 0),
    CONSTRAINT CK_Items_MinStockLevel CHECK (MinStockLevel IS NULL OR MinStockLevel >= 0)
);
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_Items_Barcode
    ON dbo.Items(Barcode)
    WHERE Barcode IS NOT NULL;
GO

CREATE NONCLUSTERED INDEX IX_Items_CategoryID_IsActive
    ON dbo.Items(CategoryID, IsActive)
    INCLUDE (ItemName, QualityGrade, SellingPrice, StockQty);
GO

-- 2.4 PartCompatibility (M:N Junction Table)
CREATE TABLE dbo.PartCompatibility (
    ItemID          INT                 NOT NULL,
    PhoneModelID    INT                 NOT NULL,

    CONSTRAINT PK_PartCompatibility PRIMARY KEY CLUSTERED (ItemID, PhoneModelID),
    CONSTRAINT FK_PartCompatibility_Items FOREIGN KEY (ItemID)
        REFERENCES dbo.Items(ItemID) ON DELETE NO ACTION,
    CONSTRAINT FK_PartCompatibility_PhoneModels FOREIGN KEY (PhoneModelID)
        REFERENCES dbo.PhoneModels(PhoneModelID) ON DELETE NO ACTION
);
GO

CREATE NONCLUSTERED INDEX IX_PartCompatibility_PhoneModelID
    ON dbo.PartCompatibility(PhoneModelID)
    INCLUDE (ItemID);
GO

/* ============================================================================
   3. BRANCH A: REPAIR TICKETS (3 Tables)
   ============================================================================ */

-- 3.1 RepairTickets
-- Status: 1 = Received, 2 = InProgress, 3 = Completed, 4 = Delivered, 5 = Cancelled
CREATE TABLE dbo.RepairTickets (
    TicketID                    INT IDENTITY(1000,1)    NOT NULL,
    TicketCode                  NVARCHAR(30)            NOT NULL,
    CustomerID                  INT                     NOT NULL,
    PhoneModelID                INT                     NOT NULL,
    DeviceIMEI                  NVARCHAR(30)            NULL,
    IssueDescription            NVARCHAR(500)           NOT NULL,
    IncludedAccessories         NVARCHAR(250)           NULL,
    AssignedTechID              INT                     NULL,
    ReceivedByUserID            INT                     NOT NULL,
    Status                      TINYINT                 NOT NULL CONSTRAINT DF_RepairTickets_Status DEFAULT (1),
    AgreedPrice                 DECIMAL(18,2)           NOT NULL CONSTRAINT DF_RepairTickets_AgreedPrice DEFAULT (0.00),
    Discount                    DECIMAL(18,2)           NOT NULL CONSTRAINT DF_RepairTickets_Discount DEFAULT (0.00),
    NetTotal                    AS CAST((AgreedPrice - Discount) AS DECIMAL(18,2)) PERSISTED,
    TechCommissionRateAtTime    DECIMAL(5,2)            NOT NULL CONSTRAINT DF_RepairTickets_TechCommRate DEFAULT (0.00),
    TechDamageRateAtTime        DECIMAL(5,2)            NOT NULL CONSTRAINT DF_RepairTickets_TechDamageRate DEFAULT (0.00),
    CreatedAt                   DATETIME2(0)            NOT NULL CONSTRAINT DF_RepairTickets_CreatedAt DEFAULT (GETDATE()),
    CompletedAt                 DATETIME2(0)            NULL,
    DeliveredAt                 DATETIME2(0)            NULL,

    CONSTRAINT PK_RepairTickets PRIMARY KEY CLUSTERED (TicketID),
    CONSTRAINT UQ_RepairTickets_TicketCode UNIQUE (TicketCode),
    CONSTRAINT FK_RepairTickets_Customers FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customers(CustomerID) ON DELETE NO ACTION,
    CONSTRAINT FK_RepairTickets_PhoneModels FOREIGN KEY (PhoneModelID)
        REFERENCES dbo.PhoneModels(PhoneModelID) ON DELETE NO ACTION,
    CONSTRAINT FK_RepairTickets_AssignedTech FOREIGN KEY (AssignedTechID)
        REFERENCES dbo.Users(UserID) ON DELETE NO ACTION,
    CONSTRAINT FK_RepairTickets_ReceivedByUser FOREIGN KEY (ReceivedByUserID)
        REFERENCES dbo.Users(UserID) ON DELETE NO ACTION,
    CONSTRAINT CK_RepairTickets_Status CHECK (Status IN (1, 2, 3, 4, 5)),
    CONSTRAINT CK_RepairTickets_AgreedPrice CHECK (AgreedPrice >= 0.00),
    CONSTRAINT CK_RepairTickets_Discount CHECK (Discount >= 0.00 AND Discount <= AgreedPrice),
    CONSTRAINT CK_RepairTickets_TechCommRate CHECK (TechCommissionRateAtTime BETWEEN 0.00 AND 100.00),
    CONSTRAINT CK_RepairTickets_TechDamageRate CHECK (TechDamageRateAtTime BETWEEN 0.00 AND 100.00),
    CONSTRAINT CK_RepairTickets_TechRequiredWhenDone CHECK (Status NOT IN (3, 4) OR AssignedTechID IS NOT NULL),
    CONSTRAINT CK_RepairTickets_CompletedAt CHECK (Status NOT IN (3, 4) OR CompletedAt IS NOT NULL),
    CONSTRAINT CK_RepairTickets_DeliveredAt CHECK (Status <> 4 OR DeliveredAt IS NOT NULL)
);
GO

CREATE NONCLUSTERED INDEX IX_RepairTickets_Status_CreatedAt
    ON dbo.RepairTickets(Status, CreatedAt DESC)
    INCLUDE (TicketCode, CustomerID, PhoneModelID, AssignedTechID, NetTotal);
GO

CREATE NONCLUSTERED INDEX IX_RepairTickets_CustomerID
    ON dbo.RepairTickets(CustomerID);
GO

CREATE NONCLUSTERED INDEX IX_RepairTickets_AssignedTechID_Status
    ON dbo.RepairTickets(AssignedTechID, Status)
    WHERE AssignedTechID IS NOT NULL;
GO

-- 3.2 TicketPhotos (PhotoType: 1 = Before, 2 = After)
CREATE TABLE dbo.TicketPhotos (
    PhotoID         INT IDENTITY(1,1)   NOT NULL,
    TicketID        INT                 NOT NULL,
    PhotoType       TINYINT             NOT NULL,
    RelativePath    NVARCHAR(500)       NOT NULL,
    UploadedAt      DATETIME2(0)        NOT NULL CONSTRAINT DF_TicketPhotos_UploadedAt DEFAULT (GETDATE()),

    CONSTRAINT PK_TicketPhotos PRIMARY KEY CLUSTERED (PhotoID),
    CONSTRAINT FK_TicketPhotos_RepairTickets FOREIGN KEY (TicketID)
        REFERENCES dbo.RepairTickets(TicketID) ON DELETE NO ACTION,
    CONSTRAINT CK_TicketPhotos_PhotoType CHECK (PhotoType IN (1, 2))
);
GO

CREATE NONCLUSTERED INDEX IX_TicketPhotos_TicketID
    ON dbo.TicketPhotos(TicketID);
GO

-- 3.3 TicketParts
-- PartStatus: 1 = Valid, 2 = TechDamaged, 3 = FactoryDefect
-- Source XOR: Either ItemID (from Shop Stock) OR ExternalPartName (temporary external part)
CREATE TABLE dbo.TicketParts (
    TicketPartID        INT IDENTITY(1,1)   NOT NULL,
    TicketID            INT                 NOT NULL,
    ItemID              INT                 NULL,
    ExternalPartName    NVARCHAR(150)       NULL,
    Quantity            INT                 NOT NULL,
    UnitCostAtTime      DECIMAL(18,2)       NOT NULL,
    PartStatus          TINYINT             NOT NULL CONSTRAINT DF_TicketParts_PartStatus DEFAULT (1),
    LoggedByUserID      INT                 NOT NULL,
    Notes               NVARCHAR(300)       NULL,
    LoggedAt            DATETIME2(0)        NOT NULL CONSTRAINT DF_TicketParts_LoggedAt DEFAULT (GETDATE()),

    CONSTRAINT PK_TicketParts PRIMARY KEY CLUSTERED (TicketPartID),
    CONSTRAINT FK_TicketParts_RepairTickets FOREIGN KEY (TicketID)
        REFERENCES dbo.RepairTickets(TicketID) ON DELETE NO ACTION,
    CONSTRAINT FK_TicketParts_Items FOREIGN KEY (ItemID)
        REFERENCES dbo.Items(ItemID) ON DELETE NO ACTION,
    CONSTRAINT FK_TicketParts_Users FOREIGN KEY (LoggedByUserID)
        REFERENCES dbo.Users(UserID) ON DELETE NO ACTION,
    CONSTRAINT CK_TicketParts_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_TicketParts_UnitCostAtTime CHECK (UnitCostAtTime >= 0.00),
    CONSTRAINT CK_TicketParts_PartStatus CHECK (PartStatus IN (1, 2, 3)),
    CONSTRAINT CK_TicketParts_SourceXOR CHECK (
        (ItemID IS NOT NULL AND NULLIF(LTRIM(RTRIM(ExternalPartName)), N'') IS NULL)
        OR
        (ItemID IS NULL AND NULLIF(LTRIM(RTRIM(ExternalPartName)), N'') IS NOT NULL)
    )
);
GO

CREATE NONCLUSTERED INDEX IX_TicketParts_TicketID
    ON dbo.TicketParts(TicketID)
    INCLUDE (ItemID, ExternalPartName, Quantity, UnitCostAtTime, PartStatus);
GO

/* ============================================================================
   4. BRANCH B: POS SALES (2 Tables)
   ============================================================================ */

-- 4.1 SalesInvoices
CREATE TABLE dbo.SalesInvoices (
    InvoiceID       INT IDENTITY(1000,1)    NOT NULL,
    InvoiceNumber   NVARCHAR(30)            NOT NULL,
    CustomerID      INT                     NULL,
    CashierUserID   INT                     NOT NULL,
    SubTotal        DECIMAL(18,2)           NOT NULL,
    Discount        DECIMAL(18,2)           NOT NULL CONSTRAINT DF_SalesInvoices_Discount DEFAULT (0.00),
    NetTotal        AS CAST((SubTotal - Discount) AS DECIMAL(18,2)) PERSISTED,
    CreatedAt       DATETIME2(0)            NOT NULL CONSTRAINT DF_SalesInvoices_CreatedAt DEFAULT (GETDATE()),

    CONSTRAINT PK_SalesInvoices PRIMARY KEY CLUSTERED (InvoiceID),
    CONSTRAINT UQ_SalesInvoices_InvoiceNumber UNIQUE (InvoiceNumber),
    CONSTRAINT FK_SalesInvoices_Customers FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customers(CustomerID) ON DELETE NO ACTION,
    CONSTRAINT FK_SalesInvoices_Users FOREIGN KEY (CashierUserID)
        REFERENCES dbo.Users(UserID) ON DELETE NO ACTION,
    CONSTRAINT CK_SalesInvoices_SubTotal CHECK (SubTotal >= 0.00),
    CONSTRAINT CK_SalesInvoices_Discount CHECK (Discount >= 0.00 AND Discount <= SubTotal)
);
GO

CREATE NONCLUSTERED INDEX IX_SalesInvoices_CreatedAt
    ON dbo.SalesInvoices(CreatedAt DESC)
    INCLUDE (InvoiceNumber, CustomerID, CashierUserID, NetTotal);
GO

-- 4.2 SalesInvoiceItems
CREATE TABLE dbo.SalesInvoiceItems (
    InvoiceItemID   INT IDENTITY(1,1)   NOT NULL,
    InvoiceID       INT                 NOT NULL,
    ItemID          INT                 NOT NULL,
    Quantity        INT                 NOT NULL,
    UnitCostAtTime  DECIMAL(18,2)       NOT NULL,
    UnitPriceAtTime DECIMAL(18,2)       NOT NULL,

    CONSTRAINT PK_SalesInvoiceItems PRIMARY KEY CLUSTERED (InvoiceItemID),
    CONSTRAINT FK_SalesInvoiceItems_SalesInvoices FOREIGN KEY (InvoiceID)
        REFERENCES dbo.SalesInvoices(InvoiceID) ON DELETE NO ACTION,
    CONSTRAINT FK_SalesInvoiceItems_Items FOREIGN KEY (ItemID)
        REFERENCES dbo.Items(ItemID) ON DELETE NO ACTION,
    CONSTRAINT CK_SalesInvoiceItems_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_SalesInvoiceItems_UnitCostAtTime CHECK (UnitCostAtTime >= 0.00),
    CONSTRAINT CK_SalesInvoiceItems_UnitPriceAtTime CHECK (UnitPriceAtTime >= 0.00)
);
GO

CREATE NONCLUSTERED INDEX IX_SalesInvoiceItems_InvoiceID
    ON dbo.SalesInvoiceItems(InvoiceID)
    INCLUDE (ItemID, Quantity, UnitCostAtTime, UnitPriceAtTime);
GO

/* ============================================================================
   5. SHARED TREASURY & STOCK LEDGER (3 Tables)
   ============================================================================ */

-- 5.1 Payments (Unified Treasury Inflows / Refunds for both Repairs & POS)
CREATE TABLE dbo.Payments (
    PaymentID           INT IDENTITY(1,1)   NOT NULL,
    TicketID            INT                 NULL,
    InvoiceID           INT                 NULL,
    Amount              DECIMAL(18,2)       NOT NULL,
    PaymentMethodID     INT                 NOT NULL,
    ReceivedByUserID    INT                 NOT NULL,
    PaidAt              DATETIME2(0)        NOT NULL CONSTRAINT DF_Payments_PaidAt DEFAULT (GETDATE()),
    Notes               NVARCHAR(250)       NULL,

    CONSTRAINT PK_Payments PRIMARY KEY CLUSTERED (PaymentID),
    CONSTRAINT FK_Payments_RepairTickets FOREIGN KEY (TicketID)
        REFERENCES dbo.RepairTickets(TicketID) ON DELETE NO ACTION,
    CONSTRAINT FK_Payments_SalesInvoices FOREIGN KEY (InvoiceID)
        REFERENCES dbo.SalesInvoices(InvoiceID) ON DELETE NO ACTION,
    CONSTRAINT FK_Payments_PaymentMethods FOREIGN KEY (PaymentMethodID)
        REFERENCES dbo.PaymentMethods(PaymentMethodID) ON DELETE NO ACTION,
    CONSTRAINT FK_Payments_Users FOREIGN KEY (ReceivedByUserID)
        REFERENCES dbo.Users(UserID) ON DELETE NO ACTION,
    CONSTRAINT CK_Payments_Amount CHECK (Amount <> 0.00),
    CONSTRAINT CK_Payments_TargetXOR CHECK (
        (TicketID IS NOT NULL AND InvoiceID IS NULL)
        OR
        (TicketID IS NULL AND InvoiceID IS NOT NULL)
    )
);
GO

CREATE NONCLUSTERED INDEX IX_Payments_PaidAt_PaymentMethodID
    ON dbo.Payments(PaidAt, PaymentMethodID)
    INCLUDE (Amount, ReceivedByUserID);
GO

CREATE NONCLUSTERED INDEX IX_Payments_TicketID
    ON dbo.Payments(TicketID)
    WHERE TicketID IS NOT NULL;
GO

CREATE NONCLUSTERED INDEX IX_Payments_InvoiceID
    ON dbo.Payments(InvoiceID)
    WHERE InvoiceID IS NOT NULL;
GO

-- 5.2 Expenses (Operational Expenses + Rare Ticket-Linked External Parts)
CREATE TABLE dbo.Expenses (
    ExpenseID           INT IDENTITY(1,1)   NOT NULL,
    ExpenseCategory     NVARCHAR(50)        NOT NULL,
    Description         NVARCHAR(250)       NOT NULL,
    Amount              DECIMAL(18,2)       NOT NULL,
    PaymentMethodID     INT                 NOT NULL,
    TicketID            INT                 NULL,
    RecordedByUserID    INT                 NOT NULL,
    ExpenseDate         DATETIME2(0)        NOT NULL CONSTRAINT DF_Expenses_ExpenseDate DEFAULT (GETDATE()),

    CONSTRAINT PK_Expenses PRIMARY KEY CLUSTERED (ExpenseID),
    CONSTRAINT FK_Expenses_PaymentMethods FOREIGN KEY (PaymentMethodID)
        REFERENCES dbo.PaymentMethods(PaymentMethodID) ON DELETE NO ACTION,
    CONSTRAINT FK_Expenses_RepairTickets FOREIGN KEY (TicketID)
        REFERENCES dbo.RepairTickets(TicketID) ON DELETE NO ACTION,
    CONSTRAINT FK_Expenses_Users FOREIGN KEY (RecordedByUserID)
        REFERENCES dbo.Users(UserID) ON DELETE NO ACTION,
    CONSTRAINT CK_Expenses_Amount CHECK (Amount > 0.00)
);
GO

CREATE NONCLUSTERED INDEX IX_Expenses_ExpenseDate_PaymentMethodID
    ON dbo.Expenses(ExpenseDate, PaymentMethodID)
    INCLUDE (ExpenseCategory, Amount, TicketID);
GO

CREATE NONCLUSTERED INDEX IX_Expenses_TicketID
    ON dbo.Expenses(TicketID)
    WHERE TicketID IS NOT NULL;
GO

-- 5.3 StockMovements (Unified Stock Ledger)
-- MovementType: 1=StockIn(+), 2=PosSale(-), 3=RepairValid(-), 4=TechDamaged(-), 5=FactoryDefect(-), 6=Adjustment(!=0)
CREATE TABLE dbo.StockMovements (
    MovementID      INT IDENTITY(1,1)   NOT NULL,
    ItemID          INT                 NOT NULL,
    MovementType    TINYINT             NOT NULL,
    QuantityChange  INT                 NOT NULL,
    UnitCostAtTime  DECIMAL(18,2)       NOT NULL,
    TicketID        INT                 NULL,
    InvoiceID       INT                 NULL,
    CreatedByUserID INT                 NOT NULL,
    Notes           NVARCHAR(300)       NULL,
    CreatedAt       DATETIME2(0)        NOT NULL CONSTRAINT DF_StockMovements_CreatedAt DEFAULT (GETDATE()),

    CONSTRAINT PK_StockMovements PRIMARY KEY CLUSTERED (MovementID),
    CONSTRAINT FK_StockMovements_Items FOREIGN KEY (ItemID)
        REFERENCES dbo.Items(ItemID) ON DELETE NO ACTION,
    CONSTRAINT FK_StockMovements_RepairTickets FOREIGN KEY (TicketID)
        REFERENCES dbo.RepairTickets(TicketID) ON DELETE NO ACTION,
    CONSTRAINT FK_StockMovements_SalesInvoices FOREIGN KEY (InvoiceID)
        REFERENCES dbo.SalesInvoices(InvoiceID) ON DELETE NO ACTION,
    CONSTRAINT FK_StockMovements_Users FOREIGN KEY (CreatedByUserID)
        REFERENCES dbo.Users(UserID) ON DELETE NO ACTION,
    CONSTRAINT CK_StockMovements_MovementType CHECK (MovementType IN (1, 2, 3, 4, 5, 6)),
    CONSTRAINT CK_StockMovements_UnitCostAtTime CHECK (UnitCostAtTime >= 0.00),
    CONSTRAINT CK_StockMovements_Sign CHECK (
        (MovementType = 1 AND QuantityChange > 0)
        OR (MovementType IN (2, 3, 4, 5) AND QuantityChange < 0)
        OR (MovementType = 6 AND QuantityChange <> 0)
    ),
    CONSTRAINT CK_StockMovements_SourceMatch CHECK (
        (MovementType IN (1, 6) AND TicketID IS NULL AND InvoiceID IS NULL)
        OR (MovementType = 2 AND InvoiceID IS NOT NULL AND TicketID IS NULL)
        OR (MovementType IN (3, 4, 5) AND TicketID IS NOT NULL AND InvoiceID IS NULL)
    )
);
GO

CREATE NONCLUSTERED INDEX IX_StockMovements_ItemID_CreatedAt
    ON dbo.StockMovements(ItemID, CreatedAt DESC)
    INCLUDE (MovementType, QuantityChange, UnitCostAtTime);
GO

CREATE NONCLUSTERED INDEX IX_StockMovements_MovementType_CreatedAt
    ON dbo.StockMovements(MovementType, CreatedAt DESC)
    INCLUDE (ItemID, QuantityChange, UnitCostAtTime, TicketID);
GO

PRINT N'MobileCareDB schema (16 tables, constraints, and indexes) created successfully.';
GO