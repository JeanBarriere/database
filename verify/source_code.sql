-- Verify storyscript:source_code on pg

SET search_path TO :search_path;

BEGIN;

SELECT column_name
FROM information_schema.columns
WHERE table_name='releases' AND column_name='source_code';

ROLLBACK;
