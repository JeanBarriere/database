ALTER TABLE services ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_public ON services FOR SELECT USING (public);
CREATE POLICY select_own ON services FOR SELECT USING (owner_uuid = current_owner_uuid());
CREATE POLICY select_organization ON services FOR SELECT USING (owner_uuid = ANY (current_owner_organization_uuids()));
GRANT SELECT ON services TO asyncy_visitor;

---

ALTER TABLE service_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_tag ON service_tags FOR SELECT USING (EXISTS(SELECT 1 FROM services WHERE services.uuid = service_tags.service_uuid));
GRANT SELECT ON service_tags TO asyncy_visitor;

---

ALTER TABLE service_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_all ON service_categories FOR SELECT USING (true);
GRANT SELECT ON service_categories TO asyncy_visitor;

---

ALTER TABLE service_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_all ON service_plans FOR SELECT USING (true);
GRANT SELECT ON service_plans TO asyncy_visitor;

-- Do not grant INSERT, UPDATE, DELETE - these permissions are managed by the system, not users.

---

ALTER TABLE service_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_public_or_own on service_usage FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM service_tags
        INNER JOIN services on services.uuid = service_tags.service_uuid
        WHERE service_tags.uuid = service_usage.service_tag_uuid
          AND (
              services.public
              OR services.owner_uuid = current_owner_uuid()
          )
    )
);

GRANT SELECT ON service_usage to asyncy_visitor;
