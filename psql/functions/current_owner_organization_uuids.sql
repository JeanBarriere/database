CREATE FUNCTION app_hidden.current_owner_organization_uuids(required_permission_slugs text[] = array[]::text[]) RETURNS uuid[] AS $$
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

COMMENT ON FUNCTION current_owner_organization_uuids(text[]) IS E'Gives a list of the organization_uuids for which the current user has ALL passed permissions (via team memberships). If no arguments are passed, gives the organizations that the user is a member of.';
