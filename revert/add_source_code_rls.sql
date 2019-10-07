-- Revert storyscript:add_source_code_rls from pg

SET search_path TO :search_path;

BEGIN;

REVOKE INSERT (source_code) ON releases FROM asyncy_visitor;

COMMIT;
