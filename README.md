<!-- # senaite-mysql-populator
Batch script to populate a MySQL database from SENAITE data for Metabase reporting. -->

# SENAITE MySQL Populator & Metabase Report

This project provides an automated data pipeline (Python batch script) to synchronize laboratory data from **SENAITE LIMS** into a relational **MySQL database**. This layout enables advanced analytics, business intelligence, and dashboarding within **Metabase**.

---

## 📊 Data Model (ERD)

This data model maps the core entities of SENAITE, split into configuration, CRM, operational laboratory workflows, reporting, and auditing.

```mermaid
erDiagram
    %% 1. LAB CONFIGURATION DOMAIN
    LAB-DEPARTMENTS ||--o{ ANALYSIS-SERVICES : "contains"
    INSTRUMENTS ||--o{ METHODS : "used for"
    INSTRUMENTS ||--o{ WORKSHEETS : "linked to"
    CALCULATIONS ||--o{ ANALYSIS-SERVICES : "calculates"
    METHODS ||--o{ ANALYSIS-SERVICES : "defines"
    SAMPLE-TYPES ||--o{ SAMPLES : "matrixed as"

    %% 2. RELATION & CLIENT DOMAIN (CRM)
    CLIENTS ||--o{ CONTACTS : "has"
    CLIENTS ||--o{ ANALYSIS-REQUESTS : "requests"
    CONTACTS ||--o{ ANALYSIS-REQUESTS : "is contact for"

    %% 3. OPERATIONAL WORKFLOW & RESULTS
    SAMPLES ||--|| ANALYSIS-REQUESTS : "strict 1:1 link"
    SAMPLES ||--o{ SAMPLE-PARTITIONS : "split into"
    ANALYSIS-REQUESTS ||--o{ ANALYSES : "contains"
    ANALYSIS-SERVICES ||--o{ ANALYSES : "provides definition for"
    WORKSHEETS ||--o{ ANALYSES : "groups"

    %% 4. REPORTS & AUDIT TRAIL
    ANALYSIS-REQUESTS ||--o{ REPORTS : "results in"

    LAB-DEPARTMENTS {
        varchar uid PK
        varchar title
        varchar review_state
    }
    INSTRUMENTS {
        varchar uid PK
        varchar title
        date calibration_expiry
    }
    METHODS {
        varchar uid PK
        varchar instrument_uid FK
    }
    ANALYSIS-SERVICES {
        varchar uid PK
        varchar keyword UK
        varchar department_uid FK
        varchar method_uid FK
        varchar calculation_uid FK
    }
    CLIENTS {
        varchar uid PK
        varchar client_id UK
        varchar name
    }
    SAMPLES {
        varchar uid PK
        varchar sample_id UK
        varchar sample_type_uid FK
        varchar review_state
    }
    ANALYSIS-REQUESTS {
        varchar uid PK
        varchar request_id UK
        varchar client_uid FK
        varchar sample_uid FK
    }
    WORKSHEETS {
        varchar uid PK
        varchar worksheet_id UK
        varchar instrument_uid FK
    }
    ANALYSES {
        varchar uid PK
        varchar analysis_request_uid FK
        varchar analysis_service_uid FK
        varchar worksheet_uid FK
        varchar formatted_result
        varchar review_state
    }
```

## 🛠️ Database Setup

To initialize the database environment, the raw SQL definitions are available in `/database/schema.sql`.

---

## 🔄 Python Batch Program (Cron)

The synchronization script runs as a periodic batch job using `cron`. It fetches modified objects from the **SENAITE JSON API** and writes them transactionally to MySQL.
