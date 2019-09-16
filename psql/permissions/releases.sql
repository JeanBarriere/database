ALTER TABLE releases ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_app ON releases FOR SELECT USING (EXISTS(SELECT 1 FROM apps WHERE apps.uuid = releases.app_uuid));
GRANT SELECT ON releases TO asyncy_visitor;

CREATE POLICY insert_permission ON releases FOR INSERT WITH CHECK (current_owner_has_app_permission(releases.app_uuid, 'CREATE_RELEASE'));
GRANT INSERT (app_uuid, config, message, payload, always_pull_images, source) ON releases TO asyncy_visitor;
