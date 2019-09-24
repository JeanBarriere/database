#!/usr/bin/env bash

# $ bash dump.sh DATABASE_URL [DUMP_PATH]

set -e

database_url="${1}"
dump_path="${2:-dump}"
schemas=("app_public" "app_hidden" "app_private" "app_runtime" "public")

[[ -z "${database_url}" ]] && { echo "No database specified"; exit 1; }

for schema in "${schemas[@]}"
do
  mkdir -p "${dump_path}/${schema}"
  tables=(`psql -Atc "select tablename from pg_tables where schemaname='${schema}';" ${database_url}`)
  table_excludes=""
  for table in "${tables[@]}"
  do
    pg_dump -s -t "${schema}.${table}" "${database_url}" > "${dump_path}/${schema}/${table}.sql"
    table_excludes+="-T ${schema}.${table} "
  done
  pg_dump -s -n "${schema}" ${table_excludes} "${database_url}" > "${dump_path}/${schema}/_base.sql"
done
