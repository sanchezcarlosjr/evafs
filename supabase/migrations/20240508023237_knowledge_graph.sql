CREATE OR REPLACE FUNCTION find_order(id text)
RETURNS SETOF relationships
LANGUAGE plpgsql
AS $$
BEGIN
   RETURN QUERY  WITH RECURSIVE TopologicalOrder AS (
     SELECT * FROM relationships r WHERE r.in = id
     UNION
     SELECT new_hop.* FROM TopologicalOrder previous_hop INNER JOIN relationships new_hop ON previous_hop.out = new_hop.in
   )
   SELECT * FROM TopologicalOrder;
END;
$$;


CREATE OR REPLACE FUNCTION is_compatible(id text, set_ids text[])
RETURNS bool
LANGUAGE plpgsql
AS $$
BEGIN
   RETURN NOT EXISTS (
      SELECT 1
      FROM find_order(id) AS r
      INNER JOIN langchain_pg_embedding lg ON r.out = lg.id
      WHERE lg.document != ANY(set_ids)
   );
END;
$$;



CREATE OR REPLACE FUNCTION task_scheduling(task_id text)
RETURNS TABLE(id text, task text, depends_on text[], cmetadata jsonb, getter text)
LANGUAGE plpgsql
AS $$
BEGIN
   RETURN QUERY SELECT lg.id::text, lg.document::text as task, array_agg(lg2.document::text) as depends_on, COALESCE(lg.cmetadata::jsonb||relationship.metadata::jsonb, lg.cmetadata::jsonb, relationship.metadata::jsonb), relationship.getter FROM find_order(task_id) relationship
    INNER JOIN langchain_pg_embedding lg ON relationship.out = lg.id
    INNER JOIN langchain_pg_embedding lg2 ON relationship.in = lg2.id
    GROUP BY lg.id, lg.document, relationship.order, lg.cmetadata, relationship.getter, relationship.metadata
    ORDER BY relationship.order;
END;
$$;
