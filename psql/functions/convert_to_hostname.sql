CREATE FUNCTION convert_to_hostname(name title) RETURNS text AS $$
  SELECT substring(
    regexp_replace(
      trim(
          both '-_' from
          lower(name)
      ),
      '[^\w\-\_]', '', 'gi'
    )
    from 1 for 256
  );
$$ LANGUAGE sql STABLE SET search_path FROM CURRENT;
