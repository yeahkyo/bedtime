"""Chat usage parsing for admin story metrics."""

from app.providers.chat_usage import (
    ChatOutcome,
    coerce_chat_outcome,
    merge_job_metrics,
    merge_metrics_dicts,
    merge_stage_rows,
    metrics_payload,
    outcome_from_response,
    parse_chat_usage,
    parse_metrics_json,
)


def test_parse_usage_with_reasoning_details():
    data = {
        "usage": {
            "prompt_tokens": 100,
            "completion_tokens": 250,
            "total_tokens": 350,
            "completion_tokens_details": {"reasoning_tokens": 80},
        }
    }
    u = parse_chat_usage(data)
    assert u["prompt_tokens"] == 100
    assert u["completion_tokens"] == 250
    assert u["total_tokens"] == 350
    assert u["reasoning_tokens"] == 80


def test_outcome_from_response_and_coerce():
    data = {"usage": {"prompt_tokens": 1, "completion_tokens": 2, "total_tokens": 3}}
    out = outcome_from_response(data, '{"ok":true}')
    assert out.content.startswith("{")
    assert out.prompt_tokens == 1
    assert coerce_chat_outcome("raw").content == "raw"
    assert coerce_chat_outcome(out) is out


def test_metrics_payload_sums_stages():
    stages = [
        {"stage": "plan", "ms": 100, "prompt_tokens": 10, "completion_tokens": 20, "total_tokens": 30},
        {"stage": "draft", "ms": 200, "prompt_tokens": 5, "completion_tokens": 15, "total_tokens": 20},
    ]
    m = metrics_payload(stages=stages, pipeline_ms=300)
    assert m["pipeline_ms"] == 300
    assert m["prompt_tokens"] == 15
    assert m["completion_tokens"] == 35
    assert m["total_tokens"] == 50


def test_merge_job_metrics():
    m = merge_job_metrics(
        {"pipeline_ms": 100, "total_tokens": 9},
        llm_ms=120,
        tts_ms=50,
        storage_ms=10,
        total_ms=200,
    )
    assert m["llm_ms"] == 120
    assert m["tts_ms"] == 50
    assert m["total_ms"] == 200
    assert m["total_tokens"] == 9


def test_chat_outcome_usage_dict_omits_none():
    o = ChatOutcome(content="x", prompt_tokens=1, completion_tokens=None)
    assert o.usage_dict() == {"prompt_tokens": 1}


def test_merge_stage_rows_keeps_real_over_skipped():
    prior = [
        {"stage": "episode_plan", "ms": 1200, "total_tokens": 100},
    ]
    newer = [
        {"stage": "episode_plan", "ms": 0, "skipped": True, "reason": "resume_saved_plan"},
        {"stage": "draft", "ms": 800, "total_tokens": 50},
    ]
    merged = merge_stage_rows(prior, newer)
    assert [r["stage"] for r in merged] == ["episode_plan", "draft"]
    assert merged[0]["ms"] == 1200
    assert not merged[0].get("skipped")
    assert merged[1]["ms"] == 800


def test_merge_metrics_dicts_across_retry():
    prior = parse_metrics_json(
        '{"stages":[{"stage":"episode_plan","ms":1000,"prompt_tokens":10,'
        '"completion_tokens":20,"total_tokens":30}]}'
    )
    newer = metrics_payload(
        stages=[
            {
                "stage": "episode_plan",
                "ms": 0,
                "skipped": True,
                "reason": "resume_saved_plan",
            },
            {
                "stage": "draft",
                "ms": 2000,
                "prompt_tokens": 5,
                "completion_tokens": 15,
                "total_tokens": 20,
            },
        ],
        pipeline_ms=2100,
    )
    m = merge_metrics_dicts(prior, newer, llm_ms=2100)
    assert [r["stage"] for r in m["stages"]] == ["episode_plan", "draft"]
    assert m["stages"][0]["ms"] == 1000
    assert m["total_tokens"] == 50
    assert m["llm_ms"] == 1000 + 2100
    assert m["pipeline_ms"] == 2100
