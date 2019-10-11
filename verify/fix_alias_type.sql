-- Verify storyscript:fix_alias_type on pg

SET search_path TO :search_path;

BEGIN;

-- Inspired from https://dba.stackexchange.com/a/203937/161921
create function try_cast(t text)
    returns alias
as
$$
begin
    begin
        return cast(t as alias);
    exception
        when others then
            return null;
    end;
end;
$$
    language plpgsql;

do
$$
    begin
        assert try_cast('helloworld') is not null;
        assert try_cast('hello123') is not null;
        assert try_cast('h2') is not null;
        assert try_cast('hello_') is not null;
        assert try_cast('world-') is not null;
        assert try_cast('hello-world') is not null;
        assert try_cast('hello_world') is not null;

        assert try_cast('hello world') is null;
        assert try_cast('123') is null;
        assert try_cast('1world') is null;
        assert try_cast('hello.world') is null;
        assert try_cast('-') is null;
        assert try_cast('_') is null;
        assert try_cast('.') is null;
        assert try_cast('.helloworld') is null;
    end;
$$;

ROLLBACK;
