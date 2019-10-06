-- Deploy storyscript:source_code to pg

SET search_path TO :search_path;

BEGIN;

ALTER TABLE releases
ADD COLUMN source_code JSONB DEFAULT NULL;

COMMENT ON COLUMN releases.source_code IS '{"story_name": "(line\n)*"}';

COMMIT;
