CREATE TABLE app_hidden.repos(
  uuid                       uuid default uuid_generate_v4() primary key,
  owner_vcs_uuid             uuid references owner_vcs on delete cascade not null,
  service                    git_service not null default 'github'::git_service,
  service_id                 citext unique CHECK (LENGTH(service_id) < 45) not null,
  name                       username not null,
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
