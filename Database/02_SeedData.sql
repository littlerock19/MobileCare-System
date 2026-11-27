/* ============================================================================
   Project      : MobileCare ERP & POS System
   Database     : MobileCareDB (Microsoft SQL Server 2019+)
   Script       : 02_SeedData.sql
   Description  : Inserts initial production lookup data (Roles, PaymentMethods,
                  Admin user) and comprehensive test scenarios covering M:N part
                  compatibility, split payments, valid/damaged/defective parts,
                  separate profit & damage liability rates, rare external parts,
                  POS sales, and expenses.
   ============================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE [MobileCareDB];
GO

-- Guard against accidental re-execution on an already populated database
IF EXISTS (SELECT 1 FROM dbo.Roles)
BEGIN
    PRINT N'Seed data already exists in MobileCareDB. Aborting 02_SeedData.sql to prevent duplicates.';
    RETURN;
END
GO

BEGIN TRANSACTION;

/* ============================================================================
   1. CORE SYSTEM & LOOKUPS (Roles, PaymentMethods, Users, Customers)
   ============================================================================ */

-- 1.1 Roles (IDs: 1 = Admin, 2 = Sales, 3 = Technician)
INSERT INTO dbo.Roles (RoleName, Description, IsActive)
VALUES
    (N'Admin',      N'Full system access, financial reports, settings, and technician payroll', 1),
    (N'Sales',      N'POS checkout, repair ticket intake, customer payments, and device photos', 1),
    (N'Technician', N'Assigned repair tickets, spare parts withdrawal, and status updates',     1);

-- 1.2 PaymentMethods (IDs: 1 = Cash, 2 = InstaPay, 3 = VodafoneCash, 4 = Card)
INSERT INTO dbo.PaymentMethods (MethodName, IsActive)
VALUES
    (N'Cash',         1),
    (N'InstaPay',     1),
    (N'VodafoneCash', 1),
    (N'Card',         1);

-- 1.3 Users
-- Tech 1 (Mahmoud): 40% Profit Commission, 50% Damage Liability
-- Tech 2 (Kareem) : 35% Profit Commission, 100% Damage Liability
-- Note: Replace placeholder PasswordHash values with real BCrypt/PBKDF2 hashes from C#
INSERT INTO dbo.Users (FullName, Username, PasswordHash, RoleID, CommissionRate, DamageLiabilityRate, IsActive)
VALUES
    (N'مصطفى زلط',   N'admin',        N'PLACEHOLDER_HASH_ADMIN_123', 1,  0.00,   0.00, 1),
    (N'أحمد سامي',   N'sales_ahmed',  N'PLACEHOLDER_HASH_SALES_123', 2,  0.00,   0.00, 1),
    (N'محمود حسن',   N'tech_mahmoud', N'PLACEHOLDER_HASH_TECH1_123', 3, 40.00,  50.00, 1),
    (N'كريم عادل',   N'tech_kareem',  N'PLACEHOLDER_HASH_TECH2_123', 3, 35.00, 100.00, 1);

-- 1.4 Customers (IDs: 1, 2, 3)
INSERT INTO dbo.Customers (FullName, Phone, Notes)
VALUES
    (N'محمد عبد الله', N'01012345678', N'عميل دائم - صيانة وإكسسوارات'),
    (N'سارة محمود',    N'01123456789', NULL),
    (N'عمر طارق',      N'01234567890', N'يفضل التواصل عبر واتساب');

/* ============================================================================
   2. SHARED INVENTORY & M:N COMPATIBILITY (Categories, PhoneModels, Items)
   ============================================================================ */

-- 2.1 Categories (IDs: 1..5)
INSERT INTO dbo.Categories (CategoryName, IsActive)
VALUES
    (N'شاشات',            1),
    (N'بطاريات',          1),
    (N'فلاتات شحن',       1),
    (N'جرابات واسكرينات', 1),
    (N'شواحن وكابلات',    1);

-- 2.2 PhoneModels (IDs: 1..5)
INSERT INTO dbo.PhoneModels (Brand, ModelName)
VALUES
    (N'Samsung', N'Galaxy A52'),
    (N'Samsung', N'Galaxy A52s 5G'),
    (N'Samsung', N'Galaxy A72'),
    (N'Apple',   N'iPhone 13'),
    (N'Honor',   N'Honor X9a');

-- 2.3 Items (IDs: 1..5 | ItemType: 1 = SparePart, 2 = Accessory)
-- Note: Items 2 and 5 intentionally have StockQty <= MinStockLevel to test Low-Stock Alerts
INSERT INTO dbo.Items (CategoryID, Barcode, ItemName, ItemType, QualityGrade, PurchasePrice, SellingPrice, StockQty, MinStockLevel, IsActive)
VALUES
    (1, NULL,             N'شاشة Samsung A52 / A52s / A72', 1, N'Original OLED', 1400.00, 2100.00,  5,  2, 1),
    (1, NULL,             N'شاشة Samsung A52 / A52s / A72', 1, N'Incell X',       650.00, 1100.00,  2,  3, 1),
    (2, NULL,             N'بطارية iPhone 13',              1, N'Original Pull',  700.00, 1150.00,  4,  2, 1),
    (4, N'6221000000011', N'اسكرينة سيراميك ضد البصمة',     2, NULL,              15.00,   50.00, 30, 10, 1),
    (5, N'6221000000028', N'شاحن Samsung 25W PD أصلي',      2, NULL,             280.00,  450.00,  3,  5, 1);

-- 2.4 PartCompatibility (Demonstrating M:N mapping across shared Samsung models)
INSERT INTO dbo.PartCompatibility (ItemID, PhoneModelID)
VALUES
    (1, 1), (1, 2), (1, 3),
    (2, 1), (2, 2), (2, 3),
    (3, 4);

/* ============================================================================
   3. BRANCH A: REPAIR TICKETS, PHOTOS & PARTS (TicketID starts at 1000)
   ============================================================================ */

-- 3.1 RepairTickets (IDs: 1000, 1001, 1002)
INSERT INTO dbo.RepairTickets (
    TicketCode, CustomerID, PhoneModelID, DeviceIMEI, IssueDescription,
    IncludedAccessories, AssignedTechID, ReceivedByUserID, Status,
    AgreedPrice, Discount, TechCommissionRateAtTime, TechDamageRateAtTime,
    CreatedAt, CompletedAt, DeliveredAt
)
VALUES
    -- Ticket 1000: Delivered (Status=4), tests Valid + TechDamaged + FactoryDefect parts & split rates (40% profit / 50% damage)
    (
        N'TKT-2026-1000', 1, 2, N'354892104567891',
        N'كسر في الشاشة الأمامية وتغيير شاشة Incell X',
        N'جراب شفاف + بيت الخط', 3, 2, 4,
        1800.00, 100.00, 40.00, 50.00,
        DATEADD(HOUR, -5, GETDATE()), DATEADD(HOUR, -2, GETDATE()), DATEADD(HOUR, -1, GETDATE())
    ),
    -- Ticket 1001: Completed (Status=3), tests rare external part (not in Items) + Expense link (35% profit / 100% damage)
    (
        N'TKT-2026-1001', 3, 5, N'864219053312450',
        N'تغيير شاشة Honor X9a أصلية (توريد خارجي خاص بالتذكرة)',
        N'بدون مشتملات', 4, 2, 3,
        1500.00, 0.00, 35.00, 100.00,
        DATEADD(HOUR, -4, GETDATE()), DATEADD(MINUTE, -30, GETDATE()), NULL
    ),
    -- Ticket 1002: InProgress (Status=2), tests active ticket with initial deposit
    (
        N'TKT-2026-1002', 2, 4, N'359812094481230',
        N'ضعف البطارية وتغيير بطارية iPhone 13',
        N'كابل شحن', 3, 2, 2,
        1200.00, 0.00, 40.00, 50.00,
        DATEADD(HOUR, -1, GETDATE()), NULL, NULL
    );

-- 3.2 TicketPhotos (PhotoType: 1 = Before, 2 = After)
INSERT INTO dbo.TicketPhotos (TicketID, PhotoType, RelativePath)
VALUES
    (1000, 1, N'Photos/2026/11/TKT-2026-1000_before.jpg'),
    (1000, 2, N'Photos/2026/11/TKT-2026-1000_after.jpg'),
    (1001, 1, N'Photos/2026/11/TKT-2026-1001_before.jpg'),
    (1002, 1, N'Photos/2026/11/TKT-2026-1002_before.jpg');

-- 3.3 TicketParts (PartStatus: 1 = Valid, 2 = TechDamaged, 3 = FactoryDefect)
INSERT INTO dbo.TicketParts (
    TicketID, ItemID, ExternalPartName, Quantity, UnitCostAtTime, PartStatus, LoggedByUserID, Notes
)
VALUES
    -- Ticket 1000: 1 FactoryDefect (excluded from tech penalty), 1 TechDamaged (50% liability), 1 Valid
    (1000, 2,    NULL,                                                1, 650.00, 3, 3, N'خطوط عرضية عند التجربة - عيب مصنع'),
    (1000, 2,    NULL,                                                1, 650.00, 2, 3, N'انكسرت الفلاتة أثناء التقفيل - تالف فني'),
    (1000, 2,    NULL,                                                1, 650.00, 1, 3, N'تم التركيب والاختبار بنجاح'),
    -- Ticket 1001: 1 Rare External Part (ItemID is NULL, ExternalPartName is populated)
    (1001, NULL, N'شاشة Honor X9a أصلية (شراء خارجي - مركز النور)',    1, 950.00, 1, 4, N'قطعة خارجية نادرة غير مخزنة بالمحل');

/* ============================================================================
   4. BRANCH B: POS SALES INVOICES & LINE ITEMS (InvoiceID starts at 1000)
   ============================================================================ */

-- 4.1 SalesInvoices (IDs: 1000 = Walk-in customer, 1001 = Registered customer)
INSERT INTO dbo.SalesInvoices (InvoiceNumber, CustomerID, CashierUserID, SubTotal, Discount, CreatedAt)
VALUES
    (N'INV-2026-1000', NULL, 2, 500.00, 20.00, DATEADD(HOUR, -3, GETDATE())),
    (N'INV-2026-1001', 1,    2, 100.00,  0.00, DATEADD(MINUTE, -45, GETDATE()));

-- 4.2 SalesInvoiceItems
INSERT INTO dbo.SalesInvoiceItems (InvoiceID, ItemID, Quantity, UnitCostAtTime, UnitPriceAtTime)
VALUES
    (1000, 5, 1, 280.00, 450.00),
    (1000, 4, 1,  15.00,  50.00),
    (1001, 4, 2,  15.00,  50.00);

/* ============================================================================
   5. SHARED TREASURY (Payments & Expenses) & STOCK LEDGER (StockMovements)
   ============================================================================ */

-- 5.1 Payments (Unified inflows across Repairs and POS; enforces TicketID XOR InvoiceID)
INSERT INTO dbo.Payments (TicketID, InvoiceID, Amount, PaymentMethodID, ReceivedByUserID, PaidAt, Notes)
VALUES
    -- Ticket 1000 split payments (Total = 500 + 1200 = 1700 = NetTotal)
    (1000, NULL,  500.00, 1, 2, DATEADD(HOUR, -5, GETDATE()),   N'عربون استلام الجهاز (كاش)'),
    (1000, NULL, 1200.00, 2, 2, DATEADD(HOUR, -1, GETDATE()),   N'باقي حساب التذكرة عند التسليم (إنستاباي)'),
    -- Ticket 1001 deposit (Remaining = 1500 - 500 = 1000)
    (1001, NULL,  500.00, 3, 2, DATEADD(HOUR, -4, GETDATE()),   N'عربون شراء شاشة خارجية (فودافون كاش)'),
    -- Ticket 1002 deposit (Remaining = 1200 - 300 = 900)
    (1002, NULL,  300.00, 1, 2, DATEADD(HOUR, -1, GETDATE()),   N'عربون صيانة (كاش)'),
    -- POS Invoices full payments
    (NULL, 1000,  480.00, 1, 2, DATEADD(HOUR, -3, GETDATE()),   N'سداد فاتورة كاشير بالكامل'),
    (NULL, 1001,  100.00, 4, 2, DATEADD(MINUTE, -45, GETDATE()), N'سداد فاتورة كاشير بالفيزا');

-- 5.2 Expenses (Ticket-linked external parts + general operational expenses)
INSERT INTO dbo.Expenses (ExpenseCategory, Description, Amount, PaymentMethodID, TicketID, RecordedByUserID, ExpenseDate)
VALUES
    -- Ticket-linked external part purchase (deducted from Cash drawer; excluded from OPEX double-counting)
    (N'قطع غيار خارجية', N'شراء شاشة Honor X9a لتذكرة TKT-2026-1001',   950.00, 1, 1001, 2, DATEADD(HOUR, -3, GETDATE())),
    -- General operational expenses (TicketID IS NULL)
    (N'خامات ورشة',      N'شراء بكر قصدير وفلكس ودبل فيس للورشة',        180.00, 1, NULL, 1, DATEADD(HOUR, -2, GETDATE())),
    (N'ضيافة ونثريات',   N'مشروبات وضيافة المحل',                          70.00, 1, NULL, 2, DATEADD(MINUTE, -20, GETDATE()));

-- 5.3 StockMovements (Audit trail matching exact current StockQty for all 5 catalog items)
-- MovementType: 1=StockIn(+), 2=PosSale(-), 3=RepairValid(-), 4=TechDamaged(-), 5=FactoryDefect(-), 6=Adjustment(!=0)
INSERT INTO dbo.StockMovements (ItemID, MovementType, QuantityChange, UnitCostAtTime, TicketID, InvoiceID, CreatedByUserID, Notes)
VALUES
    -- Initial Stock-In entries
    (1, 1,  5, 1400.00, NULL, NULL, 1, N'رصيد افتتاحي - شاشات Samsung Original'),
    (2, 1,  5,  650.00, NULL, NULL, 1, N'رصيد افتتاحي - شاشات Samsung Incell X'),
    (3, 1,  4,  700.00, NULL, NULL, 1, N'رصيد افتتاحي - بطاريات iPhone 13'),
    (4, 1, 33,   15.00, NULL, NULL, 1, N'رصيد افتتاحي - اسكرينات سيراميك'),
    (5, 1,  4,  280.00, NULL, NULL, 1, N'رصيد افتتاحي - شواحن Samsung 25W'),
    -- Repair Ticket 1000 deductions for ItemID = 2 (5 - 1 - 1 - 1 = 2 remaining)
    (2, 5, -1,  650.00, 1000, NULL, 3, N'عيب مصنع - تذكرة TKT-2026-1000'),
    (2, 4, -1,  650.00, 1000, NULL, 3, N'تالف فني أثناء التركيب - تذكرة TKT-2026-1000'),
    (2, 3, -1,  650.00, 1000, NULL, 3, N'تركيب سليم - تذكرة TKT-2026-1000'),
    -- POS Invoice 1000 & 1001 deductions (Item 4: 33 - 1 - 2 = 30; Item 5: 4 - 1 = 3)
    (5, 2, -1,  280.00, NULL, 1000, 2, N'بيع كاشير - فاتورة INV-2026-1000'),
    (4, 2, -1,   15.00, NULL, 1000, 2, N'بيع كاشير - فاتورة INV-2026-1000'),
    (4, 2, -2,   15.00, NULL, 1001, 2, N'بيع كاشير - فاتورة INV-2026-1001');

COMMIT TRANSACTION;
PRINT N'02_SeedData.sql executed successfully.';
GO

/* ============================================================================
   6. VERIFICATION & AUDIT QUERIES (Read-Only Sanity Checks)
   ============================================================================ */

-- Check 1: Stock Ledger Integrity (Must return 0 rows; verifies Items.StockQty == SUM(StockMovements))
SELECT
    i.ItemID,
    i.ItemName,
    i.StockQty AS CatalogStockQty,
    ISNULL(SUM(sm.QuantityChange), 0) AS LedgerNetQty
FROM dbo.Items i
LEFT JOIN dbo.StockMovements sm ON sm.ItemID = i.ItemID
GROUP BY i.ItemID, i.ItemName, i.StockQty
HAVING i.StockQty <> ISNULL(SUM(sm.QuantityChange), 0);

-- Check 2: Daily Treasury Balance by Payment Method (Payments Inflows - Expenses Outflows)
SELECT
    pm.MethodName,
    ISNULL(p.TotalIn, 0.00)  AS TotalInflows,
    ISNULL(e.TotalOut, 0.00) AS TotalOutflows,
    ISNULL(p.TotalIn, 0.00) - ISNULL(e.TotalOut, 0.00) AS NetDrawerBalance
FROM dbo.PaymentMethods pm
LEFT JOIN (
    SELECT PaymentMethodID, SUM(Amount) AS TotalIn
    FROM dbo.Payments
    GROUP BY PaymentMethodID
) p ON p.PaymentMethodID = pm.PaymentMethodID
LEFT JOIN (
    SELECT PaymentMethodID, SUM(Amount) AS TotalOut
    FROM dbo.Expenses
    GROUP BY PaymentMethodID
) e ON e.PaymentMethodID = pm.PaymentMethodID;

-- Check 3: Ticket Profit & Split Technician Earnings (Separate Profit Share vs. Damage Penalty)
SELECT
    rt.TicketCode,
    u.FullName AS TechnicianName,
    rt.NetTotal,
    ISNULL(SUM(CASE WHEN tp.PartStatus = 1 THEN tp.Quantity * tp.UnitCostAtTime ELSE 0.00 END), 0.00) AS ValidPartsCost,
    ISNULL(SUM(CASE WHEN tp.PartStatus = 2 THEN tp.Quantity * tp.UnitCostAtTime ELSE 0.00 END), 0.00) AS TechDamagedCost,
    rt.NetTotal - ISNULL(SUM(CASE WHEN tp.PartStatus = 1 THEN tp.Quantity * tp.UnitCostAtTime ELSE 0.00 END), 0.00) AS GrossTicketProfit,
    CAST(
        (rt.NetTotal - ISNULL(SUM(CASE WHEN tp.PartStatus = 1 THEN tp.Quantity * tp.UnitCostAtTime ELSE 0.00 END), 0.00))
        * (rt.TechCommissionRateAtTime / 100.0)
    AS DECIMAL(18,2)) AS TechProfitShare,
    CAST(
        ISNULL(SUM(CASE WHEN tp.PartStatus = 2 THEN tp.Quantity * tp.UnitCostAtTime ELSE 0.00 END), 0.00)
        * (rt.TechDamageRateAtTime / 100.0)
    AS DECIMAL(18,2)) AS TechDamagePenalty,
    CAST(
        ((rt.NetTotal - ISNULL(SUM(CASE WHEN tp.PartStatus = 1 THEN tp.Quantity * tp.UnitCostAtTime ELSE 0.00 END), 0.00))
         * (rt.TechCommissionRateAtTime / 100.0))
        -
        (ISNULL(SUM(CASE WHEN tp.PartStatus = 2 THEN tp.Quantity * tp.UnitCostAtTime ELSE 0.00 END), 0.00)
         * (rt.TechDamageRateAtTime / 100.0))
    AS DECIMAL(18,2)) AS NetTechEarnings
FROM dbo.RepairTickets rt
LEFT JOIN dbo.Users u ON u.UserID = rt.AssignedTechID
LEFT JOIN dbo.TicketParts tp ON tp.TicketID = rt.TicketID
GROUP BY rt.TicketCode, u.FullName, rt.NetTotal, rt.TechCommissionRateAtTime, rt.TechDamageRateAtTime;
GO