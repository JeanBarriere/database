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
