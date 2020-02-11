-- Verify storyscript:bootstrap on pg

SET search_path TO :search_path;

BEGIN;

-- Are we testing everything ?
SELECT column_name
FROM information_schema.columns
WHERE table_name='services' AND column_name='configuration';

SELECT column_name
FROM information_schema.columns
WHERE table_name='owners' AND column_name='sso_github_id';

ROLLBACK;
