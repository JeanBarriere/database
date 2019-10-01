-- Verify storyscript:current_owner on pg

BEGIN;

SELECT pg_get_functiondef('current_owner()'::regprocedure);


ROLLBACK;
