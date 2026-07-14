\W
USE gold;

--idx_patid
CREATE INDEX idx_patid ON clinical (patid);

CREATE INDEX idx_patid ON test_001 (patid);
CREATE INDEX idx_patid ON test_002 (patid);

CREATE INDEX idx_patid ON referral (patid);

CREATE INDEX idx_patid ON immunisation (patid);

-- idx_medcode_eventdate
CREATE INDEX idx_medcode_eventdate ON clinical (medcode, eventdate);

CREATE INDEX idx_medcode_eventdate ON test_001 (medcode, eventdate);
CREATE INDEX idx_medcode_eventdate ON test_002 (medcode, eventdate);

CREATE INDEX idx_medcode_eventdate ON referral (medcode, eventdate);

CREATE INDEX idx_medcode_eventdate ON immunisation (medcode, eventdate);


