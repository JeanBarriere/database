COMMENT ON DATABASE postgres IS NULL;

ALTER TYPE app_hidden.http_method SET SCHEMA app_public;

ALTER DOMAIN app_public.username RENAME CONSTRAINT username_check1 TO username_check;

ALTER FUNCTION app_hidden.current_owner_has_app_permission(uuid, text) SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_hidden.current_owner_has_organization_permission(uuid, text) SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_hidden.current_owner_organization_uuids(text[]) SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_hidden.current_owner_uuid() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_hidden.search_terms_to_tsquery(regconfig, text) SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_hidden.tg_tokens__insert_secret() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_private.create_owner_by_login(app_public.git_service, text, app_public.username, text, app_public.email, text, text, uuid) SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.app_prevent_restore() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.app_updated_notify() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.apps_create_dns() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

CREATE FUNCTION app_public.assert_owner_is_organization() RETURNS trigger
    LANGUAGE plpgsql STABLE
AS $$
BEGIN

    IF EXISTS (SELECT 1 FROM app_public.owners WHERE uuid = NEW.owner_uuid AND is_user = TRUE LIMIT 1) THEN
        RAISE EXCEPTION 'Teams cannot be owned by users.';
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION app_public.assert_permissions_exist() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.builds_next_id() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.convert_to_hostname(app_public.title) SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.generate_awesome_word() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.get_service_repository(uuid) SET search_path = app_public, app_hidden, app_private, app_runtime, public;

COMMENT ON FUNCTION app_public.get_service_repository(service_uuid uuid) IS 'Return the repository information for a single service.';

ALTER FUNCTION app_public.release_post_deployed() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.releases_check_app_if_app_deleted() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.releases_defaults() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.releases_next_id() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.releases_notify() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.search_services(text) SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.service_by_alias_or_name(public.citext) SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.services__update_tsvector() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

ALTER FUNCTION app_public.update_ts_in_service_tags() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

COMMENT ON COLUMN app_public.owners.username IS 'Unique namespace for navigation and discovery.';

ALTER FUNCTION app_public.viewer() SET search_path = app_public, app_hidden, app_private, app_runtime, public;

DROP FUNCTION IF EXISTS public.releases_defaults();

COMMENT ON COLUMN app_public.owner_vcs.owner_uuid IS 'A user can attach a vcs to their profile, this is for users-only, not organizations.';

COMMENT ON COLUMN app_public.releases.state IS 'Identifying which release is active or rolling in/out.';

COMMENT ON COLUMN app_public.releases.source IS 'Identifying the cause of this release, whether it was because of a config change, a code update, or a rollback.';

ALTER TABLE ONLY app_public.marketing_sources
    ADD CONSTRAINT marketing_sources_code_key UNIQUE (code);

ALTER TABLE app_public.service_tags RENAME CONSTRAINT service_tags_service_uuid_tag_key TO service_tags_unique;

CREATE UNIQUE INDEX marketing_sources_code_uindex ON app_public.marketing_sources USING btree (code);

CREATE TRIGGER _100_assert_owner_is_organization BEFORE INSERT ON app_public.teams FOR EACH ROW EXECUTE PROCEDURE app_public.assert_owner_is_organization();

ALTER TABLE app_public.owners RENAME CONSTRAINT owners_marketing_source_uuid_fkey TO owners__fk_marketing_source;
