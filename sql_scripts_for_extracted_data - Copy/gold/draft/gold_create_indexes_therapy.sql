\W
USE gold;

--idx_patid
CREATE INDEX idx_patid ON therapy_001 (patid);
CREATE INDEX idx_patid ON therapy_002 (patid);
CREATE INDEX idx_patid ON therapy_003 (patid);

-- idx_prodcode_eventdate
CREATE INDEX idx_prodcode_eventdate ON therapy_001 (prodcode, eventdate);
CREATE INDEX idx_prodcode_eventdate ON therapy_002 (prodcode, eventdate);
CREATE INDEX idx_prodcode_eventdate ON therapy_003 (prodcode, eventdate);

