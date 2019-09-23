CREATE TABLE app_public.external_service_metadata(
    service_uuid            uuid primary key references app_public.services on delete cascade not null,
    document_uri            text not null,
    properties              jsonb not null,
    last_seen_hash          text not null
);

COMMENT on column external_service_metadata.document_uri is 'The URI of the OpenAPI document';
COMMENT on column external_service_metadata.properties is 'The properties submitted at service creation, provided to the OMG converter alongside the document';
COMMENT on column external_service_metadata.last_seen_hash is 'The hash of the document when last converted (in either success or failure cases)';
