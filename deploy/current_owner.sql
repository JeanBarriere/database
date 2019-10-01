-- Deploy storyscript:current_owner to pg

BEGIN;

SET search_path TO app_public,app_hidden,app_private,app_runtime,public;

CREATE FUNCTION current_owner() RETURNS owners AS $$
SELECT * FROM owners WHERE owners.uuid = current_owner_uuid() LIMIT 1;
$$ LANGUAGE sql STABLE SET search_path FROM CURRENT;

COMMIT;
