create table app_public.marketing_sources
(
    uuid uuid default uuid_generate_v4() not null primary key,
    code text                            not null unique
);

comment on table app_public.marketing_sources is
    'A table to help attribute marketing efforts (be able to attribute new users from conferences, events, workshops, etc).';
