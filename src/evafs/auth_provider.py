from evafs.supabase import supabase


class Auth:
    def login(self):
        oauth_response = supabase.auth.sign_in_with_oauth({"provider": "github"})
        return oauth_response


auth = Auth()
