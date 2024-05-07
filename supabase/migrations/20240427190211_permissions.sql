DROP FUNCTION IF EXISTS "public"."valid_parent"(resources);
DROP FUNCTION IF EXISTS "public"."children"(resources);

create function valid_parent(resources) RETURNS SETOF "resources" rows 1 as $$
  select * from resources where name = $1.parent
$$ stable language sql;


create function children(resources) RETURNS SETOF "resources" as $$
  select * from resources where parent = $1.name
$$ stable language sql;
