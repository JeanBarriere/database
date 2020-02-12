-- Revert storyscript:studio_specifications from pg

SET search_path TO :search_path;

BEGIN;

create type "app_public"."billing_region" as enum ('US', 'EU');

create type "app_public"."build_state" as enum ('QUEUED', 'BUILDING', 'SUCCESS', 'FAILURE', 'ERROR');

create type "app_public"."environment" as enum ('PRODUCTION', 'STAGING', 'DEV');

create type "app_public"."git_service" as enum ('github');

create type "app_public"."http_method" as enum ('POST', 'GET', 'PUT', 'DELETE');

create type "app_public"."release_source" as enum ('CONFIG_UPDATE', 'CODE_UPDATE', 'ROLLBACK');

create type "app_public"."service_state" as enum ('DEVELOPMENT', 'PRERELEASE', 'BETA', 'STABLE', 'ARCHIVED');

create type "app_public"."service_type" as enum ('container', 'openapi');

drop policy "select_public" on "app_public"."services";

drop function if exists "app_private"."create_owner_by_login"(service app_public.sso_service, service_id text, username app_public.username, name text, email app_public.email, profile_image_url text);

create table "app_hidden"."repos" (
    "uuid" uuid not null default uuid_generate_v4(),
    "owner_vcs_uuid" uuid not null,
    "service" app_public.git_service not null default 'github'::app_public.git_service,
    "service_id" citext not null,
    "name" citext not null,
    "using_github_installation" boolean not null default false
);
COMMENT on column app_hidden.repos.owner_vcs_uuid is 'The GitHub user/org that owns this repository.';
COMMENT on column app_hidden.repos.service is 'The repositorys service provider.';
COMMENT on column app_hidden.repos.service_id is 'The unique GitHub id of the repository.';
COMMENT on column app_hidden.repos.name is 'The repository slug name.';
COMMENT on column app_hidden.repos.using_github_installation is 'True: if the repository is using the GitHub App Integration';


create table "app_private"."build_numbers" (
    "repo_uuid" uuid not null,
    "build_number" integer not null default 1
);


create table "app_private"."owner_billing" (
    "owner_uuid" uuid not null,
    "region" app_public.billing_region not null default 'US'::app_public.billing_region,
    "customer" character varying(45) not null,
    "subscription" character varying(45),
    "email" app_public.email,
    "address" character varying(512),
    "vat" character varying(45)
);
COMMENT on column app_private.owner_billing.customer is 'Stripe customer ID.';
COMMENT on column app_private.owner_billing.subscription is 'Stripe subscriptions ID.';
COMMENT on column app_private.owner_billing.email is 'Where to send receipts to.';


create table "app_private"."owner_subscriptions" (
    "uuid" uuid not null default uuid_generate_v4(),
    "owner_uuid" uuid not null,
    "plan_uuid" uuid not null
);
COMMENT on table app_private.owner_subscriptions is 'An owner subscriptions to servies.';
COMMENT on column app_private.owner_subscriptions.owner_uuid is 'The owner of the subscription, for billing purposes.';
COMMENT on column app_private.owner_subscriptions.plan_uuid is 'Link to the plan subscribing too.';


create table "app_private"."owner_vcs_secrets" (
    "owner_vcs_uuid" uuid not null,
    "oauth_token" character varying(45)
);
COMMENT on column app_private.owner_vcs_secrets.oauth_token is 'Stored as an encrypted string';


create table "app_public"."builds" (
    "repo_uuid" uuid not null,
    "id" integer not null default 0,
    "timestamp" timestamp with time zone not null default now(),
    "sha" app_public.sha not null,
    "state" app_public.build_state not null
);
COMMENT on table builds is 'Building results from an Application.';
COMMENT on column builds.timestamp is 'Date the build started.';
COMMENT on column builds.sha is 'The commit id of the build being tested.';
COMMENT on column builds.state is 'The state of the build.';


create table "app_public"."external_service_metadata" (
    "service_uuid" uuid not null,
    "document_uri" text not null,
    "properties" jsonb not null,
    "last_seen_hash" text not null
);
COMMENT on column external_service_metadata.document_uri is 'The URI of the OpenAPI document';
COMMENT on column external_service_metadata.properties is 'The properties submitted at service creation, provided to the OMG converter alongside the document';
COMMENT on column external_service_metadata.last_seen_hash is 'The hash of the document when last converted (in either success or failure cases)';


create table "app_public"."marketing_sources" (
    "uuid" uuid not null default uuid_generate_v4(),
    "code" text not null
);
comment on table app_public.marketing_sources is
    'A table to help attribute marketing efforts (be able to attribute new users from conferences, events, workshops, etc).';


create table "app_public"."owner_containerconfigs" (
    "uuid" uuid not null default uuid_generate_v4(),
    "owner_uuid" uuid not null,
    "name" character varying(45) not null,
    "containerconfig" jsonb not null
);
COMMENT on column owner_containerconfigs.containerconfig is 'Container config containing the auth credentials';


create table "app_public"."owner_vcs" (
    "uuid" uuid not null default uuid_generate_v4(),
    "owner_uuid" uuid,
    "service" app_public.git_service not null default 'github'::app_public.git_service,
    "service_id" citext not null,
    "username" citext not null,
    "createstamp" timestamp with time zone not null default now(),
    "github_installation_id" integer
);
COMMENT on column app_public.owner_vcs.username is 'The handler name to the provider service';
COMMENT on column app_public.owner_vcs.owner_uuid is 'A user can attach a vcs to their profile, this is for users-only, not organizations.';
COMMENT on column app_public.owner_vcs.service is 'GitHub or another provider';
COMMENT on column app_public.owner_vcs.service_id is 'The providers unique id';
COMMENT on column app_public.owner_vcs.github_installation_id is 'The installation id to the GitHub App';



create table "app_public"."service_plans" (
    "uuid" uuid not null default uuid_generate_v4(),
    "service_uuid" uuid not null,
    "title" app_public.title not null,
    "details" jsonb
);
COMMENT on table service_plans is 'Premium service plans.';
COMMENT on column service_plans.service_uuid is 'The service that owns this plan.';
COMMENT on column service_plans.title is 'A short name for the plan.';
COMMENT on column service_plans.details is 'Sales pitch content.';


create table "app_public"."service_tags" (
    "service_uuid" uuid not null,
    "tag" citext not null,
    "state" app_public.service_state not null,
    "configuration" jsonb not null,
    "readme" text,
    "updated_at" timestamp without time zone not null default now(),
    "uuid" uuid not null default uuid_generate_v4()
);
COMMENT on column service_tags.tag is 'The verion identifier. E.g., latest or v1.2';
COMMENT on column service_tags.configuration is 'The post processing of the microservice.yml file.';
COMMENT on column service_tags.readme is 'The readme content (first generated by the repository README).';


create table "app_public"."service_usage" (
    "memory_bytes" double precision[] not null default array_fill('-1.0'::numeric, ARRAY[25]),
    "cpu_units" double precision[] not null default array_fill('-1.0'::numeric, ARRAY[25]),
    "next_index" integer not null default 1,
    "service_tag_uuid" uuid not null
);
COMMENT on table service_usage is 'Resource usage metrics for services';
COMMENT on column service_usage.memory_bytes is 'Circular queue storing memory bytes consumed';
COMMENT on column service_usage.cpu_units is 'Circular queue storing cpu units consumed';
COMMENT on column service_usage.next_index is 'Next index to be updated in the circular queues';
COMMENT on column service_usage.service_tag_uuid is 'The (service_uuid, image_tag) identifier';


create table "app_runtime"."subscriptions" (
    "uuid" uuid not null,
    "app_uuid" uuid not null,
    "url" text not null,
    "method" app_public.http_method not null,
    "payload" jsonb not null,
    "k8s_container_id" text not null,
    "k8s_pod_name" text not null
);


DELETE FROM pg_enum
WHERE enumlabel = 'DRAFT'
AND enumtypid = (
  SELECT oid FROM pg_type WHERE typname = 'release_state'
);


-- -- alter type
-- alter type "app_public"."release_state" rename to "release_state_old";

-- -- create new one
-- create type "app_public"."release_state" as enum ('QUEUED', 'DEPLOYING', 'DEPLOYED', 'TERMINATING', 'TERMINATED', 'NO_DEPLOY', 'FAILED', 'SKIPPED_CONCURRENT', 'TIMED_OUT', 'TEMP_DEPLOYMENT_FAILURE');

-- -- update tables in use
-- UPDATE "app_public"."releases" SET "state" = 'QUEUED' WHERE "state" = 'DRAFT';

-- alter table "app_public"."releases" alter column "state" DROP DEFAULT;
-- alter table "app_public"."releases" alter column "state" type "app_public"."release_state" using "state"::text::"app_public"."release_state";
-- alter table "app_public"."releases" alter column "state" set default "QUEUED"::"app_public"."release_state";

-- -- remove old type
-- drop type "app_public"."release_state_old"

CREATE TABLE apps_new(
                     uuid                    uuid default uuid_generate_v4() primary key,
                     owner_uuid              uuid references owners on delete cascade not null default current_owner_uuid(),
                     repo_uuid               uuid,
                     name                    title not null,
                     timestamp               timestamptz not null default now(),
                     maintenance             boolean default false not null,
                     deleted                 boolean default false not null,
                     environment             environment not null default 'PRODUCTION'::environment,
                     UNIQUE (owner_uuid, name)
);

insert into apps_new select uuid, owner_uuid, null, name, timestamp, deleted from apps;

drop table apps cascade;

alter table apps_new rename to apps;

alter table apps rename constraint "apps_new_owner_uuid_fkey" to "apps_owner_uuid_fkey";

-- alter table "app_public"."apps" add column "environment" app_public.environment not null default 'PRODUCTION'::app_public.environment;

-- alter table "app_public"."apps" add column "maintenance" boolean not null default false;

-- alter table "app_public"."apps" add column "repo_uuid" uuid;

COMMENT on column apps.repo_uuid is 'The Repository linked to this application.';

alter table "app_public"."owners" drop column "sso_github_id";

alter table "app_public"."owners" add column "marketing_source_uuid" uuid;

alter table "app_public"."releases" add column "always_pull_images" boolean not null default false;

alter table "app_public"."releases" add column "config" jsonb;
COMMENT on column releases.config is 'Configuration of the release.';

alter table "app_public"."releases" add column "message" text not null default 'released';
COMMENT on column releases.message is 'User defined release message.';

alter table "app_public"."releases" add column "payload" jsonb default '{"__default__": "true"}'::jsonb;
COMMENT on column releases.payload is 'An object containing the full payload of Storyscripts, e.g., {"foobar": {"1": ...}}';

alter table "app_public"."releases" add column "source" app_public.release_source not null default 'CODE_UPDATE'::app_public.release_source;

alter table "app_public"."services" drop column "configuration";

alter table "app_public"."services" add column "alias" app_public.alias;
COMMENT on column services.alias is 'The namespace reservation for the service';

alter table "app_public"."services" add column "is_certified" boolean not null default false;

alter table "app_public"."services" add column "links" jsonb;
COMMENT on column services.links is 'Custom links';

alter table "app_public"."services" add column "owner_uuid" uuid;

alter table "app_public"."services" add column "public" boolean not null default false;
COMMENT on column services.public is 'If the service is publicly available';

alter table "app_public"."services" add column "pull_url" text;
COMMENT on column services.pull_url is 'Address where the container can be pulled from.';

alter table "app_public"."services" add column "repo_uuid" uuid;

alter table "app_public"."services" add column "type" app_public.service_type not null default 'container'::app_public.service_type;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION app_private.create_owner_by_login(service app_public.git_service, service_id text, username app_public.username, name text, email app_public.email, oauth_token text, profile_image_url text DEFAULT NULL::text, marketing_source_uuid uuid DEFAULT NULL::uuid)
 RETURNS json
 LANGUAGE plpgsql
 SET search_path TO 'app_public', 'app_hidden', 'app_private', 'app_runtime', 'public'
AS $function$
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
$function$
;
COMMENT ON FUNCTION app_private.create_owner_by_login(app_public.git_service, text, username, text, email, text, text, uuid) IS 'Create new users upon logging in.';

CREATE OR REPLACE FUNCTION app_public.app_updated_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app_public', 'app_hidden', 'app_private', 'app_runtime', 'public'
AS $function$
  begin
    perform pg_notify('release', cast(old.uuid as text));
    return null;
  end;
$function$
;

CREATE OR REPLACE FUNCTION app_public.builds_next_id()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app_public', 'app_hidden', 'app_private', 'app_runtime', 'public'
AS $function$
  declare
    v_next_value int;
  begin
    -- TODO: this statement should be committed immediately in a separate
    -- transaction so that it behaves more like PostgreSQL sequences to avoid
    -- race conditions.
    -- Relevant: http://blog.dalibo.com/2016/08/19/Autonoumous_transactions_support_in_PostgreSQL.html
    insert into app_private.build_numbers (repo_uuid) values (NEW.repo_uuid) on conflict (repo_uuid) do update set build_number = build_number + 1 returning build_number into v_next_value;
    new.id := v_next_value;
    return new;
  end;
$function$
;

CREATE OR REPLACE FUNCTION app_public.convert_to_hostname(name app_public.title)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'app_public', 'app_hidden', 'app_private', 'app_runtime', 'public'
AS $function$
SELECT substring(
           regexp_replace(
               trim(
                   both '-_' from
                   lower(name)
                 ),
               '[^\w\-\_]', '', 'gi'
             )
           from 1 for 256
         );
$function$
;
CREATE TYPE app_public.service_repository AS (
    service     app_public.git_service,
    owner_name  citext,
    repo_name   citext
    );

CREATE OR REPLACE FUNCTION app_public.get_service_repository(service_uuid uuid)
 RETURNS app_public.service_repository
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'app_public', 'app_hidden', 'app_private', 'app_runtime', 'public'
AS $function$
  SELECT o.service AS service, o.username AS owner_name, r.name AS repo_name
  FROM app_public.services s
  INNER JOIN app_hidden.repos r ON (r.uuid = s.repo_uuid)
  INNER JOIN app_public.owner_vcs o ON (o.uuid = r.owner_vcs_uuid)
  WHERE s.uuid = service_uuid AND (s.public OR s.owner_uuid = current_owner_uuid())
  LIMIT 1
$function$
;
COMMENT ON FUNCTION app_public.get_service_repository(uuid) IS E'Return the repository information for a single service.';

CREATE OR REPLACE FUNCTION app_public.owner_username_conflict()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION app_public.owner_vcs_check_conflicting_username()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app_public', 'app_hidden', 'app_private', 'app_runtime', 'public'
AS $function$
begin
  if exists (
      select 1 from owner_vcs
      where service = new.service
        and username = new.username) then
    -- There is an old username associated with this username.
    -- This would typically happen when somebody changes their username on the service,
    -- and that old username is taken up by somebody new.
    update owner_vcs
    set username = null
    where service = new.service and username = new.username;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION app_public.releases_defaults()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app_public', 'app_hidden', 'app_private', 'app_runtime', 'public'
AS $function$
begin
  -- set payload and config to the previous release when empty
  if new.payload is null or new.payload->>'__default__' = 'true' then
    new.payload := (select payload from releases where app_uuid=new.app_uuid and id=new.id-1 limit 1);
  end if;
  if new.config is null then
    new.config := (select config from releases where app_uuid=new.app_uuid and id=new.id-1 limit 1);
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION app_public.service_by_alias_or_name(service_name citext)
 RETURNS app_public.services
 LANGUAGE sql
 STABLE
 SET search_path TO 'app_public', 'app_hidden', 'app_private', 'app_runtime', 'public'
AS $function$
SELECT
    services.*
FROM
    services
        INNER JOIN owners on services.owner_uuid = owners.uuid
WHERE
        services.alias ILIKE service_name
   OR (position('/' in service_name)::boolean AND owners.username ILIKE split_part(service_name, '/', 1) AND services.name ILIKE split_part(service_name, '/', 2))
LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION app_public.update_ts_in_service_tags()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'app_public', 'app_hidden', 'app_private', 'app_runtime', 'public'
AS $function$
begin
    NEW.updated_at = now();
    return NEW;
end;
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

    BEGIN
      INSERT INTO app_dns (hostname, app_uuid, is_validated)
        VALUES (convert_to_hostname(new.name), new.uuid, true)
        ON CONFLICT (hostname) DO NOTHING
        RETURNING hostname into dns;

      IF dns IS NOT NULL THEN
        RETURN new;
      END IF;
    EXCEPTION WHEN check_violation THEN
      -- Do nothing
    END;

    LOOP
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

  INSERT INTO team_members (team_uuid, owner_uuid)
  VALUES (_team_uuid, current_owner_uuid());

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
  INNER JOIN owners on services.owner_uuid = owners.uuid
  WHERE
    services.tsvector @@ app_hidden.search_terms_to_tsquery('simple', search_terms)
    OR sc.title ILIKE concat('%', search_terms, '%')
    OR services.name ILIKE concat('%', search_terms, '%')
    OR owners.name ILIKE concat('%', search_terms, '%')
    OR owners.username ILIKE concat('%', search_terms, '%')
    OR description ILIKE concat('%', search_terms, '%')
  ORDER BY
    ts_rank(services.tsvector, app_hidden.search_terms_to_tsquery('simple', search_terms)) DESC,
    services.uuid DESC;
$function$
;

drop type "app_public"."sso_service";

CREATE UNIQUE INDEX repos_pkey ON app_hidden.repos USING btree (uuid);

CREATE UNIQUE INDEX repos_service_id_key ON app_hidden.repos USING btree (service_id);

CREATE UNIQUE INDEX repos_service_ids ON app_hidden.repos USING btree (service, service_id);
COMMENT on index repos_service_ids is 'A repository service id is unique per Service.';

CREATE UNIQUE INDEX repos_slug ON app_hidden.repos USING btree (owner_vcs_uuid, name);
COMMENT on index repos_slug is 'A repository name is unique per GitHub Organization.';

CREATE UNIQUE INDEX build_numbers_pkey ON app_private.build_numbers USING btree (repo_uuid);

CREATE UNIQUE INDEX owner_billing_pkey ON app_private.owner_billing USING btree (owner_uuid);

CREATE INDEX owner_subscriptions_owner_uuid_fk ON app_private.owner_subscriptions USING btree (owner_uuid);

CREATE UNIQUE INDEX owner_subscriptions_pkey ON app_private.owner_subscriptions USING btree (uuid);

CREATE INDEX owner_subscriptions_plan_uuid_fk ON app_private.owner_subscriptions USING btree (plan_uuid);

CREATE UNIQUE INDEX owner_vcs_secrets_pkey ON app_private.owner_vcs_secrets USING btree (owner_vcs_uuid);

CREATE INDEX apps_repo_uuid_fk ON app_public.apps USING btree (repo_uuid);

CREATE UNIQUE INDEX builds_pkey ON app_public.builds USING btree (repo_uuid, id);

CREATE UNIQUE INDEX external_service_metadata_pkey ON app_public.external_service_metadata USING btree (service_uuid);

CREATE UNIQUE INDEX marketing_sources_code_key ON app_public.marketing_sources USING btree (code);

CREATE UNIQUE INDEX marketing_sources_pkey ON app_public.marketing_sources USING btree (uuid);

CREATE UNIQUE INDEX owner_containerconfigs_owner_uuid_name_key ON app_public.owner_containerconfigs USING btree (owner_uuid, name);

CREATE UNIQUE INDEX owner_containerconfigs_pkey ON app_public.owner_containerconfigs USING btree (uuid);

CREATE UNIQUE INDEX owner_vcs_ids ON app_public.owner_vcs USING btree (service, service_id);
COMMENT on index owner_vcs_ids is 'Can only have one service:service_id pair.';

CREATE UNIQUE INDEX owner_vcs_pkey ON app_public.owner_vcs USING btree (uuid);

CREATE INDEX owner_vcs_username ON app_public.owner_vcs USING btree (service, username);
COMMENT on index owner_vcs_username is 'Can only have one service:username pair.';

CREATE UNIQUE INDEX service_plans_pkey ON app_public.service_plans USING btree (uuid);

CREATE INDEX service_plans_service_uuid_fk ON app_public.service_plans USING btree (service_uuid);

CREATE UNIQUE INDEX service_tags_pkey ON app_public.service_tags USING btree (uuid);

CREATE UNIQUE INDEX service_tags_unique ON app_public.service_tags USING btree (service_uuid, tag);

CREATE UNIQUE INDEX service_usage_pkey ON app_public.service_usage USING btree (service_tag_uuid);

CREATE UNIQUE INDEX services_alias_key ON app_public.services USING btree (alias);

CREATE UNIQUE INDEX services_names ON app_public.services USING btree (owner_uuid, name);

CREATE INDEX services_owners_uuid_fk ON app_public.services USING btree (owner_uuid);

CREATE UNIQUE INDEX services_repo_uuid_fk ON app_public.services USING btree (repo_uuid);

CREATE UNIQUE INDEX subscriptions_pkey ON app_runtime.subscriptions USING btree (uuid);

alter table "app_hidden"."repos" add constraint "repos_pkey" PRIMARY KEY using index "repos_pkey";

alter table "app_private"."build_numbers" add constraint "build_numbers_pkey" PRIMARY KEY using index "build_numbers_pkey";

alter table "app_private"."owner_billing" add constraint "owner_billing_pkey" PRIMARY KEY using index "owner_billing_pkey";

alter table "app_private"."owner_subscriptions" add constraint "owner_subscriptions_pkey" PRIMARY KEY using index "owner_subscriptions_pkey";

alter table "app_private"."owner_vcs_secrets" add constraint "owner_vcs_secrets_pkey" PRIMARY KEY using index "owner_vcs_secrets_pkey";

alter table "app_public"."builds" add constraint "builds_pkey" PRIMARY KEY using index "builds_pkey";

alter table "app_public"."external_service_metadata" add constraint "external_service_metadata_pkey" PRIMARY KEY using index "external_service_metadata_pkey";

alter table "app_public"."marketing_sources" add constraint "marketing_sources_pkey" PRIMARY KEY using index "marketing_sources_pkey";

alter table "app_public"."owner_containerconfigs" add constraint "owner_containerconfigs_pkey" PRIMARY KEY using index "owner_containerconfigs_pkey";

alter table "app_public"."owner_vcs" add constraint "owner_vcs_pkey" PRIMARY KEY using index "owner_vcs_pkey";

alter table "app_public"."service_plans" add constraint "service_plans_pkey" PRIMARY KEY using index "service_plans_pkey";

alter table "app_public"."service_tags" add constraint "service_tags_pkey" PRIMARY KEY using index "service_tags_pkey";

alter table "app_public"."service_usage" add constraint "service_usage_pkey" PRIMARY KEY using index "service_usage_pkey";

alter table "app_runtime"."subscriptions" add constraint "subscriptions_pkey" PRIMARY KEY using index "subscriptions_pkey";

alter table "app_hidden"."repos" add constraint "repos_owner_vcs_uuid_fkey" FOREIGN KEY (owner_vcs_uuid) REFERENCES app_public.owner_vcs(uuid) ON DELETE CASCADE;

alter table "app_hidden"."repos" add constraint "repos_service_id_check" CHECK ((length((service_id)::text) < 45));

alter table "app_hidden"."repos" add constraint "repos_service_id_key" UNIQUE using index "repos_service_id_key";

alter table "app_private"."build_numbers" add constraint "build_numbers_repo_uuid_fkey" FOREIGN KEY (repo_uuid) REFERENCES app_hidden.repos(uuid) ON DELETE CASCADE;

alter table "app_private"."owner_billing" add constraint "owner_billing_customer_check" CHECK (((customer)::text ~ '^cust_\w+$'::text));

alter table "app_private"."owner_billing" add constraint "owner_billing_customer_check1" CHECK (((customer)::text ~ '^sub_\w+$'::text));

alter table "app_private"."owner_billing" add constraint "owner_billing_owner_uuid_fkey" FOREIGN KEY (owner_uuid) REFERENCES app_public.owners(uuid) ON DELETE CASCADE;

alter table "app_private"."owner_subscriptions" add constraint "fk_plan_uuid" FOREIGN KEY (plan_uuid) REFERENCES app_public.service_plans(uuid) ON DELETE RESTRICT;

alter table "app_private"."owner_subscriptions" add constraint "owner_subscriptions_owner_uuid_fkey" FOREIGN KEY (owner_uuid) REFERENCES app_public.owners(uuid) ON DELETE CASCADE;

alter table "app_private"."owner_vcs_secrets" add constraint "owner_vcs_secrets_owner_vcs_uuid_fkey" FOREIGN KEY (owner_vcs_uuid) REFERENCES app_public.owner_vcs(uuid) ON DELETE CASCADE;

alter table "app_public"."apps" add constraint "apps_repo_uuid_fkey" FOREIGN KEY (repo_uuid) REFERENCES app_hidden.repos(uuid) ON DELETE CASCADE;

alter table "app_public"."builds" add constraint "builds_id_check" CHECK ((id > 0));

alter table "app_public"."builds" add constraint "builds_repo_uuid_fkey" FOREIGN KEY (repo_uuid) REFERENCES app_hidden.repos(uuid) ON DELETE CASCADE;

alter table "app_public"."external_service_metadata" add constraint "external_service_metadata_service_uuid_fkey" FOREIGN KEY (service_uuid) REFERENCES app_public.services(uuid) ON DELETE CASCADE;

alter table "app_public"."marketing_sources" add constraint "marketing_sources_code_key" UNIQUE using index "marketing_sources_code_key";

alter table "app_public"."owner_containerconfigs" add constraint "owner_containerconfigs_owner_uuid_fkey" FOREIGN KEY (owner_uuid) REFERENCES app_public.owners(uuid) ON DELETE CASCADE;

alter table "app_public"."owner_containerconfigs" add constraint "owner_containerconfigs_owner_uuid_name_key" UNIQUE using index "owner_containerconfigs_owner_uuid_name_key";

alter table "app_public"."owner_vcs" add constraint "owner_vcs_owner_uuid_fkey" FOREIGN KEY (owner_uuid) REFERENCES app_public.owners(uuid) ON DELETE SET NULL;

alter table "app_public"."owners" add constraint "owners_marketing_source_uuid_fkey" FOREIGN KEY (marketing_source_uuid) REFERENCES app_public.marketing_sources(uuid) ON DELETE SET NULL;

alter table "app_public"."releases" add constraint "releases_message_check" CHECK ((length(message) < 1000));

alter table "app_public"."service_plans" add constraint "service_plans_service_uuid_fkey" FOREIGN KEY (service_uuid) REFERENCES app_public.services(uuid) ON DELETE CASCADE;

alter table "app_public"."service_tags" add constraint "service_tags_service_uuid_fkey" FOREIGN KEY (service_uuid) REFERENCES app_public.services(uuid) ON DELETE CASCADE;

alter table "app_public"."service_tags" add constraint "service_tags_unique" UNIQUE using index "service_tags_unique";

alter table "app_public"."service_usage" add constraint "service_usage_cpu_units_check" CHECK ((cardinality(cpu_units) = 25));

alter table "app_public"."service_usage" add constraint "service_usage_memory_bytes_check" CHECK ((cardinality(memory_bytes) = 25));

alter table "app_public"."service_usage" add constraint "service_usage_next_index_check" CHECK (((next_index >= 1) AND (next_index <= 25)));

alter table "app_public"."service_usage" add constraint "service_usage_service_tag_uuid_fkey" FOREIGN KEY (service_tag_uuid) REFERENCES app_public.service_tags(uuid) ON DELETE CASCADE;

alter table "app_public"."services" add constraint "services_alias_key" UNIQUE using index "services_alias_key";

alter table "app_public"."services" add constraint "services_owner_uuid_fkey" FOREIGN KEY (owner_uuid) REFERENCES app_public.owners(uuid) ON DELETE CASCADE;

alter table "app_public"."services" add constraint "services_repo_uuid_fkey" FOREIGN KEY (repo_uuid) REFERENCES app_hidden.repos(uuid) ON DELETE CASCADE;

alter table "app_runtime"."subscriptions" add constraint "subscriptions_app_uuid_fkey" FOREIGN KEY (app_uuid) REFERENCES app_public.apps(uuid) ON DELETE CASCADE;

create policy "select_member"
on "app_private"."owner_billing"
for select
using (owner_uuid = ANY (app_hidden.current_owner_organization_uuids(ARRAY['BILLING'::text])));
grant select on "app_private"."owner_billing" to visitor;
ALTER TABLE app_private.owner_billing ENABLE ROW LEVEL SECURITY;

ALTER TABLE app_public.builds ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.marketing_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.owner_containerconfigs ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.owner_vcs ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.service_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.service_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.service_usage ENABLE ROW LEVEL SECURITY;


GRANT UPDATE (marketing_source_uuid) ON owners TO visitor;

create policy "select_billing"
on "app_private"."owner_subscriptions"
for select
using (owner_uuid = ANY (app_hidden.current_owner_organization_uuids(ARRAY['BILLING'::text])));
grant select on "app_private"."owner_subscriptions" to visitor;
ALTER TABLE app_private.owner_subscriptions ENABLE ROW LEVEL SECURITY;

create policy "select_repo_visible"
on "app_public"."builds"
for select
using (EXISTS ( SELECT 1
   FROM app_hidden.repos
  WHERE (repos.uuid = builds.repo_uuid)));
grant select on "app_public"."builds" to visitor;

create policy "select_own"
on "app_public"."marketing_sources"
for select
using (EXISTS ( SELECT 1
   FROM app_public.owners
  WHERE ((owners.uuid = app_hidden.current_owner_uuid()) AND (owners.marketing_source_uuid = marketing_sources.uuid))));
grant select on "app_public"."marketing_sources" to visitor;

create policy "delete_organization"
on "app_public"."owner_containerconfigs"
for delete
using (app_hidden.current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'::text));

create policy "delete_own"
on "app_public"."owner_containerconfigs"
for delete
using (owner_uuid = app_hidden.current_owner_uuid());
grant delete on "app_public"."owner_containerconfigs" to visitor;

create policy "insert_organization"
on "app_public"."owner_containerconfigs"
for insert
with check (app_hidden.current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'::text));

create policy "insert_own"
on "app_public"."owner_containerconfigs"
for insert
with check (owner_uuid = app_hidden.current_owner_uuid());
grant insert on "app_public"."owner_containerconfigs" to visitor;

GRANT INSERT (config, message, payload, always_pull_images) ON releases TO visitor;

create policy "select_organization"
on "app_public"."owner_containerconfigs"
for select
using (app_hidden.current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'::text));
grant select on "app_public"."owner_containerconfigs" to visitor;

create policy "select_own"
on "app_public"."owner_containerconfigs"
for select
using (owner_uuid = app_hidden.current_owner_uuid());
grant select on "app_public"."owner_containerconfigs" to visitor;

create policy "update_organization"
on "app_public"."owner_containerconfigs"
for update
using (app_hidden.current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'::text));

create policy "update_own"
on "app_public"."owner_containerconfigs"
for update
using (owner_uuid = app_hidden.current_owner_uuid());
grant update on "app_public"."owner_containerconfigs" to visitor;


create policy "select_own"
on "app_public"."owner_vcs"
for select
using (owner_uuid = app_hidden.current_owner_uuid());
grant select on "app_public"."owner_vcs" to visitor;

create policy "update_own_marketing_source"
on "app_public"."owners"
for update
using (uuid = app_hidden.current_owner_uuid());

create policy "select_all"
on "app_public"."service_plans"
for select
using (true);
grant select on "app_public"."service_plans" to visitor;

create policy "select_tag"
on "app_public"."service_tags"
for select
using (EXISTS ( SELECT 1
   FROM app_public.services
  WHERE (services.uuid = service_tags.service_uuid)));
grant select on "app_public"."service_tags" to visitor;

create policy "select_public_or_own"
on "app_public"."service_usage"
for select
using (EXISTS ( SELECT 1
   FROM (app_public.service_tags
     JOIN app_public.services ON ((services.uuid = service_tags.service_uuid)))
  WHERE ((service_tags.uuid = service_usage.service_tag_uuid) AND (services.public OR (services.owner_uuid = app_hidden.current_owner_uuid())))));
grant select on "app_public"."service_usage" to visitor;

create policy "select_organization"
on "app_public"."services"
for select
using (owner_uuid = ANY (app_hidden.current_owner_organization_uuids()));
grant select on "app_public"."services" to visitor;

create policy "select_own"
on "app_public"."services"
for select
using (owner_uuid = app_hidden.current_owner_uuid());
grant select on "app_public"."services" to visitor;

create policy "select_public"
on "app_public"."services"
for select
using (public);
grant select on "app_public"."services" to visitor;

CREATE TRIGGER _100_app_updated_notify AFTER UPDATE ON app_public.apps FOR EACH ROW WHEN (((old.maintenance IS DISTINCT FROM new.maintenance) OR (new.deleted = true))) EXECUTE PROCEDURE app_public.app_updated_notify();

CREATE TRIGGER _100_builds_next_id_insert BEFORE INSERT ON app_public.builds FOR EACH ROW EXECUTE PROCEDURE app_public.builds_next_id();

CREATE TRIGGER _050_owner_vcs_check_conflicting_username BEFORE INSERT ON app_public.owner_vcs FOR EACH ROW EXECUTE PROCEDURE app_public.owner_vcs_check_conflicting_username();

CREATE TRIGGER _100_insert_owner_username_conflict BEFORE INSERT ON app_public.owners FOR EACH ROW EXECUTE PROCEDURE app_public.owner_username_conflict();

CREATE TRIGGER _101_releases_defaults BEFORE INSERT ON app_public.releases FOR EACH ROW EXECUTE PROCEDURE app_public.releases_defaults();

CREATE TRIGGER _100_update_ts_in_service_tags BEFORE UPDATE ON app_public.service_tags FOR EACH ROW EXECUTE PROCEDURE app_public.update_ts_in_service_tags();

ALTER ROLE "visitor" RENAME TO "asyncy_visitor"; 

COMMIT;
