CREATE FUNCTION app_private.create_organization(
    service app_public.git_service,
    service_id text,
    username username,
    name text,
    github_installation_id int
) RETURNS json AS $$
  DECLARE _owner_uuid uuid DEFAULT NULL;
  DECLARE _owner_vcs_uuid uuid DEFAULT NULL;
  BEGIN

    -- TODO IF (service, username) conflict THEN need to truncate the other username
    -- TODO IF (service, service_id) conflict THEN need to update the username

    SELECT uuid, owner_uuid
      INTO _owner_vcs_uuid, _owner_uuid
      FROM owner_vcs o
      WHERE o.service=$1
        AND o.service_id=$2
      LIMIT 1;

    IF _owner_uuid IS NOT NULL THEN

      -- Update GitHub Installation ID
      UPDATE owner_vcs
        SET github_installation_id=$5
        WHERE uuid=_owner_vcs_uuid;

    ELSE

      INSERT INTO owners (is_user, username, name)
        VALUES (false, $3, $4)
        RETURNING uuid into _owner_uuid;

      INSERT INTO owner_vcs (owner_uuid, service, service_id, username, github_installation_id)
        VALUES (_owner_uuid, $1, $2, $3, $5)
        RETURNING uuid into _owner_vcs_uuid;

    END IF;

    RETURN json_build_object('owner_uuid', _owner_uuid,
                             'owner_vcs_uuid', _owner_vcs_uuid);

  END;
$$ LANGUAGE plpgsql VOLATILE SET search_path FROM CURRENT;
