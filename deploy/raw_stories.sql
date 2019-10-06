-- Deploy storyscript:raw_stories to pg

SET search_path TO :schema;

BEGIN;

ALTER TABLE releases
ADD COLUMN raw_stories JSONB DEFAULT NULL;

COMMIT;
