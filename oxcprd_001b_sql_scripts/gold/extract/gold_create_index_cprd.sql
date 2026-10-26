-- Authored by David Hippisley-Cox
-- project: gold_oxcprd_001b
-- analysis plan version: NA
-- draft
\W
USE gold;

--idx_patid
INDEX ix_medcode_eventdate_patid ON clinical
    (medcode, eventdate, patid)

INDEX ix_patid_medcode_eventdate_patid ON test
    (medcode, eventdate, patid)

INDEX ix_patid_medcode_eventdate_patid ON referral
    (medcode, eventdate, patid)

INDEX ix_patid_medcode_eventdate_patid ON immunisation
    (medcode, eventdate, patid)
     
CREATE INDEX idx_patid ON consultation (patid); -- check

-- idx_prodcode_eventdate
CREATE INDEX idx_prodcode_eventdate_patid ON therapy 
    (medcode, eventdate, patid);


--idx_adid
CREATE INDEX idx_adid_pracid ON additional (adid, pracid); -- check
CREATE INDEX idx_adid_pracid ON clinical (adid, pracid); -- check


--idx_patid
CREATE INDEX idx_patid ON patient (patid);

--idx_pracid
CREATE INDEX idx_pracid ON practice (pracid);


