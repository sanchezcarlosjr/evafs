from evafs.supabase import supabase

response = (
    supabase.table("resources").select("parent,...valid_parent(parent:name)").execute()
)

for x in response.data:
    print(x)
