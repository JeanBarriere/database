-- Revert storyscript:current_owner from pg

BEGIN;

SET search_path TO app_public,app_hidden,app_private,app_runtime,public;

DROP FUNCTION current_owner();

COMMIT;
