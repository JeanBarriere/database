ALTER TABLE random_words ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_words ON random_words FOR SELECT USING (true);
GRANT SELECT ON random_words TO asyncy_visitor;
