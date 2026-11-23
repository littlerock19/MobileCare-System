# MobileCare ERP & POS System - System Requirements Specification (SRS)

## 1. Project Overview
A desktop application built with **C# (.NET)** and **Microsoft SQL Server** designed to manage mobile phone repair centers, spare parts inventory, and accessories point-of-sale (POS) operations.

## 2. User Roles & Permissions
- **Admin (Manager):** Full access to financial reports (daily, weekly, monthly, yearly), low-stock alerts, system settings, and technician commission/salary calculations.
- **Sales / Receptionist:** Handles accessories POS checkout, creates repair tickets, logs device accessories, and captures before/after device photos.
- **Technician:** Views assigned repair tickets, withdraws spare parts from inventory, logs damaged parts (shrinkage/waste), and updates repair statuses.

## 3. Core Functional Requirements
1. **Inventory & Part Compatibility:**
   - Manage spare parts and accessories with low-stock threshold alerts.
   - Support **Many-to-Many** compatibility mapping (a single spare part can fit multiple phone models, and vice versa).
2. **Repair Ticket Management:**
   - Track full device lifecycle (`Received`, `InProgress`, `Completed`, `Delivered`, `Cancelled`).
   - Record customer details, device IMEI/serial, and included accessories (charger, case, SIM tray, etc.).
   - Capture and attach **Before & After** device photos (stored on disk/shared folder; file paths saved in SQL Server).
3. Damaged & Defective Parts Tracking (Repair Waste & Part Quality):
  - Distinguish between Valid parts (billed to customer), Technician-Damaged parts (installation waste; deducted from stock and ticket net profit), and Factory-Defective / DOA parts (faulty units per part type/grade; excluded from technician commission penalty).
  - Track factory defect count, losses, and defect rate per spare part type/grade (e.g., Incell X vs. Original) without supplier tracking, to evaluate part quality.
4. **Technician Payroll & Commissions:**
   - Automatically calculate technician earnings based on a configurable percentage of net repair profit.
5. **Accessories POS & Sales Reporting:**
   - Fast barcode-ready POS billing for accessories with automated stock deduction and periodic sales/profit reports.

## 4. Development Roadmap (Sprints / Rounds)
- [x] **Round 0:** GitHub repository setup, `.gitignore` configuration, and project folder structure (`Docs/`, `Database/`, `Src/`).
- [ ] **Round 1:** SQL Server database schema (`MobileCareDB`) and C# Data Access Layer (DAL).
- [ ] **Round 2:** Main application shell, navigation, POS screen, and Repair Ticket intake screen.
- [ ] **Round 3:** Spare parts compatibility manager, damaged parts workflow, and technician commission calculator.
- [ ] **Round 4:** Periodic sales/profit reports, low-stock dashboard alerts, and deployment installer.