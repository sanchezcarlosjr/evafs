DROP FUNCTION IF EXISTS "public"."allowed_access"(resources);

create function allowed_access(resources) RETURNS SETOF "resource_permissions" rows 1 as $$
  select u.* from resource_permissions rp
           INNER JOIN auth.users u ON u.id = rp.user_id
           WHERE resource_id = $1.name
$$ stable language sql;
