CREATE TYPE app_public.service_repository AS (
  service     app_public.git_service,
  owner_name  app_public.username,
  repo_name   app_public.username
);

CREATE FUNCTION app_public.get_service_repository(service_uuid uuid) RETURNS app_public.service_repository AS $$
  SELECT o.service AS service, o.username AS owner_name, r.name AS name
  FROM app_public.services s
  INNER JOIN app_hidden.repos r ON (r.uuid = s.repo_uuid)
  INNER JOIN app_public.owner_vcs o ON (o.uuid = r.owner_vcs_uuid)
  WHERE s.uuid = service_uuid
  LIMIT 1
$$ LANGUAGE sql STABLE SET search_path FROM CURRENT;

COMMENT ON FUNCTION app_public.get_service_repository(uuid) IS E'Return the repository information for a single service.';
