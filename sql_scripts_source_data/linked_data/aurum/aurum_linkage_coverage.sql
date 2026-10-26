-- Authored by David Hippisley-Cox
-- project: sql_scripts_source_data
-- analysis plan version: NA
CREATE TABLE IF NOT EXISTS aurum_linkage_coverage_march_2026
(
    data_source VARCHAR(16),
    `start` DATE,
    `end` DATE
)
ENGINE = InnoDB
CHARSET = utf8mb4;

LOAD DATA INFILE
    '{{DATA_ROOT}}/Gold_JAN2026_linked/Gold_1/Documentation/2026 March/Aurum_linkage_coverage_March_2026.txt'
IGNORE
INTO TABLE aurum_linkage_coverage_march_2026
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    data_source,
    @start,
    @end
)
SET
    `start` = STR_TO_DATE(NULLIF(@start, ''), '%d/%m/%Y'),
    `end`   = STR_TO_DATE(NULLIF(@end, ''), '%d/%m/%Y');



