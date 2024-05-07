import logging
import os
import signal

import uvicorn
from fastapi import FastAPI
from gotrue import CodeExchangeParams

from evafs.auth_provider import auth
from evafs.supabase import supabase


def create_server_client():
    app = FastAPI()

    oauth_response = auth.login()
    print("Please this URL on this device to log in:")
    print(oauth_response.url)

    print("Waiting for authentication...")

    @app.get("/")
    def exchange_code_for_session(code: str):
        session = supabase.auth.exchange_code_for_session(
            CodeExchangeParams(auth_code=code, redirect_to="http://localhost:3001/")
        )
        print(f"✔  Success! Logged in as {session.user.email}")
        os.kill(os.getpid(), signal.SIGTERM)

    logging.getLogger("")
    uvicorn.run(app, host="0.0.0.0", port=3001, log_level=logging.FATAL)
