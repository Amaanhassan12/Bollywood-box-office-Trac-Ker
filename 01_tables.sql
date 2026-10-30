-- =====================================================================
-- 01_tables.sql  |  Bollywood Box Office Tracker
-- Creates sequences, tables and the verdict function.
-- Safe to re-run: it drops old objects first (errors on first run are OK).
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED

-- ---------- clean slate (ignore "does not exist" errors) ----------
BEGIN
  FOR t IN (SELECT object_name, object_type FROM user_objects
            WHERE object_name IN ('BOXOFFICE_PKG','TRG_DC_BEFORE_INS','TRG_DC_TOTALS',
                                  'TRG_MOVIES_VERDICT','V_MOVIE_PERFORMANCE',
                                  'FN_CALC_VERDICT','LOAD_MOVIES_FROM_STAGING')
              AND object_type IN ('PACKAGE','TRIGGER','VIEW','FUNCTION','PROCEDURE'))
  LOOP
    EXECUTE IMMEDIATE 'DROP ' || t.object_type || ' ' || t.object_name;
  END LOOP;
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('COLLECTION_AUDIT','DAILY_COLLECTION','MOVIES',
                                 'INDUSTRIES','STG_MOVIES'))
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
  FOR s IN (SELECT sequence_name FROM user_sequences
            WHERE sequence_name IN ('SEQ_MOVIE','SEQ_INDUSTRY','SEQ_COLLECTION'))
  LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
/

-- ---------- sequences ----------
CREATE SEQUENCE seq_industry   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_movie      START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_collection START WITH 1 INCREMENT BY 1 NOCACHE;

-- ---------- staging table: mirrors the CSV exactly ----------
CREATE TABLE stg_movies (
  movie_name    VARCHAR2(200),
  worldwide     NUMBER,
  india_net     NUMBER,
  india_gross   NUMBER,
  overseas      NUMBER,
  budget        NUMBER,
  verdict       VARCHAR2(50),
  movie_type    VARCHAR2(50),
  released_date VARCHAR2(20)
);

-- ---------- lookup: film industry ----------
CREATE TABLE industries (
  industry_id   NUMBER        PRIMARY KEY,
  industry_name VARCHAR2(50)  NOT NULL UNIQUE
);

-- ---------- movies (all amounts in INR crore) ----------
CREATE TABLE movies (
  movie_id            NUMBER         PRIMARY KEY,
  title               VARCHAR2(200)  NOT NULL,
  industry_id         NUMBER         NOT NULL,
  release_date        DATE           NOT NULL,
  budget_cr           NUMBER(10,2),                 -- NULL = budget unknown
  worldwide_cr        NUMBER(14,4),
  india_net_cr        NUMBER(14,4),
  india_gross_cr      NUMBER(14,4),
  overseas_cr         NUMBER(14,4),
  official_verdict    VARCHAR2(30),                 -- verdict given in the dataset
  total_collection_cr NUMBER(14,4)   DEFAULT 0 NOT NULL,  -- running total (kept by trigger)
  calc_verdict        VARCHAR2(30)   DEFAULT 'Running',    -- verdict computed by our rule
  CONSTRAINT fk_movie_industry FOREIGN KEY (industry_id) REFERENCES industries(industry_id),
  CONSTRAINT uq_movie_title_date UNIQUE (title, release_date),
  CONSTRAINT ck_movie_budget CHECK (budget_cr IS NULL OR budget_cr > 0)
);

-- ---------- day-wise collection ----------
CREATE TABLE daily_collection (
  collection_id   NUMBER        PRIMARY KEY,
  movie_id        NUMBER        NOT NULL,
  collection_date DATE          NOT NULL,
  day_number      NUMBER,                            -- set by trigger
  amount_cr       NUMBER(12,4)  NOT NULL,
  CONSTRAINT fk_dc_movie  FOREIGN KEY (movie_id) REFERENCES movies(movie_id),
  CONSTRAINT uq_movie_day UNIQUE (movie_id, collection_date),
  CONSTRAINT ck_dc_amount CHECK (amount_cr >= 0)
);
CREATE INDEX idx_dc_movie ON daily_collection(movie_id);

-- ---------- audit log (filled by trigger) ----------
CREATE TABLE collection_audit (
  audit_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  movie_id   NUMBER,
  old_amount NUMBER(12,4),
  new_amount NUMBER(12,4),
  action     VARCHAR2(10),
  changed_on TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- ---------- verdict rule: collection vs budget ----------
-- Our own rule (the dataset's verdicts are kept separately in official_verdict).
CREATE OR REPLACE FUNCTION fn_calc_verdict (
  p_budget     IN NUMBER,
  p_collection IN NUMBER
) RETURN VARCHAR2 DETERMINISTIC IS
  v_ratio NUMBER;
BEGIN
  IF p_collection IS NULL OR p_collection = 0 THEN
    RETURN 'Running';
  END IF;
  IF p_budget IS NULL THEN
    RETURN 'Budget N/A';
  END IF;

  v_ratio := p_collection / p_budget;
  IF    v_ratio >= 3    THEN RETURN 'Blockbuster';
  ELSIF v_ratio >= 2    THEN RETURN 'Super Hit';
  ELSIF v_ratio >= 1.25 THEN RETURN 'Hit';
  ELSIF v_ratio >= 0.8  THEN RETURN 'Average';
  ELSIF v_ratio >= 0.4  THEN RETURN 'Flop';
  ELSE                       RETURN 'Disaster';
  END IF;
END fn_calc_verdict;
/

-- ---------- convenience view ----------
CREATE OR REPLACE VIEW v_movie_performance AS
SELECT m.movie_id,
       m.title,
       i.industry_name,
       m.release_date,
       m.budget_cr,
       m.total_collection_cr,
       CASE WHEN m.budget_cr IS NULL THEN NULL
            ELSE ROUND(m.total_collection_cr - m.budget_cr, 2) END AS profit_cr,
       ROUND(m.total_collection_cr / NULLIF(m.budget_cr, 0), 2)    AS roi_multiple,
       m.official_verdict,
       m.calc_verdict
FROM   movies m
JOIN   industries i ON i.industry_id = m.industry_id;

PROMPT 01_tables.sql done.
