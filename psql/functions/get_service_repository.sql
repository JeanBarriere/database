CREATE TYPE app_public.service_repository AS (
  service     app_public.git_service,
  owner_name  citext,
  repo_name   citext
);

CREATE FUNCTION app_public.get_service_repository(service_uuid uuid) RETURNS app_public.service_repository AS $$
  SELECT o.service AS service, o.username AS owner_name, r.name AS repo_name
  FROM app_public.services s
  INNER JOIN app_hidden.repos r ON (r.uuid = s.repo_uuid)
  INNER JOIN app_public.owner_vcs o ON (o.uuid = r.owner_vcs_uuid)
  WHERE s.uuid = service_uuid AND (s.public OR s.owner_uuid = current_owner_uuid())
  LIMIT 1
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path FROM CURRENT;

COMMENT ON FUNCTION app_public.get_service_repository(uuid) IS E'Return the repository information for a single service.';
