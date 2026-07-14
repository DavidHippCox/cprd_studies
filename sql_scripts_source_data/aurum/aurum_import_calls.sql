USE aurum_test;

-- Run the schema/procedure file once first.
-- Then run these calls in separate MySQL sessions if you want parallel loading.
-- Ranges are inclusive and non-overlapping.

-- SET SESSION foreign_key_checks = 0;
-- SET SESSION unique_checks      = 0;

-- drugissue
/*
CALL load_aurum_range_raw('drugissue_001', 'drugissue', 'drugIssue', 1, 100);
CALL load_aurum_range_raw('drugissue_002', 'drugissue', 'drugIssue', 101, 200);
CALL load_aurum_range_raw('drugissue_003', 'drugissue', 'drugIssue', 201, 300);
CALL load_aurum_range_raw('drugissue_004', 'drugissue', 'drugIssue', 301, 400);
CALL load_aurum_range_raw('drugissue_005', 'drugissue', 'drugIssue', 401, 500);
CALL load_aurum_range_raw('drugissue_006', 'drugissue', 'drugIssue', 501, 600);
CALL load_aurum_range_raw('drugissue_007', 'drugissue', 'drugIssue', 601, 700);
CALL load_aurum_range_raw('drugissue_008', 'drugissue', 'drugIssue', 701, 769);
*/
-- observation
-- CALL load_aurum_range_raw('observation_001', 'observation', 'observation', 1, 100);
/* load_aurum_range_raw('observation_002', 'observation', 'observation', 101, 200);
CALL load_aurum_range_raw('observation_003', 'observation', 'observation', 201, 300);
CALL load_aurum_range_raw('observation_004', 'observation', 'observation', 301, 400);
CALL load_aurum_range_raw('observation_005', 'observation', 'observation', 401, 500);
CALL load_aurum_range_raw('observation_006', 'observation', 'observation', 501, 600);
CALL load_aurum_range_raw('observation_007', 'observation', 'observation', 601, 700);
CALL load_aurum_range_raw('observation_008', 'observation', 'observation', 701, 800); 
CALL load_aurum_range_raw('observation_009', 'observation', 'observation', 801, 900);
*/
CALL load_aurum_range_raw('observation_010', 'observation', 'observation', 902, 1000);
CALL load_aurum_range_raw('observation_011', 'observation', 'observation', 1026, 1100);
CALL load_aurum_range_raw('observation_012', 'observation', 'observation', 1101, 1200);
CALL load_aurum_range_raw('observation_013', 'observation', 'observation', 1201, 1300);
CALL load_aurum_range_raw('observation_014', 'observation', 'observation', 1301, 1400);
CALL load_aurum_range_raw('observation_015', 'observation', 'observation', 1401, 1500);
CALL load_aurum_range_raw('observation_016', 'observation', 'observation', 1501, 1600);
CALL load_aurum_range_raw('observation_017', 'observation', 'observation', 1601, 1700);
CALL load_aurum_range_raw('observation_018', 'observation', 'observation', 1701, 1800);
CALL load_aurum_range_raw('observation_019', 'observation', 'observation', 1801, 1900);
CALL load_aurum_range_raw('observation_020', 'observation', 'observation', 1901, 1987);

-- consultation
CALL load_aurum_range_raw('consultation_001', 'consultation', 'consultation', 1, 100);
CALL load_aurum_range_raw('consultation_002', 'consultation', 'consultation', 101, 200);
CALL load_aurum_range_raw('consultation_003', 'consultation', 'consultation', 201, 300);
CALL load_aurum_range_raw('consultation_004', 'consultation', 'consultation', 301, 400);
CALL load_aurum_range_raw('consultation_005', 'consultation', 'consultation', 401, 500);
CALL load_aurum_range_raw('consultation_006', 'consultation', 'consultation', 501, 600);
CALL load_aurum_range_raw('consultation_007', 'consultation', 'consultation', 601, 642);
