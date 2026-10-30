# 🎬 Bollywood Box Office Tracker

A complete Database Management System (DBMS) project designed to track, manage, and analyze Bollywood movie box office collections using Oracle SQL and PL/SQL.

This project implements a full data pipeline from raw data ingestion to final analytical reporting.

### 📂 Repository Structure

| File Name | Purpose |
| :--- | :--- |
| `01_tables.sql` | Defines and creates all core tables - Movies, Actors, Producers, Theatres, and Collections. |
| `02_load_staging.sql` | Scripts to load raw CSV/excel data into temporary staging tables. |
| `03_clean_and_load.sql` | Data cleaning logic - handles NULL values, duplicates, and data type validation before loading into main tables. |
| `04_triggers.sql` | Contains triggers to maintain data integrity and auto-calculate total box office collections. |
| `05_boxoffice_pkg.sql` | A PL/SQL package containing stored procedures and functions for business reports and analytics. |

### ✨ Key Features

- **Normalized Database Design:** Follows 3NF to reduce data redundancy.
- **ETL Pipeline:** Complete flow from Staging -> Cleaning -> Main Tables.
- **Data Integrity:** Implemented using Primary Keys, Foreign Keys, and Triggers.
- **Analytical Reports:** Get insights like Top 10 grossing movies, year-wise performance, and actor-wise hit ratio.

### 🛠️ Tech Stack

- **Database:** Oracle 19c / Oracle SQL Developer
- **Language:** SQL, PL/SQL

### 🚀 How to Run the Project

Run the SQL files in sequential order in your SQL Developer or SQL*Plus:

```sql
-- Step 1: Create tables
@01_tables.sql

-- Step 2: Load staging data
@02_load_staging.sql

-- Step 3: Clean and move to main tables
@03_clean_and_load.sql

-- Step 4: Create triggers
@04_triggers.sql

-- Step 5: Create package for reports
@05_boxoffice_pkg.sql