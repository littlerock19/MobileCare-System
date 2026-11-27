/* ============================================================================
   Project      : MobileCare ERP & POS System
   Database     : MobileCareDB (Microsoft SQL Server 2019+)
   Script       : 02_SeedData.sql
   Version      : 1.0 Production-Ready Final Seed Data & Audit Queries
   Description  : Inserts initial lookup data and end-to-end test scenarios
                  covering Retail & Wholesale sales, POS & Repair part returns,
                  Warranty Comeback tickets, separate Profit & Damage Liability
                  rates with ResponsibleTechID isolation, Owner draws, Employee
                  advances, and 4 built-in audit verification queries.
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
    (N'Admin',      N'Full system access, financial reports, settings, reassignment, and technician payroll', 1),
    (N'Sales',      N'Retail/Wholesale POS checkout, repair ticket intake, customer payments, and device photos', 1),
    (N'Technician', N'Assigned repair tickets, spare parts withdrawal, and status updates', 1);

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

-- 1.4 Customers (IDs: 1..3 Retail, 4 WholesaleShop)
INSERT INTO dbo.Customers (FullName, Phone, CustomerType, Notes)
VALUES
    (N'محمد عبد الله',      N'01012345678', 1, N'عميل دائم - صيانة وإكسسوارات'),
    (N'سارة محمود',         N'01123456789', 1, NULL),
    (N'عمر طارق',           N'01234567890', 1, N'يفضل التواصل عبر واتساب'),
    (N'مركز النور للصيانة', N'01555512345', 2, N'محل صيانة شريك - يشتري قطع غيار جملة');

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

-- 2.3 Items (IDs: 1..5 | ItemType: 1 = SparePart, 2 = Accessory | includes WholesalePrice)
-- Note: Items 2 and 5 intentionally have StockQty <= MinStockLevel to test Low-Stock Alerts
INSERT INTO dbo.Items (CategoryID, Barcode, ItemName, ItemType, QualityGrade, PurchasePrice, SellingPrice, WholesalePrice, StockQty, MinStockLevel, IsActive)
VALUES
    (1, NULL,             N'شاشة Samsung A52 / A52s / A72', 1, N'Original OLED', 1400.00, 2100.00, 1650.00,  4,  2, 1),
    (1, NULL,             N'شاشة Samsung A52 / A52s / A72', 1, N'Incell X',       650.00, 1100.00,  800.00,  2,  3, 1),
    (2, NULL,             N'بطارية iPhone 13',              1, N'Original Pull',  700.00, 1150.00,  850.00,  4,  2, 1),
    (4, N'6221000000011', N'اسكرينة سيراميك ضد البصمة',     2, NULL,              15.00,   50.00,    NULL, 30, 10, 1),
    (5, N'6221000000028', N'شاحن Samsung 25W PD أصلي',      2, NULL,             280.00,  450.00,  340.00,  3,  5, 1);

-- 2.4 PartCompatibility (M:N mapping across shared Samsung models)
INSERT INTO dbo.PartCompatibility (ItemID, PhoneModelID)
VALUES
    (1, 1), (1, 2), (1, 3),
    (2, 1), (2, 2), (2, 3),
    (3, 4);

/* ============================================================================
   3. BRANCH A: REPAIR TICKETS, PHOTOS & PARTS (TicketID starts at 1000)
   ============================================================================ */

-- 3.1 Primary RepairTickets (IDs: 1000, 1001, 1002)
INSERT INTO dbo.RepairTickets (
    TicketCode, ParentTicketID, CustomerID, PhoneModelID, DeviceIMEI, IssueDescription,
    IncludedAccessories, AssignedTechID, ReceivedByUserID, Status,
    AgreedPrice, Discount, TechCommissionRateAtTime, TechDamageRateAtTime,
    IsCommissionSettled, SettledAt, CreatedAt, CompletedAt, DeliveredAt
)
VALUES
    -- Ticket 1000: Delivered (Status=4), tests Valid + TechDamaged + FactoryDefect + ReturnedToStock parts
    (
        N'TKT-2026-1000', NULL, 1, 2, N'354892104567891',
        N'كسر في الشاشة الأمامية وتغيير شاشة Incell X',
        N'جراب شفاف + بيت الخط', 3, 2, 4,
        1800.00, 100.00, 40.00, 50.00,
        0, NULL, DATEADD(HOUR, -5, GETDATE()), DATEADD(HOUR, -2, GETDATE()), DATEADD(HOUR, -1, GETDATE())
    ),
    -- Ticket 1001: Completed (Status=3), tests rare external part + ExpenseType=2 link
    (
        N'TKT-2026-1001', NULL, 3, 5, N'864219053312450',
        N'تغيير شاشة Honor X9a أصلية (توريد خارجي خاص بالتذكرة)',
        N'بدون مشتملات', 4, 2, 3,
        1500.00, 0.00, 35.00, 100.00,
        0, NULL, DATEADD(HOUR, -4, GETDATE()), DATEADD(MINUTE, -30, GETDATE()), NULL
    ),
    -- Ticket 1002: InProgress (Status=2), active ticket with initial deposit
    (
        N'TKT-2026-1002', NULL, 2, 4, N'359812094481230',
        N'ضعف البطارية وتغيير بطارية iPhone 13',
        N'كابل شحن', 3, 2, 2,
        1200.00, 0.00, 40.00, 50.00,
        0, NULL, DATEADD(HOUR, -1, GETDATE()), NULL, NULL
    );

-- 3.2 Warranty Comeback Ticket (ID: 1003, linked via ParentTicketID = 1000)
INSERT INTO dbo.RepairTickets (
    TicketCode, ParentTicketID, CustomerID, PhoneModelID, DeviceIMEI, IssueDescription,
    IncludedAccessories, AssignedTechID, ReceivedByUserID, Status,
    AgreedPrice, Discount, TechCommissionRateAtTime, TechDamageRateAtTime,
    IsCommissionSettled, SettledAt, CreatedAt, CompletedAt, DeliveredAt
)
VALUES
    (
        N'TKT-2026-1003', 1000, 1, 2, N'354892104567891',
        N'راجع ضمان على تذكرة TKT-2026-1000 - فحص تقفيل فريم الشاشة',
        N'بدون مشتملات', 3, 2, 1,
        0.00, 0.00, 40.00, 50.00,
        0, NULL, DATEADD(MINUTE, -10, GETDATE()), NULL, NULL
    );

-- 3.3 TicketPhotos (PhotoType: 1 = Before, 2 = After)
INSERT INTO dbo.TicketPhotos (TicketID, PhotoType, RelativePath)
VALUES
    (1000, 1, N'Photos/2026/11/TKT-2026-1000_before.jpg'),
    (1000, 2, N'Photos/2026/11/TKT-2026-1000_after.jpg'),
    (1001, 1, N'Photos/2026/11/TKT-2026-1001_before.jpg'),
    (1002, 1, N'Photos/2026/11/TKT-2026-1002_before.jpg');

-- 3.4 TicketParts (PartStatus: 1 = Valid, 2 = TechDamaged, 3 = FactoryDefect, 4 = ReturnedToStock)
-- Demonstrates Sales (UserID=2) logging a damaged part on behalf of Tech Mahmoud (ResponsibleTechID=3)
INSERT INTO dbo.TicketParts (
    TicketID, ItemID, ExternalPartName, Quantity, UnitCostAtTime,
    PartStatus, ResponsibleTechID, DamageRateAtTime, IsDamageSettled, LoggedByUserID, Notes
)
VALUES
    (1000, 2,    NULL,                                                1,  650.00, 3, 3,  0.00, 0, 2, N'خطوط عرضية عند التجربة - عيب مصنع'),
    (1000, 2,    NULL,                                                1,  650.00, 2, 3, 50.00, 0, 2, N'انكسرت الفلاتة أثناء التقفيل - تالف فني (سجلها الريسبشن على عهدة محمود)'),
    (1000, 2,    NULL,                                                1,  650.00, 1, 3,  0.00, 0, 3, N'تم التركيب والاختبار بنجاح'),
    (1000, 1,    NULL,                                                1, 1400.00, 4, 3,  0.00, 0, 3, N'تم سحب شاشة أصلية ثم إرجاعها سليمة للمخزن بعد اختيار العميل شاشة Incell X'),
    (1001, NULL, N'شاشة Honor X9a أصلية (شراء خارجي - مركز النور)',    1,  950.00, 1, 4,  0.00, 0, 4, N'قطعة خارجية نادرة غير مخزنة بالمحل');

/* ============================================================================
   4. BRANCH B: RETAIL & WHOLESALE POS SALES (InvoiceID starts at 1000)
   ============================================================================ */

-- 4.1 SalesInvoices (1000 & 1001 = Retail, 1002 = Wholesale with 1 returned screen)
INSERT INTO dbo.SalesInvoices (InvoiceNumber, SaleType, CustomerID, CashierUserID, SubTotal, Discount, ReturnedTotal, CreatedAt)
VALUES
    (N'INV-2026-1000', 1, NULL, 2,  500.00, 20.00,    0.00, DATEADD(HOUR, -3, GETDATE())),
    (N'INV-2026-1001', 1, 1,    2,  100.00,  0.00,    0.00, DATEADD(MINUTE, -45, GETDATE())),
    (N'INV-2026-1002', 2, 4,    2, 3300.00,  0.00, 1650.00, DATEADD(MINUTE, -30, GETDATE()));

-- 4.2 SalesInvoiceItems (Invoice 1002 sold 2 wholesale screens and returned 1)
INSERT INTO dbo.SalesInvoiceItems (InvoiceID, ItemID, Quantity, ReturnedQty, UnitCostAtTime, UnitPriceAtTime)
VALUES
    (1000, 5, 1, 0,  280.00,  450.00),
    (1000, 4, 1, 0,   15.00,   50.00),
    (1001, 4, 2, 0,   15.00,   50.00),
    (1002, 1, 2, 1, 1400.00, 1650.00);

/* ============================================================================
   5. SHARED TREASURY (Payments & Expenses) & STOCK LEDGER (StockMovements)
   ============================================================================ */

-- 5.1 Payments (Includes split payments, deposits, wholesale sale, and negative refund)
INSERT INTO dbo.Payments (TicketID, InvoiceID, Amount, PaymentMethodID, ReceivedByUserID, PaidAt, Notes)
VALUES
    -- Ticket 1000 split payments (500 + 1200 = 1700 = NetTotal)
    (1000, NULL,   500.00, 1, 2, DATEADD(HOUR, -5, GETDATE()),   N'عربون استلام الجهاز (كاش)'),
    (1000, NULL,  1200.00, 2, 2, DATEADD(HOUR, -1, GETDATE()),   N'باقي حساب التذكرة عند التسليم (إنستاباي)'),
    -- Ticket 1001 deposit (Remaining = 1000)
    (1001, NULL,   500.00, 3, 2, DATEADD(HOUR, -4, GETDATE()),   N'عربون شراء شاشة خارجية (فودافون كاش)'),
    -- Ticket 1002 deposit (Remaining = 900)
    (1002, NULL,   300.00, 1, 2, DATEADD(HOUR, -1, GETDATE()),   N'عربون صيانة (كاش)'),
    -- Retail POS invoices
    (NULL, 1000,   480.00, 1, 2, DATEADD(HOUR, -3, GETDATE()),   N'سداد فاتورة كاشير قطاعي بالكامل'),
    (NULL, 1001,   100.00, 4, 2, DATEADD(MINUTE, -45, GETDATE()), N'سداد فاتورة كاشير بالفيزا'),
    -- Wholesale invoice 1002 payment & partial return refund (3300 - 1650 = 1650 = NetTotal)
    (NULL, 1002,  3300.00, 1, 2, DATEADD(MINUTE, -30, GETDATE()), N'تحصيل فاتورة جملة شاشتين - مركز النور'),
    (NULL, 1002, -1650.00, 1, 2, DATEADD(MINUTE, -15, GETDATE()), N'رد مبلغ شاشة مرتجعة سليمة - مركز النور');

-- 5.2 Expenses (Covers all 4 ExpenseType classifications)
-- 1=OperationalExpense, 2=ExternalPartPurchase, 3=OwnerDrawOrTransfer, 4=EmployeePayrollOrAdvance
INSERT INTO dbo.Expenses (ExpenseType, ExpenseCategory, Description, Amount, PaymentMethodID, TicketID, RelatedUserID, IsSettled, RecordedByUserID, ExpenseDate)
VALUES
    (2, N'قطع غيار خارجية', N'شراء شاشة Honor X9a لتذكرة TKT-2026-1001',   950.00, 1, 1001, NULL, 0, 2, DATEADD(HOUR, -3, GETDATE())),
    (1, N'خامات ورشة',      N'شراء بكر قصدير وفلكس ودبل فيس للورشة',        180.00, 1, NULL, NULL, 0, 1, DATEADD(HOUR, -2, GETDATE())),
    (1, N'ضيافة ونثريات',   N'مشروبات وضيافة المحل',                          70.00, 1, NULL, NULL, 0, 2, DATEADD(MINUTE, -25, GETDATE())),
    (3, N'مسحوبات مالك',    N'مسحوبات شخصية لصاحب المحل من درج الكاش',       500.00, 1, NULL, NULL, 0, 1, DATEADD(MINUTE, -20, GETDATE())),
    (4, N'سلف موظفين',      N'سلفة نقدية للفني محمود حسن',                   200.00, 1, NULL,    3, 0, 1, DATEADD(MINUTE, -15, GETDATE()));

-- 5.3 StockMovements (Complete audit trail matching exact Items.StockQty including returns)
-- 1=StockIn(+), 2=PosSale(-), 3=RepairValid(-), 4=TechDamaged(-), 5=FactoryDefect(-), 6=Adjustment(!=0), 7=PosReturn(+), 8=RepairPartReturn(+)
INSERT INTO dbo.StockMovements (ItemID, MovementType, QuantityChange, UnitCostAtTime, TicketID, InvoiceID, CreatedByUserID, Notes)
VALUES
    -- Opening stock entries
    (1, 1,  5, 1400.00, NULL, NULL, 1, N'رصيد افتتاحي - شاشات Samsung Original'),
    (2, 1,  5,  650.00, NULL, NULL, 1, N'رصيد افتتاحي - شاشات Samsung Incell X'),
    (3, 1,  4,  700.00, NULL, NULL, 1, N'رصيد افتتاحي - بطاريات iPhone 13'),
    (4, 1, 33,   15.00, NULL, NULL, 1, N'رصيد افتتاحي - اسكرينات سيراميك'),
    (5, 1,  4,  280.00, NULL, NULL, 1, N'رصيد افتتاحي - شواحن Samsung 25W'),
    -- Ticket 1000 part withdrawals & return to stock (Item 1: 5 - 1 + 1 = 5 before wholesale; Item 2: 5 - 3 = 2)
    (1, 3, -1, 1400.00, 1000, NULL, 3, N'سحب مؤقت للفحص - تذكرة TKT-2026-1000'),
    (1, 8,  1, 1400.00, 1000, NULL, 3, N'إرجاع شاشة سليمة للمخزن - تذكرة TKT-2026-1000'),
    (2, 5, -1,  650.00, 1000, NULL, 2, N'عيب مصنع - تذكرة TKT-2026-1000'),
    (2, 4, -1,  650.00, 1000, NULL, 2, N'تالف فني أثناء التركيب - تذكرة TKT-2026-1000'),
    (2, 3, -1,  650.00, 1000, NULL, 3, N'تركيب سليم - تذكرة TKT-2026-1000'),
    -- Retail POS deductions (Item 4: 33 - 1 - 2 = 30; Item 5: 4 - 1 = 3)
    (5, 2, -1,  280.00, NULL, 1000, 2, N'بيع كاشير قطاعي - فاتورة INV-2026-1000'),
    (4, 2, -1,   15.00, NULL, 1000, 2, N'بيع كاشير قطاعي - فاتورة INV-2026-1000'),
    (4, 2, -2,   15.00, NULL, 1001, 2, N'بيع كاشير قطاعي - فاتورة INV-2026-1001'),
    -- Wholesale sale & return (Item 1: 5 - 2 + 1 = 4)
    (1, 2, -2, 1400.00, NULL, 1002, 2, N'بيع جملة - فاتورة INV-2026-1002'),
    (1, 7,  1, 1400.00, NULL, 1002, 2, N'مرتجع جملة سليم - فاتورة INV-2026-1002');

COMMIT TRANSACTION;
PRINT N'02_SeedData.sql v1.0 executed successfully.';
GO

/* ============================================================================
   6. VERIFICATION & AUDIT QUERIES (4 Read-Only Sanity Checks)
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

-- Check 2: Daily Treasury Balance by Payment Method (All Payments - All Expenses)
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

-- Check 3: Unsettled Technician Payroll Summary (Profit Share - Responsible Damage Penalty - Unsettled Advances)
WITH UnsettledTicketProfit AS (
    SELECT
        rt.AssignedTechID AS TechID,
        CAST(SUM(
            (rt.NetTotal - ISNULL(vp.ValidPartsCost, 0.00)) * (rt.TechCommissionRateAtTime / 100.0)
        ) AS DECIMAL(18,2)) AS ProfitShare
    FROM dbo.RepairTickets rt
    LEFT JOIN (
        SELECT TicketID, SUM(Quantity * UnitCostAtTime) AS ValidPartsCost
        FROM dbo.TicketParts
        WHERE PartStatus = 1
        GROUP BY TicketID
    ) vp ON vp.TicketID = rt.TicketID
    WHERE rt.Status IN (3, 4)
      AND rt.IsCommissionSettled = 0
      AND rt.AssignedTechID IS NOT NULL
    GROUP BY rt.AssignedTechID
),
UnsettledDamages AS (
    SELECT
        ResponsibleTechID AS TechID,
        CAST(SUM((Quantity * UnitCostAtTime) * (DamageRateAtTime / 100.0)) AS DECIMAL(18,2)) AS DamagePenalty
    FROM dbo.TicketParts
    WHERE PartStatus = 2
      AND IsDamageSettled = 0
      AND ResponsibleTechID IS NOT NULL
    GROUP BY ResponsibleTechID
),
UnsettledAdvances AS (
    SELECT
        RelatedUserID AS TechID,
        SUM(Amount) AS AdvancesTotal
    FROM dbo.Expenses
    WHERE ExpenseType = 4
      AND IsSettled = 0
      AND RelatedUserID IS NOT NULL
    GROUP BY RelatedUserID
)
SELECT
    u.UserID,
    u.FullName AS TechnicianName,
    ISNULL(utp.ProfitShare, 0.00)   AS UnsettledProfitShare,
    ISNULL(ud.DamagePenalty, 0.00)  AS UnsettledDamagePenalty,
    ISNULL(ua.AdvancesTotal, 0.00)  AS UnsettledAdvances,
    ISNULL(utp.ProfitShare, 0.00) - ISNULL(ud.DamagePenalty, 0.00) - ISNULL(ua.AdvancesTotal, 0.00) AS NetPayableNow
FROM dbo.Users u
LEFT JOIN UnsettledTicketProfit utp ON utp.TechID = u.UserID
LEFT JOIN UnsettledDamages ud       ON ud.TechID = u.UserID
LEFT JOIN UnsettledAdvances ua      ON ua.TechID = u.UserID
WHERE u.RoleID = 3;

-- Check 4: Net Retail vs. Wholesale Sales & Gross Profit (Accounting for Returns)
SELECT
    CASE si.SaleType WHEN 1 THEN N'Retail' ELSE N'Wholesale' END AS SaleChannel,
    COUNT(DISTINCT si.InvoiceID) AS InvoiceCount,
    SUM(si.NetTotal) AS NetSalesRevenue,
    SUM(line_agg.NetItemsCost) AS NetCOGS,
    SUM(si.NetTotal) - SUM(line_agg.NetItemsCost) AS NetGrossProfit
FROM dbo.SalesInvoices si
INNER JOIN (
    SELECT
        InvoiceID,
        SUM((Quantity - ReturnedQty) * UnitCostAtTime) AS NetItemsCost
    FROM dbo.SalesInvoiceItems
    GROUP BY InvoiceID
) line_agg ON line_agg.InvoiceID = si.InvoiceID
GROUP BY si.SaleType;
GO