"""Two-machine fox/centaur undress collaboration (cap = 2, mutex power-on).

Mother 791 = preferred environment / weights source of truth.
Clone     = long-lived peer (reuse BJB_CLONE_UUID; never release once kept).

User 2026-10-08 13:58: **at most one machine powered on**. No parallel generate.
Prefer 791; if 791 has no card / cannot start, run on clone only (clone may act as
temporary mother). Sync via intermediary + sync-manifest (not dual-online rsync).

    python dual_collab_run.py                # ensure fleet, mutex run, pull, shutdown-fleet
    python dual_collab_run.py --dry-plan     # print plan only

Rules:
  - At most two instances. Count before any clone; refuse a third.
  - Never power both at once; peer must be shutdown before power-on.
  - Models/nodes: prefer 791; if 791 down, clone writes sync-manifest; 791 pulls later.
  - Artifacts pull back locally / GitHub; do not rely on machine storage.
  - End: shutdown both, keep disks. Never release the kept pair (13:44).
  - No numeric score gate — Cursor visual judgment (VISUAL_JUDGE).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shlex
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import autodl_power as power  # noqa: E402
import bringup_and_run as bring  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
LOCAL_ARTIFACTS = Path("/opt/cursor/artifacts/fox-centaur-semantic/dual")
CLONE_ENV = Path("/cursor/stores/user/bjb-clone.env")
SYNC_MANIFEST_LOCAL = Path("/cursor/stores/user/fox-centaur-sync-manifest.json")
EXPAND_MIN = 107374182400  # 100 GiB
BASE_IMAGE = "base-image-ec1e9vdbd3"
MOTHER = power.MOTHER_UUID
SYNC_WATCH = (
    "workflows/comfyui/run_fox_centaur_semantic.py",
    "workflows/comfyui/semantic_undress.py",
    "workflows/comfyui/install_undress_stack.sh",
    "workflows/comfyui/bringup_and_run.py",
    "workflows/comfyui/dual_collab_run.py",
)


def fleet_count(auth: str | None = None) -> list[dict]:
    auth = auth or power.web_authorization()
    if not auth:
        raise SystemExit("WEB_AUTH_MISSING")
    status, reply = power.post(power.WEB_INSTANCE_LIST, {"Authorization": auth}, {"page_index": 1, "page_size": 50})
    if str(reply.get("code")) != "Success":
        raise SystemExit(f"INSTANCE_LIST_FAILED {reply.get('code')}")
    return list((reply.get("data") or {}).get("list") or [])


def refuse_third(auth: str | None = None) -> list[dict]:
    items = fleet_count(auth)
    uuids = [str(it.get("uuid") or "") for it in items if it.get("uuid")]
    if power.assert_fleet_cap(uuids) != 0:
        raise SystemExit(2)
    if len(uuids) > power.MAX_FLEET:
        raise SystemExit(f"FLEET_CAP_EXCEEDED refuse third machine; have {uuids}")
    return items


def write_clone_env(uuid: str, *, host: str, port: str, alias: str, machine_id: str, expand: int) -> None:
    CLONE_ENV.write_text(
        "\n".join(
            [
                f"BJB_CLONE_UUID={uuid}",
                f"BJB_CLONE_HOST={host}",
                f"BJB_CLONE_PORT={port}",
                "BJB_CLONE_USER=root",
                f"BJB_CLONE_ALIAS={alias}",
                f"BJB_CLONE_MACHINE_ID={machine_id}",
                f"BJB_CLONE_EXPAND={expand}",
                "BJB_CLONE_KEEP=1",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"CLONE_ENV_WRITTEN {CLONE_ENV} uuid={uuid} alias={alias}", flush=True)


def detail(auth: str, uuid: str) -> dict:
    import urllib.request

    req = urllib.request.Request(
        f"https://www.autodl.com/api/v1/instance/detail?instance_uuid={uuid}",
        headers={"Authorization": auth},
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = json.loads(resp.read().decode())
    if str(body.get("code")) != "Success":
        raise SystemExit(f"DETAIL_FAILED {uuid} {body.get('code')}")
    return body["data"]


def instance_status(auth: str, uuid: str) -> str:
    try:
        return str(detail(auth, uuid).get("status") or "")
    except Exception as exc:  # noqa: BLE001
        print(f"STATUS_ERR {uuid} {exc}", flush=True)
        return "unknown"


def release_bad_clone(auth: str, uuid: str, reason: str) -> None:
    """Only for a brand-new clone that failed the ≥100GiB gate before it joins the kept fleet."""
    print(f"CLONE_ABORT_RELEASE {uuid} reason={reason}", flush=True)
    power.post(power.WEB_POWER_OFF, {"Authorization": auth}, {"instance_uuid": uuid})
    time.sleep(5)
    for _ in range(30):
        d = detail(auth, uuid)
        if d.get("status") in ("shutdown", "shutdown_by_starting_error"):
            break
        time.sleep(3)
    status, reply = power.post(power.WEB_RELEASE, {"Authorization": auth}, {"instance_uuid": uuid})
    print(f"CLONE_ABORT_RELEASE_RESULT code={reply.get('code')} msg={str(reply.get('msg', ''))[:120]}", flush=True)


def list_clone_targets(auth: str) -> list[dict]:
    body = {
        "charge_type": "payg",
        "region_sign": "",
        "gpu_type_name": ["RTX 5090"],
        "machine_tag_name": [],
        "gpu_idle_num": 1,
        "mount_net_disk": False,
        "instance_disk_size_order": "",
        "date_range": "",
        "date_from": "",
        "date_to": "",
        "page_index": 1,
        "page_size": 90,
        "pay_price_order": "",
        "gpu_idle_type": "",
        "default_order": True,
        "region_sign_list": ["bj-B2", "bj-B1"],
    }
    status, reply = power.post(
        "https://www.autodl.com/api/v1/user/machine/list",
        {"Authorization": auth},
        body,
    )
    lst = (reply.get("data") or {}).get("list") or []
    cands = []
    for m in lst:
        idle = m.get("gpu_idle_num") or 0
        expand = m.get("max_data_disk_expand_size") or 0
        if idle < 1 or expand < EXPAND_MIN:
            continue
        region = m.get("region_sign") or ""
        score = (0 if region == "bj-B2" else 1, -idle, -expand)
        cands.append((score, m))
    cands.sort(key=lambda x: x[0])
    return [m for _, m in cands]


def wait_mother_clone_lock(auth: str, *, max_minutes: float = 90) -> str:
    """Wait until 791 leaves shutdown_cloning/cloning. Also nudge stuck ghost removers."""
    deadline = time.monotonic() + max_minutes * 60
    attempt = 0
    while time.monotonic() < deadline:
        st = instance_status(auth, MOTHER)
        print(f"LOCK_POLL attempt={attempt} mother={st}", flush=True)
        if st not in ("shutdown_cloning", "cloning"):
            print(f"LOCK_CLEAR mother={st}", flush=True)
            return st
        _, orders = power.post(
            "https://www.autodl.com/api/v1/order/list",
            {"Authorization": auth},
            {"page_index": 1, "page_size": 10},
        )
        for o in (orders.get("data") or {}).get("list") or []:
            if o.get("order_type") != "clone_instance":
                continue
            if o.get("migrate_instance_uuid") != MOTHER:
                continue
            ghost = str(o.get("product_uuid") or "")
            if not ghost or ghost == MOTHER:
                continue
            gst = instance_status(auth, ghost)
            print(f"GHOST_POLL uuid={ghost} status={gst}", flush=True)
            if gst == "removing":
                power.post(power.WEB_POWER_OFF, {"Authorization": auth}, {"instance_uuid": ghost})
            elif gst in ("shutdown", "shutdown_by_starting_error", "create_failed", "clone_failed"):
                if ghost not in power.kept_fleet_uuids():
                    release_bad_clone(auth, ghost, f"ghost_{gst}")
        wait = power.BACKOFF[min(attempt, len(power.BACKOFF) - 1)]
        attempt += 1
        time.sleep(wait)
    raise SystemExit("CLONE_LOCK_TIMEOUT mother still locked")


def ensure_clone(auth: str) -> str:
    """Return clone UUID. Reuse bjb-clone.env when live. Cap checked first."""
    existing = refuse_third(auth)
    uuids = {str(it.get("uuid")) for it in existing}
    known = power.clone_uuid()
    if known and known not in uuids:
        st = instance_status(auth, known)
        if st in ("unknown",) or str(st).startswith("HTTP_"):
            print(f"CLONE_STALE_ENV {known} not live; ignoring", flush=True)
            known = None
        elif st == "removing":
            print(f"CLONE_WAIT_REMOVING {known}; not reusing yet", flush=True)
            known = None
        else:
            print(f"CLONE_REUSE_OFFLIST {known} status={st}", flush=True)
            return known
    if known and known in uuids:
        print(f"CLONE_REUSE {known}", flush=True)
        return known
    if len(uuids) >= power.MAX_FLEET:
        other = sorted(uuids - {MOTHER})
        if other:
            print(f"CLONE_SKIP fleet already at cap with {other}; treating as clone peer", flush=True)
            write_clone_env(other[0], host="", port="", alias="peer", machine_id="", expand=EXPAND_MIN)
            return other[0]
        raise SystemExit("FLEET_FULL cannot clone")

    wait_mother_clone_lock(auth, max_minutes=90)

    targets = list_clone_targets(auth)
    if not targets:
        raise SystemExit("NO_CLONE_TARGET no idle RTX 5090 with expand≥100GiB")

    for m in targets[:30]:
        alias = m.get("machine_alias") or m["machine_id"]
        payload = {
            "instance_uuid": MOTHER,
            "instance_info": {
                "machine_id": m["machine_id"],
                "charge_type": "payg",
                "req_gpu_amount": 1,
                "base_image_uuid": BASE_IMAGE,
                "instance_name": f"fox-collab-{alias}",
                "private_image_uuid": "",
                "reproduction_uuid": "",
                "cg_application_uuid": "",
                "cg_application_info": {},
                "expand_data_disk": EXPAND_MIN,
                "copy_data_disk_after_clone": True,
                "keep_src_user_service_address_after_clone": False,
                "reproduction_id": 0,
                "ft_sparse": False,
            },
            "price_info": {
                "coupon_id_list": [],
                "machine_id": m["machine_id"],
                "charge_type": "payg",
                "duration": 1,
                "num": 1,
                "expand_data_disk": EXPAND_MIN,
            },
        }
        status, result = power.post(
            "https://www.autodl.com/api/v1/order/instance/clone/payg",
            {"Authorization": auth},
            payload,
        )
        code = str(result.get("code"))
        print(f"CLONE_TRY {alias} {m['machine_id']} -> {code} {str(result.get('msg', ''))[:80]}", flush=True)
        if code != "Success":
            time.sleep(0.4)
            continue
        new_uuid = str(result.get("data"))
        for i in range(90):
            try:
                d = detail(auth, new_uuid)
            except SystemExit:
                time.sleep(4)
                continue
            st = d.get("status")
            expand = int(d.get("data_disk_expand_size") or 0)
            print(f"CLONE_WAIT {new_uuid} status={st} expand={expand} i={i}", flush=True)
            if expand and expand < EXPAND_MIN:
                release_bad_clone(auth, new_uuid, f"expand {expand} < {EXPAND_MIN}")
                break
            if st in ("running", "shutdown", "clone_failed", "create_failed"):
                if st in ("clone_failed", "create_failed"):
                    release_bad_clone(auth, new_uuid, st)
                    break
                if expand < EXPAND_MIN:
                    release_bad_clone(auth, new_uuid, f"expand {expand} < {EXPAND_MIN}")
                    break
                machine = d.get("machine") or {}
                host = str(d.get("proxy_host") or "")
                port = str(d.get("ssh_port") or "")
                if st == "running":
                    power.power_off_keep_disk(new_uuid, auth)
                write_clone_env(
                    new_uuid,
                    host=host,
                    port=port,
                    alias=str(machine.get("machine_alias") or alias),
                    machine_id=str(machine.get("machine_id") or m["machine_id"]),
                    expand=expand or EXPAND_MIN,
                )
                print(f"CLONE_READY {new_uuid} (kept, powered off for mutex)", flush=True)
                return new_uuid
            time.sleep(4)
        else:
            release_bad_clone(auth, new_uuid, "timeout waiting for clone")
    raise SystemExit("CLONE_ALL_FAILED no supporting host accepted the clone order")


def assignment(actors: list[str]) -> dict[str, list[str]]:
    """Compat: historical split for dry-plan notes. Runtime is mutex (all on one role)."""
    clone = power.clone_uuid()
    if not clone:
        return {"mother": list(actors), "clone": []}
    if len(actors) == 1:
        return {"mother": [], "clone": list(actors)}
    mid = max(1, len(actors) // 2)
    return {"mother": actors[:mid], "clone": actors[mid:]}


def peer_uuid(active: str) -> str | None:
    clone = power.clone_uuid()
    if active == MOTHER:
        return clone
    return MOTHER


def ensure_peer_shutdown(auth: str, active_uuid: str) -> None:
    """Hard mutex: peer must not be running before we power on active."""
    peer = peer_uuid(active_uuid) if active_uuid in (MOTHER, power.clone_uuid() or "") else None
    # active_uuid is mother or clone uuid
    clone = power.clone_uuid()
    if active_uuid == MOTHER:
        peer = clone
    else:
        peer = MOTHER
    if not peer:
        return
    st = instance_status(auth, peer)
    print(f"MUTEX_PEER uuid={peer} status={st}", flush=True)
    if st in ("", "unknown"):
        return
    if st in ("shutdown", "shutdown_by_starting_error", "create_failed", "clone_failed", "removing"):
        return
    if st in ("shutdown_cloning", "cloning"):
        print(f"MUTEX_PEER_LOCKED {peer} status={st}; waiting", flush=True)
        if peer == MOTHER:
            wait_mother_clone_lock(auth, max_minutes=60)
            return
    print(f"MUTEX_POWER_OFF_PEER {peer}", flush=True)
    power.power_off_keep_disk(peer, auth)
    for i in range(40):
        st = instance_status(auth, peer)
        print(f"MUTEX_WAIT_PEER i={i} status={st}", flush=True)
        if st in ("shutdown", "shutdown_by_starting_error", "removing"):
            return
        time.sleep(3)
    raise SystemExit(f"MUTEX_PEER_STILL_ON {peer} status={st}")


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def build_sync_manifest(*, role: str, uuid: str, extra: dict | None = None) -> dict:
    files = []
    for rel in SYNC_WATCH:
        p = ROOT / rel
        if not p.is_file():
            continue
        files.append(
            {
                "path": rel,
                "sha256": file_sha256(p),
                "mtime": int(p.stat().st_mtime),
                "size": p.stat().st_size,
            }
        )
    manifest = {
        "schema": 1,
        "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "source_role": role,
        "source_uuid": uuid,
        "files": files,
        "notes": "Newer updated_at + per-file sha wins; never overwrite newer with older.",
    }
    if extra:
        manifest["extra"] = extra
    return manifest


def write_sync_manifest(manifest: dict) -> Path:
    SYNC_MANIFEST_LOCAL.parent.mkdir(parents=True, exist_ok=True)
    SYNC_MANIFEST_LOCAL.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"SYNC_MANIFEST_WRITTEN {SYNC_MANIFEST_LOCAL} role={manifest.get('source_role')}", flush=True)
    return SYNC_MANIFEST_LOCAL


def load_sync_manifest() -> dict | None:
    if not SYNC_MANIFEST_LOCAL.is_file():
        return None
    try:
        return json.loads(SYNC_MANIFEST_LOCAL.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def pick_active_role(auth: str) -> str:
    """Prefer mother; fall back to clone when mother locked / no GPU / ensure fails."""
    clone = power.clone_uuid()
    mother_st = instance_status(auth, MOTHER)
    if mother_st in ("shutdown_cloning", "cloning"):
        print(f"PICK_ACTIVE mother locked ({mother_st}); prefer clone if available", flush=True)
        if clone:
            return "clone"
        wait_mother_clone_lock(auth, max_minutes=90)

    ensure_peer_shutdown(auth, MOTHER)
    code = power.ensure_on(MOTHER, max_minutes=8)
    if code == 0:
        print("PICK_ACTIVE mother", flush=True)
        return "mother"
    print(f"PICK_ACTIVE mother_failed code={code}; trying clone", flush=True)
    if not clone:
        ensure_peer_shutdown(auth, MOTHER)
        code = power.ensure_on(MOTHER, max_minutes=0)
        if code != 0:
            raise SystemExit(f"NO_ACTIVE_MACHINE mother_failed={code} no_clone")
        return "mother"
    ensure_peer_shutdown(auth, clone)
    code = power.ensure_on(clone, max_minutes=45)
    if code != 0:
        raise SystemExit(f"NO_ACTIVE_MACHINE mother_and_clone_failed clone_code={code}")
    print("PICK_ACTIVE clone (temporary mother)", flush=True)
    return "clone"


def materialize_clone_ssh_env(auth: str, uuid: str) -> Path:
    d = detail(auth, uuid)
    host = str(d.get("proxy_host") or "")
    port = str(d.get("ssh_port") or "")
    password = str(d.get("root_password") or "")
    if not host or not port:
        cmd = str(d.get("ssh_command") or "")
        parts = cmd.split()
        if "-p" in parts:
            port = parts[parts.index("-p") + 1]
        for p in parts:
            if "@" in p:
                host = p.split("@", 1)[1]
    path = Path("/tmp/bjb-clone-ssh.env")
    mother = power.read_env_file(bring.SSH_ENV)
    lines = [
        f"BJB_INSTANCE_UUID={uuid}",
        f"BJB_SSH_HOST={host}",
        f"BJB_SSH_PORT={port}",
        "BJB_SSH_USER=root",
        f"BJB_SSH_KEY_PATH={mother.get('BJB_SSH_KEY_PATH', '/cursor/stores/user/bjb791')}",
    ]
    if password:
        lines.append(f"BJB_SSH_PASSWORD={password}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def run_mutex(
    role: str,
    actors: list[str],
    *,
    attempt: int,
    out: Path,
    light_ship: bool,
    skip_install: bool,
    auth: str,
) -> dict:
    uuid = MOTHER if role == "mother" else power.clone_uuid()
    assert uuid
    ensure_peer_shutdown(auth, uuid)
    code = power.ensure_on(uuid, max_minutes=45)
    if code != 0:
        return {"role": role, "uuid": uuid, "actors": actors, "power_on": code, "failed": True}
    ensure_peer_shutdown(auth, uuid)

    env_path = bring.SSH_ENV if role == "mother" else materialize_clone_ssh_env(auth, uuid)
    old = bring.SSH_ENV
    bring.SSH_ENV = env_path
    try:
        bring.wait_ssh(20)
        bring.ship(light_ship)
        manifest = build_sync_manifest(role=role, uuid=uuid, extra={"actors": actors, "attempt": attempt})
        prev = load_sync_manifest()
        if prev and prev.get("source_role") != role:
            print(
                f"SYNC_MANIFEST_COMPARE prev_role={prev.get('source_role')} "
                f"prev_at={prev.get('updated_at')} active={role}",
                flush=True,
            )
        write_sync_manifest(manifest)
        if not skip_install:
            bring.ssh(f"bash {bring.REMOTE_ROOT}/workflows/comfyui/install_undress_stack.sh install", timeout=7200)
        bring.restart_comfy()
        bring.remote_run("--check-stack")
        bring.ssh(f"mkdir -p {bring.REMOTE_OUT}")
        only = " ".join(actors)
        role_out = out / role
        role_out.mkdir(parents=True, exist_ok=True)
        for mode in ("nude", "torn"):
            run = bring.remote_run(
                f"--only {only} --mode {mode} --attempt {attempt} --out {shlex.quote(bring.REMOTE_OUT)}",
                check=False,
            )
            bring.pull(role_out)
            bring.list_for_visual_judge(role_out)
            if run.returncode != 0:
                return {
                    "role": role,
                    "uuid": uuid,
                    "actors": actors,
                    "failed": True,
                    "mode": mode,
                    "rc": run.returncode,
                    "out": str(role_out),
                }
        bring.keep_in_repo(out / role)
        write_sync_manifest(build_sync_manifest(role=role, uuid=uuid, extra={"actors": actors, "ok": True}))
        return {"role": role, "uuid": uuid, "actors": actors, "failed": False, "out": str(role_out), "mutex": True}
    finally:
        bring.SSH_ENV = old


def plan_text(actors: list[str]) -> str:
    asg = assignment(actors)
    return json.dumps(
        {
            "mother": MOTHER,
            "clone": power.clone_uuid(),
            "mode": "mutex_single_power",
            "historical_assignment_note": asg,
            "runtime": "all actors on one active role; never both powered",
            "notes": (
                "791 preferred; clone fallback temporary mother; sync-manifest bidirectional via "
                "intermediary; pull artifacts locally; shutdown-fleet keep disk; never release; "
                "VISUAL_JUDGE; fleet cap 2."
            ),
        },
        ensure_ascii=False,
        indent=2,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--actors", nargs="*", choices=("lin", "elena"), default=["lin", "elena"])
    parser.add_argument("--attempt", type=int, default=0)
    parser.add_argument("--out", type=Path, default=LOCAL_ARTIFACTS)
    parser.add_argument("--dry-plan", action="store_true")
    parser.add_argument("--skip-clone", action="store_true", help="Do not create a clone; mother only.")
    parser.add_argument("--skip-install", action="store_true")
    parser.add_argument("--light-ship", action="store_true")
    parser.add_argument("--keep-on", action="store_true")
    parser.add_argument("--no-power-on", action="store_true")
    parser.add_argument("--force-role", choices=("mother", "clone"), help="Skip pick_active; still enforces mutex.")
    args = parser.parse_args()

    auth = power.web_authorization()
    if not auth:
        raise SystemExit("WEB_AUTH_MISSING")

    refuse_third(auth)
    if args.dry_plan:
        print(plan_text(list(args.actors)))
        return

    if not args.skip_clone and not power.clone_uuid():
        ensure_clone(auth)
        refuse_third(auth)

    print("DUAL_PLAN", plan_text(list(args.actors)), flush=True)
    args.out.mkdir(parents=True, exist_ok=True)

    if args.no_power_on:
        raise SystemExit("NO_POWER_ON mutex runner requires power control; refuse")

    if args.force_role:
        role = args.force_role
        if role == "clone" and not power.clone_uuid():
            raise SystemExit("FORCE_CLONE_MISSING")
        target = MOTHER if role == "mother" else power.clone_uuid()
        ensure_peer_shutdown(auth, target)
    else:
        role = pick_active_role(auth)

    result = run_mutex(
        role,
        list(args.actors),
        attempt=args.attempt,
        out=args.out,
        light_ship=args.light_ship,
        skip_install=args.skip_install,
        auth=auth,
    )
    report = {"results": [result], "mode": "mutex_single_power", "active": role}
    (args.out / "dual-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("DUAL_REPORT", json.dumps(report, ensure_ascii=False), flush=True)
    if (args.out / role).exists():
        bring.list_for_visual_judge(args.out / role)

    failed = bool(result.get("failed"))
    if args.keep_on or failed:
        print("MACHINE_STILL_ON mutex left active on (keep_on or failure).", flush=True)
    else:
        print("SHUTDOWN_FLEET_KEEP_DISK never release", flush=True)
        power.shutdown_fleet()
    power.balance()
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
