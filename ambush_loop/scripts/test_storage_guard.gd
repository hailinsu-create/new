extends RefCounted

## Destructive SceneTree test scripts must run inside a fresh, private user://.
## The launchers set these values before Godot starts, including autoloads.

static func check() -> bool:
	var run_id := OS.get_environment("AMBUSH_TEST_RUN_ID")
	var data_root := OS.get_environment("AMBUSH_TEST_DATA_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path().trim_suffix("/")
	if run_id.length() != 32 or not run_id.is_valid_hex_number():
		push_error("TEST_STORAGE_ISOLATION_REQUIRED: missing unique run ID")
		return false
	if not data_root.is_absolute_path() or data_root.get_file() != "data":
		push_error("TEST_STORAGE_ISOLATION_REQUIRED: invalid data root")
		return false
	if data_root.get_base_dir().get_file() != run_id:
		push_error("TEST_STORAGE_ISOLATION_REQUIRED: data root does not match run ID")
		return false
	if data_root.get_base_dir().get_base_dir().get_file() != "ambush_test_runs":
		push_error("TEST_STORAGE_ISOLATION_REQUIRED: data root is outside test runs")
		return false
	if OS.get_name() == "Windows":
		data_root = data_root.to_lower()
		actual = actual.to_lower()
	if not actual.begins_with(data_root + "/"):
		push_error("TEST_STORAGE_ISOLATION_REQUIRED: user data escaped test root: %s" % actual)
		return false
	print("TEST_STORAGE_ISOLATED user_dir=", actual, " run_id=", run_id)
	return true
