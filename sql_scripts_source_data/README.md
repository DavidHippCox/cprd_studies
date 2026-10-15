# Source data management

## Summary

Import & export (and indexing) scripts in mariadb database

## Order to Run Scripts

Run the scripts in the following order:

### Aurum
1. `sql_scripts_source_data\aurum\aurum_import_schema_and_procedures.sql`
2. `sql_scripts_source_data\aurum\aurum_import_calls.sql`
3. `sql_scripts_source_data\aurum\aurum_create_indexes_consultation.sql`
4. `sql_scripts_source_data\aurum\aurum_create_indexes_drugissue.sql`
5. `sql_scripts_source_data\aurum\aurum_create_indexes_observation.sql`
6. `sql_scripts_source_data\aurum\aurum_create_indexes_other_tables.sql`
7. `sql_scripts_source_data\aurum\aurum_extract_procedures.sql`
8. `sql_scripts_source_data\aurum\aurum_vison_to_emis_migrators.sql`


#### Quality control
1. `sql_scripts_source_data\aurum\drugissue_patids.sql`
2. `sql_scripts_source_data\aurum\observation_patids.sql`
3. `sql_scripts_source_data\aurum\aurum_create_own_medical_table.sql`


### Gold


1. `sql_scripts_source_data\gold\gold_import_schema_and_procedures.sql`
2. `sql_scripts_source_data\gold\gold_call_tables.sql`
3. `sql_scripts_source_data\gold\gold_create_indexes_clinical_test_referral.sql`
4. `sql_scripts_source_data\gold\gold_create_indexes_therapy.sql`
5. `sql_scripts_source_data\gold\gold_create_indexes_consultation.sql`
6. `sql_scripts_source_data\gold\gold_create_indexes_other_tables.sql`
7. `sql_scripts_source_data\gold\gold_extract_procedures.sql`


### Linked data

#### Aurum
1. `sql_scripts_source_data\linked_data\aurum\aurum_create_hesae_tables.sql`
2. `sql_scripts_source_data\linked_data\aurum\aurum_create_hesapc_tables.sql`
3. `sql_scripts_source_data\linked_data\aurum\aurum_create_hesop_tables.sql`
4. `sql_scripts_source_data\linked_data\aurum\aurum_linkage_coverage.sql`
5. `sql_scripts_source_data\linked_data\aurum\aurum_other_linked_tables.sql`
6. `sql_scripts_source_data\linked_data\aurum\aurum_create_indexes_icd10_date.sql`
7. `sql_scripts_source_data\linked_data\aurum\aurum_create_indexes_patid.sql`
8. `sql_scripts_source_data\linked_data\aurum\aurum_linked_extract_procedures.sql`

#### Gold
1. `sql_scripts_source_data\linked_data\gold\create_hesae_tables.sql`
2. `sql_scripts_source_data\linked_data\gold\create_hesapc_tables.sql`
3. `sql_scripts_source_data\linked_data\gold\create_hesop_tables.sql`
4. `sql_scripts_source_data\linked_data\gold\gold_linkage_coverage.sql`
5. `sql_scripts_source_data\linked_data\gold\other_linked_tables.sql`
6. `sql_scripts_source_data\linked_data\gold\create_indexes_icd10_date.sql`
7. `sql_scripts_source_data\linked_data\gold\create_indexes_patid.sql`
8. `sql_scripts_source_data\linked_data\gold\linked_extract_procedures.sql`
