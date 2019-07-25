ALTER TABLE teams ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_organization ON teams FOR SELECT USING (owner_uuid = ANY (current_owner_organization_uuids()));
GRANT SELECT ON teams TO asyncy_visitor;

-- NOTE organization members can see all teams, permissions, members and apps

---

ALTER TABLE team_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_organization ON team_permissions FOR SELECT USING (EXISTS(SELECT 1 FROM teams WHERE teams.uuid = team_uuid));
GRANT SELECT ON team_permissions TO asyncy_visitor;

CREATE POLICY insert_admin ON team_permissions FOR INSERT WITH CHECK (current_owner_has_organization_permission(owner_uuid, 'ADMIN'));
GRANT INSERT ON team_permissions TO asyncy_visitor;

CREATE POLICY delete_admin ON team_permissions FOR DELETE USING (current_owner_has_organization_permission(owner_uuid, 'ADMIN'));
GRANT DELETE ON team_permissions TO asyncy_visitor;

---

ALTER TABLE team_apps ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_team_member ON team_apps FOR SELECT USING (EXISTS(SELECT 1 FROM teams WHERE teams.uuid = team_uuid));
GRANT SELECT ON team_apps TO asyncy_visitor;

CREATE POLICY insert_admin ON team_apps FOR INSERT WITH CHECK
  (current_owner_has_organization_permission((SELECT owner_uuid FROM teams WHERE teams.uuid = team_uuid), 'ADMIN'));
GRANT INSERT ON team_apps TO asyncy_visitor;

CREATE POLICY delete_admin ON team_apps FOR DELETE USING
  (current_owner_has_organization_permission((SELECT owner_uuid FROM teams WHERE teams.uuid = team_uuid), 'ADMIN'));
GRANT DELETE ON team_apps TO asyncy_visitor;
