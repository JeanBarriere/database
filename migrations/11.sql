DROP POLICY select_all ON owners;
CREATE POLICY select_own ON owners FOR SELECT USING (uuid = current_owner_uuid());
