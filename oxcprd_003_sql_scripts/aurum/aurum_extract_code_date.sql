-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_003
-- analysis plan version: NA
USE aurum_oxcprd_003;

CREATE TABLE v0_thimaine_only_drug_aurum 
SELECT * 
  FROM v0_thiamine_drug_aurum 
  WHERE exclude_patid_if_within_thimaine_monotherapy_window=0;

-- CHANGE DATABASE -- 
USE aurum_test;
CALL extract_by_code_to_table(
  'drugissue',
  'aurum_oxcprd_003',
  'v0_thiamine_only_drug_aurum',
  '1998-01-02',
  '2024-12-31',
  '*',
  'thiamine_only_drug_drugissue',
  TRUE,
  TRUE
);

-- CHANGE DATABASE -- 
USE aurum_oxcprd_003;

CREATE INDEX idx_patid on thiamine_only_drug_drugissue (patid, drugrecid);
CREATE INDEX idx_prodcodeid_issuedate on thiamine_only_drug_drugissue (prodcodeid,dosageid);

ALTER TABLE thiamine_only_drug_drugissue ORDER BY patid, issuedate; 

CREATE TABLE thiamine_dosageid 
SELECT prodcodeid, dosageid, count(dosageid) as dosageid_count
FROM thiamine_only_drug_drugissue 
GROUP BY dosageid;

ALTER TABLE thiamine_dosageid order by dosageid_count desc;



CREATE TABLE aurum_oxcprd_003.thiamine_only_patids AS
SELECT
    patid,
    MIN(issuedate) AS earliest_issuedate
    FROM aurum_oxcprd_003.thiamine_only_drug_drugissue
group by patid;


