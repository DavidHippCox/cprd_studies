\W
USE gold;

--idx_adid
CREATE INDEX idx_patid ON additional (patid;)
CREATE INDEX idx_adid_pracid ON additional (adid, pracid);

--idx_patid
-- CREATE INDEX idx_patid ON patient (patid);

--idx_pracid
CREATE INDEX idx_pracid ON practice (pracid);
