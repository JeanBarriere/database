-- Note that although we reference the search_terms_to_tsquery function twice
-- here, PostgreSQL will notice it's IMMUTABLE and will (probably) memoize the
-- first call.

CREATE FUNCTION search_services(search_terms text) RETURNS SETOF services AS $$
  SELECT
    services.*
  FROM
    services
  LEFT JOIN service_categories sc on services.category = sc.uuid
  INNER JOIN owners on services.owner_uuid = owners.uuid
  WHERE
    services.tsvector @@ app_hidden.search_terms_to_tsquery('simple', search_terms)
    OR sc.title ILIKE concat('%', search_terms, '%')
    OR services.name ILIKE concat('%', search_terms, '%')
    OR owners.name ILIKE concat('%', search_terms, '%')
    OR description ILIKE concat('%', search_terms, '%')
  ORDER BY
    ts_rank(services.tsvector, app_hidden.search_terms_to_tsquery('simple', search_terms)) DESC,
    services.uuid DESC;
$$ LANGUAGE sql STABLE SET search_path FROM CURRENT;
