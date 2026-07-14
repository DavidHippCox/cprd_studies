\W
USE aurum_test;

CREATE INDEX idx_patid ON observation_001 (patid);
CREATE INDEX idx_patid ON observation_002 (patid);
CREATE INDEX idx_patid ON observation_003 (patid);
CREATE INDEX idx_patid ON observation_004 (patid);
CREATE INDEX idx_patid ON observation_005 (patid);
CREATE INDEX idx_patid ON observation_006 (patid);
CREATE INDEX idx_patid ON observation_007 (patid);
CREATE INDEX idx_patid ON observation_009 (patid);
CREATE INDEX idx_patid ON observation_010 (patid);

CREATE INDEX idx_patid ON observation_011 (patid);
CREATE INDEX idx_patid ON observation_012 (patid);
CREATE INDEX idx_patid ON observation_013 (patid);
CREATE INDEX idx_patid ON observation_014 (patid);
CREATE INDEX idx_patid ON observation_015 (patid);
CREATE INDEX idx_patid ON observation_016 (patid);
CREATE INDEX idx_patid ON observation_017 (patid);
CREATE INDEX idx_patid ON observation_018 (patid);
CREATE INDEX idx_patid ON observation_019 (patid);
CREATE INDEX idx_patid ON observation_020 (patid);


CREATE INDEX idx_medcodeid_obsdate ON observation_001 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_002 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_003 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_004 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_005 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_006 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_007 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_008 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_009 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_010 (medcodeid, obsdate);

CREATE INDEX idx_medcodeid_obsdate ON observation_011 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_012 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_013 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_014 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_015 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_016 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_017 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_018 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_019 (medcodeid, obsdate);
CREATE INDEX idx_medcodeid_obsdate ON observation_020 (medcodeid, obsdate);



ALTER TABLE observation_001 ADD PRIMARY KEY (obsid);
ALTER TABLE observation_002 ADD PRIMARY KEY (obsid);
ALTER TABLE observation_003 ADD PRIMARY KEY (obsid);
ALTER TABLE observation_004 ADD PRIMARY KEY (obsid);
ALTER TABLE observation_005 ADD PRIMARY KEY (obsid);
ALTER TABLE observation_006 ADD PRIMARY KEY (obsid);
ALTER TABLE observation_007 ADD PRIMARY KEY (obsid);
ALTER TABLE observation_008 ADD PRIMARY KEY (obsid);
ALTER TABLE observation_009 ADD PRIMARY KEY (obsid);
ALTER TABLE observation_010 ADD PRIMARY KEY (obsid);

ALTER TABLE observation_011 ADD PRIMARY KEY (obsid); 
ALTER TABLE observation_012 ADD PRIMARY KEY (obsid); 
ALTER TABLE observation_013 ADD PRIMARY KEY (obsid); 
ALTER TABLE observation_014 ADD PRIMARY KEY (obsid); 
ALTER TABLE observation_015 ADD PRIMARY KEY (obsid); 
ALTER TABLE observation_016 ADD PRIMARY KEY (obsid); 
ALTER TABLE observation_017 ADD PRIMARY KEY (obsid); 
ALTER TABLE observation_018 ADD PRIMARY KEY (obsid); 
ALTER TABLE observation_019 ADD PRIMARY KEY (obsid); 
ALTER TABLE observation_020 ADD PRIMARY KEY (obsid);



