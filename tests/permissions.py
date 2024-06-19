from evafs.supabase_client import supabase_client

response = (
    supabase_client.table("resources")
    .select("parent,...valid_parent(parent:name)")
    .execute()
)

for x in response.data:
    print(x)
