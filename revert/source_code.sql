-- Revert storyscript:source_code from pg

SET search_path TO :search_path;

BEGIN;

ALTER TABLE releases
DROP COLUMN source_code;

COMMIT;
