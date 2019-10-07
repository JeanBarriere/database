-- Deploy storyscript:add_source_code_rls to pg

SET search_path TO :search_path;

BEGIN;

GRANT INSERT (source_code) ON releases TO asyncy_visitor;

COMMIT;
