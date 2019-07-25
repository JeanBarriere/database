CREATE FUNCTION app_hidden.current_owner_has_organization_permission(owner_uuid uuid, required_permission_slug text) RETURNS boolean AS $$
  SELECT EXISTS(
    SELECT 1
    FROM team_permissions
    INNER JOIN teams ON (team_permissions.team_uuid = teams.uuid)
    WHERE teams.owner_uuid = current_owner_has_organization_permission.owner_uuid
    AND team_permissions.owner_uuid = current_owner_uuid()
    AND team_permissions.permission_slug IN (required_permission_slug, 'ADMIN')
    LIMIT 1
  );
$$ LANGUAGE sql STABLE STRICT SECURITY DEFINER SET search_path FROM CURRENT;

COMMENT ON FUNCTION app_hidden.current_owner_has_organization_permission(owner_uuid uuid, required_permission_slug text) IS
  'If the current user has requested permission slug.';
