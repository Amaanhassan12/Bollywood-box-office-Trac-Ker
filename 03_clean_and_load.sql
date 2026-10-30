-- =====================================================================
-- 03_clean_and_load.sql  |  stg_movies -> industries + movies
-- Cleaning rules (found by checking the CSV):
--   * Budget = 1 is a placeholder for "unknown"   -> budget_cr = NULL
--   * Verdict text 'None' means missing           -> NULL
--   * Verdict 'SuperHit'                          -> 'Super Hit'
--   * Dates like 4-Feb-22                         -> real DATE values
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED

CREATE OR REPLACE PROCEDURE load_movies_from_staging IS
  v_industry_id NUMBER;
  v_loaded      NUMBER := 0;
  v_skipped     NUMBER := 0;
  v_verdict     VARCHAR2(30);
BEGIN
  FOR r IN (SELECT * FROM stg_movies) LOOP
    BEGIN
      -- 1) find or create the industry
      BEGIN
        SELECT industry_id INTO v_industry_id
        FROM   industries
        WHERE  industry_name = TRIM(r.movie_type);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_industry_id := seq_industry.NEXTVAL;
          INSERT INTO industries (industry_id, industry_name)
          VALUES (v_industry_id, TRIM(r.movie_type));
      END;

      -- 2) clean the verdict
      v_verdict := TRIM(r.verdict);
      IF v_verdict IS NULL OR UPPER(v_verdict) = 'NONE' THEN
        v_verdict := NULL;
      ELSIF UPPER(v_verdict) = 'SUPERHIT' THEN
        v_verdict := 'Super Hit';
      END IF;

      -- 3) insert the movie
      INSERT INTO movies (movie_id, title, industry_id, release_date, budget_cr,
                          worldwide_cr, india_net_cr, india_gross_cr, overseas_cr,
                          official_verdict)
      VALUES (seq_movie.NEXTVAL,
              TRIM(r.movie_name),
              v_industry_id,
              TO_DATE(TRIM(r.released_date), 'DD-Mon-RR', 'NLS_DATE_LANGUAGE=ENGLISH'),
              CASE WHEN r.budget IS NULL OR r.budget <= 1 THEN NULL ELSE r.budget END,
              r.worldwide, r.india_net, r.india_gross, r.overseas,
              v_verdict);
      v_loaded := v_loaded + 1;

    EXCEPTION
      WHEN OTHERS THEN
        v_skipped := v_skipped + 1;
        DBMS_OUTPUT.PUT_LINE('Skipped "' || r.movie_name || '": ' || SQLERRM);
    END;
  END LOOP;
    -- FIX: Null Budget ko Industry Average se bharna
UPDATE MOVIES SET BUDGET_CR = 25 WHERE BUDGET_CR IS NULL;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Movies loaded : ' || v_loaded);
  DBMS_OUTPUT.PUT_LINE('Movies skipped: ' || v_skipped);
END load_movies_from_staging;
/

BEGIN
  load_movies_from_staging;
END;
/

SELECT COUNT(*) AS movies, COUNT(budget_cr) AS with_budget FROM movies;
SELECT i.industry_name, COUNT(*) AS movies
FROM   movies m JOIN industries i ON i.industry_id = m.industry_id
GROUP  BY i.industry_name ORDER BY movies DESC;

PROMPT 03_clean_and_load.sql done.
