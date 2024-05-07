DROP FUNCTION IF EXISTS "public"."access"(resources);

create function access(resources) RETURNS SETOF "resource_permissions" rows 1 as $$
  select * from resource_permissions where resource_id = $1.name
$$ stable language sql;
