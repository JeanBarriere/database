create policy update_own_marketing_source on owners for update using (uuid = current_owner_uuid());
grant update (marketing_source_uuid) on owners to asyncy_visitor;
