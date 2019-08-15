-- Trigger to abort if a team is inserted with a user-owner

CREATE TRIGGER _500_abort_on_team_owner_is_user
  BEFORE INSERT ON teams
  FOR EACH ROW
  WHEN (NEW.is_user IS TRUE)
  EXECUTE PROCEDURE abort_with_errorcode('400', 'Teams cannot be owned by users.');
