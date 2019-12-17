-- Verify storyscript:cascade-token-secret-deletion on pg

SET search_path TO :search_path;

BEGIN;

do $$
DECLARE
  owneruuid uuid;
  tokenuuid uuid;

BEGIN
    INSERT INTO owners (username) VALUES ('sqitch-test') RETURNING uuid INTO owneruuid;
    INSERT INTO tokens (owner_uuid, type) VALUES (owneruuid, 'API') RETURNING uuid INTO tokenuuid;

    assert (SELECT COUNT(*) FROM token_secrets WHERE token_uuid = tokenuuid) = 1, 'not 1!';

    DELETE FROM owners WHERE uuid = owneruuid;

    assert (SELECT COUNT(*) FROM token_secrets WHERE token_uuid = tokenuuid) = 0, 'not 0!';
END;
$$;

ROLLBACK;
