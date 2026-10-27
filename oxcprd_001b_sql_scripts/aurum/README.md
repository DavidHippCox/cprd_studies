# OXCPRD_001B

**Analysis plan version:** v2

## Summary

Heavy or dependent alcohol use is associated with an increased risk of dementia; however, less is known about whether people with a history of harmful alcohol use experience a different clinical course following a dementia diagnosis.

This study will compare outcomes among people with dementia according to their recorded history of alcohol use. Individuals with no or trivial alcohol consumption (<7 units per week) will be compared with those with alcohol-related dementia or a recorded history of alcohol use disorder, alcohol dependence, or very high alcohol consumption.

Outcomes of interest will include:

- Mortality
- Care-home placement
- Medication use
- Neuropsychiatric symptoms

## Order to Run Scripts

Run the scripts in the following order:

### Preprocessing
1. `extract/identification/aurum_import_codelists_oxcprd_001b.sql`
2. `extract/identification/aurum_extract_code_date.sql`
3. `extract/identification/aurum_linked_extract_code_date.sql`
4. `extract/identification/aurum_create_index_linked.sql`
5. `extract/identification/aurum_cprd_candidate_patids.sql`
6. `extract/retrieval/aurum_extract_cprd_patid_from_source.sql`
7. `extract/retrieval/aurum_extract_linked_patid_from_source.sql`
8. `extract/retrieval/aurum_create_index_cprd.sql`
9. `extract/retrieval/aurum_create_index_linked.sql`
10. `preprocessing/00_ons_death_dedup_export_import.sql`
11. `preprocessing/00_ons_death_dedup.r`
12. `preprocessing/01_patient.sql`
13. `preprocessing/02_dementia.sql`
14. `preprocessing/02a_alcohol_observation.sql`
15. `preprocessing/02b_alcohol_observation_classification.sql`
16. `preprocessing/02c_alcohol_append_hes.sql`
17. `preprocessing/03a_dementia_index.sql`
18. `preprocessing/03b_patient_alcohol_dementia.sql`
19. `preprocessing/04_bmi.sql`
20. `preprocessing/04_patient_freq_and_len.sql`
21. `preprocessing/04_psychiatric_confounders.sql`
22. `preprocessing/04_smoking.sql`
23. `preprocessing/05_post_dementia_outcomes.sql`
24. `preprocessing/06_descriptives.sql`
25. `preprocessing/07_analysis_dataset.sql`
26. `preprocessing/08_table1.sql`


### Analysis

27.  `analysis/descriptives/distributions.R`
28.  `analysis/models/survival.R`