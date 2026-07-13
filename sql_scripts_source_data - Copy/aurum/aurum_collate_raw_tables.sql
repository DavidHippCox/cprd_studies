 /*
  Consolidate raw sharded Aurum-style tables into unindexed final raw tables.

  Assumptions:
  - All source shard tables already exist.
  - All source shard tables have the same schema as their corresponding *_raw table.
  - Final consolidated tables should have the exact same schema as the templates.
  - Indexes and primary keys are added later by a separate post-import indexing script.
  - problem_*_raw is consolidated into problem, not referral, because problem_raw
    and referral_raw have different schemas.
*/
SET GLOBAL innodb_buffer_pool_size        = 18719476736;

SET SESSION sql_log_bin = 0;
SET SESSION unique_checks = 0;
SET SESSION foreign_key_checks = 0;
SET SESSION autocommit = 1;

-- Optional, depending on your server settings and workload.
-- Increase only if you understand memory impact per connection.
-- SET SESSION bulk_insert_buffer_size = 1024 * 1024 * 256;


/* --------------------------------------------------------------------------
   Drop and recreate consolidated target tables from templates
   -------------------------------------------------------------------------- */
/*
DROP TABLE IF EXISTS practice;
DROP TABLE IF EXISTS staff;
DROP TABLE IF EXISTS patient;
DROP TABLE IF EXISTS referral;
DROP TABLE IF EXISTS problem;
DROP TABLE IF EXISTS consultation;
DROP TABLE IF EXISTS drug_issue;
DROP TABLE IF EXISTS observation;
*/

/*
CREATE TABLE practice     LIKE practice_001_raw;
CREATE TABLE staff        LIKE staff_001_raw;
CREATE TABLE patient      LIKE patient_001_raw;
CREATE TABLE referral     LIKE referral_001_raw;
*/
CREATE TABLE problem      LIKE problem_001_raw;
CREATE TABLE consultation LIKE consultation_001_raw;
CREATE TABLE drug_issue   LIKE drug_issue_001_raw;
CREATE TABLE observation  LIKE observation_001_raw;


/* --------------------------------------------------------------------------
   Non-sharded template raw tables
   -------------------------------------------------------------------------- */

/*
RENAME TABLE practice_001_raw TO practice;

RENAME TABLE staff_001_raw TO staff;

RENAME TABLE patient_001_raw TO patient;
*/

/* --------------------------------------------------------------------------
   Helper procedure for sharded table consolidation
   -------------------------------------------------------------------------- */

DROP TABLE IF EXISTS consolidation_log;

CREATE TABLE consolidation_log (
    log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    log_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    target_table VARCHAR(128) NOT NULL,
    source_table VARCHAR(128) NOT NULL,
    rows_inserted BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ok', -- update this
    error_sqlstate CHAR(5) NULL,
    error_message TEXT NULL,
    PRIMARY KEY (log_id)
);

DELIMITER //

DROP PROCEDURE IF EXISTS consolidate_shards//

CREATE PROCEDURE consolidate_shards(
    IN p_target_table VARCHAR(128),
    IN p_source_prefix VARCHAR(128),
    IN p_source_suffix VARCHAR(128),
    IN p_start_n INT,
    IN p_end_n INT,
    IN p_pad_width INT
)
BEGIN
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_source_table VARCHAR(256);
    DECLARE v_sql TEXT;
    DECLARE v_rows BIGINT DEFAULT 0;
    DECLARE v_sqlstate CHAR(5);
    DECLARE v_msg TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_msg = MESSAGE_TEXT;

        INSERT INTO consolidation_log
            (target_table, source_table, rows_inserted, status, error_sqlstate, error_message)
        VALUES
            (p_target_table, v_source_table, v_rows, 'failed', v_sqlstate, v_msg);

        RESIGNAL;
    END;

    SET v_i = p_start_n;

    WHILE v_i <= p_end_n DO
        SET v_source_table = CONCAT(
            p_source_prefix,
            LPAD(v_i, p_pad_width, '0'),
            p_source_suffix
        );

        SET v_sql = CONCAT(
            'INSERT INTO `', REPLACE(p_target_table,'`','``'), '` ',
            'SELECT * FROM `', REPLACE(v_source_table,'`','``'), '`'
        );

        SET @sql = v_sql;
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        SET v_rows = ROW_COUNT();
        DEALLOCATE PREPARE stmt;

        INSERT INTO consolidation_log
            (target_table, source_table, rows_inserted, status)
        VALUES
            (p_target_table, v_source_table, v_rows, 'ok');

        SET v_i = v_i + 1;
    END WHILE;
END//

DELIMITER ;


/* --------------------------------------------------------------------------
   Sharded raw table consolidation
   -------------------------------------------------------------------------- */

CALL consolidate_shards('drug_issue',   'drug_issue_',   '_raw', 1,   769,  3);

/* observation_001_raw ... observation_999_raw */
CALL consolidate_shards('observation', 'observation_', '_raw', 1, 999, 3);

/* observation_1000_raw ... observation_1987_raw */
CALL consolidate_shards('observation', 'observation_', '_raw', 1000, 1987, 4);

CALL consolidate_shards('consultation', 'consultation_', '_raw', 1,   642,  3);

CALL consolidate_shards('referral',     'referral_',     '_raw', 1,   16,   3);

CALL consolidate_shards('problem',      'problem_',      '_raw', 1,   90,   3);


/* --------------------------------------------------------------------------
   Cleanup
   -------------------------------------------------------------------------- */

DROP PROCEDURE IF EXISTS consolidate_shards;

SET SESSION foreign_key_checks = 1;
SET SESSION unique_checks = 1;
SET SESSION sql_log_bin = 1;