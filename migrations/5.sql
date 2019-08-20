-- Trigger to abort if a team is inserted with a user-owner

CREATE OR REPLACE FUNCTION assert_owner_is_organization() RETURNS TRIGGER AS $$
BEGIN

    IF EXISTS (SELECT 1 FROM app_public.owners WHERE uuid = NEW.owner_uuid AND is_user = TRUE LIMIT 1) THEN
      RAISE EXCEPTION 'Teams cannot be owned by users.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql STABLE;

DROP TRIGGER IF EXISTS _100_assert_owner_is_organization ON teams;
CREATE TRIGGER _100_assert_owner_is_organization
  BEFORE INSERT ON teams
  FOR EACH ROW
  EXECUTE PROCEDURE assert_owner_is_organization();
