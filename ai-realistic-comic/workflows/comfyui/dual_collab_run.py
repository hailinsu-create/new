"""Two-machine fox/centaur undress collaboration (cap = 2).

Mother 791 = environment / weights source of truth (may also generate).
Clone     = generate worker, synced from 791.

    python dual_collab_run.py                # ensure fleet, split actors, pull, shutdown-fleet
    python dual_collab_run.py --dry-plan     # print assignment only

Rules (user 2026-10-08):
  - At most two instances. Count before any clone; refuse a third.
  - If 791 has no GPU, wait or run on clone only — never open a third box.
  - Models/nodes change on 791 first; clone pulls from mother (or re-ships from this repo).
  - Artifacts pull back locally / GitHub; do not rely on machine storage.
  - End: shutdown both, keep disks. Never release the kept pair (13:44 voided stop⇒release).
  - No numeric score gate — Cursor visual judgment (VISUAL_JUDGE).
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import autodl_power as power  # noqa: E402
import bringup_and_run as bring  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
LOCAL_ARTIFACTS = Path("/opt/cursor/artifacts/fox-centaur-semantic/dual")
CLONE_ENV = Path("/cursor/stores/user/bjb-clone.env")
EXPAND_MIN = 107374182400  # 100 GiB
BASE_IMAGE = "base-image-ec1e9vdbd3"
MOTHER = power.MOTHER_UUID


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


def release_bad_clone(auth: str, uuid: str, reason: str) -> None:
    """Only for a brand-new clone that failed the ≥100GiB gate before it joins the kept fleet."""
    print(f"CLONE_ABORT_RELEASE {uuid} reason={reason}", flush=True)
    # Must power_off before release on AutoDL payg.
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


def ensure_clone(auth: str) -> str:
    """Return clone UUID. Create one if missing. Cap checked first. expand≥100GiB or abort-release."""
    existing = refuse_third(auth)
    uuids = {str(it.get("uuid")) for it in existing}
    known = power.clone_uuid()
    if known and known not in uuids:
        print(f"CLONE_STALE_ENV {known} not in live list; ignoring and cloning fresh", flush=True)
        known = None
    if known and known in uuids:
        print(f"CLONE_REUSE {known}", flush=True)
        return known
    if len(uuids) >= power.MAX_FLEET:
        # Mother + something else already — if the other is not our clone env, refuse.
        other = sorted(uuids - {MOTHER})
        if other:
            print(f"CLONE_SKIP fleet already at cap with {other}; treating as clone peer", flush=True)
            write_clone_env(
                other[0],
                host="",
                port="",
                alias="peer",
                machine_id="",
                expand=EXPAND_MIN,
            )
            return other[0]
        raise SystemExit("FLEET_FULL cannot clone")

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
        # Wait until instance exists and copy finishes / running or shutdown-ready.
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
                # SSH fields appear when running
                host = str(d.get("proxy_host") or "")
                port = str(d.get("ssh_port") or "")
                if st != "running":
                    # power on clone
                    power.power_on_loop(new_uuid, auth, max_minutes=45)
                    d = detail(auth, new_uuid)
                    host = str(d.get("proxy_host") or host)
                    port = str(d.get("ssh_port") or port)
                write_clone_env(
                    new_uuid,
                    host=host,
                    port=port,
                    alias=str(machine.get("machine_alias") or alias),
                    machine_id=str(machine.get("machine_id") or m["machine_id"]),
                    expand=expand or EXPAND_MIN,
                )
                print(f"CLONE_READY {new_uuid}", flush=True)
                return new_uuid
            time.sleep(4)
        else:
            release_bad_clone(auth, new_uuid, "timeout waiting for clone")
    raise SystemExit("CLONE_ALL_FAILED no supporting host accepted the clone order")


def assignment(actors: list[str]) -> dict[str, list[str]]:
    """Split actors across mother / clone. Default: lin→791, elena→clone."""
    clone = power.clone_uuid()
    if not clone:
        return {"mother": list(actors), "clone": []}
    if len(actors) == 1:
        return {"mother": [], "clone": list(actors)}
    mid = max(1, len(actors) // 2)
    return {"mother": actors[:mid], "clone": actors[mid:]}


def ssh_env_for(role: str) -> Path:
    if role == "mother":
        return bring.SSH_ENV
    # Temporarily point bringup helpers at clone by writing a side env the caller uses.
    return Path("/tmp/bjb-clone-ssh.env")


def materialize_clone_ssh_env(auth: str, uuid: str) -> Path:
    d = detail(auth, uuid)
    host = str(d.get("proxy_host") or "")
    port = str(d.get("ssh_port") or "")
    password = str(d.get("root_password") or "")
    if not host or not port:
        # parse ssh_command
        cmd = str(d.get("ssh_command") or "")
        parts = cmd.split()
        if "-p" in parts:
            port = parts[parts.index("-p") + 1]
        for p in parts:
            if "@" in p:
                host = p.split("@", 1)[1]
    path = Path("/tmp/bjb-clone-ssh.env")
    # Reuse mother key; password fallback from clone detail if present.
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


def run_on_role(
    role: str,
    actors: list[str],
    *,
    attempt: int,
    out: Path,
    light_ship: bool,
    skip_install: bool,
    auth: str,
) -> dict:
    if not actors:
        return {"role": role, "actors": [], "skipped": True}
    uuid = MOTHER if role == "mother" else power.clone_uuid()
    assert uuid
    # Ensure on
    code = power.ensure_on(uuid, max_minutes=45)
    if code != 0:
        return {"role": role, "uuid": uuid, "actors": actors, "power_on": code, "failed": True}

    env_path = bring.SSH_ENV if role == "mother" else materialize_clone_ssh_env(auth, uuid)
    # Monkeypatch bring.SSH_ENV for this thread's connection() reads.
    old = bring.SSH_ENV
    bring.SSH_ENV = env_path
    try:
        bring.wait_ssh(20)
        bring.ship(light_ship)
        if not skip_install:
            bring.ssh(f"bash {bring.REMOTE_ROOT}/workflows/comfyui/install_undress_stack.sh install", timeout=7200)
        bring.restart_comfy()
        bring.remote_run("--check-stack")
        bring.ssh(f"mkdir -p {bring.REMOTE_OUT}")
        only = " ".join(actors)
        # Nude then torn for assigned actors only.
        for mode in ("nude", "torn"):
            run = bring.remote_run(
                f"--only {only} --mode {mode} --attempt {attempt} --out {shlex.quote(bring.REMOTE_OUT)}",
                check=False,
            )
            role_out = out / role
            role_out.mkdir(parents=True, exist_ok=True)
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
        return {"role": role, "uuid": uuid, "actors": actors, "failed": False, "out": str(out / role)}
    finally:
        bring.SSH_ENV = old


def plan_text(actors: list[str]) -> str:
    asg = assignment(actors)
    return json.dumps(
        {
            "mother": MOTHER,
            "clone": power.clone_uuid(),
            "assignment": asg,
            "notes": "791=source+generate; clone=generate; sync install from repo (791 is truth); "
            "pull artifacts locally; shutdown-fleet keep disk; never release kept pair; VISUAL_JUDGE.",
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

    asg = assignment(list(args.actors))
    print("DUAL_PLAN", plan_text(list(args.actors)), flush=True)
    args.out.mkdir(parents=True, exist_ok=True)

    results = []
    # Parallel roles
    with ThreadPoolExecutor(max_workers=2) as pool:
        futs = []
        if asg["mother"]:
            futs.append(
                pool.submit(
                    run_on_role,
                    "mother",
                    asg["mother"],
                    attempt=args.attempt,
                    out=args.out,
                    light_ship=args.light_ship,
                    skip_install=args.skip_install,
                    auth=auth,
                )
            )
        if asg["clone"] and power.clone_uuid():
            futs.append(
                pool.submit(
                    run_on_role,
                    "clone",
                    asg["clone"],
                    attempt=args.attempt,
                    out=args.out,
                    light_ship=args.light_ship,
                    skip_install=args.skip_install,
                    auth=auth,
                )
            )
        # If clone assignment empty but mother has all (no clone), already covered.
        if not futs and asg["mother"]:
            results.append(
                run_on_role(
                    "mother",
                    asg["mother"],
                    attempt=args.attempt,
                    out=args.out,
                    light_ship=args.light_ship,
                    skip_install=args.skip_install,
                    auth=auth,
                )
            )
        for fut in as_completed(futs):
            results.append(fut.result())

    report = {"results": results, "assignment": asg}
    (args.out / "dual-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("DUAL_REPORT", json.dumps(report, ensure_ascii=False), flush=True)
    bring.list_for_visual_judge(args.out / "mother") if (args.out / "mother").exists() else None
    bring.list_for_visual_judge(args.out / "clone") if (args.out / "clone").exists() else None

    failed = any(r.get("failed") for r in results)
    if args.keep_on or failed:
        print("MACHINE_STILL_ON dual collab left machines on (keep_on or failure).", flush=True)
    else:
        print("SHUTDOWN_FLEET_KEEP_DISK never release", flush=True)
        power.shutdown_fleet()
    power.balance()
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
