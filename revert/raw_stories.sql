-- Revert storyscript:raw_stories from pg

SET search_path TO :schema;

BEGIN;

ALTER TABLE releases
DROP COLUMN raw_stories;

COMMIT;
