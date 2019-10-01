-- Verify storyscript:current_owner on pg

BEGIN;

#SELECT 1;
#SELECT pg_get_functiondef('current_owner()'::regprocedure);


ROLLBACK;
