
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE EXTENSION IF NOT EXISTS "timescaledb" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";

CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgsodium" WITH SCHEMA "pgsodium";

COMMENT ON SCHEMA "public" IS 'standard public schema';

CREATE EXTENSION IF NOT EXISTS "plv8" WITH SCHEMA "pg_catalog";

CREATE EXTENSION IF NOT EXISTS "fuzzystrmatch" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "http" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "insert_username" WITH SCHEMA "public";

CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";

CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA "extensions";


CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";

CREATE EXTENSION IF NOT EXISTS "tablefunc" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "unaccent" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "extensions";

CREATE TYPE "public"."access_level" AS ENUM (
    '*',
    'can_edit',
    'can_input',
    'can_comment',
    'can_view'
);

ALTER TYPE "public"."access_level" OWNER TO "postgres";

CREATE DOMAIN "public"."document_nano_id_domain" AS "text"
	CONSTRAINT "document_nano_id_domain_check" CHECK ((VALUE ~ '^d[0-9A-Za-z]{5,}(/\.inbox)?$'::"text"));

ALTER DOMAIN "public"."document_nano_id_domain" OWNER TO "postgres";

CREATE DOMAIN "public"."name_domain" AS "text"
	CONSTRAINT "name_domain_check" CHECK (((VALUE !~~* '%typecell%'::"text") AND (VALUE !~~* '%admin%'::"text") AND (("length"(VALUE) >= 3) AND ("length"(VALUE) <= 20)) AND (VALUE ~ '^[A-Za-z][A-Za-z0-9_]*$'::"text") AND (VALUE ~ '^([^_]*(_[^_]*)*)$'::"text")));

ALTER DOMAIN "public"."name_domain" OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."check_column_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.public_access_level IS DISTINCT FROM OLD.public_access_level THEN
    IF auth.uid() IS DISTINCT FROM OLD.user_id THEN
      RAISE EXCEPTION 'Cannot update column unless auth.uid() = user_id.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."check_column_update"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."check_document_access"("uid" "uuid", "doc_id" "uuid") RETURNS "public"."access_level"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    access access_level;
BEGIN
    -- Get the access for the current document
    SELECT p.access_level FROM document_permissions p WHERE p.user_id = uid AND document_id = doc_id INTO access;

    if access IS NOT NULL then
      RETURN access;
    end if;

    -- get access for parent, use MIN to take the most restrictive access.
    -- Note that this is a recursive function and could cause an infinite loop
    RETURN(
      SELECT MIN(check_document_access(uid, parent_id)) FROM document_relations r WHERE child_id = doc_id
    );
END;
$$;

ALTER FUNCTION "public"."check_document_access"("uid" "uuid", "doc_id" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."dependencies"() RETURNS "text"
    LANGUAGE "plv8"
    AS $$
    return `import "https://gradio.s3-us-west-2.amazonaws.com/4.23.0/gradio.js";
var j = function(t, e, n = !1) {
  (function(i, r, s, u, c, a) {
    i.hj = i.hj || function() {
      (i.hj.q = i.hj.q || []).push(arguments);
    }, i._hjSettings = { hjid: t, hjsv: e, hjDebug: n }, i._scriptPath = s + i._hjSettings.hjid + u + i._hjSettings.hjsv, document.querySelector(
      'script[src*="' + i._scriptPath + '"]'
    ) || (c = r.getElementsByTagName("head")[0], a = r.createElement("script"), a.async = 1, a.src = i._scriptPath, c.appendChild(a));
  })(window, document, "https://static.hotjar.com/c/hotjar-", ".js?sv=");
};
const h = j, o = (...t) => {
  if (!window.hj)
    throw new Error("Hotjar is not initialized");
  window.hj(...t);
};
var d = {
  hotjar: {
    initialize: function(e, n) {
      h(e, n);
    },
    initialized: function() {
      return typeof window < "u" && typeof (window == null ? void 0 : window.hj) == "function";
    },
    identify: function(e, n) {
      o("identify", e, n);
    },
    event: function(t) {
      o("event", t);
    },
    stateChange: function(e) {
      o("stateChange", e);
    }
  }
};
function f() {
  var t;
  (t = document.getElementById("evatutor-gradio-app")) == null || t.remove();
};
d.hotjar.initialize(3898484, 6);
function l(t) {
  d.hotjar.identify(t.identity.id, {}), t.widgets.addToolbarWidget({ label: "EvaTutor", component: \`<gradio-app id='evatutor-gradio-app' style="---button-secondary-border-color: transparent; --embed-radius: 0; " src="https://evatutor-space.sanchezcarlosjr.com/"></gradio-app>\` });
}
export {
  l as install,
  f as unmount
};
`;
$$;

ALTER FUNCTION "public"."dependencies"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."filesystem"() RETURNS "json"
    LANGUAGE "plv8"
    AS $$
    const objects = plv8.execute(
        'select name from storage.objects'
    );
    return {
      'supabase': objects.reduce((acc, value) => ({
        ...acc,
        [value.name]: ""
      }), {})
    };
$$;

ALTER FUNCTION "public"."filesystem"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."filesystem"("name" "text") RETURNS "json"
    LANGUAGE "plv8"
    AS $$
    const objects = plv8.execute(
        'select name from storage.objects'
    );
    const uid = plv8.execute(
        'select auth.uid()'
    );
    return {
      'home': uid
    };
$$;

ALTER FUNCTION "public"."filesystem"("name" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_messages"() RETURNS SETOF "storage"."objects"
    LANGUAGE "plv8"
    AS $$

    var json_result = plv8.execute(
        'select * from storage.objects'
    );

    return json_result;
$$;

ALTER FUNCTION "public"."get_messages"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_valid_parent"("parent_candidate" "text") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    valid_parent TEXT;
BEGIN
    -- Check if the parent_candidate exists in the resources table
    SELECT name INTO valid_parent
    FROM resources
    WHERE name = parent_candidate;

    -- If a matching name is found, return it; otherwise, return NULL
    IF FOUND THEN
        RETURN valid_parent;
    ELSE
        RETURN NULL;
    END IF;
END;
$$;

ALTER FUNCTION "public"."get_valid_parent"("parent_candidate" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."hello_world"("name" "text") RETURNS "text"
    LANGUAGE "plv8"
    AS $_$

    let output = `Hello, ${name}!`;
    return output;

$_$;

ALTER FUNCTION "public"."hello_world"("name" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."hello_world2"("name" "text") RETURNS "json"
    LANGUAGE "plv8"
    AS $$
    var json_result = plv8.execute(
        'select name from storage.objects'
    );
    return {
      'home': json_result.reduce((acc, value) => ({
        ...acc,
        [value.name]: null
      }), {})
    };
$$;

ALTER FUNCTION "public"."hello_world2"("name" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."store_default_permissions"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO resource_permissions(user_id, resource_id, access) VALUES (auth.uid(), NEW.name, '*');
    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."store_default_permissions"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."store_permissions"("people" "text"[], "permission" "public"."access_level") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    person TEXT;
    uid uuid;
BEGIN
    -- Loop through each email in the 'people' array
    FOREACH person IN ARRAY people
    LOOP
        -- Find the 'uid' for the current 'person' (email) from the 'users' table
        SELECT u.id INTO uid FROM users u WHERE u.email = person;

        -- Check if a UID was found before inserting
        IF uid IS NOT NULL THEN
            -- Insert a record into 'resource_permissions' table
            INSERT INTO resource_permissions(person, permission)
            VALUES (uid, permission);
        END IF;

        -- Reset uid for the next iteration
        uid := NULL;
    END LOOP;
END;
$$;

ALTER FUNCTION "public"."store_permissions"("people" "text"[], "permission" "public"."access_level") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."store_permissions"("people" "text"[], "resource_id" "uuid", "permission" "public"."access_level") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    person TEXT;
    uid uuid;
BEGIN
    -- Loop through each email in the 'people' array
    FOREACH person IN ARRAY people
    LOOP
        -- Find the 'uid' for the current 'person' (email) from the 'users' table
        SELECT u.id INTO uid FROM auth.users u WHERE u.email ILIKE person;

        -- Check if a UID was found before inserting
        IF uid IS NOT NULL THEN
            -- Insert a record into 'resource_permissions' table
            INSERT INTO resource_permissions(user_id, resource_id, access)
            VALUES (uid, resource_id, permission);
        END IF;

        -- Reset uid for the next iteration
        uid := NULL;
    END LOOP;
END;
$$;

ALTER FUNCTION "public"."store_permissions"("people" "text"[], "resource_id" "uuid", "permission" "public"."access_level") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."sync_web_with_permission_deletes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    DELETE FROM web WHERE name = OLD.resource_id AND user_id = OLD.user_id;
    UPDATE web
    SET parent = NULL
    WHERE parent = OLD.resource_id AND user_id = OLD.user_id;
    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."sync_web_with_permission_deletes"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."sync_web_with_permission_insertions"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
   v_name uuid;
   v_meta JSONB;
   v_parent uuid;
BEGIN
    SELECT name, meta,
           CASE
               WHEN parent IS NOT NULL AND parent IN (SELECT name FROM resources) THEN parent
               ELSE NULL
           END INTO v_name, v_meta, v_parent
    FROM resources
    WHERE name = NEW.resource_id;

    UPDATE web
    SET parent = NEW.resource_id
    WHERE web.user_id = NEW.user_id AND web.name IN (SELECT name FROM resources WHERE parent = NEW.resource_id);

    INSERT INTO web(name, meta, parent, user_id, access) VALUES (v_name, v_meta, v_parent, NEW.user_id, NEW.access);

    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."sync_web_with_permission_insertions"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."sync_web_with_permission_updates"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    UPDATE web
    SET access = NEW.access
    WHERE name = NEW.resource_id AND user_id = NEW.user_id;
    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."sync_web_with_permission_updates"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."sync_web_with_resource_updates"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.deleted = true THEN
       UPDATE web
       SET parent = null
       WHERE parent = NEW.name;
       DELETE FROM web WHERE name = NEW.name;
    ELSE
      UPDATE web
      SET meta = NEW.meta, parent = CASE WHEN NEW.parent IN (SELECT name FROM resources) THEN NEW.parent ELSE NULL END
      WHERE name = NEW.name;
    END IF;
    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."sync_web_with_resource_updates"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";

CREATE TABLE IF NOT EXISTS "public"."audit-logs" (
    "log_id" integer NOT NULL,
    "log_timestamp" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "resource" character varying(255),
    "resource_id" character varying(255),
    "action" character varying(50),
    "author_id" character varying(255),
    "author_name" character varying(255),
    "data" "jsonb",
    "previous_data" "jsonb"
);

ALTER TABLE "public"."audit-logs" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."audit-logs_log_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER TABLE "public"."audit-logs_log_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."audit-logs_log_id_seq" OWNED BY "public"."audit-logs"."log_id";

CREATE TABLE IF NOT EXISTS "public"."document_permissions" (
    "document_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "access_level" "public"."access_level" NOT NULL
);

ALTER TABLE "public"."document_permissions" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."document_relations" (
    "parent_id" "uuid" NOT NULL,
    "child_id" "uuid" NOT NULL
);

ALTER TABLE "public"."document_relations" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."documents" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "nano_id" "public"."document_nano_id_domain" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "data" "bytea" NOT NULL,
    "public_access_level" "public"."access_level" NOT NULL
);

ALTER TABLE "public"."documents" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."filesystem" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "object_id" "uuid" NOT NULL,
    "access_level" "public"."access_level" DEFAULT 'can_view'::"public"."access_level",
    "parent_id" bigint
);

ALTER TABLE "public"."filesystem" OWNER TO "postgres";

ALTER TABLE "public"."filesystem" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."filesystem_permissions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE TABLE IF NOT EXISTS "public"."resource_permissions" (
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "resource_id" "uuid" NOT NULL,
    "access" "public"."access_level" DEFAULT 'can_view'::"public"."access_level" NOT NULL
);

ALTER TABLE "public"."resource_permissions" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."resources" (
    "name" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "meta" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "parent" "uuid",
    "embeddings" "extensions"."vector"
);

ALTER TABLE "public"."resources" OWNER TO "postgres";

COMMENT ON COLUMN "public"."resources"."name" IS ' POSIX-compliant filesystem filename. :, ?, =, and & are forbbiden.';

CREATE TABLE IF NOT EXISTS "public"."web" (
    "name" "uuid" NOT NULL,
    "meta" "jsonb",
    "parent" "uuid",
    "user_id" "uuid" NOT NULL,
    "access" "public"."access_level"
);

ALTER TABLE "public"."web" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."workspaces" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "name" "public"."name_domain" NOT NULL,
    "owner_user_id" "uuid" NOT NULL,
    "is_username" boolean NOT NULL,
    "document_nano_id" "public"."document_nano_id_domain" NOT NULL
);

ALTER TABLE "public"."workspaces" OWNER TO "postgres";

ALTER TABLE ONLY "public"."audit-logs" ALTER COLUMN "log_id" SET DEFAULT "nextval"('"public"."audit-logs_log_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."audit-logs"
    ADD CONSTRAINT "audit-logs_pkey" PRIMARY KEY ("log_id");

ALTER TABLE ONLY "public"."document_permissions"
    ADD CONSTRAINT "document_permissions_document_id_user_id_key" UNIQUE ("document_id", "user_id");

ALTER TABLE ONLY "public"."document_relations"
    ADD CONSTRAINT "document_relations_parent_id_child_id_key" UNIQUE ("parent_id", "child_id");

ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_nano_id_key" UNIQUE ("nano_id");

ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."filesystem"
    ADD CONSTRAINT "filesystem_permissions_pkey" PRIMARY KEY ("id", "user_id", "object_id");

ALTER TABLE ONLY "public"."resource_permissions"
    ADD CONSTRAINT "resource_permissions_pkey" PRIMARY KEY ("user_id", "resource_id");

ALTER TABLE ONLY "public"."resources"
    ADD CONSTRAINT "resources_pkey" PRIMARY KEY ("name");

ALTER TABLE ONLY "public"."web"
    ADD CONSTRAINT "web_pkey" PRIMARY KEY ("name", "user_id");

ALTER TABLE ONLY "public"."workspaces"
    ADD CONSTRAINT "workspaces_pkey" PRIMARY KEY ("id");

CREATE UNIQUE INDEX "workspaces_name_key" ON "public"."workspaces" USING "btree" ("lower"(("name")::"text"));

CREATE UNIQUE INDEX "workspaces_owner_user_id_key" ON "public"."workspaces" USING "btree" ("owner_user_id") WHERE ("is_username" IS TRUE);

CREATE OR REPLACE TRIGGER "after_insert_resource" AFTER INSERT ON "public"."resources" FOR EACH ROW EXECUTE FUNCTION "public"."store_default_permissions"();

CREATE OR REPLACE TRIGGER "check_column_update_trigger" BEFORE UPDATE ON "public"."documents" FOR EACH ROW EXECUTE FUNCTION "public"."check_column_update"();

CREATE OR REPLACE TRIGGER "permissions_update_web" AFTER DELETE ON "public"."resource_permissions" FOR EACH ROW EXECUTE FUNCTION "public"."sync_web_with_permission_deletes"();

CREATE OR REPLACE TRIGGER "resources_update_web" AFTER UPDATE ON "public"."resources" FOR EACH ROW EXECUTE FUNCTION "public"."sync_web_with_resource_updates"();

CREATE OR REPLACE TRIGGER "web_insert" AFTER INSERT ON "public"."resource_permissions" FOR EACH ROW EXECUTE FUNCTION "public"."sync_web_with_permission_insertions"();

CREATE OR REPLACE TRIGGER "web_update" AFTER UPDATE ON "public"."resource_permissions" FOR EACH ROW EXECUTE FUNCTION "public"."sync_web_with_permission_updates"();

ALTER TABLE ONLY "public"."document_permissions"
    ADD CONSTRAINT "document_permissions_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "public"."documents"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."document_permissions"
    ADD CONSTRAINT "document_permissions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."document_relations"
    ADD CONSTRAINT "document_relations_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "public"."documents"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."document_relations"
    ADD CONSTRAINT "document_relations_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."documents"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."filesystem"
    ADD CONSTRAINT "public_filesystem_permissions_object_id_fkey" FOREIGN KEY ("object_id") REFERENCES "storage"."objects"("id");

ALTER TABLE ONLY "public"."filesystem"
    ADD CONSTRAINT "public_filesystem_permissions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."resource_permissions"
    ADD CONSTRAINT "public_resource_permissions_resource_id_fkey" FOREIGN KEY ("resource_id") REFERENCES "public"."resources"("name") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."resource_permissions"
    ADD CONSTRAINT "public_resource_permissions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."resources"
    ADD CONSTRAINT "public_resources_parent_fkey" FOREIGN KEY ("parent") REFERENCES "public"."resources"("name") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."workspaces"
    ADD CONSTRAINT "workspaces_document_nano_id_fkey" FOREIGN KEY ("document_nano_id") REFERENCES "public"."documents"("nano_id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."workspaces"
    ADD CONSTRAINT "workspaces_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

CREATE POLICY "Enable DELETE document_relations for users with write access on" ON "public"."document_relations" FOR DELETE TO "authenticated" USING (((( SELECT "documents"."public_access_level"
   FROM "public"."documents"
  WHERE ("documents"."id" = "document_relations"."parent_id")) >= 'can_comment'::"public"."access_level") OR (( SELECT "documents"."user_id"
   FROM "public"."documents"
  WHERE ("documents"."id" = "document_relations"."parent_id")) = "auth"."uid"()) OR ("public"."check_document_access"("auth"."uid"(), "parent_id") >= 'can_comment'::"public"."access_level")));

CREATE POLICY "Enable INSERT document_relations for users with write access on" ON "public"."document_relations" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "documents"."public_access_level"
   FROM "public"."documents"
  WHERE ("documents"."id" = "document_relations"."parent_id")) >= 'can_comment'::"public"."access_level") OR (( SELECT "documents"."user_id"
   FROM "public"."documents"
  WHERE ("documents"."id" = "document_relations"."parent_id")) = "auth"."uid"()) OR ("public"."check_document_access"("auth"."uid"(), "parent_id") >= 'can_comment'::"public"."access_level")));

CREATE POLICY "Enable SELECT document_relations for users with write access on" ON "public"."document_relations" FOR SELECT TO "authenticated" USING (((( SELECT "documents"."public_access_level"
   FROM "public"."documents"
  WHERE ("documents"."id" = "document_relations"."parent_id")) >= 'can_comment'::"public"."access_level") OR (( SELECT "documents"."user_id"
   FROM "public"."documents"
  WHERE ("documents"."id" = "document_relations"."parent_id")) = "auth"."uid"()) OR ("public"."check_document_access"("auth"."uid"(), "parent_id") >= 'can_comment'::"public"."access_level")));

CREATE POLICY "Enable UPDATE document_relations for users with write access on" ON "public"."document_relations" FOR UPDATE TO "authenticated" USING (((( SELECT "documents"."public_access_level"
   FROM "public"."documents"
  WHERE ("documents"."id" = "document_relations"."parent_id")) >= 'can_comment'::"public"."access_level") OR (( SELECT "documents"."user_id"
   FROM "public"."documents"
  WHERE ("documents"."id" = "document_relations"."parent_id")) = "auth"."uid"()) OR ("public"."check_document_access"("auth"."uid"(), "parent_id") >= 'can_comment'::"public"."access_level")));

CREATE POLICY "Enable all actions for users based on user_id" ON "public"."filesystem" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));

CREATE POLICY "Enable all operations for root" ON "public"."resource_permissions" USING (("auth"."uid"() = '421e1e4c-ea58-4a6b-867b-38b1618f743d'::"uuid")) WITH CHECK (("auth"."uid"() = '421e1e4c-ea58-4a6b-867b-38b1618f743d'::"uuid"));

CREATE POLICY "Enable all operations for root" ON "public"."resources" USING (("auth"."uid"() = '421e1e4c-ea58-4a6b-867b-38b1618f743d'::"uuid")) WITH CHECK (("auth"."uid"() = '421e1e4c-ea58-4a6b-867b-38b1618f743d'::"uuid"));

CREATE POLICY "Enable delete for users based on user_id" ON "public"."documents" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));

CREATE POLICY "Enable insert for authenticated users only" ON "public"."documents" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));

CREATE POLICY "Enable insert for authenticated users only" ON "public"."resource_permissions" FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "Enable insert for authenticated users only" ON "public"."resources" FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable insert for authenticated users only" ON "public"."workspaces" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "owner_user_id"));

CREATE POLICY "Enable read access for all users" ON "public"."documents" FOR SELECT USING ((("public_access_level" >= 'can_edit'::"public"."access_level") OR ("auth"."uid"() = "user_id") OR ("public"."check_document_access"("auth"."uid"(), "id") >= 'can_edit'::"public"."access_level")));

CREATE POLICY "Enable read access for all users" ON "public"."resource_permissions" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));

CREATE POLICY "Enable read access for all users" ON "public"."web" FOR SELECT USING (("user_id" = "auth"."uid"()));

CREATE POLICY "Enable read access for all users" ON "public"."workspaces" FOR SELECT USING (true);

CREATE POLICY "Enable read access for users with permissions" ON "public"."resources" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."resource_permissions"
  WHERE (("resources"."name" = "resource_permissions"."resource_id") AND (("auth"."uid"() = "resource_permissions"."user_id") AND ("resources"."deleted" = false))))));

CREATE POLICY "Enable update for authenticated users only" ON "public"."documents" FOR UPDATE TO "authenticated" USING ((("public_access_level" >= 'can_comment'::"public"."access_level") OR ("auth"."uid"() = "user_id") OR ("public"."check_document_access"("auth"."uid"(), "id") >= 'can_comment'::"public"."access_level"))) WITH CHECK (true);

CREATE POLICY "Enable update for users based on permissions" ON "public"."resources" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."resource_permissions"
  WHERE (("resources"."name" = "resource_permissions"."resource_id") AND ("auth"."uid"() = "resource_permissions"."user_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."resource_permissions"
  WHERE (("resources"."name" = "resource_permissions"."resource_id") AND ("auth"."uid"() = "resource_permissions"."user_id")))));

ALTER TABLE "public"."audit-logs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."document_permissions" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "document_permissions_delete_policy" ON "public"."document_permissions" FOR DELETE TO "authenticated" USING ((( SELECT "documents"."user_id"
   FROM "public"."documents"
  WHERE ("documents"."id" = "document_permissions"."document_id")) = "auth"."uid"()));

CREATE POLICY "document_permissions_insert_policy" ON "public"."document_permissions" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "documents"."user_id"
   FROM "public"."documents"
  WHERE ("documents"."id" = "document_permissions"."document_id")) = "auth"."uid"()));

CREATE POLICY "document_permissions_select_policy" ON "public"."document_permissions" FOR SELECT TO "authenticated" USING ((( SELECT "documents"."user_id"
   FROM "public"."documents"
  WHERE ("documents"."id" = "document_permissions"."document_id")) = "auth"."uid"()));

CREATE POLICY "document_permissions_update_policy" ON "public"."document_permissions" FOR UPDATE TO "authenticated" USING ((( SELECT "documents"."user_id"
   FROM "public"."documents"
  WHERE ("documents"."id" = "document_permissions"."document_id")) = "auth"."uid"()));

ALTER TABLE "public"."document_relations" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."documents" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."filesystem" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."resource_permissions" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."resources" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."web" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."workspaces" ENABLE ROW LEVEL SECURITY;

ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";

ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."web";

GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

GRANT ALL ON FUNCTION "public"."check_column_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_column_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_column_update"() TO "service_role";

GRANT ALL ON FUNCTION "public"."check_document_access"("uid" "uuid", "doc_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_document_access"("uid" "uuid", "doc_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_document_access"("uid" "uuid", "doc_id" "uuid") TO "service_role";

GRANT ALL ON FUNCTION "public"."dependencies"() TO "anon";
GRANT ALL ON FUNCTION "public"."dependencies"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."dependencies"() TO "service_role";

GRANT ALL ON FUNCTION "public"."filesystem"() TO "anon";
GRANT ALL ON FUNCTION "public"."filesystem"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."filesystem"() TO "service_role";

GRANT ALL ON FUNCTION "public"."filesystem"("name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."filesystem"("name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."filesystem"("name" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_messages"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_messages"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_messages"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_valid_parent"("parent_candidate" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_valid_parent"("parent_candidate" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_valid_parent"("parent_candidate" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."hello_world"("name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."hello_world"("name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hello_world"("name" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."hello_world2"("name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."hello_world2"("name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hello_world2"("name" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."insert_username"() TO "postgres";
GRANT ALL ON FUNCTION "public"."insert_username"() TO "anon";
GRANT ALL ON FUNCTION "public"."insert_username"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."insert_username"() TO "service_role";

GRANT ALL ON FUNCTION "public"."store_default_permissions"() TO "anon";
GRANT ALL ON FUNCTION "public"."store_default_permissions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."store_default_permissions"() TO "service_role";

GRANT ALL ON FUNCTION "public"."store_permissions"("people" "text"[], "permission" "public"."access_level") TO "anon";
GRANT ALL ON FUNCTION "public"."store_permissions"("people" "text"[], "permission" "public"."access_level") TO "authenticated";
GRANT ALL ON FUNCTION "public"."store_permissions"("people" "text"[], "permission" "public"."access_level") TO "service_role";

GRANT ALL ON FUNCTION "public"."store_permissions"("people" "text"[], "resource_id" "uuid", "permission" "public"."access_level") TO "anon";
GRANT ALL ON FUNCTION "public"."store_permissions"("people" "text"[], "resource_id" "uuid", "permission" "public"."access_level") TO "authenticated";
GRANT ALL ON FUNCTION "public"."store_permissions"("people" "text"[], "resource_id" "uuid", "permission" "public"."access_level") TO "service_role";

GRANT ALL ON FUNCTION "public"."sync_web_with_permission_deletes"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_web_with_permission_deletes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_web_with_permission_deletes"() TO "service_role";

GRANT ALL ON FUNCTION "public"."sync_web_with_permission_insertions"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_web_with_permission_insertions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_web_with_permission_insertions"() TO "service_role";

GRANT ALL ON FUNCTION "public"."sync_web_with_permission_updates"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_web_with_permission_updates"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_web_with_permission_updates"() TO "service_role";

GRANT ALL ON FUNCTION "public"."sync_web_with_resource_updates"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_web_with_resource_updates"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_web_with_resource_updates"() TO "service_role";

GRANT ALL ON TABLE "public"."audit-logs" TO "anon";
GRANT ALL ON TABLE "public"."audit-logs" TO "authenticated";
GRANT ALL ON TABLE "public"."audit-logs" TO "service_role";

GRANT ALL ON SEQUENCE "public"."audit-logs_log_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."audit-logs_log_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."audit-logs_log_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."document_permissions" TO "anon";
GRANT ALL ON TABLE "public"."document_permissions" TO "authenticated";
GRANT ALL ON TABLE "public"."document_permissions" TO "service_role";

GRANT ALL ON TABLE "public"."document_relations" TO "anon";
GRANT ALL ON TABLE "public"."document_relations" TO "authenticated";
GRANT ALL ON TABLE "public"."document_relations" TO "service_role";

GRANT ALL ON TABLE "public"."documents" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE ON TABLE "public"."documents" TO "authenticated";
GRANT ALL ON TABLE "public"."documents" TO "service_role";

GRANT UPDATE("updated_at") ON TABLE "public"."documents" TO "authenticated";

GRANT UPDATE("data") ON TABLE "public"."documents" TO "authenticated";

GRANT UPDATE("public_access_level") ON TABLE "public"."documents" TO "authenticated";

GRANT ALL ON TABLE "public"."filesystem" TO "anon";
GRANT ALL ON TABLE "public"."filesystem" TO "authenticated";
GRANT ALL ON TABLE "public"."filesystem" TO "service_role";

GRANT ALL ON SEQUENCE "public"."filesystem_permissions_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."filesystem_permissions_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."filesystem_permissions_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."resource_permissions" TO "anon";
GRANT ALL ON TABLE "public"."resource_permissions" TO "authenticated";
GRANT ALL ON TABLE "public"."resource_permissions" TO "service_role";

GRANT ALL ON TABLE "public"."resources" TO "anon";
GRANT ALL ON TABLE "public"."resources" TO "authenticated";
GRANT ALL ON TABLE "public"."resources" TO "service_role";

GRANT ALL ON TABLE "public"."web" TO "anon";
GRANT ALL ON TABLE "public"."web" TO "authenticated";
GRANT ALL ON TABLE "public"."web" TO "service_role";

GRANT ALL ON TABLE "public"."workspaces" TO "anon";
GRANT ALL ON TABLE "public"."workspaces" TO "authenticated";
GRANT ALL ON TABLE "public"."workspaces" TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";

RESET ALL;
