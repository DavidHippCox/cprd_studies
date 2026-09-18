
--  much of the schema is from 
--  https://github.com/Exeter-Diabetes/CPRD-analysis-package/blob/646c32a216c6f43d1b3135b86cd99cb1ef5eb219/data-raw/data-tables.yaml: 

-- replace '{path}' root.file


DROP TABLE IF EXISTS hes_patient;

CREATE TABLE IF NOT EXISTS hes_patient
(patid BIGINT UNSIGNED NOT NULL,
pracid MEDIUMINT,
cprd_mpsid BIGINT UNSIGNED,
gen_ethnicity VARCHAR(16)
)
ENGINE=InnoDB
CHARSET=utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_6/hes_patient_24_004516.txt' IGNORE
INTO TABLE hes_patient
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, pracid, cprd_mpsid, @gen_ethnicity)
SET gen_ethnicity = NULLIF(@gen_ethnicity,''); 



DROP TABLE IF EXISTS hes_maternity;

CREATE TABLE IF NOT EXISTS hes_maternity
(
    patid      BIGINT UNSIGNED NOT NULL,
    spno       BIGINT UNSIGNED,
    epikey     BIGINT UNSIGNED NOT NULL,
    epistart   DATE,
    epiend     DATE,
    eorder     INT,
    epidur     INT,
    numbaby    VARCHAR(9),
    numtailb   INT,
    matordr    INT,
    neocare    INT,
    wellbaby   VARCHAR(9),
    anasdate   DATE,
    birordr    VARCHAR(9),
    birstat    INT,
    biresus    INT,
    sexbaby    VARCHAR(9),
    birweit    INT,
    delmeth    VARCHAR(9),
    delonset   INT,
    delinten   INT,
    delplac    INT,
    delchang   INT,
    delprean   INT,
    delposan   INT,
    delstat    INT,
    anagest    INT,
    gestat     INT,
    numpreg    INT,
    matage     INT,
    neodur     INT,
    antedur    INT,
    postdur    INT
)
ENGINE = InnoDB
CHARSET = utf8mb4;

LOAD DATA INFILE
    '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_6/hes_maternity_24_004516.txt'
IGNORE
INTO TABLE hes_maternity
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    patid,
    @spno,
    epikey,
    @epistart,
    @epiend,
    @eorder,
    @epidur,
    @numbaby,
    @numtailb,
    @matordr,
    @neocare,
    @wellbaby,
    @anasdate,
    @birordr,
    @birstat,
    @biresus,
    @sexbaby,
    @birweit,
    @delmeth,
    @delonset,
    @delinten,
    @delplac,
    @delchang,
    @delprean,
    @delposan,
    @delstat,
    @anagest,
    @gestat,
    @numpreg,
    @matage,
    @neodur,
    @antedur,
    @postdur
)
SET
    spno      = NULLIF(@spno, ''),
    epistart  = STR_TO_DATE(NULLIF(@epistart, ''), '%Y/%m/%d'),
    epiend    = STR_TO_DATE(NULLIF(@epiend, ''), '%Y/%m/%d'),
    eorder    = NULLIF(@eorder, ''),
    epidur    = NULLIF(@epidur, ''),
    numbaby   = NULLIF(@numbaby, ''),
    numtailb  = NULLIF(@numtailb, ''),
    matordr   = NULLIF(@matordr, ''),
    neocare   = NULLIF(@neocare, ''),
    wellbaby  = NULLIF(@wellbaby, ''),
    anasdate  = STR_TO_DATE(NULLIF(@anasdate, ''), '%Y/%m/%d'),
    birordr   = NULLIF(@birordr, ''),
    birstat   = NULLIF(@birstat, ''),
    biresus   = NULLIF(@biresus, ''),
    sexbaby   = NULLIF(@sexbaby, ''),
    birweit   = NULLIF(@birweit, ''),
    delmeth   = NULLIF(@delmeth, ''),
    delonset  = NULLIF(@delonset, ''),
    delinten  = NULLIF(@delinten, ''),
    delplac   = NULLIF(@delplac, ''),
    delchang  = NULLIF(@delchang, ''),
    delprean  = NULLIF(@delprean, ''),
    delposan  = NULLIF(@delposan, ''),
    delstat   = NULLIF(@delstat, ''),
    anagest   = NULLIF(@anagest, ''),
    gestat    = NULLIF(@gestat, ''),
    numpreg   = NULLIF(@numpreg, ''),
    matage    = NULLIF(@matage, ''),
    neodur    = NULLIF(@neodur, ''),
    antedur   = NULLIF(@antedur, ''),
    postdur   = NULLIF(@postdur, '');



--  hes_hospital:

DROP TABLE IF EXISTS hes_hospital;

CREATE TABLE IF NOT EXISTS hes_hospital
(patid BIGINT UNSIGNED NOT NULL,
spno BIGINT UNSIGNED NOT NULL,
admidate DATE,
discharged DATE,
admimeth VARCHAR(2),
admisorc TINYINT,
disdest TINYINT,
dismeth TINYINT,
duration MEDIUMINT,
elecdate DATE,
elecdur SMALLINT
)
ENGINE=InnoDB
CHARSET=utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_4/hes_hospital_24_004516.txt' IGNORE
INTO TABLE hes_hospital
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, spno, @admidate, @discharged, admimeth, admisorc, disdest, dismeth, @duration, @elecdate, @elecdur)
SET admidate = STR_TO_DATE(NULLIF(@admidate,''),'%Y/%m/%d'),
duration = NULLIF(@duration,''),
discharged = STR_TO_DATE(NULLIF(@discharged,''),'%Y/%m/%d'),
elecdate = STR_TO_DATE(NULLIF(@elecdate,''),'%Y/%m/%d'),
elecdur = NULLIF(@elecdur,'');
-- hes_episodes:

DROP TABLE IF EXISTS hes_episodes;

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
admimeth VARCHAR(2),
admisorc TINYINT,
disdest TINYINT,
dismeth TINYINT,
mainspef VARCHAR(3),
tretspef VARCHAR(3),
pconsult VARCHAR(16),
intmanig TINYINT,
classpat TINYINT,
firstreg TINYINT,
ethnos VARCHAR(16)
)
ENGINE=InnoDB
CHARSET=utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_4/hes_episodes_24_004516.txt' IGNORE
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
mainspef = NULLIF(@mainspef,''),
tretspef = NULLIF(NULLIF(@tretspef,''),'000'),
pconsult = IF(@pconsult='&' OR @pconsult='99',NULL,@pconsult),
intmanig = NULLIF(@intmanig,''),
firstreg = NULLIF(@firstreg,''),
ethnos = NULLIF(@ethnos,'');
--  hes_diagnosis_epi:

DROP TABLE IF EXISTS hes_diagnosis_epi;

CREATE TABLE IF NOT EXISTS hes_diagnosis_epi
(patid BIGINT UNSIGNED NOT NULL,
spno BIGINT UNSIGNED,
epikey BIGINT UNSIGNED NOT NULL,
epistart DATE,
epiend DATE,
ICD VARCHAR(5),
ICDx VARCHAR(2),
d_order TINYINT NOT NULL
)
ENGINE=InnoDB
CHARSET=utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_2/hes_diagnosis_epi_24_004516.txt' IGNORE
INTO TABLE hes_diagnosis_epi
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, spno, epikey, @epistart, @epiend, @ICD, @ICDx, d_order)
SET epistart = STR_TO_DATE(NULLIF(@epistart,''),'%Y/%m/%d'),
epiend = STR_TO_DATE(NULLIF(@epiend,''),'%Y/%m/%d'),
ICD = NULLIF(@ICD,'-.'),
ICDx = CASE
            WHEN @ICDx = '' THEN NULL
            WHEN @ICDx = 'A\\' THEN 'A'
            WHEN @ICDx = 'B\\' THEN 'B'
            ELSE @ICDx
        END;

--  hes_diagnosis_hosp:

DROP TABLE IF EXISTS hes_diagnosis_hosp;

CREATE TABLE IF NOT EXISTS hes_diagnosis_hosp
(patid BIGINT UNSIGNED,
spno BIGINT UNSIGNED,
admidate DATE,
discharged DATE,
ICD VARCHAR(5),
ICDx VARCHAR(2)
)
ENGINE=InnoDB
CHARSET=utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_3/hes_diagnosis_hosp_24_004516.txt' 
IGNORE
INTO TABLE hes_diagnosis_hosp
FIELDS TERMINATED BY '\t' ESCAPED BY '\b'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, spno, @admidate, @discharged, @ICD, @ICDx)
SET admidate = STR_TO_DATE(NULLIF(@admidate,''),'%Y/%m/%d'),
discharged = STR_TO_DATE(NULLIF(@discharged,''),'%Y/%m/%d'),
ICD = NULLIF(@ICD,'-.'),
ICDx = NULLIF(@ICDx,'');

--  hes_hrg:

DROP TABLE IF  EXISTS hes_hrg;

CREATE TABLE IF NOT EXISTS hes_hrg
(
    patid       BIGINT UNSIGNED NOT NULL,
    spno        BIGINT UNSIGNED,
    epikey      BIGINT UNSIGNED NOT NULL,
    domproc     VARCHAR(16),
    hrglate35   VARCHAR(16),
    hrgnhs      VARCHAR(16),
    hrgnhsvn    VARCHAR(16),
    suscorehrg  VARCHAR(16),
    sushrg      VARCHAR(16),
    sushrgvers  DECIMAL(16, 4),
    hes_yr      SMALLINT UNSIGNED
)
ENGINE = InnoDB
CHARSET = utf8mb4;


LOAD DATA INFILE
    '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_4/hes_hrg_24_004516.txt'
IGNORE
INTO TABLE hes_hrg
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    patid,
    @spno,
    epikey,
    @domproc,
    @hrglate35,
    @hrgnhs,
    @hrgnhsvn,
    @suscorehrg,
    @sushrg,
    @sushrgvers,
    @hes_yr
)
SET
    spno       = NULLIF(@spno, ''),
    domproc    = NULLIF(@domproc, ''),
    hrglate35  = NULLIF(@hrglate35, ''),
    hrgnhs     = NULLIF(@hrgnhs, ''),
    hrgnhsvn   = NULLIF(@hrgnhsvn, ''),
    suscorehrg = NULLIF(@suscorehrg, ''),
    sushrg     = NULLIF(@sushrg, ''),
    sushrgvers = NULLIF(@sushrgvers, ''),
    hes_yr     = NULLIF(@hes_yr, '');

--  hes_primary_diag_hosp:

DROP TABLE IF EXISTS hes_primary_diag_hosp;

CREATE TABLE IF NOT EXISTS hes_primary_diag_hosp
(patid BIGINT UNSIGNED,
spno BIGINT UNSIGNED,
admidate DATE,
discharged DATE,
ICD_PRIMARY VARCHAR(5),
ICDx VARCHAR(2)
)
ENGINE=InnoDB
CHARSET=utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_6/hes_primary_diag_hosp_24_004516.txt' IGNORE
INTO TABLE hes_primary_diag_hosp
FIELDS TERMINATED BY '\t' ESCAPED BY '\b'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, spno, @admidate, @discharged, ICD_PRIMARY, @ICDx)
SET admidate = STR_TO_DATE(NULLIF(@admidate,''),'%Y/%m/%d'),
discharged = STR_TO_DATE(NULLIF(@discharged,''),'%Y/%m/%d'),
ICDx = NULLIF(@ICDx,'');
--  hes_procedures_epi:

DROP TABLE IF EXISTS hes_procedures_epi;

CREATE TABLE IF NOT EXISTS hes_procedures_epi
(patid BIGINT UNSIGNED NOT NULL,
spno BIGINT UNSIGNED,
epikey BIGINT UNSIGNED NOT NULL,
admidate DATE,
epistart DATE,
epiend DATE,
discharged DATE,
OPCS VARCHAR(4),
evdate DATE,
p_order TINYINT NOT NULL
)
ENGINE=InnoDB
CHARSET=utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_5/hes_procedures_epi_24_004516.txt' IGNORE
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
evdate = STR_TO_DATE(NULLIF(@evdate,''),'%Y/%m/%d');

--  hes_ccare:

DROP TABLE IF EXISTS hes_ccare;

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
ccapcrel TINYINT
)
ENGINE=InnoDB
CHARSET=utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_6/hes_ccare_24_004516.txt' IGNORE
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
bestmatch = NULLIF(@bestmatch,'');



