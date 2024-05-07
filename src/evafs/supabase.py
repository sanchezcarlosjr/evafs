from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

from supabase import Client, ClientOptions, create_client


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")
    root_dir: str = Field()
    supabase_url: str = Field()
    supabase_key: str = Field()


settings = Settings()

supabase: Client = create_client(
    settings.supabase_url,
    settings.supabase_key,
    options=ClientOptions(flow_type="pkce"),
)
