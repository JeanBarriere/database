# Storyscript Cloud Database

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v1.4%20adopted-ff69b4.svg?style=for-the-badge)](https://github.com/storyscript/.github/blob/master/CODE_OF_CONDUCT.md)

## Bootstrapping the database
1. Install PostgreSQL 9.6.14
2. Create a database
```bash
# The createdb command is a part of the PostgreSQL distribution
$ createdb storyscript
```
3. Get [sqitch](https://sqitch.org/download/)
- For Mac, install it using Homebrew
```bash
$ brew tap sqitchers/sqitch
$ brew install sqitch --with-postgres-support
```
4. Checkout this project, and in the checked out directory, use `sqitch` to bootstrap the DB created
```bash
$ sqitch deploy db:pg:storyscript
```
`sqitch deploy` accepts a [database URI](https://github.com/libwww-perl/uri-db/) argument, denoting the target database where you want to deploy changes.

To learn more about sqitch, you can go through its [postgres tutorial](https://sqitch.org/docs/manual/sqitchtutorial/).

## Creating a change
```bash
$ sqitch add <change_name>
```

Remember to set the search path in all of deploy, verify and revert scripts.
```sql
SET search_path TO :search_path;

BEGIN;

-- XXX Add DDLs here.
```
This variable is set in `sqitch.conf`.
## Updating an existing database
Simply run the following to update your database to the latest version:
```bash
$ sqitch deploy db:pg:storyscript
```

## Advanced notes
If you need to access the database from other than your local network,
say from Kubernetes, or a Docker container, you will need to enable
access for the `storyscript` database in `pg_hba.conf`.
Add the following line to `pg_hba.conf`:
```
host	storyscript			all				samenet					trust
```

**Note 1**: `samenet` matches any address in any subnet that the server is directly connected to (which includes the Kubernetes network).
