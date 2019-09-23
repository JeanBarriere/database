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

---

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

---

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
