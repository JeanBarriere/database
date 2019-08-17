-- https://github.com/storyscript/database/pull/101

-- since repo names come directly from vcs
ALTER TABLE app_hidden.repos
    ALTER COLUMN name
    SET DATA TYPE citext;

-- since vcs usernames come directly from vcs
ALTER TABLE owner_vcs
    ALTER COLUMN username
    SET DATA TYPE citext;

ALTER TABLE owner_vcs
    ALTER COLUMN username
    SET NOT NULL;

-- usename domain must be citext
ALTER DOMAIN username RENAME TO username_pending_delete;

CREATE DOMAIN username as citext
  CHECK (LENGTH(VALUE) <= 45 AND LENGTH(VALUE) >= 2 AND VALUE ~ '^\w([\.\-]?\w)*$' );

ALTER TABLE owners
    ALTER COLUMN username
    SET DATA TYPE username;

ALTER TYPE app_public.service_repository
    RENAME TO service_repository_pending_delete;

CREATE TYPE app_public.service_repository AS (
  service     app_public.git_service,
  owner_name  citext,
  repo_name   citext
);

DROP FUNCTION app_public.get_service_repository(uuid);

CREATE FUNCTION app_public.get_service_repository(service_uuid uuid) RETURNS app_public.service_repository AS $$
  SELECT o.service AS service, o.username AS owner_name, r.name AS repo_name
  FROM app_public.services s
  INNER JOIN app_hidden.repos r ON (r.uuid = s.repo_uuid)
  INNER JOIN app_public.owner_vcs o ON (o.uuid = r.owner_vcs_uuid)
  WHERE s.uuid = service_uuid AND (s.public OR s.owner_uuid = current_owner_uuid())
  LIMIT 1
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path FROM CURRENT;

DROP TYPE service_repository_pending_delete;

DROP FUNCTION app_private.create_owner_by_login(
  app_public.git_service,
  text,
  username_pending_delete,
  text,
  email,
  text);

DROP FUNCTION app_private.create_owner_by_login(
  app_public.git_service,
  text,
  username_pending_delete,
  text,
  email,
  text,
  text);

DROP FUNCTION app_private.create_owner_by_login(
  app_public.git_service,
  text,
  username_pending_delete,
  text,
  email,
  text,
  text,
  boolean);

CREATE FUNCTION app_private.create_owner_by_login(
  service app_public.git_service,
  service_id text,
  username username,
  name text,
  email email,
  oauth_token text
) RETURNS json AS $$
  DECLARE
    profile_picture text;
  BEGIN
    profile_picture := '';
    IF $1='github' THEN
      profile_picture := CONCAT('https://avatars.githubusercontent.com/u/', $2);
    END IF;
    RETURN app_private.create_owner_by_login(
      $1, $2, $3, $4, $5, $6, profile_picture, TRUE);
  END;
$$ LANGUAGE plpgsql VOLATILE SET search_path FROM CURRENT;

CREATE OR REPLACE FUNCTION owner_username_conflict() RETURNS TRIGGER AS $$
DECLARE
  _username username;
  _n int default 0;
BEGIN

  _username = NEW.username;

  LOOP
    IF EXISTS (SELECT 1 FROM owners WHERE username=_username limit 1) THEN
      IF _n > 0 THEN
        _username = rtrim(_username, ('-' || _n)) || '-' || (_n + 1);
      ELSE
        _username = _username || '-' || (_n + 1);
      END IF;
      _n = _n + 1;
    ELSE
      NEW.username = _username;
      EXIT;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION app_private.create_owner_by_login(
  service app_public.git_service,
  service_id text,
  username username,
  name text,
  email email,
  oauth_token text,
  profile_image_url text
) RETURNS json AS $$
  BEGIN
    RETURN app_private.create_owner_by_login(
      $1, $2, $3, $4, $5, $6, $7, TRUE);
  END;
$$ LANGUAGE plpgsql VOLATILE SET search_path FROM CURRENT;

CREATE FUNCTION app_private.create_owner_by_login(
    service app_public.git_service,
    service_id text,
    username username,
    name text,
    email email,
    oauth_token text,
    profile_image_url text,
    is_user boolean
) RETURNS json AS $$
  DECLARE _owner_uuid uuid DEFAULT NULL;
  DECLARE _owner_vcs_uuid uuid DEFAULT NULL;
  DECLARE _token_uuid uuid DEFAULT NULL;
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

      -- update their oauth token
      UPDATE app_private.owner_vcs_secrets
        SET oauth_token=$6
        WHERE owner_vcs_uuid=_owner_vcs_uuid;

      -- select an existing login token
      -- TODO create new tokens based on the IP/source of login
      SELECT uuid into _token_uuid
        FROM tokens
        WHERE owner_uuid=_owner_uuid
          AND type='LOGIN'
        LIMIT 1;

    ELSE

      INSERT INTO owners (is_user, username, name, profile_image_url)
        VALUES ($8, $3, $4, $7)
        RETURNING uuid into _owner_uuid;

      INSERT INTO owner_vcs (owner_uuid, service, service_id, username)
        VALUES (_owner_uuid, $1, $2, $3)
        RETURNING uuid into _owner_vcs_uuid;

      IF $5 IS NOT NULL THEN
        INSERT INTO owner_emails (owner_uuid, email, is_verified)
          VALUES (_owner_uuid, $5, true);
      END IF;

      IF $6 IS NOT NULL THEN
        INSERT INTO app_private.owner_vcs_secrets (owner_vcs_uuid, oauth_token)
          VALUES (_owner_vcs_uuid, $6);
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

DROP DOMAIN username_pending_delete;
