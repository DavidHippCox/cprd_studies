USE aurum_oxcprd_003;

CREATE INDEX idx_patid ON patient (patid);
CREATE INDEX idx_patid ON patient_2019_imd (patid);
CREATE INDEX idx_patid ON linkage_eligibility (patid);
CREATE INDEX idx_patid ON ethnicity_record (patid);

