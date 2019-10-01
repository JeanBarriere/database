-- Revert storyscript:current_owner from pg

BEGIN;

DROP FUNCTION current_owner();

COMMIT;
