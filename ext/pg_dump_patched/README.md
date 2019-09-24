This is a patched version of official docker image used for building Postgres.

# Source
https://github.com/docker-library/postgres/blob/bcfe8611162fb6b9a7190f85e9ae337eeb1057ad/9.6/alpine/Dockerfile

## Extra patches applied
1. Benjie's patch to sort the RLS output by table names - https://www.postgresql.org/message-id/attachment/104251/pg-dump-policy-trigger-sort_v1.patch
