CREATE FUNCTION app_private.create_repository(
    owner_vcs_uuid uuid,
    service app_public.git_service,
    service_id text,
    name text
) RETURNS json AS $$
  DECLARE _repo_uuid uuid DEFAULT NULL;
  BEGIN

    SELECT uuid
      INTO _repo_uuid
      FROM repos r
      WHERE r.service=$2
        AND r.service_id=$3
      LIMIT 1;

    IF _repo_uuid IS NOT NULL THEN

      UPDATE repos
        SET owner_vcs_uuid=$1, name=$4, using_github_installation=true
        WHERE uuid=_repo_uuid;

    ELSE

      INSERT INTO repos (owner_vcs_uuid, service, service_id, name, using_github_installation)
        VALUES ($1, $2, $3, $4, true)
        RETURNING uuid into _repo_uuid;

    END IF;

    RETURN json_build_object('repo_uuid', _repo_uuid);

  END;
$$ LANGUAGE plpgsql VOLATILE SET search_path FROM CURRENT;
