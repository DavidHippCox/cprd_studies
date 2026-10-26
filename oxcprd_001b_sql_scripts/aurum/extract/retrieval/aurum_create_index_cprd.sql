-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_001b
-- analysis plan version: v2
USE aurum_oxcprd_001b;

-- observation
/*
CREATE INDEX idx_patid ON observation
(patid); 
*/
CREATE INDEX idx_medcodeid_eventdate ON observation (medcodeid, obsdate);

-- drugissue
CREATE INDEX idx_patid ON drugissue (patid);

CREATE INDEX idx_medcodeid_eventdate ON drugissue (prodcodeid, issuedate);

-- problem
CREATE INDEX ix_patid ON problem (patid);

-- referral
CREATE INDEX ix_patid ON referral (patid);

--consultation
CREATE INDEX idx_patid ON consultation (patid);

--idx_patid
CREATE INDEX idx_patid ON patient (patid);

--idx_pracid
CREATE INDEX idx_pracid ON practice (pracid);
