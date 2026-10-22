-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- Implements v1 Analysis Plan  
USE aurum_test;

/*
CALL extract_by_patid_to_table(
'patient',
'aurum_oxcprd_001b',
'candidate_patids',
'*',
'patient',
TRUE,
TRUE
);

CALL extract_by_patid_to_table(
'drugissue',
'aurum_oxcprd_001b',
'candidate_patids',
'*',
'drugissue',
TRUE,
TRUE
);
*/
CALL extract_by_patid_to_table (
  'observation',
  'aurum_oxcprd_001b',
  'candidate_patids',
  '*',
  'observation',
  TRUE,
  TRUE
);

CALL extract_by_patid_to_table (
  'consultation',
  'aurum_oxcprd_001b',
  'candidate_patids',
  '*',
  'consultation',
  TRUE,
  TRUE
);

CALL extract_by_patid_to_table (
  'referral',
  'aurum_oxcprd_001b',
  'candidate_patids',
  '*',
  'referral',
  TRUE,
  TRUE
);

CALL extract_by_patid_to_table ('problem', 'aurum_oxcprd_001b', 'candidate_patids', '*', 'problem', TRUE, TRUE);

/*
CREATE TABLE aurum_oxcprd_001b.practice LIKE aurum_test.practice;
INSERT INTO aurum_oxcprd_001b._practice
SELECT * FROM aurum_test.practice;

CREATE TABLE aurum_oxcprd_001b.staff LIKE aurum_test.staff;
INSERT INTO aurum_oxcprd_001b.staff
SELECT * FROM aurum_test.staff;
*/