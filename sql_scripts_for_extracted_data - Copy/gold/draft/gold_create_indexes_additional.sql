\W
USE gold;

--idx_patid
CREATE INDEX idx_patid ON patient (patid);

--idx_pracid
CREATE INDEX idx_pracid ON practice (pracid);

--idx_adid
CREATE INDEX idx_adid ON additional (adid);




