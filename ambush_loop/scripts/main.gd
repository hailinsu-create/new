extends Node2D

## Ambush Loop — Commandos-style ambush prep + time-loop coordinator.
## SETUP → Alarm freezes PlanState → WATCHING (SimClock) → FAIL/WIN/REPLAY.

enum Phase { SETUP, WATCHING, FAILED, WON, REPLAY }
enum Tool { DEPLOY, TRIPWIRE }

const MAX_TRIPWIRES := 1
const TRIPWIRE_ROUTE_DIST := 24.0
const SNAPSHOT_EVERY := 6
const COVER_LONGPRESS_MS := 400
const PROGRESS_PATH := "user://ambush_loop.cfg"
const LEVEL_ORDER := ["yard", "warehouse", "pump", "railcut", "depot"]
const SfxBusScript := preload("res://scripts/sfx/sfx_bus.gd")
const AmbushZoneFxScript := preload("res://scripts/fx/ambush_zone_fx.gd")
const MissionSkyScript := preload("res://scripts/fx/mission_sky.gd")
const TouchHudScript := preload("res://scripts/touch_hud.gd")

var grid: AmbushGrid = AmbushGrid.new()
var phase: Phase = Phase.SETUP
var tool: Tool = Tool.DEPLOY
var loop_index: int = 1
var run_id: int = 0
var intel_paths: Array[PackedVector2Array] = [] # legacy mirror of intel.records paths
var intel: IntelStore = IntelStore.new()
var replay: ReplayPlayer = ReplayPlayer.new()
var fail_reason: String = ""

var level: LevelDef = null
var level_index: int = 0
var sim: SimClock = SimClock.new()
var battle_log: BattleLog = BattleLog.new()
var last_plan: PlanState = PlanState.new()
var door_locked: bool = false

var cover_slots: Array[CoverSlot] = []
var operators: Array[OperatorUnit] = []
var selected: OperatorUnit = null
var enemies: Array[EnemyRunner] = []
var tripwires: Array[Tripwire] = []
var loot_piles: Array[LootPickup] = []
var barrels: Array = []
var frozen_plan: PlanState = PlanState.new()
var replay_return_phase: Phase = Phase.SETUP

var pending_spawns: Array = [] # {id, route, delay, loot, spawned}
var route_world: Dictionary = {} # name -> PackedVector2Array
var escape_world: Vector2
var return_fire_fx: Array = []
var hud_tick: float = 0.0
var ambush_zone_poly: Node2D = null
var door_marker: Node2D = null
var mission_sky: Node2D = null
var all_spawns_done: bool = false
var pending_result: String = "" # "" | "fail" | "win" — build panel after tick events/snapshot

@onready var map_draw: Node2D = $World/MapDraw
@onready var entities: Node2D = $World/Entities
@onready var ghosts: Node2D = $World/Ghosts
@onready var covers: Node2D = $World/Covers
@onready var routes_draw: Node2D = $World/RoutesDraw
@onready var escape_marker: Node2D = $World/EscapeMarker
@onready var title_label: Label = $HUD/Root/TopBar/Title
@onready var status_label: Label = $HUD/Root/TopBar/Status
@onready var intel_label: Label = $HUD/Root/TopBar/Intel
@onready var help_label: Label = $HUD/Root/Help
@onready var alarm_button: Button = $HUD/Root/BottomBar/AlarmButton
@onready var clear_button: Button = $HUD/Root/BottomBar/ClearButton
@onready var tool_button: Button = $HUD/Root/BottomBar/ToolButton
@onready var result_panel: PanelContainer = $HUD/Root/ResultPanel
@onready var result_label: Label = $HUD/Root/ResultPanel/Margin/VBox/ResultLabel
@onready var continue_button: Button = $HUD/Root/ResultPanel/Margin/VBox/ContinueButton

var speed_button: Button = null
var pause_button: Button = null
var mode_button: Button = null
var door_button: Button = null
var pack_button: Button = null
var abort_button: Button = null
var replay_button: Button = null
var scrub_slider: HSlider = null
var event_log: Control = null
var level_label: Label = null
var tut_label: Label = null
var flash_label: Label = null
var role_box: Control = null
var role_card_buttons: Array[Button] = []
var role_cards: Array = []
var plan_readout: Label = null
var replay_layer: Node2D = null
var _flash_tween: Tween = null
var event_list: ItemList = null
var event_log_title: Label = null
var _event_list_items: Array = []
var focus_ring: Node2D = null
var replay_focus_actor: int = -1
var replay_focus_type: String = ""
var _escape_tween: Tween = null
var _result_panel_home: Vector4 = Vector4(-180, -90, 180, 90)
var killzone_draw: Node2D = null
var tripwire_ghost: Node2D = null

var sfx = null
var mute_button: Button = null
var _watch_first_fire: bool = false
var _watch_first_return: bool = false
var _restored_this_setup: bool = false
var _plan_diff_guard: bool = false
var plan_restore_hint: String = ""
var sfx_muted: bool = false
var pause_overlay: PauseOverlay = null
var tutorial_overlay: TutorialOverlay = null
var credits_overlay: CreditsOverlay = null
var _menu_paused_sim: bool = false
var _campaign_complete: bool = false
var title_return_button: Button = null
var _punch_tween: Tween = null
var _game_cam: Camera2D = null
var _rim_flash: Control = null
var _tone_wash: ColorRect = null
var _rim_tween: Tween = null
var _tone_tween: Tween = null
var _result_fade_tween: Tween = null
var touch_hud: CanvasLayer = null
var settings_button: Button = null
var extra_bar: HBoxContainer = null
var log_button: Button = null
var _event_log_open: bool = false
var _cam_pan: Vector2 = Vector2.ZERO
var _cam_zoom: float = 1.0
var _cam_punch: Vector2 = Vector2.ZERO
var _touches: Dictionary = {}
var _facing_touch: int = -1
var _pinch_start_dist: float = 0.0
var _pinch_start_zoom: float = 1.0
var _pinch_start_mid: Vector2 = Vector2.ZERO
var _focus_paused_watch: bool = false
var _touch_ate_click: bool = false
var _cover_hold_slot: CoverSlot = null
var _cover_hold_msec: int = 0
var _alarm_btn_tween: Tween = null
var _door_tween: Tween = null
var _touch_preview_slot: CoverSlot = null
var _pending_setup_touch: bool = false
var _pending_touch_world: Vector2 = Vector2.ZERO
var _touch_dragged: bool = false


func _ready() -> void:
	_resolve_optional_hud()
	sfx = get_node_or_null("/root/AudioDirector")
	if sfx == null:
		sfx = SfxBusScript.new()
		sfx.name = "SfxBus"
		add_child(sfx)
	alarm_button.pressed.connect(_on_alarm_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	tool_button.pressed.connect(_toggle_tool)
	continue_button.pressed.connect(_on_continue_pressed)
	_ensure_debrief_buttons()
	result_panel.visible = false
	_result_panel_home = Vector4(
		result_panel.offset_left, result_panel.offset_top,
		result_panel.offset_right, result_panel.offset_bottom
	)
	clear_button.text = "收回部署"
	tool_button.text = "工具: 部署队员"
	_bind_settings()
	_ensure_presentation_fx()
	_ensure_touch_hud()
	_load_level(_resolve_start_level(), false, false)


func _resolve_optional_hud() -> void:
	var root: Control = $HUD/Root
	root.theme = NightOps.theme()
	var bar: HBoxContainer = $HUD/Root/BottomBar
	speed_button = get_node_or_null("HUD/Root/BottomBar/SpeedButton") as Button
	pause_button = get_node_or_null("HUD/Root/BottomBar/PauseButton") as Button
	mode_button = get_node_or_null("HUD/Root/BottomBar/ModeButton") as Button
	door_button = get_node_or_null("HUD/Root/BottomBar/DoorButton") as Button
	pack_button = get_node_or_null("HUD/Root/BottomBar/PackButton") as Button
	event_log = get_node_or_null("HUD/Root/EventLog") as Control
	level_label = get_node_or_null("HUD/Root/TopBar/LevelLabel") as Label
	tut_label = get_node_or_null("HUD/Root/TutLabel") as Label

	var extra := HBoxContainer.new()
	extra.name = "ExtraBar"
	extra.alignment = BoxContainer.ALIGNMENT_CENTER
	extra.add_theme_constant_override("separation", 8)
	extra.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	extra.offset_left = -400.0
	extra.offset_right = 400.0
	extra.offset_top = -92.0
	extra.offset_bottom = -56.0
	root.add_child(extra)

	if speed_button == null:
		speed_button = _make_hud_btn("SpeedButton", "速度 1×", bar)
	if pause_button == null:
		pause_button = _make_hud_btn("PauseButton", "暂停", bar)
	if mode_button == null:
		mode_button = _make_hud_btn("ModeButton", "开火: 见敌即打 (F)", extra)
	if pack_button == null:
		pack_button = _make_hud_btn("PackButton", "弹包 (G)", extra)
	if door_button == null:
		door_button = _make_hud_btn("DoorButton", "门: 畅通 (B)", extra)

	extra_bar = extra
	mute_button = _make_hud_btn("MuteButton", "音效 M", extra)
	mute_button.pressed.connect(_toggle_mute)
	settings_button = _make_hud_btn("SettingsButton", "菜单 Esc", extra)
	settings_button.pressed.connect(_toggle_pause_menu)
	log_button = _make_hud_btn("LogButton", "日志", extra)
	log_button.pressed.connect(_toggle_event_log)

	speed_button.pressed.connect(_on_speed_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	mode_button.pressed.connect(_on_mode_pressed)
	pack_button.pressed.connect(_on_pack_pressed)
	door_button.pressed.connect(_on_door_pressed)

	abort_button = _make_hud_btn("AbortButton", "中止尝试 (X)", bar)
	abort_button.pressed.connect(_on_abort_pressed)
	abort_button.visible = false

	replay_button = _make_hud_btn("ReplayButton", "时间轴复盘", bar)
	replay_button.pressed.connect(_on_replay_pressed)
	replay_button.visible = false

	scrub_slider = HSlider.new()
	scrub_slider.name = "ScrubSlider"
	scrub_slider.min_value = 0.0
	scrub_slider.max_value = 1.0
	scrub_slider.step = 0.01
	scrub_slider.custom_minimum_size = Vector2(220, 24)
	scrub_slider.visible = false
	scrub_slider.value_changed.connect(_on_scrub_changed)
	bar.add_child(scrub_slider)

	flash_label = Label.new()
	flash_label.name = "FlashLabel"
	flash_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	flash_label.offset_left = -200.0
	flash_label.offset_right = 200.0
	flash_label.offset_top = 72.0
	flash_label.offset_bottom = 100.0
	flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_label.add_theme_font_size_override("font_size", 18)
	flash_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_label.text = ""
	root.add_child(flash_label)

	if event_log == null:
		var box := VBoxContainer.new()
		box.name = "EventLog"
		box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		box.offset_left = -328.0
		box.offset_top = 206.0
		box.offset_right = -12.0
		box.offset_bottom = 430.0
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title := Label.new()
		title.name = "EventLogTitle"
		title.text = "事件日志 · 点击定位"
		title.add_theme_font_size_override("font_size", 12)
		title.add_theme_color_override("font_color", Color(0.75, 0.82, 0.78))
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(title)
		var list := ItemList.new()
		list.name = "EventList"
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.allow_reselect = true
		list.add_theme_font_size_override("font_size", 12)
		list.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.item_clicked.connect(_on_event_item_clicked)
		box.add_child(list)
		root.add_child(box)
		event_log = box
		event_log.visible = false
		event_log_title = title
		event_list = list
	else:
		event_list = event_log.get_node_or_null("EventList") as ItemList
		event_log_title = event_log.get_node_or_null("EventLogTitle") as Label
		if event_list:
			event_list.item_clicked.connect(_on_event_item_clicked)

	if level_label == null:
		level_label = Label.new()
		level_label.name = "LevelLabel"
		$HUD/Root/TopBar.add_child(level_label)
		level_label.add_theme_font_size_override("font_size", 14)
		level_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.75))

	if tut_label == null:
		tut_label = Label.new()
		tut_label.name = "TutLabel"
		tut_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		tut_label.offset_left = 220.0
		tut_label.offset_top = 108.0
		tut_label.offset_right = 940.0
		tut_label.offset_bottom = 168.0
		tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tut_label.add_theme_font_size_override("font_size", 13)
		tut_label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.65))
		tut_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tut_label)

	_build_role_card_hud(root)
	_build_modals()
	if killzone_draw == null:
		killzone_draw = Node2D.new()
		killzone_draw.name = "KillzoneDraw"
		$World.add_child(killzone_draw)
		$World.move_child(killzone_draw, routes_draw.get_index())
	_ensure_tripwire_ghost()
	_setup_world_layers()
	_ensure_game_camera()
	if replay_layer == null:
		replay_layer = Node2D.new()
		replay_layer.name = "ReplayLayer"
		replay_layer.z_index = 10
		$World.add_child(replay_layer)


func _build_role_card_hud(root: Control) -> void:
	var dock := VBoxContainer.new()
	dock.name = "RoleCards"
	dock.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dock.offset_left = 10.0
	dock.offset_top = 78.0
	dock.offset_right = 214.0
	dock.offset_bottom = 430.0
	dock.add_theme_constant_override("separation", 8)
	dock.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dock)
	role_box = dock
	role_cards.clear()
	role_card_buttons.clear()
	for i in 3:
		var card := OpCard.new()
		card.setup(i)
		card.picked.connect(_select_op)
		dock.add_child(card)
		role_cards.append(card)
	plan_readout = Label.new()
	plan_readout.name = "PlanReadout"
	plan_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan_readout.add_theme_font_size_override("font_size", 11)
	plan_readout.add_theme_color_override("font_color", Color(0.7, 0.85, 0.78))
	plan_readout.custom_minimum_size = Vector2(196, 48)
	dock.add_child(plan_readout)


func _build_modals() -> void:
	pause_overlay = PauseOverlay.new()
	add_child(pause_overlay)
	pause_overlay.closed.connect(_on_pause_overlay_closed)
	pause_overlay.return_to_title.connect(_return_to_title)
	pause_overlay.redeploy_requested.connect(_on_redeploy_from_menu)
	if pause_overlay.has_signal("memory_wipe_requested"):
		pause_overlay.memory_wipe_requested.connect(_on_memory_wipe_from_menu)
	if pause_overlay.has_signal("touch_hud_toggled"):
		pause_overlay.touch_hud_toggled.connect(_ensure_touch_hud)
	tutorial_overlay = TutorialOverlay.new()
	add_child(tutorial_overlay)
	tutorial_overlay.dismissed.connect(_on_tutorial_dismissed)
	credits_overlay = CreditsOverlay.new()
	add_child(credits_overlay)
	credits_overlay.finished.connect(_return_to_title)


func _gs():
	return get_node_or_null("/root/GameSettings")


func _bind_settings() -> void:
	var gs = _gs()
	if gs and not gs.changed.is_connected(_sync_settings):
		gs.changed.connect(_sync_settings)
	_sync_settings()


func _sync_settings() -> void:
	var gs = _gs()
	if gs:
		sfx_muted = bool(gs.muted)
	_apply_mute_state()
	_ensure_touch_hud()


func _modal_blocks_input() -> bool:
	if pause_overlay and pause_overlay.is_open():
		return true
	if tutorial_overlay and tutorial_overlay.is_open():
		return true
	if credits_overlay and credits_overlay.is_open():
		return true
	return false


func _resolve_start_level() -> String:
	var gs = _gs()
	if gs and str(gs.pending_level_id) != "":
		var id := str(gs.pending_level_id)
		gs.pending_level_id = ""
		var idx := LEVEL_ORDER.find(id)
		level_index = idx if idx >= 0 else 0
		return LEVEL_ORDER[level_index]
	_load_progress()
	return LEVEL_ORDER[level_index]


func _maybe_show_tutorial() -> void:
	if level == null or tutorial_overlay == null:
		return
	if tutorial_overlay.is_open():
		return
	var gs = _gs()
	var lid := level.level_id
	if gs and gs.has_method("has_seen_tutorial"):
		if gs.has_seen_tutorial(lid):
			return
	elif gs and bool(gs.get("seen_tutorial")):
		return
	tutorial_overlay.present(lid)


func _on_tutorial_dismissed() -> void:
	var gs = _gs()
	if gs == null:
		return
	var lid := level.level_id if level else "yard"
	if gs.has_method("mark_tutorial_seen"):
		gs.mark_tutorial_seen(lid)
	else:
		gs.set("seen_tutorial", true)


func _toggle_pause_menu() -> void:
	if pause_overlay == null:
		return
	if pause_overlay.is_open():
		pause_overlay.dismiss()
		return
	pause_overlay.present(phase == Phase.SETUP, true)
	if phase == Phase.WATCHING and not sim.paused:
		sim.paused = true
		_menu_paused_sim = true
		if pause_button:
			pause_button.text = "继续"


func _on_pause_overlay_closed() -> void:
	if _menu_paused_sim and phase == Phase.WATCHING:
		sim.paused = false
		_menu_paused_sim = false
		if pause_button:
			pause_button.text = "暂停"


func _on_redeploy_from_menu() -> void:
	if pause_overlay:
		pause_overlay.dismiss()
	_on_clear_pressed()


func _return_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _show_credits() -> void:
	result_panel.visible = false
	if credits_overlay:
		credits_overlay.present()


func _make_hud_btn(p_name: String, text: String, parent: Control) -> Button:
	var b := Button.new()
	b.name = p_name
	b.text = text
	var touch := _want_touch()
	b.custom_minimum_size = Vector2(128, 48) if touch else Vector2(120, 32)
	parent.add_child(b)
	return b


func _want_touch() -> bool:
	var gs = _gs()
	if gs and gs.has_method("want_touch_controls"):
		return bool(gs.want_touch_controls())
	return OS.has_feature("android") or OS.has_feature("mobile")


func _ensure_touch_hud() -> void:
	if touch_hud == null or not is_instance_valid(touch_hud):
		touch_hud = TouchHudScript.new()
		touch_hud.name = "TouchHud"
		add_child(touch_hud)
		if touch_hud.has_method("bind_host"):
			touch_hud.bind_host(self)
	var on := _want_touch()
	touch_hud.visible = on
	_apply_phone_chrome(on)
	_refresh_touch_hud()


func _apply_phone_chrome(on: bool) -> void:
	var bar: Control = get_node_or_null("HUD/Root/BottomBar") as Control
	if bar:
		bar.visible = not on
	if extra_bar:
		extra_bar.visible = not on
	if help_label:
		help_label.visible = not on
	if tut_label:
		tut_label.visible = not on
	if event_log:
		event_log.visible = _event_log_open
	var root: Control = get_node_or_null("HUD/Root") as Control
	if root:
		var pad := _safe_area_pad()
		root.offset_left = pad.x
		root.offset_top = pad.y
		root.offset_right = -pad.z
		if on:
			root.offset_bottom = -pad.w - 150.0
		else:
			root.offset_bottom = -pad.w
	if role_box and on:
		role_box.offset_bottom = 460.0
	alarm_button.custom_minimum_size = Vector2(180, 48) if on else Vector2(180, 36)
	clear_button.custom_minimum_size = Vector2(120, 48) if on else Vector2(120, 36)
	tool_button.custom_minimum_size = Vector2(160, 48) if on else Vector2(160, 36)
	for card in role_cards:
		if card is Control:
			(card as Control).custom_minimum_size = Vector2(210, 118) if on else Vector2(196, 108)


func _safe_area_pad() -> Vector4:
	var sa := DisplayServer.get_display_safe_area()
	var wsz := DisplayServer.window_get_size()
	if wsz.x <= 0 or wsz.y <= 0:
		return Vector4(8, 8, 8, 8)
	var vis := get_viewport().get_visible_rect().size
	var left := sa.position.x * vis.x / float(wsz.x)
	var top := sa.position.y * vis.y / float(wsz.y)
	var right := (float(wsz.x) - sa.end.x) * vis.x / float(wsz.x)
	var bottom := (float(wsz.y) - sa.end.y) * vis.y / float(wsz.y)
	return Vector4(maxf(8.0, left), maxf(4.0, top), maxf(8.0, right), maxf(8.0, bottom))


func _refresh_touch_hud() -> void:
	if touch_hud == null or not touch_hud.has_method("refresh_phase"):
		return
	var phase_name := "SETUP"
	match phase:
		Phase.WATCHING:
			phase_name = "WATCHING"
		Phase.FAILED:
			phase_name = "FAILED"
		Phase.WON:
			phase_name = "WON"
		Phase.REPLAY:
			phase_name = "REPLAY"
		_:
			phase_name = "SETUP"
	var paused := phase == Phase.WATCHING and sim.paused
	var hi := phase == Phase.WATCHING and sim.speed >= 1.5
	touch_hud.refresh_phase(phase_name, paused, hi, sfx_muted, _event_log_open and event_log != null and event_log.visible)


func _toggle_event_log() -> void:
	_event_log_open = not _event_log_open
	if event_log:
		event_log.visible = _event_log_open
	if log_button:
		log_button.text = "收日志" if _event_log_open else "日志"
	_refresh_touch_hud()


func apply_touch_command(cmd: String) -> void:
	if cmd == "settings":
		_toggle_pause_menu()
		_refresh_touch_hud()
		return
	if cmd == "mute":
		_toggle_mute()
		_refresh_touch_hud()
		return
	if cmd == "log":
		_toggle_event_log()
		return
	if _modal_blocks_input():
		return
	match cmd:
		"alarm":
			if phase == Phase.REPLAY:
				_exit_replay_to_setup()
			else:
				_on_alarm_pressed()
		"abort":
			_on_abort_pressed()
		"pause":
			_on_pause_pressed()
		"speed":
			_on_speed_pressed()
		"fire":
			_on_mode_pressed()
		"pack":
			_on_pack_pressed()
		"trip":
			_toggle_tool()
		"door":
			_on_door_pressed()
		"clear":
			_on_clear_pressed()
		"rotate_cw":
			if phase == Phase.SETUP and selected and selected.visible:
				selected.rotate_by(15.0)
				_announce_plan_edit()
				_refresh_killzone_preview()
		"rotate_ccw":
			if phase == Phase.SETUP and selected and selected.visible:
				selected.rotate_by(-15.0)
				_announce_plan_edit()
				_refresh_killzone_preview()
	_update_hud()


func handle_android_back() -> void:
	if tutorial_overlay and tutorial_overlay.is_open():
		return
	if credits_overlay and credits_overlay.is_open():
		_return_to_title()
		return
	_toggle_pause_menu()


func handle_app_focus_out() -> void:
	_gate_scene_audio(true)
	# Freeze the sim clock whenever it can still step. Result panels are idle.
	if phase == Phase.WATCHING and not sim.paused:
		sim.paused = true
		_focus_paused_watch = true
		if pause_button:
			pause_button.text = "继续"
	elif phase != Phase.FAILED and phase != Phase.WON:
		sim.paused = true
	_refresh_touch_hud()


func handle_app_focus_in() -> void:
	_gate_scene_audio(false)
	# Stay paused after a home-button; player taps 继续. Do not auto-unpause sim.
	_refresh_touch_hud()


func _gate_scene_audio(paused: bool) -> void:
	var gs = _gs()
	if gs and gs.has_method("gate_background_audio"):
		gs.gate_background_audio(paused)
		return
	var audio = get_node_or_null("/root/AudioDirector")
	if audio == null:
		return
	if paused and audio.has_method("pause_for_background"):
		audio.pause_for_background()
	elif (not paused) and audio.has_method("resume_from_background"):
		audio.resume_from_background()


func _on_memory_wipe_from_menu() -> void:
	if pause_overlay:
		pause_overlay.dismiss()
	loop_index = 1
	intel_paths.clear()
	intel.clear()
	last_plan.clear()
	_start_setup(false, false)


func _sfx(cue: String) -> void:
	if sfx == null:
		return
	sfx.play(cue)


func _toggle_mute() -> void:
	var gs = _gs()
	if gs:
		gs.toggle_mute()
	else:
		sfx_muted = not sfx_muted
		_apply_mute_state()
	if status_label:
		status_label.text = "音效已关闭（M）" if sfx_muted else "音效已开启（M）"
	_save_progress()


func _apply_mute_state() -> void:
	if sfx:
		sfx.set_muted(sfx_muted)
	_refresh_mute_button()


func _refresh_mute_button() -> void:
	if mute_button == null:
		return
	mute_button.text = "静音 M" if sfx_muted else "音效 M"


func _update_observation_rings() -> void:
	var show := phase == Phase.SETUP
	for op in operators:
		if is_instance_valid(op):
			op.set_observation_ring(show)


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		level_index = 0
		_campaign_complete = false
		return
	var id := str(cfg.get_value("progress", "level_id", "yard"))
	level_index = LEVEL_ORDER.find(id)
	if level_index < 0:
		level_index = 0
	_campaign_complete = bool(cfg.get_value("progress", "complete", false))


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	# After a win, GameSettings.record_win already advanced level_id / cleared.
	if phase != Phase.WON:
		cfg.set_value("progress", "level_id", level.level_id if level else "yard")
		cfg.set_value("progress", "level_index", level_index)
		cfg.set_value("progress", "complete", _campaign_complete)
	cfg.set_value("progress", "loop_index", loop_index)
	cfg.set_value("audio", "muted", sfx_muted)
	cfg.save(PROGRESS_PATH)


func _ensure_debrief_buttons() -> void:
	if title_return_button != null:
		return
	var vbox := result_panel.get_node_or_null("Margin/VBox") as VBoxContainer
	if vbox == null:
		return
	title_return_button = Button.new()
	title_return_button.name = "TitleReturnButton"
	title_return_button.text = "返回标题"
	title_return_button.visible = false
	title_return_button.pressed.connect(_return_to_title)
	vbox.add_child(title_return_button)


func _setup_world_layers() -> void:
	## Floor under routes/arcs; entities and FX sit above dimmed authored ink.
	if map_draw:
		map_draw.z_index = 0
	if routes_draw:
		routes_draw.z_index = 1
	if covers:
		covers.z_index = 2
	if killzone_draw:
		killzone_draw.z_index = 3
	if ghosts:
		ghosts.z_index = 4
	if entities:
		entities.z_index = 6
	if escape_marker:
		escape_marker.z_index = 7


func _apply_watch_layers() -> void:
	var dim_routes := phase != Phase.SETUP
	if routes_draw:
		routes_draw.modulate = Color(1, 1, 1, 0.32) if dim_routes else Color.WHITE
	if killzone_draw:
		killzone_draw.modulate = Color.WHITE
		killzone_draw.visible = phase == Phase.SETUP
	if entities:
		entities.modulate = Color.WHITE
	if ghosts:
		ghosts.modulate = Color.WHITE
	if sfx and sfx.has_method("set_watch_bed"):
		sfx.set_watch_bed(phase == Phase.WATCHING)


func _ensure_game_camera() -> void:
	if _game_cam != null and is_instance_valid(_game_cam):
		return
	# Default 2D view is origin = top-left. A centered camera at the viewport
	# midpoint preserves that, so we can punch offset without moving World
	# (which would shift gameplay global_position and break 1×/2×).
	_game_cam = Camera2D.new()
	_game_cam.name = "GameCam"
	_game_cam.position = Vector2(640, 360)
	_game_cam.enabled = true
	add_child(_game_cam)
	_apply_cam()


func _apply_cam() -> void:
	_ensure_game_camera()
	_cam_zoom = clampf(_cam_zoom, 0.72, 1.65)
	var max_pan := 220.0 * _cam_zoom
	_cam_pan.x = clampf(_cam_pan.x, -max_pan, max_pan)
	_cam_pan.y = clampf(_cam_pan.y, -max_pan, max_pan)
	_game_cam.zoom = Vector2(_cam_zoom, _cam_zoom)
	_game_cam.offset = _cam_pan + _cam_punch


func _reset_cam_view() -> void:
	_cam_pan = Vector2.ZERO
	_cam_zoom = 1.0
	_cam_punch = Vector2.ZERO
	_apply_cam()


func _camera_punch(amount: Vector2 = Vector2(2, -1)) -> void:
	_ensure_game_camera()
	if _punch_tween != null:
		_punch_tween.kill()
	_cam_punch = amount
	_apply_cam()
	_punch_tween = create_tween()
	_punch_tween.tween_method(func(v: Vector2) -> void:
		_cam_punch = v
		_apply_cam()
	, _cam_punch, Vector2.ZERO, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _ensure_presentation_fx() -> void:
	var root: Control = $HUD/Root
	if _rim_flash == null or not is_instance_valid(_rim_flash):
		_rim_flash = Control.new()
		_rim_flash.name = "AlarmRim"
		_rim_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rim_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rim_flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_rim_flash.grow_vertical = Control.GROW_DIRECTION_BOTH
		_rim_flash.z_index = 40
		root.add_child(_rim_flash)
		var specs: Array = [
			["Top", Control.PRESET_TOP_WIDE, 0.0, 0.0, 0.0, 16.0],
			["Bottom", Control.PRESET_BOTTOM_WIDE, 0.0, -16.0, 0.0, 0.0],
			["Left", Control.PRESET_LEFT_WIDE, 0.0, 0.0, 16.0, 0.0],
			["Right", Control.PRESET_RIGHT_WIDE, -16.0, 0.0, 0.0, 0.0],
		]
		for spec in specs:
			var edge := ColorRect.new()
			edge.name = str(spec[0])
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			edge.color = Color(0.95, 0.32, 0.12, 0.0)
			edge.set_anchors_preset(int(spec[1]))
			edge.offset_left = float(spec[2])
			edge.offset_top = float(spec[3])
			edge.offset_right = float(spec[4])
			edge.offset_bottom = float(spec[5])
			_rim_flash.add_child(edge)
	if _tone_wash == null or not is_instance_valid(_tone_wash):
		_tone_wash = ColorRect.new()
		_tone_wash.name = "ToneWash"
		_tone_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tone_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_tone_wash.color = Color(0.10, 0.09, 0.08, 0.0)
		_tone_wash.z_index = 20
		root.add_child(_tone_wash)


func _alarm_edge_flash() -> void:
	_ensure_presentation_fx()
	if _rim_flash == null:
		return
	if _rim_tween != null:
		_rim_tween.kill()
	for c in _rim_flash.get_children():
		if c is ColorRect:
			(c as ColorRect).color = Color(0.95, 0.28, 0.10, 0.0)
	_rim_tween = create_tween()
	# Two screen-edge pulses so the lock reads as an alarm, not a single blink.
	for pulse_i in 2:
		_rim_tween.set_parallel(true)
		for c in _rim_flash.get_children():
			if c is ColorRect:
				_rim_tween.tween_property(c, "color:a", 0.82 if pulse_i == 0 else 0.55, 0.05)
		_rim_tween.chain()
		_rim_tween.set_parallel(true)
		for c in _rim_flash.get_children():
			if c is ColorRect:
				_rim_tween.tween_property(c, "color:a", 0.0, 0.16)
		_rim_tween.chain()
	_flash_alarm_button()
	_camera_punch(Vector2(8, -5))


func _flash_alarm_button() -> void:
	if alarm_button == null:
		return
	if _alarm_btn_tween != null:
		_alarm_btn_tween.kill()
	alarm_button.modulate = Color(1.55, 0.45, 0.28)
	alarm_button.pivot_offset = alarm_button.size * 0.5
	_alarm_btn_tween = create_tween()
	_alarm_btn_tween.tween_property(alarm_button, "scale", Vector2(1.08, 1.08), 0.06)
	_alarm_btn_tween.parallel().tween_property(alarm_button, "modulate", Color(1.55, 0.45, 0.28), 0.06)
	_alarm_btn_tween.tween_property(alarm_button, "scale", Vector2.ONE, 0.22)
	_alarm_btn_tween.parallel().tween_property(alarm_button, "modulate", Color.WHITE, 0.28)


func _play_result_tone(win: bool) -> void:
	_ensure_presentation_fx()
	if _tone_tween != null:
		_tone_tween.kill()
	var world: Node2D = $World
	var wash := Color(0.12, 0.10, 0.09, 0.28) if not win else Color(0.10, 0.14, 0.08, 0.18)
	var world_col := Color(0.62, 0.60, 0.58) if not win else Color(0.86, 0.92, 0.80)
	if _tone_wash:
		_tone_wash.color = Color(wash.r, wash.g, wash.b, 0.0)
	_tone_tween = create_tween()
	_tone_tween.tween_property(world, "modulate", world_col, 0.32)
	if _tone_wash:
		_tone_tween.parallel().tween_property(_tone_wash, "color:a", wash.a, 0.32)


func _reset_presentation_fx() -> void:
	if _tone_tween != null:
		_tone_tween.kill()
		_tone_tween = null
	if _rim_tween != null:
		_rim_tween.kill()
		_rim_tween = null
	if has_node("World"):
		$World.modulate = Color.WHITE
	if _tone_wash:
		_tone_wash.color.a = 0.0
	if _rim_flash:
		for c in _rim_flash.get_children():
			if c is ColorRect:
				(c as ColorRect).color.a = 0.0
	if result_panel:
		result_panel.modulate = Color.WHITE


func _fade_result_panel() -> void:
	if result_panel == null:
		return
	if _result_fade_tween != null:
		_result_fade_tween.kill()
	result_panel.modulate.a = 0.0
	_result_fade_tween = create_tween()
	_result_fade_tween.tween_property(result_panel, "modulate:a", 1.0, 0.22)


func _load_level(level_id: String, keep_intel: bool, restore_plan: bool) -> void:
	level = LevelDef.by_id(level_id)
	var idx := LEVEL_ORDER.find(level.level_id)
	if idx >= 0:
		level_index = idx
	var effective_door_locked := door_locked if restore_plan else false
	if not keep_intel:
		effective_door_locked = false
	grid.rebuild(level.level_id)
	if level.door_cell.x >= 0:
		grid.set_door_state(level.door_cell, effective_door_locked)
	else:
		grid.door_cell = Vector2i(-1, -1)
		grid.door_locked = false
	var geo_errs := grid.validate_level_geometry(
		level.cover_defs,
		level.route_cells,
		level.alternate_route_cells,
		level.door_blocks_route if (level.door_cell.x >= 0 and effective_door_locked) else "",
		level.barrel_cell
	)
	for e in geo_errs:
		push_error("LEVEL_GEO %s: %s" % [level.level_id, e])
	escape_world = grid.cell_to_world_center(level.escape_cell)
	escape_marker.position = escape_world
	map_draw.atmosphere_id = level.atmosphere_id if level.atmosphere_id != "" else level.level_id
	map_draw.set("grid", grid)
	map_draw.escape_cell = level.escape_cell
	map_draw.barrel_cell = level.barrel_cell
	map_draw.escape_flash = false
	if map_draw.has_method("invalidate_static_cache"):
		map_draw.invalidate_static_cache()
	map_draw.queue_redraw()
	_ensure_mission_sky()
	_build_route_world()
	_build_cover_slots()
	_build_operators()
	_draw_fixed_routes()
	_build_ambush_zone_visual()
	_build_door_marker()
	_build_barrels()
	_start_setup(keep_intel, restore_plan)
	_save_progress()
	_maybe_show_tutorial()


func _ensure_mission_sky() -> void:
	if mission_sky == null or not is_instance_valid(mission_sky):
		mission_sky = get_node_or_null("World/MissionSky")
	if mission_sky == null or not is_instance_valid(mission_sky):
		mission_sky = MissionSkyScript.new()
		mission_sky.name = "MissionSky"
		$World.add_child(mission_sky)
		if map_draw:
			$World.move_child(mission_sky, mini(map_draw.get_index() + 1, $World.get_child_count() - 1))
	if mission_sky.has_method("setup"):
		mission_sky.setup(level.atmosphere_id if level and level.atmosphere_id != "" else (level.level_id if level else "yard"))


func _build_route_world() -> void:
	route_world.clear()
	for key in level.route_cells.keys():
		route_world[key] = _cells_to_world(level.route_cells[key])


func _cells_to_world(cells: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for c in cells:
		out.append(grid.cell_to_world_center(c as Vector2i))
	return out


func _active_routes() -> Array:
	## Routes enemies will actually walk: skip locked door_blocks_route, include alt.
	var out: Array = []
	if level == null:
		return out
	for key in route_world.keys():
		if door_locked and level.door_blocks_route != "" and str(key) == level.door_blocks_route:
			continue
		out.append(route_world[key])
	if door_locked and not level.alternate_route_cells.is_empty():
		out.append(_cells_to_world(level.alternate_route_cells))
	return out


func _refresh_killzone_preview() -> void:
	if killzone_draw == null:
		return
	for c in killzone_draw.get_children():
		killzone_draw.remove_child(c)
		c.free()
	if phase != Phase.SETUP:
		return
	if selected == null or not selected.visible or not selected.alive:
		return
	const STEP := 16.0
	for route in _active_routes():
		var hit_run := PackedVector2Array()
		for p in _sample_polyline(route, STEP):
			if selected.in_fire_geometry(p, grid):
				hit_run.append(p)
			else:
				_add_killzone_line(hit_run)
				hit_run = PackedVector2Array()
		_add_killzone_line(hit_run)


func _sample_polyline(points: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.is_empty():
		return out
	if points.size() == 1:
		out.append(points[0])
		return out
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var dist := a.distance_to(b)
		var n := maxi(1, int(ceil(dist / spacing)))
		for s in n:
			out.append(a.lerp(b, float(s) / float(n)))
		if i == points.size() - 2:
			out.append(b)
	return out


func _add_killzone_line(pts: PackedVector2Array) -> void:
	if killzone_draw == null or pts.is_empty():
		return
	var line := Line2D.new()
	line.width = 8.0
	line.default_color = Color(0.95, 0.28, 0.18, 0.42)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	if pts.size() == 1:
		var p: Vector2 = pts[0]
		line.points = PackedVector2Array([p + Vector2(-5, 0), p + Vector2(5, 0)])
	else:
		line.points = pts
	killzone_draw.add_child(line)


func _build_cover_slots() -> void:
	for c in covers.get_children():
		c.queue_free()
	cover_slots.clear()
	var id := 0
	for d in level.cover_defs:
		var cell: Vector2i = d["cell"]
		var slot := _make_slot(id, str(d["name"]), grid.cell_to_world_center(cell))
		var face := float(d.get("face", 0.0))
		var protect := float(d.get("protect", face))
		slot.set_meta("default_face", face)
		slot.protect_facing_deg = protect
		slot.rebuild_protect_arc()
		covers.add_child(slot)
		cover_slots.append(slot)
		id += 1


func _make_slot(id: int, text: String, pos: Vector2) -> CoverSlot:
	var s := CoverSlot.new()
	s.position = pos
	var pad := Polygon2D.new()
	pad.name = "Pad"
	pad.polygon = PackedVector2Array([
		Vector2(-13, -10), Vector2(-8, -14), Vector2(8, -14), Vector2(13, -10),
		Vector2(13, 10), Vector2(8, 14), Vector2(-8, 14), Vector2(-13, 10)
	])
	pad.color = Color(0.30, 0.38, 0.24, 0.92)
	s.add_child(pad)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = text
	tag.position = Vector2(-40, 16)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(0.65, 0.85, 0.7))
	tag.z_index = 2
	s.add_child(tag)
	s.setup(id, text, 0.0)
	s.z_index = 0
	s.z_as_relative = true
	return s


func _build_operators() -> void:
	for o in operators:
		if is_instance_valid(o):
			o.queue_free()
	operators.clear()
	var defs := [
		{"id": 1, "name": OperatorUnit.role_codename(OperatorUnit.Role.RIFLE)},
		{"id": 2, "name": OperatorUnit.role_codename(OperatorUnit.Role.MG)},
		{"id": 3, "name": OperatorUnit.role_codename(OperatorUnit.Role.SCOUT)},
	]
	for d in defs:
		var op := _make_operator(int(d["id"]), str(d["name"]))
		entities.add_child(op)
		op.setup(int(d["id"]), str(d["name"]), grid)
		op.died.connect(_on_operator_died)
		op.fired_shot.connect(_on_op_fired_shot)
		op.ammo_empty.connect(_on_op_ammo_empty)
		op.ammo_repacked.connect(_on_op_ammo_repacked)
		op.visible = false
		operators.append(op)
	selected = operators[0]
	_refresh_selection_visual()


func _make_operator(id: int, pname: String) -> OperatorUnit:
	var op := OperatorUnit.new()
	op.op_id = id
	op.display_name = pname
	var outline := Polygon2D.new()
	outline.name = "BodyOutline"
	outline.color = Color(0.08, 0.14, 0.18, 0.95)
	op.add_child(outline)
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(0, -13), Vector2(9, 10), Vector2(-9, 10)
	])
	body.color = Color(0.35, 0.65, 0.95)
	op.add_child(body)
	var cone := Polygon2D.new()
	cone.name = "Cone"
	op.add_child(cone)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = pname
	tag.position = Vector2(-30, -32)
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", OperatorUnit.role_kit_color(OperatorUnit.role_for_id(id)))
	tag.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.03, 0.9))
	tag.add_theme_constant_override("shadow_offset_x", 1)
	tag.add_theme_constant_override("shadow_offset_y", 1)
	op.add_child(tag)
	var glyph := Polygon2D.new()
	glyph.name = "RoleGlyph"
	glyph.visible = true
	op.add_child(glyph)
	return op


func _draw_fixed_routes() -> void:
	for c in routes_draw.get_children():
		c.queue_free()
	var colors := {
		"main": Color(0.9, 0.4, 0.35, 0.35),
		"flank": Color(0.95, 0.55, 0.2, 0.3),
		"sneak": Color(0.55, 0.72, 0.38, 0.32),
	}
	var labels := {"main": "主路线", "flank": "侧翼路线", "sneak": "西暗道"}
	for key in route_world.keys():
		var col: Color = colors.get(key, Color(0.7, 0.7, 0.4, 0.3))
		_add_route_line(route_world[key], col, str(labels.get(key, key)))
	if not level.alternate_route_cells.is_empty():
		_add_route_line(
			_cells_to_world(level.alternate_route_cells),
			Color(0.62, 0.52, 0.28, 0.32),
			"备用接近"
		)


func _add_route_line(points: PackedVector2Array, color: Color, label: String) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	line.points = points
	routes_draw.add_child(line)
	if points.size() > 1:
		var t := Label.new()
		t.text = label
		var idx := mini(2, points.size() - 1)
		t.position = points[idx] + Vector2(8, -18)
		t.add_theme_font_size_override("font_size", 12)
		t.add_theme_color_override("font_color", color)
		routes_draw.add_child(t)


func _build_ambush_zone_visual() -> void:
	if ambush_zone_poly != null and is_instance_valid(ambush_zone_poly):
		ambush_zone_poly.queue_free()
	ambush_zone_poly = null
	if level.ambush_zone.size == Vector2.ZERO:
		return
	var fx = AmbushZoneFxScript.new()
	fx.name = "AmbushZone"
	fx.setup(level.ambush_zone)
	$World.add_child(fx)
	ambush_zone_poly = fx


func _build_door_marker() -> void:
	if door_marker != null and is_instance_valid(door_marker):
		door_marker.queue_free()
	door_marker = null
	if level.door_cell.x < 0:
		return
	var n := Node2D.new()
	n.name = "DoorMarker"
	n.position = grid.cell_to_world_center(level.door_cell)
	var pad := Polygon2D.new()
	pad.name = "Polygon2D"
	pad.polygon = PackedVector2Array([
		Vector2(-10, -14), Vector2(10, -14), Vector2(10, 14), Vector2(-10, 14)
	])
	pad.color = Color(0.55, 0.4, 0.25, 0.7)
	n.add_child(pad)
	var leaf := Polygon2D.new()
	leaf.name = "DoorLeaf"
	leaf.polygon = PackedVector2Array([
		Vector2(0, -13), Vector2(18, -13), Vector2(18, 13), Vector2(0, 13)
	])
	leaf.position = Vector2(-10, 0)
	leaf.color = Color(0.62, 0.42, 0.22, 0.92)
	n.add_child(leaf)
	var hinge := Polygon2D.new()
	hinge.name = "Hinge"
	hinge.polygon = PackedVector2Array([
		Vector2(-12, -4), Vector2(-7, -4), Vector2(-7, 4), Vector2(-12, 4)
	])
	hinge.color = Color(0.18, 0.14, 0.10, 0.95)
	n.add_child(hinge)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "门"
	tag.position = Vector2(-10, -28)
	tag.add_theme_font_size_override("font_size", 12)
	n.add_child(tag)
	routes_draw.add_child(n)
	door_marker = n
	_refresh_door_visual()


func _refresh_door_visual(animate: bool = false) -> void:
	if door_marker == null or not is_instance_valid(door_marker):
		return
	var pad := door_marker.get_node_or_null("Polygon2D") as Polygon2D
	if pad == null and door_marker.get_child_count() > 0:
		pad = door_marker.get_child(0) as Polygon2D
	var leaf := door_marker.get_node_or_null("DoorLeaf") as Polygon2D
	var tag := door_marker.get_node_or_null("Tag") as Label
	var locked_col := Color(0.88, 0.22, 0.16, 0.92)
	var open_col := Color(0.55, 0.4, 0.25, 0.7)
	var target_rot := 0.0 if door_locked else -1.15
	if pad:
		pad.color = locked_col if door_locked else open_col
	if tag:
		tag.text = "门·锁" if door_locked else "门·开"
		tag.add_theme_color_override("font_color", Color(1.0, 0.45, 0.28) if door_locked else Color(0.85, 0.78, 0.55))
	if leaf:
		leaf.color = locked_col if door_locked else Color(0.62, 0.42, 0.22, 0.92)
		if animate:
			if _door_tween != null:
				_door_tween.kill()
			_door_tween = create_tween()
			_door_tween.tween_property(leaf, "rotation", target_rot, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			var flash := Color(1.0, 0.92, 0.55, 1.0)
			leaf.modulate = flash
			_door_tween.parallel().tween_property(leaf, "modulate", Color.WHITE, 0.22)
			if pad:
				pad.modulate = flash
				_door_tween.parallel().tween_property(pad, "modulate", Color.WHITE, 0.22)
		else:
			leaf.rotation = target_rot
	if door_button:
		door_button.text = "门: 锁闭 (B)" if door_locked else "门: 畅通 (B)"
		door_button.visible = level != null and level.door_cell.x >= 0
		if animate:
			door_button.modulate = Color(1.4, 0.7, 0.4) if door_locked else Color(0.85, 1.2, 0.7)
			var bt := door_button.create_tween()
			bt.tween_property(door_button, "modulate", Color.WHITE, 0.28)


func _start_setup(keep_intel: bool, restore_plan: bool) -> void:
	phase = Phase.SETUP
	tool = Tool.DEPLOY
	fail_reason = ""
	pending_result = ""
	run_id += 1
	sim.reset()
	battle_log.clear()
	pending_spawns.clear()
	all_spawns_done = false
	_watch_first_fire = false
	_watch_first_return = false
	_restored_this_setup = false
	plan_restore_hint = ""
	_clear_enemies()
	_clear_tripwires()
	_clear_loot()
	_clear_return_fx()
	if not keep_intel:
		intel_paths.clear()
		intel.clear()
		loop_index = 1
		last_plan.clear()
		door_locked = false
	if restore_plan and not last_plan.deployments.is_empty():
		_restore_last_plan()
	else:
		_clear_deployments()
		door_locked = last_plan.door_locked if restore_plan else false
	if level != null and level.door_cell.x >= 0:
		grid.set_door_state(level.door_cell, door_locked)
	_redraw_ghosts()
	_refresh_door_visual()
	for op in operators:
		if op.visible:
			op._rebuild_cone()
	_update_cover_previews()
	_update_observation_rings()
	_update_role_cards()
	_refresh_killzone_preview()
	_update_tripwire_ghost()
	alarm_button.disabled = false
	clear_button.disabled = false
	tool_button.disabled = false
	if mode_button:
		mode_button.disabled = false
	if pack_button:
		pack_button.disabled = false
		pack_button.visible = level != null and level.has_ammo_pack
	if door_button:
		door_button.disabled = false
		door_button.visible = level != null and level.door_cell.x >= 0
	if pause_button:
		pause_button.disabled = true
		pause_button.text = "暂停"
	if speed_button:
		speed_button.disabled = true
		speed_button.text = "速度 1×"
	result_panel.visible = false
	if abort_button:
		abort_button.visible = false
		abort_button.disabled = true
	if replay_button:
		replay_button.visible = false
	if title_return_button:
		title_return_button.visible = false
	if scrub_slider:
		scrub_slider.visible = false
	_clear_replay_layer()
	_clear_focus_ring()
	_reset_escape_flash()
	_reset_result_panel_pos()
	_reset_barrels()
	replay_focus_actor = -1
	replay_focus_type = ""
	if has_node("World"):
		$World.position = Vector2.ZERO
	if _punch_tween != null:
		_punch_tween.kill()
		_punch_tween = null
	if _game_cam != null:
		_reset_cam_view()
	_reset_presentation_fx()
	_update_event_log()
	_update_hud()


func _on_clear_pressed() -> void:
	if phase != Phase.SETUP:
		return
	_clear_deployments()
	status_label.text = "已收回部署（记忆与绊索保留）"
	_announce_plan_edit()
	_update_hud()


func _clear_deployments() -> void:
	for slot in cover_slots:
		slot.occupied_by = null
		slot.set_highlight(false)
	for op in operators:
		op.has_ammo_pack = false
		op.fire_mode = OperatorUnit.FireMode.ENGAGE_ON_SIGHT
		op.reset_loadout()
		op.slot = null
		op.visible = false
		op.position = Vector2(-1000, -1000)
	selected = operators[0] if operators.size() > 0 else null
	_refresh_selection_visual()
	_refresh_mode_pack_buttons()
	_update_cover_previews()
	_update_observation_rings()
	_refresh_killzone_preview()
	_update_tripwire_ghost()


func _capture_plan() -> void:
	_fill_plan(last_plan)


func _fill_plan(p: PlanState) -> void:
	p.clear()
	for op in operators:
		if op.visible and op.slot != null:
			p.deployments.append({
				"op_id": op.op_id,
				"slot_id": op.slot.slot_id,
				"facing": op.facing_deg,
				"fire_mode": op.fire_mode,
				"has_ammo_pack": op.has_ammo_pack,
			})
	p.tripwire_positions.clear()
	for t in tripwires:
		if is_instance_valid(t):
			p.tripwire_positions.append(t.position)
	p.door_locked = door_locked


func _live_plan() -> PlanState:
	var p := PlanState.new()
	_fill_plan(p)
	return p


func _restore_last_plan() -> void:
	_plan_diff_guard = true
	_clear_deployments()
	_clear_tripwires()
	door_locked = last_plan.door_locked
	for entry in last_plan.deployments:
		var op := _op_by_id(int(entry["op_id"]))
		var slot := _slot_by_id(int(entry["slot_id"]))
		if op == null or slot == null:
			continue
		selected = op
		_deploy_selected_to(slot, false)
		op.fire_mode = int(entry.get("fire_mode", OperatorUnit.FireMode.ENGAGE_ON_SIGHT))
		op.has_ammo_pack = bool(entry.get("has_ammo_pack", false))
		op.reset_loadout()
		op.set_facing(float(entry["facing"]))
	for pos in last_plan.tripwire_positions:
		var tw := _make_tripwire(pos)
		entities.add_child(tw)
		tripwires.append(tw)
	if operators.size() > 0:
		selected = operators[0]
		_refresh_selection_visual()
	_refresh_door_visual()
	_refresh_mode_pack_buttons()
	_update_observation_rings()
	_refresh_killzone_preview()
	_restored_this_setup = true
	_plan_diff_guard = false
	var summary := _plan_summary_text(last_plan)
	plan_restore_hint = "已恢复上轮计划：%s" % summary
	status_label.text = plan_restore_hint
	_flash(plan_restore_hint, Color(0.7, 0.92, 0.75))


func _compass_deg(deg: float) -> String:
	var d := fposmod(deg, 360.0)
	if d >= 315.0 or d < 45.0:
		return "东"
	if d < 135.0:
		return "南"
	if d < 225.0:
		return "西"
	return "北"


func _plan_summary_text(plan: PlanState) -> String:
	if plan == null or plan.deployments.is_empty():
		return "无部署"
	var parts: PackedStringArray = []
	for entry in plan.deployments:
		var op := _op_by_id(int(entry["op_id"]))
		var slot := _slot_by_id(int(entry["slot_id"]))
		var nm := op.display_name if op else ("队员%d" % int(entry["op_id"]))
		var sn := slot.label_text if slot else ("位%d" % int(entry["slot_id"]))
		var face := float(entry["facing"])
		parts.append("%s→「%s」朝%s%d°" % [nm, sn, _compass_deg(face), int(face)])
	if plan.door_locked:
		parts.append("门锁")
	if plan.tripwire_positions.size() > 0:
		parts.append("绊索%d" % plan.tripwire_positions.size())
	return " · ".join(parts)


func _diff_vs_last_plan() -> String:
	if last_plan == null:
		return ""
	var live := _live_plan()
	var bits: PackedStringArray = []
	var old_map := {}
	for e in last_plan.deployments:
		old_map[int(e["op_id"])] = e
	var live_map := {}
	for e in live.deployments:
		var oid := int(e["op_id"])
		live_map[oid] = e
		var op := _op_by_id(oid)
		var nm := op.display_name if op else str(oid)
		if not old_map.has(oid):
			var slot := _slot_by_id(int(e["slot_id"]))
			bits.append("%s新部署「%s」" % [nm, slot.label_text if slot else "?"])
			continue
		var oe: Dictionary = old_map[oid]
		if int(oe["slot_id"]) != int(e["slot_id"]):
			var os := _slot_by_id(int(oe["slot_id"]))
			var ns := _slot_by_id(int(e["slot_id"]))
			bits.append("%s「%s」→「%s」" % [
				nm,
				os.label_text if os else "?",
				ns.label_text if ns else "?"
			])
		if absf(float(oe["facing"]) - float(e["facing"])) > 0.51:
			bits.append("%s朝向%d°→%d°" % [nm, int(oe["facing"]), int(e["facing"])])
		if int(oe.get("fire_mode", 0)) != int(e.get("fire_mode", 0)):
			bits.append("%s开火条件已改" % nm)
		if bool(oe.get("has_ammo_pack", false)) != bool(e.get("has_ammo_pack", false)):
			bits.append("%s弹包已改" % nm)
	for oid in old_map.keys():
		if not live_map.has(oid):
			var op2 := _op_by_id(int(oid))
			bits.append("%s已收回" % (op2.display_name if op2 else str(oid)))
	if last_plan.door_locked != live.door_locked:
		bits.append("门:%s" % ("锁闭" if live.door_locked else "畅通"))
	if last_plan.tripwire_positions.size() != live.tripwire_positions.size():
		bits.append("绊索%d→%d" % [last_plan.tripwire_positions.size(), live.tripwire_positions.size()])
	return "；".join(bits)


func _announce_plan_edit() -> void:
	if _plan_diff_guard or not _restored_this_setup:
		return
	if last_plan.deployments.is_empty():
		return
	var diff := _diff_vs_last_plan()
	if diff == "":
		return
	var msg := "相对上轮：%s" % diff
	status_label.text = msg
	_flash(msg, Color(0.95, 0.82, 0.4))


func _op_by_id(id: int) -> OperatorUnit:
	for op in operators:
		if op.op_id == id:
			return op
	return null


func _slot_by_id(id: int) -> CoverSlot:
	for s in cover_slots:
		if s.slot_id == id:
			return s
	return null


func _clear_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()


func _clear_tripwires() -> void:
	for t in tripwires:
		if is_instance_valid(t):
			t.queue_free()
	tripwires.clear()


func _clear_loot() -> void:
	for l in loot_piles:
		if is_instance_valid(l):
			l.queue_free()
	loot_piles.clear()
	for n in get_tree().get_nodes_in_group("loot"):
		if is_instance_valid(n):
			n.queue_free()


func _clear_return_fx() -> void:
	for fx in return_fire_fx:
		if is_instance_valid(fx):
			fx.queue_free()
	return_fire_fx.clear()


func _toggle_tool() -> void:
	if phase != Phase.SETUP:
		return
	tool = Tool.TRIPWIRE if tool == Tool.DEPLOY else Tool.DEPLOY
	tool_button.text = "工具: 部署队员" if tool == Tool.DEPLOY else "工具: 绊索(后勤)"
	status_label.text = "部署到掩体位，A/D 调整射界" if tool == Tool.DEPLOY else "在路线线段附近放绊索（最多1）"
	_update_tripwire_ghost()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _touch_ate_click:
		if not event.pressed:
			_touch_ate_click = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		_toggle_mute()
		if pause_overlay and pause_overlay.is_open():
			pause_overlay._refresh_audio()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if tutorial_overlay and tutorial_overlay.is_open():
			get_viewport().set_input_as_handled()
			return
		if credits_overlay and credits_overlay.is_open():
			_return_to_title()
			get_viewport().set_input_as_handled()
			return
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if _handle_touch_gestures(event):
		get_viewport().set_input_as_handled()
		return
	if _modal_blocks_input():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("reset_run"):
		loop_index = 1
		intel_paths.clear()
		intel.clear()
		last_plan.clear()
		_start_setup(false, false)
		get_viewport().set_input_as_handled()
		return

	if phase == Phase.REPLAY:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_LEFT:
					replay.set_tick(replay.scrub_tick - 6)
					_apply_replay_scrub()
				KEY_RIGHT:
					replay.set_tick(replay.scrub_tick + 6)
					_apply_replay_scrub()
				KEY_SPACE:
					_exit_replay_to_setup()
			get_viewport().set_input_as_handled()
		return

	if phase == Phase.WATCHING:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_P, KEY_SPACE:
					_on_pause_pressed()
				KEY_X:
					_on_abort_pressed()
				KEY_EQUAL, KEY_KP_ADD:
					sim.set_speed(2.0)
					if speed_button:
						speed_button.text = "速度 2×"
				KEY_MINUS, KEY_KP_SUBTRACT:
					sim.set_speed(1.0)
					if speed_button:
						speed_button.text = "速度 1×"
			get_viewport().set_input_as_handled()
		return

	if phase != Phase.SETUP:
		return

	if event.is_action_pressed("sound_alarm"):
		_on_alarm_pressed()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				_select_op(0)
			KEY_2:
				_select_op(1)
			KEY_3:
				_select_op(2)
			KEY_A, KEY_Q:
				if selected and selected.visible:
					selected.rotate_by(-15.0)
					_announce_plan_edit()
					_refresh_killzone_preview()
			KEY_D, KEY_E:
				if selected and selected.visible:
					selected.rotate_by(15.0)
					_announce_plan_edit()
					_refresh_killzone_preview()
			KEY_F:
				_on_mode_pressed()
			KEY_G:
				_on_pack_pressed()
			KEY_B:
				_on_door_pressed()
			KEY_TAB:
				_toggle_tool()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_setup_click(get_global_mouse_position())
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if selected and selected.visible and not selected.locked:
			var v := get_global_mouse_position() - selected.global_position
			selected.set_facing(rad_to_deg(atan2(v.y, v.x)))
			_announce_plan_edit()
			_refresh_killzone_preview()
		get_viewport().set_input_as_handled()
		return


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _touch_span() -> Dictionary:
	var keys: Array = _touches.keys()
	if keys.size() < 2:
		return {"dist": 0.0, "mid": Vector2.ZERO}
	var a: Vector2 = _touches[keys[0]]
	var b: Vector2 = _touches[keys[1]]
	return {"dist": a.distance_to(b), "mid": (a + b) * 0.5}


func _handle_touch_gestures(event: InputEvent) -> bool:
	if event is InputEventMagnifyGesture:
		_cam_zoom *= (event as InputEventMagnifyGesture).factor
		_apply_cam()
		return true
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() >= 2:
				_facing_touch = -1
				_pending_setup_touch = false
				_cover_hold_slot = null
				var span: Dictionary = _touch_span()
				_pinch_start_dist = float(span["dist"])
				_pinch_start_zoom = _cam_zoom
				_pinch_start_mid = span["mid"]
				return true
			if _modal_blocks_input():
				return true
			if phase == Phase.SETUP:
				var world := _screen_to_world(st.position)
				_touch_preview_slot = null
				_pending_setup_touch = true
				_pending_touch_world = world
				_touch_dragged = false
				_cover_hold_slot = _nearest_slot(world, 32.0)
				_cover_hold_msec = Time.get_ticks_msec()
				if selected and selected.visible and world.distance_to(selected.global_position) <= 44.0:
					_facing_touch = st.index
				_touch_ate_click = true
			return true
		_touches.erase(st.index)
		if _facing_touch == st.index:
			_facing_touch = -1
		_pinch_start_dist = 0.0
		if phase == Phase.SETUP and _pending_setup_touch:
			if not _touch_dragged and _touch_preview_slot == null:
				_handle_setup_click(_pending_touch_world)
			_pending_setup_touch = false
			_cover_hold_slot = null
		return true
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var span2: Dictionary = _touch_span()
			var dist: float = float(span2["dist"])
			if _pinch_start_dist > 8.0:
				_cam_zoom = _pinch_start_zoom * (dist / _pinch_start_dist)
			var mid: Vector2 = span2["mid"]
			var mid_delta: Vector2 = mid - _pinch_start_mid
			_pinch_start_mid = mid
			_cam_pan -= mid_delta / maxf(_cam_zoom, 0.01)
			_apply_cam()
			return true
		if phase == Phase.SETUP and sd.index == _facing_touch and selected and selected.visible and not selected.locked:
			var world2 := _screen_to_world(sd.position)
			var v := world2 - selected.global_position
			if v.length() > 10.0:
				selected.set_facing(rad_to_deg(atan2(v.y, v.x)))
				_announce_plan_edit()
				_refresh_killzone_preview()
				_touch_dragged = true
				_cover_hold_slot = null
			return true
		if phase == Phase.SETUP and sd.relative.length() >= 8.0:
			_touch_dragged = true
			_cover_hold_slot = null
			_cam_pan -= sd.relative / maxf(_cam_zoom, 0.01)
			_apply_cam()
			return true
		return false
	return false


func _select_op(idx: int) -> void:
	if phase == Phase.REPLAY:
		return
	if idx < 0 or idx >= operators.size():
		return
	selected = operators[idx]
	_refresh_selection_visual()
	_update_role_cards()
	if phase != Phase.SETUP:
		return
	tool = Tool.DEPLOY
	tool_button.text = "工具: 部署队员"
	_refresh_mode_pack_buttons()
	status_label.text = "已选择 %s — %s" % [selected.display_name, selected.kit_blurb()]
	_update_cover_previews()
	_refresh_killzone_preview()
	_update_hud()


func _refresh_selection_visual() -> void:
	for op in operators:
		if op.body:
			if op == selected and op.visible:
				op.body.color = Color(0.95, 0.85, 0.35)
			else:
				op.body.color = op.body_color if op.alive else Color(0.25, 0.28, 0.32)


func _refresh_mode_pack_buttons() -> void:
	if mode_button and selected:
		mode_button.text = "开火: %s (F)" % selected.fire_mode_label()
	if pack_button:
		pack_button.visible = level != null and level.has_ammo_pack
		if selected and selected.has_ammo_pack:
			pack_button.text = "弹包: %s (G)" % selected.display_name
		else:
			pack_button.text = "弹包分配 (G)"


func _handle_setup_click(world_pos: Vector2) -> void:
	if tool == Tool.TRIPWIRE:
		_try_place_tripwire(world_pos)
		return
	var slot := _nearest_slot(world_pos, 28.0)
	if slot:
		_deploy_selected_to(slot, true)
		return
	for op in operators:
		if op.visible and op.global_position.distance_to(world_pos) <= 20.0:
			selected = op
			_refresh_selection_visual()
			_refresh_mode_pack_buttons()
			status_label.text = "已选择 %s — %s" % [op.display_name, op.kit_blurb()]
			_update_cover_previews()
			_refresh_killzone_preview()
			_update_hud()
			return


func _nearest_slot(world_pos: Vector2, max_dist: float) -> CoverSlot:
	var best: CoverSlot = null
	var best_d := max_dist
	for s in cover_slots:
		var d := s.global_position.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = s
	return best


func _deploy_selected_to(slot: CoverSlot, announce: bool = true) -> void:
	if selected == null:
		return
	if selected.slot:
		selected.slot.occupied_by = null
		selected.slot.set_highlight(false)
	if slot.occupied_by and slot.occupied_by != selected:
		var other: OperatorUnit = slot.occupied_by
		other.slot = null
		other.visible = false
		other.position = Vector2(-1000, -1000)
	slot.occupied_by = selected
	slot.set_highlight(true)
	selected.slot = slot
	selected.visible = true
	selected.global_position = slot.global_position
	var face := float(slot.get_meta("default_face"))
	selected.reset_loadout()
	selected.set_facing(face)
	_refresh_selection_visual()
	_refresh_mode_pack_buttons()
	_update_cover_previews()
	if announce:
		var prot := slot.protect_compass()
		status_label.text = "%s →「%s」弹%d · 保护弧朝%s（来袭减伤60%%，侧背无减免）" % [
			selected.display_name, slot.label_text, selected.ammo, prot
		]
		_announce_plan_edit()
	_update_observation_rings()
	_refresh_killzone_preview()
	_update_hud()


func _try_place_tripwire(world_pos: Vector2) -> void:
	if tripwires.size() >= MAX_TRIPWIRES:
		status_label.text = "绊索已用完（后勤限额 1）"
		return
	if not _near_any_route_segment(world_pos, TRIPWIRE_ROUTE_DIST):
		status_label.text = "绊索只能布在路线线段附近"
		return
	var tw := _make_tripwire(world_pos)
	entities.add_child(tw)
	tripwires.append(tw)
	status_label.text = "绊索已埋伏"
	_announce_plan_edit()
	_update_hud()


func _near_any_route_segment(pos: Vector2, max_dist: float) -> bool:
	for route in _active_routes():
		if _dist_to_polyline(pos, route) <= max_dist:
			return true
	return false


func _dist_to_polyline(pos: Vector2, points: PackedVector2Array) -> float:
	if points.is_empty():
		return INF
	if points.size() == 1:
		return pos.distance_to(points[0])
	var best := INF
	for i in range(points.size() - 1):
		best = minf(best, _dist_point_to_segment(pos, points[i], points[i + 1]))
	return best


func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _make_tripwire(pos: Vector2) -> Tripwire:
	var t := Tripwire.new()
	t.position = pos
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = PackedVector2Array([
		Vector2(-13, -1.2), Vector2(13, -1.2), Vector2(13, 1.2), Vector2(-13, 1.2)
	])
	visual.color = Color(0.55, 0.98, 0.58, 0.55)
	t.add_child(visual)
	var wire := Line2D.new()
	wire.name = "Wire"
	wire.width = 1.4
	wire.default_color = Color(0.62, 0.98, 0.55, 0.92)
	wire.points = PackedVector2Array([Vector2(-12, 0), Vector2(12, 0)])
	t.add_child(wire)
	var peg_a := Polygon2D.new()
	peg_a.name = "PegA"
	peg_a.polygon = PackedVector2Array([
		Vector2(-16, -6), Vector2(-10, -6), Vector2(-10, 6), Vector2(-16, 6)
	])
	peg_a.color = Color(0.18, 0.32, 0.2, 0.95)
	t.add_child(peg_a)
	var peg_b := Polygon2D.new()
	peg_b.name = "PegB"
	peg_b.polygon = PackedVector2Array([
		Vector2(10, -6), Vector2(16, -6), Vector2(16, 6), Vector2(10, 6)
	])
	peg_b.color = Color(0.18, 0.32, 0.2, 0.95)
	t.add_child(peg_b)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "绊索"
	tag.position = Vector2(-16, -20)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(tag)
	return t


func _build_barrels() -> void:
	_clear_barrels()
	if level == null or level.barrel_cell.x < 0:
		return
	if grid.is_blocked(level.barrel_cell.x, level.barrel_cell.y):
		push_error("BARREL blocked %s %s" % [level.level_id, str(level.barrel_cell)])
		return
	var b := _make_barrel(grid.cell_to_world_center(level.barrel_cell))
	entities.add_child(b)
	barrels.append(b)


func _clear_barrels() -> void:
	for b in barrels:
		if is_instance_valid(b):
			b.queue_free()
	barrels.clear()


func _reset_barrels() -> void:
	for b in barrels:
		if is_instance_valid(b):
			b.reset_fuse()
			b.visible = true


func _make_barrel(pos: Vector2) -> Node2D:
	var b = preload("res://scripts/barrel.gd").new()
	b.position = pos
	b.z_index = 2
	var vis := Polygon2D.new()
	vis.name = "Visual"
	vis.polygon = PackedVector2Array([
		Vector2(-9, -13), Vector2(9, -13), Vector2(10, 13), Vector2(-10, 13)
	])
	vis.color = Color(0.98, 0.48, 0.08, 0.98)
	b.add_child(vis)
	var band := Polygon2D.new()
	band.name = "Band"
	band.polygon = PackedVector2Array([
		Vector2(-10, -3), Vector2(10, -3), Vector2(10, 3), Vector2(-10, 3)
	])
	band.color = Color(0.12, 0.07, 0.04, 0.95)
	b.add_child(band)
	var band2 := Polygon2D.new()
	band2.name = "Band2"
	band2.polygon = PackedVector2Array([
		Vector2(-9, 6), Vector2(10, 6), Vector2(10, 9), Vector2(-9, 9)
	])
	band2.color = Color(0.12, 0.07, 0.04, 0.9)
	b.add_child(band2)
	var band3 := Polygon2D.new()
	band3.name = "Band3"
	band3.polygon = PackedVector2Array([
		Vector2(-9, -9), Vector2(9, -9), Vector2(9, -6), Vector2(-9, -6)
	])
	band3.color = Color(0.12, 0.07, 0.04, 0.88)
	b.add_child(band3)
	var lid := Polygon2D.new()
	lid.name = "Lid"
	lid.polygon = PackedVector2Array([
		Vector2(-8, -16), Vector2(8, -16), Vector2(7, -12), Vector2(-7, -12)
	])
	lid.color = Color(0.62, 0.32, 0.10, 0.96)
	b.add_child(lid)
	var blast := Polygon2D.new()
	blast.name = "BlastPreview"
	var pts := PackedVector2Array()
	for i in 12:
		var r := deg_to_rad(float(i) * 30.0)
		pts.append(Vector2(cos(r), sin(r)) * 52.0)
	blast.polygon = pts
	blast.color = Color(0.98, 0.42, 0.08, 0.18)
	blast.show_behind_parent = true
	b.add_child(blast)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "油桶"
	tag.position = Vector2(-16, -28)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(1.0, 0.62, 0.22))
	b.add_child(tag)
	b.detonated.connect(_on_barrel_detonated)
	return b


func _on_barrel_detonated(barrel: Node2D) -> void:
	if phase == Phase.WATCHING or pending_result != "":
		battle_log.add_event(sim.tick, "barrel", -1, -1, barrel.global_position)
	_flash("油桶爆炸", Color(1.0, 0.45, 0.2))
	_update_event_log()


func _deployed_count() -> int:
	var n := 0
	for op in operators:
		if op.visible and op.slot != null:
			n += 1
	return n


func _on_mode_pressed() -> void:
	if phase != Phase.SETUP or selected == null or not selected.visible:
		return
	selected.cycle_fire_mode()
	_refresh_mode_pack_buttons()
	status_label.text = "%s 开火模式：%s" % [selected.display_name, selected.fire_mode_label()]
	_announce_plan_edit()
	_refresh_killzone_preview()
	_update_hud()


func _on_pack_pressed() -> void:
	if phase != Phase.SETUP or level == null or not level.has_ammo_pack:
		return
	if selected == null or not selected.visible:
		status_label.text = "先部署并选中一名队员再分配弹包"
		return
	if selected.has_ammo_pack:
		selected.has_ammo_pack = false
		selected.reset_loadout()
		status_label.text = "%s 卸下备用弹包" % selected.display_name
	else:
		for op in operators:
			op.has_ammo_pack = false
			if op.visible:
				op.reset_loadout()
				op.set_facing(op.facing_deg)
		selected.has_ammo_pack = true
		selected.reset_loadout()
		selected.set_facing(selected.facing_deg)
		status_label.text = "%s 携带备用弹包（空弹自动补一次）" % selected.display_name
	_refresh_mode_pack_buttons()
	_announce_plan_edit()
	_update_hud()


func _on_door_pressed() -> void:
	if phase != Phase.SETUP or level == null or level.door_cell.x < 0:
		return
	door_locked = not door_locked
	grid.set_door_state(level.door_cell, door_locked)
	if map_draw.has_method("invalidate_static_cache"):
		map_draw.invalidate_static_cache()
	map_draw.queue_redraw()
	_refresh_door_visual(true)
	for op in operators:
		if op.visible:
			op._rebuild_cone()
	_update_cover_previews()
	status_label.text = "门已锁闭 — 侧翼改走备用接近" if door_locked else "门保持畅通"
	_announce_plan_edit()
	_refresh_killzone_preview()
	_update_hud()


func _on_speed_pressed() -> void:
	if phase != Phase.WATCHING:
		return
	sim.set_speed(1.0 if sim.speed >= 1.5 else 2.0)
	if speed_button:
		speed_button.text = "速度 2×" if sim.speed >= 1.5 else "速度 1×"


func _on_pause_pressed() -> void:
	if phase != Phase.WATCHING:
		return
	sim.toggle_pause()
	if pause_button:
		pause_button.text = "继续" if sim.paused else "暂停"


func _on_alarm_pressed() -> void:
	if phase != Phase.SETUP:
		return
	if _deployed_count() < 1:
		status_label.text = "至少部署一名队员到掩体"
		return
	_capture_plan()
	frozen_plan = last_plan.duplicate_plan()
	run_id += 1
	var this_run := run_id
	phase = Phase.WATCHING
	sim.reset()
	battle_log.clear()
	_watch_first_fire = false
	_watch_first_return = false
	_sfx("alarm")
	_alarm_edge_flash()
	_update_observation_rings()
	alarm_button.disabled = true
	clear_button.disabled = true
	tool_button.disabled = true
	if mode_button:
		mode_button.disabled = true
	if pack_button:
		pack_button.disabled = true
	if door_button:
		door_button.disabled = true
	if pause_button:
		pause_button.disabled = false
	if speed_button:
		speed_button.disabled = false
	for op in operators:
		if op.visible:
			op.last_deny.clear()
			op.lock_plan()
			op._rebuild_cone()
	_update_cover_previews()
	_refresh_killzone_preview()
	_update_tripwire_ghost()
	battle_log.add_event(0, "door", -1, -1, Vector2.ZERO, {"locked": door_locked})
	_queue_spawns(this_run)
	if abort_button:
		abort_button.visible = true
		abort_button.disabled = false
	if pause_button:
		pause_button.disabled = false
	if speed_button:
		speed_button.disabled = false
	status_label.text = "方案锁死 — 暂停/变速仅改变观看。跑掉或全灭均失败。中止(X)保留截止情报。"
	_update_event_log()
	_update_hud()


func _queue_spawns(_this_run: int) -> void:
	_clear_enemies()
	_clear_loot()
	pending_spawns.clear()
	all_spawns_done = false
	for spec in level.spawn_schedule:
		pending_spawns.append({
			"id": int(spec["id"]),
			"route": str(spec["route"]),
			"delay": float(spec["delay"]),
			"loot": int(spec["loot"]),
			"spawned": false,
		})


func _route_for_spawn(route_name: String) -> PackedVector2Array:
	## Always the authored primary. Locked-door branch happens at the decision cell.
	if route_world.has(route_name):
		return route_world[route_name]
	for key in route_world.keys():
		return route_world[key]
	return PackedVector2Array()


func _spawn_one(spec: Dictionary) -> void:
	var e := _make_enemy(int(spec["id"]))
	entities.add_child(e)
	var route_name := str(spec["route"])
	var route := _route_for_spawn(route_name)
	e.setup(int(spec["id"]), route, grid, int(spec["loot"]), route_name)
	e.return_fired.connect(_on_return_fired)
	enemies.append(e)
	e.activate()
	battle_log.add_event(sim.tick, "spawn", e.label_id, -1, e.global_position)
	_update_event_log()


func _make_enemy(id: int) -> EnemyRunner:
	var e := EnemyRunner.new()
	var outline := Polygon2D.new()
	outline.name = "BodyOutline"
	outline.color = Color(0.18, 0.04, 0.04, 0.95)
	e.add_child(outline)
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([Vector2(0, -13), Vector2(9, 0), Vector2(0, 11), Vector2(-9, 0)])
	body.color = Color(0.82, 0.16, 0.14)
	e.add_child(body)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "敌%d" % id
	tag.position = Vector2(-16, -36)
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.9))
	tag.add_theme_constant_override("shadow_offset_x", 1)
	tag.add_theme_constant_override("shadow_offset_y", 1)
	e.add_child(tag)
	var hp := Polygon2D.new()
	hp.name = "HpBar"
	e.add_child(hp)
	e.escaped.connect(_on_enemy_escaped)
	e.died.connect(_on_enemy_died)
	return e


func _spawn_loot_at(pos: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	var loot := LootPickup.new()
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = PackedVector2Array([
		Vector2(-7, -7), Vector2(7, -7), Vector2(7, 7), Vector2(-7, 7)
	])
	visual.color = Color(0.95, 0.85, 0.25)
	loot.add_child(visual)
	var tag := Label.new()
	tag.name = "Tag"
	tag.position = Vector2(-14, -22)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	loot.add_child(tag)
	entities.add_child(loot)
	loot.global_position = pos
	loot.setup(amount)
	loot_piles.append(loot)


func _on_return_fired(from: EnemyRunner, to: OperatorUnit) -> void:
	# Called before damage is applied so terminal summaries include the shot.
	if phase == Phase.WATCHING or pending_result != "":
		battle_log.add_event(sim.tick, "return_fire", from.label_id, to.op_id, from.global_position)
	if not _watch_first_return:
		_watch_first_return = true
		_sfx("return_fire")
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(1.0, 0.55, 0.15, 0.85)
	line.points = PackedVector2Array([from.global_position, to.global_position])
	entities.add_child(line)
	return_fire_fx.append(line)
	# Tween owned by the line so level reloads don't leave dangling captures.
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.2)
	tw.tween_callback(line.queue_free)


func _process(delta: float) -> void:
	if phase == Phase.SETUP:
		_tick_cover_long_press()
		_update_cover_previews()
		_update_tripwire_ghost()
		return
	if phase != Phase.WATCHING:
		return
	var steps := sim.steps_for_frame(delta)
	for _i in steps:
		if phase != Phase.WATCHING:
			break
		_sim_tick()
	hud_tick += delta
	if hud_tick >= 0.35:
		hud_tick = 0.0
		_update_hud()
	else:
		_update_role_cards()


func _sim_tick() -> void:
	var this_run := run_id
	# Blueprint §5: spawn/env → move → escape → fire/return → loot → win → snapshot
	# 1) Spawn schedule by sim time
	var tsec := sim.time_sec()
	all_spawns_done = true
	for spec in pending_spawns:
		if spec["spawned"]:
			continue
		if tsec + 0.0001 >= float(spec["delay"]):
			if run_id != this_run or phase != Phase.WATCHING:
				return
			spec["spawned"] = true
			_spawn_one(spec)
		else:
			all_spawns_done = false

	# 2) Cooldowns
	for op in operators:
		if op.visible and op.alive:
			op.tick_cooldown(SimClock.TICK_DT)

	# 3) Ambush zone arming
	_tick_ambush_zone()

	# 4) Enemy move — branch at decision, then escape commits on last waypoint
	for enemy in enemies:
		if enemy.alive and enemy.active:
			_try_enemy_branch(enemy)
			enemy.sim_step(SimClock.TICK_DT)
			_try_enemy_branch(enemy)
		if phase != Phase.WATCHING:
			_finish_sim_tick()
			return

	# 5) Tripwire checks (fixed-step only; never from Tripwire._process)
	if phase == Phase.WATCHING:
		for tw in tripwires:
			if is_instance_valid(tw):
				var victim: EnemyRunner = tw.sim_check(enemies)
				if victim != null:
					battle_log.add_event(sim.tick, "trip", victim.label_id, -1, tw.global_position)
					_update_event_log()
			if phase != Phase.WATCHING:
				_finish_sim_tick()
				return

	# 5b) Authored explosive barrel — sim_tick only, like tripwire
	if phase == Phase.WATCHING:
		for barrel in barrels:
			if is_instance_valid(barrel):
				barrel.sim_check(enemies, operators)
			if phase != Phase.WATCHING:
				_finish_sim_tick()
				return

	# 6) Operator fire — priority: shortest remaining path to escape, then stable ID
	if phase == Phase.WATCHING:
		for op in operators:
			if not op.visible or not op.locked or not op.alive:
				continue
			var best: EnemyRunner = null
			var best_escape := INF
			var best_id := 999999
			for enemy in enemies:
				if not enemy.alive or not enemy.active:
					continue
				var deny := op.engage_block_reason(enemy.global_position, grid)
				if deny != "":
					_log_no_engage_if_changed(op, enemy, deny)
					continue
				op.last_deny[enemy.label_id] = ""
				var rem := enemy.remaining_path_to_escape()
				if rem < best_escape - 0.5 or (absf(rem - best_escape) <= 0.5 and enemy.label_id < best_id):
					best_escape = rem
					best_id = enemy.label_id
					best = enemy
			if best != null and op.shot_cd <= 0.0 and op.can_engage(best.global_position, grid):
				battle_log.add_event(sim.tick, "fire", op.op_id, best.label_id, op.global_position)
				if op.try_fire(best, grid):
					if not _watch_first_fire:
						_watch_first_fire = true
						_sfx("fire")
					if op.ammo <= 0:
						battle_log.add_event(sim.tick, "empty", op.op_id)
				if phase != Phase.WATCHING:
					_finish_sim_tick()
					return

	# 7) Return fire (signal logs before damage)
	if phase == Phase.WATCHING:
		for enemy in enemies:
			if enemy.alive and enemy.active:
				enemy.resolve_return_fire()
			if phase != Phase.WATCHING:
				_finish_sim_tick()
				return

	# 8) Loot: nearest + LOS + stable op_id
	if phase == Phase.WATCHING:
		for loot in loot_piles.duplicate():
			if not is_instance_valid(loot) or loot.collected:
				continue
			_try_assign_loot(loot)
		loot_piles = loot_piles.filter(func(l: LootPickup) -> bool: return is_instance_valid(l) and not l.collected)

	_finish_sim_tick()


func _finish_sim_tick() -> void:
	# Win check before snapshot so terminal ticks always get a recorded frame.
	if phase == Phase.WATCHING:
		_check_win()
	if sim.tick % SNAPSHOT_EVERY == 0 or pending_result != "" or phase != Phase.WATCHING:
		battle_log.add_snapshot(sim.tick, _snapshot_data())
		if phase == Phase.WATCHING:
			_update_role_cards()
	sim.advance()
	_flush_pending_result()


func _flush_pending_result() -> void:
	if pending_result == "fail":
		pending_result = ""
		_show_fail_result()
	elif pending_result == "win":
		pending_result = ""
		_show_win_result()

func _try_enemy_branch(enemy: EnemyRunner) -> void:
	if level == null or level.decision_cell.x < 0:
		return
	if not enemy.alive or not enemy.active:
		return
	var decision_world := grid.cell_to_world_center(level.decision_cell)
	var alt := _cells_to_world(level.alternate_route_cells)
	if enemy.maybe_branch(door_locked, decision_world, alt, level.door_blocks_route):
		battle_log.add_event(sim.tick, "route_choice", enemy.label_id, -1, enemy.global_position)
		_update_event_log()


func _log_no_engage_if_changed(op: OperatorUnit, enemy: EnemyRunner, reason: String) -> void:
	if reason == "":
		op.last_deny[enemy.label_id] = ""
		return
	var prev := str(op.last_deny.get(enemy.label_id, ""))
	if prev == reason:
		return
	op.last_deny[enemy.label_id] = reason
	battle_log.add_event(
		sim.tick, "no_engage", op.op_id, enemy.label_id, op.global_position, {"reason": reason}
	)


func _ensure_tripwire_ghost() -> void:
	if tripwire_ghost != null and is_instance_valid(tripwire_ghost):
		return
	tripwire_ghost = Node2D.new()
	tripwire_ghost.name = "TripwireGhost"
	tripwire_ghost.z_index = 6
	tripwire_ghost.visible = false
	var vis := Polygon2D.new()
	vis.name = "Visual"
	vis.polygon = PackedVector2Array([
		Vector2(-14, -2.5), Vector2(14, -2.5), Vector2(14, 2.5), Vector2(-14, 2.5)
	])
	vis.color = Color(0.9, 0.25, 0.22, 0.75)
	tripwire_ghost.add_child(vis)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "绊索"
	tag.position = Vector2(-16, -18)
	tag.add_theme_font_size_override("font_size", 11)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tripwire_ghost.add_child(tag)
	$World.add_child(tripwire_ghost)


func _update_tripwire_ghost() -> void:
	_ensure_tripwire_ghost()
	if phase != Phase.SETUP or tool != Tool.TRIPWIRE:
		tripwire_ghost.visible = false
		return
	tripwire_ghost.visible = true
	var pos := get_global_mouse_position()
	tripwire_ghost.global_position = pos
	var ok := _near_any_route_segment(pos, TRIPWIRE_ROUTE_DIST)
	var vis := tripwire_ghost.get_node_or_null("Visual") as Polygon2D
	if vis:
		vis.color = Color(0.42, 0.95, 0.52, 0.88) if ok else Color(0.92, 0.22, 0.2, 0.85)
	var tag := tripwire_ghost.get_node_or_null("Tag") as Label
	if tag:
		tag.add_theme_color_override("font_color", Color(0.5, 0.95, 0.5) if ok else Color(0.95, 0.4, 0.3))


func _tick_ambush_zone() -> void:
	if level.ambush_zone.size == Vector2.ZERO:
		return
	var any_in := false
	for enemy in enemies:
		if enemy.alive and enemy.active and level.ambush_zone.has_point(enemy.global_position):
			any_in = true
			break
	if not any_in:
		return
	for op in operators:
		if not op.visible or not op.alive:
			continue
		if op.fire_mode == OperatorUnit.FireMode.HOLD_FOR_AMBUSH and not op.fire_permitted:
			op.arm_ambush()
			battle_log.add_event(sim.tick, "ambush_armed", op.op_id)


func _snapshot_data() -> Dictionary:
	var ops := []
	for op in operators:
		if op.visible:
			ops.append({"id": op.op_id, "hp": op.hp, "ammo": op.ammo, "alive": op.alive, "pos": op.global_position})
	var ens := []
	for e in enemies:
		ens.append({"id": e.label_id, "hp": e.hp, "alive": e.alive, "pos": e.global_position})
	var bars := []
	for b in barrels:
		if is_instance_valid(b):
			bars.append({"pos": b.global_position, "spent": bool(b.spent)})
	return {"ops": ops, "enemies": ens, "barrels": bars}


func _try_assign_loot(loot: LootPickup) -> void:
	var candidates: Array[OperatorUnit] = []
	for op in operators:
		if op.visible and op.can_reach_loot(loot.global_position, grid):
			candidates.append(op)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: OperatorUnit, b: OperatorUnit) -> bool:
		var da := a.global_position.distance_to(loot.global_position)
		var db := b.global_position.distance_to(loot.global_position)
		if absf(da - db) > 0.01:
			return da < db
		return a.op_id < b.op_id
	)
	for op in candidates:
		var amount := loot.ammo_amount
		var gained := op.receive_ammo(amount)
		if gained > 0:
			loot.collect()
			battle_log.add_event(sim.tick, "loot", op.op_id, -1, loot.global_position, {"amount": gained})
			status_label.text = "%s 搜刮 +%d弹" % [op.display_name, gained]
			_sfx("loot")
			_update_event_log()
			return


func _on_enemy_escaped(enemy: EnemyRunner, path: PackedVector2Array) -> void:
	if phase != Phase.WATCHING:
		return
	fail_reason = "escape"
	phase = Phase.FAILED
	battle_log.add_event(sim.tick, "escape", enemy.label_id, -1, enemy.global_position)
	battle_log.mark_terminal(sim.tick, "escape")
	for e in enemies:
		e.active = false
	_remember_path(path, "escape")
	_flash("逃逸！出口已标记", Color(1.0, 0.35, 0.25))
	_sfx("escape")
	_camera_punch()
	_begin_escape_flash()
	_redraw_ghosts()
	pending_result = "fail"


func _on_enemy_died(enemy: EnemyRunner) -> void:
	if phase != Phase.WATCHING and pending_result == "":
		return
	if phase == Phase.WATCHING or pending_result != "":
		battle_log.add_event(sim.tick, "kill", enemy.label_id)
	_spawn_loot_at(enemy.global_position, enemy.loot_ammo)
	_update_event_log()
	if phase == Phase.WATCHING:
		_check_win()


func _on_operator_died(op: OperatorUnit) -> void:
	if phase != Phase.WATCHING:
		return
	battle_log.add_event(sim.tick, "op_down", op.op_id)
	status_label.text = "%s 阵亡 — 敌军还击（需 LOS）" % op.display_name
	_sfx("op_death")
	_update_event_log()
	if _living_ops() == 0:
		_fail_squad_wipe()


func _living_ops() -> int:
	var n := 0
	for op in operators:
		if op.visible and op.alive:
			n += 1
	return n


func _fail_squad_wipe() -> void:
	if phase != Phase.WATCHING:
		return
	fail_reason = "wipe"
	phase = Phase.FAILED
	battle_log.mark_terminal(sim.tick, "wipe")
	for e in enemies:
		e.active = false
		if e.recorded.size() > 1:
			_remember_path(e.recorded.duplicate(), "wipe")
	_flash("小队全灭", Color(0.85, 0.2, 0.2))
	_redraw_ghosts()
	pending_result = "fail"


func _remember_path(path: PackedVector2Array, reason: String) -> void:
	intel.add_path(loop_index, path, sim.time_sec(), reason)
	intel_paths.clear()
	for rec in intel.records:
		intel_paths.append(rec["path"])


func _on_abort_pressed() -> void:
	if phase != Phase.WATCHING:
		return
	fail_reason = "abort"
	phase = Phase.FAILED
	battle_log.add_event(sim.tick, "abort", -1, -1, Vector2.ZERO)
	battle_log.mark_terminal(sim.tick, "abort")
	for e in enemies:
		e.active = false
		if e.recorded.size() > 1:
			_remember_path(e.recorded.duplicate(), "abort")
	_flash("中止尝试", Color(0.85, 0.75, 0.35))
	_redraw_ghosts()
	pending_result = "fail"
	_finish_sim_tick()


func _on_op_fired_shot(op: OperatorUnit, target_pos: Vector2) -> void:
	var line := Line2D.new()
	line.width = 1.5
	line.default_color = Color(0.95, 0.9, 0.55, 0.75)
	line.points = PackedVector2Array([op.global_position, target_pos])
	entities.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.12)
	tw.tween_callback(line.queue_free)


func _on_op_ammo_empty(op: OperatorUnit) -> void:
	_flash("%s 空弹" % op.display_name, Color(0.9, 0.55, 0.2))
	_sfx("empty")


func _on_op_ammo_repacked(op: OperatorUnit) -> void:
	if phase == Phase.WATCHING or pending_result != "":
		battle_log.add_event(sim.tick, "repack", op.op_id)
	_flash("%s 弹包补给" % op.display_name, Color(0.55, 0.9, 0.45))
	_update_event_log()
	_update_role_cards()


func _flash(text: String, color: Color) -> void:
	if flash_label == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	flash_label.text = text
	flash_label.add_theme_color_override("font_color", color)
	flash_label.modulate = Color(1, 1, 1, 1)
	_flash_tween = flash_label.create_tween()
	_flash_tween.tween_property(flash_label, "modulate:a", 0.0, 1.2)


func _show_fail_result() -> void:
	if abort_button:
		abort_button.visible = false
	if title_return_button:
		title_return_button.visible = false
	result_panel.visible = true
	_dock_fail_result_panel(fail_reason == "escape")
	var lines := battle_log.summary_lines(10)
	var summary := "\n".join(lines)
	var reason_zh: String = BattleLog.reason_zh(fail_reason)
	var epitaph := battle_log.terminal_summary_line()
	result_label.text = "第 %d 世失败（%s）。\n%s\n穿梭后恢复上轮计划，满血满弹。\n%s\n\n—— 事件摘要（点击右侧日志定位）——\n%s" % [
		loop_index,
		reason_zh,
		epitaph,
		"逃逸口已在地图上闪烁。" if fail_reason == "escape" else "",
		summary,
	]
	continue_button.text = "带着情报穿梭回去"
	if replay_button:
		replay_button.visible = true
	status_label.text = "%s — 穿梭或打开时间轴复盘；点击事件定位" % reason_zh
	_update_event_log()
	_update_hud()
	_play_result_tone(false)
	_fade_result_panel()
	# Re-dock after text layout so a tall summary cannot cover the south-east mouth.
	if fail_reason == "escape":
		_dock_fail_result_panel(true)


func _show_win_result() -> void:
	if abort_button:
		abort_button.visible = false
	_reset_result_panel_pos()
	result_panel.offset_left = -300.0
	result_panel.offset_right = 300.0
	result_panel.offset_top = -230.0
	result_panel.offset_bottom = 230.0
	result_panel.visible = true
	if title_return_button:
		title_return_button.visible = true
	var lines := battle_log.summary_lines(5)
	var has_next := level_index + 1 < LEVEL_ORDER.size()
	var epitaph := battle_log.terminal_summary_line()
	if has_next:
		result_label.text = "任务完成。\n本关用了 %d 世。\n%s\n\n—— 关键事件 ——\n%s" % [
			loop_index, epitaph, "\n".join(lines)
		]
		continue_button.text = "下一关"
	else:
		result_label.text = "全部关卡封锁完成。\n本关用了 %d 世。\n%s\n\n—— 关键事件 ——\n%s" % [
			loop_index, epitaph, "\n".join(lines)
		]
		continue_button.text = "查看致谢"
		_campaign_complete = true
	var gs = _gs()
	if gs and level:
		gs.record_win(level.level_id)
	if replay_button:
		replay_button.visible = true
	status_label.text = "计划奏效"
	_save_progress()
	_update_event_log()
	_update_hud()
	_play_result_tone(true)
	_fade_result_panel()


func _on_replay_pressed() -> void:
	if battle_log.events.is_empty() and battle_log.snapshots.is_empty():
		return
	replay_return_phase = phase
	frozen_plan = last_plan.duplicate_plan()
	phase = Phase.REPLAY
	result_panel.visible = false
	replay.bind(battle_log)
	if scrub_slider:
		scrub_slider.visible = true
		scrub_slider.value = 1.0
	if replay_button:
		replay_button.visible = false
	# Hide live combat nodes; do not copy snapshot hp/ammo/alive onto them.
	for op in operators:
		op.visible = false
	for e in enemies:
		if is_instance_valid(e):
			e.visible = false
	for l in loot_piles:
		if is_instance_valid(l):
			l.visible = false
	_clear_replay_layer()
	_apply_replay_scrub()
	status_label.text = "只读时间轴 — 拖动滑条或 ←/→；点击事件定位对象。空格返回并恢复上轮计划"
	_update_hud()


func _on_scrub_changed(v: float) -> void:
	if phase != Phase.REPLAY:
		return
	replay.seek_ratio(v)
	_apply_replay_scrub()


func _apply_replay_scrub() -> void:
	if phase != Phase.REPLAY:
		return
	var snap: Dictionary = replay.snapshot_at_or_before(replay.scrub_tick)
	if scrub_slider and replay.max_tick() > 0:
		scrub_slider.set_value_no_signal(float(replay.scrub_tick) / float(replay.max_tick()))
	_paint_replay_snapshot(snap)
	_fill_event_list(replay.events_up_to(replay.scrub_tick), 12, "复盘 t=%.1fs · 点击定位" % (float(replay.scrub_tick) / 60.0))
	_update_hud()


func _paint_replay_snapshot(snap: Dictionary) -> void:
	_clear_replay_layer()
	if replay_layer == null or not snap.has("data"):
		return
	var data: Dictionary = snap["data"]
	for o in data.get("ops", []):
		var op := _op_by_id(int(o["id"]))
		var col := op.body_color if op != null else Color(0.35, 0.65, 0.95)
		var alive := bool(o["alive"])
		var hot := replay_focus_actor == int(o["id"]) and replay_focus_type in ["fire", "empty", "op_down", "loot", "ambush_armed", "repack", "return_fire", "no_engage"]
		_add_replay_marker(o["pos"], col if alive else Color(0.3, 0.3, 0.32), "队员%d" % int(o["id"]), alive, hot)
	for e in data.get("enemies", []):
		var alive := bool(e["alive"])
		var hot := replay_focus_actor == int(e["id"]) and replay_focus_type in ["spawn", "kill", "escape", "fire", "return_fire", "trip", "route_choice", "no_engage"]
		_add_replay_marker(
			e["pos"],
			Color(0.75, 0.22, 0.2) if alive else Color(0.35, 0.35, 0.38, 0.7),
			"敌%d" % int(e["id"]),
			alive,
			hot
		)
	for b in data.get("barrels", []):
		var spent := bool(b.get("spent", false))
		_add_replay_marker(
			b["pos"],
			Color(0.45, 0.28, 0.2) if spent else Color(0.85, 0.4, 0.15),
			"油桶",
			not spent,
			replay_focus_type == "barrel"
		)


func _add_replay_marker(pos: Vector2, color: Color, label: String, alive: bool, focused: bool = false) -> void:
	var n := Node2D.new()
	n.position = pos
	if focused:
		var halo := Polygon2D.new()
		var hpts := PackedVector2Array()
		for i in 12:
			var r := deg_to_rad(float(i) * 30.0)
			hpts.append(Vector2(cos(r), sin(r)) * 20.0)
		halo.polygon = hpts
		halo.color = Color(1.0, 0.92, 0.25, 0.38)
		n.add_child(halo)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(0, -10), Vector2(8, 8), Vector2(-8, 8)])
	body.color = Color(1.0, 0.9, 0.3) if focused else color
	n.add_child(body)
	var t := Label.new()
	t.text = label if alive else "%s·亡" % label
	t.position = Vector2(-18, -28)
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4) if focused else color)
	n.add_child(t)
	replay_layer.add_child(n)


func _clear_replay_layer() -> void:
	if replay_layer == null:
		return
	for c in replay_layer.get_children():
		c.queue_free()


func _exit_replay_to_setup() -> void:
	_clear_replay_layer()
	if scrub_slider:
		scrub_slider.visible = false
	if not frozen_plan.deployments.is_empty():
		last_plan = frozen_plan.duplicate_plan()
	if replay_return_phase == Phase.WON:
		phase = Phase.WON
		for op in operators:
			if op.slot != null:
				op.visible = true
				op.global_position = op.slot.global_position
		for e in enemies:
			if is_instance_valid(e):
				e.visible = true
		for l in loot_piles:
			if is_instance_valid(l):
				l.visible = true
		_show_win_result()
		_update_hud()
		return
	if replay_return_phase == Phase.FAILED:
		loop_index += 1
	_start_setup(true, true)


func _check_win() -> void:
	if phase != Phase.WATCHING:
		return
	if not all_spawns_done:
		return
	for e in enemies:
		if e.alive:
			return
	if _living_ops() == 0:
		_fail_squad_wipe()
		return
	phase = Phase.WON
	battle_log.mark_terminal(sim.tick, "win")
	_flash("零逃逸", Color(0.45, 0.9, 0.45))
	_sfx("win")
	_camera_punch()
	pending_result = "win"


func _on_continue_pressed() -> void:
	if phase == Phase.FAILED:
		loop_index += 1
		_start_setup(true, true)
	elif phase == Phase.WON:
		if level_index + 1 < LEVEL_ORDER.size():
			level_index += 1
			_load_level(LEVEL_ORDER[level_index], false, false)
			_save_progress()
		else:
			_campaign_complete = true
			_save_progress()
			_show_credits()
	elif phase == Phase.REPLAY:
		_exit_replay_to_setup()


func _redraw_ghosts() -> void:
	for c in ghosts.get_children():
		c.queue_free()
	var recent: Array = intel.recent(3)
	var gi := 0
	for rec in recent:
		var path: PackedVector2Array = rec["path"]
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.35, 0.75, 1.0, 0.55 - minf(0.15, float(gi) * 0.05))
		line.points = path
		ghosts.add_child(line)
		if path.size() > 0:
			var tag := Label.new()
			var reason_zh := BattleLog.reason_zh(str(rec["reason"]))
			tag.text = "第%d世 · %.1fs · %s" % [int(rec["loop"]), float(rec["cut_sec"]), reason_zh]
			tag.position = path[mini(path.size() - 1, path.size() / 2)] + Vector2(6, -18)
			tag.add_theme_font_size_override("font_size", 11)
			tag.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 0.92))
			ghosts.add_child(tag)
		gi += 1


func _ammo_summary() -> String:
	var parts: PackedStringArray = []
	for op in operators:
		if op.visible:
			if not op.alive:
				parts.append("%s:亡" % op.display_name)
			else:
				parts.append("%s:%d弹%s" % [op.display_name, op.ammo, ("·" + op.fire_mode_label()) if phase == Phase.SETUP else ""])
	return "  ".join(parts)


func _update_event_log() -> void:
	_fill_event_list(battle_log.events, 14, "事件日志 · 点击定位")


func _fill_event_list(evs: Array, max_count: int, title: String) -> void:
	if event_log_title:
		event_log_title.text = title
	if event_list == null:
		if event_log is RichTextLabel:
			var lines := PackedStringArray()
			var start0 := maxi(evs.size() - max_count, 0)
			for i in range(start0, evs.size()):
				lines.append(battle_log.format_event(evs[i]))
			(event_log as RichTextLabel).text = "[b]%s[/b]\n%s" % [title, "\n".join(lines)]
		return
	event_list.clear()
	_event_list_items.clear()
	var start := maxi(evs.size() - max_count, 0)
	for i in range(start, evs.size()):
		var ev: Dictionary = evs[i]
		_event_list_items.append(ev)
		event_list.add_item(battle_log.format_event(ev))
	if _event_list_items.size() > 0:
		event_list.select(_event_list_items.size() - 1)
		event_list.ensure_current_is_visible()
	_set_event_log_interactive(phase != Phase.SETUP and _event_list_items.size() > 0)


func _set_event_log_interactive(on: bool) -> void:
	var f := Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if event_log:
		event_log.mouse_filter = f
	if event_list:
		event_list.mouse_filter = f


func _on_event_item_clicked(index: int, _at: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	if index < 0 or index >= _event_list_items.size():
		return
	_focus_battle_event(_event_list_items[index])


func _focus_battle_event(ev: Dictionary) -> void:
	if ev.is_empty():
		return
	replay_focus_actor = int(ev.get("actor_id", -1))
	replay_focus_type = str(ev.get("type", ""))
	if phase == Phase.REPLAY:
		replay.set_tick(int(ev["tick"]))
		_apply_replay_scrub()
	var pos := _event_focus_position(ev)
	if phase == Phase.REPLAY:
		pos = _pos_from_snapshot(replay.snapshot_at_or_before(replay.scrub_tick), ev, pos)
	_spawn_focus_ring(pos)
	if str(ev["type"]) == "escape":
		_begin_escape_flash()
	if status_label:
		status_label.text = "定位 · %s" % battle_log.format_event(ev)


func focus_latest_of_type(type_name: String) -> bool:
	var ev := battle_log.last_of_type(type_name)
	if ev.is_empty():
		return false
	_focus_battle_event(ev)
	return focus_ring != null and is_instance_valid(focus_ring)


func _event_focus_position(ev: Dictionary) -> Vector2:
	var pos: Vector2 = ev.get("position", Vector2.ZERO)
	if pos.length() > 4.0:
		return pos
	var typ := str(ev["type"])
	match typ:
		"fire", "empty", "op_down", "loot", "ambush_armed", "repack", "no_engage":
			var op := _op_by_id(int(ev["actor_id"]))
			if op != null:
				return op.global_position
		"spawn", "kill", "escape", "return_fire", "trip", "route_choice":
			for e in enemies:
				if e.label_id == int(ev["actor_id"]):
					return e.global_position
		"barrel":
			if barrels.size() > 0 and is_instance_valid(barrels[0]):
				return barrels[0].global_position
		"terminal", "abort", "door":
			return escape_world
	return escape_world


func _pos_from_snapshot(snap: Dictionary, ev: Dictionary, fallback: Vector2) -> Vector2:
	if not snap.has("data"):
		return fallback
	var data: Dictionary = snap["data"]
	var typ := str(ev["type"])
	var aid := int(ev.get("actor_id", -1))
	if typ in ["fire", "empty", "op_down", "loot", "ambush_armed", "repack", "return_fire", "no_engage"]:
		var look_id := aid
		if typ == "return_fire":
			look_id = int(ev.get("target_id", aid))
			for e in data.get("enemies", []):
				if int(e["id"]) == aid:
					return e["pos"]
			aid = look_id
		for o in data.get("ops", []):
			if int(o["id"]) == look_id or int(o["id"]) == aid:
				return o["pos"]
	if typ in ["spawn", "kill", "escape", "fire", "trip", "route_choice"]:
		for e in data.get("enemies", []):
			if int(e["id"]) == int(ev.get("target_id", -1)) and typ == "fire":
				return e["pos"]
			if int(e["id"]) == aid:
				return e["pos"]
	if typ == "barrel":
		for b in data.get("barrels", []):
			return b["pos"]
	return fallback


func _spawn_focus_ring(pos: Vector2) -> void:
	_clear_focus_ring()
	focus_ring = Node2D.new()
	focus_ring.name = "FocusRing"
	focus_ring.z_index = 25
	focus_ring.position = pos
	var halo := Polygon2D.new()
	var hpts := PackedVector2Array()
	for i in 16:
		var r := deg_to_rad(float(i) * 22.5)
		hpts.append(Vector2(cos(r), sin(r)) * 24.0)
	halo.polygon = hpts
	halo.color = Color(1.0, 0.92, 0.25, 0.32)
	focus_ring.add_child(halo)
	var line := Line2D.new()
	line.width = 2.5
	line.closed = true
	line.default_color = Color(1.0, 0.9, 0.2, 0.95)
	var lp := PackedVector2Array()
	for i in 17:
		var r := deg_to_rad(float(i) * 22.5)
		lp.append(Vector2(cos(r), sin(r)) * 28.0)
	line.points = lp
	focus_ring.add_child(line)
	$World.add_child(focus_ring)
	var tw := focus_ring.create_tween()
	tw.tween_property(focus_ring, "scale", Vector2(1.35, 1.35), 0.16)
	tw.tween_property(focus_ring, "scale", Vector2(1.0, 1.0), 0.16)


func _clear_focus_ring() -> void:
	if focus_ring != null and is_instance_valid(focus_ring):
		focus_ring.queue_free()
	focus_ring = null


func _begin_escape_flash() -> void:
	if map_draw:
		map_draw.escape_cell = level.escape_cell if level else map_draw.escape_cell
		map_draw.escape_flash = true
		map_draw.queue_redraw()
	if _escape_tween != null:
		_escape_tween.kill()
	escape_marker.scale = Vector2.ONE
	_escape_tween = create_tween().set_loops()
	_escape_tween.tween_property(escape_marker, "scale", Vector2(1.4, 1.4), 0.22)
	_escape_tween.tween_property(escape_marker, "scale", Vector2(1.0, 1.0), 0.22)
	var ring := escape_marker.get_node_or_null("Ring") as Polygon2D
	if ring:
		ring.color = Color(1.0, 0.22, 0.12, 0.72)
	var lab := escape_marker.get_node_or_null("EscapeLabel") as Label
	if lab:
		lab.text = "逃逸口·越界"
		lab.add_theme_color_override("font_color", Color(1.0, 0.45, 0.28))


func _reset_escape_flash() -> void:
	if _escape_tween != null:
		_escape_tween.kill()
		_escape_tween = null
	if is_instance_valid(escape_marker):
		escape_marker.scale = Vector2.ONE
		var ring := escape_marker.get_node_or_null("Ring") as Polygon2D
		if ring:
			ring.color = Color(0.2, 0.85, 0.55, 0.35)
		var lab := escape_marker.get_node_or_null("EscapeLabel") as Label
		if lab:
			lab.text = "逃逸口"
			lab.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75, 1))
	if map_draw:
		map_draw.escape_flash = false
		map_draw.queue_redraw()


func _reset_result_panel_pos() -> void:
	if result_panel == null:
		return
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.anchor_left = 0.5
	result_panel.anchor_top = 0.5
	result_panel.anchor_right = 0.5
	result_panel.anchor_bottom = 0.5
	result_panel.offset_left = _result_panel_home.x
	result_panel.offset_top = _result_panel_home.y
	result_panel.offset_right = _result_panel_home.z
	result_panel.offset_bottom = _result_panel_home.w
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH


func _dock_fail_result_panel(keep_escape_visible: bool) -> void:
	if result_panel == null:
		return
	# Escape mouth is south-east; dock bottom-left so the marker stays readable.
	# Other fails dock bottom-right, above the command bar.
	if keep_escape_visible:
		result_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		result_panel.anchor_left = 0.0
		result_panel.anchor_top = 1.0
		result_panel.anchor_right = 0.0
		result_panel.anchor_bottom = 1.0
		result_panel.offset_left = 16.0
		result_panel.offset_right = 420.0
		result_panel.offset_top = -280.0
		result_panel.offset_bottom = -100.0
		result_panel.grow_horizontal = Control.GROW_DIRECTION_END
		result_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		result_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		result_panel.anchor_left = 1.0
		result_panel.anchor_top = 1.0
		result_panel.anchor_right = 1.0
		result_panel.anchor_bottom = 1.0
		result_panel.offset_left = -400.0
		result_panel.offset_right = -16.0
		result_panel.offset_top = -280.0
		result_panel.offset_bottom = -100.0
		result_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		result_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN


func result_panel_covers_escape() -> bool:
	if result_panel == null or not result_panel.visible or escape_marker == null:
		return false
	var panel_rect := result_panel.get_global_rect()
	var esc: Vector2 = escape_marker.get_global_transform_with_canvas().origin
	for ox in [-24.0, 0.0, 24.0]:
		for oy in [-24.0, 0.0, 24.0]:
			if panel_rect.has_point(esc + Vector2(ox, oy)):
				return true
	return false


func _update_hud() -> void:
	var lv_title := level.title if level else "AMBUSH LOOP"
	title_label.text = "AMBUSH LOOP  ·  第 %d 世" % loop_index
	if level_label:
		level_label.text = lv_title
	if tut_label and level:
		tut_label.text = level.tutorial if phase == Phase.SETUP else level.teaching
	intel_label.text = "漏网记忆：%d   |   %s" % [intel.records.size(), _ammo_summary()]
	var dep := _deployed_count()
	if phase == Phase.SETUP:
		help_label.text = "准备：左卡选步枪/机枪/侦察。青弧=掩体保护方向。黄锥=墙裁切射界。红线=选中队员可打到的路线。侦察观察环仅准备期。点掩体（%d/3）| 1/2/3 | A/D射界 | F开火 | G弹包 | B门 | Tab绊索 | M静音 | Esc菜单\n空格拉警报（锁死方案）。X中止留情报。时间轴复盘只读。R清空记忆。" % dep
	elif phase == Phase.WATCHING:
		var spd := "暂停" if sim.paused else ("2×" if sim.speed >= 1.5 else "1×")
		help_label.text = "锁死看戏 t=%.1fs [%s]：优先打更接近逃逸口的目标；点事件可定位。X中止保留情报。暂停/变速只改观看。" % [sim.time_sec(), spd]
	elif phase == Phase.FAILED:
		help_label.text = "失败原因：%s。点击右侧事件定位对象；逃逸口在失败时闪烁。打开时间轴或改朝向/掩体/开火条件后再警报。" % fail_reason
	elif phase == Phase.WON:
		help_label.text = "战前准备决定战斗。可回看只读时间轴；点击事件定位。"
	elif phase == Phase.REPLAY:
		help_label.text = "复盘只读 t=%.1fs / %.1fs — 点击事件定位并跳到该时刻。不重演模拟、不改写下一世计划。空格返回。Esc 菜单。" % [
			float(replay.scrub_tick) / 60.0, float(replay.max_tick()) / 60.0
		]
	_refresh_door_visual()
	_refresh_mode_pack_buttons()
	_update_role_cards()
	_update_observation_rings()
	if phase != Phase.SETUP:
		_update_cover_previews()
	_apply_watch_layers()
	_refresh_touch_hud()


func _tick_cover_long_press() -> void:
	if phase != Phase.SETUP:
		return
	if _cover_hold_slot == null or not is_instance_valid(_cover_hold_slot):
		return
	if Time.get_ticks_msec() - _cover_hold_msec < COVER_LONGPRESS_MS:
		return
	_touch_preview_slot = _cover_hold_slot
	if status_label:
		status_label.text = "保护弧朝%s（长按预览，松手不部署）" % _cover_hold_slot.protect_compass()
	_update_cover_previews()


func _update_cover_previews() -> void:
	if cover_slots.is_empty():
		return
	var show := phase == Phase.SETUP or phase == Phase.WATCHING or phase == Phase.REPLAY or phase == Phase.FAILED
	var hover: CoverSlot = null
	if phase == Phase.SETUP:
		if _touch_preview_slot != null and is_instance_valid(_touch_preview_slot):
			hover = _touch_preview_slot
		else:
			hover = _nearest_slot(get_global_mouse_position(), 32.0)
	for s in cover_slots:
		if not show:
			s.set_protect_preview(0)
			continue
		var hot := false
		if hover == s:
			hot = true
		if selected != null and selected.visible and selected.slot == s:
			hot = true
		elif phase == Phase.WATCHING and s.occupied_by != null and is_instance_valid(s.occupied_by) and s.occupied_by.visible:
			hot = true
		s.set_protect_preview(2 if hot else 1)


func _update_role_cards() -> void:
	if role_box:
		role_box.modulate = Color(1, 1, 1, 0.45) if phase == Phase.REPLAY else Color.WHITE
	for i in role_cards.size():
		var card: OpCard = role_cards[i]
		if i >= operators.size():
			card.visible = false
			continue
		var op: OperatorUnit = operators[i]
		card.bind(op, op == selected, phase != Phase.REPLAY)
	if plan_readout == null:
		return
	if selected == null:
		plan_readout.text = ""
	elif not selected.visible or selected.slot == null:
		plan_readout.text = "选中 %s（未部署）\n%s" % [selected.display_name, selected.kit_blurb()]
	else:
		plan_readout.text = "掩体「%s」保护弧朝%s（%d°）— 该方向来袭减伤60%%，侧背无减免。黄锥=墙体裁切射界。\n优先目标：距逃逸口剩余路程最短。" % [
			selected.slot.label_text,
			selected.slot.protect_compass(),
			int(selected.slot.protect_facing_deg),
		]
