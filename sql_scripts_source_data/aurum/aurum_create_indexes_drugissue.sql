\W
USE aurum_test;

/*
CREATE INDEX idx_patid ON drugissue_001 (patid);
CREATE INDEX idx_patid ON drugissue_002 (patid);
CREATE INDEX idx_patid ON drugissue_003 (patid);
CREATE INDEX idx_patid ON drugissue_004 (patid);
CREATE INDEX idx_patid ON drugissue_005 (patid);
CREATE INDEX idx_patid ON drugissue_006 (patid);
CREATE INDEX idx_patid ON drugissue_007 (patid);
CREATE INDEX idx_patid ON drugissue_008 (patid);

CREATE INDEX idx_prodcodeid_issuedate ON drugissue_001 (prodcodeid, issuedate);
CREATE INDEX idx_prodcodeid_issuedate ON drugissue_002 (prodcodeid, issuedate);
CREATE INDEX idx_prodcodeid_issuedate ON drugissue_003 (prodcodeid, issuedate);
CREATE INDEX idx_prodcodeid_issuedate ON drugissue_004 (prodcodeid, issuedate);
CREATE INDEX idx_prodcodeid_issuedate ON drugissue_005 (prodcodeid, issuedate);
CREATE INDEX idx_prodcodeid_issuedate ON drugissue_006 (prodcodeid, issuedate);
*/
CREATE INDEX idx_prodcodeid_issuedate ON drugissue_007 (prodcodeid, issuedate);
CREATE INDEX idx_prodcodeid_issuedate ON drugissue_008 (prodcodeid, issuedate);

/*
ALTER TABLE drugissue_001 ADD PRIMARY KEY (issueid);
ALTER TABLE drugissue_002 ADD PRIMARY KEY (issueid);
ALTER TABLE drugissue_003 ADD PRIMARY KEY (issueid);
ALTER TABLE drugissue_004 ADD PRIMARY KEY (issueid);
ALTER TABLE drugissue_005 ADD PRIMARY KEY (issueid);
ALTER TABLE drugissue_006 ADD PRIMARY KEY (issueid);
ALTER TABLE drugissue_007 ADD PRIMARY KEY (issueid);
ALTER TABLE drugissue_008 ADD PRIMARY KEY (issueid);
*/