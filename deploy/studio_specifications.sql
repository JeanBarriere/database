-- Deploy storyscript:studio_specifications to pg

SET search_path TO :search_path;

BEGIN;

create type "app_public"."sso_service" as enum ('github');

drop trigger if exists "_100_app_updated_notify" on "app_public"."apps";

drop trigger if exists "_100_builds_next_id_insert" on "app_public"."builds";

drop trigger if exists "_050_owner_vcs_check_conflicting_username" on "app_public"."owner_vcs";

drop trigger if exists "_100_insert_owner_username_conflict" on "app_public"."owners";

drop trigger if exists "_101_releases_defaults" on "app_public"."releases";

drop trigger if exists "_100_update_ts_in_service_tags" on "app_public"."service_tags";

drop policy "select_member" on "app_private"."owner_billing";

drop policy "select_billing" on "app_private"."owner_subscriptions";

drop policy "select_repo_visible" on "app_public"."builds";

drop policy "select_own" on "app_public"."marketing_sources";

drop policy "delete_organization" on "app_public"."owner_containerconfigs";

drop policy "delete_own" on "app_public"."owner_containerconfigs";

drop policy "insert_organization" on "app_public"."owner_containerconfigs";

drop policy "insert_own" on "app_public"."owner_containerconfigs";

drop policy "select_organization" on "app_public"."owner_containerconfigs";

drop policy "select_own" on "app_public"."owner_containerconfigs";

drop policy "update_organization" on "app_public"."owner_containerconfigs";

drop policy "update_own" on "app_public"."owner_containerconfigs";

drop policy "select_own" on "app_public"."owner_vcs";

drop policy "update_own_marketing_source" on "app_public"."owners";

drop policy "select_all" on "app_public"."service_plans";

drop policy "select_tag" on "app_public"."service_tags";

drop policy "select_public_or_own" on "app_public"."service_usage";

drop policy "select_organization" on "app_public"."services";

drop policy "select_own" on "app_public"."services";

drop policy "select_public" on "app_public"."services";

alter table "app_hidden"."repos" drop constraint "repos_owner_vcs_uuid_fkey";

alter table "app_hidden"."repos" drop constraint "repos_service_id_check";

alter table "app_hidden"."repos" drop constraint "repos_service_id_key";

alter table "app_private"."build_numbers" drop constraint "build_numbers_repo_uuid_fkey";

alter table "app_private"."owner_billing" drop constraint "owner_billing_customer_check";

alter table "app_private"."owner_billing" drop constraint "owner_billing_customer_check1";

alter table "app_private"."owner_billing" drop constraint "owner_billing_owner_uuid_fkey";

alter table "app_private"."owner_subscriptions" drop constraint "fk_plan_uuid";

alter table "app_private"."owner_subscriptions" drop constraint "owner_subscriptions_owner_uuid_fkey";

alter table "app_private"."owner_vcs_secrets" drop constraint "owner_vcs_secrets_owner_vcs_uuid_fkey";

alter table "app_public"."apps" drop constraint "apps_repo_uuid_fkey";

alter table "app_public"."builds" drop constraint "builds_id_check";

alter table "app_public"."builds" drop constraint "builds_repo_uuid_fkey";

alter table "app_public"."external_service_metadata" drop constraint "external_service_metadata_service_uuid_fkey";

alter table "app_public"."marketing_sources" drop constraint "marketing_sources_code_key";

alter table "app_public"."owner_containerconfigs" drop constraint "owner_containerconfigs_owner_uuid_fkey";

alter table "app_public"."owner_containerconfigs" drop constraint "owner_containerconfigs_owner_uuid_name_key";

alter table "app_public"."owner_vcs" drop constraint "owner_vcs_owner_uuid_fkey";

alter table "app_public"."owners" drop constraint "owners_marketing_source_uuid_fkey";

alter table "app_public"."releases" drop constraint "releases_message_check";

alter table "app_public"."service_plans" drop constraint "service_plans_service_uuid_fkey";

alter table "app_public"."service_tags" drop constraint "service_tags_service_uuid_fkey";

alter table "app_public"."service_tags" drop constraint "service_tags_unique";

alter table "app_public"."service_usage" drop constraint "service_usage_cpu_units_check";

alter table "app_public"."service_usage" drop constraint "service_usage_memory_bytes_check";

alter table "app_public"."service_usage" drop constraint "service_usage_next_index_check";

alter table "app_public"."service_usage" drop constraint "service_usage_service_tag_uuid_fkey";

alter table "app_public"."services" drop constraint "services_alias_key";

alter table "app_public"."services" drop constraint "services_owner_uuid_fkey";

alter table "app_public"."services" drop constraint "services_repo_uuid_fkey";

alter table "app_runtime"."subscriptions" drop constraint "subscriptions_app_uuid_fkey";

alter table "app_hidden"."repos" drop constraint "repos_pkey";

alter table "app_private"."build_numbers" drop constraint "build_numbers_pkey";

alter table "app_private"."owner_billing" drop constraint "owner_billing_pkey";

alter table "app_private"."owner_subscriptions" drop constraint "owner_subscriptions_pkey";

alter table "app_private"."owner_vcs_secrets" drop constraint "owner_vcs_secrets_pkey";

alter table "app_public"."builds" drop constraint "builds_pkey";

alter table "app_public"."external_service_metadata" drop constraint "external_service_metadata_pkey";

alter table "app_public"."marketing_sources" drop constraint "marketing_sources_pkey";

alter table "app_public"."owner_containerconfigs" drop constraint "owner_containerconfigs_pkey";

alter table "app_public"."owner_vcs" drop constraint "owner_vcs_pkey";

alter table "app_public"."service_plans" drop constraint "service_plans_pkey";

alter table "app_public"."service_tags" drop constraint "service_tags_pkey";

alter table "app_public"."service_usage" drop constraint "service_usage_pkey";

alter table "app_runtime"."subscriptions" drop constraint "subscriptions_pkey";

drop index if exists "app_hidden"."repos_pkey";

drop index if exists "app_hidden"."repos_service_id_key";

drop index if exists "app_hidden"."repos_service_ids";

drop index if exists "app_hidden"."repos_slug";

drop index if exists "app_private"."build_numbers_pkey";

drop index if exists "app_private"."owner_billing_pkey";

drop index if exists "app_private"."owner_subscriptions_owner_uuid_fk";

drop index if exists "app_private"."owner_subscriptions_pkey";

drop index if exists "app_private"."owner_subscriptions_plan_uuid_fk";

drop index if exists "app_private"."owner_vcs_secrets_pkey";

drop index if exists "app_public"."apps_repo_uuid_fk";

drop index if exists "app_public"."builds_pkey";

drop index if exists "app_public"."external_service_metadata_pkey";

drop index if exists "app_public"."marketing_sources_code_key";

drop index if exists "app_public"."marketing_sources_pkey";

drop index if exists "app_public"."owner_containerconfigs_owner_uuid_name_key";

drop index if exists "app_public"."owner_containerconfigs_pkey";

drop index if exists "app_public"."owner_vcs_ids";

drop index if exists "app_public"."owner_vcs_pkey";

drop index if exists "app_public"."owner_vcs_username";

drop index if exists "app_public"."service_plans_pkey";

drop index if exists "app_public"."service_plans_service_uuid_fk";

drop index if exists "app_public"."service_tags_pkey";

drop index if exists "app_public"."service_tags_unique";

drop index if exists "app_public"."service_usage_pkey";

drop index if exists "app_public"."services_alias_key";

drop index if exists "app_public"."services_names";

drop index if exists "app_public"."services_owners_uuid_fk";

drop index if exists "app_public"."services_repo_uuid_fk";

drop index if exists "app_runtime"."subscriptions_pkey";

drop function if exists "app_private"."create_owner_by_login"(service app_public.git_service, service_id text, username app_public.username, name text, email app_public.email, oauth_token text, profile_image_url text, marketing_source_uuid uuid);

drop function if exists "app_public"."app_updated_notify"();

drop function if exists "app_public"."builds_next_id"();

drop function if exists "app_public"."convert_to_hostname"(name app_public.title);

drop function if exists "app_public"."get_service_repository"(service_uuid uuid);

drop function if exists "app_public"."owner_username_conflict"();

drop function if exists "app_public"."owner_vcs_check_conflicting_username"();

drop function if exists "app_public"."releases_defaults"();

drop function if exists "app_public"."service_by_alias_or_name"(service_name citext);

drop function if exists "app_public"."update_ts_in_service_tags"();

drop table "app_hidden"."repos";

drop table "app_private"."build_numbers";

drop table "app_private"."owner_billing";

drop table "app_private"."owner_subscriptions";

drop table "app_private"."owner_vcs_secrets";

drop table "app_public"."builds";

drop table "app_public"."external_service_metadata";

drop table "app_public"."marketing_sources";

drop table "app_public"."owner_containerconfigs";

drop table "app_public"."service_plans";

drop table "app_public"."service_usage";

drop table "app_runtime"."subscriptions";

-- INSERT INTO pg_enum
--   (enumtypid, enumlabel, enumsortorder)
-- SELECT
--   'release_state'::regtype::oid,
--   'DRAFT',
--   (
--     SELECT MAX(enumsortorder) + 1 FROM pg_enum WHERE enumtypid = 'release_state'::regtype
--   );

ALTER TYPE release_state rename to release_state_old;
CREATE TYPE release_state as enum('DRAFT', 'QUEUED', 'DEPLOYING', 'DEPLOYED', 'TERMINATING', 'TERMINATED', 'NO_DEPLOY', 'FAILED', 'SKIPPED_CONCURRENT', 'TIMED_OUT', 'TEMP_DEPLOYMENT_FAILURE');
alter table "app_public"."releases" alter column "state" type release_state_old USING "state"::text::release_state set default 'DRAFT'::release_state;
drop type release_state_old;

alter table "app_public"."apps" drop column "environment";

alter table "app_public"."apps" drop column "maintenance";

alter table "app_public"."apps" drop column "repo_uuid";

alter table "app_public"."owners" drop column "marketing_source_uuid";

-- push sso_github_id from old owner_vcs.service_id place
alter table "app_public"."owners" add column "sso_github_id" citext;

UPDATE "app_public"."owners" SET "sso_github_id" = "vcs"."service_id" FROM "app_public"."owner_vcs" as "vcs" WHERE "app_public"."owners"."uuid" = "vcs"."owner_uuid";

alter table "app_public"."owners" alter column "sso_github_id" set not null;

drop table "app_public"."owner_vcs";

alter table "app_public"."releases" drop column "always_pull_images";

alter table "app_public"."releases" drop column "config";

alter table "app_public"."releases" drop column "message";

alter table "app_public"."releases" drop column "payload";

alter table "app_public"."releases" drop column "source";

alter table "app_public"."services" drop column "alias";

alter table "app_public"."services" drop column "is_certified";

alter table "app_public"."services" drop column "links";

alter table "app_public"."services" drop column "owner_uuid";

alter table "app_public"."services" drop column "public";

alter table "app_public"."services" drop column "pull_url";

alter table "app_public"."services" drop column "repo_uuid";

alter table "app_public"."services" drop column "type";

-- moved services.tags.configuration to services.configuration before setting default to null
alter table "app_public"."services" add column "configuration" jsonb;
UPDATE "app_public"."services" SET "configuration" = "tags"."configuration" FROM "app_public"."service_tags" as "tags" WHERE "app_public"."services"."uuid" = "tags"."service_uuid";

alter table "app_public"."services" alter column "configuration" set not null;

drop table "app_public"."service_tags";


set check_function_bodies = off;

CREATE OR REPLACE FUNCTION app_private.create_owner_by_login(service app_public.sso_service, service_id text, username app_public.username, name text, email app_public.email, profile_image_url text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SET search_path TO 'app_public', 'app_hidden', 'app_private', 'app_runtime', 'public'
AS $function$
DECLARE _owner_uuid uuid DEFAULT NULL;
    DECLARE _token_uuid uuid DEFAULT NULL;
BEGIN
    IF profile_image_url IS NULL AND $1 = 'github' THEN
        profile_image_url = CONCAT('https://avatars.githubusercontent.com/u/', create_owner_by_login.service_id);
    END IF;

    -- TODO IF (service, username) conflict THEN need to truncate the other username
    -- TODO IF (service, service_id) conflict THEN need to update the username

    -- TODO IF we add a sso provider THEN check not only for sso_github_id
    SELECT uuid
    INTO _owner_uuid
    FROM owners o
    WHERE o.sso_github_id = create_owner_by_login.service_id
    LIMIT 1;

    IF _owner_uuid IS NOT NULL THEN

        -- select an existing login token
        -- TODO create new tokens based on the IP/source of login
        SELECT uuid into _token_uuid
        FROM tokens
        WHERE owner_uuid = _owner_uuid
          AND type = 'LOGIN'
        LIMIT 1;

    ELSE

        INSERT INTO owners (is_user, username, name, sso_github_id, profile_image_url)
        VALUES (TRUE, username, name, service_id, profile_image_url)
        RETURNING uuid into _owner_uuid;

        IF email IS NOT NULL THEN
            INSERT INTO owner_emails (owner_uuid, email, is_verified)
            VALUES (_owner_uuid, email, TRUE);
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
$function$
;

CREATE OR REPLACE FUNCTION app_public.apps_create_dns()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app_public', 'app_hidden', 'app_private', 'app_runtime', 'public'
AS $function$
  DECLARE dns hostname default null;
  BEGIN

    LOOP
      -- IF generate_awesome_word() generates a DNS entry that is already in use
      -- THEN try again until a unique DNS is generated
      INSERT INTO app_dns (hostname, app_uuid, is_validated)
        VALUES (generate_awesome_word()::hostname, new.uuid, true)
        ON CONFLICT (hostname) DO NOTHING
        RETURNING hostname into dns;

      IF dns IS NOT NULL THEN
        RETURN new;
      END IF;
    END LOOP;

  END;
$function$
;

CREATE OR REPLACE FUNCTION app_public.insert_organization_admin()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION app_public.search_services(search_terms text)
 RETURNS SETOF app_public.services
 LANGUAGE sql
 STABLE
 SET search_path TO 'app_public', 'app_hidden', 'app_private', 'app_runtime', 'public'
AS $function$
  SELECT
    services.*
  FROM
    services
  LEFT JOIN service_categories sc on services.category = sc.uuid
  WHERE
    services.tsvector @@ app_hidden.search_terms_to_tsquery('simple'::regconfig, search_terms)
    OR sc.title ILIKE concat('%', search_terms, '%')
    OR services.name ILIKE concat('%', search_terms, '%')
    OR description ILIKE concat('%', search_terms, '%')
  ORDER BY
    ts_rank(services.tsvector, app_hidden.search_terms_to_tsquery('simple', search_terms)) DESC,
    services.uuid DESC;
$function$
;

drop type "app_public"."billing_region";

drop type "app_public"."build_state";

drop type "app_public"."environment";

drop type "app_public"."service_repository";

drop type "app_public"."git_service";

drop type "app_public"."http_method";

drop type "app_public"."release_source";

drop type "app_public"."service_state";

drop type "app_public"."service_type";

CREATE POLICY "select_public" ON "app_public"."services" FOR SELECT USING (true);
GRANT SELECT ON services TO asyncy_visitor;

ALTER ROLE "asyncy_visitor" RENAME TO "visitor"; 

COMMIT;
