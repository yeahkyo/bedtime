from app.services.errors import safe_error_message


def test_safe_error_message_hides_raw_exception_text():
    msg = safe_error_message(
        RuntimeError("sqlalchemy.exc.OperationalError: connection refused at 10.0.0.1"),
        fallback="Story generation failed",
    )
    assert msg == "Story generation failed"
    assert "sqlalchemy" not in msg
    assert "10.0.0.1" not in msg


def test_safe_error_message_maps_timeout():
    assert safe_error_message(TimeoutError("x")) == "Request timed out"


def test_safe_error_message_quota_hint():
    assert safe_error_message(Exception("monthly quota limit reached")) == "Quota exceeded"
