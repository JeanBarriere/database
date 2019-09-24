# Storyscript Cloud Database

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

## Updating an existing database
Simply run the following to update your database to the latest version:
```bash
$ sqitch deploy db:pg:storyscript
```
