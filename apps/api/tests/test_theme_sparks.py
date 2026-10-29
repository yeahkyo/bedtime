"""Theme spark catalog helpers."""

from app.services.theme_sparks import DEFAULT_SPARKS, normalize_spark_language


def test_normalize_spark_language():
    assert normalize_spark_language("zh_CN") == "zh"
    assert normalize_spark_language("zh-TW") == "zh"
    assert normalize_spark_language("en") == "en"
    assert normalize_spark_language("en_US") == "en"
    assert normalize_spark_language(None) == "zh"


def test_default_sparks_include_bedtime_seed():
    assert "我不想睡觉" in DEFAULT_SPARKS["zh"]
    assert "I don't want to sleep" in DEFAULT_SPARKS["en"]
    assert all(1 <= len(t) <= 40 for texts in DEFAULT_SPARKS.values() for t in texts)
