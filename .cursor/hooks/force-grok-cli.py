#!/usr/bin/env python3
"""Force Cursor Agent / Cloud Agent to hand work to grok.com CLI.

Grok CLI must not honor these deny-hooks: when GROK_AGENT=1 this script
allows every event so the grok.com worker can implement the task.
"""
from __future__ import annotations

import json
import os
import sys

REQUIRED_ACCOUNT = "lningha@gmail.com"
ROUTE = (
    "You are only a router. Do not implement with Cursor tools. "
    f"Spend {REQUIRED_ACCOUNT} grok.com CLI quota (not Cursor Grok, "
    "not hailinsu@gmail.com). Write the user's task to "
    "/tmp/grok-prompt.txt and run: "
    "bash .cursor/grok/run.sh run --file /tmp/grok-prompt.txt"
)
SESSION_CONTEXT = (
    "HARD REQUIREMENT: implement nothing with Cursor. "
    "Every Cloud Agent must hand every user task to grok.com CLI "
    f"as {REQUIRED_ACCOUNT} SuperGrok Heavy, Grok 4.6 Extra High Fast "
    "(effort xhigh, x-grok-service-tier=priority): "
    "bash .cursor/grok/run.sh run --file /tmp/grok-prompt.txt. "
    "If grok CLI is already running this turn (GROK_AGENT=1), do the "
    "work and do not recurse. Do not use hailinsu@gmail.com."
)

ALLOW_TOOLS = {
    "read",
    "grep",
    "glob",
    "semanticsearch",
    "readlints",
    "awaitshell",
    "todowrite",
    "switchmode",
    "setactivebranch",
    "managepullrequest",
    "editpullrequestlabels",
    "getdynamictools",
    "calldynamictool",
    "fetchmcpresource",
    "ls",
    "readdir",
}

DENY_TOOLS = {
    "task",
    "write",
    "strreplace",
    "delete",
    "editnotebook",
    "generateimage",
    "websearch",
    "webfetch",
    "recordscreen",
    "browser",
    "computeruse",
}

ALLOW_SHELL_MARKERS = (
    ".cursor/grok/",
    "run.sh",
    "/.grok/bin/grok",
    "grok login",
    "grok --",
    "grok models",
    "/tmp/grok",
    "x.ai/cli/install",
    ".grok-cursor-router",
    "force-grok-cli.py",
    ".cursor/hooks/",
)


def emit(payload: dict) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=True)
    sys.stdout.write("\n")


def allow() -> None:
    emit({"permission": "allow", "continue": True})
    raise SystemExit(0)


def deny(agent_message: str) -> None:
    emit(
        {
            "permission": "deny",
            "continue": True,
            "agent_message": agent_message,
            "user_message": "Blocked: spend grok.com CLI quota via bash .cursor/grok/run.sh",
        }
    )
    raise SystemExit(0)


def event_name(data: dict) -> str:
    return str(
        data.get("hook_event_name")
        or data.get("event")
        or data.get("type")
        or ""
    ).lower()


def tool_name(data: dict) -> str:
    raw = data.get("tool_name") or data.get("tool") or ""
    return str(raw).split(":")[-1].strip().lower()


def shell_command(data: dict) -> str:
    tool_input = data.get("tool_input")
    if isinstance(tool_input, dict):
        cmd = tool_input.get("command")
        if isinstance(cmd, str):
            return cmd
    cmd = data.get("command")
    return cmd if isinstance(cmd, str) else ""


def shell_allowed(cmd: str) -> bool:
    stripped = cmd.strip()
    if not stripped:
        return False
    if stripped.startswith("grok") or stripped.startswith("~/.grok") or stripped.startswith("$HOME/.grok"):
        return True
    if stripped.startswith("git") or stripped.startswith("gh "):
        return True
    lowered = cmd
    return any(marker in lowered for marker in ALLOW_SHELL_MARKERS)


def mcp_allowed(name: str, data: dict) -> bool:
    blob = json.dumps(data, default=str).lower()
    if name.startswith("mcp") or name.startswith("calldynamic") or "cursor-cloud" in blob:
        return True
    if name in {"managepullrequest", "editpullrequestlabels", "getdynamictools", "fetchmcpresource"}:
        return True
    return False


def running_as_grok_cli() -> bool:
    return os.environ.get("GROK_AGENT") == "1"


def main() -> None:
    if running_as_grok_cli():
        allow()

    try:
        data = json.load(sys.stdin)
    except Exception:
        allow()
    if not isinstance(data, dict):
        allow()

    ev = event_name(data)
    name = tool_name(data)

    if ev in {"beforesubmitprompt", "sessionstart"}:
        emit(
            {
                "continue": True,
                "permission": "allow",
                "additional_context": SESSION_CONTEXT,
            }
        )
        raise SystemExit(0)

    if ev in {"subagentstart", "subagent_start"} or name == "task":
        deny(
            "Cursor subagents spend Cursor-billed quota. "
            "Run the whole task through bash .cursor/grok/run.sh instead."
        )

    if ev in {"beforeshellexecution", "before_shell_execution"} or name in {"shell", "bash"}:
        cmd = shell_command(data)
        if shell_allowed(cmd):
            allow()
        deny(ROUTE + f" Blocked shell: {cmd[:200]}")

    if mcp_allowed(name, data):
        allow()

    if name in ALLOW_TOOLS:
        allow()

    if name in DENY_TOOLS or ev in {"pretooluse", "pre_tool_use"}:
        if name in ALLOW_TOOLS or name in {"shell", "bash"}:
            allow()
        if not name:
            allow()
        deny(ROUTE + f" Blocked Cursor tool: {name or ev}")

    allow()


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        allow()
