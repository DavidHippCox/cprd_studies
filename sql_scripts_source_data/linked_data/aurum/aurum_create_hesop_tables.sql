--  hesop_patient:

DROP TABLE IF EXISTS hesop_patient;

CREATE TABLE IF NOT EXISTS hesop_patient
(patid BIGINT UNSIGNED NOT NULL,
pracid MEDIUMINT,
cprd_mpsid BIGINT UNSIGNED,
gen_ethnicity VARCHAR(16)
)
ENGINE=InnoDB
CHARSET=utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_1/hesop_patient_24_004516.txt' 
IGNORE
INTO TABLE hesop_patient
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, pracid, cprd_mpsid, @gen_ethnicity)
SET gen_ethnicity = NULLIF(@gen_ethnicity,'');
--  hesop_patient_pathway:

DROP TABLE IF EXISTS hesop_patient_pathway;

CREATE TABLE IF NOT EXISTS hesop_patient_pathway
(patid BIGINT UNSIGNED NOT NULL,
attendkey BIGINT UNSIGNED NOT NULL,
subdate DATE
)
ENGINE=InnoDB
CHARSET=utf8mb4;

DELIMITER //

CREATE PROCEDURE load_hesop_patient_pathway_files()
BEGIN
    DECLARE file_number INT DEFAULT 1;
    DECLARE file_path VARCHAR(1000);

    WHILE file_number <= 20 DO

        SET file_path = CONCAT(
            '{{DATA_ROOT}}/',
            'AURUM_SEP2024_linked/Aurum_10/',
            'hesop_patient_pathway_',
            LPAD(file_number, 3, '0'),
            '_24_004516.txt'
        );

        SET @load_sql = CONCAT(
            'LOAD DATA INFILE ',
            QUOTE(file_path),
            ' IGNORE INTO TABLE hesop_patient_pathway ',
            'FIELDS TERMINATED BY ''\\t'' ',
            'LINES TERMINATED BY ''\\r\\n'' ',
            'IGNORE 1 LINES ',
            '(patid, attendkey, @subdate) ',
            'SET subdate = STR_TO_DATE(',
                'NULLIF(@subdate, ''''), ',
                '''%Y/%m/%d''',
            ')'
        );

        PREPARE load_statement FROM @load_sql;
        EXECUTE load_statement;
        DEALLOCATE PREPARE load_statement;

        SET file_number = file_number + 1;
    END WHILE;
END//

DELIMITER ;
--  hesop_appointment:

DROP TABLE IF EXISTS hesop_appointment;

CREATE TABLE IF NOT EXISTS hesop_appointment
(patid BIGINT UNSIGNED NOT NULL,
attendkey BIGINT UNSIGNED NOT NULL,
ethnos VARCHAR(16),
admincat TINYINT,
apptdate DATE,
apptage SMALLINT,
atentype TINYINT,
attended TINYINT,
dnadate DATE,
firstatt VARCHAR(16),
outcome TINYINT,
priority TINYINT,
refsourc TINYINT,
reqdate DATE,
servtype TINYINT,
stafftyp TINYINT,
wait_ind TINYINT,
waiting SMALLINT
)
ENGINE=InnoDB
CHARSET=utf8mb4;

DELIMITER //

CREATE PROCEDURE load_hesop_appointment_files()
BEGIN
    DECLARE file_number INT DEFAULT 1;
    DECLARE directory_name VARCHAR(20);
    DECLARE file_path VARCHAR(1000);

    WHILE file_number <= 20 DO

        SET directory_name =
            CASE
                WHEN file_number <= 10 THEN 'Aurum_7'
                ELSE 'Aurum_8'
            END;

        SET file_path = CONCAT(
            '{{DATA_ROOT}}/',
            'AURUM_SEP2024_linked/',
            directory_name,
            '/hesop_appointment_',
            LPAD(file_number, 3, '0'),
            '_24_004516.txt'
        );

        SET @load_sql = CONCAT(
            'LOAD DATA INFILE ',
            QUOTE(file_path),
            ' IGNORE INTO TABLE hesop_appointment ',
            'FIELDS TERMINATED BY ''\\t'' ',
            'LINES TERMINATED BY ''\\r\\n'' ',
            'IGNORE 1 LINES ',
            '(',
                'patid, ',
                'attendkey, ',
                '@ethnos, ',
                'admincat, ',
                '@apptdate, ',
                '@apptage, ',
                'atentype, ',
                'attended, ',
                '@dnadate, ',
                '@firstatt, ',
                '@outcome, ',
                'priority, ',
                'refsourc, ',
                '@reqdate, ',
                'servtype, ',
                'stafftyp, ',
                'wait_ind, ',
                '@waiting',
            ') ',
            'SET ',
                'ethnos = NULLIF(@ethnos, ''''), ',
                'apptdate = STR_TO_DATE(',
                    'NULLIF(@apptdate, ''''), ',
                    '''%Y/%m/%d''',
                '), ',
                'apptage = NULLIF(@apptage, ''''), ',
                'dnadate = STR_TO_DATE(',
                    'NULLIF(@dnadate, ''''), ',
                    '''%Y/%m/%d''',
                '), ',
                'firstatt = NULLIF(@firstatt, ''''), ',
                'outcome = NULLIF(@outcome, ''''), ',
                'reqdate = STR_TO_DATE(',
                    'NULLIF(@reqdate, ''''), ',
                    '''%Y/%m/%d''',
                '), ',
                'waiting = NULLIF(@waiting, '''')'
        );

        PREPARE load_statement FROM @load_sql;
        EXECUTE load_statement;
        DEALLOCATE PREPARE load_statement;

        SET file_number = file_number + 1;
    END WHILE;
END//

DELIMITER ;

--  hesop_clinical:

DROP TABLE IF EXISTS hesop_clinical;

CREATE TABLE IF NOT EXISTS hesop_clinical
(patid BIGINT UNSIGNED NOT NULL,
attendkey BIGINT UNSIGNED NOT NULL,
diagnosis VARCHAR(16),
icdx VARCHAR(16),
icd VARCHAR(16),
diag_order SMALLINT,
tretspef VARCHAR(16),
mainspef VARCHAR(16)
)
ENGINE=InnoDB
CHARSET=utf8mb4;

DELIMITER //

CREATE PROCEDURE load_hesop_clinical_files()
BEGIN
    DECLARE file_number INT DEFAULT 1;
    DECLARE file_path VARCHAR(1000);

    WHILE file_number <= 20 DO

        SET file_path = CONCAT(
            '{{DATA_ROOT}}/',
            'AURUM_SEP2024_linked/Aurum_9/',
            'hesop_clinical_',
            LPAD(file_number, 3, '0'),
            '_24_004516.txt'
        );

        SET @load_sql = CONCAT(
            'LOAD DATA INFILE ',
            QUOTE(file_path),
            ' IGNORE INTO TABLE hesop_clinical ',
            'FIELDS TERMINATED BY ''\\t'' ',
            'LINES TERMINATED BY ''\\r\\n'' ',
            'IGNORE 1 LINES ',
            '(',
                'patid, ',
                'attendkey, ',
                '@diagnosis, ',
                '@icdx, ',
                '@icd, ',
                '@diag_order, ',
                '@tretspef, ',
                '@mainspef',
            ') ',
            'SET ',
                'diagnosis = NULLIF(@diagnosis, ''''), ',
                'icdx = NULLIF(@icdx, ''''), ',
                'icd = NULLIF(@icd, ''''), ',
                'diag_order = NULLIF(@diag_order, ''''), ',
                'tretspef = NULLIF(@tretspef, ''''), ',
                'mainspef = NULLIF(@mainspef, '''')'
        );

        PREPARE load_statement FROM @load_sql;
        EXECUTE load_statement;
        DEALLOCATE PREPARE load_statement;

        SET file_number = file_number + 1;
    END WHILE;
END//

DELIMITER ;


-- create hesop_clinical_apptdate by copying hesop_clinical
CREATE TABLE hesop_clinical_apptdate AS
SELECT *
FROM hesop_clinical;

-- add apptdate to hesop_clinical_apptdate from hesop_appointment

ALTER TABLE hesop_clinical_apptdate ADD COLUMN apptdate DATE;

UPDATE hesop_clinical_apptdate AS t1
LEFT JOIN hesop_appointment AS t2
ON t1.patid = t2.patid 
AND t1.attendkey = t2.attendkey
SET t1.apptdate = t2.apptdate
WHERE t1.apptdate IS NULL;

--  hesop_operation:

DROP TABLE IF EXISTS hesop_operation;

CREATE TABLE IF NOT EXISTS hesop_operation
(patid BIGINT UNSIGNED NOT NULL,
attendkey BIGINT UNSIGNED NOT NULL,
operation VARCHAR(16),
opcs VARCHAR(16),
opertn_order SMALLINT,
operstat SMALLINT,
tretspef VARCHAR(16),
mainspef VARCHAR(16)
)
ENGINE=InnoDB
CHARSET=utf8mb4;

DELIMITER //

CREATE PROCEDURE load_hesop_operation_files()
BEGIN
    DECLARE file_number INT DEFAULT 1;
    DECLARE directory_name VARCHAR(20);
    DECLARE file_path VARCHAR(1000);

    WHILE file_number <= 20 DO

        SET directory_name =
            CASE
                WHEN file_number <= 9 THEN 'Aurum_1'
                ELSE 'Aurum_11'
            END;

        SET file_path = CONCAT(
            '{{DATA_ROOT}}/',
            'AURUM_SEP2024_linked/',
            directory_name,
            '/hesop_operation_',
            LPAD(file_number, 3, '0'),
            '_24_004516.txt'
        );

        SET @load_sql = CONCAT(
            'LOAD DATA INFILE ',
            QUOTE(file_path),
            ' IGNORE INTO TABLE hesop_operation ',
            'FIELDS TERMINATED BY ''\\t'' ',
            'LINES TERMINATED BY ''\\r\\n'' ',
            'IGNORE 1 LINES ',
            '(patid, attendkey, @operation, @opcs, ',
            '@opertn_order, @operstat, @tretspef, @mainspef) ',
            'SET ',

            'operation = NULLIF(',
                'REPLACE(REPLACE(REPLACE(TRIM(@operation), ',
                '''\\r'', ''''), ''\\n'', ''''), ''\\t'', ''''), ''''), ',

            'opcs = NULLIF(',
                'REPLACE(REPLACE(REPLACE(TRIM(@opcs), ',
                '''\\r'', ''''), ''\\n'', ''''), ''\\t'', ''''), ''''), ',

            'opertn_order = NULLIF(',
                'REPLACE(REPLACE(REPLACE(TRIM(@opertn_order), ',
                '''\\r'', ''''), ''\\n'', ''''), ''\\t'', ''''), ''''), ',

            'operstat = CASE ',
                'WHEN NULLIF(',
                    'REPLACE(REPLACE(REPLACE(',
                        'TRIM(REPLACE(@operstat, ''"'', '''')), ',
                        '''\\r'', ''''), ''\\n'', ''''), ''\\t'', ''''), ',
                    '''''',
                ') REGEXP ''^[0-9]+$'' ',
                'THEN CAST(',
                    'NULLIF(',
                        'REPLACE(REPLACE(REPLACE(',
                            'TRIM(REPLACE(@operstat, ''"'', '''')), ',
                            '''\\r'', ''''), ''\\n'', ''''), ''\\t'', ''''), ',
                        '''''',
                    ') AS UNSIGNED',
                ') ',
                'ELSE NULL ',
            'END, ',

            'tretspef = NULLIF(',
                'REPLACE(REPLACE(REPLACE(TRIM(@tretspef), ',
                '''\\r'', ''''), ''\\n'', ''''), ''\\t'', ''''), ''''), ',

            'mainspef = NULLIF(',
                'REPLACE(REPLACE(REPLACE(TRIM(@mainspef), ',
                '''\\r'', ''''), ''\\n'', ''''), ''\\t'', ''''), '''')'
        );

        PREPARE load_statement FROM @load_sql;
        EXECUTE load_statement;
        DEALLOCATE PREPARE load_statement;

        SET file_number = file_number + 1;
    END WHILE;
END//

DELIMITER ;

CALL load_hesop_operation_files();