import logging
import os

import psutil
import uvicorn
from fastapi import FastAPI
from gotrue import CodeExchangeParams
from rich import print

from evafs.supabase_client import supabase_client


class Auth:
    def request_authorization(self, provider):
        oauth_response = supabase_client.auth.sign_in_with_oauth({"provider": provider})
        return oauth_response

    def get_session(self):
        return supabase_client.auth.get_session()

    def logout(self):
        supabase_client.auth.sign_out()
        print("✔  [bold green]Success![/bold green] Logged out")

    def login(self, provider):
        if (session := self.get_session()) is not None:
            print(f"Already logged in as [bold]{session.user.email}[bold]")
            return
        app = FastAPI()

        oauth_response = self.request_authorization(provider)
        print("Please this URL on this device to log in:")
        print(oauth_response.url)

        print("Waiting for authentication...")

        @app.get("/")
        def exchange_code_for_session(code: str):
            session = supabase_client.auth.exchange_code_for_session(
                CodeExchangeParams(auth_code=code, redirect_to="http://localhost:3001/")
            )
            print(
                f"✔  [bold green]Success![/bold green] Logged in as [bold]{session.user.email}[bold]"
            )
            parent_pid = os.getpid()
            parent = psutil.Process(parent_pid)
            for child in parent.children(recursive=True):
                child.kill()
            parent.kill()

        uvicorn.run(app, host="0.0.0.0", port=3001, log_level=logging.FATAL)


auth = Auth()
