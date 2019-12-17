-- Deploy storyscript:cascade-token-secret-deletion to pg

BEGIN;

-- drop old constraint
ALTER TABLE app_private.token_secrets DROP CONSTRAINT token_secrets_token_uuid_fkey;

-- add new constraing
ALTER TABLE app_private.token_secrets
    ADD CONSTRAINT token_secrets_token_uuid_fkey
        FOREIGN KEY (token_uuid)
            REFERENCES app_public.tokens(uuid)
            ON DELETE CASCADE;

COMMIT;
