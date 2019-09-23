CREATE FUNCTION app_private.create_owner_by_login(
  service app_public.git_service,
  service_id text,
  username username,
  name text,
  email email,
  oauth_token text,
  profile_image_url text default null,
  marketing_source_uuid uuid default null
) RETURNS json AS $$
DECLARE _owner_uuid uuid DEFAULT NULL;
    DECLARE _owner_vcs_uuid uuid DEFAULT NULL;
    DECLARE _token_uuid uuid DEFAULT NULL;
BEGIN
    IF profile_image_url IS NULL AND $1 = 'github' THEN
        profile_image_url = CONCAT('https://avatars.githubusercontent.com/u/', create_owner_by_login.service_id);
    END IF;

    -- TODO IF (service, username) conflict THEN need to truncate the other username
    -- TODO IF (service, service_id) conflict THEN need to update the username

    SELECT uuid, owner_uuid
    INTO _owner_vcs_uuid, _owner_uuid
    FROM owner_vcs o
    WHERE o.service = create_owner_by_login.service
      AND o.service_id = create_owner_by_login.service_id
    LIMIT 1;

    IF _owner_uuid IS NOT NULL THEN

        -- update their oauth token
        UPDATE app_private.owner_vcs_secrets
        SET oauth_token = create_owner_by_login.oauth_token
        WHERE owner_vcs_uuid=_owner_vcs_uuid;

        -- select an existing login token
        -- TODO create new tokens based on the IP/source of login
        SELECT uuid into _token_uuid
        FROM tokens
        WHERE owner_uuid = _owner_uuid
          AND type = 'LOGIN'
        LIMIT 1;

    ELSE

        INSERT INTO owners (is_user, username, name, profile_image_url, marketing_source_uuid)
        VALUES (TRUE, username, name, profile_image_url, marketing_source_uuid)
        RETURNING uuid into _owner_uuid;

        INSERT INTO owner_vcs (owner_uuid, service, service_id, username)
        VALUES (_owner_uuid, service, service_id, username)
        RETURNING uuid into _owner_vcs_uuid;

        IF email IS NOT NULL THEN
            INSERT INTO owner_emails (owner_uuid, email, is_verified)
            VALUES (_owner_uuid, email, TRUE);
        END IF;

        IF oauth_token IS NOT NULL THEN
            INSERT INTO app_private.owner_vcs_secrets (owner_vcs_uuid, oauth_token)
            VALUES (_owner_vcs_uuid, oauth_token);
        END IF;

    END IF;

    IF _token_uuid IS NULL THEN

        INSERT INTO tokens (owner_uuid, type, name, expires)
        VALUES (_owner_uuid, 'LOGIN', 'CLI Login', current_timestamp + '3 months'::interval)
        RETURNING uuid into _token_uuid;

    ELSE

        UPDATE tokens
        SET expires=(current_timestamp + '3 months'::interval)
        WHERE owner_uuid=_owner_uuid
          AND type='LOGIN';

    END IF;

    RETURN json_build_object('owner_uuid', _owner_uuid,
                             'token_uuid', _token_uuid);

END;
$$ LANGUAGE plpgsql VOLATILE SET search_path FROM CURRENT;

COMMENT ON FUNCTION app_private.create_owner_by_login(app_public.git_service, text, username, text, email, text, text, uuid) IS 'Create new users upon logging in.';
