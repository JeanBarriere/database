# Storyscript Cloud Database

### Initialization steps

1. Create a postgres database
```bash
$ createdb storyscript
```
2. Get [sqitch](https://sqitch.org/download/)
```bash
$ brew tap sqitchers/sqitch
$ brew install sqitch --with-postgres-support
```
3. Run migrations
```bash
$ sqitch deploy db:pg:storyscript
```

`sqitch deploy` accepts a [database URI](https://github.com/libwww-perl/uri-db/) argument, denoting the target database where you want to deploy changes.

To learn more about sqitch, you can go through its [postgres tutorial](https://sqitch.org/docs/manual/sqitchtutorial/).
