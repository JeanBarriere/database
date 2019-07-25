CREATE FUNCTION insert_organization_admin() RETURNS TRIGGER AS $$
DECLARE
   _team_uuid uuid DEFAULT NULL;
BEGIN
  INSERT INTO teams (owner_uuid, name)
    VALUES (NEW.uuid, 'Owners')
    RETURNING uuid into _team_uuid;

  INSERT INTO team_permissions (team_uuid, permission_slug, owner_uuid)
    VALUES (_team_uuid, 'ADMIN', current_owner_uuid());

  RETURN NEW;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE TRIGGER _900_insert_organization_admin
  AFTER INSERT ON owners
  FOR EACH ROW
  WHEN (NEW.is_user IS FALSE)
  EXECUTE PROCEDURE insert_organization_admin();
