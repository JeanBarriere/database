-- https://github.com/storyscript/database/pull/86
/*

Remove `team_members` table, it is redundent.

*/

CREATE OR REPLACE FUNCTION app_hidden.current_owner_has_app_permission(app_uuid uuid, required_permission_slug text) RETURNS boolean AS $$
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

CREATE OR REPLACE FUNCTION app_hidden.current_owner_has_organization_permission(owner_uuid uuid, required_permission_slug text) RETURNS boolean AS $$
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


CREATE OR REPLACE FUNCTION app_hidden.current_owner_organization_uuids(required_permission_slugs text[] = array[]::text[]) RETURNS uuid[] AS $$
  SELECT array_agg(distinct uuid)
  FROM (
    SELECT teams.owner_uuid uuid
    FROM team_permissions
    INNER JOIN teams ON (team_permissions.team_uuid = teams.uuid)
    WHERE team_permissions.owner_uuid = current_owner_uuid()
    GROUP BY teams.owner_uuid
    HAVING
      (
        cardinality(required_permission_slugs) = 0
      OR
        (
          -- This is the full set of permissions the user has for all the teams across this organization
          SELECT array_agg(DISTINCT permissions.slug)
          FROM team_permissions
          INNER JOIN permissions ON (team_permissions.permission_slug = permissions.slug)
          WHERE team_permissions.team_uuid = ANY(array_agg(teams.uuid))
          AND permissions.slug = ANY(required_permission_slugs)
        ) @> required_permission_slugs -- `@>` means "contains"
      )
  ) a
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path FROM CURRENT;

DROP TABLE team_members;
