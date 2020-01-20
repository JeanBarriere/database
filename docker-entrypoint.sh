#!/bin/bash

for i in {1..10}; do
  echo "attempting to sqitch deploy, attempt $i"
  sqitch deploy "$DATABASE_URL" && exit 0 || sleep 5;
done

exit 1
