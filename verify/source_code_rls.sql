-- Verify storyscript:source_code_rls on pg

SET search_path TO :search_path;

BEGIN;

do $$
begin
    assert (
        select count(*)
        from information_schema.column_privileges
        where table_name='releases'
          and grantee='asyncy_visitor'
          and privilege_type='INSERT'
          and column_name='source_code'
        ) = 1,
        'Policy not found';
end;
$$;

ROLLBACK;
