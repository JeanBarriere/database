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
GRANT CONNECT ON DATABASE asyncy TO asyncy_authenticator;
GRANT CONNECT ON DATABASE postgres TO asyncy_authenticator;

GRANT USAGE ON SCHEMA app_public TO asyncy_visitor;
GRANT USAGE ON SCHEMA app_hidden TO asyncy_visitor;

CREATE TABLE app_private.version (
  version             text CHECK (version ~ '^\d+\.\d+\.\d+$') primary key
);
INSERT INTO app_private.version values ('0.0.1');

\ir types.sql
\ir early_functions/main.sql
\ir tables/main.sql
\ir functions/main.sql
\ir permissions/main.sql
\ir triggers/main.sql
