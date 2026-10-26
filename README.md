# CPRD Studies

**Author: David Hippisley-Cox**

SQL scripts and supporting R and PowerShell code for managing and analysing CPRD Aurum, CPRD GOLD, and linked healthcare data in MariaDB. The codebase covers data import, indexing, cohort extraction, clinical variable preparation, and study analyses, with a focus on alcohol use and dementia-related outcomes.

## Codebase overview

- `sql_scripts_source_data/` — schemas, import and extraction procedures, indexes, and quality-control queries for Aurum, GOLD, and linked data, including Hospital Episode Statistics (HES).
- `aurum_alcohol/`, `aurum_bmi/`, and `aurum_smoking/` — scripts for identifying and preparing alcohol, BMI, and smoking observations.
- `aurum_sample/` — practice-based sample extraction and supporting database utilities.
- `oxcprd_001b_sql_scripts/` — cohort extraction, preprocessing, and R analyses of dementia outcomes by recorded alcohol-use history.
- `oxcprd_002_sql_scripts/` — Aurum extraction for a study of alcohol assessment and interventions before alcohol-related liver disease.
- `oxcprd_003_sql_scripts/` — Aurum cohort preparation for a study of thiamine prescribing among people with alcohol use disorder and subsequent dementia-related outcomes.
- `transfer_databases/` — SQL and PowerShell utilities for transferring MariaDB tablespaces.
- `config/` and `render_paths.ps1` — path templates and a helper for generating scripts with local directory paths.

## Getting started

See [PATHS.md](PATHS.md) for local path configuration and script rendering. Follow the README in each study or utility folder for its purpose and execution order; the repository contains separate workflows rather than one pipeline.
