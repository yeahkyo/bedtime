import asyncio
from pathlib import Path
from uuid import uuid4

import boto3
from botocore.client import Config

from app.core.config import get_settings


class StorageService:
    def __init__(self) -> None:
        self.settings = get_settings()
        self.local_root = Path(__file__).resolve().parents[2] / ".data"
        self.local_root.mkdir(parents=True, exist_ok=True)

    def _s3(self):
        return boto3.client(
            "s3",
            endpoint_url=self.settings.s3_endpoint_url,
            aws_access_key_id=self.settings.s3_access_key,
            aws_secret_access_key=self.settings.s3_secret_key,
            region_name=self.settings.s3_region,
            config=Config(signature_version="s3v4"),
        )

    async def put_bytes(self, key: str, data: bytes, content_type: str) -> str:
        if self.settings.storage_backend == "local":
            path = self.local_root / key
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            return key

        def _put() -> None:
            self._s3().put_object(
                Bucket=self.settings.s3_bucket,
                Key=key,
                Body=data,
                ContentType=content_type,
            )

        await asyncio.to_thread(_put)
        return key

    async def get_bytes(self, key: str) -> bytes | None:
        if self.settings.storage_backend == "local":
            path = self.local_root / key
            if not path.is_file():
                return None
            return path.read_bytes()

        def _get() -> bytes | None:
            try:
                obj = self._s3().get_object(Bucket=self.settings.s3_bucket, Key=key)
            except Exception:
                return None
            body = obj.get("Body")
            if body is None:
                return None
            return body.read()

        return await asyncio.to_thread(_get)

    async def delete(self, key: str) -> None:
        if self.settings.storage_backend == "local":
            path = self.local_root / key
            if path.exists():
                path.unlink()
            return

        def _del() -> None:
            self._s3().delete_object(Bucket=self.settings.s3_bucket, Key=key)

        await asyncio.to_thread(_del)

    async def presigned_url(self, key: str, expires: int = 3600) -> str:
        if self.settings.storage_backend == "local":
            return f"/media/{key}"

        if self.settings.s3_public_base_url:
            return f"{self.settings.s3_public_base_url.rstrip('/')}/{key}"

        def _url() -> str:
            return self._s3().generate_presigned_url(
                "get_object",
                Params={"Bucket": self.settings.s3_bucket, "Key": key},
                ExpiresIn=expires,
            )

        return await asyncio.to_thread(_url)

    @staticmethod
    def new_key(prefix: str, suffix: str) -> str:
        return f"{prefix}/{uuid4().hex}{suffix}"


storage_service = StorageService()
