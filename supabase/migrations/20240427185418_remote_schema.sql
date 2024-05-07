create policy "Give users authenticated access to folder 8bxmw9_0"
on "storage"."objects"
as permissive
for select
to public
using (((bucket_id = 'dependencies'::text) AND (auth.role() = 'authenticated'::text)));
