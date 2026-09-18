-- HES Accident & Emergency tables
-- Based on HES_AE_Documentation_v1.9 (March 2026).

DROP TABLE IF EXISTS hesae_patient;

CREATE TABLE IF NOT EXISTS hesae_patient
(
    patid          BIGINT UNSIGNED NOT NULL,
    pracid         INT UNSIGNED,
    gen_hesid      BIGINT UNSIGNED,
    n_patid_hes    BIGINT UNSIGNED,
    gen_ethnicity  VARCHAR(16),
    match_rank     TINYINT UNSIGNED
)
ENGINE = InnoDB
CHARSET = utf8mb4;

LOAD DATA INFILE
    '{{DATA_ROOT}}/Gold_JAN2026_linked/Gold_2/hesae_patient_24_004516.txt'
IGNORE
INTO TABLE hesae_patient
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    patid,
    @pracid,
    @gen_hesid,
    @n_patid_hes,
    @gen_ethnicity,
    @match_rank
)
SET
    pracid        = NULLIF(@pracid, ''),
    gen_hesid     = NULLIF(@gen_hesid, ''),
    n_patid_hes   = NULLIF(@n_patid_hes, ''),
    gen_ethnicity = NULLIF(@gen_ethnicity, ''),
    match_rank    = NULLIF(@match_rank, '');

DROP TABLE IF EXISTS hesae_attendance;

CREATE TABLE IF NOT EXISTS hesae_attendance
(
    patid         BIGINT UNSIGNED NOT NULL,
    aekey         BIGINT UNSIGNED NOT NULL,
    arrivaldate   DATE,
    aepatgroup    INT UNSIGNED,
    aeattendcat   INT UNSIGNED,
    aearrivalmode INT UNSIGNED,
    aedepttype    INT UNSIGNED,
    aerefsource   INT UNSIGNED,
    aeincloctype  INT UNSIGNED,
    aeattenddisp  INT UNSIGNED,
    initdur       INT UNSIGNED,
    tretdur       INT UNSIGNED,
    concldur      INT UNSIGNED,
    depdur        INT UNSIGNED,
    ethnos        VARCHAR(16)
)
ENGINE = InnoDB
CHARSET = utf8mb4;

LOAD DATA INFILE
    '{{DATA_ROOT}}/Gold_JAN2026_linked/Gold_2/hesae_attendance_24_004516.txt'
IGNORE
INTO TABLE hesae_attendance
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    patid,
    aekey,
    @arrivaldate,
    @aepatgroup,
    @aeattendcat,
    @aearrivalmode,
    @aedepttype,
    @aerefsource,
    @aeincloctype,
    @aeattenddisp,
    @initdur,
    @tretdur,
    @concldur,
    @depdur,
    @ethnos
)
SET
    arrivaldate   = STR_TO_DATE(NULLIF(@arrivaldate, ''), '%d/%m/%Y'),
    aepatgroup    = NULLIF(@aepatgroup, ''),
    aeattendcat   = NULLIF(@aeattendcat, ''),
    aearrivalmode = NULLIF(@aearrivalmode, ''),
    aedepttype    = NULLIF(@aedepttype, ''),
    aerefsource   = NULLIF(@aerefsource, ''),
    aeincloctype  = NULLIF(@aeincloctype, ''),
    aeattenddisp  = NULLIF(@aeattenddisp, ''),
    initdur       = NULLIF(@initdur, ''),
    tretdur       = NULLIF(@tretdur, ''),
    concldur      = NULLIF(@concldur, ''),
    depdur        = NULLIF(@depdur, ''),
    ethnos        = NULLIF(@ethnos, '');

DROP TABLE IF EXISTS hesae_diagnosis;

CREATE TABLE IF NOT EXISTS hesae_diagnosis
(
    patid       BIGINT UNSIGNED NOT NULL,
    aekey       BIGINT UNSIGNED NOT NULL,
    diag        VARCHAR(16),
    diag2       VARCHAR(16),
    diag3       VARCHAR(16),
    diaga       VARCHAR(16),
    diags       VARCHAR(16),
    diagscheme  VARCHAR(16),
    diag_order  INT UNSIGNED
)
ENGINE = InnoDB
CHARSET = utf8mb4;

LOAD DATA INFILE
    '{{DATA_ROOT}}/Gold_JAN2026_linked/Gold_2/hesae_diagnosis_24_004516.txt'
IGNORE
INTO TABLE hesae_diagnosis
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    patid,
    aekey,
    @diag,
    @diag2,
    @diag3,
    @diaga,
    @diags,
    @diagscheme,
    @diag_order
)
SET
    diag       = NULLIF(@diag, ''),
    diag2      = NULLIF(@diag2, ''),
    diag3      = NULLIF(@diag3, ''),
    diaga      = NULLIF(@diaga, ''),
    diags      = NULLIF(@diags, ''),
    diagscheme = NULLIF(@diagscheme, ''),
    diag_order = NULLIF(@diag_order, '');

DROP TABLE IF  EXISTS hesae_investigation;

CREATE TABLE IF NOT EXISTS hesae_investigation
(
    patid         BIGINT UNSIGNED NOT NULL,
    aekey         BIGINT UNSIGNED NOT NULL,
    invest        VARCHAR(16),
    invest2       VARCHAR(16),
    invest_order  INT UNSIGNED
)
ENGINE = InnoDB
CHARSET = utf8mb4;

LOAD DATA INFILE
    '{{DATA_ROOT}}/Gold_JAN2026_linked/Gold_2/hesae_investigation_24_004516.txt'
IGNORE
INTO TABLE hesae_investigation
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    patid,
    aekey,
    @invest,
    @invest2,
    @invest_order
)
SET
    invest       = NULLIF(@invest, ''),
    invest2      = NULLIF(@invest2, ''),
    invest_order = NULLIF(@invest_order, '');

DROP TABLE IF EXISTS hesae_treatment;

CREATE TABLE IF NOT EXISTS hesae_treatment
(
    patid        BIGINT UNSIGNED NOT NULL,
    aekey        BIGINT UNSIGNED NOT NULL,
    treat        VARCHAR(16),
    treat2       VARCHAR(16),
    treat3       VARCHAR(16),
    treat_order  INT UNSIGNED
)
ENGINE = InnoDB
CHARSET = utf8mb4;

LOAD DATA INFILE
    '{{DATA_ROOT}}/Gold_JAN2026_linked/Gold_2/hesae_treatment_24_004516.txt'
IGNORE
INTO TABLE hesae_treatment
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    patid,
    aekey,
    @treat,
    @treat2,
    @treat3,
    @treat_order
)
SET
    treat       = NULLIF(@treat, ''),
    treat2      = NULLIF(@treat2, ''),
    treat3      = NULLIF(@treat3, ''),
    treat_order = NULLIF(@treat_order, '');

DROP TABLE IF  EXISTS hesae_hrg;

CREATE TABLE IF NOT EXISTS hesae_hrg
(
    patid       BIGINT UNSIGNED NOT NULL,
    aekey       BIGINT UNSIGNED NOT NULL,
    domproc     VARCHAR(16),
    hrgnhs      VARCHAR(16),
    hrgnhsvn    VARCHAR(16),
    sushrg      VARCHAR(16),
    sushrgvers  DECIMAL(16, 4)
)
ENGINE = InnoDB
CHARSET = utf8mb4;

LOAD DATA INFILE
    '{{DATA_ROOT}}/Gold_JAN2026_linked/Gold_2/hesae_hrg_24_004516.txt'
IGNORE
INTO TABLE hesae_hrg
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    patid,
    aekey,
    @domproc,
    @hrgnhs,
    @hrgnhsvn,
    @sushrg,
    @sushrgvers
)
SET
    domproc    = NULLIF(@domproc, ''),
    hrgnhs     = NULLIF(@hrgnhs, ''),
    hrgnhsvn   = NULLIF(@hrgnhsvn, ''),
    sushrg     = NULLIF(@sushrg, ''),
    sushrgvers = NULLIF(@sushrgvers, '');

DROP TABLE IF  EXISTS hesae_pathway;

CREATE TABLE IF NOT EXISTS hesae_pathway
(
    patid        BIGINT UNSIGNED NOT NULL,
    aekey        BIGINT UNSIGNED NOT NULL,
    rttperstart  DATE,
    rttperend    DATE
)
ENGINE = InnoDB
CHARSET = utf8mb4;

LOAD DATA INFILE
    '{{DATA_ROOT}}/Gold_JAN2026_linked/Gold_2/hesae_pathway_24_004516.txt'
IGNORE
INTO TABLE hesae_pathway
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    patid,
    aekey,
    @rttperstart,
    @rttperend
)
SET
    rttperstart =
        CASE
            WHEN NULLIF(@rttperstart, '') IS NULL
                 OR @rttperstart IN ('01/01/1900', '1900-01-01')
                THEN NULL
            ELSE STR_TO_DATE(@rttperstart, '%d/%m/%Y')
        END,
    rttperend =
        CASE
            WHEN NULLIF(@rttperend, '') IS NULL
                 OR @rttperend IN ('01/01/1900', '1900-01-01')
                THEN NULL
            ELSE STR_TO_DATE(@rttperend, '%d/%m/%Y')
        END;
