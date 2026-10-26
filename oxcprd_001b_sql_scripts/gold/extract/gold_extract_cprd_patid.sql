-- Authored by David Hippisley-Cox
-- project: gold_oxcprd_001b
-- analysis plan version: NA
-- done in source database gold;

CALL extract_by_patid_to_table(
   'patient',
   'gold_oxcprd_001b',
   'candidate_patids',
   '*',
   'patient',
   TRUE
);

CALL extract_by_patid_to_table(
   'therapy',
   'gold_oxcprd_001b',
   'candidate_patids',
   '*',
   'therapy',
   TRUE
);

CALL extract_by_patid_to_table(
    'clinical',
    'gold_oxcprd_001b',
    'candidate_patids',
    '*',
    'clinical',
    TRUE
);

CALL extract_by_patid_to_table(
   'consultation',
   'gold_oxcprd_001b',
   'candidate_patids',
   '*',
   'consultation',
   TRUE
);

CALL extract_by_patid_to_table(
   'referral',
   'gold_oxcprd_001b',
   'candidate_patids',
   '*',
   'referral',
   TRUE
);

CALL extract_by_patid_to_table(
   'test',
   'gold_oxcprd_001b',
   'candidate_patids',
   '*',
   'test',
   TRUE
);

CALL extract_by_patid_to_table(
   'immunisation',
   'gold_oxcprd_001b',
   'candidate_patids',
   '*',
   'immunisation',
   TRUE
);

CALL extract_by_adid_to_table(
    'additional',
    'gold_oxcprd_001b',
    'clinical',
    '*',
    'additional',
    TRUE
);


CREATE TABLE gold_oxcprd_001b.practice LIKE gold.practice;
INSERT INTO gold_oxcprd_001b.practice
SELECT * FROM gold.practice;

CREATE TABLE gold_oxcprd_001b.staff LIKE gold.staff;
INSERT INTO gold_oxcprd_001b.staff
SELECT * FROM gold.staff;