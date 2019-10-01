#!/usr/bin/env bash

set -euxo pipefail

mapfile -t changes < <(sqitch status db:pg://${DATABASE_URL} | sed -n 's/^  \* //p')

for change in "${changes[@]}"
do
  pg_dump -s postgres://${DATABASE_URL} > $HOME/${change}.base.sql
  sqitch deploy --to ${change} db:pg://${DATABASE_URL}
  sqitch revert --to @HEAD^ -y db:pg://${DATABASE_URL}
  pg_dump -s postgres://${DATABASE_URL} > $HOME/${change}.revert.sql
  diff $HOME/${change}.base.sql $HOME/${change}.revert.sql
  sqitch deploy --to ${change} db:pg://${DATABASE_URL}
done
