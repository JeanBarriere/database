-- Revert storyscript:fix_alias_type from pg

BEGIN;

-- remove current constraint
ALTER DOMAIN app_public.alias DROP CONSTRAINT alias_check;

-- add old constraint, super permissive, allowing dots in service names
ALTER DOMAIN app_public.alias ADD CONSTRAINT alias_check CHECK ((length((VALUE)::text) > 1) AND (length((VALUE)::text) < 25) AND
                                (VALUE ~ '^[\w\-\.]+$'::citext));

COMMIT;
