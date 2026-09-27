#!/usr/bin/env bash
set -euo pipefail

godot_bin="${1:?Pass an absolute path to Godot 4.7.2}"
entry="${2:-smoke_test.gd}"
case "$entry" in
  smoke_test.gd|feel_gate.gd|playable_dump.gd|visual_dump.gd|storage_probe.gd|eval_dump_0de4f1d.gd|eval_dump_71ca4af.gd|eval_dump_v030.gd|eval_dump_v031.gd|eval_dump_v040.gd|eval_dump_touch_hud.gd) ;;
  *) printf 'Unsupported destructive test entry: %s\n' "$entry" >&2; exit 2 ;;
esac

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
run_id="$(python3 -c 'import uuid; print(uuid.uuid4().hex)')"
run_dir="$project_root/build/ambush_test_runs/$run_id"
data_root="$run_dir/data"
mkdir -p -- "$data_root"
export XDG_DATA_HOME="$data_root"
export XDG_CONFIG_HOME="$run_dir/config"
export XDG_CACHE_HOME="$run_dir/cache"
export AMBUSH_TEST_DATA_ROOT="$data_root"
export AMBUSH_TEST_RUN_ID="$run_id"
printf 'TEST_RUN_ID=%s\nTEST_DATA_ROOT=%s\nTEST_ENTRY=%s\n' "$run_id" "$data_root" "$entry"
"$godot_bin" --headless --path "$project_root" -s "res://scripts/$entry" 2>&1 | tee "$run_dir/run.log"
printf 'TEST_LOG=%s\n' "$run_dir/run.log"
