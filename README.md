# 🚗 Car Repair Hub - Maintenance Tracking System

An **Oracle APEX 26.2** application designed to streamline vehicle maintenance requests. The system features a robust **Role-Based Access Control** workflow, allowing different departments to collaborate on a single request from intake to final delivery.

![Oracle APEX](https://img.shields.io/badge/Oracle%20APEX-26.2-red)
![Oracle DB](https://img.shields.io/badge/Oracle%20DB-21c-blue)

## 📖 Overview
The application consists of two main parts:
1. **Intake Application**: A public-facing or kiosk-style form where customers or receptionists submit vehicle maintenance requests, including vehicle details and 6 mandatory/optional images (using Camera and Gallery).
2. **Tracking Application**: An internal dashboard for staff to manage the request lifecycle based on their assigned roles.

## 🔄 Workflow & Roles
The system enforces a strict workflow using a custom PL/SQL Package (`CR_WORKFLOW_PKG`):
*   **Technician**: Receives the request, adds labor costs and spare parts, and sends it for financial approval.
*   **Accountant**: Reviews the costs and approves or rejects them (returning to Technician with notes if rejected).
*   **Technician**: Completes the maintenance work and sends the request to Quality Control.
*   **Quality Reviewer**: Reviews the final work and images. Approves (status becomes Completed) or Rejects (returns to Technician with mandatory notes).
*   **System Administrator**: Has read-only access to view all screens and reports, but cannot modify any data.

## 🛠️ Tech Stack & Features
*   **Oracle APEX 26.2** & **Oracle Database**.
*   **Master-Detail Forms** (Technician Workbench) with Interactive Grids.
*   **BLOB Image Handling** (Base64 rendering for Modals to avoid APEX 26.2 display bugs).
*   **PL/SQL Packages** for centralized business logic and state transitions.
*   **Authorization Schemes** & Application Access Control for security.
*   **Dynamic UI**: Dashboard with KPIs and Conditional Buttons based on status/roles.

## 🗄️ Database Schema
All tables are prefixed with `CR_`.
*   `CR_REQUEST`: Main request data.
*   `CR_REQUEST_PARTS`: Spare parts details.
*   `CR_REQUEST_IMAGES`: BLOB storage for vehicle photos.
*   `CR_APP_USERS` & `CR_USER_ROLES`: User and role management.
*   `CR_REQUEST_HISTORY`: Audit trail for all status changes.

## 🚀 Setup Instructions
1. Run `database/01_ddl.sql` to create tables and sequences.
2. Run `database/02_seed_data.sql` to insert roles and statuses.
3. Compile `database/03_package.sql`.
4. Import `apex/app_intake.sql` and `apex/app_tracking.sql` into your APEX workspace.
5. Create APEX users and assign roles in Application Access Control.

## 👤 Author
Omar Nour
- LinkedIn: https://www.linkedin.com/in/omar-nour-030666417/
