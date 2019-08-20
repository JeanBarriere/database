ALTER TABLE services alter column repo_uuid drop not null;
CREATE TYPE service_type as enum('container', 'openapi');
ALTER TABLE services add column type service_type default 'container'::service_type not null;
