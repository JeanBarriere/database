-- Verify storyscript:fix_alias_type on pg

SET search_path TO :search_path;

BEGIN;

DO $$
BEGIN

-- checking that no services contain '.' in their names anymore
ASSERT (SELECT count(*) FROM services WHERE name ~ '\.') = 0, 'cannot have services';

END;
$$;


ROLLBACK;
