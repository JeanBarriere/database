ALTER TABLE owners ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_own ON owners FOR SELECT USING (uuid = current_owner_uuid());
GRANT SELECT ON owners TO asyncy_visitor;

CREATE POLICY update_own_marketing_source ON owners FOR UPDATE USING (uuid = current_owner_uuid());
GRANT UPDATE (marketing_source_uuid) ON owners TO asyncy_visitor;

----

ALTER TABLE owner_vcs ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_own ON owner_vcs FOR SELECT USING (owner_uuid = current_owner_uuid());
GRANT SELECT ON owner_vcs TO asyncy_visitor;

----

ALTER TABLE owner_billing ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_member ON owner_billing FOR SELECT USING (owner_uuid = ANY (current_owner_organization_uuids(ARRAY['BILLING'])));
GRANT SELECT ON owner_billing TO asyncy_visitor;

----

ALTER TABLE owner_emails ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_own ON owner_emails FOR SELECT USING (owner_uuid = current_owner_uuid());
GRANT SELECT ON owner_emails TO asyncy_visitor;

CREATE POLICY insert_own ON owner_emails FOR INSERT WITH CHECK (owner_uuid = current_owner_uuid());
GRANT INSERT (owner_uuid, email) ON owner_emails TO asyncy_visitor;

-- DO NOT grant UPDATE! Only the system can update an email (to change the verified status)

CREATE POLICY delete_own ON owner_emails FOR DELETE USING (owner_uuid = current_owner_uuid());
GRANT DELETE ON owner_emails TO asyncy_visitor;

----

ALTER TABLE app_private.owner_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_billing ON app_private.owner_subscriptions FOR SELECT USING (owner_uuid = ANY(current_owner_organization_uuids(ARRAY['BILLING'])));
GRANT SELECT ON app_private.owner_subscriptions TO asyncy_visitor;

-- Do not grant INSERT, UPDATE, DELETE - these permissions are managed by the system, not users.

----

ALTER TABLE owner_containerconfigs ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_own ON owner_containerconfigs FOR SELECT USING (owner_uuid = current_owner_uuid());
CREATE POLICY select_organization ON owner_containerconfigs FOR SELECT USING (current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'));
GRANT SELECT ON owner_containerconfigs TO asyncy_visitor;

CREATE POLICY insert_own ON owner_containerconfigs FOR INSERT WITH CHECK (owner_uuid = current_owner_uuid());
CREATE POLICY insert_organization ON owner_containerconfigs FOR INSERT WITH CHECK (current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'));
GRANT INSERT ON owner_containerconfigs TO asyncy_visitor;

CREATE POLICY update_own ON owner_containerconfigs FOR UPDATE USING (owner_uuid = current_owner_uuid());
CREATE POLICY update_organization ON owner_containerconfigs FOR UPDATE USING (current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'));
GRANT UPDATE ON owner_containerconfigs TO asyncy_visitor;

CREATE POLICY delete_own ON owner_containerconfigs FOR DELETE USING (owner_uuid = current_owner_uuid());
CREATE POLICY delete_organization ON owner_containerconfigs FOR DELETE USING (current_owner_has_organization_permission(owner_uuid, 'CREATE_APP'));
GRANT DELETE ON owner_containerconfigs TO asyncy_visitor;
