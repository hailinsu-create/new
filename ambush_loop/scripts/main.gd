extends Node2D

## Ambush Loop — Commandos-style ambush prep + time-loop coordinator.
## SETUP → Alarm freezes PlanState → WATCHING (SimClock) → FAIL/WIN/REPLAY.

enum Phase { SETUP, WATCHING, FAILED, WON, REPLAY, SWEEP }
enum Tool { DEPLOY, TRIPWIRE, GRENADE, DECOY }

const MAX_TRIPWIRES := 1
const TRIPWIRE_ROUTE_DIST := 24.0
const SNAPSHOT_EVERY := 6
const COVER_LONGPRESS_MS := 400
const PROGRESS_PATH := "user://ambush_loop.cfg"
const LEVEL_ORDER := ["yard", "warehouse", "pump", "railcut", "depot", "radio"]
const SfxBusScript := preload("res://scripts/sfx/sfx_bus.gd")
const AmbushZoneFxScript := preload("res://scripts/fx/ambush_zone_fx.gd")
const MissionSkyScript := preload("res://scripts/fx/mission_sky.gd")
const TouchHudScript := preload("res://scripts/touch_hud.gd")
const IntelPathGhostScript := preload("res://scripts/fx/intel_path_ghost.gd")
const PayoffCopy := preload("res://scripts/replay/payoff.gd")
const KillzoneOverlayScript := preload("res://scripts/fx/killzone_overlay.gd")
const CombatFxScript := preload("res://scripts/fx/combat_fx.gd")
const OperatorSilhouetteScript := preload("res://scripts/fx/operator_silhouette.gd")
const EnemySilhouetteScript := preload("res://scripts/fx/enemy_silhouette.gd")
const NightGradeScript := preload("res://scripts/fx/night_grade.gd")
const TrapPathFxScript := preload("res://scripts/fx/trap_path_fx.gd")
const NightHandoffScript := preload("res://scripts/ui/night_handoff.gd")
const SpawnGhostScript := preload("res://scripts/fx/spawn_ghost.gd")
const WeaponCatalogScript := preload("res://scripts/raid/weapon_catalog.gd")
const RaidPathfinderScript := preload("res://scripts/raid/pathfinder.gd")
const RaidDirectorScript := preload("res://scripts/raid/raid_director.gd")
const RaidStashScript := preload("res://scripts/raid/stash.gd")
const RaidGrenadeScript := preload("res://scripts/raid/grenade.gd")
const RaidMineScript := preload("res://scripts/raid/landmine.gd")
const RaidDecoyScript := preload("res://scripts/raid/decoy.gd")
const BackpackPanelScript := preload("res://scripts/ui/backpack_panel.gd")

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
var raid_stashes: Array = []
var raid_grenades: Array = []
var raid_mines: Array = []
var raid_decoys: Array = []
var raid = RaidDirectorScript.new()
var barrels: Array = []
var _alarm_warned_no_gun: bool = false
var _alarm_pulled_unarmed: bool = false
var _night_hp_lost: bool = false
var _night_timer: float = 0.0
var _wave_fail_index: int = 0
var _hold_move_acc: float = 0.0
var _foot_acc: float = 0.0
var frozen_plan: PlanState = PlanState.new()
var replay_return_phase: Phase = Phase.SETUP

var pending_spawns: Array = [] # {id, route, delay, loot, spawned}
var route_world: Dictionary = {} # name -> PackedVector2Array
var escape_world: Vector2
var return_fire_fx: Array = []
var hud_tick: float = 0.0
var ambush_zone_poly: Node2D = null
var door_marker: Node2D = null
var decision_marker: Node2D = null
var barrel_hint: Node2D = null
var trap_callout: Node2D = null
var _trap_callout_tween: Tween = null
var second_callout: Node2D = null
var _second_callout_tween: Tween = null
var echo_callout: Node2D = null
var trap_path: Node2D = null
var result_dossier: Label = null
var dossier_button: Button = null
var _dossier_open: bool = false
var _fail_dossier_text: String = ""
var _wave_tension_id: int = -1
var spawn_ghost_host: Node2D = null
var plan_ghost_host: Node2D = null
var fail_gap_callout: Node2D = null
var watch_wave_chip: Label = null
var spawn_teach_label: Label = null
var intel_chip: Label = null
var checklist_strip: Control = null
var _checklist_labels: Array[Label] = []
var _checklist_touch_layout: bool = false
var _door_taught: bool = false
var _decision_pulse_tween: Tween = null
var leak_advice_shown: String = ""
var route_timeline: Control = null
var watch_timeline: Control = null
var mission_sky: Node2D = null
var night_grade: CanvasModulate = null
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
var skip_outcome_button: Button = null
var _skipping_outcome: bool = false
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
var phase_chip: Label = null
var stash_board: Label = null
var route_legend: Control = null
var _alarm_vignette: ColorRect = null
var _watch_letterbox: Control = null
var _watch_vignette: Control = null
var _fail_static: Control = null
var _fail_static_tween: Tween = null
var _tracer_pool: Array = []
var _tracer_live: Array = []
var _phase_chip_tween: Tween = null
var _kill_tween: Tween = null
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
var _leak_miss_draw: Node2D = null
var tripwire_ghost: Node2D = null

var sfx = null
var mute_button: Button = null
var _watch_first_fire: bool = false
var _watch_first_return: bool = false
var _kill_combo: int = 0
var _last_kill_tick: int = -1
var _payoff_callout: Node2D = null
var _payoff_callout_tween: Tween = null
var _last_payoff_kind: String = ""
var _last_payoff_tick: int = -1
var _barked_last: bool = false
var _restored_this_setup: bool = false
var _plan_diff_guard: bool = false
var plan_restore_hint: String = ""
var sfx_muted: bool = false
var pause_overlay: PauseOverlay = null
var tutorial_overlay: TutorialOverlay = null
var backpack_panel = null
var bag_button: Button = null
var credits_overlay: CreditsOverlay = null
var night_handoff = null
var _menu_paused_sim: bool = false
var _campaign_complete: bool = false
var title_return_button: Button = null
var result_headline: Label = null
var result_stats: Label = null
var _result_columns: GridContainer = null
var _intel_ghost: Node2D = null
var _intel_ghost_tween: Tween = null
var _mission_had_escape: bool = false
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
var _cam_zoom_punch: float = 1.0
var _stinger_tween: Tween = null
var _win_stinger_tween: Tween = null
var _sig_wash: ColorRect = null
var _load_fade_tween: Tween = null
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
var _move_ghost: Line2D = null


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
	if title_label:
		title_label.add_theme_font_size_override("font_size", 28)
		title_label.add_theme_font_override("font", NightOps.display_font())
	if status_label:
		status_label.add_theme_font_size_override("font_size", 16)
		status_label.add_theme_font_override("font", NightOps.ui_font_bold())
		status_label.clip_text = true
		status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if intel_label:
		intel_label.add_theme_font_size_override("font_size", 13)
		# TopBar Intel used to cross the route timeline. Count stays in
		# intel_label.text for dumps; the painted chip sits under the strip.
		intel_label.visible = false
		intel_label.clip_text = true
	var topbar := get_node_or_null("HUD/Root/TopBar") as Control
	if topbar:
		# Title + Status only, left column. Full-width TopBar painted status
		# across the route timeline (restore / facing strings).
		topbar.anchor_right = 0.0
		topbar.offset_left = 16.0
		topbar.offset_right = 428.0
		topbar.offset_bottom = 70.0
	if result_panel:
		result_panel.z_index = 20
		result_panel.z_as_relative = true
	if help_label:
		help_label.add_theme_font_size_override("font_size", 12)
		help_label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.66))
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
	extra.z_index = 0
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
		pack_button = _make_hud_btn("PackButton", "弹包", extra)
	if door_button == null:
		door_button = _make_hud_btn("DoorButton", "门: 畅通 (B)", extra)
	bag_button = _make_hud_btn("BagButton", "背包 (I)", extra)
	bag_button.pressed.connect(_toggle_backpack)

	extra_bar = extra
	mute_button = _make_hud_btn("MuteButton", "音效 M", extra)
	mute_button.pressed.connect(_toggle_mute)
	settings_button = _make_hud_btn("SettingsButton", "菜单 Esc", extra)
	settings_button.pressed.connect(_toggle_pause_menu)
	log_button = _make_hud_btn("LogButton", "日志", extra)
	log_button.pressed.connect(_toggle_event_log)
	_dock_setup_help()

	speed_button.pressed.connect(_on_speed_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	mode_button.pressed.connect(_on_mode_pressed)
	pack_button.pressed.connect(_on_pack_pressed)
	door_button.pressed.connect(_on_door_pressed)

	abort_button = _make_hud_btn("AbortButton", "中止尝试 (X)", bar)
	abort_button.pressed.connect(_on_abort_pressed)
	abort_button.visible = false
	skip_outcome_button = _make_hud_btn("SkipOutcomeButton", "跳到终局 (J)", bar)
	skip_outcome_button.pressed.connect(_on_skip_to_outcome_pressed)
	skip_outcome_button.visible = false

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
	flash_label.offset_left = -280.0
	flash_label.offset_right = 280.0
	flash_label.offset_top = 72.0
	flash_label.offset_bottom = 104.0
	flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flash_label.add_theme_font_override("font", NightOps.ui_font_bold())
	flash_label.add_theme_font_size_override("font_size", 18)
	flash_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	flash_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.02, 0.9))
	flash_label.add_theme_constant_override("shadow_offset_x", 1)
	flash_label.add_theme_constant_override("shadow_offset_y", 1)
	flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_label.text = ""
	root.add_child(flash_label)
	_ensure_flash_plate(root)

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
		tut_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		tut_label.offset_left = 236.0
		tut_label.offset_top = 96.0
		tut_label.offset_right = -16.0
		tut_label.offset_bottom = 132.0
		tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tut_label.add_theme_font_override("font", NightOps.ui_font())
		tut_label.add_theme_font_size_override("font_size", 12)
		tut_label.add_theme_color_override("font_color", NightOps.MUTED)
		tut_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tut_label.clip_text = true
		root.add_child(tut_label)
	_ensure_tut_plate(root)

	_build_role_card_hud(root)
	_build_modals()
	if killzone_draw == null:
		killzone_draw = Node2D.new()
		killzone_draw.name = "KillzoneDraw"
		killzone_draw.set_script(KillzoneOverlayScript)
		$World.add_child(killzone_draw)
		$World.move_child(killzone_draw, routes_draw.get_index())
	_play_ensure_leak_miss_draw()
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
	dock.offset_bottom = 438.0
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
	phase_chip = Label.new()
	phase_chip.name = "PhaseChip"
	phase_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	phase_chip.anchor_left = 1.0
	phase_chip.anchor_right = 1.0
	phase_chip.offset_left = -420.0
	phase_chip.offset_right = -16.0
	phase_chip.offset_top = 10.0
	phase_chip.offset_bottom = 36.0
	phase_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	phase_chip.add_theme_font_size_override("font_size", 18)
	phase_chip.add_theme_font_override("font", NightOps.ui_font_bold())
	phase_chip.add_theme_color_override("font_color", Color(0.95, 0.92, 0.62))
	phase_chip.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.02, 0.9))
	phase_chip.add_theme_constant_override("shadow_offset_x", 1)
	phase_chip.add_theme_constant_override("shadow_offset_y", 1)
	phase_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(phase_chip)
	stash_board = Label.new()
	stash_board.name = "StashBoard"
	stash_board.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stash_board.offset_left = 12.0
	stash_board.offset_right = -12.0
	stash_board.offset_top = -88.0
	stash_board.offset_bottom = -68.0
	stash_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stash_board.add_theme_font_size_override("font_size", 13)
	stash_board.add_theme_font_override("font", NightOps.ui_font_bold())
	stash_board.add_theme_color_override("font_color", Color(0.90, 0.82, 0.48))
	stash_board.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.02, 0.9))
	stash_board.add_theme_constant_override("shadow_offset_x", 1)
	stash_board.add_theme_constant_override("shadow_offset_y", 1)
	stash_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stash_board.text = ""
	root.add_child(stash_board)
	route_legend = HBoxContainer.new()
	route_legend.name = "RouteLegend"
	route_legend.set_anchors_preset(Control.PRESET_TOP_WIDE)
	route_legend.offset_left = 220.0
	route_legend.offset_top = 38.0
	route_legend.offset_right = -280.0
	route_legend.offset_bottom = 72.0
	route_legend.add_theme_constant_override("separation", 6)
	route_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(route_legend)
	spawn_teach_label = Label.new()
	spawn_teach_label.name = "SpawnTeach"
	spawn_teach_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	spawn_teach_label.offset_left = 220.0
	spawn_teach_label.offset_top = 122.0
	spawn_teach_label.offset_right = -16.0
	spawn_teach_label.offset_bottom = 144.0
	spawn_teach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spawn_teach_label.add_theme_font_size_override("font_size", 13)
	spawn_teach_label.add_theme_font_override("font", NightOps.ui_font_bold())
	spawn_teach_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.38))
	spawn_teach_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.92))
	spawn_teach_label.add_theme_constant_override("shadow_offset_x", 1)
	spawn_teach_label.add_theme_constant_override("shadow_offset_y", 1)
	spawn_teach_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spawn_teach_label)
	_ensure_intel_chip()
	_ensure_checklist(root)
	_pin_role_cards(_want_touch())


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
	night_handoff = NightHandoffScript.new()
	add_child(night_handoff)
	night_handoff.finished.connect(_on_night_handoff_finished)
	backpack_panel = BackpackPanelScript.new()
	backpack_panel.name = "BackpackPanel"
	add_child(backpack_panel)
	backpack_panel.equip_requested.connect(_on_pack_equip)
	backpack_panel.pass_requested.connect(_on_pack_pass)
	backpack_panel.drop_requested.connect(_on_pack_drop)
	backpack_panel.closed.connect(func() -> void:
		_update_hud()
	)


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
	if night_handoff and night_handoff.is_open():
		return true
	if backpack_panel and backpack_panel.has_method("is_open") and backpack_panel.is_open():
		return false
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
	pause_overlay.present(_is_command_phase(), true)
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


func _present_night_handoff(from_id: String, to_id: String) -> void:
	## Headless smoke advances immediately; players see the letterbox beat.
	if DisplayServer.get_name() == "headless":
		return
	if night_handoff == null:
		return
	night_handoff.present(from_id, to_id)
	_sfx("handoff")


func _on_night_handoff_finished() -> void:
	_sfx("ui")


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
	_sync_desktop_bars(not on)
	if help_label:
		# Docked one-liner stays in ExtraBar's band; never a south map wall.
		help_label.visible = (not on) and phase == Phase.SETUP
	_hide_duplicate_tut()
	if spawn_teach_label:
		# One teaching line under the timeline, never a second top paragraph.
		spawn_teach_label.offset_top = 118.0 if on else 122.0
		spawn_teach_label.offset_bottom = 140.0 if on else 144.0
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
	if plan_readout:
		plan_readout.visible = not on
	if route_legend:
		# Sit in the phase-chip band, left of the checklist — not on the timeline.
		route_legend.offset_top = 36.0 if on else 38.0
		route_legend.offset_bottom = 68.0 if on else 72.0
		route_legend.offset_right = -280.0
	alarm_button.custom_minimum_size = Vector2(180, 48) if on else Vector2(180, 36)
	clear_button.custom_minimum_size = Vector2(120, 48) if on else Vector2(120, 36)
	tool_button.custom_minimum_size = Vector2(160, 48) if on else Vector2(160, 36)
	_pin_role_cards(on)
	_layout_checklist()
	_sync_desktop_bars(not on)


func _result_overlay_active() -> bool:
	return (
		result_panel != null
		and result_panel.visible
		and (phase == Phase.FAILED or phase == Phase.WON)
	)


func _sync_desktop_bars(show: bool) -> void:
	## Touch HUD owns the command row. Never stack ExtraBar + BottomBar under it.
	## Fail/win overlays hide the bars so the three-line card / 下一关 CTA is not buried.
	var bars := show and not _result_overlay_active()
	var bar: Control = get_node_or_null("HUD/Root/BottomBar") as Control
	if bar:
		bar.visible = bars
	if extra_bar:
		extra_bar.visible = bars
		extra_bar.z_index = 0


func desktop_command_bars_visible() -> bool:
	var bar: Control = get_node_or_null("HUD/Root/BottomBar") as Control
	var bottom_on := bar != null and bar.visible
	var extra_on := extra_bar != null and extra_bar.visible
	return bottom_on or extra_on


func _kill_loop_tweens() -> void:
	if _decision_pulse_tween != null:
		_decision_pulse_tween.kill()
		_decision_pulse_tween = null
	if _trap_callout_tween != null:
		_trap_callout_tween.kill()
		_trap_callout_tween = null
	if _second_callout_tween != null:
		_second_callout_tween.kill()
		_second_callout_tween = null


func _hide_duplicate_tut() -> void:
	## Overlay + spawn-teach chip already teach. Keep TutLabel text for
	## debug/smoke but never paint the south-map plate on desktop or phone.
	if tut_label:
		tut_label.visible = false
	var plate := get_node_or_null("HUD/Root/TutPlate") as ColorRect
	if plate:
		plate.visible = false


func _pin_role_cards(touch: bool) -> void:
	## Art 5.0 pinned cards to content height so 夜枭 does not stretch across
	## the checklist. Phone chrome used to inflate desktop cards to 138px and
	## leave a 400px dock well; restore content height whenever touch is off.
	var card_min := Vector2(220, 142) if touch else Vector2(204, 96)
	for card in role_cards:
		if card is Control:
			var c := card as Control
			c.custom_minimum_size = card_min
			c.size_flags_vertical = 0
	if role_box == null or not is_instance_valid(role_box):
		return
	role_box.size_flags_vertical = 0
	var h := 0.0
	if role_box is Container:
		h = (role_box as Container).get_combined_minimum_size().y
	if h < 200.0:
		var seps := 16.0
		var plan_h := 0.0 if touch else 56.0
		h = 3.0 * card_min.y + seps + plan_h
	role_box.offset_bottom = role_box.offset_top + h
	_apply_result_rail()


func _apply_result_rail() -> void:
	## Fail/win: hide the left rail so the three-line card is not bitten.
	if role_box == null or not is_instance_valid(role_box):
		return
	role_box.visible = not _result_overlay_active()


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
		Phase.SWEEP:
			phase_name = "SWEEP"
		_:
			phase_name = "SETUP"
	var paused := phase == Phase.WATCHING and sim.paused
	var hi := phase == Phase.WATCHING and sim.speed >= 1.5
	var has_pack := level != null and bool(level.has_ammo_pack)
	var has_door := level != null and level.door_cell.x >= 0
	_refresh_alarm_cta()
	touch_hud.refresh_phase(
		phase_name, paused, hi, sfx_muted, _event_log_open and event_log != null and event_log.visible,
		has_pack, has_door
	)
	if touch_hud.has_method("set_alarm_cta") and alarm_button:
		touch_hud.set_alarm_cta(str(alarm_button.text))
	if touch_hud.has_method("set_next_wave"):
		var show_wave := phase == Phase.WATCHING
		var chip := ""
		if show_wave:
			var info := _next_wave_info()
			if bool(info.get("pending", false)):
				var road := _route_zh_short(str(info.get("route", "main")))
				if str(info.get("kit", "")) == "echo" or str(info.get("note", "")).find("回波") >= 0:
					road = "回波"
				chip = "下一波 %s %.1fs" % [road, float(info.get("remain", 0.0))]
		touch_hud.set_next_wave(chip, show_wave and chip != "")
	_refresh_watch_wave_chip()


func _toggle_event_log() -> void:
	_event_log_open = not _event_log_open
	if event_log:
		event_log.visible = _event_log_open
	if log_button:
		log_button.text = "收日志" if _event_log_open else "日志"
	if _event_log_open:
		_update_event_log()
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
		"skip":
			_on_skip_to_outcome_pressed()
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
		"replay":
			_on_replay_pressed()
		"rotate_cw":
			if phase == Phase.SETUP and selected and selected.visible:
				selected.rotate_by(15.0)
				_sfx("ui")
				_announce_plan_edit()
				_refresh_killzone_preview()
		"rotate_ccw":
			if phase == Phase.SETUP and selected and selected.visible:
				selected.rotate_by(-15.0)
				_sfx("ui")
				_announce_plan_edit()
				_refresh_killzone_preview()
		"nade":
			_place_nade_mark()
		"nade_watch":
			_toggle_auto_grenade()
		"bag":
			_toggle_backpack()
		"decoy":
			_throw_decoy_at(_throw_ahead(90.0))
		"pass":
			_transfer_selected_to_nearest()
		"haul":
			_toggle_haul_corpse()
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
	if _skipping_outcome and cue != "fail" and cue != "win" and cue != "escape" and cue != "win_stinger":
		return
	sfx.play(cue)


func _sfx_every_shot(op: OperatorUnit = null) -> void:
	## Every burst, not only the first-contact payoff. Kit timbre per role.
	_sfx(fire_cue_for(op))


func fire_cue_for(op: OperatorUnit = null) -> String:
	if op == null:
		return "fire"
	if op.weapon_id != "" and WeaponCatalogScript.is_firearm(str(op.weapon_id)):
		return WeaponCatalogScript.sfx_cue(str(op.weapon_id))
	match op.role:
		OperatorUnit.Role.MG:
			return "fire_mg"
		OperatorUnit.Role.SCOUT:
			return "fire_scout"
		_:
			return "fire"


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
	_ensure_result_layout()
	_ensure_dossier_ui()
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


func _ensure_dossier_ui() -> void:
	var vbox := result_panel.get_node_or_null("Margin/VBox") as VBoxContainer
	if vbox == null:
		return
	if dossier_button == null or not is_instance_valid(dossier_button):
		dossier_button = vbox.get_node_or_null("DossierButton") as Button
		if dossier_button == null:
			dossier_button = Button.new()
			dossier_button.name = "DossierButton"
			dossier_button.text = "卷宗"
			dossier_button.visible = false
			dossier_button.pressed.connect(_toggle_fail_dossier)
			vbox.add_child(dossier_button)
			var cont_i := continue_button.get_index() if continue_button else vbox.get_child_count()
			vbox.move_child(dossier_button, maxi(0, cont_i))
	if result_dossier == null or not is_instance_valid(result_dossier):
		result_dossier = vbox.get_node_or_null("ResultDossier") as Label
		if result_dossier == null:
			result_dossier = Label.new()
			result_dossier.name = "ResultDossier"
			result_dossier.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			result_dossier.add_theme_font_size_override("font_size", 13)
			result_dossier.add_theme_color_override("font_color", Color(0.72, 0.78, 0.70))
			result_dossier.visible = false
			vbox.add_child(result_dossier)
			vbox.move_child(result_dossier, dossier_button.get_index() + 1)


func _toggle_fail_dossier() -> void:
	_dossier_open = not _dossier_open
	if result_dossier:
		result_dossier.visible = _dossier_open and _fail_dossier_text != ""
	if dossier_button:
		dossier_button.text = "收起卷宗" if _dossier_open else "卷宗"


func fail_dossier_text() -> String:
	return _fail_dossier_text


func fail_result_search_text() -> String:
	var card := str(result_label.text) if result_label else ""
	return "%s\n%s" % [card, _fail_dossier_text]


func _ensure_result_headline() -> void:
	_ensure_result_layout()


func _ensure_result_layout() -> void:
	var vbox := result_panel.get_node_or_null("Margin/VBox") as VBoxContainer
	if vbox == null:
		return
	if result_headline == null or not is_instance_valid(result_headline):
		result_headline = vbox.get_node_or_null("ResultHeadline") as Label
		if result_headline == null:
			result_headline = Label.new()
			result_headline.name = "ResultHeadline"
			result_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			result_headline.add_theme_font_size_override("font_size", 30)
			result_headline.add_theme_font_override("font", NightOps.display_font())
	if _result_columns == null or not is_instance_valid(_result_columns):
		_result_columns = vbox.get_node_or_null("ResultColumns") as GridContainer
		if _result_columns == null:
			_result_columns = GridContainer.new()
			_result_columns.name = "ResultColumns"
			_result_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_result_columns.add_theme_constant_override("h_separation", 18)
			_result_columns.add_theme_constant_override("v_separation", 8)
			vbox.add_child(_result_columns)
			vbox.move_child(_result_columns, 0)
	if result_headline.get_parent() != _result_columns:
		if result_headline.get_parent() != null:
			result_headline.get_parent().remove_child(result_headline)
		_result_columns.add_child(result_headline)
		_result_columns.move_child(result_headline, 0)
	if result_stats == null or not is_instance_valid(result_stats):
		result_stats = _result_columns.get_node_or_null("ResultStats") as Label
		if result_stats == null:
			result_stats = Label.new()
			result_stats.name = "ResultStats"
			result_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			result_stats.add_theme_font_size_override("font_size", 15)
			result_stats.add_theme_color_override("font_color", NightOps.TEXT)
			result_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_result_columns.add_child(result_stats)
	_apply_result_columns()


func _is_wide_result() -> bool:
	var vp := get_viewport()
	var w := 1280.0
	if vp:
		w = vp.get_visible_rect().size.x
	if _want_touch() and w < 1100.0:
		return false
	return w >= 900.0


func _apply_result_columns() -> void:
	if _result_columns == null:
		return
	var wide := _is_wide_result()
	_result_columns.columns = 2 if wide else 1
	if result_headline:
		result_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_CENTER
		result_headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if result_stats:
		result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		result_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _fill_result_stats() -> void:
	_ensure_result_layout()
	if result_stats == null:
		return
	var shot := "—"
	var ev: Dictionary = battle_log.first_of_type("fire") if battle_log else {}
	if not ev.is_empty():
		shot = str(ev.get("payload", {}).get("name", "")).strip_edges()
		if shot == "":
			var op := _op_by_id(int(ev.get("actor_id", -1)))
			shot = op.display_name if op else ("队员%d" % int(ev.get("actor_id", 0)))
	var esc := "无"
	if phase == Phase.FAILED and fail_reason == "escape":
		var route := intel.latest_route() if intel and intel.has_method("latest_route") else ""
		esc = _route_zh_short(route) if route != "" else "有"
	var ticks := battle_log.terminal_tick if battle_log and battle_log.terminal_tick >= 0 else sim.tick
	var secs := float(ticks) / 60.0
	var hook := ""
	if level != null:
		hook = str(level.highlight_hook).strip_edges()
	var shot_line := "第一枪是  %s" % shot
	if hook != "":
		result_stats.text = "世数  %d\n%s\n逃逸  %s\n用时  %.1fs\n高光  %s" % [loop_index, shot_line, esc, secs, hook]
	else:
		result_stats.text = "世数  %d\n%s\n逃逸  %s\n用时  %.1fs" % [loop_index, shot_line, esc, secs]
	result_stats.visible = true
	_apply_result_columns()


func result_stats_block_text() -> String:
	if result_stats == null or not is_instance_valid(result_stats):
		return ""
	return str(result_stats.text).strip_edges()


func _mission_title_color() -> Color:
	var id := ""
	if level:
		id = level.atmosphere_id if level.atmosphere_id != "" else level.level_id
	return LevelDef.signature_color(id)


func _bind_result_headline(text: String) -> void:
	_ensure_result_headline()
	if result_headline == null:
		return
	result_headline.visible = true
	result_headline.text = text
	_apply_result_columns()
	var col := _mission_title_color()
	result_headline.add_theme_color_override("font_color", col)
	result_headline.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.02, 0.85))
	result_headline.add_theme_constant_override("shadow_offset_x", 1)
	result_headline.add_theme_constant_override("shadow_offset_y", 1)


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
	var dim_routes := not _is_command_phase()
	if routes_draw:
		routes_draw.modulate = Color(1, 1, 1, 0.32) if dim_routes else Color.WHITE
	if killzone_draw:
		killzone_draw.modulate = Color.WHITE
		killzone_draw.visible = _is_command_phase()
	if decision_marker and is_instance_valid(decision_marker):
		decision_marker.visible = _is_command_phase()
	if barrel_hint and is_instance_valid(barrel_hint):
		barrel_hint.visible = _is_command_phase()
	if trap_callout and is_instance_valid(trap_callout):
		if phase != Phase.SETUP:
			trap_callout.visible = false
		else:
			trap_callout.visible = true
			trap_callout.modulate.a = 1.0
	if second_callout and is_instance_valid(second_callout):
		if phase != Phase.SETUP:
			second_callout.visible = false
		else:
			second_callout.visible = true
			second_callout.modulate.a = 1.0
	if trap_path and is_instance_valid(trap_path):
		trap_path.visible = phase == Phase.SETUP
		if phase == Phase.SETUP:
			trap_path.modulate.a = 1.0
	if spawn_ghost_host and is_instance_valid(spawn_ghost_host):
		spawn_ghost_host.visible = phase == Phase.SETUP
	if plan_ghost_host and is_instance_valid(plan_ghost_host):
		plan_ghost_host.visible = phase == Phase.SETUP
	if entities:
		entities.modulate = Color.WHITE
	if ghosts:
		ghosts.modulate = Color.WHITE
	if sfx and sfx.has_method("set_watch_bed"):
		sfx.set_watch_bed(phase == Phase.WATCHING)
	_ensure_watch_cinema()
	var cinema := phase == Phase.WATCHING or phase == Phase.WON
	if _watch_letterbox:
		_watch_letterbox.visible = cinema
		var banner := _watch_letterbox.get_node_or_null("WatchBanner") as Label
		if banner:
			var spd := "暂停" if sim.paused else ("2×" if sim.speed >= 1.5 else "1×")
			var night := LevelDef.mood_tag(level.level_id) if level else "初阵"
			if phase == Phase.WON:
				banner.text = "封锁成功  ·  %s  ·  t=%.1fs" % [night, sim.time_sec()]
			else:
				var w := wave_index() + 1
				var tot := maxi(wave_total(), 1)
				banner.text = "警报中  ·  第%d/%d波  ·  %s  ·  %s  ·  t=%.1fs  ·  %s" % [
					w, tot, night, spd, sim.time_sec(), watch_census_text()
				]
		_refresh_watch_metronome()
		_refresh_watch_clock()
	if _watch_vignette:
		_watch_vignette.visible = cinema
	if title_label:
		title_label.visible = not cinema
	if phase_chip:
		phase_chip.visible = not cinema
	_refresh_watch_timeline()


func _ensure_watch_metronome() -> void:
	if _watch_letterbox == null or not is_instance_valid(_watch_letterbox):
		return
	if _watch_letterbox.get_node_or_null("Metronome") != null:
		return
	var top := _watch_letterbox.get_node_or_null("LetterboxTop") as Control
	var top_h := 30.0
	if top:
		top_h = absf(top.offset_bottom)
	var metro := HBoxContainer.new()
	metro.name = "Metronome"
	metro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metro.alignment = BoxContainer.ALIGNMENT_CENTER
	metro.add_theme_constant_override("separation", 6)
	metro.set_anchors_preset(Control.PRESET_TOP_WIDE)
	metro.offset_top = top_h - 8.0
	metro.offset_bottom = top_h
	metro.offset_left = 80.0
	metro.offset_right = -80.0
	_watch_letterbox.add_child(metro)
	for i in 8:
		var pip := ColorRect.new()
		pip.name = "Pip%d" % i
		pip.custom_minimum_size = Vector2(10, 4)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.color = Color(0.62, 0.72, 0.38, 0.28)
		metro.add_child(pip)


func _refresh_watch_metronome() -> void:
	_ensure_watch_metronome()
	if _watch_letterbox == null:
		return
	var metro := _watch_letterbox.get_node_or_null("Metronome") as HBoxContainer
	if metro == null:
		return
	metro.visible = phase == Phase.WATCHING
	if phase != Phase.WATCHING:
		return
	var rate := 2.0 if sim.speed >= 1.5 else 1.0
	if sim.paused:
		rate = 0.0
	var beat := int(floor(sim.time_sec() * maxf(rate, 0.25) * 2.0)) % 8
	for i in metro.get_child_count():
		var pip := metro.get_child(i) as ColorRect
		if pip == null:
			continue
		var hot := i == beat and not sim.paused
		pip.color = Color(0.78, 0.62, 0.28, 0.95) if hot else Color(0.42, 0.36, 0.20, 0.28)


func _ensure_watch_clock() -> void:
	if _watch_letterbox == null or not is_instance_valid(_watch_letterbox):
		return
	if _watch_letterbox.get_node_or_null("WatchClock") != null:
		return
	var lab := Label.new()
	lab.name = "WatchClock"
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lab.anchor_left = 1.0
	lab.offset_left = -168.0
	lab.offset_right = -12.0
	lab.offset_top = 4.0
	lab.offset_bottom = 26.0
	lab.add_theme_font_override("font", NightOps.ui_font_bold())
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", Color(0.92, 0.88, 0.52))
	lab.text = "t=0.0s"
	_watch_letterbox.add_child(lab)


func _refresh_watch_clock() -> void:
	_ensure_watch_clock()
	if _watch_letterbox == null:
		return
	var lab := _watch_letterbox.get_node_or_null("WatchClock") as Label
	if lab == null:
		return
	lab.visible = phase == Phase.WATCHING
	if phase != Phase.WATCHING:
		return
	lab.text = "t=%.1fs" % sim.time_sec()


func watch_clock_text() -> String:
	if _watch_letterbox == null:
		return ""
	var lab := _watch_letterbox.get_node_or_null("WatchClock") as Label
	if lab == null:
		return ""
	return str(lab.text)


func watch_metronome_visible() -> bool:
	if _watch_letterbox == null:
		return false
	var metro := _watch_letterbox.get_node_or_null("Metronome")
	return metro != null and metro.visible and metro.get_child_count() >= 8


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
	var z := _cam_zoom * _cam_zoom_punch
	_game_cam.zoom = Vector2(z, z)
	_game_cam.offset = _cam_pan + _cam_punch


func _reset_cam_view() -> void:
	_cam_pan = Vector2.ZERO
	_cam_zoom = 1.0
	_cam_punch = Vector2.ZERO
	_cam_zoom_punch = 1.0
	if _stinger_tween != null:
		_stinger_tween.kill()
		_stinger_tween = null
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
	if _alarm_vignette == null or not is_instance_valid(_alarm_vignette):
		_alarm_vignette = ColorRect.new()
		_alarm_vignette.name = "AlarmVignette"
		_alarm_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_alarm_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		_alarm_vignette.color = Color(0.78, 0.05, 0.04, 0.0)
		_alarm_vignette.z_index = 38
		root.add_child(_alarm_vignette)
	if _sig_wash == null or not is_instance_valid(_sig_wash):
		_sig_wash = ColorRect.new()
		_sig_wash.name = "SigWash"
		_sig_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sig_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_sig_wash.color = Color(0.62, 0.74, 0.32, 0.0)
		_sig_wash.z_index = 36
		root.add_child(_sig_wash)
	_ensure_watch_cinema()
	_ensure_fail_static()


func _dock_setup_help() -> void:
	## Collapse the old full-width south paragraph into a one-line hint that
	## sits in the left extra-bar band. Role cards, map callouts, and buttons
	## already teach; the courtyard (南廊 / 中庭 / 逃逸口) must stay readable.
	if help_label == null:
		return
	help_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help_label.anchor_left = 0.0
	help_label.anchor_top = 1.0
	help_label.anchor_right = 0.0
	help_label.anchor_bottom = 1.0
	help_label.offset_left = 10.0
	help_label.offset_right = 214.0
	help_label.offset_top = -52.0
	help_label.offset_bottom = -16.0
	help_label.grow_horizontal = Control.GROW_DIRECTION_END
	help_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	help_label.clip_text = true
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_label.add_theme_font_size_override("font_size", 12)
	help_label.add_theme_color_override("font_color", Color(0.70, 0.64, 0.46, 0.90))


func _ensure_tut_plate(root: Control) -> void:
	if root == null or tut_label == null:
		return
	var plate := root.get_node_or_null("TutPlate") as ColorRect
	if plate == null:
		plate = ColorRect.new()
		plate.name = "TutPlate"
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.color = Color(0.04, 0.05, 0.04, 0.78)
		plate.set_anchors_preset(Control.PRESET_TOP_WIDE)
		plate.offset_left = 228.0
		plate.offset_top = 90.0
		plate.offset_right = -12.0
		plate.offset_bottom = 136.0
		plate.z_index = -1
		root.add_child(plate)
		root.move_child(plate, tut_label.get_index())


func _ensure_flash_plate(root: Control) -> void:
	if root == null or flash_label == null:
		return
	var plate := root.get_node_or_null("FlashPlate") as ColorRect
	if plate == null:
		plate = ColorRect.new()
		plate.name = "FlashPlate"
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.color = Color(0.05, 0.06, 0.03, 0.82)
		plate.set_anchors_preset(Control.PRESET_CENTER_TOP)
		plate.offset_left = -300.0
		plate.offset_right = 300.0
		plate.offset_top = 70.0
		plate.offset_bottom = 106.0
		plate.z_index = 0
		root.add_child(plate)
		root.move_child(plate, flash_label.get_index())
		plate.modulate.a = 0.0


func _ensure_watch_cinema() -> void:
	var root: Control = $HUD/Root
	var top_h := 18.0 if _is_power_saving() else 30.0
	var bot_h := 6.0 if _is_power_saving() else 10.0
	if _watch_letterbox == null or not is_instance_valid(_watch_letterbox):
		_watch_letterbox = Control.new()
		_watch_letterbox.name = "WatchLetterbox"
		_watch_letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_watch_letterbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		_watch_letterbox.z_index = 42
		root.add_child(_watch_letterbox)
		var top := ColorRect.new()
		top.name = "LetterboxTop"
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.color = Color(0.015, 0.025, 0.018, 0.94)
		top.set_anchors_preset(Control.PRESET_TOP_WIDE)
		top.offset_bottom = top_h
		_watch_letterbox.add_child(top)
		var banner := Label.new()
		banner.name = "WatchBanner"
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.text = "警报中"
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
		banner.offset_bottom = top_h
		banner.add_theme_font_override("font", NightOps.ui_font_bold())
		banner.add_theme_font_size_override("font_size", 14)
		banner.add_theme_color_override("font_color", NightOps.OLIVE_HI)
		_watch_letterbox.add_child(banner)
		var top_line := ColorRect.new()
		top_line.name = "LetterboxTopLine"
		top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_line.color = Color(0.62, 0.72, 0.38, 0.55)
		top_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
		top_line.offset_top = top_h - 2.0
		top_line.offset_bottom = top_h
		_watch_letterbox.add_child(top_line)
		var bot := ColorRect.new()
		bot.name = "LetterboxBot"
		bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bot.color = Color(0.015, 0.025, 0.018, 0.94)
		bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bot.offset_top = -bot_h
		_watch_letterbox.add_child(bot)
		var bot_line := ColorRect.new()
		bot_line.name = "LetterboxBotLine"
		bot_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bot_line.color = Color(0.62, 0.72, 0.38, 0.45)
		bot_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bot_line.offset_top = -bot_h
		bot_line.offset_bottom = -bot_h + 2.0
		_watch_letterbox.add_child(bot_line)
		_watch_letterbox.visible = false
	_ensure_watch_metronome()
	_ensure_watch_clock()
	if _watch_vignette == null or not is_instance_valid(_watch_vignette):
		_watch_vignette = Control.new()
		_watch_vignette.name = "WatchVignette"
		_watch_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_watch_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		_watch_vignette.z_index = 34
		root.add_child(_watch_vignette)
		var specs: Array = [
			["VigTop", Control.PRESET_TOP_WIDE, 0.0, 0.0, 0.0, 90.0],
			["VigBot", Control.PRESET_BOTTOM_WIDE, 0.0, -110.0, 0.0, 0.0],
			["VigLeft", Control.PRESET_LEFT_WIDE, 0.0, 0.0, 70.0, 0.0],
			["VigRight", Control.PRESET_RIGHT_WIDE, -70.0, 0.0, 0.0, 0.0],
		]
		var va := 0.16 if _is_power_saving() else 0.28
		for spec in specs:
			var edge := ColorRect.new()
			edge.name = str(spec[0])
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			edge.color = Color(0.02, 0.03, 0.02, va)
			edge.set_anchors_preset(int(spec[1]))
			edge.offset_left = float(spec[2])
			edge.offset_top = float(spec[3])
			edge.offset_right = float(spec[4])
			edge.offset_bottom = float(spec[5])
			_watch_vignette.add_child(edge)
		_watch_vignette.visible = false


func _ensure_fail_static() -> void:
	var root: Control = $HUD/Root
	if _fail_static != null and is_instance_valid(_fail_static):
		return
	_fail_static = Control.new()
	_fail_static.name = "FailStatic"
	_fail_static.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fail_static.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fail_static.z_index = 44
	root.add_child(_fail_static)
	var wash := ColorRect.new()
	wash.name = "Wash"
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.08, 0.10, 0.08, 0.22)
	_fail_static.add_child(wash)
	for i in 7:
		var line := ColorRect.new()
		line.name = "Scan%d" % i
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.color = Color(0.78, 0.82, 0.62, 0.07)
		line.set_anchors_preset(Control.PRESET_TOP_WIDE)
		line.offset_top = 70.0 + float(i) * 88.0
		line.offset_bottom = line.offset_top + 3.0
		_fail_static.add_child(line)
	_fail_static.visible = false
	_fail_static.modulate.a = 0.0


func _play_fail_static() -> void:
	_ensure_fail_static()
	if _fail_static == null:
		return
	if _fail_static_tween != null:
		_fail_static_tween.kill()
	_fail_static.visible = true
	_fail_static.modulate.a = 0.0
	var dur := 0.18 if _is_power_saving() else 0.42
	_fail_static_tween = _fail_static.create_tween()
	_fail_static_tween.tween_property(_fail_static, "modulate:a", 1.0, 0.06)
	_fail_static_tween.tween_interval(dur)
	_fail_static_tween.tween_property(_fail_static, "modulate:a", 0.0, 0.20)
	_fail_static_tween.tween_callback(func() -> void:
		if _fail_static:
			_fail_static.visible = false
	)


func _is_power_saving() -> bool:
	var gs = _gs()
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


func _alarm_edge_flash() -> void:
	_ensure_presentation_fx()
	if _rim_tween != null:
		_rim_tween.kill()
	var saving := _is_power_saving()
	var vig_peak := 0.16 if saving else 0.46
	var edge_peak := 0.40 if saving else 0.88
	if _rim_flash:
		for c in _rim_flash.get_children():
			if c is ColorRect:
				(c as ColorRect).color = Color(0.95, 0.22, 0.08, 0.0)
	if _alarm_vignette:
		_alarm_vignette.color = Color(0.82, 0.04, 0.03, 0.0)
	_rim_tween = create_tween()
	# Full-width red vignette, 0.3s total. 省电 keeps a thin wash.
	_rim_tween.set_parallel(true)
	if _alarm_vignette:
		_rim_tween.tween_property(_alarm_vignette, "color:a", vig_peak, 0.06)
	if _rim_flash:
		for c in _rim_flash.get_children():
			if c is ColorRect:
				_rim_tween.tween_property(c, "color:a", edge_peak, 0.06)
	_rim_tween.chain()
	_rim_tween.set_parallel(true)
	if _alarm_vignette:
		_rim_tween.tween_property(_alarm_vignette, "color:a", 0.0, 0.24)
	if _rim_flash:
		for c in _rim_flash.get_children():
			if c is ColorRect:
				_rim_tween.tween_property(c, "color:a", 0.0, 0.24)
	_flash_alarm_button()
	_siren_phase_chip()
	if not saving:
		_camera_punch(Vector2(8, -5))


func _win_stinger() -> void:
	## Phase.WON: mission signature wash + procedural flourish. 省电 skips.
	if _is_power_saving():
		return
	_sfx("win_stinger")
	_ensure_presentation_fx()
	var lid := level.level_id if level else "yard"
	var sig: Color = LevelDef.signature_color(lid)
	if _sig_wash:
		_sig_wash.color = Color(sig.r, sig.g, sig.b, 0.0)
	if _win_stinger_tween != null:
		_win_stinger_tween.kill()
	_win_stinger_tween = create_tween()
	if _sig_wash:
		_win_stinger_tween.tween_property(_sig_wash, "color:a", 0.40, 0.07)
		_win_stinger_tween.tween_property(_sig_wash, "color:a", 0.0, 0.22)


func _play_load_fade() -> void:
	## 0.2s darken → map reveal after _load_level. Cheap modulate, both quality tiers.
	if not has_node("World"):
		return
	if _load_fade_tween != null:
		_load_fade_tween.kill()
	$World.modulate = Color(0.11, 0.12, 0.13)
	_load_fade_tween = create_tween()
	_load_fade_tween.tween_property($World, "modulate", Color.WHITE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func load_fade_active() -> bool:
	return _load_fade_tween != null and is_instance_valid(_load_fade_tween) and _load_fade_tween.is_running()


func win_stinger_active() -> bool:
	return _win_stinger_tween != null and is_instance_valid(_win_stinger_tween) and _win_stinger_tween.is_running()


func _alarm_cam_stinger() -> void:
	## SETUP→WATCHING lock: 0.25s zoom punch + cue. 省电 skips (rim flash remains).
	if _is_power_saving():
		return
	_sfx("alarm_stinger")
	_ensure_game_camera()
	if _stinger_tween != null:
		_stinger_tween.kill()
	_cam_zoom_punch = 1.0
	_apply_cam()
	_stinger_tween = create_tween()
	_stinger_tween.tween_method(func(z: float) -> void:
		_cam_zoom_punch = z
		_apply_cam()
	, 1.0, 1.04, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_stinger_tween.tween_method(func(z: float) -> void:
		_cam_zoom_punch = z
		_apply_cam()
	, 1.04, 1.0, 0.17).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _kill_edge_flash() -> void:
	## Brief green rim on a confirmed kill. Standard tier only — 省电 skips the wash.
	if _is_power_saving():
		return
	_ensure_presentation_fx()
	if _rim_tween != null:
		_rim_tween.kill()
		_rim_tween = null
	if _kill_tween != null:
		_kill_tween.kill()
	if _rim_flash == null:
		return
	for c in _rim_flash.get_children():
		if c is ColorRect:
			(c as ColorRect).color = Color(0.28, 0.95, 0.42, 0.0)
	_kill_tween = create_tween()
	_kill_tween.set_parallel(true)
	for c in _rim_flash.get_children():
		if c is ColorRect:
			_kill_tween.tween_property(c, "color:a", 0.62, 0.05)
	_kill_tween.chain()
	_kill_tween.set_parallel(true)
	for c in _rim_flash.get_children():
		if c is ColorRect:
			_kill_tween.tween_property(c, "color:a", 0.0, 0.18)


func _shake_for_explosion(world_pos: Vector2) -> void:
	## Micro camera punch when a barrel pops near a living operator. Standard only.
	if _is_power_saving() or phase != Phase.WATCHING:
		return
	var near := false
	for op in operators:
		if op.visible and op.alive and op.global_position.distance_to(world_pos) <= 280.0:
			near = true
			break
	if not near:
		return
	_camera_punch(Vector2(5, -4))


func _siren_phase_chip() -> void:
	if phase_chip == null:
		return
	phase_chip.add_theme_color_override("font_color", Color(1.0, 0.18, 0.12))
	phase_chip.modulate = Color(1.45, 0.55, 0.40)
	if _phase_chip_tween != null:
		_phase_chip_tween.kill()
	_phase_chip_tween = create_tween()
	_phase_chip_tween.tween_property(phase_chip, "modulate", Color.WHITE, 0.42)


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
	if _kill_tween != null:
		_kill_tween.kill()
		_kill_tween = null
	if has_node("World"):
		$World.modulate = Color.WHITE
	if _tone_wash:
		_tone_wash.color.a = 0.0
	if _rim_flash:
		for c in _rim_flash.get_children():
			if c is ColorRect:
				(c as ColorRect).color.a = 0.0
	if _alarm_vignette:
		_alarm_vignette.color.a = 0.0
	if _sig_wash:
		_sig_wash.color.a = 0.0
	if _win_stinger_tween != null:
		_win_stinger_tween.kill()
		_win_stinger_tween = null
	if _load_fade_tween != null:
		_load_fade_tween.kill()
		_load_fade_tween = null
	if result_panel:
		result_panel.modulate = Color.WHITE


func _fade_result_panel() -> void:
	if result_panel == null:
		return
	if _result_fade_tween != null:
		_result_fade_tween.kill()
	result_panel.modulate.a = 0.0
	_result_fade_tween = create_tween()
	_result_fade_tween.tween_property(result_panel, "modulate:a", 1.0, 0.15)


func _load_level(level_id: String, keep_intel: bool, restore_plan: bool) -> void:
	_mission_had_escape = false
	_door_taught = false
	_wave_tension_id = -1
	if not keep_intel:
		leak_advice_shown = ""
	_kill_loop_tweens()
	_clear_intel_path_ghost()
	_clear_echo_callout()
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
	_ensure_night_grade()
	_play_mission_ambient()
	_build_route_world()
	_build_cover_slots()
	_build_operators()
	_draw_fixed_routes()
	_build_ambush_zone_visual()
	_build_door_marker()
	_build_decision_marker()
	_build_barrels()
	_build_trap_callout()
	_build_second_callout()
	_build_echo_callout()
	_build_trap_path()
	_start_setup(keep_intel, restore_plan)
	_save_progress()
	_maybe_show_tutorial()
	_play_load_fade()


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


func _ensure_night_grade() -> void:
	if night_grade == null or not is_instance_valid(night_grade):
		night_grade = get_node_or_null("NightGrade") as CanvasModulate
	if night_grade == null or not is_instance_valid(night_grade):
		night_grade = get_node_or_null("World/NightGrade") as CanvasModulate
	if night_grade == null or not is_instance_valid(night_grade):
		night_grade = NightGradeScript.new() as CanvasModulate
		night_grade.name = "NightGrade"
		add_child(night_grade)
		move_child(night_grade, 0)
	var atmo := "yard"
	if level:
		atmo = level.atmosphere_id if level.atmosphere_id != "" else level.level_id
	if night_grade.has_method("setup"):
		night_grade.setup(atmo)


func _play_mission_ambient() -> void:
	if sfx == null or level == null:
		return
	if sfx.has_method("play_mission_ambient"):
		sfx.play_mission_ambient(level.level_id)
	if sfx.has_method("play_mission_mood"):
		sfx.play_mission_mood(level.level_id)
	_sfx("night_enter")


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


func _killzone_ops() -> Array[OperatorUnit]:
	var out: Array[OperatorUnit] = []
	for op in operators:
		if op != null and op.visible and op.alive:
			out.append(op)
	return out


func _refresh_killzone_preview() -> void:
	if killzone_draw == null:
		return
	for c in killzone_draw.get_children():
		killzone_draw.remove_child(c)
		c.free()
	if phase != Phase.SETUP:
		return
	var shooters := _killzone_ops()
	if shooters.is_empty():
		return
	const STEP := 16.0
	for route in _active_routes():
		var hit_run := PackedVector2Array()
		for p in _sample_polyline(route, STEP):
			var covered := false
			for op in shooters:
				if op.in_fire_geometry(p, grid):
					covered = true
					break
			if covered:
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
	var drawn: PackedVector2Array
	if pts.size() == 1:
		var p: Vector2 = pts[0]
		drawn = PackedVector2Array([p + Vector2(-5, 0), p + Vector2(5, 0)])
	else:
		drawn = pts
	var glow := Line2D.new()
	glow.width = 16.0
	glow.default_color = Color(0.95, 0.22, 0.12, 0.16)
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.joint_mode = Line2D.LINE_JOINT_ROUND
	glow.points = drawn
	killzone_draw.add_child(glow)
	var line := Line2D.new()
	line.width = 8.0
	line.default_color = Color(0.95, 0.28, 0.18, 0.42)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.points = drawn
	killzone_draw.add_child(line)
	var tip: Vector2 = drawn[drawn.size() - 1]
	var tick := Polygon2D.new()
	tick.polygon = PackedVector2Array([
		Vector2(-4, -4), Vector2(4, 0), Vector2(-4, 4)
	])
	tick.position = tip
	tick.color = Color(1.0, 0.55, 0.22, 0.72)
	killzone_draw.add_child(tick)


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
	s.setup(id, text, 0.0, cover_kit_for_level())
	s.z_index = 0
	s.z_as_relative = true
	return s


func cover_kit_for_level() -> String:
	if level == null:
		return "crate"
	match str(level.atmosphere_id):
		"warehouse":
			return "pallet"
		"pump":
			return "valve"
		"railcut":
			return "sleeper"
		"depot":
			return "drum"
		"radio":
			return "dish"
		_:
			return "crate"


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
	body.polygon = OperatorSilhouetteScript.body_poly(OperatorUnit.role_for_id(id))
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
	var rim := Line2D.new()
	rim.name = "RoleRim"
	rim.closed = true
	rim.width = 2.8
	rim.z_index = 0
	op.add_child(rim)
	return op


func _draw_fixed_routes() -> void:
	for c in routes_draw.get_children():
		c.queue_free()
	var colors := {
		"main": Color(0.9, 0.4, 0.35, 0.35),
		"flank": Color(0.95, 0.55, 0.2, 0.3),
		"sneak": Color(0.55, 0.72, 0.38, 0.32),
		"echo": Color(0.62, 0.52, 0.28, 0.42),
	}
	var labels := {
		"main": "主路·巡卫",
		"flank": "侧翼·奔袭",
		"sneak": "西暗道·影探",
		"echo": "回波·碟缝",
	}
	for key in route_world.keys():
		var col: Color = colors.get(key, Color(0.7, 0.7, 0.4, 0.3))
		_add_route_line(route_world[key], col, str(labels.get(key, key)))
	if not level.alternate_route_cells.is_empty():
		_add_route_line(
			_cells_to_world(level.alternate_route_cells),
			Color(0.62, 0.52, 0.28, 0.32),
			"备用接近·陷阱"
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
		t.position = points[idx] + Vector2(8, -20)
		t.add_theme_font_size_override("font_size", 14)
		t.add_theme_color_override("font_color", Color(color.r, color.g, color.b, 0.95))
		t.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.92))
		t.add_theme_constant_override("shadow_offset_x", 1)
		t.add_theme_constant_override("shadow_offset_y", 1)
		routes_draw.add_child(t)


func _build_ambush_zone_visual() -> void:
	if ambush_zone_poly != null and is_instance_valid(ambush_zone_poly):
		ambush_zone_poly.queue_free()
	ambush_zone_poly = null
	if level.ambush_zone.size == Vector2.ZERO:
		return
	var fx = AmbushZoneFxScript.new()
	fx.name = "AmbushZone"
	var zone_tag := "伏击区"
	if level != null and str(level.level_id) == "warehouse":
		zone_tag = "伏击区 · F 入伏再打"
	var tint := LevelDef.signature_color(level.atmosphere_id if level.atmosphere_id != "" else level.level_id)
	fx.setup(level.ambush_zone, zone_tag, tint)
	$World.add_child(fx)
	ambush_zone_poly = fx
	if level != null and str(level.level_id) == "warehouse" and fx.has_method("set_hot"):
		fx.set_hot(true)


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
		Vector2(-12, -16), Vector2(12, -16), Vector2(12, 16), Vector2(-12, 16)
	])
	pad.color = Color(0.55, 0.4, 0.25, 0.7)
	n.add_child(pad)
	var jamb_l := Polygon2D.new()
	jamb_l.name = "JambL"
	jamb_l.polygon = PackedVector2Array([
		Vector2(-14, -17), Vector2(-10, -17), Vector2(-10, 17), Vector2(-14, 17)
	])
	jamb_l.color = Color(0.22, 0.16, 0.10, 0.95)
	n.add_child(jamb_l)
	var jamb_r := Polygon2D.new()
	jamb_r.name = "JambR"
	jamb_r.polygon = PackedVector2Array([
		Vector2(10, -17), Vector2(14, -17), Vector2(14, 17), Vector2(10, 17)
	])
	jamb_r.color = Color(0.22, 0.16, 0.10, 0.95)
	n.add_child(jamb_r)
	var thresh := Polygon2D.new()
	thresh.name = "Threshold"
	thresh.polygon = PackedVector2Array([
		Vector2(-12, 14), Vector2(12, 14), Vector2(14, 18), Vector2(-14, 18)
	])
	thresh.color = Color(0.16, 0.12, 0.08, 0.88)
	n.add_child(thresh)
	var leaf := Polygon2D.new()
	leaf.name = "DoorLeaf"
	leaf.polygon = PackedVector2Array([
		Vector2(0, -14), Vector2(20, -14), Vector2(20, 14), Vector2(0, 14)
	])
	leaf.position = Vector2(-10, 0)
	leaf.color = Color(0.62, 0.42, 0.22, 0.92)
	n.add_child(leaf)
	var panel := Polygon2D.new()
	panel.name = "DoorPanel"
	panel.polygon = PackedVector2Array([
		Vector2(3, -10), Vector2(17, -10), Vector2(17, 10), Vector2(3, 10)
	])
	panel.position = Vector2(-10, 0)
	panel.color = Color(0.42, 0.28, 0.14, 0.75)
	n.add_child(panel)
	var handle := Polygon2D.new()
	handle.name = "Handle"
	handle.polygon = PackedVector2Array([
		Vector2(15, -2), Vector2(18, -2), Vector2(18, 2), Vector2(15, 2)
	])
	handle.position = Vector2(-10, 0)
	handle.color = Color(0.82, 0.72, 0.32, 0.95)
	n.add_child(handle)
	var hinge := Polygon2D.new()
	hinge.name = "Hinge"
	hinge.polygon = PackedVector2Array([
		Vector2(-14, -5), Vector2(-8, -5), Vector2(-8, 5), Vector2(-14, 5)
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


func _build_decision_marker() -> void:
	if decision_marker != null and is_instance_valid(decision_marker):
		decision_marker.queue_free()
	decision_marker = null
	if level == null or level.decision_cell.x < 0:
		return
	var n := Node2D.new()
	n.name = "DecisionMarker"
	n.position = grid.cell_to_world_center(level.decision_cell)
	n.z_index = 2
	var pad := Polygon2D.new()
	pad.polygon = PackedVector2Array([
		Vector2(-12, -12), Vector2(12, -12), Vector2(12, 12), Vector2(-12, 12)
	])
	pad.color = Color(0.72, 0.52, 0.18, 0.28)
	n.add_child(pad)
	var ring := Line2D.new()
	ring.width = 2.0
	ring.closed = true
	ring.default_color = Color(0.95, 0.72, 0.22, 0.85)
	ring.points = PackedVector2Array([
		Vector2(-13, -13), Vector2(13, -13), Vector2(13, 13), Vector2(-13, 13), Vector2(-13, -13)
	])
	n.add_child(ring)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "决策格"
	tag.position = Vector2(-46, -30)
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_font_override("font", NightOps.ui_font_bold())
	tag.add_theme_color_override("font_color", Color(0.98, 0.82, 0.32))
	tag.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.92))
	tag.add_theme_constant_override("shadow_offset_x", 1)
	tag.add_theme_constant_override("shadow_offset_y", 1)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(tag)
	var pulse := Line2D.new()
	pulse.name = "PulseRing"
	pulse.width = 2.5
	pulse.closed = true
	pulse.default_color = Color(0.62, 0.50, 0.24, 0.92)
	pulse.z_index = 3
	var pts := PackedVector2Array()
	for i in 18:
		var ang := TAU * float(i) / 18.0
		pts.append(Vector2(cos(ang), sin(ang)) * 24.0)
	if pts.size() > 0:
		pts.append(pts[0])
	pulse.points = pts
	pulse.visible = false
	n.add_child(pulse)
	routes_draw.add_child(n)
	decision_marker = n
	_refresh_decision_pulse()


func _ensure_checklist(root: Control = null) -> void:
	if checklist_strip != null and is_instance_valid(checklist_strip):
		return
	var host: Control = root
	if host == null:
		host = get_node_or_null("HUD/Root") as Control
	if host == null:
		return
	var box := BoxContainer.new()
	box.name = "SetupChecklist"
	box.vertical = true
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_SHRINK_END
	host.add_child(box)
	checklist_strip = box
	_checklist_labels.clear()
	var titles := ["已部署≥1", "射界覆盖主路", "侧路有火力"]
	for title in titles:
		var lab := Label.new()
		lab.text = title
		lab.add_theme_font_size_override("font_size", 13)
		lab.add_theme_font_override("font", NightOps.ui_font_bold())
		lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.02, 0.9))
		lab.add_theme_constant_override("shadow_offset_x", 1)
		lab.add_theme_constant_override("shadow_offset_y", 1)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lab)
		_checklist_labels.append(lab)
	_layout_checklist()


func _checklist_use_touch_layout() -> bool:
	return _want_touch()


func _layout_checklist() -> void:
	if checklist_strip == null or not is_instance_valid(checklist_strip):
		return
	var host := get_node_or_null("HUD/Root") as Control
	if host != null and checklist_strip.get_parent() != host:
		checklist_strip.get_parent().remove_child(checklist_strip)
		host.add_child(checklist_strip)
	checklist_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lab in _checklist_labels:
		if lab:
			lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := _safe_area_pad()
	_checklist_touch_layout = true
	var box := checklist_strip as BoxContainer
	if box:
		box.vertical = false
		box.alignment = BoxContainer.ALIGNMENT_END
		box.add_theme_constant_override("separation", 10)
	checklist_strip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	checklist_strip.anchor_left = 1.0
	checklist_strip.anchor_top = 0.0
	checklist_strip.anchor_right = 1.0
	checklist_strip.anchor_bottom = 0.0
	# Beside the route timeline, under the phase chip — never over the left cards.
	checklist_strip.offset_left = -520.0
	checklist_strip.offset_top = 38.0 + maxf(0.0, pad.y - 4.0)
	checklist_strip.offset_right = -maxf(8.0, pad.z)
	checklist_strip.offset_bottom = 72.0 + maxf(0.0, pad.y - 4.0)
	checklist_strip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	checklist_strip.grow_vertical = Control.GROW_DIRECTION_END


func _side_route_key() -> String:
	var keys := _play_active_route_keys()
	for k in keys:
		if str(k) != "main":
			return str(k)
	return ""


func _play_active_route_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	if level == null:
		return keys
	keys.append("main")
	if door_locked and not level.alternate_route_cells.is_empty():
		keys.append("alt")
		return keys
	if route_world.has("flank") and not (door_locked and level.door_blocks_route == "flank"):
		keys.append("flank")
	if route_world.has("sneak"):
		keys.append("sneak")
	if route_world.has("echo"):
		keys.append("echo")
	return keys


func _play_route_chip_title(key: String, compact: bool) -> String:
	match key:
		"main":
			return "主路" if compact else "射界覆盖主路"
		"flank":
			return "侧翼"
		"sneak":
			return "暗道"
		"echo":
			return "回波"
		"alt":
			return "紫备用"
		_:
			return key


func _play_ensure_leak_miss_draw() -> void:
	if _leak_miss_draw != null and is_instance_valid(_leak_miss_draw):
		return
	var n := Node2D.new()
	n.name = "LeakMissDraw"
	n.set_script(KillzoneOverlayScript)
	n.z_index = 6
	var world := get_node_or_null("World")
	if world:
		world.add_child(n)
	else:
		add_child(n)
	_leak_miss_draw = n


func _play_has_leak_object() -> bool:
	if intel == null or intel.records.is_empty():
		return false
	var rec: Dictionary = intel.records[intel.records.size() - 1]
	if str(rec.get("reason", "")) != "escape":
		return false
	return not _play_leak_samples().is_empty()


func _play_leak_samples() -> PackedVector2Array:
	var out := PackedVector2Array()
	if intel == null or intel.records.is_empty():
		return out
	var rec: Dictionary = intel.records[intel.records.size() - 1]
	if str(rec.get("reason", "")) != "escape":
		return out
	var path: PackedVector2Array = rec.get("path", PackedVector2Array())
	if path.size() < 2:
		return out
	var leak_pos: Vector2 = path[path.size() - 1]
	var skip: Array = []
	var main_poly := _route_polyline_named("main")
	if not main_poly.is_empty():
		skip.append(main_poly)
	if str(rec.get("route", "")) == "alt" and route_world.has("flank"):
		skip.append(route_world["flank"])
	for p in _sample_polyline(path, 20.0):
		if p.distance_to(leak_pos) <= 96.0:
			continue
		var shared := false
		for poly in skip:
			if _dist_to_polyline(p, poly) <= 28.0:
				shared = true
				break
		if shared:
			continue
		out.append(p)
	if out.is_empty():
		for p in _sample_polyline(path, 20.0):
			if p.distance_to(leak_pos) <= 140.0:
				out.append(p)
	return out


func _play_point_covered(p: Vector2) -> bool:
	for op in operators:
		if op == null or not op.visible or not op.alive:
			continue
		if op.in_fire_geometry(p, grid):
			return true
	for tw in tripwires:
		if tw == null or not is_instance_valid(tw):
			continue
		if tw.spent or not tw.armed:
			continue
		if tw.global_position.distance_to(p) <= Tripwire.RADIUS:
			return true
	return false


func _play_leak_uncovered_samples() -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in _play_leak_samples():
		if not _play_point_covered(p):
			out.append(p)
	return out


func leak_cover_ok() -> bool:
	var samples := _play_leak_samples()
	if samples.is_empty():
		return true
	for p in samples:
		if _play_point_covered(p):
			return true
	return false


func _play_refresh_leak_miss() -> void:
	_play_ensure_leak_miss_draw()
	if _leak_miss_draw == null:
		return
	var pts := PackedVector2Array()
	if phase == Phase.SETUP and _play_has_leak_object():
		pts = _play_leak_uncovered_samples()
	if _leak_miss_draw.has_method("set_miss_samples"):
		_leak_miss_draw.call("set_miss_samples", pts)
	_leak_miss_draw.visible = phase == Phase.SETUP and not pts.is_empty()


func _play_ensure_checklist_count(n: int) -> void:
	_ensure_checklist()
	if checklist_strip == null:
		return
	while _checklist_labels.size() < n:
		var lab := Label.new()
		lab.add_theme_font_size_override("font_size", 13)
		lab.add_theme_font_override("font", NightOps.ui_font_bold())
		lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.02, 0.9))
		lab.add_theme_constant_override("shadow_offset_x", 1)
		lab.add_theme_constant_override("shadow_offset_y", 1)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		checklist_strip.add_child(lab)
		_checklist_labels.append(lab)
	while _checklist_labels.size() > n:
		var extra: Label = _checklist_labels.pop_back()
		if extra:
			extra.queue_free()


func _route_polyline_named(route_name: String) -> PackedVector2Array:
	if route_name == "alt":
		if level == null or level.alternate_route_cells.is_empty():
			return PackedVector2Array()
		return _cells_to_world(level.alternate_route_cells)
	if route_world.has(route_name):
		return route_world[route_name]
	return PackedVector2Array()


func _play_distinct_route_samples(route_name: String) -> PackedVector2Array:
	var poly := _route_polyline_named(route_name)
	var out := PackedVector2Array()
	if poly.is_empty():
		return out
	var others: Array = []
	for k in _play_active_route_keys():
		if str(k) == route_name:
			continue
		var other := _route_polyline_named(str(k))
		if not other.is_empty():
			others.append(other)
	if route_name == "alt" and route_world.has("flank"):
		others.append(route_world["flank"])
	for p in _sample_polyline(poly, 20.0):
		var shared := false
		for other in others:
			if _dist_to_polyline(p, other) <= 28.0:
				shared = true
				break
		if not shared:
			out.append(p)
	return out


func _plan_covers_route(route_name: String) -> bool:
	var samples := _play_distinct_route_samples(route_name)
	if samples.is_empty():
		var poly := _route_polyline_named(route_name)
		if poly.is_empty():
			return false
		samples = _sample_polyline(poly, 20.0)
	for p in samples:
		if _play_point_covered(p):
			return true
	return false


func _refresh_checklist() -> void:
	_ensure_checklist()
	if checklist_strip == null:
		return
	var show := phase == Phase.SETUP and level != null
	checklist_strip.visible = show
	if not show:
		_play_refresh_leak_miss()
		return
	var keys := _play_active_route_keys()
	var leak_on := _play_has_leak_object()
	_play_ensure_checklist_count(1 + keys.size() + (1 if leak_on else 0))
	_layout_checklist()
	var deployed := _deployed_count() >= 1
	var compact := _checklist_use_touch_layout()
	var i := 0
	_paint_check_chip(_checklist_labels[i], "部署" if compact else "已部署≥1", deployed, deployed)
	i += 1
	for key in keys:
		var ok := _plan_covers_route(str(key))
		_paint_check_chip(_checklist_labels[i], _play_route_chip_title(str(key), compact), ok, deployed)
		i += 1
	if leak_on and i < _checklist_labels.size():
		var leak_ok := leak_cover_ok()
		_paint_check_chip(
			_checklist_labels[i],
			"漏网" if compact else "漏网已罩住",
			leak_ok,
			true
		)
		if not leak_ok:
			_checklist_labels[i].add_theme_color_override("font_color", Color(0.90, 0.28, 0.22))
	_play_refresh_leak_miss()


func _paint_check_chip(lab: Label, title: String, ok: bool, started: bool) -> void:
	if lab == null:
		return
	var mark := "✓" if ok else ("·" if started else "○")
	lab.text = "%s%s" % [mark, title] if _checklist_use_touch_layout() else "%s  %s" % [mark, title]
	lab.add_theme_font_size_override("font_size", 14 if _checklist_use_touch_layout() else 13)
	var col := Color(0.42, 0.78, 0.40)
	if ok:
		col = Color(0.42, 0.78, 0.40)
	elif started:
		col = Color(0.90, 0.72, 0.28)
	else:
		col = Color(0.82, 0.36, 0.22)
	lab.add_theme_color_override("font_color", col)


func checklist_strip_text() -> String:
	if checklist_strip == null or not checklist_strip.visible:
		return ""
	var bits: PackedStringArray = PackedStringArray()
	for lab in _checklist_labels:
		if lab:
			bits.append(lab.text)
	return " / ".join(bits)


func checklist_visible() -> bool:
	return checklist_strip != null and is_instance_valid(checklist_strip) and checklist_strip.visible


func _refresh_decision_pulse() -> void:
	if decision_marker == null or not is_instance_valid(decision_marker):
		return
	var ring := decision_marker.get_node_or_null("PulseRing") as Line2D
	if ring == null:
		return
	var on := phase == Phase.SETUP and level != null and level.decision_cell.x >= 0 and not _door_taught
	ring.visible = on
	if not on:
		if _decision_pulse_tween != null:
			_decision_pulse_tween.kill()
			_decision_pulse_tween = null
		ring.scale = Vector2.ONE
		return
	if _decision_pulse_tween != null and is_instance_valid(_decision_pulse_tween):
		return
	if _is_power_saving():
		ring.scale = Vector2(1.18, 1.18)
		ring.modulate.a = 0.85
		return
	ring.scale = Vector2.ONE
	ring.modulate.a = 0.95
	_decision_pulse_tween = create_tween().set_loops()
	_decision_pulse_tween.tween_property(ring, "scale", Vector2(1.42, 1.42), 0.55).set_trans(Tween.TRANS_SINE)
	_decision_pulse_tween.parallel().tween_property(ring, "modulate:a", 0.18, 0.55)
	_decision_pulse_tween.tween_property(ring, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)
	_decision_pulse_tween.parallel().tween_property(ring, "modulate:a", 0.95, 0.55)


func decision_pulse_active() -> bool:
	if decision_marker == null or not is_instance_valid(decision_marker):
		return false
	var ring := decision_marker.get_node_or_null("PulseRing") as Line2D
	return ring != null and ring.visible and not _door_taught


func _leak_advice_line() -> String:
	if intel == null or level == null or not intel.has_method("leak_advice_line"):
		return ""
	var route := intel.latest_route() if intel.has_method("latest_route") else ""
	return str(intel.leak_advice_line(level, _route_zh_short(route)))


func _leak_result_line() -> String:
	## Fail-panel one-liner from the recorded leaker, not spawn_schedule[0].
	if intel == null or intel.records.is_empty():
		return ""
	var rec: Dictionary = intel.records[intel.records.size() - 1]
	if str(rec.get("reason", "")) != "escape":
		return ""
	var route := str(rec.get("route", ""))
	var lid := int(rec.get("leaker_id", -1))
	if lid < 1:
		return ""
	var delay := 0.0
	if level != null and level.has_method("delay_for_actor"):
		delay = float(level.delay_for_actor(lid))
	var road := str(PayoffCopy.leak_road_name(level, route, false))
	var wave_n := _wave_fail_index if _wave_fail_index > 0 else (wave_index() + 1)
	if road != "" and road != _route_zh_short(route):
		return "第%d波漏网：%s · 敌%d · %.1fs出发 · %s" % [wave_n, _route_zh_short(route), lid, delay, road]
	return "第%d波漏网：%s · 敌%d · %.1fs出发" % [wave_n, _route_zh_short(route), lid, delay]


func leak_advice_text() -> String:
	return leak_advice_shown


func _second_trap_miss_line() -> String:
	## Fail teaching: the leaked route was the authored second-layer trap.
	if fail_reason != "escape" or level == null or intel == null:
		return ""
	if not level.has_method("second_trap_route"):
		return ""
	var route := str(intel.latest_route()) if intel.has_method("latest_route") else ""
	var trap := str(level.second_trap_route())
	if route == "" or trap == "":
		return ""
	if route != trap:
		return ""
	var text := str(level.second_trap_text()).strip_edges()
	if text == "":
		return "没打中第二层"
	return "没打中第二层：%s" % text


func _build_fail_gap_callout() -> void:
	_clear_fail_gap_callout()
	if fail_reason != "escape" or intel == null:
		return
	var recs: Array = intel.recent(1)
	if recs.is_empty():
		return
	var path: PackedVector2Array = recs[0].get("path", PackedVector2Array())
	if path.is_empty():
		return
	var route := str(recs[0].get("route", ""))
	var zh := _route_zh_short(route)
	var text := "缺口 · %s" % zh
	var col := _intel_flash_color(route)
	fail_gap_callout = _make_map_callout("FailGapCallout", text, path[path.size() - 1] + Vector2(-20, -28), col)


func _clear_fail_gap_callout() -> void:
	if fail_gap_callout != null and is_instance_valid(fail_gap_callout):
		fail_gap_callout.queue_free()
	fail_gap_callout = null


func _cover_vs_leak_line() -> String:
	## Fail teaching: which authored routes the current plan actually covers.
	if level == null:
		return ""
	var covered: PackedStringArray = PackedStringArray()
	var gaps: PackedStringArray = PackedStringArray()
	for key in _play_active_route_keys():
		var zh := _route_zh_short(str(key))
		if _plan_covers_route(str(key)):
			covered.append(zh)
		else:
			gaps.append(zh)
	if covered.is_empty() and gaps.is_empty():
		return ""
	var left := "、".join(covered) if not covered.is_empty() else "无"
	var right := "、".join(gaps) if not gaps.is_empty() else "无"
	return "本世罩住：%s  ·  缺口：%s" % [left, right]


func _refresh_door_visual(animate: bool = false) -> void:
	if door_marker == null or not is_instance_valid(door_marker):
		return
	var pad := door_marker.get_node_or_null("Polygon2D") as Polygon2D
	if pad == null and door_marker.get_child_count() > 0:
		pad = door_marker.get_child(0) as Polygon2D
	var leaf := door_marker.get_node_or_null("DoorLeaf") as Polygon2D
	var panel := door_marker.get_node_or_null("DoorPanel") as Polygon2D
	var handle := door_marker.get_node_or_null("Handle") as Polygon2D
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
			if panel:
				_door_tween.parallel().tween_property(panel, "rotation", target_rot, 0.18)
			if handle:
				_door_tween.parallel().tween_property(handle, "rotation", target_rot, 0.18)
			var flash := Color(1.7, 1.45, 0.55, 1.0) if door_locked else Color(1.35, 1.20, 0.70, 1.0)
			leaf.modulate = flash
			_door_tween.parallel().tween_property(leaf, "modulate", Color.WHITE, 0.28)
			if pad:
				pad.modulate = flash
				_door_tween.parallel().tween_property(pad, "modulate", Color.WHITE, 0.28)
			if tag:
				tag.modulate = flash
				_door_tween.parallel().tween_property(tag, "modulate", Color.WHITE, 0.28)
		else:
			leaf.rotation = target_rot
			if panel:
				panel.rotation = target_rot
			if handle:
				handle.rotation = target_rot
	if door_button:
		door_button.text = "门: 锁闭 (B)" if door_locked else "门: 畅通 (B)"
		door_button.visible = level != null and level.door_cell.x >= 0
		if animate:
			door_button.modulate = Color(1.4, 0.7, 0.4) if door_locked else Color(0.85, 1.2, 0.7)
			var bt := door_button.create_tween()
			bt.tween_property(door_button, "modulate", Color.WHITE, 0.28)


func door_slam_dust_active() -> bool:
	if door_marker == null or not is_instance_valid(door_marker):
		return false
	for c in door_marker.get_children():
		if str(c.name).begins_with("CfxLand"):
			return true
	return false


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
	if raid:
		raid.reset()
	_alarm_warned_no_gun = false
	_alarm_pulled_unarmed = false
	_clear_flash()
	_night_hp_lost = false
	_night_timer = 0.0
	_wave_fail_index = 0
	_watch_first_fire = false
	_watch_first_return = false
	_kill_combo = 0
	_last_kill_tick = -1
	_last_payoff_kind = ""
	_last_payoff_tick = -1
	_barked_last = false
	_clear_payoff_callout()
	_restored_this_setup = false
	plan_restore_hint = ""
	_clear_enemies()
	_clear_tripwires()
	_clear_loot()
	_clear_raid_throwables()
	_clear_stashes()
	_clear_return_fx()
	_clear_tracer_pool()
	if not keep_intel:
		intel_paths.clear()
		intel.clear()
		loop_index = 1
		last_plan.clear()
		door_locked = false
		leak_advice_shown = ""
	if restore_plan and not last_plan.deployments.is_empty():
		_restore_last_plan()
		_wipe_squad_inventory()
	else:
		_clear_deployments()
		_wipe_squad_inventory()
		_place_squad_insert()
		door_locked = last_plan.door_locked if restore_plan else false
	_spawn_level_stashes()
	if level != null and level.door_cell.x >= 0:
		grid.set_door_state(level.door_cell, door_locked)
	_redraw_ghosts()
	_clear_fail_gap_callout()
	if trap_path != null and is_instance_valid(trap_path):
		trap_path.visible = true
		trap_path.modulate.a = 1.0
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
	if result_headline:
		result_headline.visible = false
	if result_stats:
		result_stats.visible = false
		result_stats.text = ""
	if route_timeline:
		route_timeline.visible = false
	if watch_timeline:
		watch_timeline.visible = false
		if watch_timeline.has_method("set_live"):
			watch_timeline.set_live(false)
	_set_watch_view_buttons(false)
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
	if _trap_callout_tween != null:
		_trap_callout_tween.kill()
		_trap_callout_tween = null
	if trap_callout != null and is_instance_valid(trap_callout):
		trap_callout.visible = true
		trap_callout.modulate.a = 1.0
	if intel_label:
		intel_label.add_theme_color_override("font_color", Color(0.75, 0.9, 0.82))
	_update_event_log()
	_build_spawn_ghosts()
	_build_plan_ghosts()
	_update_hud()


func _on_clear_pressed() -> void:
	if not _is_command_phase():
		return
	_clear_deployments()
	status_label.text = "已收回部署（记忆与绊索保留）"
	_build_plan_ghosts()
	_announce_plan_edit()
	_update_hud()


func _clear_deployments() -> void:
	for slot in cover_slots:
		slot.occupied_by = null
		slot.set_highlight(false)
	for op in operators:
		op.fire_mode = OperatorUnit.FireMode.ENGAGE_ON_SIGHT
		op.reset_loadout()
		op.slot = null
		op.visible = true
		op.unlock_plan()
	_place_squad_insert()
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
	_build_plan_ghosts()
	var summary := _plan_summary_text(last_plan)
	plan_restore_hint = "朝向已恢复，枪要重搜 · %s" % summary
	status_label.text = "朝向已恢复，枪要重搜"
	_flash("朝向已恢复，枪要重搜", Color(0.7, 0.92, 0.75))


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


func _clear_death_stains() -> void:
	if entities == null:
		return
	for c in entities.get_children():
		if c != null and str(c.name).begins_with("CfxStain"):
			c.queue_free()


func _clear_enemies() -> void:
	_clear_death_stains()
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
	if not _is_command_phase():
		return
	match tool:
		Tool.DEPLOY:
			tool = Tool.TRIPWIRE
		Tool.TRIPWIRE:
			tool = Tool.GRENADE
		Tool.GRENADE:
			tool = Tool.DECOY
		_:
			tool = Tool.DEPLOY
	match tool:
		Tool.TRIPWIRE:
			tool_button.text = "工具: 地雷"
			status_label.text = "点地埋雷（消耗背包地雷；无雷时仍可铺一条绊索）"
		Tool.GRENADE:
			tool_button.text = "工具: 雷点"
			status_label.text = "点地设雷点，警报中敌人走进圈才自动丢"
		Tool.DECOY:
			tool_button.text = "工具: 诱饵"
			status_label.text = "点地丢诱饵，短暂停住附近敌人"
		_:
			tool_button.text = "工具: 走路/掩体"
			status_label.text = "点地走路，点掩体上垫，走近匣/尸体拾取"
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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I:
		_toggle_backpack()
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
				KEY_J:
					_on_skip_to_outcome_pressed()
				KEY_G:
					pass
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

	if not _is_command_phase():
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
			KEY_D:
				if selected and selected.visible:
					selected.rotate_by(15.0)
					_announce_plan_edit()
					_refresh_killzone_preview()
			KEY_E:
				_try_pickup_near_selected()
			KEY_F:
				_on_mode_pressed()
			KEY_G:
				_place_nade_mark()
			KEY_B:
				_on_door_pressed()
			KEY_V:
				_throw_decoy_at_cursor()
			KEY_TAB:
				_toggle_tool()
			KEY_T:
				_transfer_selected_to_nearest()
			KEY_H:
				_toggle_haul_corpse()
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
		if phase == Phase.SETUP:
			_pending_touch_world = _screen_to_world(sd.position)
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
		if phase == Phase.SETUP and tool == Tool.TRIPWIRE:
			_touch_dragged = true
			_cover_hold_slot = null
			_update_tripwire_ghost()
			return true
		if (phase == Phase.SETUP or phase == Phase.WATCHING) and sd.relative.length() >= 8.0:
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
	if _is_command_phase():
		_sfx("ui")
	if not _is_command_phase():
		return
	tool = Tool.DEPLOY
	tool_button.text = "工具: 走路/掩体"
	_refresh_mode_pack_buttons()
	status_label.text = "已选择 %s — %s" % [selected.display_name, selected.kit_blurb()]
	_update_cover_previews()
	_refresh_killzone_preview()
	_refresh_backpack_if_open()
	_update_hud()


func _refresh_selection_visual() -> void:
	for op in operators:
		if op.has_method("set_selected_visual"):
			op.set_selected_visual(op == selected and op.visible)
		if op.body:
			# Selection is the ring / cone, not a gold fill that hides kit color.
			op.body.color = op.body_color if op.alive else Color(0.25, 0.28, 0.32)


func _refresh_mode_pack_buttons() -> void:
	if mode_button and selected:
		mode_button.text = "开火: %s (F)" % selected.fire_mode_label()
	if pack_button:
		pack_button.visible = level != null and level.has_ammo_pack
		if selected and selected.has_ammo_pack:
			pack_button.text = "弹包: %s" % selected.display_name
		else:
			pack_button.text = "弹包分配"


func _handle_setup_click(world_pos: Vector2) -> void:
	if tool == Tool.TRIPWIRE:
		_try_place_inventory_mine(world_pos)
		return
	if tool == Tool.GRENADE:
		_place_nade_mark(world_pos)
		return
	if tool == Tool.DECOY:
		_throw_decoy_at(world_pos)
		return
	for op in operators:
		if op.visible and op.alive and op.global_position.distance_to(world_pos) <= 22.0:
			selected = op
			_refresh_selection_visual()
			_refresh_mode_pack_buttons()
			status_label.text = "已选择 %s — %s" % [op.display_name, op.kit_blurb()]
			_update_cover_previews()
			_refresh_killzone_preview()
			_update_hud()
			return
	var slot := _nearest_slot(world_pos, 28.0)
	if slot:
		_deploy_selected_to(slot, true)
		return
	_command_move_selected(world_pos)


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
	var had_cover := selected.visible and selected.slot != null
	var keep_deg := selected.facing_deg
	var same_pad := selected.slot == slot
	var prev_slot: CoverSlot = selected.slot
	if selected.slot:
		selected.slot.occupied_by = null
		selected.slot.set_highlight(false)
	if slot.occupied_by and slot.occupied_by != selected:
		var other: OperatorUnit = slot.occupied_by
		if prev_slot != null and prev_slot != slot:
			other.slot = prev_slot
			prev_slot.occupied_by = other
			other.global_position = prev_slot.global_position
			other.visible = true
			prev_slot.set_highlight(true)
		else:
			other.slot = null
			other.visible = false
			other.position = Vector2(-1000, -1000)
	slot.occupied_by = selected
	slot.set_highlight(true)
	selected.slot = slot
	selected.visible = true
	selected.stop_move()
	selected.global_position = slot.global_position
	var face := float(slot.get_meta("default_face"))
	if not selected.alive:
		selected.reset_loadout()
	# Re-click or pad-to-pad move keeps the aim the player already set.
	# First drop onto a pad still uses the authored default face.
	# Player double-tap (announce) faces the next authored route. Smoke uses announce=false.
	if same_pad and announce:
		selected.set_facing(_facing_toward_wave_route())
	elif had_cover:
		selected.set_facing(keep_deg)
	else:
		selected.set_facing(face)
	if selected.has_method("play_land_pop") and not same_pad:
		selected.play_land_pop()
	CombatFxScript.select_ping(selected, selected.global_position)
	_refresh_selection_visual()
	_refresh_mode_pack_buttons()
	_update_cover_previews()
	if announce:
		var prot := slot.protect_compass()
		var fire_dir := _compass_deg(selected.facing_deg)
		status_label.text = "%s · 射界朝%s · 保护朝%s" % [
			selected.display_name, fire_dir, prot
		]
		_announce_plan_edit()
	_update_observation_rings()
	_refresh_killzone_preview()
	_build_plan_ghosts()
	_update_hud()


func _try_place_tripwire(world_pos: Vector2) -> void:
	if not _near_any_route_segment(world_pos, TRIPWIRE_ROUTE_DIST):
		status_label.text = "绊索只能布在路线线段附近"
		return
	if tripwires.size() >= MAX_TRIPWIRES:
		var existing: Tripwire = tripwires[0]
		if existing == null or not is_instance_valid(existing):
			tripwires.clear()
		else:
			existing.global_position = world_pos
			existing.armed = true
			existing.spent = false
			status_label.text = "绊索已改位（限额仍为 1）"
			_announce_plan_edit()
			_update_hud()
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
	wire.default_color = Color(0.42, 0.36, 0.18, 0.92)
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
	_build_barrel_hint(b.position)


func _trap_callout_pos() -> Vector2:
	if level == null:
		return Vector2.ZERO
	match level.beat_kind:
		"barrel":
			return grid.cell_to_world_center(level.barrel_cell) + Vector2(8, -18)
		"decision":
			return grid.cell_to_world_center(level.decision_cell) + Vector2(14, 18)
		"flank_delay":
			return grid.cell_to_world_center(Vector2i(32, 11)) + Vector2(-10, -22)
		"sneak_delay":
			return grid.cell_to_world_center(Vector2i(7, 11)) + Vector2(12, -22)
		"radio_echo":
			return grid.cell_to_world_center(Vector2i(7, 11)) + Vector2(12, -22)
		_:
			if level.ambush_zone.size != Vector2.ZERO:
				return level.ambush_zone.get_center() + Vector2(-40, -8)
			return escape_world


func _trap_callout_text() -> String:
	if level == null:
		return ""
	if level.beat_text != "":
		return level.beat_text
	if not level.spawn_teaching.is_empty():
		return str(level.spawn_teaching[0])
	return ""


func _make_map_callout(p_name: String, text: String, pos: Vector2, col: Color) -> Node2D:
	var n := Node2D.new()
	n.name = p_name
	n.position = pos
	n.z_index = 8
	var plate := Polygon2D.new()
	plate.name = "Plate"
	var pw := clampf(20.0 + float(text.length()) * 15.0, 140.0, 400.0)
	plate.polygon = PackedVector2Array([
		Vector2(-8, -6), Vector2(pw, -6), Vector2(pw, 22), Vector2(-8, 22)
	])
	plate.color = Color(0.06, 0.07, 0.04, 0.72)
	n.add_child(plate)
	var lab := Label.new()
	lab.name = "Tag"
	lab.text = text
	lab.position = Vector2(-4, -4)
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_font_override("font", NightOps.ui_font_bold())
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.94))
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(lab)
	$World.add_child(n)
	return n


func _build_trap_callout() -> void:
	## Beat plate used to reprint tut/spawn-teach. Keep the node off; timeline + dashed path teach.
	if trap_callout != null and is_instance_valid(trap_callout):
		trap_callout.queue_free()
	trap_callout = null


func _build_second_callout() -> void:
	## Duplicate of trap_path Tag. Dashed second-layer path keeps the one map label.
	if second_callout != null and is_instance_valid(second_callout):
		second_callout.queue_free()
	second_callout = null


func _clear_echo_callout() -> void:
	if echo_callout != null and is_instance_valid(echo_callout):
		echo_callout.queue_free()
	echo_callout = null


func _build_echo_callout() -> void:
	_clear_echo_callout()
	if level == null or str(level.level_id) != "radio":
		return
	if not level.route_cells.has("echo"):
		return
	var pos := grid.cell_to_world_center(Vector2i(24, 12)) + Vector2(8, -22)
	echo_callout = _make_map_callout("EchoCallout", "回波 5.2s", pos, Color(0.72, 0.58, 0.28))


func echo_callout_visible() -> bool:
	return echo_callout != null and is_instance_valid(echo_callout) and echo_callout.visible


func _fade_trap_callout() -> void:
	if trap_callout == null or not is_instance_valid(trap_callout):
		return
	if _trap_callout_tween != null:
		_trap_callout_tween.kill()
	_trap_callout_tween = trap_callout.create_tween()
	_trap_callout_tween.tween_property(trap_callout, "modulate:a", 0.0, 0.28)
	_trap_callout_tween.tween_callback(func() -> void:
		if trap_callout != null and is_instance_valid(trap_callout):
			trap_callout.visible = false
	)


func _fade_second_callout() -> void:
	if second_callout == null or not is_instance_valid(second_callout):
		return
	if _second_callout_tween != null:
		_second_callout_tween.kill()
	_second_callout_tween = second_callout.create_tween()
	_second_callout_tween.tween_property(second_callout, "modulate:a", 0.0, 0.28)
	_second_callout_tween.tween_callback(func() -> void:
		if second_callout != null and is_instance_valid(second_callout):
			second_callout.visible = false
	)


func _fade_echo_callout() -> void:
	if echo_callout == null or not is_instance_valid(echo_callout):
		return
	echo_callout.visible = false


func _build_trap_path() -> void:
	if trap_path != null and is_instance_valid(trap_path):
		trap_path.queue_free()
	trap_path = null
	if level == null or not level.has_method("second_trap_route"):
		return
	var route := str(level.second_trap_route())
	var poly := _route_polyline_named(route)
	if poly.size() < 2:
		return
	var col := Color(1.0, 0.72, 0.38, 0.90)
	if route == "sneak":
		col = Color(0.68, 0.42, 0.92, 0.90)
	elif route == "echo":
		col = Color(0.70, 0.56, 0.28, 0.90)
	elif route == "alt":
		col = Color(0.78, 0.55, 1.0, 0.90)
	var fx: Node2D = TrapPathFxScript.new()
	var tag := str(level.second_trap_text()).strip_edges()
	if tag == "":
		tag = "第二层陷阱"
	var tag_at := Vector2.ZERO
	if level.has_method("second_trap_cell"):
		tag_at = grid.cell_to_world_center(level.second_trap_cell())
	fx.setup(poly, col, tag, tag_at)
	var world := get_node_or_null("World")
	if world:
		world.add_child(fx)
	else:
		add_child(fx)
	trap_path = fx


func _fade_trap_path() -> void:
	if trap_path == null or not is_instance_valid(trap_path):
		return
	trap_path.visible = false


func trap_path_visible() -> bool:
	return trap_path != null and is_instance_valid(trap_path) and trap_path.visible


func _clear_spawn_ghosts() -> void:
	if spawn_ghost_host != null and is_instance_valid(spawn_ghost_host):
		spawn_ghost_host.queue_free()
	spawn_ghost_host = null


func _build_spawn_ghosts() -> void:
	_clear_spawn_ghosts()
	if level == null or grid == null:
		return
	var world := get_node_or_null("World") as Node2D
	if world == null:
		return
	var host := Node2D.new()
	host.name = "SpawnGhosts"
	host.z_index = 6
	world.add_child(host)
	spawn_ghost_host = host
	var occupied: Dictionary = {}
	var specs: Array = []
	if raid != null and level.has_method("spawns_for_wave"):
		specs.append_array(raid.current_spawns(level))
		if not raid.is_last_wave(level):
			specs.append_array(level.spawns_for_wave(raid.wave_index + 1))
	if specs.is_empty():
		specs = level.spawn_schedule
	for spec in specs:
		var route := str(spec.get("route", "main"))
		var cells: Array = level.route_cells.get(route, [])
		if cells.is_empty():
			continue
		var cell: Vector2i = cells[0]
		var key := "%d,%d" % [cell.x, cell.y]
		var stack := int(occupied.get(key, 0))
		occupied[key] = stack + 1
		var pos := grid.cell_to_world_center(cell)
		var g = SpawnGhostScript.new()
		g.setup(
			int(spec.get("id", 0)),
			route,
			float(spec.get("delay", 0.0)),
			str(spec.get("teaching_note", ""))
		)
		g.position = pos + Vector2(-28.0, -12.0 + float(stack) * 16.0)
		host.add_child(g)
	host.visible = phase == Phase.SETUP or phase == Phase.SWEEP


func setup_spawn_ghosts_visible() -> bool:
	return (
		phase == Phase.SETUP
		and spawn_ghost_host != null
		and is_instance_valid(spawn_ghost_host)
		and spawn_ghost_host.visible
		and spawn_ghost_host.get_child_count() >= 1
	)


func setup_spawn_ghost_count() -> int:
	if spawn_ghost_host == null or not is_instance_valid(spawn_ghost_host):
		return 0
	return spawn_ghost_host.get_child_count()


func _clear_plan_ghosts() -> void:
	if plan_ghost_host != null and is_instance_valid(plan_ghost_host):
		plan_ghost_host.queue_free()
	plan_ghost_host = null


func _build_plan_ghosts() -> void:
	_clear_plan_ghosts()
	if last_plan == null or last_plan.deployments.is_empty():
		return
	if phase != Phase.SETUP:
		return
	var world := get_node_or_null("World") as Node2D
	if world == null:
		return
	var host := Node2D.new()
	host.name = "PlanGhosts"
	host.z_index = 5
	world.add_child(host)
	plan_ghost_host = host
	for entry in last_plan.deployments:
		var slot := _slot_by_id(int(entry.get("slot_id", -1)))
		var op := _op_by_id(int(entry.get("op_id", -1)))
		if slot == null:
			continue
		if op != null and op.visible and op.slot == slot:
			continue
		var n := Node2D.new()
		n.name = "PlanGhost%d" % int(entry.get("op_id", 0))
		n.position = slot.global_position
		var poly := Polygon2D.new()
		poly.name = "Sil"
		poly.polygon = PackedVector2Array([
			Vector2(0, -11), Vector2(7, 8), Vector2(-7, 8)
		])
		var col := op.body_color if op != null else Color(0.55, 0.72, 0.42)
		poly.color = Color(col.r, col.g, col.b, 0.32)
		n.add_child(poly)
		var lab := Label.new()
		lab.name = "Tag"
		lab.text = "上轮·%s" % (op.display_name if op else "队员")
		lab.position = Vector2(-22, -24)
		lab.add_theme_font_size_override("font_size", 10)
		lab.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.85))
		lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.9))
		lab.add_theme_constant_override("shadow_offset_x", 1)
		lab.add_theme_constant_override("shadow_offset_y", 1)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.add_child(lab)
		host.add_child(n)
	host.visible = phase == Phase.SETUP


func plan_ghost_count() -> int:
	if plan_ghost_host == null or not is_instance_valid(plan_ghost_host):
		return 0
	return plan_ghost_host.get_child_count()


func _intel_flash_color(route: String) -> Color:
	## Leaked-route flash: main=red, flank=orange, sneak=purple.
	match route:
		"flank":
			return Color(0.98, 0.58, 0.16)
		"sneak":
			return Color(0.68, 0.32, 0.92)
		"echo":
			return Color(0.70, 0.58, 0.32)
		"main":
			return Color(0.95, 0.28, 0.22)
		_:
			return Color(0.62, 0.54, 0.32)


func _refresh_spawn_teach() -> void:
	if spawn_teach_label == null:
		return
	## One teaching line. Tutorial overlay + dashed trap path cover the rest.
	var text := ""
	if phase == Phase.SETUP and level != null:
		text = str(level.beat_text).strip_edges()
		if text == "" and not level.spawn_teaching.is_empty():
			text = str(level.spawn_teaching[0]).strip_edges()
	spawn_teach_label.visible = text != ""
	spawn_teach_label.text = text
	_refresh_intel_chip()


func _ensure_intel_chip() -> void:
	if intel_chip != null and is_instance_valid(intel_chip):
		return
	var root: Control = get_node_or_null("HUD/Root") as Control
	if root == null:
		return
	var lab := Label.new()
	lab.name = "IntelChip"
	lab.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lab.offset_left = 220.0
	lab.offset_top = 146.0
	lab.offset_right = -16.0
	lab.offset_bottom = 168.0
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.clip_text = true
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_font_override("font", NightOps.ui_font_bold())
	lab.add_theme_color_override("font_color", Color(0.78, 0.70, 0.48))
	lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.92))
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lab)
	intel_chip = lab


func _clip_chip_line(text: String, max_chars: int = 28) -> String:
	var t := text.strip_edges()
	if t.length() <= max_chars:
		return t
	return t.substr(0, max_chars - 1) + "…"


func _refresh_intel_chip() -> void:
	_ensure_intel_chip()
	if intel_chip == null:
		return
	var line := ""
	if phase == Phase.SETUP:
		if leak_advice_shown != "":
			line = _clip_chip_line(leak_advice_shown, 28)
		elif plan_restore_hint != "":
			line = _clip_chip_line(plan_restore_hint, 28)
		else:
			var named := PackedStringArray()
			for k in named_crate_ids():
				named.append(WeaponCatalogScript.display_name(k))
			var named_bit := ("  " + "·".join(named)) if not named.is_empty() else ""
			line = _clip_chip_line("匣%d 枪%s%s  %s" % [
				stash_count(),
				"有" if squad_has_firearm() else "无",
				named_bit,
				_raid_clock_text(),
			], 48)
	elif phase == Phase.SWEEP:
		line = _clip_chip_line("掉落%d  空格%s" % [living_loot_count(), "撤离" if raid and raid.is_last_wave(level) else "下一波"], 32)
	intel_chip.visible = line != "" and (phase == Phase.SETUP or phase == Phase.SWEEP)
	intel_chip.text = line
	if _want_touch():
		intel_chip.offset_top = 142.0
		intel_chip.offset_bottom = 164.0
	else:
		intel_chip.offset_top = 146.0
		intel_chip.offset_bottom = 168.0


func intel_chip_text() -> String:
	if intel_chip == null or not is_instance_valid(intel_chip) or not intel_chip.visible:
		return ""
	return str(intel_chip.text)


func intel_chip_overlaps_timeline() -> bool:
	if intel_chip == null or not intel_chip.visible or watch_timeline == null:
		return false
	if not is_instance_valid(intel_chip) or not is_instance_valid(watch_timeline):
		return false
	return intel_chip.get_global_rect().intersects(watch_timeline.get_global_rect())


func setup_teaching_layers() -> Dictionary:
	## Playable-bar probe: at most one HUD teaching paragraph during SETUP.
	return {
		"tut": tut_label != null and tut_label.visible,
		"spawn": spawn_teach_label != null and spawn_teach_label.visible,
		"beat": trap_callout != null and is_instance_valid(trap_callout) and trap_callout.visible,
		"second": second_callout != null and is_instance_valid(second_callout) and second_callout.visible,
		"path": trap_path_visible(),
	}


func _build_barrel_hint(pos: Vector2) -> void:
	if barrel_hint != null and is_instance_valid(barrel_hint):
		barrel_hint.queue_free()
	barrel_hint = null
	if level == null or level.beat_kind != "barrel":
		return
	var n := Node2D.new()
	n.name = "BarrelHint"
	n.position = pos
	n.z_index = 3
	var tag := Label.new()
	tag.text = "爆心"
	tag.position = Vector2(-52, -36)
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_font_override("font", NightOps.ui_font_bold())
	tag.add_theme_color_override("font_color", Color(1.0, 0.62, 0.22))
	tag.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.02, 0.92))
	tag.add_theme_constant_override("shadow_offset_x", 1)
	tag.add_theme_constant_override("shadow_offset_y", 1)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(tag)
	$World.add_child(n)
	barrel_hint = n


func _clear_barrels() -> void:
	for b in barrels:
		if is_instance_valid(b):
			b.queue_free()
	barrels.clear()
	if barrel_hint != null and is_instance_valid(barrel_hint):
		barrel_hint.queue_free()
	barrel_hint = null


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
	var hits := 0
	for e in enemies:
		if e != null and is_instance_valid(e) and e.alive:
			if e.global_position.distance_to(barrel.global_position) <= ExplosiveBarrel.BLAST_RADIUS:
				hits += 1
	if phase == Phase.WATCHING or pending_result != "":
		battle_log.add_event(sim.tick, "barrel", -1, -1, barrel.global_position, {"hits": hits})
	if hits > 0:
		_announce_payoff("barrel", {"hits": hits}, barrel.global_position)
	else:
		_flash("油桶爆炸", Color(1.0, 0.45, 0.2))
	_sfx("barrel")
	_shake_for_explosion(barrel.global_position)
	_update_event_log()


func _deployed_count() -> int:
	var n := 0
	for op in operators:
		if op.visible and op.slot != null:
			n += 1
	return n


func _play_hold_pack(op_index: int) -> void:
	if phase != Phase.SETUP:
		return
	if op_index < 0 or op_index >= operators.size():
		return
	_select_op(op_index)
	if selected == null or not selected.visible:
		return
	if selected.fire_mode != OperatorUnit.FireMode.HOLD_FOR_AMBUSH:
		_on_mode_pressed()
	if level != null and level.has_ammo_pack and not selected.has_ammo_pack:
		_on_pack_pressed()


func _on_mode_pressed() -> void:
	if not _is_command_phase() or selected == null or not selected.visible:
		return
	selected.cycle_fire_mode()
	_refresh_mode_pack_buttons()
	status_label.text = "%s 开火模式：%s" % [selected.display_name, selected.fire_mode_label()]
	if selected.fire_mode == OperatorUnit.FireMode.HOLD_FOR_AMBUSH:
		_announce_payoff("hold_mode", {"name": selected.display_name}, selected.global_position)
	_announce_plan_edit()
	_refresh_killzone_preview()
	_update_hud()


func _on_pack_pressed() -> void:
	if not _is_command_phase() or level == null or not level.has_ammo_pack:
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
		if selected.role == OperatorUnit.Role.MG:
			_announce_payoff("pack_mg", {}, selected.global_position)
		else:
			_announce_payoff("pack_other", {"name": selected.display_name}, selected.global_position)
	_refresh_mode_pack_buttons()
	_announce_plan_edit()
	_update_hud()


func _on_door_pressed() -> void:
	if not _is_command_phase() or level == null or level.door_cell.x < 0:
		return
	door_locked = not door_locked
	_door_taught = true
	grid.set_door_state(level.door_cell, door_locked)
	if map_draw.has_method("invalidate_static_cache"):
		map_draw.invalidate_static_cache()
	map_draw.queue_redraw()
	_sfx("door")
	_refresh_door_visual(true)
	if door_marker != null and is_instance_valid(door_marker) and not _is_power_saving():
		CombatFxScript.land_dust(door_marker, door_marker.global_position)
		if door_locked:
			_camera_punch(Vector2(2.2, -1.4))
	for op in operators:
		if op.visible:
			op._rebuild_cone()
	_update_cover_previews()
	status_label.text = "门已锁闭 — 侧翼改走备用接近" if door_locked else "门保持畅通"
	if door_locked:
		_flash("锁门后紫线会改道 — 把青弧转过去", Color(0.78, 0.55, 1.0))
	_announce_plan_edit()
	_refresh_killzone_preview()
	_update_hud()


func _on_speed_pressed() -> void:
	if phase != Phase.WATCHING:
		return
	sim.set_speed(1.0 if sim.speed >= 1.5 else 2.0)
	if speed_button:
		speed_button.text = "速度 2×" if sim.speed >= 1.5 else "速度 1×"
	_refresh_phase_chip()
	_refresh_touch_hud()


func _on_pause_pressed() -> void:
	if phase != Phase.WATCHING:
		return
	sim.toggle_pause()
	if pause_button:
		pause_button.text = "继续" if sim.paused else "暂停"
	_refresh_phase_chip()
	_refresh_touch_hud()


func alarm_leak_warning() -> String:
	if not has_method("leak_cover_ok") or leak_cover_ok():
		return ""
	return "漏网还没罩住 — 拉警报会穿梭"


func raid_force_alarm() -> void:
	## Headless / skip-gate: treat the soft firearm warning as already shown.
	_alarm_warned_no_gun = true
	_on_alarm_pressed()


func _on_alarm_pressed() -> void:
	if phase == Phase.SWEEP:
		_on_sweep_commit()
		return
	if phase != Phase.SETUP:
		return
	if _living_ops() < 1:
		status_label.text = "没有能作战的队员"
		return
	if not squad_has_firearm():
		if not _alarm_warned_no_gun:
			_alarm_warned_no_gun = true
			var warn := "至少先拾一把枪 — 再按一次才强拉警报"
			_flash(warn, Color(1.0, 0.62, 0.28))
			if status_label:
				status_label.text = warn
			_sfx("ui")
			_refresh_alarm_cta()
			return
	var leak_warn := alarm_leak_warning()
	if leak_warn != "":
		_flash(leak_warn, Color(1.0, 0.55, 0.28))
		if status_label:
			status_label.text = leak_warn
	_alarm_pulled_unarmed = not squad_has_firearm()
	_capture_plan()
	frozen_plan = last_plan.duplicate_plan()
	run_id += 1
	var this_run := run_id
	phase = Phase.WATCHING
	leak_advice_shown = ""
	_clear_intel_path_ghost()
	sim.reset()
	battle_log.clear()
	_watch_first_fire = false
	_watch_first_return = false
	_kill_combo = 0
	_last_kill_tick = -1
	_last_payoff_kind = ""
	_last_payoff_tick = -1
	_barked_last = false
	_clear_payoff_callout()
	_sfx("alarm")
	_alarm_edge_flash()
	_alarm_cam_stinger()
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
	for s in cover_slots:
		if s != null and is_instance_valid(s) and s.has_method("set_hold_progress"):
			s.set_hold_progress(0.0)
	_update_cover_previews()
	_refresh_killzone_preview()
	_update_tripwire_ghost()
	battle_log.add_event(0, "door", -1, -1, Vector2.ZERO, {"locked": door_locked})
	_queue_spawns(this_run)
	_set_watch_view_buttons(true)
	if pause_button:
		pause_button.disabled = false
	if speed_button:
		speed_button.disabled = false
	_wave_tension_id = -1
	status_label.text = "警报 · 第%d波 — 埋伏开火。逃逸或全灭失败。中止(X)留情报。" % (raid.wave_index + 1 if raid else 1)
	_fade_trap_callout()
	_fade_second_callout()
	_fade_echo_callout()
	_fade_trap_path()
	_update_event_log()
	_refresh_watch_timeline()
	_update_hud()


func _queue_spawns(_this_run: int) -> void:
	_clear_enemies()
	pending_spawns.clear()
	all_spawns_done = false
	var specs: Array = raid.current_spawns(level) if raid else level.spawn_schedule
	for spec in specs:
		pending_spawns.append({
			"id": int(spec["id"]),
			"route": str(spec["route"]),
			"delay": float(spec["delay"]),
			"loot": int(spec.get("loot", 0)),
			"kit": str(spec.get("kit", "")),
			"teaching_note": str(spec.get("teaching_note", "")),
			"spawned": false,
		})


func queued_kit_for(id: int) -> String:
	for spec in pending_spawns:
		if int(spec.get("id", -1)) == id:
			return str(spec.get("kit", "")).strip_edges()
	if level != null and level.has_method("kit_for_actor"):
		return str(level.kit_for_actor(id))
	return ""


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
	if str(spec.get("kit", "")).strip_edges() == "echo" and e.has_method("mark_echo_kit"):
		e.mark_echo_kit(true)
	e.return_fired.connect(_on_return_fired)
	enemies.append(e)
	e.activate()
	if e.has_method("play_spawn_pop"):
		e.play_spawn_pop()
	var kit := str(spec.get("kit", "")).strip_edges()
	var note := str(spec.get("teaching_note", "")).strip_edges()
	battle_log.add_event(
		sim.tick,
		"spawn",
		e.label_id,
		-1,
		e.global_position,
		{"route": route_name, "kit": kit, "note": note}
	)
	var delay := float(spec.get("delay", 0.0))
	if kit == "echo":
		_sfx("echo_ping")
		_announce_payoff("echo", {"enemy_id": e.label_id, "name": "灯塔回波"}, e.global_position)
	elif delay >= 1.5:
		_sfx("spawn")
		_announce_payoff(
			"wave",
			{"enemy_id": e.label_id, "route": route_name, "note": note},
			e.global_position
		)
		if not _is_power_saving():
			_camera_punch(Vector2(3.6, -2.4))
			_flash_spawn_cell(e.global_position)
	_update_event_log()


func _flash_spawn_cell(pos: Vector2) -> void:
	if entities == null or _is_power_saving():
		return
	var n := Node2D.new()
	n.name = "SpawnFlash"
	n.z_index = 9
	entities.add_child(n)
	n.global_position = pos
	var ring := Line2D.new()
	ring.width = 2.4
	ring.closed = true
	ring.default_color = Color(1.0, 0.78, 0.32, 0.92)
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a), sin(a)) * 12.0)
	if pts.size() > 0:
		pts.append(pts[0])
	ring.points = pts
	n.add_child(ring)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(2.4, 2.4), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.22)
	tw.tween_callback(n.queue_free)


func spawn_flash_api() -> bool:
	return has_method("_flash_spawn_cell")


func _make_enemy(id: int) -> EnemyRunner:
	var e := EnemyRunner.new()
	var outline := Polygon2D.new()
	outline.name = "BodyOutline"
	outline.color = Color(0.18, 0.04, 0.04, 0.95)
	e.add_child(outline)
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = EnemySilhouetteScript.body_poly("main")
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
	var rim := Line2D.new()
	rim.name = "KindRim"
	rim.closed = true
	rim.width = 2.8
	rim.z_index = 0
	e.add_child(rim)
	e.escaped.connect(_on_enemy_escaped)
	e.died.connect(_on_enemy_died)
	return e


func _spawn_loot_at(pos: Vector2, amount: int, kind: String = "ammo") -> void:
	if amount <= 0 and kind == "ammo":
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
	loot.setup(amount, kind)
	loot_piles.append(loot)


func _on_return_fired(from: EnemyRunner, to: OperatorUnit) -> void:
	# Called before damage is applied so terminal summaries include the shot.
	if phase == Phase.WATCHING or pending_result != "":
		battle_log.add_event(sim.tick, "return_fire", from.label_id, to.op_id, from.global_position)
	_sfx("return_fire")
	_night_hp_lost = true
	if not _watch_first_return:
		_watch_first_return = true
	_spawn_watch_tracer(from.global_position, to.global_position, Color(1.0, 0.58, 0.22, 0.94), 2.4)
	_update_event_log()


func _process(delta: float) -> void:
	if phase == Phase.SETUP or phase == Phase.WATCHING or phase == Phase.SWEEP:
		_night_timer += delta
	if _is_command_phase():
		_tick_cover_long_press()
		_tick_cover_hold_ring()
		_update_cover_previews()
		_update_tripwire_ghost()
		_tick_hold_to_move(delta)
		_tick_command_moves(delta)
		_tick_command_pickups(delta)
		_tick_raid_grenades(delta)
		_tick_raid_decoys(delta)
		_tick_footsteps(delta)
		hud_tick += delta
		if hud_tick >= 0.20:
			hud_tick = 0.0
			_update_hud()
		return
	if phase != Phase.WATCHING:
		return
	var steps := sim.steps_for_frame(delta)
	for _i in steps:
		if phase != Phase.WATCHING:
			break
		_sim_tick()
	hud_tick += delta
	_tick_last_enemy_highlight()
	_tick_pending_wave_tension()
	_refresh_phase_chip()
	if hud_tick >= 0.20:
		hud_tick = 0.0
		_update_hud()
	else:
		_update_role_cards()
		_refresh_watch_timeline()


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

	# 4) Enemy move — branch at decision. Mouth escape is resolved after every
	#    runner has stepped so spawn-order cannot beat the first body at the cell.
	for enemy in enemies:
		if enemy.alive and enemy.active:
			_try_enemy_branch(enemy)
			enemy.sim_step(SimClock.TICK_DT)
			_try_enemy_branch(enemy)
		if phase != Phase.WATCHING:
			_finish_sim_tick()
			return

	# 4b) First alive runner at escape_cell wins; others stay disabled via the handler.
	if phase == Phase.WATCHING:
		_resolve_escapes()
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
					_announce_payoff("trip", {"enemy_id": victim.label_id}, tw.global_position)
					_sfx("trip")
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
			if not op.visible or not op.alive:
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
				battle_log.add_event(
					sim.tick, "fire", op.op_id, best.label_id, op.global_position,
					{"name": op.display_name, "role": op.role_short, "codename": op.display_name}
				)
				if op.try_fire(best, grid):
					_sfx_every_shot(op)
					if not _watch_first_fire:
						_watch_first_fire = true
						_announce_payoff(
							"first_fire",
							{"name": op.display_name, "enemy_id": best.label_id},
							op.global_position
						)
						_operator_bark(op, "contact")
					if op.ammo <= 0:
						battle_log.add_event(sim.tick, "empty", op.op_id)
					_update_event_log()
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

	# 8) Loot stays on the ground during ALERT. Sweep/scout walk-collect.
	if phase == Phase.WATCHING:
		_tick_auto_grenades(SimClock.TICK_DT)
		_tick_raid_mines()
		_tick_raid_grenades(SimClock.TICK_DT)
		_tick_raid_decoys(SimClock.TICK_DT)

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
		var covered := _plan_covers_route("alt")
		battle_log.add_event(
			sim.tick, "route_choice", enemy.label_id, -1, enemy.global_position,
			{"covered": covered}
		)
		_announce_payoff("route_choice", {"covered": covered, "enemy_id": enemy.label_id}, enemy.global_position)
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


func _aim_world() -> Vector2:
	if phase == Phase.SETUP and not _touches.is_empty() and _pending_touch_world != Vector2.ZERO:
		return _pending_touch_world
	return get_global_mouse_position()


func _update_tripwire_ghost() -> void:
	_ensure_tripwire_ghost()
	if (phase != Phase.SETUP and phase != Phase.SWEEP) or tool != Tool.TRIPWIRE:
		tripwire_ghost.visible = false
		return
	tripwire_ghost.visible = true
	var pos := _aim_world()
	tripwire_ghost.global_position = pos
	var inv_mine := selected != null and int(selected.mines) > 0
	var ok := inv_mine or _near_any_route_segment(pos, TRIPWIRE_ROUTE_DIST)
	var vis := tripwire_ghost.get_node_or_null("Visual") as Polygon2D
	if vis:
		vis.color = Color(0.42, 0.95, 0.52, 0.88) if ok else Color(0.92, 0.22, 0.2, 0.85)
	var tag := tripwire_ghost.get_node_or_null("Tag") as Label
	if tag:
		tag.text = "埋雷" if inv_mine else "绊索"
		tag.add_theme_color_override("font_color", Color(0.5, 0.95, 0.5) if ok else Color(0.95, 0.4, 0.3))


func _tick_ambush_zone() -> void:
	if level.ambush_zone.size == Vector2.ZERO:
		return
	var any_in := false
	for enemy in enemies:
		if enemy.alive and enemy.active and level.ambush_zone.has_point(enemy.global_position):
			any_in = true
			break
	if ambush_zone_poly != null and is_instance_valid(ambush_zone_poly) and ambush_zone_poly.has_method("set_hot"):
		ambush_zone_poly.set_hot(any_in)
	if not any_in:
		return
	for op in operators:
		if not op.visible or not op.alive:
			continue
		if op.fire_mode == OperatorUnit.FireMode.HOLD_FOR_AMBUSH and not op.fire_permitted:
			op.arm_ambush()
			battle_log.add_event(sim.tick, "ambush_armed", op.op_id, -1, op.global_position, {"name": op.display_name})
			_announce_payoff("ambush", {"name": op.display_name}, op.global_position)


func _snapshot_data() -> Dictionary:
	var ops := []
	for op in operators:
		if op.visible:
			ops.append({
				"id": op.op_id,
				"hp": op.hp,
				"ammo": op.ammo,
				"alive": op.alive,
				"pos": op.global_position,
				"facing": op.facing_deg,
				"role": op.role,
			})
	var ens := []
	for e in enemies:
		ens.append({
			"id": e.label_id,
			"hp": e.hp,
			"alive": e.alive,
			"pos": e.global_position,
			"route": e.spawn_route,
		})
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
		var item: Dictionary = {"kind": loot.kind, "amount": loot.ammo_amount}
		if op.has_method("pack_can_fit") and not op.pack_can_fit(str(item.get("kind", "ammo")), int(item.get("amount", 1))):
			continue
		var loot_pos := loot.global_position
		var taken := loot.collect_item()
		if taken.is_empty():
			continue
		var rec: Dictionary = op.receive_item(str(item.get("kind", "ammo")), int(item.get("amount", 1)))
		if not bool(rec.get("ok", false)) and bool(rec.get("full", false)):
			_spawn_loot_at(loot_pos, int(item.get("amount", 1)), str(item.get("kind", "ammo")))
			continue
		CombatFxScript.loot_spark(entities, loot_pos)
		CombatFxScript.loot_streak(entities, loot_pos, op.global_position)
		battle_log.add_event(sim.tick, "loot", op.op_id, -1, loot_pos, item)
		status_label.text = "%s 搜刮 %s" % [op.display_name, str(rec.get("text", ""))]
		_sfx("loot")
		_update_event_log()
		_update_role_cards()
		return


func _resolve_escapes() -> void:
	## Among alive runners who actually reached the mouth this tick, the closest
	## body wins (stable label_id on a tie). Dead / unfinished routes never leak.
	if phase != Phase.WATCHING:
		return
	var best: EnemyRunner = null
	var best_d := INF
	var best_id := 999999
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy.alive or not enemy.active:
			continue
		if not enemy.has_method("at_escape_mouth") or not bool(enemy.at_escape_mouth(escape_world)):
			continue
		var d := enemy.global_position.distance_to(escape_world)
		if d < best_d - 0.01 or (absf(d - best_d) <= 0.01 and enemy.label_id < best_id):
			best_d = d
			best_id = enemy.label_id
			best = enemy
	if best == null:
		return
	best.mark_escaped()


func _on_enemy_escaped(enemy: EnemyRunner, path: PackedVector2Array) -> void:
	if phase != Phase.WATCHING:
		return
	if enemy == null or not is_instance_valid(enemy):
		return
	# Record THIS runner — label_id + spawn_route from the emitter, never spawn_schedule[0].
	var route := str(enemy.spawn_route)
	if bool(enemy.did_branch):
		route = "alt"
	var lid := int(enemy.label_id)
	fail_reason = "escape"
	_wave_fail_index = wave_index() + 1
	phase = Phase.FAILED
	var hint := _escape_route_hint(enemy)
	battle_log.add_event(
		sim.tick, "escape", lid, -1, enemy.global_position,
		{"route": route, "kind": enemy.kind_short()}
	)
	battle_log.mark_terminal(sim.tick, "escape")
	for e in enemies:
		if e != null and is_instance_valid(e) and e != enemy:
			e.active = false
	_remember_path(path, "escape", hint, route, lid)
	_mission_had_escape = true
	_flash("逃逸！%s" % hint, Color(1.0, 0.35, 0.25))
	_sfx("escape")
	_camera_punch()
	CombatFxScript.escape_streak(entities, enemy.global_position, Vector2(0, 1))
	_begin_escape_flash()
	_redraw_ghosts()
	pending_result = "fail"


func _on_enemy_died(enemy: EnemyRunner) -> void:
	if phase != Phase.WATCHING and pending_result == "":
		return
	if phase == Phase.WATCHING or pending_result != "":
		battle_log.add_event(sim.tick, "kill", enemy.label_id)
	var drop_kit := "echo" if enemy.echo_kit else ""
	var night := str(level.level_id) if level else ""
	var drop: Dictionary = WeaponCatalogScript.enemy_drop_for(int(enemy.loot_ammo), drop_kit, night, int(enemy.label_id))
	_spawn_loot_at(enemy.global_position, int(drop.get("amount", 2)), str(drop.get("kind", "ammo")))
	if phase == Phase.WATCHING:
		_kill_edge_flash()
		if _last_kill_tick >= 0 and sim.tick - _last_kill_tick <= PayoffCopy.combo_window_ticks():
			_kill_combo += 1
		else:
			_kill_combo = 1
		_last_kill_tick = sim.tick
		if _kill_combo >= 2:
			_announce_payoff(
				"combo",
				{"combo": _kill_combo, "enemy_id": enemy.label_id},
				enemy.global_position
			)
		_sfx("kill")
		if not _is_power_saving():
			_camera_punch(Vector2(3, -2))
		var stain_tint := Color(0.55, 0.12, 0.10)
		if enemy.has_method("_kind_rim_color"):
			stain_tint = enemy._kind_rim_color()
		CombatFxScript.death_stain(entities, enemy.global_position, stain_tint)
		CombatFxScript.drag_smear(entities, enemy.global_position, enemy._last_move_dir, stain_tint)
		CombatFxScript.kill_stamp(entities, enemy.global_position, enemy.label_id, stain_tint.lightened(0.35))
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
	_sfx("fail")
	_play_fail_static()
	_redraw_ghosts()
	pending_result = "fail"


func _remember_path(path: PackedVector2Array, reason: String, hint: String = "", route: String = "", leaker_id: int = -1) -> void:
	intel.add_path(loop_index, path, sim.time_sec(), reason, hint, route, sim.tick, leaker_id)
	intel_paths.clear()
	for rec in intel.records:
		intel_paths.append(rec["path"])


func _escape_route_hint(enemy: EnemyRunner) -> String:
	if enemy == null:
		return "漏网路线已标在地图上"
	if bool(enemy.did_branch):
		return "锁门后从西侧紫备用接近漏出"
	var lid := int(enemy.label_id)
	var delay := 0.0
	if level != null and level.has_method("delay_for_actor") and lid >= 1:
		delay = float(level.delay_for_actor(lid))
	match enemy.spawn_route:
		"flank":
			if level != null and str(level.level_id) == "railcut":
				return "侧翼奔袭从东廊漏出（晚 3.8 秒）"
			if delay > 0.05:
				return "侧翼奔袭从东廊漏出（敌%d · %.1fs出发）" % [lid, delay]
			return "侧翼奔袭从东廊漏出"
		"sneak":
			if delay > 0.05:
				return "西暗道影探从夹缝漏出（敌%d · %.1fs出发）" % [lid, delay]
			return "西暗道影探从夹缝漏出"
		_:
			return "主路巡卫从南闸漏出"


func _set_watch_view_buttons(on: bool) -> void:
	if abort_button:
		abort_button.visible = on
		abort_button.disabled = not on
	if skip_outcome_button:
		skip_outcome_button.visible = on
		skip_outcome_button.disabled = not on


func _on_skip_to_outcome_pressed() -> void:
	## Viewing-only: run the frozen plan to the terminal tick. Not abort.
	if phase != Phase.WATCHING or _skipping_outcome:
		return
	_skipping_outcome = true
	var guard := 0
	var cap := 60 * 60
	while phase == Phase.WATCHING and guard < cap:
		_sim_tick()
		guard += 1
	_skipping_outcome = false
	if phase != Phase.WATCHING:
		_set_watch_view_buttons(false)


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
	_sfx("fail")
	_play_fail_static()
	_redraw_ghosts()
	pending_result = "fail"
	_finish_sim_tick()


func _on_op_fired_shot(op: OperatorUnit, target_pos: Vector2) -> void:
	var col := Color(1.0, 0.96, 0.62, 0.95)
	var w := 2.15
	if op != null:
		match op.role:
			OperatorUnit.Role.MG:
				col = Color(1.0, 0.88, 0.40, 0.96)
				w = 2.95
			OperatorUnit.Role.SCOUT:
				col = Color(0.88, 0.82, 0.58, 0.92)
				w = 1.85
		for i in operators.size():
			if operators[i] == op and i < role_cards.size():
				var card = role_cards[i]
				if card != null and card.has_method("pulse_fire"):
					card.pulse_fire()
	_spawn_watch_tracer(_muzzle_world(op), target_pos, col, w)


func _muzzle_world(op: OperatorUnit) -> Vector2:
	if op == null:
		return Vector2.ZERO
	var rad := deg_to_rad(op.facing_deg)
	var tip := absf(OperatorSilhouetteScript.barrel_tip_y(op.role))
	return op.global_position + Vector2(cos(rad), sin(rad)) * tip


func _spawn_watch_tracer(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	## Watching-phase tracer. Standard tier only; pooled Line2D, max 12 live/pool.
	if phase != Phase.WATCHING or _is_power_saving() or _skipping_outcome:
		return
	_trim_live_tracers()
	var line: Line2D = null
	while _tracer_pool.size() > 0 and line == null:
		var cand = _tracer_pool.pop_back()
		if cand != null and is_instance_valid(cand):
			line = cand as Line2D
	if line == null:
		line = Line2D.new()
		line.name = "WatchTracer"
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.z_index = 8
	line.width = width
	line.default_color = Color(color.r, color.g, color.b, minf(color.a + 0.08, 1.0))
	line.modulate = Color(1.15, 1.12, 1.05, 1)
	line.visible = true
	line.points = PackedVector2Array([from, to])
	if line.get_parent() != entities:
		if line.get_parent() != null:
			line.get_parent().remove_child(line)
		entities.add_child(line)
	_tracer_live.append(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.16)
	tw.tween_callback(_recycle_tracer.bind(line))


func _trim_live_tracers() -> void:
	var i := 0
	while i < _tracer_live.size():
		var c = _tracer_live[i]
		if c == null or not is_instance_valid(c):
			_tracer_live.remove_at(i)
			continue
		i += 1
	while _tracer_live.size() >= 12:
		var oldest: Line2D = _tracer_live[0] as Line2D
		_tracer_live.remove_at(0)
		_recycle_tracer(oldest)


func _recycle_tracer(line: Line2D) -> void:
	if line == null or not is_instance_valid(line):
		return
	var idx := _tracer_live.find(line)
	if idx >= 0:
		_tracer_live.remove_at(idx)
	# Stay parented under entities so headless quit does not leak a CanvasItem RID.
	line.visible = false
	line.modulate = Color.WHITE
	line.points = PackedVector2Array()
	if _tracer_pool.size() < 12:
		if not _tracer_pool.has(line):
			_tracer_pool.append(line)
	else:
		line.queue_free()


func _clear_tracer_pool() -> void:
	if entities:
		for c in entities.get_children():
			if c is Line2D and str(c.name).begins_with("WatchTracer"):
				c.queue_free()
	for t in _tracer_pool:
		if t != null and is_instance_valid(t):
			t.queue_free()
	_tracer_pool.clear()
	_tracer_live.clear()


func _exit_tree() -> void:
	_clear_tracer_pool()


func _on_op_ammo_empty(op: OperatorUnit) -> void:
	_flash("%s 空弹" % op.display_name, Color(0.9, 0.55, 0.2))
	if op != null and str(op.weapon_id) == "m1_garand":
		_sfx("fire_ping")
	else:
		_sfx("empty")
	_operator_bark(op, "empty")


func _operator_bark(op: OperatorUnit, kind: String) -> void:
	if op == null or not is_instance_valid(op):
		return
	var text := str(PayoffCopy.bark_text(kind, op.display_name))
	if text == "":
		return
	if op.has_method("speak_bark"):
		op.speak_bark(text)


func _on_op_ammo_repacked(op: OperatorUnit) -> void:
	if phase == Phase.WATCHING or pending_result != "":
		battle_log.add_event(sim.tick, "repack", op.op_id, -1, op.global_position, {"name": op.display_name})
	_announce_payoff("repack", {"name": op.display_name}, op.global_position)
	_update_event_log()
	_update_role_cards()


func _clear_flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
		_flash_tween = null
	if flash_label:
		flash_label.text = ""
		flash_label.modulate.a = 0.0
	if has_node("HUD/Root"):
		var plate := $HUD/Root.get_node_or_null("FlashPlate") as ColorRect
		if plate:
			plate.modulate.a = 0.0


func cinema_banner_text() -> String:
	if _watch_letterbox == null or not is_instance_valid(_watch_letterbox):
		return ""
	var banner := _watch_letterbox.get_node_or_null("WatchBanner") as Label
	if banner == null:
		return ""
	return str(banner.text)


func flash_text() -> String:
	if flash_label == null or float(flash_label.modulate.a) < 0.08:
		return ""
	return str(flash_label.text)


func _flash(text: String, color: Color) -> void:
	if flash_label == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	text = _clip_chip_line(text, 28)
	if phase == Phase.WATCHING:
		flash_label.offset_top = 118.0
		flash_label.offset_bottom = 152.0
	else:
		# Under the timeline (76–120), not across the spawn marks.
		flash_label.offset_top = 124.0
		flash_label.offset_bottom = 152.0
	flash_label.text = text
	flash_label.add_theme_color_override("font_color", color)
	flash_label.modulate = Color(1, 1, 1, 1)
	flash_label.pivot_offset = Vector2(200.0, 14.0)
	flash_label.scale = Vector2(1.12, 1.12)
	var plate := get_node_or_null("HUD/Root/FlashPlate") as ColorRect
	if plate:
		plate.offset_top = flash_label.offset_top - 2.0
		plate.offset_bottom = flash_label.offset_bottom + 2.0
		plate.modulate.a = 1.0
		_flash_tween = flash_label.create_tween()
		_flash_tween.tween_property(flash_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_flash_tween.parallel().tween_property(flash_label, "modulate:a", 0.0, 1.45)
		_flash_tween.parallel().tween_property(plate, "modulate:a", 0.0, 1.45)
		return
	_flash_tween = flash_label.create_tween()
	_flash_tween.tween_property(flash_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tween.parallel().tween_property(flash_label, "modulate:a", 0.0, 1.45)


func _fix_one_line() -> String:
	if fail_reason != "escape":
		return ""
	if _alarm_pulled_unarmed:
		return "改一处就能赢：先搜匣拿到枪再拉警报。刀强拉会漏网。"
	if level != null:
		var authored := str(level.fix_one).strip_edges()
		if authored != "":
			return authored
	return ""


func highlight_result_text() -> String:
	return str(PayoffCopy.highlight_result_line(level, battle_log, phase == Phase.WON))


func payoff_callout_active() -> bool:
	return _payoff_callout != null and is_instance_valid(_payoff_callout) and _payoff_callout.visible


func _announce_payoff(kind: String, payload: Dictionary = {}, pos: Vector2 = Vector2.ZERO) -> void:
	## Copy + camera hitch + world tag. Does not add battle_log events.
	if kind == "" or _skipping_outcome:
		return
	if kind == _last_payoff_kind and sim.tick == _last_payoff_tick and kind != "combo":
		return
	_last_payoff_kind = kind
	_last_payoff_tick = sim.tick
	var text := str(PayoffCopy.watching_text(kind, payload))
	if text == "":
		return
	var col: Color = PayoffCopy.watching_color(kind)
	_flash(text, col)
	var hitch: Vector2 = PayoffCopy.hitch_for(kind)
	if hitch != Vector2.ZERO and not _is_power_saving() and phase == Phase.WATCHING:
		_camera_punch(hitch)
	if pos.length() > 4.0 and phase == Phase.WATCHING:
		_spawn_payoff_callout(pos, text, col)
	_sync_payoff_timelines()


func _sync_payoff_timelines() -> void:
	var marks: Array = PayoffCopy.timeline_marks(battle_log)
	if watch_timeline != null and is_instance_valid(watch_timeline):
		watch_timeline.set("payoff_marks", marks)
		watch_timeline.queue_redraw()
	if route_timeline != null and is_instance_valid(route_timeline) and route_timeline.visible:
		route_timeline.set("payoff_marks", marks)
		route_timeline.queue_redraw()


func _clear_payoff_callout() -> void:
	if _payoff_callout_tween != null:
		_payoff_callout_tween.kill()
		_payoff_callout_tween = null
	if _payoff_callout != null and is_instance_valid(_payoff_callout):
		_payoff_callout.queue_free()
	_payoff_callout = null


func _spawn_payoff_callout(pos: Vector2, text: String, color: Color) -> void:
	_clear_payoff_callout()
	var n := Node2D.new()
	n.name = "PayoffCallout"
	n.position = pos + Vector2(0, -28)
	n.z_index = 12
	var pw := clampf(18.0 + float(text.length()) * 14.0, 120.0, 420.0)
	var plate := Polygon2D.new()
	plate.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(pw, -8), Vector2(pw, 20), Vector2(-8, 20)
	])
	plate.color = Color(0.04, 0.05, 0.03, 0.78)
	n.add_child(plate)
	var lab := Label.new()
	lab.name = "Tag"
	lab.text = text
	lab.position = Vector2(-2, -6)
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_font_override("font", NightOps.ui_font_bold())
	lab.add_theme_color_override("font_color", color)
	lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.94))
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(lab)
	var world := get_node_or_null("World")
	if world:
		world.add_child(n)
	else:
		add_child(n)
	_payoff_callout = n
	_payoff_callout_tween = n.create_tween()
	_payoff_callout_tween.tween_interval(1.15)
	_payoff_callout_tween.tween_property(n, "modulate:a", 0.0, 0.28)
	_payoff_callout_tween.tween_callback(_clear_payoff_callout)


func _show_fail_result() -> void:
	_play_fail_static()
	_ensure_dossier_ui()
	_set_watch_view_buttons(false)
	if title_return_button:
		title_return_button.visible = false
	result_panel.visible = true
	_bind_result_headline("失败 · %s" % BattleLog.reason_zh(fail_reason))
	if result_stats:
		result_stats.visible = false
	_dock_fail_result_panel(fail_reason == "escape")
	_raise_result_overlay()
	var lines := battle_log.summary_lines(10)
	var summary := "\n".join(lines)
	var reason_zh: String = BattleLog.reason_zh(fail_reason)
	var epitaph := battle_log.terminal_summary_line()
	var intel_line := "情报已记录"
	if fail_reason == "escape":
		var hint := intel.latest_hint()
		intel_line = "情报已记录 · %s" % (hint if hint != "" else "漏网路线已标在地图上")
	elif intel.latest_line() != "":
		intel_line = "情报已记录 · %s" % intel.latest_line()
	var shot := _first_shot_line()
	var wave := _next_wave_line()
	var leak_line := _leak_result_line() if fail_reason == "escape" else ""
	var fix := _fix_one_line()
	var hook := str(PayoffCopy.highlight_result_line(level, battle_log, false))
	var chatter := ""
	if level != null:
		chatter = str(LevelDef.chatter_for(level.level_id, fail_reason)).strip_edges()
	var cover_line := _cover_vs_leak_line()
	var trap_miss := _second_trap_miss_line()
	var wall := ""
	if intel != null and intel.has_method("wall_text"):
		wall = str(intel.wall_text(4)).strip_edges()
	var dossier_bits: PackedStringArray = PackedStringArray()
	dossier_bits.append(intel_line)
	if epitaph != "":
		dossier_bits.append(epitaph)
	if shot != "":
		dossier_bits.append(shot)
	if wave != "":
		dossier_bits.append(wave)
	if hook != "":
		dossier_bits.append(hook)
	if chatter != "":
		dossier_bits.append("截获 · %s" % chatter)
	if cover_line != "":
		dossier_bits.append(cover_line)
	if trap_miss != "":
		dossier_bits.append(trap_miss)
	if wall != "":
		dossier_bits.append(wall)
	if fail_reason == "escape":
		dossier_bits.append("逃逸口已在地图上闪烁。")
	dossier_bits.append("—— 事件摘要（点击右侧日志定位）——")
	if summary != "":
		dossier_bits.append(summary)
	_fail_dossier_text = "\n".join(dossier_bits)
	var line1 := leak_line if leak_line != "" else "第 %d 世失败（%s）。" % [loop_index, reason_zh]
	var line2 := fix if fix != "" else intel_line
	var line3 := "带着情报穿梭回去"
	result_label.text = "%s\n%s\n%s" % [line1, line2, line3]
	_dossier_open = false
	if result_dossier:
		result_dossier.text = _fail_dossier_text
		result_dossier.visible = false
	if dossier_button:
		dossier_button.visible = true
		dossier_button.text = "卷宗"
	_refresh_route_timeline(true)
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
		_sfx("leak")
		_play_intel_path_ghost(true)
		_build_fail_gap_callout()


func _show_win_result() -> void:
	_set_watch_view_buttons(false)
	_fail_dossier_text = ""
	_dossier_open = false
	if dossier_button:
		dossier_button.visible = false
	if result_dossier:
		result_dossier.visible = false
	_reset_result_panel_pos()
	# Centered, shorter than ExtraBar's old bite. Bars hide while this is up.
	result_panel.offset_left = -320.0
	result_panel.offset_right = 320.0
	result_panel.offset_top = -210.0
	result_panel.offset_bottom = 190.0
	result_panel.visible = true
	_raise_result_overlay()
	if title_return_button:
		title_return_button.visible = true
	var lines := battle_log.summary_lines(5)
	var has_next := level_index + 1 < LEVEL_ORDER.size()
	var epitaph := battle_log.terminal_summary_line()
	var shot := _first_shot_line()
	if has_next:
		_bind_result_headline("封锁成功")
		_fill_result_stats()
		var next_id := str(LEVEL_ORDER[level_index + 1])
		var unlock := "+解锁下一关 · 「%s」" % LevelDef.mood_tag(next_id)
		var star := ""
		if not _mission_had_escape:
			star = "\n★ 完美封锁：零逃逸"
		if not _night_hp_lost:
			star += "\n★ 无人受伤"
		var hook := str(PayoffCopy.highlight_result_line(level, battle_log, true))
		var hook_block := ("\n%s" % hook) if hook != "" else ""
		var beat := ""
		if level != null:
			beat = str(level.campaign_beat).strip_edges()
		var beat_block := ("\n%s" % beat) if beat != "" else ""
		var chain := ""
		if level != null:
			chain = str(LevelDef.chain_progress_line(level.level_id)).strip_edges()
		var chain_block := ("\n%s" % chain) if chain != "" else ""
		result_label.text = "任务完成。\n%s\n本关用了 %d 世。\n%s\n%s%s%s%s%s\n\n—— 关键事件 ——\n%s" % [
			unlock, loop_index, epitaph, shot, hook_block, beat_block, chain_block, star, "\n".join(lines)
		]
		continue_button.text = "下一关"
	else:
		_bind_result_headline("全部封锁")
		_fill_result_stats()
		var last_star := ""
		if not _mission_had_escape:
			last_star = "\n★ 完美封锁：零逃逸"
		if not _night_hp_lost:
			last_star += "\n★ 无人受伤"
		var last_hook := str(PayoffCopy.highlight_result_line(level, battle_log, true))
		var last_hook_block := ("\n%s" % last_hook) if last_hook != "" else ""
		var last_beat := ""
		if level != null:
			last_beat = str(level.campaign_beat).strip_edges()
		var last_beat_block := ("\n%s" % last_beat) if last_beat != "" else ""
		var recap := str(LevelDef.campaign_chain_names())
		result_label.text = "全部关卡封锁完成。\n%s\n本关用了 %d 世。\n%s\n%s%s%s%s\n\n—— 关键事件 ——\n%s" % [
			recap, loop_index, epitaph, shot, last_hook_block, last_beat_block, last_star, "\n".join(lines)
		]
		continue_button.text = "查看致谢"
		_campaign_complete = true
	var gs = _gs()
	if gs and level:
		gs.record_win(level.level_id, loop_index, not _mission_had_escape)
	_refresh_route_timeline(true)
	if replay_button:
		replay_button.visible = true
	status_label.text = "计划奏效"
	_save_progress()
	_update_event_log()
	_update_hud()
	_play_result_tone(true)
	_fade_result_panel()
	_raise_result_overlay()


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
		_add_replay_marker(
			o["pos"],
			col if alive else Color(0.3, 0.3, 0.32),
			"队员%d" % int(o["id"]),
			alive,
			hot,
			float(o.get("facing", 90.0)),
			true,
			not alive
		)
	for e in data.get("enemies", []):
		var alive := bool(e["alive"])
		var hot := replay_focus_actor == int(e["id"]) and replay_focus_type in ["spawn", "kill", "escape", "fire", "return_fire", "trip", "route_choice", "no_engage"]
		_add_replay_marker(
			e["pos"],
			Color(0.75, 0.22, 0.2) if alive else Color(0.35, 0.35, 0.38, 0.7),
			"敌%d" % int(e["id"]),
			alive,
			hot,
			90.0,
			false,
			not alive
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


func _add_replay_marker(
	pos: Vector2,
	color: Color,
	label: String,
	alive: bool,
	focused: bool = false,
	facing: float = 90.0,
	draw_cone: bool = false,
	kill_stamp: bool = false
) -> void:
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
	if draw_cone and alive:
		var cone := Polygon2D.new()
		cone.name = "ReplayCone"
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 8:
			var t := lerpf(-26.0, 26.0, float(i) / 8.0)
			var rad := deg_to_rad(facing + t)
			pts.append(Vector2(cos(rad), sin(rad)) * 54.0)
		cone.polygon = pts
		cone.color = Color(color.r, color.g, color.b, 0.22)
		n.add_child(cone)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(0, -10), Vector2(8, 8), Vector2(-8, 8)])
	body.color = Color(1.0, 0.9, 0.3) if focused else color
	n.add_child(body)
	if kill_stamp:
		var x1 := Line2D.new()
		x1.name = "KillStamp"
		x1.width = 2.4
		x1.default_color = Color(1.0, 0.82, 0.32, 0.92)
		x1.points = PackedVector2Array([Vector2(-8, -8), Vector2(8, 8)])
		n.add_child(x1)
		var x2 := Line2D.new()
		x2.name = "KillStamp2"
		x2.width = 2.4
		x2.default_color = Color(1.0, 0.82, 0.32, 0.92)
		x2.points = PackedVector2Array([Vector2(8, -8), Vector2(-8, 8)])
		n.add_child(x2)
	var t := Label.new()
	t.text = label if alive else "%s·亡" % label
	t.position = Vector2(-18, -28)
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4) if focused else color)
	n.add_child(t)
	replay_layer.add_child(n)


func replay_has_cone() -> bool:
	if replay_layer == null:
		return false
	for c in replay_layer.get_children():
		if c.get_node_or_null("ReplayCone") != null:
			return true
	return false


func replay_has_kill_stamp() -> bool:
	if replay_layer == null:
		return false
	for c in replay_layer.get_children():
		if c.get_node_or_null("KillStamp") != null:
			return true
	return false


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
	_enter_sweep()


func _first_shot_line() -> String:
	var ev := battle_log.first_of_type("fire")
	if ev.is_empty():
		return "第一枪：本世无人开火"
	var nm := str(ev.get("payload", {}).get("name", ""))
	if nm == "":
		var op := _op_by_id(int(ev.get("actor_id", -1)))
		nm = op.display_name if op else ("队员%d" % int(ev.get("actor_id", 0)))
	return str(PayoffCopy.first_shot_text(nm, int(ev.get("target_id", 0))))


func _route_zh_short(route: String) -> String:
	match route:
		"flank":
			return "侧翼"
		"sneak":
			return "暗道"
		"echo":
			return "回波"
		"alt":
			return "备用"
		_:
			return "主路"


func _next_wave_info() -> Dictionary:
	## Shared pending-wave clock for fail panel and the WATCHING touch chip.
	var out := {
		"pending": false,
		"remain": 0.0,
		"route": "",
		"intel_cut": -1.0,
		"now": 0.0,
	}
	if level == null:
		return out
	var now := sim.time_sec()
	out["now"] = now
	var intel_cut := -1.0
	if intel != null and intel.has_method("recent"):
		var recs: Array = intel.recent(1)
		if not recs.is_empty():
			intel_cut = float(recs[0].get("cut_sec", -1.0))
	out["intel_cut"] = intel_cut
	var ref_t := now
	if intel_cut >= 0.0 and phase != Phase.WATCHING:
		ref_t = intel_cut
	var next_d := INF
	var next_route := ""
	var next_kit := ""
	var next_note := ""
	var next_id := -1
	for spec in level.spawn_schedule:
		var d := float(spec.get("delay", 0.0))
		var spawned := false
		for p in pending_spawns:
			if int(p.get("id", -1)) == int(spec.get("id", -2)) and bool(p.get("spawned", false)):
				spawned = true
				break
		if spawned:
			continue
		if d > ref_t + 0.05 and d < next_d:
			next_d = d
			next_route = str(spec.get("route", "main"))
			next_kit = str(spec.get("kit", "")).strip_edges()
			next_note = str(spec.get("teaching_note", "")).strip_edges()
			next_id = int(spec.get("id", -1))
	if next_d == INF:
		return out
	out["pending"] = true
	out["route"] = next_route
	out["kit"] = next_kit
	out["note"] = next_note
	out["id"] = next_id
	out["remain"] = maxf(next_d - now, 0.0)
	return out


func _next_wave_line() -> String:
	## Seconds until the next authored spawn after now / last intel cut.
	var info := _next_wave_info()
	if level == null:
		return "下一波：—"
	var intel_cut := float(info.get("intel_cut", -1.0))
	if not bool(info.get("pending", false)):
		if intel_cut >= 0.0:
			return "下一波：已全部进场（情报截止 %.1fs）" % intel_cut
		return "下一波：已全部进场"
	var remain := float(info.get("remain", 0.0))
	var next_route := str(info.get("route", "main"))
	var road := _route_zh_short(next_route)
	if str(info.get("kit", "")) == "echo" or str(info.get("note", "")).find("回波") >= 0:
		road = "回波"
	elif str(info.get("note", "")).find("西夹缝") >= 0:
		road = "暗道"
	if intel_cut >= 0.0:
		return "下一波：%s 还有 %.1fs（情报截止 %.1fs）" % [road, remain, intel_cut]
	return "下一波：%s 还有 %.1fs" % [road, remain]


func _refresh_route_timeline(show: bool) -> void:
	_ensure_route_timeline()
	if route_timeline == null:
		return
	route_timeline.visible = show and level != null
	if not show or level == null:
		if route_timeline.has_method("set_live"):
			route_timeline.set_live(false)
		return
	var marks: Array = []
	if level.has_method("route_spawn_marks"):
		marks = level.route_spawn_marks()
	route_timeline.set("marks", marks)
	route_timeline.set("payoff_marks", PayoffCopy.timeline_marks(battle_log))
	var tmax := 1.0
	for m in marks:
		tmax = maxf(tmax, float(m.get("delay", 0.0)) + 0.5)
	tmax = maxf(tmax, sim.time_sec())
	route_timeline.set("t_max", tmax)
	route_timeline.set("elapsed", sim.time_sec())
	if route_timeline.has_method("set_live"):
		route_timeline.set_live(false)
	route_timeline.queue_redraw()


func _ensure_watch_timeline() -> void:
	if watch_timeline != null and is_instance_valid(watch_timeline):
		return
	var root: Control = get_node_or_null("HUD/Root") as Control
	if root == null:
		return
	var strip := Control.new()
	strip.name = "WatchTimeline"
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_left = 220.0
	strip.offset_top = 76.0
	strip.offset_right = -16.0
	strip.offset_bottom = 120.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.set_script(load("res://scripts/ui/route_timeline.gd"))
	root.add_child(strip)
	watch_timeline = strip


func _refresh_watch_timeline() -> void:
	_ensure_watch_timeline()
	if watch_timeline == null:
		return
	var show := (phase == Phase.WATCHING or phase == Phase.SETUP) and level != null
	var touch := _want_touch()
	watch_timeline.offset_top = 72.0 if touch else 76.0
	watch_timeline.offset_bottom = 116.0 if touch else 120.0
	watch_timeline.visible = show
	if not show:
		watch_timeline.set("preview_upcoming", 0)
		if watch_timeline.has_method("set_live"):
			watch_timeline.set_live(false)
		return
	var marks: Array = []
	if level.has_method("route_spawn_marks"):
		marks = level.route_spawn_marks()
	watch_timeline.set("marks", marks)
	watch_timeline.set("payoff_marks", PayoffCopy.timeline_marks(battle_log) if phase == Phase.WATCHING else [])
	var tmax := 1.0
	for m in marks:
		tmax = maxf(tmax, float(m.get("delay", 0.0)) + 0.5)
	tmax = maxf(tmax, sim.time_sec())
	watch_timeline.set("t_max", tmax)
	if phase == Phase.SETUP:
		watch_timeline.set("elapsed", 0.0)
		watch_timeline.set("preview_upcoming", 2)
		if watch_timeline.has_method("set_live"):
			watch_timeline.set_live(false)
	else:
		watch_timeline.set("elapsed", sim.time_sec())
		watch_timeline.set("preview_upcoming", 0)
		if watch_timeline.has_method("set_live"):
			watch_timeline.set_live(true)
	watch_timeline.queue_redraw()
	_refresh_watch_wave_chip()


func _ensure_watch_wave_chip() -> void:
	if watch_wave_chip != null and is_instance_valid(watch_wave_chip):
		return
	var root: Control = get_node_or_null("HUD/Root") as Control
	if root == null:
		return
	var lab := Label.new()
	lab.name = "WatchWaveChip"
	lab.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lab.offset_left = 220.0
	lab.offset_top = 52.0
	lab.offset_right = -16.0
	lab.offset_bottom = 74.0
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_font_override("font", NightOps.ui_font_bold())
	lab.add_theme_color_override("font_color", Color(0.95, 0.86, 0.42))
	lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.02, 0.9))
	lab.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(lab)
	watch_wave_chip = lab


func _refresh_watch_wave_chip() -> void:
	_ensure_watch_wave_chip()
	if watch_wave_chip == null:
		return
	var show := phase == Phase.WATCHING
	var info := _next_wave_info() if show else {}
	if show and bool(info.get("pending", false)):
		watch_wave_chip.visible = true
		watch_wave_chip.text = _next_wave_line()
	else:
		watch_wave_chip.visible = false
		watch_wave_chip.text = ""


func setup_spawn_preview_visible() -> bool:
	return (
		phase == Phase.SETUP
		and watch_timeline != null
		and is_instance_valid(watch_timeline)
		and watch_timeline.visible
		and int(watch_timeline.get("preview_upcoming")) >= 1
	)


func setup_spawn_preview_count() -> int:
	if watch_timeline == null or not is_instance_valid(watch_timeline):
		return 0
	if watch_timeline.has_method("preview_count"):
		return int(watch_timeline.preview_count())
	return 0


func _ensure_route_timeline() -> void:
	if route_timeline != null and is_instance_valid(route_timeline):
		return
	var vbox := result_panel.get_node_or_null("Margin/VBox") as VBoxContainer
	if vbox == null:
		return
	var strip := Control.new()
	strip.name = "RouteTimeline"
	strip.custom_minimum_size = Vector2(0, 40)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.set_script(load("res://scripts/ui/route_timeline.gd"))
	vbox.add_child(strip)
	vbox.move_child(strip, mini(1, vbox.get_child_count() - 1))
	route_timeline = strip


func _on_continue_pressed() -> void:
	if phase == Phase.FAILED:
		var intel_line := intel.latest_line()
		var leak := intel.latest_hint()
		var was_escape := fail_reason == "escape"
		var advice := _leak_advice_line() if was_escape else ""
		leak_advice_shown = advice
		loop_index += 1
		_start_setup(true, true)
		if was_escape:
			_play_intel_path_ghost()
		if leak != "":
			var line := "情报已记录 · %s" % leak
			if advice != "":
				line += "  ·  %s" % advice
			if intel_label:
				intel_label.text = line
				intel_label.visible = false
			var col := _intel_flash_color(intel.latest_route() if intel.has_method("latest_route") else "")
			_refresh_intel_chip()
			_flash("情报已记录", col)
		elif intel_line != "":
			if intel_label:
				intel_label.text = "情报已记录 · %s" % intel_line
				intel_label.visible = false
			_refresh_intel_chip()
			_flash("情报已记录", Color(0.78, 0.68, 0.40))
	elif phase == Phase.WON:
		if level_index + 1 < LEVEL_ORDER.size():
			var from_id := str(LEVEL_ORDER[level_index])
			level_index += 1
			var to_id := str(LEVEL_ORDER[level_index])
			_load_level(to_id, false, false)
			_save_progress()
			_present_night_handoff(from_id, to_id)
		else:
			_campaign_complete = true
			_save_progress()
			_show_credits()
	elif phase == Phase.REPLAY:
		_exit_replay_to_setup()


func intel_path_ghost_active() -> bool:
	return _intel_ghost != null and is_instance_valid(_intel_ghost)


func _clear_intel_path_ghost() -> void:
	if _intel_ghost_tween != null:
		_intel_ghost_tween.kill()
		_intel_ghost_tween = null
	if _intel_ghost != null and is_instance_valid(_intel_ghost):
		_intel_ghost.queue_free()
	_intel_ghost = null


func _play_intel_path_ghost(hold: bool = false) -> void:
	## Snapshot dashed leaked path (intel color). Hold ~2s then fade. Presentation only.
	## hold=true keeps it up during the fail dossier so the leak reads on the map.
	_clear_intel_path_ghost()
	if intel == null:
		return
	var recs: Array = intel.recent(1)
	if recs.is_empty():
		return
	var path: PackedVector2Array = recs[0].get("path", PackedVector2Array())
	if path.size() < 2:
		return
	var col := _intel_flash_color(str(recs[0].get("route", "")))
	col.a = 0.92
	var ghost: Node2D = IntelPathGhostScript.new()
	ghost.name = "IntelPathGhost"
	var world := get_node_or_null("World")
	if world:
		world.add_child(ghost)
	else:
		add_child(ghost)
	if ghost.has_method("setup"):
		ghost.setup(path, col)
	_intel_ghost = ghost
	ghost.modulate.a = 1.0
	if hold:
		return
	_intel_ghost_tween = ghost.create_tween()
	_intel_ghost_tween.tween_interval(2.0)
	_intel_ghost_tween.tween_property(ghost, "modulate:a", 0.0, 0.45)
	_intel_ghost_tween.tween_callback(_clear_intel_path_ghost)


func _redraw_ghosts() -> void:
	for c in ghosts.get_children():
		c.queue_free()
	var recent: Array = intel.recent(3)
	var gi := 0
	for rec in recent:
		var path: PackedVector2Array = rec["path"]
		var line := Line2D.new()
		line.width = 3.0
		var route := str(rec.get("route", ""))
		var gcol := _intel_flash_color(route)
		gcol.a = 0.55 - minf(0.15, float(gi) * 0.05)
		line.default_color = gcol
		line.points = path
		ghosts.add_child(line)
		if path.size() > 0:
			var tag := Label.new()
			var reason_zh := BattleLog.reason_zh(str(rec["reason"]))
			tag.text = "第%d世 · %.1fs · %s" % [int(rec["loop"]), float(rec["cut_sec"]), reason_zh]
			tag.position = path[mini(path.size() - 1, path.size() / 2)] + Vector2(6, -18)
			tag.add_theme_font_size_override("font_size", 11)
			tag.add_theme_color_override("font_color", Color(gcol.r, gcol.g, gcol.b, 0.92))
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
		event_list.set_item_custom_fg_color(_event_list_items.size() - 1, _event_tint(ev))
	var log_open := _event_log_open and event_log != null and event_log.visible
	if log_open and _event_list_items.size() > 0:
		event_list.select(_event_list_items.size() - 1)
		event_list.ensure_current_is_visible()
	_set_event_log_interactive(phase != Phase.SETUP and _event_list_items.size() > 0)


func _event_tint(ev: Dictionary) -> Color:
	var typ := str(ev.get("type", ""))
	var route := str(ev.get("payload", {}).get("route", ""))
	match typ:
		"spawn":
			if str(ev.get("payload", {}).get("kit", "")) == "echo":
				return Color(0.70, 0.58, 0.32)
			match route:
				"flank":
					return Color(0.95, 0.62, 0.22)
				"sneak":
					return Color(0.42, 0.48, 0.28)
				_:
					return Color(0.92, 0.40, 0.32)
		"fire":
			return Color(1.0, 0.86, 0.38)
		"kill", "trip":
			return Color(0.55, 0.92, 0.48)
		"escape":
			return Color(1.0, 0.38, 0.28)
		"barrel", "route_choice":
			return Color(0.85, 0.58, 1.0)
		"op_down", "fail":
			return Color(0.90, 0.42, 0.42)
		"win":
			return Color(0.72, 0.88, 0.42)
		_:
			return Color(0.82, 0.84, 0.70)


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
	result_panel.z_index = 20
	_apply_result_rail()


func _raise_result_overlay() -> void:
	if result_panel == null:
		return
	result_panel.z_index = 50
	result_panel.move_to_front()
	if continue_button:
		continue_button.custom_minimum_size = Vector2(0, 44)
		continue_button.add_theme_font_size_override("font_size", 18)
	_apply_result_rail()
	_sync_desktop_bars(not _want_touch())


func _dock_fail_result_panel(_keep_escape_visible: bool) -> void:
	if result_panel == null:
		return
	# Center-bottom: left rail is hidden, ExtraBar is hidden, SE escape mouth
	# stays to the right of a 560px card. Old bottom-left dock sat under 灰狼/夜枭.
	result_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	result_panel.anchor_left = 0.5
	result_panel.anchor_top = 1.0
	result_panel.anchor_right = 0.5
	result_panel.anchor_bottom = 1.0
	result_panel.offset_left = -280.0
	result_panel.offset_right = 280.0
	result_panel.offset_top = -248.0
	result_panel.offset_bottom = -16.0
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_raise_result_overlay()


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


func fail_card_bitten_by_rail() -> bool:
	## True if the three-line fail card intersects the left operator dock.
	if result_panel == null or not result_panel.visible:
		return false
	if role_box == null or not is_instance_valid(role_box) or not role_box.visible:
		return false
	return result_panel.get_global_rect().intersects(role_box.get_global_rect())


func result_cta_buried_by_bars() -> bool:
	if result_panel == null or not result_panel.visible or continue_button == null:
		return false
	if not continue_button.visible:
		return false
	var cta := continue_button.get_global_rect()
	if extra_bar != null and extra_bar.visible and extra_bar.get_global_rect().intersects(cta):
		return true
	var bar: Control = get_node_or_null("HUD/Root/BottomBar") as Control
	if bar != null and bar.visible and bar.get_global_rect().intersects(cta):
		return true
	return false


func _update_hud() -> void:
	var lv_title := level.title if level else "AMBUSH LOOP"
	title_label.text = "AMBUSH LOOP  ·  第 %d 世  ·  波 %d/%d" % [loop_index, wave_index() + 1, wave_total()]
	if level_label:
		level_label.text = lv_title
	if tut_label and level:
		tut_label.text = level.tutorial if phase == Phase.SETUP else level.teaching
	_hide_duplicate_tut()
	_sync_desktop_bars(not _want_touch())
	if help_label:
		# One-line in the bottom-left chrome. Hidden while watching so the
		# letterbox and escape mouth stay clear. Never a paragraph over the map.
		help_label.visible = _is_command_phase() and not _want_touch()
	_refresh_spawn_teach()
	# Short dump string only. Painted advice lives on intel_chip under the timeline.
	var intel_txt := "漏网记忆：%d   |   %s" % [intel.records.size(), _ammo_summary()]
	if intel.latest_line() != "" and (phase == Phase.SETUP or phase == Phase.FAILED):
		intel_txt += "   ·   %s" % intel.latest_line()
	if leak_advice_shown != "" and phase == Phase.SETUP:
		intel_txt += "   ·   %s" % leak_advice_shown
	if intel_label:
		intel_label.text = intel_txt
		intel_label.visible = false
	_refresh_intel_chip()
	_refresh_phase_chip()
	_refresh_route_legend()
	_refresh_watch_timeline()
	_refresh_checklist()
	_refresh_decision_pulse()
	for op in operators:
		if op == null or not is_instance_valid(op):
			continue
		op.tag_emphasis = phase == Phase.WATCHING and op.alive and op.slot != null
		if op.has_method("_refresh_tag"):
			op._refresh_tag()
	_refresh_alarm_cta()
	var dep := _deployed_count()
	if phase == Phase.SETUP:
		help_label.text = "点地走 开匣 I背包 G雷点 上掩体%d/3 · 空格%s" % [dep, alarm_button.text if alarm_button else "警报"]
	elif phase == Phase.WATCHING:
		var spd := "暂停" if sim.paused else ("2×" if sim.speed >= 1.5 else "1×")
		help_label.text = "警报 t=%.1fs %s  自动火力/自动手雷" % [sim.time_sec(), spd]
	elif phase == Phase.SWEEP:
		help_label.text = "打扫：走近尸体拾取 · 空格%s" % ("撤离" if raid and raid.is_last_wave(level) else "下一波")
	elif phase == Phase.FAILED:
		help_label.text = "失败：%s" % fail_reason
	elif phase == Phase.WON:
		help_label.text = "封锁成功 · 时间轴只读"
	elif phase == Phase.REPLAY:
		help_label.text = "复盘 t=%.1fs / %.1fs" % [
			float(replay.scrub_tick) / 60.0, float(replay.max_tick()) / 60.0
		]
	_refresh_stash_board()
	_refresh_door_visual()
	_refresh_mode_pack_buttons()
	_refresh_backpack_if_open()
	_update_role_cards()
	_update_observation_rings()
	if phase != Phase.SETUP:
		_update_cover_previews()
	_apply_watch_layers()
	_ensure_touch_hud()
	_refresh_touch_hud()


func _pending_unspawned() -> int:
	var n := 0
	for spec in pending_spawns:
		if spec is Dictionary and not bool(spec.get("spawned", false)):
			n += 1
	return n


func _tick_pending_wave_tension() -> void:
	## Body-feel for waves that have not arrived: cue when the next authored spawn is close.
	if phase != Phase.WATCHING:
		return
	var info := _next_wave_info()
	if not bool(info.get("pending", false)):
		return
	var remain := float(info.get("remain", 99.0))
	var wid := int(info.get("id", -1))
	var echo := str(info.get("route", "")) == "echo" or str(info.get("kit", "")) == "echo"
	var window := 2.6 if echo else 1.25
	if remain > window or remain <= 0.0:
		return
	if wid == _wave_tension_id:
		return
	_wave_tension_id = wid
	_sfx("tension")
	if watch_wave_chip:
		watch_wave_chip.modulate = Color(1.35, 1.15, 0.55)


func pending_wave_tension_armed() -> bool:
	return _wave_tension_id >= 1


func watch_pending_breathing() -> bool:
	if watch_timeline != null and is_instance_valid(watch_timeline) and watch_timeline.has_method("pending_breathing"):
		if bool(watch_timeline.call("pending_breathing")):
			return true
	if route_timeline != null and is_instance_valid(route_timeline) and route_timeline.has_method("pending_breathing"):
		return bool(route_timeline.call("pending_breathing"))
	return false


func echo_wait_breathing() -> bool:
	if watch_timeline == null or not is_instance_valid(watch_timeline):
		return false
	if watch_timeline.has_method("echo_mark_pending"):
		return bool(watch_timeline.call("echo_mark_pending"))
	return false


func _tick_last_enemy_highlight() -> void:
	var live: Array = []
	for e in enemies:
		if e != null and is_instance_valid(e) and e.alive and e.active:
			live.append(e)
	var mark := live.size() == 1 and _pending_unspawned() == 0
	for e in enemies:
		if e != null and is_instance_valid(e) and e.has_method("set_last_runner"):
			e.set_last_runner(mark and e.alive and e.active)
	if mark and not _barked_last and phase == Phase.WATCHING:
		_barked_last = true
		_sfx("tension")
		for op in operators:
			if op != null and op.visible and op.alive:
				_operator_bark(op, "last")
				break


func watch_census_text() -> String:
	var live_e := 0
	var live_o := 0
	var pending := 0
	for e in enemies:
		if e != null and is_instance_valid(e) and e.alive and e.active:
			live_e += 1
	for op in operators:
		if op != null and op.visible and op.alive:
			live_o += 1
	for spec in pending_spawns:
		if spec is Dictionary and not bool(spec.get("spawned", false)):
			pending += 1
	return "敌%d 待%d 员%d" % [live_e, pending, live_o]


func _refresh_phase_chip() -> void:
	if phase_chip == null:
		return
	var total: int = raid.wave_count(level) if raid else 1
	var w: int = raid.wave_index if raid else 0
	match phase:
		Phase.SETUP:
			phase_chip.text = "阶段 · 搜刮埋伏  波次 %d/%d" % [w + 1, total]
			phase_chip.add_theme_color_override("font_color", Color(0.82, 0.90, 0.52))
		Phase.WATCHING:
			var spd := "暂停" if sim.paused else ("2×" if sim.speed >= 1.5 else "1×")
			phase_chip.text = "警报 第%d/%d波  %s  t=%.1fs  %s" % [w + 1, total, spd, sim.time_sec(), watch_census_text()]
			phase_chip.add_theme_color_override("font_color", Color(1.0, 0.22, 0.14))
		Phase.SWEEP:
			if raid and raid.is_last_wave(level):
				phase_chip.text = "打扫战场  最后一波 · 空格撤离"
			else:
				phase_chip.text = "打扫战场  空格拉第%d波" % [w + 2]
			phase_chip.add_theme_color_override("font_color", Color(0.95, 0.82, 0.38))
		Phase.FAILED:
			phase_chip.text = "阶段 · 失败"
			phase_chip.add_theme_color_override("font_color", Color(1.0, 0.42, 0.28))
		Phase.WON:
			phase_chip.text = "阶段 · 封锁成功"
			phase_chip.add_theme_color_override("font_color", Color(0.55, 0.92, 0.48))
		Phase.REPLAY:
			phase_chip.text = "阶段 · 只读复盘"
			phase_chip.add_theme_color_override("font_color", Color(0.78, 0.70, 0.48))
		_:
			phase_chip.text = ""


func _refresh_route_legend() -> void:
	if route_legend == null:
		return
	var show := phase == Phase.SETUP and level != null
	route_legend.visible = show
	if not show:
		return
	var chips: Array = [
		{"id": "main", "icon": "主", "label": _route_chip_label("main", "主路"), "color": Color(0.92, 0.28, 0.22)},
	]
	if level.route_cells.has("flank"):
		chips.append({"id": "flank", "icon": "侧", "label": _route_chip_label("flank", "侧翼"), "color": Color(0.95, 0.55, 0.16)})
	if level.route_cells.has("sneak"):
		chips.append({"id": "sneak", "icon": "暗", "label": _route_chip_label("sneak", "暗道"), "color": Color(0.42, 0.48, 0.28)})
	if level.route_cells.has("echo"):
		chips.append({"id": "echo", "icon": "回", "label": _route_chip_label("echo", "回波"), "color": Color(0.70, 0.58, 0.32)})
	if level.level_id == "pump" and not level.alternate_route_cells.is_empty():
		chips.append({"id": "alt", "icon": "门", "label": "备用", "color": Color(0.72, 0.55, 0.28)})
	if level.has_method("second_trap_text") and str(level.second_trap_text()).strip_edges() != "":
		var tcol := Color(1.0, 0.72, 0.38)
		if str(level.level_id) == "radio":
			tcol = Color(0.70, 0.58, 0.32)
		chips.append({"id": "trap2", "icon": "二", "label": "第二层", "color": tcol})
	_fill_route_chips(chips)


func _route_chip_label(route: String, base: String) -> String:
	var lab := base
	if level != null and level.has_method("first_route_delay"):
		var delay := float(level.first_route_delay(route))
		if delay >= 1.0:
			lab = "%s %.1fs" % [base, delay]
	if level != null and level.has_method("teaching_note_for"):
		var note := str(level.teaching_note_for(route))
		if note != "":
			lab = "%s · %s" % [lab, note]
	return lab


func _fill_route_chips(chips: Array) -> void:
	while route_legend.get_child_count() > chips.size():
		var last := route_legend.get_child(route_legend.get_child_count() - 1)
		route_legend.remove_child(last)
		last.free()
	while route_legend.get_child_count() < chips.size():
		route_legend.add_child(_make_route_chip())
	for i in chips.size():
		_bind_route_chip(route_legend.get_child(i) as Control, chips[i])


func _make_route_chip() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.custom_minimum_size = Vector2(10, 10)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	var icon := Label.new()
	icon.name = "Icon"
	icon.add_theme_font_size_override("font_size", 13)
	icon.add_theme_font_override("font", NightOps.ui_font_bold())
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var lab := Label.new()
	lab.name = "Lab"
	lab.add_theme_font_size_override("font_size", 13)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lab)
	return p


func _bind_route_chip(chip: Control, spec: Dictionary) -> void:
	if chip == null:
		return
	var col: Color = spec["color"]
	var sb := NightOps.flat(Color(col.r * 0.16, col.g * 0.12, col.b * 0.10, 0.88), col, 1, 8, 10)
	chip.add_theme_stylebox_override("panel", sb)
	var swatch := chip.find_child("Swatch", true, false) as ColorRect
	if swatch:
		swatch.color = col
	var icon := chip.find_child("Icon", true, false) as Label
	if icon:
		icon.text = str(spec["icon"])
		icon.add_theme_color_override("font_color", col.lightened(0.15))
	var lab := chip.find_child("Lab", true, false) as Label
	if lab:
		lab.text = str(spec["label"])
		lab.add_theme_color_override("font_color", Color(0.94, 0.90, 0.78))


func _tick_cover_long_press() -> void:
	if phase != Phase.SETUP:
		return
	if _cover_hold_slot == null or not is_instance_valid(_cover_hold_slot):
		return
	if Time.get_ticks_msec() - _cover_hold_msec < COVER_LONGPRESS_MS:
		return
	_touch_preview_slot = _cover_hold_slot
	if status_label:
		status_label.text = "掩体保护朝%s（长按预览，松手不部署）" % _cover_hold_slot.protect_compass()
	_update_cover_previews()


func _tick_cover_hold_ring() -> void:
	var p := 0.0
	if phase == Phase.SETUP and _cover_hold_slot != null and is_instance_valid(_cover_hold_slot):
		p = clampf(float(Time.get_ticks_msec() - _cover_hold_msec) / float(COVER_LONGPRESS_MS), 0.0, 1.0)
	for s in cover_slots:
		if s != null and is_instance_valid(s) and s.has_method("set_hold_progress"):
			s.set_hold_progress(p if s == _cover_hold_slot else 0.0)


func _update_cover_previews() -> void:
	if cover_slots.is_empty():
		return
	var show := phase == Phase.SETUP or phase == Phase.WATCHING or phase == Phase.REPLAY or phase == Phase.FAILED
	var hover: CoverSlot = null
	if phase == Phase.SETUP:
		if _touch_preview_slot != null and is_instance_valid(_touch_preview_slot):
			hover = _touch_preview_slot
		else:
			hover = _nearest_slot(_aim_world(), 32.0)
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
		var occupied := s.occupied_by != null and is_instance_valid(s.occupied_by) and s.occupied_by.visible
		if s.has_method("set_plan_lock"):
			s.set_plan_lock(phase == Phase.WATCHING and occupied)
		var hint := false
		var hint_col := Color(0.62, 0.84, 0.42)
		if phase == Phase.SETUP and selected != null and not occupied and level != null and level.has_method("suggested_cover_name"):
			var want := str(level.suggested_cover_name(selected.role))
			if want != "" and s.label_text == want:
				hint = true
				hint_col = OperatorUnit.role_kit_color(selected.role)
		if s.has_method("set_role_hint"):
			s.set_role_hint(hint, hint_col)


func _update_role_cards() -> void:
	_apply_result_rail()
	if role_box:
		role_box.modulate = Color(1, 1, 1, 0.45) if phase == Phase.REPLAY else Color.WHITE
	for i in role_cards.size():
		var card: OpCard = role_cards[i]
		if i >= operators.size():
			card.visible = false
			continue
		var op: OperatorUnit = operators[i]
		var why := ""
		if level != null and level.has_method("role_why_for"):
			why = str(level.role_why_for(op.role))
		card.bind(op, op == selected, phase != Phase.REPLAY, phase == Phase.WATCHING, why)
	if plan_readout == null:
		return
	if selected == null:
		plan_readout.text = ""
	elif not selected.visible or selected.slot == null:
		var why0 := ""
		if level != null and level.has_method("role_why_for"):
			why0 = str(level.role_why_for(selected.role))
		var why_bit := ("\n%s" % why0) if why0 != "" else ""
		plan_readout.text = "选中 %s\n%s%s" % [selected.display_name, selected.kit_blurb(), why_bit]
	else:
		var why1 := ""
		if level != null and level.has_method("role_why_for"):
			why1 = str(level.role_why_for(selected.role))
		var why_line := ("\n%s" % why1) if why1 != "" else ""
		plan_readout.text = "掩体「%s」保护朝%s — 该方向来袭减伤60%%，侧背无减免。射界朝%s（黄锥，墙裁切）。\n优先目标：距逃逸口剩余路程最短。%s" % [
			selected.slot.label_text,
			selected.slot.protect_compass(),
			_compass_deg(selected.facing_deg),
			why_line,
		]


func _is_command_phase() -> bool:
	return phase == Phase.SETUP or phase == Phase.SWEEP


func phase_id() -> String:
	match phase:
		Phase.SETUP:
			return "scout"
		Phase.WATCHING:
			return "alert"
		Phase.SWEEP:
			return "sweep"
		Phase.FAILED:
			return "fail"
		Phase.WON:
			return "win"
		Phase.REPLAY:
			return "replay"
		_:
			return ""


func wave_index() -> int:
	return raid.wave_index if raid else 0


func wave_total() -> int:
	return raid.wave_count(level) if raid else 1


func _wipe_squad_inventory() -> void:
	for op in operators:
		if op:
			op.wipe_inventory()
			op.reset_loadout()


func _place_squad_insert() -> void:
	if level == null or grid == null:
		return
	for i in operators.size():
		var op: OperatorUnit = operators[i]
		if op.slot != null:
			continue
		var cell: Vector2i = level.insert_cell_for(i)
		if grid.is_blocked(cell.x, cell.y):
			cell = RaidPathfinderScript.nearest_open(grid, cell)
		op.visible = true
		op.alive = true
		op.slot = null
		op.unlock_plan()
		op.stop_move()
		op.global_position = grid.cell_to_world_center(cell)
		op.set_facing(0.0 if i == 0 else (90.0 if i == 1 else 180.0))


func _clear_stashes() -> void:
	for s in raid_stashes:
		if s != null and is_instance_valid(s):
			s.queue_free()
	raid_stashes.clear()
	for n in get_tree().get_nodes_in_group("stash"):
		if is_instance_valid(n):
			n.queue_free()


func _clear_raid_throwables() -> void:
	for g in raid_grenades:
		if g != null and is_instance_valid(g):
			g.queue_free()
	raid_grenades.clear()
	for m in raid_mines:
		if m != null and is_instance_valid(m):
			m.queue_free()
	raid_mines.clear()
	for d in raid_decoys:
		if d != null and is_instance_valid(d):
			d.queue_free()
	raid_decoys.clear()


func _spawn_level_stashes() -> void:
	_clear_stashes()
	if level == null or grid == null:
		return
	var gs = get_node_or_null("/root/GameSettings")
	var lean := gs != null and bool(gs.get("few_crates"))
	var used: Dictionary = {}
	for spec in level.stashes:
		if not spec is Dictionary:
			continue
		var authored := str(spec.get("kind", ""))
		if lean and authored in ["ammo", "pistol"]:
			continue
		var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
		if grid.is_blocked(cell.x, cell.y):
			cell = RaidPathfinderScript.nearest_open(grid, cell)
		if cell.x < 0:
			continue
		var key := "%d,%d" % [cell.x, cell.y]
		if used.has(key):
			cell = RaidPathfinderScript.nearest_open(grid, Vector2i(cell.x + 1, cell.y))
			key = "%d,%d" % [cell.x, cell.y]
			if cell.x < 0 or used.has(key):
				continue
		used[key] = true
		var kind := WeaponCatalogScript.resolve_crate_kind(authored, str(level.level_id), raid_stashes.size())
		var amount := int(spec.get("amount", 1))
		if WeaponCatalogScript.is_firearm(kind):
			var d: Dictionary = WeaponCatalogScript.def(kind)
			var mx := int(d.get("max_ammo", amount))
			if mx > 0:
				amount = clampi(amount, 1, mx)
		var st = RaidStashScript.new()
		st.name = "Stash"
		entities.add_child(st)
		st.global_position = grid.cell_to_world_center(cell)
		st.setup(kind, amount, cell)
		raid_stashes.append(st)
	_ping_first_crate()
	_cap_stashes()
	_refresh_stash_board()


func _command_move_selected(world_pos: Vector2) -> void:
	if selected == null or not selected.visible or not selected.alive:
		return
	if selected.locked:
		return
	var from_c := selected.grid_cell()
	var to_c := grid.world_to_cell(world_pos)
	var stash_c := _stash_cell_near(to_c, 1)
	if stash_c.x >= 0:
		to_c = stash_c
	elif _cell_taken(to_c, selected):
		to_c = _open_cell_near(to_c, selected)
	var cells: Array[Vector2i] = RaidPathfinderScript.find_path(grid, from_c, to_c)
	if cells.is_empty():
		status_label.text = "走不过去"
		return
	if selected.slot:
		selected.slot.occupied_by = null
		selected.slot.set_highlight(false)
		selected.slot = null
	var pts := PackedVector2Array()
	pts.append(selected.global_position)
	for c in cells:
		pts.append(grid.cell_to_world_center(c))
	selected.set_move_path(pts)
	_draw_move_ghost(pts)
	_fade_move_ghost()
	status_label.text = "%s 移动" % selected.display_name
	_sfx("ui")


func _draw_move_ghost(pts: PackedVector2Array) -> void:
	if _move_ghost == null or not is_instance_valid(_move_ghost):
		_move_ghost = Line2D.new()
		_move_ghost.name = "MoveGhost"
		_move_ghost.width = 2.0
		_move_ghost.default_color = Color(0.72, 0.88, 0.42, 0.55)
		_move_ghost.z_index = 2
		$World.add_child(_move_ghost)
	_move_ghost.points = pts
	_move_ghost.visible = pts.size() > 1
	_move_ghost.modulate.a = 1.0


func _fade_move_ghost() -> void:
	if _move_ghost == null or not is_instance_valid(_move_ghost):
		return
	var tw := _move_ghost.create_tween()
	tw.tween_interval(0.28)
	tw.tween_property(_move_ghost, "modulate:a", 0.22, 0.90)


func _tick_command_moves(delta: float) -> void:
	for op in operators:
		if op == null or not op.visible or not op.alive:
			continue
		var moving := op.tick_move(delta)
		if not moving:
			_snap_op_to_cover_if_clicked(op)
		_tick_haul_follow(op)
	if selected and not selected.is_moving() and _move_ghost:
		_move_ghost.visible = false
	_follow_selected_cam(delta)


func _snap_op_to_cover_if_clicked(op: OperatorUnit) -> void:
	## Only mount a pad if the operator stopped on that pad's cell (clicked it / walked onto it).
	## Walking past a nearby cover no longer auto-snaps.
	if op.slot != null:
		return
	var slot := _nearest_slot(op.global_position, 8.0)
	if slot == null or (slot.occupied_by != null and slot.occupied_by != op):
		return
	var dest := op.grid_cell()
	var pad := grid.world_to_cell(slot.global_position)
	if dest != pad:
		return
	var prev: OperatorUnit = selected
	selected = op
	_deploy_selected_to(slot, false)
	selected = prev
	_refresh_selection_visual()


func _facing_toward_wave_route() -> float:
	if level == null or grid == null:
		return selected.facing_deg if selected else 90.0
	var specs: Array = raid.current_spawns(level) if raid else level.spawn_schedule
	if specs.is_empty():
		return selected.facing_deg if selected else 90.0
	var route := str(specs[0].get("route", "main"))
	var cells: Array = level.route_cells.get(route, [])
	if cells.size() < 2 or selected == null:
		return selected.facing_deg if selected else 90.0
	var a: Vector2 = grid.cell_to_world_center(cells[0])
	var b: Vector2 = grid.cell_to_world_center(cells[mini(1, cells.size() - 1)])
	var v: Vector2 = b - selected.global_position
	if v.length_squared() < 4.0:
		v = b - a
	return rad_to_deg(atan2(v.y, v.x))


func _follow_selected_cam(delta: float) -> void:
	if selected == null or not selected.visible or not selected.is_moving():
		return
	var center := Vector2(640, 360)
	var want: Vector2 = (selected.global_position - center) * 0.28
	_cam_pan = _cam_pan.lerp(want, 1.0 - exp(-delta * 4.6))
	_apply_cam()


func _snap_op_to_cover_if_near(op: OperatorUnit) -> void:
	_snap_op_to_cover_if_clicked(op)


func _tick_command_pickups(delta: float = 0.016) -> void:
	_tick_crate_search(delta)
	_try_pickup_near_selected()
	for loot in loot_piles.duplicate():
		if not is_instance_valid(loot) or loot.collected:
			continue
		_try_assign_loot(loot)
	loot_piles = loot_piles.filter(func(l: LootPickup) -> bool: return is_instance_valid(l) and not l.collected)


func _nearest_stash_for(op: OperatorUnit) -> Node2D:
	if op == null or not op.alive or not op.visible:
		return null
	var oc := op.grid_cell()
	var best: Node2D = null
	var best_d := 22.0
	for st in raid_stashes:
		if st == null or not is_instance_valid(st) or st.collected:
			continue
		if st.cell != oc:
			continue
		var d := op.global_position.distance_to(st.global_position)
		if d <= best_d:
			best_d = d
			best = st
	return best


func _complete_stash_search(op: OperatorUnit) -> bool:
	if op == null or not op.is_searching():
		return false
	var st: Node2D = op.search_stash
	op.cancel_search()
	if st == null or not is_instance_valid(st) or bool(st.collected):
		return false
	var kind := str(st.kind)
	var amount := int(st.amount)
	if op.has_method("pack_can_fit") and not op.pack_can_fit(kind, amount):
		status_label.text = "%s 背包满" % op.display_name
		_flash("背包满 · 丢掉或递给队友", Color(0.95, 0.62, 0.32))
		return false
	var item: Dictionary = st.take()
	if item.is_empty():
		return false
	var rec: Dictionary = op.receive_item(str(item.get("kind", "ammo")), int(item.get("amount", 1)))
	if not bool(rec.get("ok", false)) and bool(rec.get("full", false)):
		_spawn_loot_at(op.global_position + Vector2(18, 10), int(item.get("amount", 1)), str(item.get("kind", "ammo")))
		status_label.text = "%s 背包满，掉在脚下" % op.display_name
		_flash("背包满", Color(0.95, 0.62, 0.32))
		_update_role_cards()
		_update_hud()
		return true
	status_label.text = "%s %s" % [op.display_name, str(rec.get("text", "拾取"))]
	_sfx(_pickup_cue(str(item.get("kind", "ammo"))))
	_operator_bark(op, "crate")
	_flash(str(rec.get("text", "拾取")), Color(0.95, 0.82, 0.35))
	_update_role_cards()
	_update_hud()
	return true


func _tick_crate_search(delta: float) -> void:
	for op in operators:
		if op == null or not op.alive or not op.visible:
			continue
		if op.is_moving():
			op.cancel_search()
			continue
		var st := _nearest_stash_for(op)
		if st == null:
			op.cancel_search()
			continue
		if not op.is_searching() or op.search_stash != st:
			op.begin_search(st)
			status_label.text = "%s 开匣中…" % op.display_name
		if op.tick_search(delta):
			_complete_stash_search(op)
	raid_stashes = raid_stashes.filter(func(s) -> bool: return s != null and is_instance_valid(s) and not s.collected)


func _try_pickup_near_selected() -> void:
	## Starts a 0.4s crate channel if standing still on a stash. Completes via _tick_crate_search.
	for op in operators:
		if op == null or not op.alive or not op.visible or op.is_moving():
			continue
		var st := _nearest_stash_for(op)
		if st == null:
			continue
		if not op.is_searching() or op.search_stash != st:
			op.begin_search(st)


func raid_advance_search(seconds: float) -> int:
	## Headless helper: fast-forward crate channels without waiting real time.
	var n := 0
	var guard := 0
	var remain := maxf(seconds, 0.0)
	while remain > 0.0 and guard < 12:
		guard += 1
		var step := minf(remain, 0.4)
		remain -= step
		_tick_crate_search(step)
		n += 1
	raid_stashes = raid_stashes.filter(func(s) -> bool: return s != null and is_instance_valid(s) and not s.collected)
	return n


func _try_place_inventory_mine(world_pos: Vector2) -> void:
	if selected == null or not selected.alive:
		return
	if selected.mines <= 0:
		_try_place_tripwire(world_pos)
		return
	if selected.global_position.distance_to(world_pos) > 64.0:
		status_label.text = "走近再埋"
		return
	if selected.has_method("consume_mine"):
		if not selected.consume_mine():
			_try_place_tripwire(world_pos)
			return
	else:
		selected.mines -= 1
	var mine = RaidMineScript.new()
	entities.add_child(mine)
	mine.global_position = world_pos
	raid_mines.append(mine)
	status_label.text = "%s 埋雷 剩余%d" % [selected.display_name, selected.mines]
	_sfx("trip")
	_operator_bark(selected, "mine_ready")
	_update_hud()


func _throw_grenade_at_cursor() -> void:
	_throw_grenade_at(get_global_mouse_position())


func _throw_grenade_at(world_pos: Vector2) -> void:
	_throw_grenade_from(selected, world_pos)


func _throw_grenade_from(op: OperatorUnit, world_pos: Vector2) -> bool:
	if op == null or not op.alive or not op.visible:
		return false
	if op.grenades <= 0:
		if op == selected:
			status_label.text = "没有手雷"
		return false
	var d: Dictionary = WeaponCatalogScript.def("grenade")
	var max_r := float(d.get("throw_range", 160.0))
	var dest := world_pos
	if op.global_position.distance_to(dest) > max_r:
		dest = op.global_position + (dest - op.global_position).limit_length(max_r)
	if op.has_method("consume_grenade"):
		if not op.consume_grenade():
			return false
	else:
		op.grenades -= 1
	op.grenade_cd = float(d.get("auto_cd", 3.6))
	var g = RaidGrenadeScript.new()
	entities.add_child(g)
	var night := str(level.level_id) if level else ""
	var gvar := WeaponCatalogScript.grenade_variant_for(str(op.weapon_id), night)
	g.setup(op.global_position, dest, float(d.get("fuse", 0.55)), float(d.get("radius", 78.0)), float(d.get("damage", 78.0)), gvar)
	g.detonated.connect(_on_grenade_boom)
	raid_grenades.append(g)
	if op == selected:
		status_label.text = "%s 丢手雷 剩余%d" % [op.display_name, op.grenades]
	_sfx("ui")
	_update_hud()
	return true


func _place_nade_mark(world_pos: Vector2 = Vector2(INF, INF)) -> void:
	if selected == null or not selected.alive or not selected.visible:
		return
	if selected.grenades <= 0:
		status_label.text = "没有手雷"
		return
	if selected.has_nade_mark and not world_pos.is_finite():
		selected.clear_nade_mark()
		status_label.text = "雷点已撤"
		_flash("雷点已撤", Color(0.72, 0.70, 0.52))
		_update_hud()
		return
	var dest := world_pos if world_pos.is_finite() else _throw_ahead(110.0)
	var d: Dictionary = WeaponCatalogScript.def("grenade")
	var max_r := float(d.get("throw_range", 160.0))
	if selected.global_position.distance_to(dest) > max_r:
		dest = selected.global_position + (dest - selected.global_position).limit_length(max_r)
	selected.set_nade_mark(dest)
	status_label.text = "%s 雷点 · 警报自动丢" % selected.display_name
	_flash("雷点已设 · 警报自动丢", Color(0.95, 0.72, 0.32))
	_sfx("ui")
	_update_hud()


func _toggle_auto_grenade() -> void:
	if selected == null:
		return
	selected.auto_grenade = not selected.auto_grenade
	var on := selected.auto_grenade
	status_label.text = "%s 自动手雷 %s" % [selected.display_name, "开" if on else "关"]
	_flash(status_label.text, Color(0.95, 0.72, 0.32) if on else Color(0.62, 0.58, 0.48))
	_update_hud()


func _grenade_ff_hit(op: OperatorUnit, dest: Vector2, radius: float) -> bool:
	var mul := 0.55
	var d: Dictionary = WeaponCatalogScript.def("grenade")
	mul = float(d.get("ff_radius_mul", 0.55))
	for other in operators:
		if other == null or other == op or not other.alive or not other.visible:
			continue
		if other.global_position.distance_to(dest) <= radius * mul:
			return true
	return false


func _auto_grenade_dest(op: OperatorUnit) -> Vector2:
	var d: Dictionary = WeaponCatalogScript.def("grenade")
	var max_r := float(d.get("throw_range", 160.0))
	var radius := float(d.get("radius", 78.0))
	var half := float(d.get("cone_half_deg", 52.0))
	if op.has_nade_mark:
		var n := 0
		for e in enemies:
			if e != null and e.alive and e.active and e.global_position.distance_to(op.nade_mark) <= radius:
				n += 1
		if n > 0 and not _grenade_ff_hit(op, op.nade_mark, radius):
			return op.nade_mark
		return Vector2(INF, INF)
	var best: EnemyRunner = null
	var best_n := 0
	for e in enemies:
		if e == null or not e.alive or not e.active:
			continue
		var dist := op.global_position.distance_to(e.global_position)
		if dist > max_r:
			continue
		if op.has_method("in_throw_cone") and not op.in_throw_cone(e.global_position, half):
			continue
		var cluster := 0
		for o in enemies:
			if o != null and o.alive and o.global_position.distance_to(e.global_position) <= radius * 0.7:
				cluster += 1
		if cluster > best_n:
			best_n = cluster
			best = e
	if best == null:
		return Vector2(INF, INF)
	if _grenade_ff_hit(op, best.global_position, radius):
		return Vector2(INF, INF)
	return best.global_position


func _tick_auto_grenades(_dt: float) -> void:
	if phase != Phase.WATCHING:
		return
	for op in operators:
		if op == null or not op.alive or not op.visible:
			continue
		if not bool(op.auto_grenade):
			continue
		if op.grenades <= 0 or op.grenade_cd > 0.0:
			continue
		var dest := _auto_grenade_dest(op)
		if not dest.is_finite():
			continue
		if _throw_grenade_from(op, dest):
			_operator_bark(op, "mine_ready")


func _toggle_backpack() -> void:
	if backpack_panel == null:
		return
	if backpack_panel.is_open():
		backpack_panel.dismiss()
		return
	if selected == null:
		return
	backpack_panel.present(selected)


func _refresh_backpack_if_open() -> void:
	if backpack_panel != null and backpack_panel.is_open() and selected != null:
		backpack_panel.refresh(selected)


func _on_pack_equip(kind: String) -> void:
	if selected == null:
		return
	var rec: Dictionary = selected.equip_from_pack(kind)
	status_label.text = str(rec.get("text", ""))
	if bool(rec.get("ok", false)):
		_sfx("loot")
		_flash(str(rec.get("text", "")), Color(0.82, 0.92, 0.45))
	_refresh_backpack_if_open()
	_update_role_cards()
	_update_hud()


func _on_pack_pass(kind: String) -> void:
	if selected == null:
		return
	var best: OperatorUnit = null
	var best_d := 56.0
	for op in operators:
		if op == null or op == selected or not op.visible or not op.alive:
			continue
		var d := selected.global_position.distance_to(op.global_position)
		if d <= best_d:
			best_d = d
			best = op
	if best == null:
		status_label.text = "走近队友再递装"
		return
	var rec: Dictionary = selected.transfer_to(best, kind)
	status_label.text = str(rec.get("text", "递装"))
	if bool(rec.get("ok", false)):
		_sfx("loot")
		_flash(str(rec.get("text", "")), Color(0.82, 0.92, 0.45))
	_refresh_backpack_if_open()
	_update_role_cards()
	_update_hud()


func _on_pack_drop(kind: String) -> void:
	if selected == null:
		return
	var rec: Dictionary = selected.drop_from_pack(kind)
	if not bool(rec.get("ok", false)):
		status_label.text = str(rec.get("text", "丢不掉"))
		return
	_spawn_loot_at(selected.global_position + Vector2(16, 12), int(rec.get("amount", 1)), str(rec.get("kind", kind)))
	status_label.text = str(rec.get("text", "丢掉"))
	_sfx("ui")
	_refresh_backpack_if_open()
	_update_role_cards()
	_update_hud()


func _on_grenade_boom(pos: Vector2, radius: float, damage: float) -> void:
	_sfx("barrel")
	_shake_for_explosion(pos)
	if entities:
		CombatFxScript.grenade_scorch(entities, pos)
	for e in enemies:
		if e != null and is_instance_valid(e) and e.alive:
			if e.global_position.distance_to(pos) <= radius:
				e.apply_fire(damage, selected)
	for op in operators:
		if op != null and op.alive and op.global_position.distance_to(pos) <= radius * 0.55:
			op.take_damage(damage * 0.35, pos)
			_night_hp_lost = true
	if phase == Phase.WATCHING:
		_check_win()


func _throw_decoy_at_cursor() -> void:
	_throw_decoy_at(get_global_mouse_position())


func _throw_decoy_at(world_pos: Vector2) -> void:
	if selected == null or not selected.alive:
		return
	if selected.decoys <= 0:
		status_label.text = "没有诱饵"
		return
	if selected.has_method("consume_decoy"):
		if not selected.consume_decoy():
			return
	else:
		selected.decoys -= 1
	var d = RaidDecoyScript.new()
	entities.add_child(d)
	d.global_position = world_pos
	d.setup()
	raid_decoys.append(d)
	status_label.text = "%s 诱饵" % selected.display_name
	_sfx("ui")


func _tick_raid_grenades(dt: float) -> void:
	for g in raid_grenades.duplicate():
		if g == null or not is_instance_valid(g):
			continue
		g.sim_step(dt)
	raid_grenades = raid_grenades.filter(func(n) -> bool: return n != null and is_instance_valid(n) and not n.spent())


func _tick_raid_mines() -> void:
	for m in raid_mines:
		if m != null and is_instance_valid(m) and m.has_method("sim_check"):
			var victim: EnemyRunner = m.sim_check(enemies)
			if victim != null:
				battle_log.add_event(sim.tick, "mine", victim.label_id, -1, m.global_position)
				_sfx("trip")
				_announce_payoff("trip", {"enemy_id": victim.label_id}, m.global_position)
	raid_mines = raid_mines.filter(func(n) -> bool: return n != null and is_instance_valid(n) and not bool(n.spent))


func _tick_raid_decoys(dt: float) -> void:
	for d in raid_decoys:
		if d != null and is_instance_valid(d) and d.has_method("sim_step"):
			d.sim_step(dt, enemies)
	raid_decoys = raid_decoys.filter(func(n) -> bool: return n != null and is_instance_valid(n) and not bool(n.spent))


func _enter_sweep() -> void:
	phase = Phase.SWEEP
	if raid:
		raid.mark_wave_cleared()
	for op in operators:
		if op:
			op.unlock_plan()
			op.stop_move()
			if op.alive and op.visible:
				op.hp = minf(op.hp + 10.0, OperatorUnit.MAX_HP)
				op._update_hp_bar()
				op._refresh_tag()
	alarm_button.disabled = false
	clear_button.disabled = false
	tool_button.disabled = false
	if pause_button:
		pause_button.disabled = true
	if speed_button:
		speed_button.disabled = true
	_set_watch_view_buttons(false)
	_refresh_alarm_cta()
	var last: bool = raid != null and raid.is_last_wave(level)
	if last:
		_flash("打扫战场 · 空格撤离封锁", Color(0.85, 0.92, 0.45))
		status_label.text = "最后一波已清。走近尸体搜刮，空格撤离。"
	else:
		_flash("打扫战场 · 空格下一波", Color(0.95, 0.82, 0.38))
		status_label.text = "本波已清。搜刮掉落，空格拉下一波警报。"
	_sfx("ui")
	if selected:
		_operator_bark(selected, "sweep")
	_build_spawn_ghosts()
	_sfx("tension")
	_update_hud()


func _on_sweep_commit() -> void:
	if phase != Phase.SWEEP:
		return
	if raid != null and raid.is_last_wave(level):
		_extract_win()
		return
	_begin_next_wave()


func _begin_next_wave() -> void:
	if raid:
		raid.advance_wave()
	run_id += 1
	var this_run := run_id
	phase = Phase.WATCHING
	sim.reset()
	_watch_first_fire = false
	_watch_first_return = false
	_kill_combo = 0
	pending_result = ""
	fail_reason = ""
	_sfx("alarm" if (raid != null and raid.wave_index <= 0) else "alarm_stinger")
	_alarm_edge_flash()
	alarm_button.disabled = true
	clear_button.disabled = true
	if pause_button:
		pause_button.disabled = false
	if speed_button:
		speed_button.disabled = false
	for op in operators:
		if op.visible and op.alive:
			op.lock_plan()
			if op.fire_mode == OperatorUnit.FireMode.HOLD_FOR_AMBUSH:
				op.arm_ambush()
	_queue_spawns(this_run)
	_set_watch_view_buttons(true)
	status_label.text = "警报 · 第%d波" % (raid.wave_index + 1 if raid else 1)
	_update_hud()


func _extract_win() -> void:
	phase = Phase.WON
	battle_log.mark_terminal(sim.tick, "win")
	_ensure_watch_cinema()
	if _watch_letterbox:
		_watch_letterbox.visible = true
	_flash("零逃逸 · 撤离封锁", Color(0.45, 0.9, 0.45))
	_sfx("win")
	_win_stinger()
	_camera_punch()
	pending_result = "win"
	_flush_pending_result()


func _refresh_alarm_cta() -> void:
	if alarm_button == null:
		return
	match phase:
		Phase.SETUP:
			if squad_has_firearm():
				alarm_button.text = "拉警报"
			elif _alarm_warned_no_gun:
				alarm_button.text = "强拉警报"
			else:
				alarm_button.text = "需枪"
			alarm_button.disabled = _living_ops() < 1
		Phase.SWEEP:
			if raid and raid.is_last_wave(level):
				alarm_button.text = "撤离封锁"
			else:
				alarm_button.text = "下一波警报"
			alarm_button.disabled = false
		Phase.WATCHING:
			alarm_button.text = "警报中"
			alarm_button.disabled = true
		_:
			alarm_button.disabled = true


func raid_prepare_ref(slots: Array, facings: Array, extra: Dictionary = {}) -> void:
	## Smoke/reference: grant role firearms, optional mines, snap to covers.
	if operators.size() < 3:
		return
	operators[0].receive_item("rifle", 7)
	operators[1].receive_item("mg", 12)
	operators[2].receive_item("scout", 6)
	var g := int(extra.get("grenades", 1))
	var m := int(extra.get("mines", 1))
	for op in operators:
		if g > 0:
			op.receive_item("grenade", g)
		if m > 0:
			op.receive_item("mine", m)
	for i in slots.size():
		_select_op(i)
		_deploy_selected_to(cover_slots[int(slots[i])])
		selected.set_facing(float(facings[i]))
	_select_op(0)
	_update_hud()


func _ping_first_crate() -> void:
	if raid_stashes.is_empty():
		return
	var best = null
	for st in raid_stashes:
		if st == null or not is_instance_valid(st):
			continue
		if WeaponCatalogScript.is_firearm(str(st.kind)):
			best = st
			break
	if best == null:
		best = raid_stashes[0]
	CombatFxScript.select_ping(best, best.global_position, WeaponCatalogScript.color(str(best.kind)))
	if level != null and str(level.level_id) == "yard":
		_flash("先开这匣", Color(0.95, 0.82, 0.38))


func _raid_clock_text() -> String:
	var s := int(_night_timer)
	return "%d:%02d" % [int(s / 60.0), s % 60]


func _tick_hold_to_move(delta: float) -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs == null or not bool(gs.get("hold_to_move")):
		return
	if selected == null or not selected.alive or selected.locked:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	_hold_move_acc += delta
	if _hold_move_acc < 0.28:
		return
	_hold_move_acc = 0.0
	_command_move_selected(get_global_mouse_position())


func _tick_footsteps(delta: float) -> void:
	var loud := 0.0
	for op in operators:
		if op == null or not op.visible or not op.alive:
			continue
		if op.is_moving():
			loud = maxf(loud, op.noise_if_sprinting())
	if loud >= 0.8:
		_foot_acc += delta
		if _foot_acc >= 0.42:
			_foot_acc = 0.0
			_sfx("ui")
	else:
		_foot_acc = 0.0


func _cap_stashes() -> void:
	## Perf: never keep more than 12 live crate nodes.
	while raid_stashes.size() > 12:
		var extra = raid_stashes.pop_back()
		if extra != null and is_instance_valid(extra):
			extra.queue_free()


func _pickup_cue(kind: String) -> String:
	match kind:
		"grenade", "mine":
			return "trip"
		"decoy":
			return "ui"
		"mg", "rifle", "scout", "pistol", "shotgun":
			return "loot"
		_:
			return "loot"


func raid_grant_and_pickup(op_index: int, kind: String, amount: int = 1) -> bool:
	if op_index < 0 or op_index >= operators.size():
		return false
	var rec: Dictionary = operators[op_index].receive_item(kind, amount)
	return bool(rec.get("ok", false))


func squad_has_firearm() -> bool:
	for op in operators:
		if op == null or not op.visible or not op.alive:
			continue
		if WeaponCatalogScript.is_firearm(str(op.weapon_id)):
			return true
	return false


func raid_transfer(from_index: int, to_index: int, kind: String = "auto") -> Dictionary:
	if from_index < 0 or from_index >= operators.size() or to_index < 0 or to_index >= operators.size():
		return {"ok": false, "text": "索引"}
	var rec: Dictionary = operators[from_index].transfer_to(operators[to_index], kind)
	_update_role_cards()
	_update_hud()
	return rec


func _transfer_selected_to_nearest() -> void:
	if selected == null or not selected.alive:
		return
	var best: OperatorUnit = null
	var best_d := 56.0
	for op in operators:
		if op == null or op == selected or not op.visible or not op.alive:
			continue
		var d := selected.global_position.distance_to(op.global_position)
		if d <= best_d:
			best_d = d
			best = op
	if best == null:
		status_label.text = "走近队友再递装（T）"
		return
	var rec: Dictionary = selected.transfer_to(best, "auto")
	status_label.text = str(rec.get("text", "递装"))
	if bool(rec.get("ok", false)):
		_sfx("loot")
		_flash(str(rec.get("text", "递装")), Color(0.82, 0.92, 0.45))
	_update_role_cards()
	_update_hud()


func _throw_ahead(max_r: float) -> Vector2:
	if selected == null:
		return get_global_mouse_position()
	var rad := deg_to_rad(selected.facing_deg)
	return selected.global_position + Vector2(cos(rad), sin(rad)) * minf(max_r, 110.0)


func _toggle_haul_corpse() -> void:
	if selected == null or not selected.alive or not selected.visible:
		return
	if selected.has_method("is_hauling") and selected.is_hauling():
		_drop_hauled(selected)
		return
	var best: LootPickup = null
	var best_d := 36.0
	for loot in loot_piles:
		if loot == null or not is_instance_valid(loot) or loot.collected:
			continue
		var d := selected.global_position.distance_to(loot.global_position)
		if d <= best_d:
			best_d = d
			best = loot
	if best == null:
		status_label.text = "走近尸体再拖（H）"
		return
	selected.haul_loot(best)
	status_label.text = "%s 拖尸" % selected.display_name
	_sfx("ui")


func _drop_hauled(op: OperatorUnit) -> void:
	if op == null or not op.has_method("drop_hauled"):
		return
	op.drop_hauled()
	status_label.text = "%s 放下尸体" % op.display_name
	_sfx("ui")


func _tick_haul_follow(op: OperatorUnit) -> void:
	if op == null or not op.has_method("is_hauling") or not op.is_hauling():
		return
	op.sync_hauled()


func command_move_to_cell(op_index: int, cell: Vector2i) -> bool:
	if op_index < 0 or op_index >= operators.size():
		return false
	_select_op(op_index)
	_command_move_selected(grid.cell_to_world_center(cell))
	return selected != null and selected.is_moving()


func _stash_cell_near(cell: Vector2i, radius: int = 1) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 99
	for st in raid_stashes:
		if st == null or not is_instance_valid(st) or bool(st.collected):
			continue
		var c: Vector2i = st.cell
		var d: int = maxi(absi(c.x - cell.x), absi(c.y - cell.y))
		if d <= radius and d < best_d:
			best_d = d
			best = c
	return best


func named_crate_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for st in raid_stashes:
		if st == null or not is_instance_valid(st) or bool(st.collected):
			continue
		var k := str(st.kind)
		if WeaponCatalogScript.is_firearm(k) and not WeaponCatalogScript.is_class_firearm(k):
			out.append(k)
	return out


func _refresh_stash_board() -> void:
	if stash_board == null:
		return
	## Names live on crate tags + intel chip. Keep the label for dumps, off the chrome.
	var names: PackedStringArray = PackedStringArray()
	for k in named_crate_ids():
		names.append(WeaponCatalogScript.display_name(k))
	if names.is_empty():
		stash_board.text = "本夜匣  先走近木箱开盖"
	else:
		stash_board.text = "本夜枪  %s" % " · ".join(names)
	stash_board.visible = false


func stash_count() -> int:
	var n := 0
	for s in raid_stashes:
		if s != null and is_instance_valid(s) and not s.collected:
			n += 1
	return n


func living_loot_count() -> int:
	var n := 0
	for l in loot_piles:
		if l != null and is_instance_valid(l) and not l.collected:
			n += 1
	return n


func _cell_taken(cell: Vector2i, except_op: OperatorUnit = null) -> bool:
	for op in operators:
		if op == null or op == except_op or not op.visible or not op.alive:
			continue
		if op.grid_cell() == cell:
			return true
	return false


func _open_cell_near(cell: Vector2i, except_op: OperatorUnit = null) -> Vector2i:
	var open: Vector2i = RaidPathfinderScript.nearest_open(grid, cell)
	if not _cell_taken(open, except_op):
		return open
	for r in range(1, 5):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := Vector2i(cell.x + dx, cell.y + dy)
				if RaidPathfinderScript.walkable(grid, n) and not _cell_taken(n, except_op):
					return n
	return open


func raid_vacuum_loot() -> int:
	## Sweep helper: assign remaining piles to nearest living operators.
	var n := 0
	for loot in loot_piles.duplicate():
		if loot == null or not is_instance_valid(loot) or loot.collected:
			continue
		var best: OperatorUnit = null
		var best_d := INF
		for op in operators:
			if op == null or not op.visible or not op.alive:
				continue
			var d := op.global_position.distance_to(loot.global_position)
			if d < best_d:
				best_d = d
				best = op
		if best == null:
			continue
		var item := {"kind": loot.kind, "amount": loot.ammo_amount}
		loot.collect_item()
		best.receive_item(str(item.get("kind", "ammo")), int(item.get("amount", 1)))
		n += 1
	loot_piles = loot_piles.filter(func(l: LootPickup) -> bool: return is_instance_valid(l) and not l.collected)
	_update_hud()
	return n

