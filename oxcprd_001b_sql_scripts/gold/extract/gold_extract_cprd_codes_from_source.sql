-- dementia


CALL extract_by_code_to_table(
    'therapy',
    'gold_oxcprd_001b',
    'v1_2_dementia_drug_gold',
    '1900-01-02',
    '2026-04-03',
    'patid,eventdate,prodcode',
    'dementia_drug_therapy',
    TRUE
);


CALL extract_by_code_to_table(
    'clinical',
    'gold_oxcprd_001b',
    'v1_5_dementia_codes_gold',
    '1900-01-02',
    '2026-04-03',
    'patid,eventdate,medcode',
    'dementia_clinical',
    TRUE
);

CALL extract_by_code_to_table(
    'referral',
    'gold_oxcprd_001b',
    'v1_5_dementia_codes_gold',
    '1900-01-02',
    '2026-04-03',
    'patid,eventdate,medcode',
    'dementia_referral',
    TRUE
);

CALL extract_by_code_to_table(
    'test',
    'gold_oxcprd_001b',
    'v1_5_dementia_codes_gold',
    '1900-01-02',
    '2026-04-03',
    'patid,eventdate,medcode',
    'dementia_test',
    TRUE
);

CALL extract_by_code_to_table(
    'immunisation',
    'gold_oxcprd_001b',
    'v1_5_dementia_codes_gold',
    '1900-01-02',
    '2026-04-03',
    'patid,eventdate,medcode',
    'dementia_immunisation',
    TRUE
);


CALL extract_by_code_to_table(
    'clinical',
    'gold_oxcprd_001b',
    'v2_2_alcohol_codes_gold',
    '1900-01-02',
    '2026-04-03',
    'patid,eventdate,medcode',
    'alcohol_clinical',
    TRUE
);

CALL extract_by_code_to_table(
    'referral',
    'gold_oxcprd_001b',
    'v2_2_alcohol_codes_gold',
    '1900-01-02',
    '2026-04-03',
    'patid,eventdate,medcode',
    'alcohol_referral',
    TRUE
);

CALL extract_by_code_to_table(
    'test',
    'gold_oxcprd_001b',
    'v2_2_alcohol_codes_gold',
    '1900-01-02',
    '2026-04-03',
    'patid,eventdate,medcode',
    'alcohol_test',
    TRUE
);

CALL extract_by_code_to_table(
    'immunisation',
    'gold_oxcprd_001b',
    'v2_2_alcohol_codes_gold',
    '1900-01-02',
    '2026-04-03',
    'patid,eventdate,medcode',
    'alcohol_immunisation',
    TRUE
);