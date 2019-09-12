CREATE OR REPLACE FUNCTION service_by_alias_or_name(service_name citext) RETURNS services AS $$
  SELECT
    services.*
  FROM
    services
  INNER JOIN owners on services.owner_uuid = owners.uuid
  WHERE
    services.alias ILIKE service_name
    OR (position('/' in service_name)::boolean AND owners.username ILIKE split_part(service_name, '/', 1) AND services.name ILIKE split_part(service_name, '/', 2))
   LIMIT 1;
$$ LANGUAGE sql STABLE SET search_path FROM CURRENT;
