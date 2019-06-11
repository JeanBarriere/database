# Storyscript Cloud's Database
This is the Storyscript Cloud's database bootstrap tool, which creates the schemas and tables.

## Creating the database locally
1. Ensure you have Postgres installed and running (at least version 10.5)
2. Install the `make` tool (on macOS, run `xcode-select --install`)
3. Create the `storyscript` database in Postgres. In the terminal run the following commands:
  - `psql postgres`
  - `create database storyscript;`
  - `\q`
4. Clone this project
5. Run `make reset DB=storyscript` in the cloned project

Here's what your output should look like:
```shell
$ psql postgres
psql (10.5)
Type "help" for help.

postgres=# create database storyscript;
CREATE DATABASE
postgres=# \q
$ make reset DB=storyscript
...
...
$
```

## Advanced notes
If you need to access the database from other than your local network, say from Kubernetes, or a Docker container, you will need to enable access for the `storyscript` database in `pg_hba.conf`. Add the following line to `pg_hba.conf`:
```
host	asyncy			all				samenet					md5
```

**Note 1**: `samenet` matches any address in any subnet that the server is directly connected to (which includes the Kubernetes network).

**Note 2**: You need to create a password for the user accessing the database (this is a Postgres requirement)
