#!/usr/bin/env bash
# Idempotent installer for quota/coding CLIs used inside Cursor云开发
# (Cursor Environment / Cloud Agent VMs).
#
# INCLUDE: Grok (caller may already install), Antigravity agy, OpenCode, Kimi Code
# EXCLUDE: Codex / ChatGPT / OpenAI / GPT CLIs (user: 除了gpt之外)
#
# Auth is NOT baked here (OAuth / API keys stay on the VM via login or secret mount).
set -euo pipefail

MARKER="# quota-clis-path"
PATH_EXPORT='export PATH="$HOME/.grok/bin:$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.kimi-code/bin:$PATH"'

log() { printf 'quota-clis: %s\n' "$*" >&2; }

ensure_path() {
  export PATH="${HOME}/.grok/bin:${HOME}/.local/bin:${HOME}/.opencode/bin:${HOME}/.kimi-code/bin:${PATH}"
  if [[ -f "${HOME}/.bashrc" ]] && ! grep -q "${MARKER}" "${HOME}/.bashrc" 2>/dev/null; then
    printf '\n%s\n%s\n' "${MARKER}" "${PATH_EXPORT}" >> "${HOME}/.bashrc"
    log "appended PATH to ~/.bashrc"
  fi
  # Also ensure current shell sees bins even if bashrc was already sourced.
  eval "${PATH_EXPORT}"
}

have_bin() {
  local name="$1"
  command -v "${name}" >/dev/null 2>&1 && return 0
  case "${name}" in
    grok) [[ -x "${HOME}/.grok/bin/grok" ]] ;;
    agy) [[ -x "${HOME}/.local/bin/agy" ]] ;;
    opencode) [[ -x "${HOME}/.opencode/bin/opencode" ]] ;;
    kimi) [[ -x "${HOME}/.kimi-code/bin/kimi" ]] ;;
    *) return 1 ;;
  esac
}

install_agy() {
  if have_bin agy; then
    log "agy already present: $(command -v agy 2>/dev/null || echo "${HOME}/.local/bin/agy")"
    return 0
  fi
  log "installing Antigravity CLI (agy) from https://antigravity.google/cli/install.sh"
  curl -fsSL https://antigravity.google/cli/install.sh | bash
  export PATH="${HOME}/.local/bin:${PATH}"
  if have_bin agy; then
    log "agy installed"
    return 0
  fi
  log "WARNING: agy install finished but binary not found"
  return 1
}

install_opencode() {
  if have_bin opencode; then
    log "opencode already present: $(command -v opencode 2>/dev/null || echo "${HOME}/.opencode/bin/opencode")"
    return 0
  fi
  log "installing OpenCode from https://opencode.ai/install"
  curl -fsSL https://opencode.ai/install | bash
  export PATH="${HOME}/.opencode/bin:${PATH}"
  if have_bin opencode; then
    log "opencode installed"
    return 0
  fi
  log "WARNING: opencode install finished but binary not found"
  return 1
}

install_kimi() {
  if have_bin kimi; then
    log "kimi already present: $(command -v kimi 2>/dev/null || echo "${HOME}/.kimi-code/bin/kimi")"
    return 0
  fi
  log "installing Kimi Code CLI from https://code.kimi.com/kimi-code/install.sh"
  # Prefer mainland CDN; if it fails, try global mirror.
  if ! curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash; then
    log "mainland installer failed; trying code.kimi.ai mirror"
    curl -fsSL https://code.kimi.ai/kimi-code/install.sh | bash || true
  fi
  export PATH="${HOME}/.kimi-code/bin:${PATH}"
  if have_bin kimi; then
    log "kimi installed"
    return 0
  fi
  log "WARNING: kimi install finished but binary not found"
  return 1
}

refuse_gpt() {
  # Soft guard: never invoke Codex/OpenAI installers from this script.
  for bad in codex chatgpt openai-codex "@openai/codex"; do
    if [[ "${1:-}" == *"${bad}"* ]]; then
      log "REFUSED: GPT/Codex install requested (${bad}); excluded by policy"
      return 1
    fi
  done
  return 0
}

main() {
  refuse_gpt "$*" || exit 1
  ensure_path

  local rc=0
  install_agy || rc=1
  install_opencode || rc=1
  install_kimi || rc=1

  ensure_path
  log "summary:"
  for b in grok agy opencode kimi; do
    if have_bin "${b}"; then
      log "  OK  ${b} -> $(command -v "${b}" 2>/dev/null || true)"
    else
      log "  --  ${b} missing (grok may be installed by sibling inject)"
    fi
  done
  log "auth is interactive / secret-mount only; see .cursor/quota-clis/CALL-RECIPES.md"
  return "${rc}"
}

main "$@"
