import pytest

from app.core.config import (
    DEFAULT_JWT_SECRET,
    Settings,
    SettingsValidationError,
    validate_settings_for_runtime,
)


def test_dev_allows_default_jwt_secret():
    s = Settings(
        env="dev",
        jwt_secret=DEFAULT_JWT_SECRET,
        dev_auth_bypass=True,
    )
    validate_settings_for_runtime(s)


def test_non_dev_rejects_default_jwt_secret():
    s = Settings(
        env="prod",
        jwt_secret=DEFAULT_JWT_SECRET,
        dev_auth_bypass=False,
    )
    with pytest.raises(SettingsValidationError, match="JWT_SECRET"):
        validate_settings_for_runtime(s)


def test_non_dev_rejects_dev_auth_bypass():
    s = Settings(
        env="staging",
        jwt_secret="a-strong-secret-value",
        dev_auth_bypass=True,
    )
    with pytest.raises(SettingsValidationError, match="DEV_AUTH_BYPASS"):
        validate_settings_for_runtime(s)


def test_non_dev_rejects_local_storage():
    s = Settings(
        env="prod",
        jwt_secret="a-strong-secret-value",
        dev_auth_bypass=False,
        storage_backend="local",
        retention_admin_token="admin-token",
        admin_bootstrap_password="admin-pass",
    )
    with pytest.raises(SettingsValidationError, match="STORAGE_BACKEND"):
        validate_settings_for_runtime(s)


def test_non_dev_rejects_missing_retention_admin_token():
    s = Settings(
        env="staging",
        jwt_secret="a-strong-secret-value",
        dev_auth_bypass=False,
        storage_backend="s3",
        retention_admin_token="",
        admin_bootstrap_password="admin-pass",
    )
    with pytest.raises(SettingsValidationError, match="RETENTION_ADMIN_TOKEN"):
        validate_settings_for_runtime(s)


def test_non_dev_rejects_missing_admin_bootstrap_password():
    s = Settings(
        env="prod",
        jwt_secret="a-strong-secret-value",
        dev_auth_bypass=False,
        storage_backend="s3",
        retention_admin_token="admin-token",
        admin_bootstrap_password="",
    )
    with pytest.raises(SettingsValidationError, match="ADMIN_BOOTSTRAP_PASSWORD"):
        validate_settings_for_runtime(s)


def test_non_dev_ok_with_safe_settings():
    s = Settings(
        env="prod",
        jwt_secret="a-strong-secret-value",
        dev_auth_bypass=False,
        storage_backend="s3",
        retention_admin_token="admin-token",
        admin_bootstrap_password="admin-pass",
    )
    validate_settings_for_runtime(s)


def test_api_docs_enabled_only_in_dev_when_flag_on():
    assert Settings(env="dev", expose_api_docs=True).api_docs_enabled is True
    assert Settings(env="dev", expose_api_docs=False).api_docs_enabled is False
    assert Settings(env="staging", expose_api_docs=True).api_docs_enabled is False
    assert Settings(env="prod", expose_api_docs=True).api_docs_enabled is False
