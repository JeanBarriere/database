alter table marketing_sources enable row level security;


create policy select_own on marketing_sources for select using (
    exists(
        select 1 from owners
        where owners.uuid = current_owner_uuid()
          and owners.marketing_source_uuid = marketing_sources.uuid
    )
);
grant select on marketing_sources to asyncy_visitor;
