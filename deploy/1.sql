-- Deploy storyscript:1 to pg

BEGIN;

CREATE EXTENSION "pgcrypto" WITH SCHEMA public;
CREATE EXTENSION "uuid-ossp" WITH SCHEMA public;
CREATE EXTENSION "citext" WITH SCHEMA public;
CREATE SCHEMA app_public;
CREATE SCHEMA app_hidden;
CREATE SCHEMA app_private;
CREATE SCHEMA app_runtime;
SET search_path to app_public, app_hidden, app_private, app_runtime, public;
DO $$
    BEGIN
        IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'asyncy_authenticator') THEN
            CREATE ROLE asyncy_authenticator WITH LOGIN PASSWORD 'PLEASE_CHANGE_ME' NOINHERIT;
        END IF;
        IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'asyncy_visitor') THEN
            CREATE ROLE asyncy_visitor;
        END IF;
    END;
$$ LANGUAGE plpgsql;
GRANT asyncy_visitor to asyncy_authenticator;
DO $$
    BEGIN
        EXECUTE FORMAT('GRANT CONNECT ON DATABASE %I TO asyncy_authenticator', current_database());
    END;
$$;
GRANT CONNECT ON DATABASE postgres TO asyncy_authenticator;
GRANT USAGE ON SCHEMA app_public TO asyncy_visitor;
GRANT USAGE ON SCHEMA app_hidden TO asyncy_visitor;
CREATE TABLE app_private.version (
    version             text CHECK (version ~ '^\d+\.\d+\.\d+$') primary key
);
INSERT INTO app_private.version values ('0.0.1');
CREATE TYPE git_service as enum('github');
CREATE DOMAIN title as citext
    CHECK ( LENGTH(VALUE) < 46 AND VALUE ~ '^[\w\-\.\s]+$' );
CREATE DOMAIN username as citext
    CHECK (LENGTH(VALUE) <= 45 AND LENGTH(VALUE) >= 2 AND VALUE ~ '^\w([\.\-]?\w)*$' );
CREATE DOMAIN hostname as text
    CHECK ( LENGTH(VALUE) > 3 AND LENGTH(VALUE) < 255 AND VALUE ~ '^((\*|[a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$' );
CREATE DOMAIN email AS citext
    CHECK ( LENGTH(VALUE) >= 5 AND LENGTH(VALUE) <= 512 AND VALUE ~ '^[^@]+@[^@]+\.[^@]+$' );
CREATE DOMAIN sha as citext
    CHECK ( LENGTH(VALUE) = 40 AND VALUE ~ '^\w+$' );
CREATE DOMAIN alias as citext
    CHECK ( LENGTH(VALUE) > 1 AND LENGTH(VALUE) < 25 AND VALUE ~ '^[\w\-\.]+$' );
CREATE DOMAIN url as citext
    CHECK ( LENGTH(VALUE) <= 4096 and VALUE ~ '^https?://');
CREATE TYPE billing_region as enum('US', 'EU');
CREATE TYPE build_state as enum('QUEUED', 'BUILDING', 'SUCCESS', 'FAILURE', 'ERROR');
CREATE TYPE release_state as enum('QUEUED', 'DEPLOYING', 'DEPLOYED', 'TERMINATING', 'TERMINATED', 'NO_DEPLOY', 'FAILED', 'SKIPPED_CONCURRENT', 'TIMED_OUT', 'TEMP_DEPLOYMENT_FAILURE');
CREATE TYPE release_source as enum('CONFIG_UPDATE', 'CODE_UPDATE', 'ROLLBACK');
CREATE TYPE token_type as enum('API', 'LOGIN', 'APP');
CREATE TYPE category_type as enum('SERVICE', 'FUNCTION');
CREATE TYPE environment as enum('PRODUCTION', 'STAGING', 'DEV');
CREATE TYPE http_method as enum('POST', 'GET', 'PUT', 'DELETE');
CREATE TYPE service_type as enum('container', 'openapi');
CREATE FUNCTION app_hidden.current_owner_uuid() RETURNS uuid AS $$
  SELECT nullif(current_setting('jwt.claims.owner_uuid', true), '')::uuid;
$$ LANGUAGE sql STABLE SET search_path FROM CURRENT;
CREATE FUNCTION abort_with_errorcode() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'ERROR %: %', TG_ARGV[0], TG_ARGV[1] USING errcode = TG_ARGV[0];
END;
$$ LANGUAGE plpgsql;
CREATE TABLE permissions(
                            slug                       text not null check (slug ~ '^[A-Z_]+$') primary key,
                            title                      title not null
);
COMMENT on column permissions.title is 'Short description of the permission.';
INSERT INTO permissions (slug, title) VALUES
('ADMIN', 'Organization administrator'),
('BILLING', 'Billing'),
('CREATE_APP', 'Create application'),
('CREATE_RELEASE', 'Create release');
CREATE FUNCTION assert_permissions_exist() returns trigger as $$
begin
  if array_ndims(NEW.permissions) > 1 then
    raise exception 'Invalid permissions, expected one-dimensional array' using errcode = 'SECPD';
  end if;
  if exists(
    select 1
    from unnest(NEW.permissions) pslug
    left join permissions on (pslug = permissions.slug)
    where permissions.slug is null
  ) then
    raise exception 'Invalid permissions, permission unrecognised' using errcode = 'SECPX';
  end if;
 return new;
end;
$$ language plpgsql SET search_path FROM CURRENT;
create table app_public.marketing_sources
(
    uuid uuid default uuid_generate_v4() not null primary key,
    code text                            not null unique
);
comment on table app_public.marketing_sources is
    'A table to help attribute marketing efforts (be able to attribute new users from conferences, events, workshops, etc).';
CREATE TABLE owners(
                       uuid                    uuid default uuid_generate_v4() primary key,
                       is_user                 boolean not null default true,
                       username                username not null,
                       createstamp             timestamptz not null default now(),
                       name                    citext,
                       profile_image_url       citext default null,
                       marketing_source_uuid   uuid references marketing_sources on delete set null
);
COMMENT on column owners.username is 'Unique namespace for navigation and discovery.';
COMMENT on column owners.name is 'A pretty organization name, UI visual only.';
CREATE UNIQUE INDEX owner_username on owners (username);
CREATE TABLE owner_vcs (
                           uuid                    uuid default uuid_generate_v4() primary key,
                           owner_uuid              uuid references owners on delete set null,
                           service                 git_service not null default 'github'::git_service,
                           service_id              citext not null,
                           username                citext not null,
                           createstamp             timestamptz not null default now(),
                           github_installation_id  int default null
);
COMMENT on column owner_vcs.username is 'The handler name to the provider service';
COMMENT on column owner_vcs.owner_uuid is 'A user can attach a vcs to their profile, this is for users-only, not organizations.';
COMMENT on column owner_vcs.service is 'GitHub or another provider';
COMMENT on column owner_vcs.service_id is 'The providers unique id';
COMMENT on column owner_vcs.github_installation_id is 'The installation id to the GitHub App';
CREATE INDEX owner_vcs_username on owner_vcs (service, username);
CREATE UNIQUE INDEX owner_vcs_ids on owner_vcs (service, service_id);
COMMENT on index owner_vcs_username is 'Can only have one service:username pair.';
COMMENT on index owner_vcs_ids is 'Can only have one service:service_id pair.';
CREATE FUNCTION owner_vcs_check_conflicting_username() returns trigger as $$
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
$$ language plpgsql security definer SET search_path FROM CURRENT;
CREATE TRIGGER _050_owner_vcs_check_conflicting_username before insert on owner_vcs
    for each row execute procedure owner_vcs_check_conflicting_username();
CREATE TABLE owner_emails (
                              uuid                    uuid default uuid_generate_v4() primary key,
                              owner_uuid              uuid not null references owners on delete cascade,
                              email                   email not null,
                              is_verified             boolean not null default false
);
CREATE UNIQUE INDEX ON owner_emails(owner_uuid, email);
CREATE TABLE owner_containerconfigs (
                                        uuid                    uuid default uuid_generate_v4() primary key,
                                        owner_uuid              uuid not null references owners on delete cascade,
                                        name                    varchar(45) not null,
                                        containerconfig         jsonb not null,
                                        UNIQUE (owner_uuid, name)
);
COMMENT on column owner_containerconfigs.containerconfig is 'Container config containing the auth credentials';
CREATE TABLE app_private.owner_vcs_secrets (
                                               owner_vcs_uuid      uuid primary key references owner_vcs on delete cascade,
                                               oauth_token             varchar(45)
);
COMMENT on column app_private.owner_vcs_secrets.oauth_token is 'Stored as an encrypted string';
CREATE TABLE app_private.owner_billing(
                                          owner_uuid              uuid primary key references owners on delete cascade,
                                          region                  billing_region not null default 'US'::billing_region,
                                          customer                varchar(45) CHECK (customer ~ '^cust_\w+$') not null,
                                          subscription            varchar(45) CHECK (customer ~ '^sub_\w+$'),
                                          email                   email,
                                          address                 varchar(512),
                                          vat                     varchar(45)
);
COMMENT on column app_private.owner_billing.customer is 'Stripe customer ID.';
COMMENT on column app_private.owner_billing.subscription is 'Stripe subscriptions ID.';
COMMENT on column app_private.owner_billing.email is 'Where to send receipts to.';
CREATE TABLE app_private.owner_subscriptions(
                                                uuid                       uuid default uuid_generate_v4() primary key,
                                                owner_uuid                 uuid references owners on delete cascade not null,
                                                plan_uuid                  uuid not null
);
COMMENT on table app_private.owner_subscriptions is 'An owner subscriptions to servies.';
COMMENT on column app_private.owner_subscriptions.owner_uuid is 'The owner of the subscription, for billing purposes.';
COMMENT on column app_private.owner_subscriptions.plan_uuid is 'Link to the plan subscribing too.';
CREATE INDEX owner_subscriptions_owner_uuid_fk on app_private.owner_subscriptions (owner_uuid);
CREATE INDEX owner_subscriptions_plan_uuid_fk on app_private.owner_subscriptions (plan_uuid);
CREATE TABLE app_hidden.repos(
                                 uuid                       uuid default uuid_generate_v4() primary key,
                                 owner_vcs_uuid             uuid references owner_vcs on delete cascade not null,
                                 service                    git_service not null default 'github'::git_service,
                                 service_id                 citext unique CHECK (LENGTH(service_id) < 45) not null,
                                 name                       citext not null,
                                 using_github_installation  boolean not null default false
);
COMMENT on column app_hidden.repos.owner_vcs_uuid is 'The GitHub user/org that owns this repository.';
COMMENT on column app_hidden.repos.service is 'The repositorys service provider.';
COMMENT on column app_hidden.repos.service_id is 'The unique GitHub id of the repository.';
COMMENT on column app_hidden.repos.name is 'The repository slug name.';
COMMENT on column app_hidden.repos.using_github_installation is 'True: if the repository is using the GitHub App Integration';
CREATE UNIQUE INDEX repos_slug on app_hidden.repos (owner_vcs_uuid, name);
COMMENT on index repos_slug is 'A repository name is unique per GitHub Organization.';
CREATE UNIQUE INDEX repos_service_ids on app_hidden.repos (service, service_id);
COMMENT on index repos_service_ids is 'A repository service id is unique per Service.';
CREATE TABLE apps(
                     uuid                    uuid default uuid_generate_v4() primary key,
                     owner_uuid              uuid references owners on delete cascade not null default current_owner_uuid(),
                     repo_uuid               uuid references repos on delete cascade,
                     name                    title not null,
                     timestamp               timestamptz not null default now(),
                     maintenance             boolean default false not null,
                     deleted                 boolean default false not null,
                     environment             environment not null default 'PRODUCTION'::environment,
                     UNIQUE (owner_uuid, name)
);
COMMENT on table apps is 'Owned by an org, an App is a group of Repos that make up an application.';
COMMENT on column apps.timestamp is 'Date the application was created.';
COMMENT on column apps.owner_uuid is 'The Owner that owns this application.';
COMMENT on column apps.repo_uuid is 'The Repository linked to this application.';
CREATE INDEX apps_owners_uuid_fk on apps (owner_uuid);
CREATE INDEX apps_repo_uuid_fk on apps (repo_uuid);
CREATE TABLE app_dns(
                        hostname                hostname primary key,
                        app_uuid                uuid references apps on delete cascade not null,
                        is_validated            boolean default false not null
);
COMMENT on table app_dns is 'Apps may have many DNS endpoints that resolve to the application.';
COMMENT on column app_dns.hostname is 'A full hostname entry such as foobar.asyncyapp.com, example.com or *.everything.com';
COMMENT on column app_dns.is_validated is 'If dns resolves properly from registry.';
CREATE INDEX app_dns_app_uuid_fk on app_dns (app_uuid);
CREATE FUNCTION app_updated_notify() returns trigger as $$
  begin
    perform pg_notify('release', cast(old.uuid as text));
    return null;
  end;
$$ language plpgsql security definer SET search_path FROM CURRENT;
CREATE TRIGGER _100_app_updated_notify after update on apps
    for each row
    when (old.maintenance is distinct from new.maintenance or new.deleted=true)
execute procedure app_updated_notify();
CREATE FUNCTION app_prevent_restore() returns trigger as $$
begin
  if old.deleted is true then
    raise 'Once an app is destroyed, no updates are permitted to it.';
  end if;
  return new;
end;
$$ language plpgsql security definer SET search_path FROM CURRENT;
CREATE TRIGGER _50_app_prevent_restore before update on apps
    for each row execute procedure app_prevent_restore();
CREATE TABLE teams(
                      uuid                    uuid default uuid_generate_v4() primary key,
                      owner_uuid              uuid references owners on delete cascade not null,
                      name                    title not null,
                      UNIQUE (owner_uuid, name)
);
COMMENT on column teams.owner_uuid is 'The Owner that this team belong to.';
COMMENT on column teams.name is 'The title of the Team.';
CREATE INDEX teams_owner_uuid_fk on teams (owner_uuid);
CREATE TABLE team_permissions (
                                  team_uuid               uuid not null references teams on delete cascade,
                                  permission_slug         text not null references permissions on delete restrict,
                                  owner_uuid              uuid not null references owners on delete cascade,
                                  PRIMARY KEY (team_uuid, permission_slug, owner_uuid)
);
CREATE TRIGGER _500_abort_on_team_owner_change
    BEFORE UPDATE ON teams
    FOR EACH ROW
    WHEN (OLD.owner_uuid IS DISTINCT FROM NEW.owner_uuid)
EXECUTE PROCEDURE abort_with_errorcode('400', 'Teams are not allowed to move between owners.');
CREATE TABLE team_apps(
                          team_uuid                  uuid references teams on delete cascade not null,
                          app_uuid                   uuid references apps on delete cascade not null,
                          primary key (team_uuid, app_uuid)
);
CREATE TABLE service_categories(
                                   uuid                  uuid default uuid_generate_v4() primary key,
                                   title                 title,
                                   icon                  citext,
                                   type                  category_type not null
);
COMMENT on table service_categories is 'Collection of services.';
INSERT INTO service_categories (title, icon, type) values
('Authentication', null, 'SERVICE'),
('CMS', null, 'SERVICE'),
('Database', null, 'SERVICE'),
('Logging', null, 'SERVICE'),
('Memory Store', null, 'SERVICE'),
('Messaging', null, 'SERVICE'),
('Monitoring', null, 'SERVICE'),
('Optimization', null, 'SERVICE'),
('Search', null, 'SERVICE'),
('Social Media', null, 'SERVICE'),
('Video Processing', null, 'SERVICE'),
('Image Processing', null, 'SERVICE'),
('Text Processing', null, 'SERVICE'),
('Machine Learning', null, 'SERVICE'),
('Programming Languages', null, 'SERVICE'),
('Developer Tools', null, 'SERVICE'),
('IoT', null, 'SERVICE'),
('Worker', null, 'SERVICE'),
('Sorting', null, 'FUNCTION'),
('Filtering', null, 'FUNCTION'),
('Strings', null, 'FUNCTION');
CREATE TABLE services(
                         uuid                       uuid default uuid_generate_v4() primary key,
                         repo_uuid                  uuid references repos on delete cascade,
                         owner_uuid                 uuid references owners on delete cascade not null,
                         name                       alias not null,
                         category                   uuid references service_categories on delete set null,
                         description                text,
                         alias                      alias unique,
                         pull_url                   text,
                         topics                     citext[],
                         is_certified               boolean not null default false,
                         links                      jsonb,
                         tsvector                   tsvector,
                         public                     boolean not null default false,
                         created_at                 timestamp not null default now(),
                         type                       service_type not null default 'container'::service_type
);
COMMENT on column services.name is 'The namespace used for the project slug (org/service).';
COMMENT on column services.alias is 'The namespace reservation for the service';
COMMENT on column services.category is 'The category this service belongs too.';
COMMENT on column services.pull_url is 'Address where the container can be pulled from.';
COMMENT on column services.topics is 'GitHub repository topics for searching services.';
COMMENT on column services.links is 'Custom links';
COMMENT on column services.tsvector is E'@omit\nThis field will not be exposed to GraphQL, it''s for internal use only.';
COMMENT on column services.public is 'If the service is publicly available';
CREATE UNIQUE INDEX services_repo_uuid_fk on services (repo_uuid);
CREATE UNIQUE INDEX services_names on services (owner_uuid, name);
CREATE INDEX services_tsvector_idx ON services USING GIN (tsvector);
CREATE INDEX services_owners_uuid_fk on services (owner_uuid);
CREATE FUNCTION services__update_tsvector() RETURNS trigger AS $$
BEGIN
  if NEW.topics IS NULL THEN
    NEW.tsvector = NULL;
  ELSE
    NEW.tsvector = to_tsvector('simple', array_to_string(NEW.topics, E'\n'));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path FROM CURRENT;
CREATE TRIGGER _200_update_tsvector_insert BEFORE INSERT ON services FOR EACH ROW EXECUTE PROCEDURE services__update_tsvector();
CREATE TRIGGER _200_update_tsvector_update BEFORE UPDATE ON services FOR EACH ROW WHEN (NEW.topics IS DISTINCT FROM OLD.topics) EXECUTE PROCEDURE services__update_tsvector();
CREATE TYPE service_state as enum('DEVELOPMENT', 'PRERELEASE', 'BETA', 'STABLE', 'ARCHIVED');
CREATE TABLE service_tags(
                             service_uuid               uuid references services on delete cascade not null,
                             tag                        citext not null,
                             state                      service_state not null,
                             configuration              jsonb not null,
                             readme                     text,
                             updated_at                 timestamp not null default now(),
                             uuid                       uuid default uuid_generate_v4() primary key
);
ALTER TABLE service_tags ADD CONSTRAINT service_tags_unique UNIQUE (service_uuid, tag);
CREATE FUNCTION update_ts_in_service_tags() returns trigger as $$
begin
    NEW.updated_at = now();
    return NEW;
end;
$$ language plpgsql SET search_path FROM CURRENT;
CREATE TRIGGER _100_update_ts_in_service_tags before update on service_tags
    for each row
execute procedure update_ts_in_service_tags();
COMMENT on column service_tags.tag is 'The verion identifier. E.g., latest or v1.2';
COMMENT on column service_tags.configuration is 'The post processing of the microservice.yml file.';
COMMENT on column service_tags.readme is 'The readme content (first generated by the repository README).';
CREATE TABLE service_plans(
                              uuid                       uuid default uuid_generate_v4() primary key,
                              service_uuid               uuid references services on delete cascade not null,
                              title                      title not null,
                              details                    jsonb



);
COMMENT on table service_plans is 'Premium service plans.';
COMMENT on column service_plans.service_uuid is 'The service that owns this plan.';
COMMENT on column service_plans.title is 'A short name for the plan.';
COMMENT on column service_plans.details is 'Sales pitch content.';
CREATE INDEX service_plans_service_uuid_fk on service_plans (service_uuid);
ALTER TABLE app_private.owner_subscriptions
    ADD CONSTRAINT fk_plan_uuid
        FOREIGN KEY (plan_uuid)
            REFERENCES service_plans(uuid)
            ON DELETE RESTRICT;
CREATE TABLE service_usage(
                              memory_bytes               float[25] default array_fill(-1.0, array[25]) CHECK (cardinality(memory_bytes) = 25) not null,
                              cpu_units                  float[25] default array_fill(-1.0, array[25]) CHECK (cardinality(cpu_units) = 25) not null,
                              next_index                 int default 1 CHECK (next_index between 1 and 25) not null,
                              service_tag_uuid           uuid references service_tags on delete cascade primary key
);
COMMENT on table service_usage is 'Resource usage metrics for services';
COMMENT on column service_usage.memory_bytes is 'Circular queue storing memory bytes consumed';
COMMENT on column service_usage.cpu_units is 'Circular queue storing cpu units consumed';
COMMENT on column service_usage.next_index is 'Next index to be updated in the circular queues';
COMMENT on column service_usage.service_tag_uuid is 'The (service_uuid, image_tag) identifier';
CREATE TABLE builds(
                       repo_uuid               uuid references repos on delete cascade not null,
                       id                      int CHECK (id > 0) not null default 0,
                       timestamp               timestamptz not null default now(),
                       sha                     sha not null,
                       state                   build_state not null,
                       primary key (repo_uuid, id)
);
COMMENT on table builds is 'Building results from an Application.';
COMMENT on column builds.timestamp is 'Date the build started.';
COMMENT on column builds.sha is 'The commit id of the build being tested.';
COMMENT on column builds.state is 'The state of the build.';
CREATE TABLE app_private.build_numbers (
                                           repo_uuid               uuid references repos on delete cascade primary key,
                                           build_number            int not null default 1
);
CREATE FUNCTION builds_next_id() returns trigger as $$
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
$$ language plpgsql security definer SET search_path FROM CURRENT;
CREATE TRIGGER _100_builds_next_id_insert before insert on builds
    for each row execute procedure builds_next_id();
CREATE TABLE releases(
                         app_uuid                uuid references apps on delete cascade not null,
                         id                      int CHECK (id > 0) not null default 0,
                         config                  jsonb,
                         message                 text CHECK (LENGTH(message) < 1000) not null,
                         owner_uuid              uuid not null default current_owner_uuid() references owners on delete set null,
                         timestamp               timestamptz not null default now(),
                         payload                 jsonb default '{"__default__": "true"}'::jsonb,
                         state                   release_state not null default 'QUEUED'::release_state,
                         source                  release_source not null default 'CODE_UPDATE'::release_source,
                         always_pull_images      boolean not null default false,
                         primary key (app_uuid, id)
);
COMMENT on table releases is 'Identifying the active version of the application.';
COMMENT on column releases.app_uuid is 'The application this release belongs to.';
COMMENT on column releases.id is 'The release number of this release (within this app).';
COMMENT on column releases.config is 'Configuration of the release.';
COMMENT on column releases.message is 'User defined release message.';
COMMENT on column releases.owner_uuid is 'The person who submitted the release.';
COMMENT on column releases.timestamp is 'Time when release was first created.';
COMMENT on column releases.state is 'Identifying which release is active or rolling in/out.';
COMMENT on column releases.source is 'Identifying the cause of this release, whether it was because of a config change, a code update, or a rollback.';
COMMENT on column releases.payload is 'An object containing the full payload of Storyscripts, e.g., {"foobar": {"1": ...}}';
CREATE TABLE app_private.release_numbers (
                                             app_uuid                uuid references apps on delete cascade primary key,
                                             release_number          int not null default 1
);
CREATE FUNCTION releases_check_app_if_app_deleted() returns trigger as $$
  begin
    if exists (
              select 1 from apps
              where uuid = new.app_uuid
                    and deleted = false) then
      return new;
    end if;
    raise 'Once an app is destroyed, no deployments are permitted to it.';
  end;
$$ language plpgsql security definer SET search_path FROM CURRENT;
CREATE TRIGGER _050_releases_check_app_if_app_deleted before insert on releases
    for each row execute procedure releases_check_app_if_app_deleted();
CREATE FUNCTION releases_next_id() returns trigger as $$
  declare
    v_next_value int;
  begin
    -- TODO: this statement should be committed immediately in a separate
    -- transaction so that it behaves more like PostgreSQL sequences to avoid
    -- race conditions.
    -- Relevant: http://blog.dalibo.com/2016/08/19/Autonoumous_transactions_support_in_PostgreSQL.html
    insert into app_private.release_numbers (app_uuid) values (NEW.app_uuid) on conflict (app_uuid) do update set release_number = release_numbers.release_number + 1 returning release_number into v_next_value;
    new.id := v_next_value;
    return new;
  end;
$$ language plpgsql security definer SET search_path FROM CURRENT;
CREATE TRIGGER _100_releases_next_id_insert before insert on releases
    for each row execute procedure releases_next_id();
CREATE FUNCTION releases_defaults() returns trigger as $$
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
$$ language plpgsql security definer SET search_path FROM CURRENT;
CREATE TRIGGER _101_releases_defaults before insert on releases
    for each row execute procedure releases_defaults();
CREATE FUNCTION releases_notify() returns trigger as $$
  begin
    -- publish new releases to the channel "release"
    if new.state != 'NO_DEPLOY'::release_state then
      perform pg_notify('release', cast(new.app_uuid as text));
    end if;
    return null;
  end;
$$ language plpgsql security definer SET search_path FROM CURRENT;
CREATE TRIGGER _900_releases_notify after insert on releases
    for each row execute procedure releases_notify();
CREATE FUNCTION release_post_deployed() returns trigger as $$
begin
  -- When a release is deployed, check to see if there are
  -- previous releases in the 'queued' state. If yes, then set their
  -- state to `skipped_concurrent`.

  update releases set state = 'SKIPPED_CONCURRENT'::release_state
  where app_uuid=old.app_uuid
    and state = 'QUEUED'::release_state
    and id < new.id;

  -- Update all previous releases which are in the state of
  -- deployed, deploying, terminating to terminated.
  update releases set state = 'TERMINATED'::release_state
  where app_uuid=old.app_uuid
    and state in ('DEPLOYED'::release_state,
                  'DEPLOYING'::release_state,
                  'TERMINATING'::release_state)
    and id < new.id;

  -- Lastly, if there are any new releases in the queued state,
  -- notify the release channel.
  if exists (
      select 1 from releases
      where app_uuid = old.app_uuid
        and id > new.id
        and state = 'QUEUED'::release_state) then
    perform pg_notify('release', cast(new.app_uuid as text));
  end if;
  return null;
end;
$$ language plpgsql security definer SET search_path FROM CURRENT;
CREATE TRIGGER _901_releases_queued_check after update on releases
    for EACH ROW
    when (old.state is distinct from new.state and new.state = 'DEPLOYED'::release_state)
execute procedure release_post_deployed();
CREATE TABLE app_public.tokens(
                                  uuid                    uuid default uuid_generate_v4() primary key,
                                  owner_uuid              uuid references owners on delete cascade not null,
                                  type                    token_type not null,
                                  name                    title,
                                  expires                 timestamptz not null default NOW() + INTERVAL '25 years' CHECK (expires > NOW()),
                                  permissions             text[]
);
COMMENT on column tokens.uuid is 'The token itself that is shared with the user.';
COMMENT on column tokens.type is 'User login, api token, or application link.';
COMMENT on column tokens.name is 'A custom title for the login.';
COMMENT on column tokens.expires is 'Date the token should expire on.';
COMMENT on column tokens.permissions is 'List of permission slugs this token has privileges too.';
CREATE INDEX token_owner_uuid_fk on tokens (owner_uuid);
CREATE TRIGGER _100_insert_assert_permissions_exist before insert on tokens
    for each row
    when (cardinality(new.permissions) > 0)
execute procedure assert_permissions_exist();
CREATE TRIGGER _100_update_assert_permissions_exist before update on tokens
    for each row
    when (new.permissions is distinct from old.permissions and cardinality(new.permissions) > 0)
execute procedure assert_permissions_exist();
CREATE TABLE app_private.token_secrets (
                                           token_uuid              uuid primary key references app_public.tokens,
                                           secret                  text not null default encode(gen_random_bytes(16), 'base64') unique
);
COMMENT ON COLUMN app_private.token_secrets.secret IS '16 bytes, encoded as base64; at least as much entropy as a UUID - risk of collisions is vanishingly small.';
CREATE FUNCTION app_hidden.tg_tokens__insert_secret() RETURNS trigger AS $$
BEGIN
  INSERT INTO app_private.token_secrets(token_uuid) VALUES (NEW.uuid);
  RETURN NEW;
END;
$$ LANGUAGE PLPGSQL VOLATILE SECURITY DEFINER SET search_path FROM CURRENT;
CREATE TRIGGER _500_insert_secret AFTER INSERT ON tokens FOR EACH ROW EXECUTE PROCEDURE app_hidden.tg_tokens__insert_secret();
CREATE TABLE app_runtime.subscriptions (
                                           uuid             uuid PRIMARY KEY,
                                           app_uuid         uuid REFERENCES apps (uuid) ON DELETE CASCADE NOT NULL,
                                           url              text                                          NOT NULL,
                                           method           http_method                                   NOT NULL,
                                           payload          jsonb                                         NOT NULL,
                                           k8s_container_id text                                          NOT NULL,
                                           k8s_pod_name     text                                          NOT NULL
);
CREATE TABLE app_runtime.beta_users (
    username         text primary key
);
CREATE TABLE app_public.external_service_metadata(
                                                     service_uuid            uuid primary key references app_public.services on delete cascade not null,
                                                     document_uri            text not null,
                                                     properties              jsonb not null,
                                                     last_seen_hash          text not null
);
COMMENT on column external_service_metadata.document_uri is 'The URI of the OpenAPI document';
COMMENT on column external_service_metadata.properties is 'The properties submitted at service creation, provided to the OMG converter alongside the document';
COMMENT on column external_service_metadata.last_seen_hash is 'The hash of the document when last converted (in either success or failure cases)';
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
CREATE FUNCTION app_hidden.current_owner_has_organization_permission(owner_uuid uuid, required_permission_slug text) RETURNS boolean AS $$
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
COMMENT ON FUNCTION app_hidden.current_owner_has_organization_permission(owner_uuid uuid, required_permission_slug text) IS
    'If the current user has requested permission slug.';
CREATE FUNCTION app_hidden.current_owner_has_app_permission(app_uuid uuid, required_permission_slug text) RETURNS boolean AS $$
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
COMMENT ON FUNCTION app_hidden.current_owner_has_app_permission(app_uuid uuid, required_permission_slug text) IS
    'If the current user has permission to the app using requested permission slug.';
CREATE FUNCTION viewer() RETURNS owners AS $$
  SELECT * FROM owners WHERE uuid = current_owner_uuid();
$$ LANGUAGE sql STABLE SET search_path FROM CURRENT;
CREATE FUNCTION app_hidden.search_terms_to_tsquery(config regconfig, search_terms text) RETURNS tsquery AS $$
DECLARE
  v_sanitised text;
  v_sanitised_and_trimmed text;
  v_joined_with_ampersands text;
BEGIN
  v_sanitised = lower(regexp_replace(
    search_terms,
    '[^\d\w\s]',
    ' ',
    'g'
  ));
  v_sanitised_and_trimmed = regexp_replace(
    v_sanitised,
    '(^[^\d\w]*|[^\d\w]*$)',
    '',
    'g'
  );
  v_joined_with_ampersands = regexp_replace(v_sanitised_and_trimmed, '\s+', ' & ', 'g');
  RETURN to_tsquery(config, v_joined_with_ampersands || ':*');
END;
$$ LANGUAGE plpgsql IMMUTABLE SET search_path FROM CURRENT;
COMMENT ON FUNCTION app_hidden.search_terms_to_tsquery(config regconfig, search_terms text) IS
    E'Converts a web search term to a tsquery that can be used for FTS. This is a poor approximation for websearch_to_tsquery that''s coming in PG11. The final term is treated as a prefix search, all other terms are full matches.';
CREATE TYPE app_public.service_repository AS (
    service     app_public.git_service,
    owner_name  citext,
    repo_name   citext
    );
CREATE FUNCTION app_public.get_service_repository(service_uuid uuid) RETURNS app_public.service_repository AS $$
  SELECT o.service AS service, o.username AS owner_name, r.name AS repo_name
  FROM app_public.services s
  INNER JOIN app_hidden.repos r ON (r.uuid = s.repo_uuid)
  INNER JOIN app_public.owner_vcs o ON (o.uuid = r.owner_vcs_uuid)
  WHERE s.uuid = service_uuid AND (s.public OR s.owner_uuid = current_owner_uuid())
  LIMIT 1
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path FROM CURRENT;
COMMENT ON FUNCTION app_public.get_service_repository(uuid) IS E'Return the repository information for a single service.';
CREATE FUNCTION search_services(search_terms text) RETURNS SETOF services AS $$
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
$$ LANGUAGE sql STABLE SET search_path FROM CURRENT;
CREATE FUNCTION service_by_alias_or_name(service_name citext) RETURNS services AS $$
SELECT
    services.*
FROM
    services
        INNER JOIN owners on services.owner_uuid = owners.uuid
WHERE
        services.alias ILIKE service_name
   OR (position('/' in service_name)::boolean AND owners.username ILIKE split_part(service_name, '/', 1) AND services.name ILIKE split_part(service_name, '/', 2))
LIMIT 1;
$$ LANGUAGE sql STABLE SET search_path FROM CURRENT;
CREATE FUNCTION convert_to_hostname(name title) RETURNS text AS $$
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
$$ LANGUAGE sql STABLE SET search_path FROM CURRENT;
CREATE TABLE random_words (
                              word text unique not null,
                              start boolean not null
);
CREATE FUNCTION generate_awesome_word() RETURNS text AS $$
  SELECT
    (SELECT word FROM random_words where start OFFSET floor(random()*92) LIMIT 1) ||
    '-' ||
    (SELECT word FROM random_words where not start OFFSET floor(random()*231) LIMIT 1) ||
    '-' ||
    ((random()*1000)::int)::text;
$$ LANGUAGE sql STABLE SET search_path FROM CURRENT;
INSERT INTO random_words VALUES
('admiring', true),
('adoring', true),
('affectionate', true),
('amazing', true),
('awesome', true),
('blissful', true),
('brave', true),
('charming', true),
('clever', true),
('cool', true),
('compassionate', true),
('competent', true),
('condescending', true),
('confident', true),
('crazy', true),
('dazzling', true),
('determined', true),
('distracted', true),
('dreamy', true),
('eager', true),
('ecstatic', true),
('elastic', true),
('elated', true),
('elegant', true),
('eloquent', true),
('epic', true),
('fervent', true),
('festive', true),
('flamboyant', true),
('focused', true),
('friendly', true),
('frosty', true),
('gallant', true),
('gifted', true),
('goofy', true),
('gracious', true),
('happy', true),
('hardcore', true),
('heuristic', true),
('hopeful', true),
('hungry', true),
('infallible', true),
('inspiring', true),
('jolly', true),
('jovial', true),
('keen', true),
('kind', true),
('laughing', true),
('loving', true),
('lucid', true),
('magical', true),
('mystifying', true),
('modest', true),
('musing', true),
('naughty', true),
('nifty', true),
('nostalgic', true),
('objective', true),
('optimistic', true),
('peaceful', true),
('pedantic', true),
('pensive', true),
('practical', true),
('priceless', true),
('quirky', true),
('quizzical', true),
('recursing', true),
('relaxed', true),
('reverent', true),
('romantic', true),
('serene', true),
('sharp', true),
('silly', true),
('sleepy', true),
('stoic', true),
('stupefied', true),
('suspicious', true),
('sweet', true),
('tender', true),
('thirsty', true),
('trusting', true),
('unruffled', true),
('upbeat', true),
('vibrant', true),
('vigilant', true),
('vigorous', true),
('wizardly', true),
('wonderful', true),
('xenodochial', true),
('youthful', true),
('zealous', true),
('zen', true),
('albattani', false),
('allen', false),
('almeida', false),
('antonelli', false),
('agnesi', false),
('archimedes', false),
('ardinghelli', false),
('aryabhata', false),
('austin', false),
('babbage', false),
('banach', false),
('banzai', false),
('bardeen', false),
('bartik', false),
('bassi', false),
('beaver', false),
('bell', false),
('benz', false),
('bhabha', false),
('bhaskara', false),
('blackburn', false),
('blackwell', false),
('bohr', false),
('booth', false),
('borg', false),
('bose', false),
('boyd', false),
('brahmagupta', false),
('brattain', false),
('brown', false),
('buck', false),
('burnell', false),
('cannon', false),
('carson', false),
('cartwright', false),
('chandrasekhar', false),
('chaplygin', false),
('chatelet', false),
('chatterjee', false),
('chebyshev', false),
('cocks', false),
('cohen', false),
('chaum', false),
('clarke', false),
('colden', false),
('cori', false),
('cray', false),
('curran', false),
('curie', false),
('darwin', false),
('davinci', false),
('dewdney', false),
('dhawan', false),
('diffie', false),
('dijkstra', false),
('dirac', false),
('driscoll', false),
('dubinsky', false),
('easley', false),
('edison', false),
('einstein', false),
('elbakyan', false),
('elgamal', false),
('elion', false),
('ellis', false),
('engelbart', false),
('euclid', false),
('euler', false),
('faraday', false),
('feistel', false),
('fermat', false),
('fermi', false),
('feynman', false),
('franklin', false),
('gagarin', false),
('galileo', false),
('galois', false),
('ganguly', false),
('gates', false),
('gauss', false),
('germain', false),
('goldberg', false),
('goldstine', false),
('goldwasser', false),
('golick', false),
('goodall', false),
('greider', false),
('grothendieck', false),
('haibt', false),
('hamilton', false),
('haslett', false),
('hawking', false),
('hellman', false),
('heisenberg', false),
('hermann', false),
('herschel', false),
('hertz', false),
('heyrovsky', false),
('hodgkin', false),
('hofstadter', false),
('hoover', false),
('hopper', false),
('hugle', false),
('hypatia', false),
('ishizaka', false),
('jackson', false),
('jang', false),
('jennings', false),
('jepsen', false),
('johnson', false),
('joliot', false),
('jones', false),
('kalam', false),
('kapitsa', false),
('kare', false),
('keldysh', false),
('keller', false),
('kepler', false),
('khayyam', false),
('khorana', false),
('kilby', false),
('kirch', false),
('knuth', false),
('kowalevski', false),
('lalande', false),
('lamarr', false),
('lamport', false),
('leakey', false),
('leavitt', false),
('lederberg', false),
('lehmann', false),
('lewin', false),
('lichterman', false),
('liskov', false),
('lovelace', false),
('lumiere', false),
('mahavira', false),
('margulis', false),
('matsumoto', false),
('maxwell', false),
('mayer', false),
('mccarthy', false),
('mcclintock', false),
('mclaren', false),
('mclean', false),
('mcnulty', false),
('mendel', false),
('mendeleev', false),
('meitner', false),
('meninsky', false),
('merkle', false),
('mestorf', false),
('minsky', false),
('mirzakhani', false),
('moore', false),
('morse', false),
('murdock', false),
('moser', false),
('napier', false),
('nash', false),
('neumann', false),
('newton', false),
('nightingale', false),
('nobel', false),
('noether', false),
('northcutt', false),
('noyce', false),
('panini', false),
('pare', false),
('pascal', false),
('pasteur', false),
('payne', false),
('perlman', false),
('pike', false),
('poincare', false),
('poitras', false),
('proskuriakova', false),
('ptolemy', false),
('raman', false),
('ramanujan', false),
('ride', false),
('montalcini', false),
('ritchie', false),
('rhodes', false),
('robinson', false),
('roentgen', false),
('rosalind', false),
('rubin', false),
('saha', false),
('sammet', false),
('sanderson', false),
('shannon', false),
('shaw', false),
('shirley', false),
('shockley', false),
('shtern', false),
('sinoussi', false),
('snyder', false),
('solomon', false),
('spence', false),
('sutherland', false),
('stallman', false),
('stonebraker', false),
('swanson', false),
('swartz', false),
('swirles', false),
('taussig', false),
('tereshkova', false),
('tesla', false),
('tharp', false),
('thompson', false),
('torvalds', false),
('tu', false),
('turing', false),
('varahamihira', false),
('vaughan', false),
('visvesvaraya', false),
('volhard', false),
('villani', false),
('wescoff', false),
('wiles', false),
('williams', false),
('williamson', false),
('wilson', false),
('wing', false),
('wozniak', false),
('wright', false),
('wu', false),
('yalow', false),
('yonath', false),
('zhukovsky', false);
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
ALTER TABLE apps ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_own ON apps FOR SELECT USING (owner_uuid = current_owner_uuid());
CREATE POLICY select_organization ON apps FOR SELECT USING (owner_uuid = ANY (current_owner_organization_uuids()));
GRANT SELECT ON apps TO asyncy_visitor;
CREATE POLICY insert_own ON apps FOR INSERT WITH CHECK (owner_uuid = current_owner_uuid());
CREATE POLICY insert_organization ON apps FOR INSERT WITH CHECK (current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'));
GRANT INSERT ON apps TO asyncy_visitor;
CREATE POLICY update_own ON apps FOR UPDATE USING (owner_uuid = current_owner_uuid());
CREATE POLICY update_organization ON apps FOR UPDATE USING (current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'));
GRANT UPDATE ON apps TO asyncy_visitor;
ALTER TABLE app_dns ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_app ON app_dns FOR SELECT USING (EXISTS(SELECT 1 FROM apps WHERE apps.uuid = app_dns.app_uuid));
GRANT SELECT ON app_dns TO asyncy_visitor;
ALTER TABLE builds ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_repo_visible ON builds FOR SELECT USING (EXISTS(SELECT 1 FROM repos WHERE repos.uuid = builds.repo_uuid));
GRANT SELECT ON builds TO asyncy_visitor;
ALTER TABLE owners ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_all ON owners FOR SELECT USING (true);
CREATE POLICY select_own ON owners FOR SELECT USING (uuid = current_owner_uuid());
GRANT SELECT ON owners TO asyncy_visitor;
CREATE POLICY update_own_marketing_source ON owners FOR UPDATE USING (uuid = current_owner_uuid());
GRANT UPDATE (marketing_source_uuid) ON owners TO asyncy_visitor;
ALTER TABLE owner_vcs ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_own ON owner_vcs FOR SELECT USING (owner_uuid = current_owner_uuid());
GRANT SELECT ON owner_vcs TO asyncy_visitor;
ALTER TABLE owner_billing ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_member ON owner_billing FOR SELECT USING (owner_uuid = ANY (current_owner_organization_uuids(ARRAY['BILLING'])));
GRANT SELECT ON owner_billing TO asyncy_visitor;
ALTER TABLE owner_emails ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_own ON owner_emails FOR SELECT USING (owner_uuid = current_owner_uuid());
GRANT SELECT ON owner_emails TO asyncy_visitor;
CREATE POLICY insert_own ON owner_emails FOR INSERT WITH CHECK (owner_uuid = current_owner_uuid());
GRANT INSERT (owner_uuid, email) ON owner_emails TO asyncy_visitor;
CREATE POLICY delete_own ON owner_emails FOR DELETE USING (owner_uuid = current_owner_uuid());
GRANT DELETE ON owner_emails TO asyncy_visitor;
ALTER TABLE app_private.owner_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_billing ON app_private.owner_subscriptions FOR SELECT USING (owner_uuid = ANY(current_owner_organization_uuids(ARRAY['BILLING'])));
GRANT SELECT ON app_private.owner_subscriptions TO asyncy_visitor;
ALTER TABLE owner_containerconfigs ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_own ON owner_containerconfigs FOR SELECT USING (owner_uuid = current_owner_uuid());
CREATE POLICY select_organization ON owner_containerconfigs FOR SELECT USING (current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'));
GRANT SELECT ON owner_containerconfigs TO asyncy_visitor;
CREATE POLICY insert_own ON owner_containerconfigs FOR INSERT WITH CHECK (owner_uuid = current_owner_uuid());
CREATE POLICY insert_organization ON owner_containerconfigs FOR INSERT WITH CHECK (current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'));
GRANT INSERT ON owner_containerconfigs TO asyncy_visitor;
CREATE POLICY update_own ON owner_containerconfigs FOR UPDATE USING (owner_uuid = current_owner_uuid());
CREATE POLICY update_organization ON owner_containerconfigs FOR UPDATE USING (current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'));
GRANT UPDATE ON owner_containerconfigs TO asyncy_visitor;
CREATE POLICY delete_own ON owner_containerconfigs FOR DELETE USING (owner_uuid = current_owner_uuid());
CREATE POLICY delete_organization ON owner_containerconfigs FOR DELETE USING (current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'));
GRANT DELETE ON owner_containerconfigs TO asyncy_visitor;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_organization ON teams FOR SELECT USING (owner_uuid = ANY (current_owner_organization_uuids()));
GRANT SELECT ON teams TO asyncy_visitor;
ALTER TABLE team_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_organization ON team_permissions FOR SELECT USING (EXISTS(SELECT 1 FROM teams WHERE teams.uuid = team_uuid));
GRANT SELECT ON team_permissions TO asyncy_visitor;
CREATE POLICY insert_admin ON team_permissions FOR INSERT WITH CHECK (current_owner_has_organization_permission(owner_uuid, 'ADMIN'));
GRANT INSERT ON team_permissions TO asyncy_visitor;
CREATE POLICY delete_admin ON team_permissions FOR DELETE USING (current_owner_has_organization_permission(owner_uuid, 'ADMIN'));
GRANT DELETE ON team_permissions TO asyncy_visitor;
ALTER TABLE team_apps ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_team_member ON team_apps FOR SELECT USING (EXISTS(SELECT 1 FROM teams WHERE teams.uuid = team_uuid));
GRANT SELECT ON team_apps TO asyncy_visitor;
CREATE POLICY insert_admin ON team_apps FOR INSERT WITH CHECK
    (current_owner_has_organization_permission((SELECT owner_uuid FROM teams WHERE teams.uuid = team_uuid), 'ADMIN'));
GRANT INSERT ON team_apps TO asyncy_visitor;
CREATE POLICY delete_admin ON team_apps FOR DELETE USING
    (current_owner_has_organization_permission((SELECT owner_uuid FROM teams WHERE teams.uuid = team_uuid), 'ADMIN'));
GRANT DELETE ON team_apps TO asyncy_visitor;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_all ON permissions FOR SELECT USING (true);
GRANT SELECT ON permissions TO asyncy_visitor;
ALTER TABLE releases ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_app ON releases FOR SELECT USING (EXISTS(SELECT 1 FROM apps WHERE apps.uuid = releases.app_uuid));
GRANT SELECT ON releases TO asyncy_visitor;
CREATE POLICY insert_permission ON releases FOR INSERT WITH CHECK (current_owner_has_app_permission(releases.app_uuid, 'CREATE_RELEASE'));
GRANT INSERT (app_uuid, config, message, payload, always_pull_images, source) ON releases TO asyncy_visitor;
ALTER TABLE random_words ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_words ON random_words FOR SELECT USING (true);
GRANT SELECT ON random_words TO asyncy_visitor;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_public ON services FOR SELECT USING (public);
CREATE POLICY select_own ON services FOR SELECT USING (owner_uuid = current_owner_uuid());
CREATE POLICY select_organization ON services FOR SELECT USING (owner_uuid = ANY (current_owner_organization_uuids()));
GRANT SELECT ON services TO asyncy_visitor;
ALTER TABLE service_tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_tag ON service_tags FOR SELECT USING (EXISTS(SELECT 1 FROM services WHERE services.uuid = service_tags.service_uuid));
GRANT SELECT ON service_tags TO asyncy_visitor;
ALTER TABLE service_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_all ON service_categories FOR SELECT USING (true);
GRANT SELECT ON service_categories TO asyncy_visitor;
ALTER TABLE service_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_all ON service_plans FOR SELECT USING (true);
GRANT SELECT ON service_plans TO asyncy_visitor;
ALTER TABLE service_usage ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_public_or_own on service_usage FOR SELECT USING (
    EXISTS (
            SELECT 1 FROM service_tags
                              INNER JOIN services on services.uuid = service_tags.service_uuid
            WHERE service_tags.uuid = service_usage.service_tag_uuid
              AND (
                    services.public
                    OR services.owner_uuid = current_owner_uuid()
                )
        )
    );
GRANT SELECT ON service_usage to asyncy_visitor;
alter table marketing_sources enable row level security;
create policy select_own on marketing_sources for select using (
    exists(
            select 1 from owners
            where owners.uuid = current_owner_uuid()
              and owners.marketing_source_uuid = marketing_sources.uuid
        )
    );
grant select on marketing_sources to asyncy_visitor;
CREATE FUNCTION insert_organization_admin() RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;
CREATE TRIGGER _900_insert_organization_admin
    AFTER INSERT ON owners
    FOR EACH ROW
    WHEN (NEW.is_user IS FALSE)
EXECUTE PROCEDURE insert_organization_admin();
CREATE FUNCTION apps_create_dns() returns trigger as $$
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
$$ language plpgsql security definer SET search_path FROM CURRENT;
CREATE TRIGGER _101_apps_create_dns after insert on apps
    for each row execute procedure apps_create_dns();
CREATE FUNCTION owner_username_conflict() RETURNS TRIGGER AS $$
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
CREATE TRIGGER _100_insert_owner_username_conflict
    BEFORE INSERT ON owners
    FOR EACH ROW
EXECUTE PROCEDURE owner_username_conflict();
CREATE FUNCTION assert_owner_is_organization() RETURNS TRIGGER AS $$
BEGIN

    IF EXISTS (SELECT 1 FROM app_public.owners WHERE uuid = NEW.owner_uuid AND is_user = TRUE LIMIT 1) THEN
        RAISE EXCEPTION 'Teams cannot be owned by users.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql STABLE;
CREATE TRIGGER _100_assert_owner_is_organization
    BEFORE INSERT ON teams
    FOR EACH ROW
EXECUTE PROCEDURE assert_owner_is_organization();

COMMIT;
