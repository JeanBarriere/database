CREATE FUNCTION app_hidden.current_owner_has_app_permission(app_uuid uuid, required_permission_slug text) RETURNS boolean AS $$
  SELECT EXISTS(
    SELECT 1
    FROM apps
    WHERE uuid = app_uuid
    AND (
      -- If the user owns the app then they have all permissions
      owner_uuid = current_owner_uuid()
    OR
      EXISTS(
        SELECT 1
        FROM team_apps
        INNER JOIN team_permissions USING (team_uuid)
        WHERE team_apps.app_uuid = current_owner_has_app_permission.app_uuid
        AND team_permissions.owner_uuid = current_owner_uuid()
        AND team_permissions.permission_slug IN (required_permission_slug, 'ADMIN')
        LIMIT 1
      )
    )
  );
$$ LANGUAGE sql STABLE STRICT SECURITY DEFINER SET search_path FROM CURRENT;

COMMENT ON FUNCTION app_hidden.current_owner_has_app_permission(app_uuid uuid, required_permission_slug text) IS
  'If the current user has permission to the app using requested permission slug.';
