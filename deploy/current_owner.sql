-- Deploy storyscript:current_owner to pg

BEGIN;

CREATE FUNCTION current_owner() RETURNS app_public.owners AS $$
SELECT * FROM owners WHERE owners.uuid = current_owner_uuid() LIMIT 1;
$$ LANGUAGE sql STABLE SET search_path FROM CURRENT;

COMMIT;
