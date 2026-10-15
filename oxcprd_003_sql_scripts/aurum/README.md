# OXCPRD_003

**Analysis plan version:** 0.1v

## Summary

People with alcohol use disorder (AUD) are commonly prescribed thiamine to prevent or treat thiamine deficiency and associated neurological complications, but it is unclear whether the dose of regular thiamine supplementation influences subsequent dementia risk or dementia-related outcomes. This study will use causal inference methods to estimate the effect of regular prescription of 50 mg versus 100 mg thiamine among people with clinically diagnosed AUD. Outcomes will include the subsequent development of dementia and other clinically relevant dementia-related outcomes, to be determined. 

## Order to Run Scripts

Run the scripts in the following order:

1. `aurum_import_codelists.sql`
2. `import_common_dosages.sql`
3. `aurum_extract_code_date.sql`
4. `aurum_extract_candidate_patids.sql`
5. `aurum_create_index.sql`
6. `cohort_patids.sql`
7. `aurum_export_tables_csv.sql`
