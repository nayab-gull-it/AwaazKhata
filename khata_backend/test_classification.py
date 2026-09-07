"""Tests for action classification (Qwen prompt + keyword fallback).

Run without Groq (keyword fallback only):
    python test_classification.py

Run with Groq (tests the real Qwen prompt too):
    GROQ_API_KEY=gsk_... python test_classification.py
"""

from __future__ import annotations

import asyncio
import json
import os
import sys

from main import SYSTEM_PROMPT, _keyword_fallback, _call_groq, lifespan

# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------

CASES = [
    # (transcript, expected_action, extra_check=None)
    # Primary targets from the task
    (
        "Ahmad ke khate mein 500 add karo",
        "add_udhaar",
        lambda r: r.get("customer_name", "").lower().startswith("ahm")
        and float(r.get("amount", 0)) == 500,
    ),
    (
        "5 bottle tel add karo",
        "add_inventory",
        lambda r: int(r.get("quantity", 0)) == 5
        and "bottle" in r.get("unit", "").lower(),
    ),
    (
        "chini restock karne ka task banao",
        "add_task",
        lambda r: "sugar" in r.get("title", "").lower()
        or "restock" in r.get("title", "").lower()
        or "chini" in r.get("title", "").lower(),
    ),

    # add_task priority — urgent phrasings should map to high
    (
        "urgent kaam hai, subah 9 baje uthna hai",
        "add_task",
        lambda r: r.get("priority") == "high",
    ),
    (
        "jaldi karna hai, abhi call karna hai Ahmad ko",
        "add_task",
        lambda r: r.get("priority") == "high",
    ),
    (
        "zaroori kaam hai, foran supplier se baat karo",
        "add_task",
        lambda r: r.get("priority") == "high",
    ),

    # add_task priority — non-urgent phrasings should stay normal
    (
        "kal subah 9 baje dukaan kholna hai",
        "add_task",
        lambda r: r.get("priority") == "normal",
    ),
    (
        "shaam ko supplier ko call karna yaad dilao",
        "add_task",
        lambda r: r.get("priority") == "normal",
    ),

    # query_balance — the new action type
    (
        "Ahmad ka kitna baaki hai",
        "query_balance",
        lambda r: r.get("customer_name", "").lower().startswith("ahm")
        and r.get("direction") == "outgoing",
    ),
    (
        "Sara se kitna lena hai",
        "query_balance",
        lambda r: r.get("customer_name", "").lower().startswith("sar")
        and r.get("direction") == "incoming",
    ),
    (
        "Bashir bhai ka balance batao",
        "query_balance",
        lambda r: r.get("customer_name", "").lower().startswith("bas"),
    ),
    (
        "Ali ke khate mein kitna hai",
        "query_balance",
        lambda r: r.get("customer_name", "").lower().startswith("ali"),
    ),
    (
        "Rashid ko kitna dena hai",
        "query_balance",
        lambda r: r.get("customer_name", "").lower().startswith("ras"),
    ),
    (
        "Nadia ka udhaar kitna ho gaya",
        "query_balance",
        lambda r: r.get("customer_name", "").lower().startswith("nad"),
    ),

    # reduce_udhaar — customer paid back / settled part of existing credit
    (
        "Ahmad Khan ka udhaar 500 kaat do",
        "reduce_udhaar",
        lambda r: r.get("customer_name", "").lower().startswith("ahmad")
        and float(r.get("amount", 0)) == 500,
    ),
    (
        "aaj Sara ne 400 wapas kiye hisab mein minus kar do",
        "reduce_udhaar",
        lambda r: r.get("customer_name", "").lower().startswith("sara")
        and float(r.get("amount", 0)) == 400,
    ),
    (
        "Bilal ne 1000 rupaye jama kiye",
        "reduce_udhaar",
        lambda r: r.get("customer_name", "").lower().startswith("bilal")
        and float(r.get("amount", 0)) == 1000,
    ),
    ("Ali ka udhaar clear kar do 700", "reduce_udhaar", None),
    ("Kamran ka 300 udhaar minus karo", "reduce_udhaar", None),

    # Query actions — direct answers, no navigation
    (
        "Tapal hai inventory mein?",
        "query_item_stock",
        lambda r: r.get("name", "").lower().startswith("tapal"),
    ),
    (
        "Nestle juice hai kya",
        "query_item_stock",
        lambda r: r.get("name", "").lower().startswith("nestle"),
    ),
    ("cheeni ka stock hai", "query_item_stock", None),
    (
        "Shan biryani kitne ki hai",
        "query_item_price",
        lambda r: r.get("name", "").lower().startswith("shan"),
    ),
    (
        "Tapal ka daam kya hai",
        "query_item_price",
        lambda r: r.get("name", "").lower().startswith("tapal"),
    ),
    ("kaunse item ka stock kam hai", "query_low_stock", None),
    ("kaunse item ka low stock hai", "query_low_stock", None),
    ("kitne items low stock mein hain", "query_low_stock", None),
    ("low stock items batao", "query_low_stock", None),
    ("stock kam hai kaunse item ka", "query_low_stock", None),
    ("total kitne item hain", "query_inventory_count", None),
    ("inventory mein kitne products hain", "query_inventory_count", None),

    # query_transactions_by_date — date-wise transaction read questions
    (
        "5 tareekh ko kaun se udhaar hue",
        "query_transactions_by_date",
        lambda r: len(r.get("date", "")) == 10 and r["date"].endswith("-05"),
    ),
    ("aaj kitne udhaar hue", "query_transactions_by_date", None),
    ("kal ke transactions batao", "query_transactions_by_date", None),
    ("3 September ka hisab dikhao", "query_transactions_by_date", None),

    # Regression guards: dates mentioned inside write/task commands must
    # not be swallowed by the date-query branch.
    ("aaj Sara ne 400 wapas kiye hisab mein minus kar do", "reduce_udhaar", None),
    ("kal subah 9 baje dukaan kholna hai", "add_task", None),

    # Boundary cases — make sure we didn't regress
    ("Ahmed ka udhaar 500 rupaye likho", "add_udhaar", None),
    ("paanch bottle tel add karo", "add_inventory", None),
    ("kal subah 9 baje dukaan kholna hai", "add_task", None),
    ("inventory dikhao", "navigate", lambda r: r.get("target_tab") == "inventory"),
    ("udhaar tab kholo", "navigate", lambda r: r.get("target_tab") == "udhaar"),
    ("tasks dikha do", "navigate", lambda r: r.get("target_tab") == "tasks"),
    ("Bashir bhai ko 1200 credit karo", "add_udhaar", None),
    ("shaam ko supplier ko call karna yaad dilao", "add_task", None),
    ("do pack sabun stock karo", "add_inventory", None),
]


def _check(transcript: str, expected: str, extra, result: dict, source: str) -> bool:
    actual = result.get("action")
    ok = actual == expected
    detail = ""
    if ok and extra is not None:
        try:
            ok = bool(extra(result))
        except Exception as e:  # noqa: BLE001
            ok = False
            detail = f" extra-check-err={e}"
        if not ok:
            detail = f" extra-check-failed result={json.dumps(result, ensure_ascii=False)}"

    mark = "PASS" if ok else "FAIL"
    print(f"[{mark}] {source:7s} | {transcript!r:55s} -> {actual:15s} (expected {expected}){detail}")
    return ok


async def _run_groq_with_timeout(transcript: str, timeout: float) -> dict:
    """Wrap _call_groq in asyncio.wait_for so a slow reasoning model can't hang the suite."""
    return await asyncio.wait_for(_call_groq(transcript), timeout=timeout)


async def run() -> int:
    results = {"pass": 0, "fail": 0}

    run_keyword = os.environ.get("_TEST_GROQ_ONLY") != "1"
    run_groq = os.environ.get("_TEST_KEYWORD_ONLY") != "1"
    per_call_timeout = float(os.environ.get("_TEST_TIMEOUT", "60") or "60")

    # 1. Keyword fallback
    if run_keyword:
        print("=== Keyword fallback ===")
        for transcript, expected, extra in CASES:
            result = _keyword_fallback(transcript)
            if _check(transcript, expected, extra, result, "keyword"):
                results["pass"] += 1
            else:
                results["fail"] += 1
    else:
        print("(--groq-only set — skipping keyword fallback)")

    # 2. Groq/Qwen (only if key provided and not disabled)
    from main import settings as _settings  # noqa: E402 (loaded after .env)
    api_key = _settings.groq_api_key or ""
    if run_groq and api_key and api_key != "gsk_your_key_here":
        print(f"\n=== Qwen via Groq (per-call timeout={per_call_timeout}s) ===")
        os.environ["GROQ_API_KEY"] = api_key
        from main import app  # noqa: F401  (import after env set)
        async with lifespan(app):
            for transcript, expected, extra in CASES:
                try:
                    result = await _run_groq_with_timeout(transcript, per_call_timeout)
                except asyncio.TimeoutError:
                    print(f"[FAIL] groq    | {transcript!r} -> TIMEOUT after {per_call_timeout}s")
                    results["fail"] += 1
                    continue
                except Exception as e:  # noqa: BLE001
                    print(f"[FAIL] groq    | {transcript!r} -> ERROR {e}")
                    results["fail"] += 1
                    continue
                if _check(transcript, expected, extra, result, "groq"):
                    results["pass"] += 1
                else:
                    results["fail"] += 1
    elif not run_groq:
        print("\n(--keyword-only set — skipping Qwen/Groq tests)")
    else:
        print("\n(GROQ_API_KEY not set — skipping Qwen/Groq tests)")

    print(f"\nTotal: {results['pass']} passed, {results['fail']} failed")
    return 0 if results["fail"] == 0 else 1


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--keyword-only", action="store_true")
    parser.add_argument("--groq-only", action="store_true")
    parser.add_argument("--per-call-timeout", type=float, default=60.0)
    args, _ = parser.parse_known_args()
    os.environ["_TEST_KEYWORD_ONLY"] = "1" if args.keyword_only else ""
    os.environ["_TEST_GROQ_ONLY"] = "1" if args.groq_only else ""
    os.environ["_TEST_TIMEOUT"] = str(args.per_call_timeout)
    sys.exit(asyncio.run(run()))
