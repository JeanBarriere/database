-- Deploy storyscript:source_code to pg

SET search_path TO :search_path;

BEGIN;

ALTER TABLE releases
ADD COLUMN source_code JSONB DEFAULT NULL;

COMMENT ON COLUMN releases.source_code IS 'A collection of the raw stories deployed. The key is the path to the story from the project root, and the value is a new line delimited story. Example: {"path/to/mystory.story": "line1\nline2"}';

COMMIT;
