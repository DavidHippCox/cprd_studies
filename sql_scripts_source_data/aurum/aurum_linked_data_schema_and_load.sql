use aurum_test;

--  much of the schema is from 
--  https://github.com/Exeter-Diabetes/CPRD-analysis-package/blob/646c32a216c6f43d1b3135b86cd99cb1ef5eb219/data-raw/data-tables.yaml: 

-- replace '{path}' root.file
--  linkage_eligibilty:

DROP TABLE IF EXISTS linkage_eligibilty

CREATE TABLE IF NOT EXISTS linkage_eligibilty
(patid BIGINT UNSIGNED NOT NULL,
PRIMARY KEY (patid))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE linkage_eligibilty
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, @pracid, @linkdate, @hes_e, @death_e, @cr_e, @lsoa_e, @mh_e),
patid = NULLIF(@patid,''),
pracid = NULLIF(@pracid,''),
linkdate = NULLIF(@linkdate,''),
hes_e = NULLIF(@hes_e,''),
death_e = NULLIF(@death_e,''),
cr_e = NULLIF(@cr_e,''),
lsoa_e = NULLIF(@lsoa_e,''),
mh_e = NULLIF(@mh_e,'')

-- hes_patient:

DROP TABLE IF EXISTS hes_patient

CREATE TABLE IF NOT EXISTS hes_patient
(patid BIGINT UNSIGNED NOT NULL,
pracid MEDIUMINT,
cprd_mpsid BIGINT UNSIGNED,
gen_ethnicity TINYINT,
PRIMARY KEY (patid))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hes_patient
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, pracid, cprd_mpsid, @gen_ethnicity)
SET gen_ethnicity = IF(@gen_ethnicity = 'White', 1,
IF(@gen_ethnicity = 'Bl_Carib', 2,
IF(@gen_ethnicity = 'Bl_Afric', 3,
IF(@gen_ethnicity = 'Bl_Other', 4,
IF(@gen_ethnicity = 'Indian', 5,
IF(@gen_ethnicity = 'Pakistani', 6,
IF(@gen_ethnicity = 'Bangladesi', 7,
IF(@gen_ethnicity = 'Oth_Asian', 8,
IF(@gen_ethnicity = 'Chinese', 9,
IF(@gen_ethnicity = 'Mixed', 10,
IF(@gen_ethnicity = 'Other', 11,
IF(@gen_ethnicity = 'Unknown', NULL, NULL))))))))))))

--  hes_hospital:

DROP TABLE IF EXISTS hes_hospital

CREATE TABLE IF NOT EXISTS hes_hospital
(patid BIGINT UNSIGNED NOT NULL,
spno BIGINT UNSIGNED NOT NULL,
admidate DATE,
discharged DATE,
admimeth CHAR(2),
admisorc TINYINT,
disdest TINYINT,
dismeth TINYINT,
duration MEDIUMINT,
elecdate DATE,
elecdur SMALLINT,
PRIMARY KEY (patid, spno))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hes_hospital
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, spno, @admidate, @discharged, admimeth, admisorc, disdest, dismeth, @duration, @elecdate, @elecdur)
SET admidate = STR_TO_DATE(NULLIF(@admidate,''),'%Y/%m/%d'),
discharged = STR_TO_DATE(NULLIF(@discharged,''),'%Y/%m/%d'),
duration = NULLIF(@duration,''),
elecdate = STR_TO_DATE(NULLIF(@elecdate,''),'%Y/%m/%d'),
elecdur = NULLIF(@elecdur,'')
-- hes_episodes:

DROP TABLE IF EXISTS hes_episodes

CREATE TABLE IF NOT EXISTS hes_episodes
(patid BIGINT UNSIGNED NOT NULL,
spno BIGINT UNSIGNED,
epikey BIGINT UNSIGNED NOT NULL,
admidate DATE,
epistart DATE,
epiend DATE,
discharged DATE,
eorder SMALLINT,
epidur MEDIUMINT,
epitype TINYINT,
admimeth CHAR(2),
admisorc TINYINT,
disdest TINYINT,
dismeth TINYINT,
mainspef CHAR(3),
tretspef CHAR(3),
pconsult CHAR(16),
intmanig TINYINT,
classpat TINYINT,
firstreg TINYINT,
ethnos TINYINT,
PRIMARY KEY (patid, epikey))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hes_episodes
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, spno, epikey, @admidate, @epistart, @epiend, @discharged, eorder, @epidur, epitype, admimeth, @admisorc, @disdest, dismeth, @mainspef, @tretspef, @pconsult, @intmanig, classpat, @firstreg, @ethnos)
SET admidate = STR_TO_DATE(NULLIF(@admidate,''),'%Y/%m/%d'),
epistart = STR_TO_DATE(NULLIF(@epistart,''),'%Y/%m/%d'),
epiend = STR_TO_DATE(NULLIF(@epiend,''),'%Y/%m/%d'),
discharged = STR_TO_DATE(NULLIF(@discharged,''),'%Y/%m/%d'),
epidur = NULLIF(@epidur,''),
admisorc = NULLIF(@admisorc,''),
disdest = NULLIF(@disdest,''),
tretspef = NULLIF(NULLIF(@tretspef,''),'000'),
mainspef = NULLIF(@mainspef,''),
pconsult = IF(@pconsult='&' OR @pconsult='99',NULL,@pconsult),
intmanig = NULLIF(@intmanig,''),
firstreg = NULLIF(@firstreg,''),
ethnos = IF(@ethnos = 'White', 1,
IF(@ethnos = 'Bl_Carib', 2,
IF(@ethnos = 'Bl_Afric', 3,
IF(@ethnos = 'Bl_Other', 4,
IF(@ethnos = 'Indian', 5,
IF(@ethnos = 'Pakistani', 6,
IF(@ethnos = 'Bangladesi', 7,
IF(@ethnos = 'Oth_Asian', 8,
IF(@ethnos = 'Chinese', 9,
IF(@ethnos = 'Mixed', 10,
IF(@ethnos = 'Other', 11,
IF(@ethnos = 'Unknown', NULL, NULL))))))))))))
--  hes_diagnosis_epi:

DROP TABLE IF EXISTS hes_diagnosis_epi

CREATE TABLE IF NOT EXISTS hes_diagnosis_epi
(patid BIGINT UNSIGNED NOT NULL,
spno BIGINT UNSIGNED,
epikey BIGINT UNSIGNED NOT NULL,
epistart DATE,
epiend DATE,
ICD CHAR(5),
ICDx CHAR(2),
d_order TINYINT NOT NULL,
PRIMARY KEY (patid, epikey, d_order))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hes_diagnosis_epi
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, spno, epikey, @epistart, @epiend, @ICD, @ICDx, d_order)
SET epistart = STR_TO_DATE(NULLIF(@epistart,''),'%Y/%m/%d'),
epiend = STR_TO_DATE(NULLIF(@epiend,''),'%Y/%m/%d'),
ICD = NULLIF(@ICD,'-.'),
ICDx = NULLIF(@ICDx,'')
--  hesDiagnosisHosp:

DROP TABLE IF EXISTS hesDiagnosisHosp

CREATE TABLE IF NOT EXISTS hesDiagnosisHosp
(patid BIGINT UNSIGNED,
spno BIGINT UNSIGNED,
admidate DATE,
discharged DATE,
ICD CHAR(5),
ICDx CHAR(2),
primary_key INT PRIMARY KEY AUTO_INCREMENT)
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hesDiagnosisHosp
FIELDS TERMINATED BY '\t' ESCAPED BY '\b'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, spno, @admidate, @discharged, @ICD, @ICDx)
SET admidate = STR_TO_DATE(NULLIF(@admidate,''),'%Y/%m/%d'),
discharged = STR_TO_DATE(NULLIF(@discharged,''),'%Y/%m/%d'),
ICD = NULLIF(@ICD,'-.'),
ICDx = NULLIF(@ICDx,'')
--  hes_primary_diag_hosp:

DROP TABLE IF EXISTS hes_primary_diag_hosp

CREATE TABLE IF NOT EXISTS hes_primary_diag_hosp
(patid BIGINT UNSIGNED,
spno BIGINT UNSIGNED,
admidate DATE,
discharged DATE,
ICD_PRIMARY CHAR(5),
ICDx CHAR(2),
primary_key INT PRIMARY KEY AUTO_INCREMENT)
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hes_primary_diag_hosp
FIELDS TERMINATED BY '\t' ESCAPED BY '\b'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, spno, @admidate, @discharged, ICD_PRIMARY, @ICDx)
SET admidate = STR_TO_DATE(NULLIF(@admidate,''),'%Y/%m/%d'),
discharged = STR_TO_DATE(NULLIF(@discharged,''),'%Y/%m/%d'),
ICDx = NULLIF(@ICDx,'')
--  hes_procedures_epi:

DROP TABLE IF EXISTS hes_procedures_epi

CREATE TABLE IF NOT EXISTS hes_procedures_epi
(patid BIGINT UNSIGNED NOT NULL,
spno BIGINT UNSIGNED,
epikey BIGINT UNSIGNED NOT NULL,
admidate DATE,
epistart DATE,
epiend DATE,
discharged DATE,
OPCS CHAR(4),
evdate DATE,
p_order TINYINT NOT NULL,
PRIMARY KEY (patid, epikey, p_order))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hes_procedures_epi
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, spno, epikey, @admidate, @epistart, @epiend, @discharged, @OPCS, @evdate, p_order)
SET admidate = STR_TO_DATE(NULLIF(@admidate,''),'%Y/%m/%d'),
epistart = STR_TO_DATE(NULLIF(@epistart,''),'%Y/%m/%d'),
epiend = STR_TO_DATE(NULLIF(@epiend,''),'%Y/%m/%d'),
discharged = STR_TO_DATE(NULLIF(@discharged,''),'%Y/%m/%d'),
OPCS=NULLIF(NULLIF(@OPCS,''), '&'),
evdate = STR_TO_DATE(NULLIF(@evdate,''),'%Y/%m/%d')
--  hes_acp:

DROP TABLE IF EXISTS hes_acp

CREATE TABLE IF NOT EXISTS hes_acp
(patid BIGINT UNSIGNED,
spno BIGINT UNSIGNED,
epikey BIGINT UNSIGNED,
epistart DATE,
epiend DATE,
eorder TINYINT,
epidur SMALLINT,
numacp TINYINT,
acpn TINYINT,
acpstar DATE,
acpend DATE,
acpdur SMALLINT,
intdays SMALLINT,
depdays SMALLINT,
acploc TINYINT,
acpsour TINYINT,
acpdisp TINYINT,
acpout TINYINT,
acpplan TINYINT,
acpspef CHAR(3),
orgsup TINYINT,
acpdqind CHAR(1),
primary_key INT PRIMARY KEY AUTO_INCREMENT)
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hes_acp
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, spno, epikey, @epistart, @epiend, eorder, @epidur, numacp, @acpn, @acpstar, @acpend, @acpdur, @intdays, @depdays, @acploc, @acpsour, @acpdisp, @acpout, @acpplan, @acpspef, @orgsup, @acpdqind)
SET epistart = STR_TO_DATE(@epistart,'%d/%m/%Y'),
epiend = STR_TO_DATE(NULLIF(@epiend,''),'%d/%m/%Y'),
epidur = NULLIF(@epidur,''),
acpn = IF(@acpn='' OR acpn='99',NULL,@acpn),
acpstar = STR_TO_DATE(NULLIF(@acpstar,''),'%d/%m/%Y'),
acpend = STR_TO_DATE(NULLIF(@acpend,''),'%d/%m/%Y'),
acpdur = NULLIF(@acpdur,''),
intdays = NULLIF(@intdays,''),
depdays = NULLIF(@depdays,''),
acploc = NULLIF(@acploc,''),
acpsour = IF(@acpsour='' OR @acpsour='0',NULL,@acpsour),
acpdisp = IF(@acpdisp='' OR @acpdisp='0',NULL,@acpdisp),
acpout = IF(@acpout='' OR @acpout='0',NULL,@acpout),
acpplan = IF(@acpplan='Y',1,IF(@acpplan='N',2,IF(@acpplan='',NULL,@acpplan))),
acpspef = IF(@acpspef='' OR @acpspef='0',NULL,@acpspef),
orgsup = NULLIF(@orgsup,''),
acpdqind = NULLIF(@acpdqind,'')
--  hes_ccare:

DROP TABLE IF EXISTS hes_ccare

CREATE TABLE IF NOT EXISTS hes_ccare
(patid BIGINT UNSIGNED,
spno BIGINT UNSIGNED,
epikey BIGINT UNSIGNED,
admidate DATE,
discharged DATE,
epistart DATE,
epiend DATE,
eorder TINYINT,
ccstartdate DATE,
ccstarttime TIME,
ccdisrdydate DATE,
ccdisrdytime TIME,
ccdisdate DATE,
ccdistime TIME,
ccadmitype TINYINT,
ccadmisorc TINYINT,
ccsorcloc TINYINT,
ccdisstat TINYINT,
ccdisdest TINYINT,
ccdisloc TINYINT,
cclev2days SMALLINT,
cclev3days SMALLINT,
bcardsupdays SMALLINT,
acardsupdays SMALLINT,
bressupdays SMALLINT,
aressupdays SMALLINT,
gisupdays SMALLINT,
liversupdays SMALLINT,
neurosupdays SMALLINT,
rensupdays SMALLINT,
dermsupdays SMALLINT,
orgsupmax TINYINT,
ccunitfun TINYINT,
unitbedconfig TINYINT,
bestmatch BOOL DEFAULT NULL,
ccapcrel TINYINT,
primary_key INT PRIMARY KEY AUTO_INCREMENT)
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hes_ccare
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, spno, epikey, @admidate, @discharged, @epistart, @epiend, eorder, @ccstartdate, @ccstarttime, @ccdisrdydate, @ccdisrdytime, @ccdisdate, @ccdistime, @ccadmitype, @ccadmisorc, @ccsorcloc, @ccdisstat, @ccdisdest, @ccdisloc, @cclev2days, @cclev3days, @bcardsupdays, @acardsupdays, @bressupdays, @aressupdays, @gisupdays, @liversupdays, @neurosupdays, @rensupdays, @dermsupdays, @orgsupmax, @ccunitfun, @unitbedconfig, @bestmatch, ccapcrel)
SET admidate = STR_TO_DATE(@admidate,'%Y/%m/%d'),
discharged = STR_TO_DATE(NULLIF(@discharged,''),'%Y/%m/%d'),
epistart = STR_TO_DATE(@epistart,'%Y/%m/%d'),
epiend = STR_TO_DATE(@epiend,'%Y/%m/%d'),
ccstartdate = STR_TO_DATE(@ccstartdate,'%Y/%m/%d'),
ccstarttime = NULLIF(@ccstarttime,''),
ccdisrdydate = STR_TO_DATE(NULLIF(@ccdisrdydate,''),'%Y/%m/%d'),
ccdisrdytime = NULLIF(@ccdisrdytime,''),
ccdisdate = STR_TO_DATE(@ccdisdate,'%Y/%m/%d'),
ccdistime = NULLIF(@ccdistime,''),
ccadmitype = NULLIF(NULLIF(@ccadmitype,''), 'NU'),
ccadmisorc = NULLIF(@ccadmisorc,''),
ccsorcloc = NULLIF(@ccsorcloc,''),
ccdisstat = NULLIF(@ccdisstat,''),
ccdisdest = NULLIF(@ccdisdest,''),
ccdisloc = NULLIF(@ccdisloc,''),
cclev2days = IF(@cclev2days='' OR @cclev2days='999',NULL,@cclev2days),
cclev3days = IF(@cclev3days='' OR @cclev3days='999',NULL,@cclev3days),
bcardsupdays = IF(@bcardsupdays='' OR @bcardsupdays='999',NULL,@bcardsupdays),
acardsupdays = IF(@acardsupdays='' OR @acardsupdays='999',NULL,@acardsupdays),
bressupdays = IF(@bressupdays='' OR @bressupdays='999',NULL,@bressupdays),
aressupdays = IF(@aressupdays='' OR @aressupdays='999',NULL,@aressupdays),
gisupdays = IF(@gisupdays='' OR @gisupdays='999',NULL,@gisupdays),
liversupdays = IF(@liversupdays='' OR @liversupdays='999',NULL,@liversupdays),
neurosupdays = IF(@neurosupdays='' OR @neurosupdays='999',NULL,@neurosupdays),
rensupdays = IF(@rensupdays='' OR @rensupdays='999',NULL,@rensupdays),
dermsupdays = IF(@dermsupdays='' OR @dermsupdays='999',NULL,@dermsupdays),
orgsupmax = NULLIF(@orgsupmax,''),
ccunitfun = NULLIF(@ccunitfun,''),
unitbedconfig = NULLIF(@unitbedconfig,''),
bestmatch = NULLIF(@bestmatch,'')

--  hesop_patient:

DROP TABLE IF EXISTS hesop_patient

CREATE TABLE IF NOT EXISTS hesop_patient
(patid BIGINT UNSIGNED NOT NULL,
pracid MEDIUMINT,
cprd_mpsid BIGINT UNSIGNED,
gen_ethnicity CHAR(8),
PRIMARY KEY (patid))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hesop_patient
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, pracid, cprd_mpsid, @gen_ethnicity)
SET gen_ethnicity = NULLIF(@gen_ethnicity,'')
--  hesop_patient_pathway:

DROP TABLE IF EXISTS hesop_patient_pathway

CREATE TABLE IF NOT EXISTS hesop_patient_pathway
(patid BIGINT UNSIGNED NOT NULL,
attendkey BIGINT UNSIGNED NOT NULL,
subdate DATE,
PRIMARY KEY (patid, attendkey))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hesop_patient_pathway
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, attendkey, @subdate)
SET subdate = STR_TO_DATE(NULLIF(@subdate,''),'%Y/%m/%d')
--  hesop_appointment:

DROP TABLE IF EXISTS hesop_appointment

CREATE TABLE IF NOT EXISTS hesop_appointment
(patid BIGINT UNSIGNED NOT NULL,
attendkey BIGINT UNSIGNED NOT NULL,
ethnos CHAR(9),
admincat TINYINT,
apptdate DATE,
apptage SMALLINT,
atentype TINYINT,
attended TINYINT,
dnadate DATE,
firstatt CHAR(9),
outcome TINYINT,
priority TINYINT,
refsourc TINYINT,
reqdate DATE,
servtype TINYINT,
stafftyp TINYINT,
wait_ind TINYINT,
waiting SMALLINT,
PRIMARY KEY (patid, attendkey))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hesop_appointment
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, attendkey, @ethnos, admincat, @apptdate, @apptage, atentype, attended, @dnadate, @firstatt, outcome, priority, refsourc, @reqdate, servtype, stafftyp, wait_ind, @waiting)
SET ethnos = NULLIF(@ethnos,''),
apptdate = STR_TO_DATE(NULLIF(@apptdate,''),'%Y/%m/%d'),
apptage = NULLIF(@apptage,''),
dnadate = STR_TO_DATE(NULLIF(@dnadate,''),'%Y/%m/%d'),
firstatt = NULLIF(@firstatt,''),
reqdate = STR_TO_DATE(NULLIF(@reqdate,''),'%Y/%m/%d'),
waiting = NULLIF(@waiting,'')
--  hesop_clinical:

DROP TABLE IF EXISTS hesop_clinical

CREATE TABLE IF NOT EXISTS hesop_clinical
(patid BIGINT UNSIGNED NOT NULL,
attendkey BIGINT UNSIGNED NOT NULL,
diagnosis CHAR(9),
icdx CHAR(9),
icd CHAR(9),
diag_order SMALLINT,
tretspef CHAR(9),
mainspef CHAR(9),
PRIMARY KEY (patid, attendkey))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hesop_clinical
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, attendkey, @diagnosis, @icdx, @icd, @diag_order, @tretspef, @mainspef)
SET diagnosis = NULLIF(@diagnosis,''),
icdx = NULLIF(@icdx,''),
icd = NULLIF(@icd,''),
diag_order = NULLIF(@diag_order,''),
tretspef = NULLIF(@tretspef,''),
mainspef = NULLIF(@mainspef,'')
--  hesop_operation:

DROP TABLE IF EXISTS hesop_operation

CREATE TABLE IF NOT EXISTS hesop_operation
(patid BIGINT UNSIGNED NOT NULL,
attendkey BIGINT UNSIGNED NOT NULL,
operation CHAR(9),
opcs CHAR(9),
opertn_order SMALLINT,
operstat SMALLINT,
tretspef CHAR(9),
mainspef CHAR(9),
PRIMARY KEY (patid, attendkey))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE hesop_operation
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, attendkey, @operation, @opcs, @opertn_order, @operstat, @tretspef, @mainspef)
SET operation = NULLIF(REPLACE(REPLACE(REPLACE(TRIM(@operation), '\r', ''), '\n', ''), '\t', ''), ''),
    opcs = NULLIF(REPLACE(REPLACE(REPLACE(TRIM(@opcs), '\r', ''), '\n', ''), '\t', ''), ''),
    opertn_order = NULLIF(REPLACE(REPLACE(REPLACE(TRIM(@opertn_order), '\r', ''), '\n', ''), '\t', ''), ''),
    operstat = CASE
                 WHEN NULLIF(REPLACE(REPLACE(REPLACE(TRIM(REPLACE(@operstat, '"', '')), '\r', ''), '\n', ''), '\t', ''), '') REGEXP '^[0-9]+$'
                 THEN CAST(NULLIF(REPLACE(REPLACE(REPLACE(TRIM(REPLACE(@operstat, '"', '')), '\r', ''), '\n', ''), '\t', ''), '') AS UNSIGNED)
                 ELSE NULL
               END,
    tretspef = NULLIF(REPLACE(REPLACE(REPLACE(TRIM(@tretspef), '\r', ''), '\n', ''), '\t', ''), ''),
    mainspef = NULLIF(REPLACE(REPLACE(REPLACE(TRIM(@mainspef), '\r', ''), '\n', ''), '\t', ''), '');

patient_imd:

DROP TABLE IF EXISTS patient_imd

CREATE TABLE IF NOT EXISTS patient_imd
(patid BIGINT UNSIGNED NOT NULL,
pracid MEDIUMINT,
imd_decile TINYINT,
PRIMARY KEY (patid))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE patient_imd
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, pracid, @imd_decile)
SET imd_decile = NULLIF(@imd_decile,'')
--  practiceImd:

DROP TABLE IF EXISTS practiceImd

CREATE TABLE IF NOT EXISTS practiceImd
(pracid MEDIUMINT NOT NULL,
country VARCHAR(9),
e2015_imd_10 TINYINT,
ni2017_imd_10 TINYINT,
s2016_imd_10 TINYINT,
w2014_imd_10 TINYINT,
PRIMARY KEY (pracid))
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE practiceImd
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(pracid, country, @e2015_imd_10, @ni2017_imd_10, @s2016_imd_10, @w2014_imd_10)
SET e2015_imd_10 = NULLIF(@e2015_imd_10,''),
ni2017_imd_10 = NULLIF(@ni2017_imd_10,''),
s2016_imd_10 = NULLIF(@s2016_imd_10,''),
w2014_imd_10 = NULLIF(@w2014_imd_10,'')
--  ons_death:

DROP TABLE IF EXISTS ons_death

CREATE TABLE IF NOT EXISTS ons_death
(patid BIGINT UNSIGNED NOT NULL,
pracid MEDIUMINT,
gen_death_id BIGINT UNSIGNED,
n_patid_death SMALLINT,
match_rank TINYINT,
dor DATE,
dod DATE,
dod_partial SMALLINT,
nhs_indicator TINYINT,
pod_category VARCHAR(21),
cause VARCHAR(5),
cause1 VARCHAR(5),
cause2 VARCHAR(5),
cause3 VARCHAR(5),
cause4 VARCHAR(5),
cause5 VARCHAR(5),
cause6 VARCHAR(5),
cause7 VARCHAR(5),
cause8 VARCHAR(5),
cause9 VARCHAR(5),
cause10 VARCHAR(5),
cause11 VARCHAR(5),
cause12 VARCHAR(5),
cause13 VARCHAR(5),
cause14 VARCHAR(5),
cause15 VARCHAR(5),
PRIMARY KEY (patid))
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{path}' IGNORE
INTO TABLE ons_death
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, pracid, gen_death_id, n_patid_death, match_rank, @dor, @dod, @dod_partial, nhs_indicator, @pod_category, @cause, @cause1, @cause2, @cause3, @cause4, @cause5, @cause6, @cause7, @cause8, @cause9, @cause10, @cause11, @cause12, @cause13, @cause14, @cause15)
SET dor = STR_TO_DATE(@dor,'%d/%m/%Y'),
dod = STR_TO_DATE(NULLIF(@dod,''),'%d/%m/%Y'),
dod_partial = IF(@dod_partial='' OR @dod_partial='--',NULL,SUBSTR(@dod_partial,1,4)),
pod_category = NULLIF(@pod_category,''),
cause = NULLIF(@cause,''),
cause1 = NULLIF(@cause1,''),
cause2 = NULLIF(@cause2,''),
cause3 = NULLIF(@cause3,''),
cause4 = NULLIF(@cause4,''),
cause5 = NULLIF(@cause5,''),
cause6 = NULLIF(@cause6,''),
cause7 = NULLIF(@cause7,''),
cause8 = NULLIF(@cause8,''),
cause9 = NULLIF(@cause9,''),
cause10 = NULLIF(@cause10,''),
cause11 = NULLIF(@cause11,''),
cause12 = NULLIF(@cause12,''),
cause13 = NULLIF(@cause13,''),
cause14 = NULLIF(@cause14,''),
cause15 = NULLIF(@cause15,'')
