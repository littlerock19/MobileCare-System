# MobileCare ERP & POS System - System Requirements Specification (SRS)

## 1. Project Overview
A desktop application built with **C# (.NET)** and **Microsoft SQL Server** designed to manage mobile phone repair centers, spare parts & accessories inventory, POS sales, and daily treasury reconciliation using a **Two-Branch Architecture** (Repair Tickets & POS Sales) connected to a shared inventory and financial ledger.

## 2. User Roles & Permissions
- **Admin (Manager):** Full access to financial & profit reports (daily, weekly, monthly, yearly), daily cash drawer closing, low-stock alerts, operational expenses, system settings, and technician commission calculations.
- **Sales / Receptionist:** Handles barcode-ready accessories POS checkout, creates repair tickets, logs device accessories and agreed repair prices, records customer payments/deposits, and captures before/after device photos.
- **Technician:** Views assigned repair tickets, withdraws spare parts from shop inventory, logs temporary external parts or damaged parts (shrinkage/waste), and updates repair statuses.

## 3. Core Functional Requirements
1. **Shared Inventory & Part Compatibility:**
   - Manage spare parts (`ItemType = 1`, with `QualityGrade` such as Original, Incell X, Copy) and accessories (`ItemType = 2`) with optional low-stock threshold alerts (`MinStockLevel`).
   - Support **Many-to-Many** compatibility mapping (`PartCompatibility`) so a single spare part can fit multiple phone models and vice versa.
   - Maintain a full stock audit ledger (`StockMovements`) tracking stock-in, POS sales, valid repairs, technician damage, factory defects, and manual inventory adjustments.

2. **Repair Ticket Management & Pricing:**
   - Track full device lifecycle (`Received`, `InProgress`, `Completed`, `Delivered`, `Cancelled`) starting from ticket ID `1000`.
   - Record customer details, device model, IMEI/serial, included accessories, and **Before & After** device photos (stored on disk/shared folder; relative file paths saved in SQL Server).
   - Use **Agreed Repair Pricing** (`AgreedPrice - Discount = NetTotal`) quoted to the customer rather than itemizing part selling prices, while recording internal part costs (`UnitCostAtTime`) for accurate profit calculation.

3. **Damaged, Defective & Rare External Parts:**
   - **Valid Parts (`PartStatus = 1`):** Deducted from shop stock and subtracted from ticket net profit.
   - **Technician-Damaged Parts (`PartStatus = 2`):** Installation waste; deducted from shop stock and subtracted from ticket net profit (impacting technician net profit share).
   - **Factory-Defective / DOA Parts (`PartStatus = 3`):** Faulty units deducted from stock and tracked per part type/grade to evaluate part quality without supplier complexity, **excluded** from ticket cost penalty against the technician.
   - **Rare External Parts (`ExternalPartName`):** Allow logging one-off spare parts bought externally for a specific ticket without polluting the `Items` catalog or `StockMovements`, while recording the cash outflow in `Expenses` linked to `TicketID` for accurate drawer reconciliation.

4. **Technician Commissions (Historical Snapshot):**
   - Automatically calculate technician earnings as a configurable percentage (`TechCommissionRateAtTime` locked per ticket) of **Ticket Net Profit**:
     $$\text{Ticket Net Profit} = (\text{AgreedPrice} - \text{Discount}) - \sum (\text{Valid \& Tech-Damaged Parts Cost})$$

5. **Accessories POS & Unified Treasury:**
   - Fast barcode-ready POS billing (`SalesInvoices` starting from `1000`) for walk-in or registered customers with automated stock deduction.
   - **Unified Payments Ledger (`Payments`):** Support deposits, partial installments, split payment methods (`Cash`, `InstaPay`, `VodafoneCash`, `Card`), and refunds across both Repair Tickets and POS Invoices.
   - **Operational Expenses & Drawer Closing (`Expenses`):** Record shop expenses and rare ticket-linked external parts to compute exact daily cash drawer balances (`Total Inflows - Total Outflows`) per payment method without double-counting external parts in monthly net profit.

## 4. Development Roadmap (Sprints / Rounds)
- [x] **Round 0:** GitHub repository setup, `.gitignore` configuration, and project folder structure (`Docs/`, `Database/`, `Src/`).
- [ ] **Round 1:** SQL Server database schema (`MobileCareDB` — 16 tables in `01_CreateTables.sql` completed), seed data (`02_SeedData.sql`), reporting views/procedures (`03_ViewsAndProcedures.sql`), and C# Data Access Layer (DAL).
- [ ] **Round 2:** Main application shell, role-based navigation, POS checkout screen, and Repair Ticket intake screen.
- [ ] **Round 3:** Spare parts compatibility manager, damaged/external parts workflow, and technician commission calculator.
- [ ] **Round 4:** Daily treasury closing, periodic sales/profit reports, low-stock dashboard alerts, and deployment installer.