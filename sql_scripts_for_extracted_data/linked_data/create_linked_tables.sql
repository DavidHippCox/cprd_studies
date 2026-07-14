use gold;

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


--  hes_diagnosis_hosp:

DROP TABLE IF EXISTS hes_diagnosis_hosp

CREATE TABLE IF NOT EXISTS hes_diagnosis_hosp
(patid BIGINT UNSIGNED,
spno BIGINT UNSIGNED,
admidate DATE,
discharged DATE,
ICD CHAR(5),
ICDx CHAR(2),
primary_key INT PRIMARY KEY AUTO_INCREMENT)
ENGINE=InnoDB
CHARSET=utf8mb4

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

--  hesop_patient_pathway:

DROP TABLE IF EXISTS hesop_patient_pathway

CREATE TABLE IF NOT EXISTS hesop_patient_pathway
(patid BIGINT UNSIGNED NOT NULL,
attendkey BIGINT UNSIGNED NOT NULL,
subdate DATE,
PRIMARY KEY (patid, attendkey))
ENGINE=InnoDB
CHARSET=utf8mb4

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

-- patient_imd:

DROP TABLE IF EXISTS patient_imd

CREATE TABLE IF NOT EXISTS patient_imd
(patid BIGINT UNSIGNED NOT NULL,
pracid MEDIUMINT,
imd_decile TINYINT,
PRIMARY KEY (patid))
ENGINE=InnoDB
CHARSET=utf8mb4

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
