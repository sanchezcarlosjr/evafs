from typing import Optional

import keyring
from gotrue import SyncSupportedStorage
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

from supabase import Client, ClientOptions, create_client


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="allow"
    )
    root_dir: str = Field()
    supabase_url: str = Field()
    supabase_key: str = Field()


settings = Settings()


class KeyringMemoryStorage(SyncSupportedStorage):
    def __init__(self):
        self.service = "system"

    def get_item(self, key: str) -> Optional[str]:
        return keyring.get_password(self.service, key)

    def set_item(self, key: str, value: str) -> None:
        keyring.set_password(self.service, key, value)

    def remove_item(self, key: str) -> None:
        keyring.delete_password(self.service, key)
        return None


supabase_client: Client = create_client(
    settings.supabase_url,
    settings.supabase_key,
    options=ClientOptions(flow_type="pkce", storage=KeyringMemoryStorage()),
)
