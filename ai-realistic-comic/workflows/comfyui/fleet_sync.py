"""Bidirectional fox/centaur fleet sync via intermediary sync-manifest.

User supplement (2026-10-08): when 791 cannot power on, the clone is temporary
mother. Code/params go through GitHub; newly installed models/nodes/weights are
recorded in a sync-manifest (path, sha256, mtime, source machine). When 791 later
powers on, clone changes reverse-sync to 791 first; manifests/hashes must match
before 791 may generate. Source is not hard-coded — newer side wins; never
overwrite newer with older. Pre-run consistency check: if drift, sync first and
refuse generate until aligned.

    python fleet_sync.py status
    python fleet_sync.py record --role mother|clone --uuid <uuid> [--remote-root ...]
    python fleet_sync.py plan                 # compare two role snapshots / intermediary
    python fleet_sync.py apply --active mother|clone   # pull intermediary onto active (SSH via bringup env)
    python fleet_sync.py check --role mother|clone --uuid <uuid>  # exit 0 aligned, 3 need sync

Intermediary files (not committed):
  /cursor/stores/user/fox-centaur-sync-manifest.json          # merged truth
  /cursor/stores/user/fox-centaur-sync-manifest.mother.json   # last mother snapshot
  /cursor/stores/user/fox-centaur-sync-manifest.clone.json    # last clone snapshot
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORE = Path("/cursor/stores/user")
MERGED = STORE / "fox-centaur-sync-manifest.json"
ROLE_PATHS = {
    "mother": STORE / "fox-centaur-sync-manifest.mother.json",
    "clone": STORE / "fox-centaur-sync-manifest.clone.json",
}

# Repo-side code/params (shipped via GitHub / bringup.ship).
CODE_WATCH = (
    "workflows/comfyui/run_fox_centaur_semantic.py",
    "workflows/comfyui/semantic_undress.py",
    "workflows/comfyui/install_undress_stack.sh",
    "workflows/comfyui/bringup_and_run.py",
    "workflows/comfyui/dual_collab_run.py",
    "workflows/comfyui/fleet_sync.py",
    "workflows/comfyui/autodl_power.py",
)

# Remote stack assets relative to ComfyUI root (usually /root/autodl-tmp/arc/... sibling or Comfy root).
# install_undress_stack.sh records under ComfyUI ROOT; bringup REMOTE_ROOT is the repo checkout.
# Weights live next to ComfyUI; we probe both repo-relative and common Comfy roots on the active host.
REMOTE_ASSET_GLOBS = (
    "models/inpaint/fooocus_inpaint_head.pth",
    "models/inpaint/inpaint_v26.fooocus.patch",
    "models/inpaint/big-lama.pt",
    "models/segformer_b2_clothes/model.safetensors",
    "models/segformer_b2_clothes/config.json",
    "models/grounding-dino/GroundingDINO_SwinT_OGC.cfg.py",
)


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def entry_for(path: Path, *, rel: str, source_role: str, source_uuid: str) -> dict:
    st = path.stat()
    return {
        "path": rel,
        "sha256": file_sha256(path),
        "mtime": int(st.st_mtime),
        "size": st.st_size,
        "source_role": source_role,
        "source_uuid": source_uuid,
        "recorded_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


def collect_local_code(*, role: str, uuid: str) -> list[dict]:
    out = []
    for rel in CODE_WATCH:
        p = ROOT / rel
        if p.is_file():
            out.append(entry_for(p, rel=rel, source_role=role, source_uuid=uuid))
    return out


def collect_remote_assets(*, role: str, uuid: str, remote_roots: list[str]) -> list[dict]:
    """SSH to active host and hash asset paths. Uses bringup SSH env already pointed at host."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import bringup_and_run as bring  # noqa: WPS433

    entries: list[dict] = []
    for root in remote_roots:
        for rel in REMOTE_ASSET_GLOBS:
            remote = f"{root.rstrip('/')}/{rel}"
            script = (
                f"python3 - <<'PY'\n"
                f"import hashlib, os, json\n"
                f"p={remote!r}\n"
                f"if not os.path.isfile(p):\n"
                f"    print('MISS')\n"
                f"else:\n"
                f"    h=hashlib.sha256()\n"
                f"    with open(p,'rb') as f:\n"
                f"        [h.update(c) for c in iter(lambda:f.read(1<<20), b'')]\n"
                f"    st=os.stat(p)\n"
                f"    print(json.dumps({{'sha256':h.hexdigest(),'mtime':int(st.st_mtime),'size':st.st_size}}))\n"
                f"PY"
            )
            try:
                proc = bring.ssh(script, timeout=120, check=False)
            except Exception as exc:  # noqa: BLE001
                print(f"ASSET_SSH_ERR {rel} {exc}", flush=True)
                continue
            line = (proc.stdout or "").strip().splitlines()
            if not line or line[-1] == "MISS":
                continue
            try:
                meta = json.loads(line[-1])
            except json.JSONDecodeError:
                continue
            entries.append(
                {
                    "path": rel,
                    "sha256": meta["sha256"],
                    "mtime": meta["mtime"],
                    "size": meta["size"],
                    "source_role": role,
                    "source_uuid": uuid,
                    "remote_root": root,
                    "recorded_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                }
            )
    return entries


def build_manifest(
    *,
    role: str,
    uuid: str,
    include_remote: bool = False,
    remote_roots: list[str] | None = None,
    extra: dict | None = None,
) -> dict:
    files = collect_local_code(role=role, uuid=uuid)
    if include_remote:
        roots = remote_roots or [
            "/root/autodl-tmp/arc/ComfyUI",
            "/root/ComfyUI",
            "/root/autodl-tmp/ComfyUI",
        ]
        # Dedupe by path preferring first hit
        seen = {e["path"] for e in files}
        for e in collect_remote_assets(role=role, uuid=uuid, remote_roots=roots):
            if e["path"] in seen:
                continue
            files.append(e)
            seen.add(e["path"])
    manifest = {
        "schema": 2,
        "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "source_role": role,
        "source_uuid": uuid,
        "files": files,
        "notes": (
            "Bidirectional via intermediary. Per-file: higher mtime wins; if mtime tie, "
            "prefer non-empty sha from newer updated_at role. Never overwrite newer with older."
        ),
    }
    if extra:
        manifest["extra"] = extra
    return manifest


def save(path: Path, manifest: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"SYNC_MANIFEST_WRITTEN {path} role={manifest.get('source_role')} n={len(manifest.get('files') or [])}", flush=True)


def load(path: Path) -> dict | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def index_files(manifest: dict | None) -> dict[str, dict]:
    if not manifest:
        return {}
    return {f["path"]: f for f in (manifest.get("files") or []) if f.get("path")}


def newer_entry(a: dict | None, b: dict | None) -> dict | None:
    """Return the newer of two file entries; never prefer empty over filled."""
    if not a:
        return b
    if not b:
        return a
    am, bm = int(a.get("mtime") or 0), int(b.get("mtime") or 0)
    if am != bm:
        return a if am > bm else b
    # tie: keep existing merged if sha equal; else prefer b if recorded_at newer
    if a.get("sha256") == b.get("sha256"):
        return a
    ar, br = str(a.get("recorded_at") or ""), str(b.get("recorded_at") or "")
    return a if ar >= br else b


def merge_manifests(mother: dict | None, clone: dict | None, fallback_role: str, fallback_uuid: str) -> dict:
    """Merge role snapshots + existing MERGED; per-file newer wins."""
    merged_prev = load(MERGED)
    paths = set(index_files(mother)) | set(index_files(clone)) | set(index_files(merged_prev))
    files = []
    for p in sorted(paths):
        pick = newer_entry(
            newer_entry(index_files(merged_prev).get(p), index_files(mother).get(p)),
            index_files(clone).get(p),
        )
        if pick:
            files.append(pick)
    # Declare source_role as the role that contributed the most newest files
    mother_wins = sum(
        1
        for f in files
        if index_files(mother).get(f["path"], {}).get("sha256") == f.get("sha256")
        and index_files(mother).get(f["path"], {}).get("mtime") == f.get("mtime")
    )
    clone_wins = sum(
        1
        for f in files
        if index_files(clone).get(f["path"], {}).get("sha256") == f.get("sha256")
        and index_files(clone).get(f["path"], {}).get("mtime") == f.get("mtime")
    )
    if clone_wins > mother_wins:
        role, uuid = "clone", (clone or {}).get("source_uuid") or fallback_uuid
    else:
        role, uuid = "mother", (mother or {}).get("source_uuid") or fallback_uuid
    # If fallback_role forced (active recorder), bias stamp to active but keep per-file winners.
    if fallback_role in ("mother", "clone"):
        role = fallback_role
        uuid = fallback_uuid
    return {
        "schema": 2,
        "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "source_role": role,
        "source_uuid": uuid,
        "files": files,
        "merge": {"mother_wins": mother_wins, "clone_wins": clone_wins},
        "notes": "Merged intermediary; per-file newer wins; never old over new.",
    }


def plan_sync(active_role: str) -> dict:
    """Decide direction: which files the active host must receive from intermediary."""
    merged = load(MERGED) or {"files": []}
    active = load(ROLE_PATHS[active_role]) or {"files": []}
    m_idx, a_idx = index_files(merged), index_files(active)
    need_pull = []
    need_push = []
    for path in sorted(set(m_idx) | set(a_idx)):
        m, a = m_idx.get(path), a_idx.get(path)
        winner = newer_entry(m, a)
        if not winner:
            continue
        if a and winner.get("sha256") == a.get("sha256") and winner.get("mtime") == a.get("mtime"):
            continue
        # Active is behind intermediary (or missing) → pull to active.
        if m and (not a or newer_entry(m, a) is m):
            need_pull.append({"path": path, "from": "intermediary", "entry": m})
        # Active has newer → push into intermediary (record only; ship handles code).
        elif a and (not m or newer_entry(m, a) is a):
            need_push.append({"path": path, "from": active_role, "entry": a})
    direction = "noop"
    if need_pull and active_role == "mother":
        direction = "clone_to_mother_reverse" if (load(ROLE_PATHS["clone"]) or {}).get("source_role") == "clone" else "intermediary_to_mother"
    elif need_pull and active_role == "clone":
        direction = "mother_to_clone"
    elif need_push:
        direction = f"{active_role}_to_intermediary"
    return {
        "active_role": active_role,
        "direction": direction,
        "need_pull": need_pull,
        "need_push": need_push,
        "aligned": not need_pull and not need_push,
    }


def record(*, role: str, uuid: str, include_remote: bool) -> dict:
    man = build_manifest(role=role, uuid=uuid, include_remote=include_remote)
    save(ROLE_PATHS[role], man)
    merged = merge_manifests(load(ROLE_PATHS["mother"]), load(ROLE_PATHS["clone"]), role, uuid)
    save(MERGED, merged)
    return merged


def check_aligned(*, role: str, uuid: str, include_remote: bool = False) -> int:
    """Exit semantics: 0 aligned (or refreshed same-role), 3 must sync before generate."""
    # Refresh active snapshot from what we can see locally (+ optional remote).
    active = build_manifest(role=role, uuid=uuid, include_remote=include_remote)
    save(ROLE_PATHS[role], active)
    merged = merge_manifests(load(ROLE_PATHS["mother"]), load(ROLE_PATHS["clone"]), role, uuid)
    save(MERGED, merged)
    plan = plan_sync(role)
    print("SYNC_PLAN", json.dumps({k: plan[k] for k in ("active_role", "direction", "aligned", "need_pull", "need_push") if k in plan}, ensure_ascii=False, default=str)[:2000], flush=True)
    if plan["aligned"]:
        print(f"SYNC_CHECK_OK role={role}", flush=True)
        return 0
    # Special case: mother coming back while clone snapshot is newer → reverse sync required.
    clone_man = load(ROLE_PATHS["clone"])
    mother_man = load(ROLE_PATHS["mother"])
    if role == "mother" and clone_man and plan["need_pull"]:
        print(
            "SYNC_CHECK_NEED_REVERSE clone→791 required before mother may generate; "
            f"pull={len(plan['need_pull'])} push={len(plan['need_push'])}",
            flush=True,
        )
        return 3
    if plan["need_pull"]:
        print(
            f"SYNC_CHECK_NEED_SYNC role={role} direction={plan['direction']} "
            f"pull={len(plan['need_pull'])}; refuse generate until apply",
            flush=True,
        )
        return 3
    # Only need_push: active is ahead — update intermediary already done via merge; OK to generate.
    print(f"SYNC_CHECK_OK role={role} active_ahead_pushed_to_intermediary", flush=True)
    return 0


def apply_to_active(*, role: str, uuid: str) -> int:
    """Bring active host up to intermediary for code (ship) and record assets after install.

    Mutex world: cannot rsync machine-to-machine. Code/params: GitHub + bringup.ship.
    Weights/nodes: re-run install_undress_stack on active when pull list includes models/*,
    then re-record remote hashes into role snapshot + merged.
    """
    plan = plan_sync(role)
    if plan["aligned"]:
        print("SYNC_APPLY_SKIP already aligned", flush=True)
        return 0
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import bringup_and_run as bring  # noqa: WPS433

    print(f"SYNC_APPLY direction={plan['direction']} pull={len(plan['need_pull'])}", flush=True)
    # Code always from repo intermediary (GitHub truth already on this Cloud Agent).
    bring.ship(False)
    need_assets = any(str(i["path"]).startswith("models/") for i in plan["need_pull"])
    if need_assets or plan["direction"] in ("clone_to_mother_reverse", "mother_to_clone", "intermediary_to_mother"):
        bring.ssh(f"bash {bring.REMOTE_ROOT}/workflows/comfyui/install_undress_stack.sh install", timeout=7200)
    # Re-record after apply
    record(role=role, uuid=uuid, include_remote=True)
    again = plan_sync(role)
    if again["need_pull"]:
        print(f"SYNC_APPLY_INCOMPLETE still_need_pull={len(again['need_pull'])}", flush=True)
        return 3
    print("SYNC_APPLY_OK", flush=True)
    return 0


def ensure_before_generate(*, role: str, uuid: str, include_remote: bool = True) -> None:
    """Hard gate used by dual_collab_run: sync first or refuse generate."""
    code = check_aligned(role=role, uuid=uuid, include_remote=include_remote)
    if code == 0:
        return
    print("SYNC_GATE applying intermediary → active before generate", flush=True)
    applied = apply_to_active(role=role, uuid=uuid)
    code2 = check_aligned(role=role, uuid=uuid, include_remote=include_remote)
    if applied != 0 or code2 != 0:
        raise SystemExit(
            f"SYNC_GATE_REFUSE role={role} apply={applied} check={code2}; "
            f"inconsistent manifests — synced/attempted but still drifting; no generate"
        )
    print("SYNC_GATE_PASSED", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    rec = sub.add_parser("record")
    rec.add_argument("--role", choices=("mother", "clone"), required=True)
    rec.add_argument("--uuid", required=True)
    rec.add_argument("--remote", action="store_true")
    plan = sub.add_parser("plan")
    plan.add_argument("--role", choices=("mother", "clone"), required=True)
    chk = sub.add_parser("check")
    chk.add_argument("--role", choices=("mother", "clone"), required=True)
    chk.add_argument("--uuid", required=True)
    chk.add_argument("--remote", action="store_true")
    app = sub.add_parser("apply")
    app.add_argument("--role", choices=("mother", "clone"), required=True)
    app.add_argument("--uuid", required=True)
    args = parser.parse_args()
    if args.cmd == "status":
        print(json.dumps({
            "merged": load(MERGED),
            "mother": load(ROLE_PATHS["mother"]),
            "clone": load(ROLE_PATHS["clone"]),
        }, ensure_ascii=False, indent=2)[:4000])
        return
    if args.cmd == "record":
        record(role=args.role, uuid=args.uuid, include_remote=args.remote)
        return
    if args.cmd == "plan":
        print(json.dumps(plan_sync(args.role), ensure_ascii=False, indent=2, default=str)[:4000])
        return
    if args.cmd == "check":
        raise SystemExit(check_aligned(role=args.role, uuid=args.uuid, include_remote=args.remote))
    if args.cmd == "apply":
        raise SystemExit(apply_to_active(role=args.role, uuid=args.uuid))


if __name__ == "__main__":
    main()
