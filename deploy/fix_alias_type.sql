-- Deploy storyscript:fix_alias_type to pg

BEGIN;

-- drop old constraint
ALTER DOMAIN app_public.alias DROP CONSTRAINT alias_check;

-- add new constraint
ALTER DOMAIN app_public.alias ADD CONSTRAINT alias_check CHECK ((length((VALUE)::text) > 1) AND (length((VALUE)::text) < 25) AND
                                (VALUE ~ '^[a-zA-Z][a-zA-Z-_0-9]*$'::citext));

COMMIT;
