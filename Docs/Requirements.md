# MobileCare ERP & POS System - System Requirements Specification (SRS)

## 1. Project Overview
A desktop application built with **C# (.NET)** and **Microsoft SQL Server** designed to manage mobile phone repair centers, spare parts & accessories inventory, retail and wholesale POS sales, returns, technician payroll settlement, and daily treasury reconciliation using a **Two-Branch Architecture** (Repair Tickets & Retail/Wholesale POS Sales) connected to a shared inventory and financial ledger.

## 2. User Roles & Permissions
- **Admin (Manager):** Full access to financial & profit reports (daily, weekly, monthly, yearly), daily cash drawer closing, low-stock alerts, operational expenses, owner draws/transfers, employee advances, system settings, emergency ticket reassignment between technicians, technician performance metrics, and technician payroll settlement.
- **Sales / Receptionist:** Handles barcode-ready retail & wholesale POS checkout, full/partial sales returns, repair ticket intake (including warranty comebacks), device accessories & agreed repair pricing, customer payments/deposits/refunds, and before/after device photos.
- **Technician:** Views assigned repair tickets, withdraws or returns spare parts from/to shop inventory, logs temporary external parts or damaged parts (shrinkage/waste), and updates repair statuses.

## 3. Core Functional Requirements
1. **Shared Inventory, Wholesale Pricing & Part Compatibility:**
   - Manage spare parts (`ItemType = 1`, with `QualityGrade` such as Original OLED, Incell X, Copy) and accessories (`ItemType = 2`) with retail pricing (`SellingPrice`), optional wholesale pricing (`WholesalePrice`) for partner repair shops, and optional low-stock threshold alerts (`MinStockLevel`).
   - Support **Many-to-Many** compatibility mapping (`PartCompatibility`) so a single spare part can fit multiple phone models and vice versa.
   - Maintain a full stock audit ledger (`StockMovements`) tracking 8 movement types: `StockIn (+)`, `PosSale (-)`, `RepairValid (-)`, `TechDamaged (-)`, `FactoryDefect (-)`, `Adjustment (!= 0)`, `PosReturn (+)`, and `RepairPartReturn (+)`.
   - Protect concurrent edits on catalog items, repair tickets, and sales invoices using optimistic concurrency (`RowVersion` and `UpdatedAt`), alongside pessimistic locking (`UPDLOCK`) during transactional stock deductions.

2. **Repair Ticket Management, Warranty Comebacks & Reassignment:**
   - Track full device lifecycle (`Received`, `InProgress`, `Completed`, `Delivered`, `Cancelled`) starting from ticket ID `1000`.
   - Record customer details (`CustomerType`: `1 = Retail`, `2 = WholesaleShop`), device model, IMEI/serial, included accessories, and **Before & After** device photos (stored on disk/shared folder; relative file paths saved in SQL Server).
   - Use **Agreed Repair Pricing** (`AgreedPrice - Discount = NetTotal`) quoted to the customer rather than itemizing part selling prices, while recording internal part costs (`UnitCostAtTime`) for accurate profit calculation.
   - **Warranty Comebacks (`ParentTicketID`):** Link follow-up warranty tickets to their original `RepairTickets.TicketID` via a self-referencing foreign key without reopening closed historical tickets.
   - **Emergency Reassignment (Admin Only):** Allow the manager to reassign an active ticket to another technician (`AssignedTechID` and ticket snapshot rates updated) if an emergency occurs, while isolating prior part damage accountability on `TicketParts`.

3. **Damaged, Defective, Returned & Rare External Parts:**
   - **Valid Parts (`PartStatus = 1`):** Deducted from shop stock and subtracted from ticket gross profit.
   - **Technician-Damaged Parts (`PartStatus = 2`):** Installation waste; deducted from shop stock and charged against `ResponsibleTechID` using the frozen `DamageRateAtTime` snapshot on `TicketParts`—keeping accountability independent from who typed the entry (`LoggedByUserID`) and unaffected by subsequent ticket reassignments.
   - **Factory-Defective / DOA Parts (`PartStatus = 3`):** Faulty units deducted from stock and tracked per part type/grade to evaluate part quality without supplier complexity, **excluded** from technician financial penalties and success-rate deductions.
   - **Returned to Stock (`PartStatus = 4`):** Unused parts withdrawn for testing and returned intact to inventory, logged via `StockMovements` (`MovementType = 8 = RepairPartReturn`).
   - **Rare External Parts (`ExternalPartName`):** Allow logging one-off spare parts bought externally for a specific ticket without polluting the `Items` catalog or `StockMovements`, while recording the cash outflow (or vendor refund if defective) in `Expenses` (`ExpenseType = 2`, linked to `TicketID`).

4. **Technician Commissions, Payroll Settlement & Performance:**
   - Store separate configurable default rates per technician in `Users` (`CommissionRate` for profit share and `DamageLiabilityRate` for damaged-part liability) and lock historical snapshots per ticket (`TechCommissionRateAtTime`, `TechDamageRateAtTime`) and per damaged part (`DamageRateAtTime`):
     $$\text{Net Tech Earnings} = \Big((\text{NetTotal} - \text{ValidPartsCost}) \times \text{ProfitRate}\Big) - \Big(\text{TechDamagedCost} \times \text{DamageRateAtTime}\Big)$$
   - **Payroll Settlement & Employee Advances:** Track unsettled profit shares (`RepairTickets.IsCommissionSettled`, `SettledAt`), unsettled damage penalties (`TicketParts.IsDamageSettled`), and unsettled employee cash advances (`Expenses` where `ExpenseType = 4`, linked to `RelatedUserID` and `IsSettled`) to calculate exact `NetPayableNow` without double-paying or double-deducting.
   - **Technician Performance Analytics:** Calculate each technician's **Ticket Success Rate** (clean completed/delivered tickets with zero technician damage divided by total handled tickets) and **Part Damage Rate** (excluding factory defects and returned parts).

5. **Retail & Wholesale POS, Returns & Unified Treasury:**
   - Fast barcode-ready POS billing (`SalesInvoices` starting from `1000`) supporting both retail walk-in/registered customers (`SaleType = 1`) and wholesale partner shops (`SaleType = 2`).
   - **Full & Partial Sales Returns:** Track returned quantities per line (`SalesInvoiceItems.ReturnedQty`) and agreed returned amounts on the invoice header (`SalesInvoices.ReturnedTotal`), automatically recalculating `NetTotal = SubTotal - Discount - ReturnedTotal`, restoring stock via `PosReturn` (`MovementType = 7`), and recording negative cash refunds in `Payments` when cash is returned.
   - **Unified Payments Ledger (`Payments`):** Support deposits, partial installments, split payment methods (`Cash`, `InstaPay`, `VodafoneCash`, `Card`), wholesale credit collection, and refunds across both Repair Tickets and Sales Invoices.
   - **Classified Treasury Outflows & Drawer Closing (`Expenses`):** Classify all outflows into 4 strict `ExpenseType` categories:
     1. `OperationalExpense` (OPEX: rent, utilities, consumables — positive amounts only; deducted from monthly net profit).
     2. `ExternalPartPurchase` (linked to `TicketID` — excluded from OPEX double-counting; negative allowed for vendor refunds).
     3. `OwnerDrawOrTransfer` (owner draws or internal cash/wallet transfers — affects drawer balance only, excluded from OPEX; negative allowed for injections/transfers-in).
     4. `EmployeePayrollOrAdvance` (linked to `RelatedUserID` — tracks advances and payroll disbursements; negative allowed for employee cash repayments).

## 4. Development Roadmap (Sprints / Rounds)
- [x] **Round 0:** GitHub repository setup, `.gitignore` configuration, and project folder structure (`Docs/`, `Database/`, `Src/`).
- [ ] **Round 1:** SQL Server database schema (`MobileCareDB` v1.0 — 16 tables in `01_CreateTables.sql` & `02_SeedData.sql` completed and verified), reporting views & transactional stored procedures (`03_ViewsAndProcedures.sql`), and C# Data Access Layer (DAL).
- [ ] **Round 2:** Main application shell, role-based navigation, Retail/Wholesale POS checkout & returns screen, and Repair Ticket intake (including warranty comebacks) screen.
- [ ] **Round 3:** Spare parts compatibility manager, damaged/returned/external parts workflow, admin ticket reassignment, technician payroll settlement, and performance reports.
- [ ] **Round 4:** Daily treasury closing (with classified expenses/transfers), periodic sales & profit reports, low-stock dashboard alerts, and deployment installer.