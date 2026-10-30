-- =====================================================================
-- 04_triggers.sql  |  automatic bookkeeping
--   trg_dc_before_ins  : assigns collection_id and day_number
--   trg_dc_totals      : keeps movies.total_collection_cr in sync + audit log
--   trg_movies_verdict : recalculates calc_verdict whenever the total changes
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED

CREATE OR REPLACE TRIGGER trg_dc_before_ins
BEFORE INSERT ON daily_collection
FOR EACH ROW
DECLARE
  v_release DATE;
BEGIN
  IF :NEW.collection_id IS NULL THEN
    :NEW.collection_id := seq_collection.NEXTVAL;
  END IF;

  SELECT release_date INTO v_release FROM movies WHERE movie_id = :NEW.movie_id;
  :NEW.day_number := TRUNC(:NEW.collection_date) - TRUNC(v_release) + 1;
END trg_dc_before_ins;
/

CREATE OR REPLACE TRIGGER trg_dc_totals
AFTER INSERT OR UPDATE OR DELETE ON daily_collection
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    UPDATE movies
    SET    total_collection_cr = total_collection_cr + :NEW.amount_cr
    WHERE  movie_id = :NEW.movie_id;

    INSERT INTO collection_audit (movie_id, old_amount, new_amount, action)
    VALUES (:NEW.movie_id, NULL, :NEW.amount_cr, 'INSERT');

  ELSIF UPDATING THEN
    IF :OLD.movie_id <> :NEW.movie_id THEN
      RAISE_APPLICATION_ERROR(-20010, 'A collection row cannot be moved to another movie.');
    END IF;

    UPDATE movies
    SET    total_collection_cr = total_collection_cr - :OLD.amount_cr + :NEW.amount_cr
    WHERE  movie_id = :NEW.movie_id;

    INSERT INTO collection_audit (movie_id, old_amount, new_amount, action)
    VALUES (:NEW.movie_id, :OLD.amount_cr, :NEW.amount_cr, 'UPDATE');

  ELSIF DELETING THEN
    UPDATE movies
    SET    total_collection_cr = total_collection_cr - :OLD.amount_cr
    WHERE  movie_id = :OLD.movie_id;

    INSERT INTO collection_audit (movie_id, old_amount, new_amount, action)
    VALUES (:OLD.movie_id, :OLD.amount_cr, NULL, 'DELETE');
  END IF;
END trg_dc_totals;
/

CREATE OR REPLACE TRIGGER trg_movies_verdict
BEFORE UPDATE OF total_collection_cr ON movies
FOR EACH ROW
BEGIN
  :NEW.calc_verdict := fn_calc_verdict(:NEW.budget_cr, :NEW.total_collection_cr);
END trg_movies_verdict;
/

PROMPT 04_triggers.sql done.
