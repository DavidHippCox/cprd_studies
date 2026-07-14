\W
USE aurum_test;


CREATE INDEX idx_patid ON consultation_001 (patid);
CREATE INDEX idx_patid ON consultation_002 (patid);
CREATE INDEX idx_patid ON consultation_003 (patid);
CREATE INDEX idx_patid ON consultation_004 (patid);
CREATE INDEX idx_patid ON consultation_005 (patid);
CREATE INDEX idx_patid ON consultation_006 (patid);
CREATE INDEX idx_patid ON consultation_007 (patid);

ALTER TABLE consultation_001 ADD PRIMARY KEY (consid);
ALTER TABLE consultation_002 ADD PRIMARY KEY (consid);
ALTER TABLE consultation_003 ADD PRIMARY KEY (consid);
ALTER TABLE consultation_004 ADD PRIMARY KEY (consid);
ALTER TABLE consultation_005 ADD PRIMARY KEY (consid);
ALTER TABLE consultation_006 ADD PRIMARY KEY (consid);
ALTER TABLE consultation_007 ADD PRIMARY KEY (consid);
