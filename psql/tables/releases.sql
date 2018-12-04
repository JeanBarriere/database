CREATE TABLE releases(
  app_uuid                uuid references apps on delete cascade not null,
  id                      int CHECK (id > 0) not null default 0,
  config                  jsonb,
  message                 text CHECK (LENGTH(message) < 1000) not null,
  owner_uuid              uuid not null default current_owner_uuid() references owners on delete set null,
  timestamp               timestamptz not null default now(),
  state                   release_state not null default 'QUEUED'::release_state,
  source                  release_source not null default 'CODE_UPDATE'::release_source,
  payload                 jsonb default '{"__default__": "true"}'::jsonb,
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
    perform pg_notify('release', cast(new.app_uuid as text));
    return null;
  end;
$$ language plpgsql security definer SET search_path FROM CURRENT;

CREATE TRIGGER _900_releases_notify after insert or update on releases
  for each row execute procedure releases_notify();
