-- https://github.com/storyscript/database/pull/101

-- since repo names come directly from vcs
ALTER TABLE app_hidden.repos
    ALTER COLUMN name
    SET DATA TYPE citext;
