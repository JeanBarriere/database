-- Trigger to abort if a team is inserted with a user-owner

CREATE OR REPLACE FUNCTION ensure_organization_owner_is_not_user() RETURNS TRIGGER AS $$
BEGIN

    IF EXISTS (SELECT 1 FROM app_public.owners WHERE uuid = NEW.owner_uuid AND is_user = TRUE LIMIT 1) THEN
      RAISE EXCEPTION 'Teams cannot be owned by users.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql VOLATILE;

DROP TRIGGER IF EXISTS _500_abort_on_team_owner_is_user ON teams;
CREATE TRIGGER _500_abort_on_team_owner_is_user
  BEFORE INSERT ON teams
  FOR EACH ROW
  EXECUTE PROCEDURE ensure_organization_owner_is_not_user();