-- Verify storyscript:raw_stories on pg

BEGIN;

SELECT column_name
FROM information_schema.columns
WHERE table_name='releases' AND column_name='raw_stories';

ROLLBACK;
