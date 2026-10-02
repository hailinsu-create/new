#!/usr/bin/env python3
"""Force Cursor Agent / Cloud Agent to hand work to grok.com CLI.

Grok CLI is a separate process and does not run these Cursor hooks.
"""
from __future__ import annotations

import json
import sys

ROUTE = (
    "You are only a router. Do not implement with Cursor tools. "
    "Write the user's task to /tmp/grok-prompt.txt and run: "
    "bash .cursor/grok/run.sh run --file /tmp/grok-prompt.txt"
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
    ".cursor/quota-clis/",
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
    # Other quota CLIs (NOT Codex/GPT) — explicit user/agent invocations
    "/.local/bin/agy",
    "agy -p",
    "agy --",
    "agy models",
    "antigravity.google/cli/install",
    "/.opencode/bin/opencode",
    "opencode run",
    "opencode auth",
    "opencode models",
    "opencode.ai/install",
    "/.kimi-code/bin/kimi",
    "kimi -p",
    "kimi -c",
    "code.kimi.com/kimi-code/install",
    "code.kimi.ai/kimi-code/install",
    "install-all.sh",
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
    if (
        stripped.startswith("agy")
        or stripped.startswith("~/.local/bin/agy")
        or stripped.startswith("$HOME/.local/bin/agy")
    ):
        return True
    if (
        stripped.startswith("opencode")
        or stripped.startswith("~/.opencode/bin/opencode")
        or stripped.startswith("$HOME/.opencode/bin/opencode")
    ):
        # Refuse OpenAI/Codex-shaped opencode invocations if any sneak in via args
        lowered0 = stripped.lower()
        if "codex" in lowered0 or "chatgpt" in lowered0:
            return False
        return True
    if (
        stripped.startswith("kimi")
        or stripped.startswith("~/.kimi-code/bin/kimi")
        or stripped.startswith("$HOME/.kimi-code/bin/kimi")
    ):
        return True
    if stripped.startswith("git") or stripped.startswith("gh "):
        return True
    # Hard-deny GPT/Codex CLIs even if somehow on PATH
    lowered = cmd.lower()
    for banned in ("codex ", "npx codex", "openai ", "chatgpt", "@openai/codex"):
        if banned in lowered:
            return False
    return any(marker in cmd for marker in ALLOW_SHELL_MARKERS)


def mcp_allowed(name: str, data: dict) -> bool:
    blob = json.dumps(data, default=str).lower()
    if name.startswith("mcp") or name.startswith("calldynamic") or "cursor-cloud" in blob:
        return True
    if name in {"managepullrequest", "editpullrequestlabels", "getdynamictools", "fetchmcpresource"}:
        return True
    return False


def main() -> None:
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
                "additional_context": (
                    "HARD REQUIREMENT: implement nothing with Cursor-billed tools. "
                    "Default: hand the task to grok.com CLI Extra High Fast via "
                    "bash .cursor/grok/run.sh run --file /tmp/grok-prompt.txt. "
                    "When the user explicitly asks for another quota CLI, call it instead: "
                    "agy -p '...', opencode run -m opencode-go/... --auto, or kimi -p '...'. "
                    "Never install or invoke Codex/ChatGPT/OpenAI GPT CLIs. "
                    "If a quota CLI is already running this turn, do the work and do not recurse."
                ),
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
