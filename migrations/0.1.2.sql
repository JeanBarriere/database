-- https://github.com/storyscript/database/pull/87
/*

Add `service_tags.uuid` which is a new fk of `service_usage` table

*/

ALTER TABLE service_tags DROP CONSTRAINT service_tags_pkey;
ALTER TABLE service_tags ADD COLUMN uuid uuid DEFAULT uuid_generate_v4() PRIMARY KEY;
ALTER TABLE service_tags ADD CONSTRAINT service_tags_unique unique (service_uuid, tag);

ALTER TABLE service_usage DROP CONSTRAINT service_usage_pkey;
ALTER TABLE service_usage DROP COLUMN service_uuid;
ALTER TABLE service_usage DROP COLUMN tag;
ALTER TABLE service_usage ADD COLUMN service_tag_uuid uuid REFERENCES service_tags ON DELETE CASCADE PRIMARY KEY;

COMMENT on table service_usage is 'Resource usage metrics for services';
COMMENT on column service_usage.service_tag_uuid is 'The (service_uuid, image_tag) identifier';
COMMENT on column service_usage.memory_bytes is 'Circular queue storing memory bytes consumed';
COMMENT on column service_usage.cpu_units is 'Circular queue storing cpu units consumed';
COMMENT on column service_usage.next_index is 'Next index to be updated in the circular queues';

DROP POLICY select_public ON service_usage;

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
