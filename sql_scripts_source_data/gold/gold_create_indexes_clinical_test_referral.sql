-- Authored by David Hippisley-Cox
-- project: sql_scripts_source_data
-- analysis plan version: NA
\W
USE gold;

--idx_patid

CREATE INDEX idx_patid ON clinical_001 (patid);
CREATE INDEX idx_patid ON clinical_002 (patid);
CREATE INDEX idx_patid ON clinical_003 (patid);


CREATE INDEX idx_patid ON test_001 (patid);
CREATE INDEX idx_patid ON test_002 (patid);

CREATE INDEX idx_patid ON referral (patid);

CREATE INDEX idx_patid ON immunisation (patid);

-- idx_medcode_eventdate
CREATE INDEX idx_medcode_eventdate ON clinical_001 (medcode, eventdate);
CREATE INDEX idx_medcode_eventdate ON clinical_002 (medcode, eventdate);
CREATE INDEX idx_medcode_eventdate ON clinical_003 (medcode, eventdate);


CREATE INDEX idx_medcode_eventdate ON test_001 (medcode, eventdate);
CREATE INDEX idx_medcode_eventdate ON test_002 (medcode, eventdate);

CREATE INDEX idx_medcode_eventdate ON referral (medcode, eventdate);

CREATE INDEX idx_medcode_eventdate ON immunisation (medcode, eventdate);


