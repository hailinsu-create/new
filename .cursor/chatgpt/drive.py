#!/usr/bin/env python3
"""Drive ChatGPT web via existing Chrome CDP. Uses chatgpt.com web quota."""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.request
from pathlib import Path

from playwright.sync_api import sync_playwright


CDP = os.environ.get("CHATGPT_CDP_URL", "http://127.0.0.1:9222")
CHAT_URL = os.environ.get("CHATGPT_URL", "https://chatgpt.com")


def cdp_up() -> bool:
    try:
        with urllib.request.urlopen(f"{CDP}/json/version", timeout=2) as r:
            return r.status == 200
    except Exception:
        return False


def looks_logged_in(page) -> bool:
    url = page.url or ""
    if "auth" in url and "login" in url:
        return False
    # Logged-in UIs expose a composer / prompt textarea
    for sel in (
        "textarea#prompt-textarea",
        "div#prompt-textarea",
        '[data-testid="composer-input"]',
        "textarea[placeholder*='Message']",
        "div[contenteditable='true']",
    ):
        try:
            if page.locator(sel).first.count() > 0:
                return True
        except Exception:
            pass
    body = ""
    try:
        body = page.locator("body").inner_text(timeout=3000)[:2000]
    except Exception:
        pass
    if re.search(r"\b(Log in|Sign up|Sign in)\b", body, re.I) and "Log out" not in body:
        return False
    return "Log in" not in body[:500]


def find_composer(page):
    selectors = [
        "textarea#prompt-textarea",
        "div#prompt-textarea",
        '[data-testid="composer-input"]',
        "div[contenteditable='true']",
        "textarea",
    ]
    for sel in selectors:
        loc = page.locator(sel).first
        try:
            if loc.count() > 0 and loc.is_visible():
                return loc
        except Exception:
            continue
    return None


def try_enable_thinking(page) -> None:
    """Best-effort: open tools / model picker and pick a thinking / highest option."""
    labels = [
        "Thinking",
        "Think longer",
        "Pro",
        "o3",
        "o4",
        "GPT-5",
        "最高",
        "深度思考",
    ]
    for text in labels:
        try:
            btn = page.get_by_role("button", name=re.compile(text, re.I)).first
            if btn.count() and btn.is_visible():
                btn.click(timeout=1500)
                page.wait_for_timeout(400)
        except Exception:
            continue


def extract_last_assistant(page) -> str:
    # Prefer markdown/assistant message blocks
    candidates = [
        '[data-message-author-role="assistant"]',
        'div[data-testid^="conversation-turn"]',
        "article",
    ]
    for sel in candidates:
        locs = page.locator(sel)
        try:
            n = locs.count()
        except Exception:
            n = 0
        if n:
            try:
                return locs.nth(n - 1).inner_text(timeout=5000).strip()
            except Exception:
                pass
    try:
        return page.locator("main").inner_text(timeout=5000)[-8000:].strip()
    except Exception:
        return ""


def wait_generation(page, timeout_s: float) -> None:
    end = time.time() + timeout_s
    # Wait for stop button to appear then disappear, or composer to re-enable
    while time.time() < end:
        try:
            stop = page.get_by_role("button", name=re.compile(r"Stop|停止", re.I))
            if stop.count() and stop.first.is_visible():
                page.wait_for_timeout(800)
                continue
        except Exception:
            pass
        # If we previously saw streaming, a quiet period means done
        page.wait_for_timeout(1200)
        try:
            stop = page.get_by_role("button", name=re.compile(r"Stop|停止", re.I))
            if not (stop.count() and stop.first.is_visible()):
                return
        except Exception:
            return
    raise TimeoutError("chatgpt generation timeout")


def run(mode: str, request_text: str, out_path: Path, timeout_s: float) -> int:
    if not cdp_up():
        print("chatgpt:unavailable CDP not up", file=sys.stderr)
        return 2

    prefix = {
        "plan": (
            "You are PLAN for a Cursor Cloud coding agent. Use highest thinking. "
            "Reply with a concise actionable plan. Language: match the request.\n\n"
        ),
        "review": (
            "You are REVIEW for a Cursor Cloud coding agent. Use highest thinking. "
            "End with exactly one line: VERDICT: approve|revise|block\n\n"
        ),
    }[mode]
    prompt = prefix + request_text.strip()

    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp(CDP)
        context = browser.contexts[0] if browser.contexts else browser.new_context()
        page = context.pages[0] if context.pages else context.new_page()
        if "chatgpt.com" not in (page.url or ""):
            page.goto(CHAT_URL, wait_until="domcontentloaded", timeout=60000)
        else:
            page.reload(wait_until="domcontentloaded", timeout=60000)
        page.wait_for_timeout(1500)

        if not looks_logged_in(page):
            print("chatgpt:not_logged_in open Chrome on chatgpt.com and sign in", file=sys.stderr)
            out_path.write_text("chatgpt:not_logged_in\n", encoding="utf-8")
            return 4

        try_enable_thinking(page)
        # Prefer a fresh chat
        try:
            new_btn = page.get_by_role("button", name=re.compile(r"New chat|新聊天", re.I)).first
            if new_btn.count() and new_btn.is_visible():
                new_btn.click(timeout=2000)
                page.wait_for_timeout(800)
        except Exception:
            pass

        composer = find_composer(page)
        if composer is None:
            print("chatgpt:unavailable composer not found", file=sys.stderr)
            return 5

        composer.click()
        try:
            tag = composer.evaluate("el => el.tagName.toLowerCase()")
        except Exception:
            tag = ""
        if tag == "textarea":
            composer.fill(prompt)
        else:
            # contenteditable
            page.keyboard.press("Control+A")
            page.keyboard.insert_text(prompt)

        page.keyboard.press("Enter")
        wait_generation(page, timeout_s)
        text = extract_last_assistant(page)
        if not text:
            print("chatgpt:unavailable empty reply", file=sys.stderr)
            return 6
        out_path.write_text(text + "\n", encoding="utf-8")
        print(text)
        return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=("plan", "review"), default="plan")
    ap.add_argument("--request-file", default="")
    ap.add_argument("--out-file", default="/workspace/.cursor/chatgpt/last-out.md")
    ap.add_argument("--timeout", type=float, default=float(os.environ.get("CHATGPT_TIMEOUT_S", "900")))
    ap.add_argument("--status-only", action="store_true")
    args = ap.parse_args()

    if args.status_only:
        if not cdp_up():
            print(json.dumps({"cdp": False, "logged_in": False}))
            return 2
        with sync_playwright() as p:
            browser = p.chromium.connect_over_cdp(CDP)
            context = browser.contexts[0] if browser.contexts else browser.new_context()
            page = context.pages[0] if context.pages else context.new_page()
            if "chatgpt.com" not in (page.url or ""):
                page.goto(CHAT_URL, wait_until="domcontentloaded", timeout=60000)
            ok = looks_logged_in(page)
            print(json.dumps({"cdp": True, "logged_in": ok, "url": page.url}))
            return 0 if ok else 4

    if not args.request_file:
        print("chatgpt:unavailable --request-file required", file=sys.stderr)
        return 1
    req = Path(args.request_file).read_text(encoding="utf-8")
    out = Path(args.out_file)
    out.parent.mkdir(parents=True, exist_ok=True)
    return run(args.mode, req, out, args.timeout)


if __name__ == "__main__":
    raise SystemExit(main())
