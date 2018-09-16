CREATE TABLE services(
  uuid                       uuid default uuid_generate_v4() primary key,
  repo_uuid                  uuid references repos on delete cascade not null,
  organization_uuid          uuid references organizations on delete cascade,
  owner_uuid                 uuid references owners on delete cascade,
  title                      title not null,
  category                   uuid references categories on delete set null,
  description                text,
  alias                      alias unique,
  pull_url                   text,
  topics                     citext[],
  is_certified               boolean not null default false,
  links                      jsonb,
  tsvector                   tsvector,
  public                     boolean not null default false,
  CONSTRAINT must_have_exactly_one_owner CHECK (
    (organization_uuid IS NULL) <> (owner_uuid IS NULL)
  )
);
COMMENT on column services.alias is 'The namespace reservation for the container';
COMMENT on column services.category is 'The category this service belongs too.';
COMMENT on column services.pull_url is 'Address where the container can be pulled from.';
COMMENT on column services.topics is 'GitHub repository topics for searching services.';
COMMENT on column services.links is 'Custom links';
COMMENT on column services.tsvector is E'@omit\nThis field will not be exposed to GraphQL, it''s for internal use only.';
COMMENT on column services.public is 'If the service is publicly available';

CREATE UNIQUE INDEX services_repo_uuid_fk on services (repo_uuid);
CREATE INDEX services_tsvector_idx ON services USING GIN (tsvector);
CREATE INDEX services_organization_uuid_fk on services (organization_uuid);
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
  primary key (service_uuid, tag)
);

COMMENT on column service_tags.tag is 'The verion identifier. E.g., latest or v1.2';
COMMENT on column service_tags.configuration is 'The post processing of the microservice.yml file.';
COMMENT on column service_tags.readme is 'The readme content (first generated by the repository README).';
