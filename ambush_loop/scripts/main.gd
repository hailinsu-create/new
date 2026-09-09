extends Node2D

## Ambush Loop — vertical slice coordinator (blueprint §3–§6).
## SETUP → Alarm freezes PlanState → WATCHING (SimClock) → FAIL/WIN + BattleLog.

enum Phase { SETUP, WATCHING, FAILED, WON, REPLAY }
enum Tool { DEPLOY, TRIPWIRE }
enum AppScreen { MENU, GAME }

const MAX_TRIPWIRES := 1
const TRIPWIRE_ROUTE_DIST := 24.0
const MAP_TOUCH_HIT_RADIUS := 40.0
const SNAPSHOT_EVERY := 6
const DEFAULT_PROGRESS_PATH := "user://ambush_loop.cfg"
const PROGRESS_PATH_SETTING := "application/config/ambush_progress_path"
const LEVEL_ORDER := ["yard", "warehouse", "pump"]
const SAVE_SCHEMA_VERSION := 2

var grid: AmbushGrid = AmbushGrid.new()
var phase: Phase = Phase.SETUP
var tool: Tool = Tool.DEPLOY
var loop_index: int = 1
var run_id: int = 0
var intel_paths: Array[PackedVector2Array] = []
var fail_reason: String = ""

var level: LevelDef = null
var level_index: int = 0
var sim: SimClock = SimClock.new()
var battle_log: BattleLog = BattleLog.new()
var last_plan: PlanState = PlanState.new()
var door_locked: bool = false
var plan_locked: bool = false

var cover_slots: Array[CoverSlot] = []
var operators: Array[OperatorUnit] = []
var selected: OperatorUnit = null
var enemies: Array[EnemyRunner] = []
var tripwires: Array[Tripwire] = []
var loot_piles: Array[LootPickup] = []

var pending_spawns: Array = [] # {id, route, delay, loot, spawned}
var route_world: Dictionary = {} # name -> PackedVector2Array
var escape_world: Vector2
var return_fire_fx: Array = []
var hud_tick: float = 0.0
var ambush_zone_poly: Polygon2D = null
var door_marker: Node2D = null
var all_spawns_done: bool = false
var pending_result: String = "" # "" | "fail" | "win" — build panel after tick events/snapshot
var progress_path: String = DEFAULT_PROGRESS_PATH
var save_store := AmbushSaveStore.new()
var save_state: Dictionary = {}
var best_stars: Dictionary = {}
var level_failures: Dictionary = {}
var last_stars := 0
var last_rating := ""
var settings_volume := 0.75
var haptics_enabled := true
var touch_feedback_enabled := true
var tutorial_seen := false
var test_mode := false
var app_screen: AppScreen = AppScreen.MENU
var tutorial_active := false
var tutorial_step := 0
var tutorial_watch_ticks := 0
var lifecycle_paused := false
var frontend_overlay: Control = null
var menu_panel: PanelContainer = null
var settings_panel: PanelContainer = null
var about_panel: PanelContainer = null
var confirm_panel: PanelContainer = null
var menu_title: Label = null
var menu_status: Label = null
var menu_continue_button: Button = null
var menu_new_button: Button = null
var menu_start_button: Button = null
var settings_volume_button: Button = null
var settings_haptics_button: Button = null
var settings_touch_button: Button = null
var settings_close_button: Button = null
var about_close_button: Button = null
var confirm_label: Label = null
var confirm_yes_button: Button = null
var confirm_no_button: Button = null
var frontend_active_button: Button = null
var frontend_touch_blocking := false
var frontend_return: String = "menu"
var confirm_action := ""
var audio_feedback: AmbushAudioFeedback = null
var frontend_background: ColorRect = null
var guide_layer: Control = null
var guide_panel: PanelContainer = null
var guide_title: Label = null
var guide_body: Label = null
var guide_step_label: Label = null
var guide_next_button: Button = null
var guide_skip_button: Button = null
var guide_highlight: Panel = null

@onready var map_draw: Node2D = $World/MapDraw
@onready var entities: Node2D = $World/Entities
@onready var ghosts: Node2D = $World/Ghosts
@onready var covers: Node2D = $World/Covers
@onready var routes_draw: Node2D = $World/RoutesDraw
@onready var escape_marker: Node2D = $World/EscapeMarker
@onready var title_label: Label = $HUD/Root/TopBar/Title
@onready var status_label: Label = $HUD/Root/TopBar/Status
@onready var intel_label: Label = $HUD/Root/TopBar/Intel
@onready var help_label: Label = get_node_or_null("HUD/Root/Help") as Label
@onready var result_panel: PanelContainer = $HUD/Root/ResultPanel
@onready var result_label: Label = $HUD/Root/ResultPanel/Margin/VBox/ResultLabel
@onready var battlefield_button: Button = $HUD/Root/ResultPanel/Margin/VBox/BattlefieldButton
@onready var continue_button: Button = $HUD/Root/ResultPanel/Margin/VBox/ContinueButton
@onready var touch_hud: TouchHUD = $HUD/TouchHUD

var speed_button: Button = null
var pause_button: Button = null
var mode_button: Button = null
var door_button: Button = null
var pack_button: Button = null
var alarm_button: Button = null
var clear_button: Button = null
var tool_button: Button = null
var event_log: Control = null
var level_label: Label = null
var tut_label: Label = null
var aim_mode: bool = false
var active_pointer_id: int = -1
var active_touch_target: int = 0 # 0=map/ignored, 1=HUD button, 2=result button
var active_result_button: Button = null
var safe_rect := Rect2()
var safe_area_source := "fallback"
var _safe_area_refresh_queued := false


func _ready() -> void:
	_resolve_progress_path()
	_resolve_optional_hud()
	_build_frontend_ui()
	audio_feedback = AmbushAudioFeedback.new()
	audio_feedback.name = "AudioFeedback"
	add_child(audio_feedback)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	battlefield_button.pressed.connect(_on_battlefield_view_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	result_panel.visible = false
	clear_button.text = "收回部署"
	tool_button.text = "工具: 部署队员"
	_load_progress()
	_load_level(LEVEL_ORDER[level_index], true, true)
	if test_mode:
		app_screen = AppScreen.GAME
		frontend_overlay.visible = false
	else:
		_show_main_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_pressed()
		return
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_reset_active_pointer_for_layout()
		if phase == Phase.WATCHING and not sim.paused:
			sim.toggle_pause()
			lifecycle_paused = true
			status_label.text = "应用已暂停，回到前台后点击“继续”观看。"
			_update_hud()
		return
	if what == NOTIFICATION_WM_SIZE_CHANGED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_queue_safe_area_refresh()
		if what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN:
			if lifecycle_paused and phase == Phase.WATCHING:
				status_label.text = "已暂停等待继续。计划仍然锁死。"
				_update_hud()


func _resolve_progress_path() -> void:
	var injected := str(ProjectSettings.get_setting(PROGRESS_PATH_SETTING, DEFAULT_PROGRESS_PATH))
	if injected.begins_with("user://") and not injected.is_empty():
		progress_path = injected
	else:
		progress_path = DEFAULT_PROGRESS_PATH
	test_mode = injected.begins_with("user://test/")


func _resolve_optional_hud() -> void:
	var root: Control = $HUD/Root
	touch_hud.build()
	alarm_button = touch_hud.alarm_button
	clear_button = touch_hud.clear_button
	tool_button = touch_hud.tripwire_button
	speed_button = touch_hud.speed_button
	pause_button = touch_hud.pause_button
	mode_button = touch_hud.mode_button
	door_button = touch_hud.door_button
	pack_button = touch_hud.pack_button
	touch_hud.card_selected.connect(_on_touch_card_selected)
	touch_hud.facing_requested.connect(_on_touch_facing)
	touch_hud.aim_requested.connect(_on_aim_pressed)
	touch_hud.tripwire_requested.connect(_toggle_tool)
	touch_hud.clear_requested.connect(_on_clear_pressed)
	touch_hud.mode_requested.connect(_on_mode_pressed)
	touch_hud.pack_requested.connect(_on_pack_pressed)
	touch_hud.door_requested.connect(_on_door_pressed)
	touch_hud.alarm_requested.connect(_on_alarm_pressed)
	touch_hud.pause_requested.connect(_on_pause_pressed)
	touch_hud.speed_requested.connect(_on_speed_pressed)
	touch_hud.log_requested.connect(_on_log_requested)
	touch_hud.safe_area_changed.connect(_on_safe_area_changed)
	touch_hud.safe_area_refresh_requested.connect(_queue_safe_area_refresh)
	event_log = get_node_or_null("HUD/Root/EventLog") as Control
	level_label = get_node_or_null("HUD/Root/TopBar/LevelLabel") as Label
	tut_label = get_node_or_null("HUD/Root/TutLabel") as Label
	help_label = get_node_or_null("HUD/Root/Help") as Label

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
		tut_label.offset_left = 16.0
		tut_label.offset_top = 118.0
		tut_label.offset_right = 690.0
		tut_label.offset_bottom = 108.0
		tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tut_label.add_theme_font_size_override("font_size", 13)
		tut_label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.65))
		tut_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tut_label)

	if help_label == null:
		help_label = Label.new()
		help_label.name = "Help"
		help_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		help_label.offset_left = 16.0
		help_label.offset_top = 916.0
		help_label.offset_right = 704.0
		help_label.offset_bottom = 938.0
		help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help_label.add_theme_font_size_override("font_size", 12)
		help_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.75))
		help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(help_label)
	_queue_safe_area_refresh()


func _frontend_button(parent: Control, text: String, name: String = "", min_size := Vector2(0, 96)) -> Button:
	var button := Button.new()
	button.text = text
	if not name.is_empty():
		button.name = name
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 22)
	button.focus_mode = Control.FOCUS_NONE
	button.add_to_group("frontend_button")
	parent.add_child(button)
	return button


func _frontend_label(parent: Control, text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _frontend_style(color := Color(0.045, 0.06, 0.085, 0.98), border := Color(0.25, 0.38, 0.48, 1.0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 24
	style.content_margin_top = 24
	style.content_margin_right = 24
	style.content_margin_bottom = 24
	return style


func _center_frontend_panel(panel: Control, panel_size: Vector2) -> void:
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = panel_size
	panel.position = (get_viewport_rect().size - panel_size) * 0.5


func _build_frontend_ui() -> void:
	frontend_overlay = Control.new()
	frontend_overlay.name = "FrontendOverlay"
	frontend_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	frontend_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	$HUD.add_child(frontend_overlay)
	frontend_background = ColorRect.new()
	frontend_background.name = "Background"
	frontend_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	frontend_background.color = Color(0.025, 0.04, 0.065, 0.99)
	frontend_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frontend_overlay.add_child(frontend_background)
	_build_menu_panel()
	_build_settings_panel()
	_build_about_panel()
	_build_confirm_panel()
	_build_guide_panel()
	settings_panel.visible = false
	about_panel.visible = false
	confirm_panel.visible = false
	guide_panel.visible = false


func _build_menu_panel() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.name = "MainMenu"
	menu_panel.add_theme_stylebox_override("panel", _frontend_style(Color(0.045, 0.07, 0.105, 0.99), Color(0.85, 0.55, 0.25, 0.9)))
	frontend_overlay.add_child(menu_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	menu_panel.add_child(body)
	menu_title = _frontend_label(body, "AMBUSH LOOP", 42, Color(0.95, 0.86, 0.68))
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _frontend_label(body, "警报之前，先赢一次", 22, Color(0.55, 0.78, 0.95))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_status = _frontend_label(body, "离线单机 · 中文首发 · 方案锁死后观看战斗", 16, Color(0.7, 0.76, 0.82))
	menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_start_button = _frontend_button(body, "开始游戏", "StartGame")
	menu_start_button.pressed.connect(_on_menu_start_pressed)
	menu_continue_button = _frontend_button(body, "继续", "ContinueGame")
	menu_continue_button.pressed.connect(_on_menu_continue_pressed)
	menu_new_button = _frontend_button(body, "新游戏", "NewGame")
	menu_new_button.pressed.connect(_on_menu_new_pressed)
	var settings_button := _frontend_button(body, "设置", "Settings")
	settings_button.pressed.connect(_show_settings)
	var about_button := _frontend_button(body, "关于 / 隐私", "AboutPrivacy")
	about_button.pressed.connect(_show_about)
	var hint := _frontend_label(body, "第一次玩：跟随高亮完成教学。失败会留下路线记忆，零逃逸才算胜利。", 16, Color(0.65, 0.72, 0.78))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_frontend_panel(menu_panel, Vector2(minf(620.0, get_viewport_rect().size.x - 32.0), 920.0))


func _build_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.add_theme_stylebox_override("panel", _frontend_style())
	frontend_overlay.add_child(settings_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	settings_panel.add_child(body)
	var title := _frontend_label(body, "设置", 32, Color(0.95, 0.86, 0.68))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_volume_button = _frontend_button(body, "音量", "VolumeSetting")
	settings_volume_button.pressed.connect(_cycle_volume)
	settings_haptics_button = _frontend_button(body, "震动：开", "HapticsSetting")
	settings_haptics_button.pressed.connect(_toggle_haptics)
	settings_touch_button = _frontend_button(body, "触控反馈：开", "TouchFeedbackSetting")
	settings_touch_button.pressed.connect(_toggle_touch_feedback)
	var language := _frontend_label(body, "语言：中文首发（首发版本不提供切换）", 18, Color(0.72, 0.78, 0.84))
	language.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_close_button = _frontend_button(body, "返回", "SettingsClose")
	settings_close_button.pressed.connect(_close_overlay_to_return)
	_center_frontend_panel(settings_panel, Vector2(minf(620.0, get_viewport_rect().size.x - 32.0), 700.0))


func _build_about_panel() -> void:
	about_panel = PanelContainer.new()
	about_panel.name = "AboutPrivacyPanel"
	about_panel.add_theme_stylebox_override("panel", _frontend_style())
	frontend_overlay.add_child(about_panel)
	var body := VBoxContainer.new()
	body.name = "AboutBody"
	body.add_theme_constant_override("separation", 14)
	about_panel.add_child(body)
	var title := _frontend_label(body, "关于 / 隐私", 32, Color(0.95, 0.86, 0.68))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var copy := _frontend_label(body, "Ambush Loop 是离线单机的计划与观看游戏。进度、失败路线、计划、评价和设置只保存在本机。\n\n当前版本没有广告、分析或联网功能，也不会把你的数据上传到服务器。\n\n版本 0.1.0\n正式发行页面会提供支持渠道和完整隐私政策。", 18, Color(0.78, 0.82, 0.86))
	copy.name = "PrivacyCopy"
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	about_close_button = _frontend_button(body, "返回", "AboutClose")
	about_close_button.pressed.connect(_close_overlay_to_return)
	_center_frontend_panel(about_panel, Vector2(minf(650.0, get_viewport_rect().size.x - 32.0), 760.0))


func _build_confirm_panel() -> void:
	confirm_panel = PanelContainer.new()
	confirm_panel.name = "ConfirmPanel"
	confirm_panel.add_theme_stylebox_override("panel", _frontend_style(Color(0.08, 0.055, 0.05, 0.99), Color(0.9, 0.35, 0.25, 0.9)))
	frontend_overlay.add_child(confirm_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	confirm_panel.add_child(body)
	confirm_label = _frontend_label(body, "确定吗？", 24, Color(0.95, 0.86, 0.68))
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	confirm_yes_button = _frontend_button(row, "确认", "ConfirmYes", Vector2(0, 96))
	confirm_yes_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_yes_button.pressed.connect(_confirm_yes)
	confirm_no_button = _frontend_button(row, "取消", "ConfirmNo", Vector2(0, 96))
	confirm_no_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_no_button.pressed.connect(_confirm_no)
	_center_frontend_panel(confirm_panel, Vector2(minf(600.0, get_viewport_rect().size.x - 32.0), 300.0))


func _build_guide_panel() -> void:
	guide_layer = Control.new()
	guide_layer.name = "GuideLayer"
	guide_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	guide_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frontend_overlay.add_child(guide_layer)
	guide_highlight = Panel.new()
	guide_highlight.name = "GuideHighlight"
	guide_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var highlight_style := StyleBoxFlat.new()
	highlight_style.bg_color = Color(0.2, 0.85, 0.65, 0.12)
	highlight_style.border_width_left = 4
	highlight_style.border_width_top = 4
	highlight_style.border_width_right = 4
	highlight_style.border_width_bottom = 4
	highlight_style.border_color = Color(0.35, 0.95, 0.75, 0.9)
	guide_highlight.add_theme_stylebox_override("panel", highlight_style)
	guide_layer.add_child(guide_highlight)
	guide_panel = PanelContainer.new()
	guide_panel.name = "TutorialGuide"
	guide_panel.add_theme_stylebox_override("panel", _frontend_style(Color(0.04, 0.12, 0.16, 0.96), Color(0.25, 0.78, 0.95, 0.95)))
	guide_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	guide_layer.add_child(guide_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	guide_panel.add_child(body)
	guide_step_label = _frontend_label(body, "新手教学", 18, Color(0.55, 0.9, 1.0))
	guide_title = _frontend_label(body, "跟随高亮完成第一局", 24, Color(0.95, 0.86, 0.68))
	guide_body = _frontend_label(body, "", 18, Color(0.84, 0.9, 0.94))
	guide_next_button = _frontend_button(body, "知道了", "GuideNext", Vector2(0, 96))
	guide_next_button.pressed.connect(_guide_next)
	guide_skip_button = _frontend_button(body, "跳过教学", "GuideSkip", Vector2(0, 96))
	guide_skip_button.pressed.connect(_guide_skip)
	_center_frontend_panel(guide_panel, Vector2(minf(680.0, get_viewport_rect().size.x - 24.0), 430.0))


func _hide_frontend_panels() -> void:
	if menu_panel != null:
		menu_panel.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	if about_panel != null:
		about_panel.visible = false
	if confirm_panel != null:
		confirm_panel.visible = false
	if guide_layer != null:
		guide_layer.visible = false
	if frontend_background != null:
		frontend_background.visible = true


func _show_main_menu() -> void:
	app_screen = AppScreen.MENU
	frontend_return = "menu"
	_hide_frontend_panels()
	if frontend_overlay != null:
		frontend_overlay.visible = true
	if menu_panel != null:
		menu_panel.visible = true
	if frontend_background != null:
		frontend_background.visible = true
	$World.visible = false
	$HUD/Root.visible = false
	if menu_continue_button != null:
		menu_continue_button.disabled = not FileAccess.file_exists(progress_path)
	if menu_status != null:
		menu_status.text = "离线单机 · 中文首发 · 方案锁死后观看战斗"


func _enter_game_from_frontend(show_tutorial := false) -> void:
	app_screen = AppScreen.GAME
	frontend_return = "game"
	_hide_frontend_panels()
	if frontend_overlay != null:
		frontend_overlay.visible = false
	$World.visible = true
	$HUD/Root.visible = true
	_update_hud()
	if show_tutorial:
		_start_tutorial()


func _on_menu_start_pressed() -> void:
	if audio_feedback != null:
		audio_feedback.beep("select")
	_enter_game_from_frontend(not tutorial_seen)


func _on_menu_continue_pressed() -> void:
	if audio_feedback != null:
		audio_feedback.beep("select")
	_load_progress()
	_load_level(LEVEL_ORDER[level_index], true, true)
	_enter_game_from_frontend(false)


func _on_menu_new_pressed() -> void:
	confirm_action = "new_game"
	confirm_label.text = "清空当前记忆并从院子重新开始？"
	frontend_return = "menu"
	_hide_frontend_panels()
	confirm_panel.visible = true


func _show_settings() -> void:
	frontend_return = "menu" if app_screen == AppScreen.MENU else "game"
	_hide_frontend_panels()
	if frontend_overlay != null:
		frontend_overlay.visible = true
	settings_panel.visible = true
	_update_settings_labels()


func _show_about() -> void:
	frontend_return = "menu" if app_screen == AppScreen.MENU else "game"
	_hide_frontend_panels()
	if frontend_overlay != null:
		frontend_overlay.visible = true
	about_panel.visible = true


func _close_overlay_to_return() -> void:
	if frontend_return == "game":
		_enter_game_from_frontend(false)
	else:
		_show_main_menu()


func _update_settings_labels() -> void:
	if settings_volume_button != null:
		settings_volume_button.text = "音量：%d%%" % int(round(settings_volume * 100.0))
	if settings_haptics_button != null:
		settings_haptics_button.text = "震动：%s" % ("开" if haptics_enabled else "关")
	if settings_touch_button != null:
		settings_touch_button.text = "触控反馈：%s" % ("开" if touch_feedback_enabled else "关")


func _cycle_volume() -> void:
	var values := [0.0, 0.35, 0.7, 1.0]
	var next_index := 0
	for i in values.size():
		if settings_volume < float(values[i]) - 0.01:
			next_index = i
			break
		if i == values.size() - 1:
			next_index = 0
	settings_volume = float(values[next_index])
	if audio_feedback != null:
		audio_feedback.configure(settings_volume)
	_update_settings_labels()
	_save_progress()


func _toggle_haptics() -> void:
	haptics_enabled = not haptics_enabled
	_update_settings_labels()
	_save_progress()


func _toggle_touch_feedback() -> void:
	touch_feedback_enabled = not touch_feedback_enabled
	_update_settings_labels()
	_save_progress()


func _confirm_yes() -> void:
	if confirm_action == "new_game":
		level_index = 0
		loop_index = 1
		intel_paths.clear()
		last_plan.clear()
		best_stars.clear()
		level_failures.clear()
		tutorial_seen = false
		door_locked = false
		_load_level(LEVEL_ORDER[0], false, false)
		_save_progress()
		_enter_game_from_frontend(true)
	confirm_action = ""


func _confirm_no() -> void:
	confirm_action = ""
	_close_overlay_to_return()


func _start_tutorial() -> void:
	tutorial_active = true
	tutorial_step = 0
	tutorial_watch_ticks = 0
	if frontend_overlay != null:
		frontend_overlay.visible = true
	if frontend_background != null:
		frontend_background.visible = false
	if guide_layer != null:
		guide_layer.visible = true
	_update_tutorial()


func _update_tutorial() -> void:
	if guide_body == null:
		return
	var steps := [
		"先点队员卡，再点绿色掩体完成部署。",
		"用左右按钮调整射界；也可以进入点地图瞄准。",
		"需要时放置绊索、切换开火模式或准备弹包。",
		"准备完成后按红色警报。警报后计划锁死，只能观看。",
	]
	var idx := clampi(tutorial_step, 0, steps.size() - 1)
	guide_step_label.text = "新手教学  %d / %d" % [idx + 1, steps.size()]
	guide_body.text = steps[idx]
	guide_next_button.text = "完成" if idx == steps.size() - 1 else "下一步"
	var target: Control = null
	if touch_hud != null:
		match idx:
			0:
				if not touch_hud.card_buttons.is_empty():
					target = touch_hud.card_buttons[0]
			1:
				target = touch_hud.left_button
			2:
				target = touch_hud.tripwire_button
			3:
				target = touch_hud.alarm_button
	if target != null and target.is_visible_in_tree():
		var rect := target.get_global_rect().grow(8.0)
		guide_highlight.position = rect.position
		guide_highlight.size = rect.size
		guide_highlight.visible = true
	else:
		guide_highlight.visible = false


func _advance_tutorial_to(next_step: int) -> void:
	if not tutorial_active:
		return
	if next_step <= tutorial_step:
		return
	tutorial_step = mini(next_step, 3)
	_update_tutorial()


func _guide_next() -> void:
	tutorial_step += 1
	if tutorial_step >= 4:
		_guide_skip()
		return
	_update_tutorial()


func _guide_skip() -> void:
	tutorial_active = false
	tutorial_seen = true
	guide_layer.visible = false
	frontend_overlay.visible = false
	frontend_background.visible = true
	_save_progress()
	_update_hud()



func _on_viewport_size_changed() -> void:
	_queue_safe_area_refresh()


func _queue_safe_area_refresh() -> void:
	if _safe_area_refresh_queued:
		return
	_safe_area_refresh_queued = true
	call_deferred("_refresh_safe_area_layout")


func _refresh_safe_area_layout() -> void:
	_safe_area_refresh_queued = false
	if touch_hud == null:
		return
	var resolved := _collect_production_safe_rect()
	touch_hud.set_safe_rect(resolved.rect, str(resolved.source))


func _collect_production_safe_rect() -> Dictionary:
	var viewport_size := touch_hud.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = touch_hud.get_viewport_rect().size
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	if not TouchHUD.is_valid_safe_rect(viewport_rect):
		return {"rect": Rect2(), "source": "invalid_viewport_fallback"}

	var mobile := OS.get_name() == "Android" or OS.get_name() == "iOS"
	if not mobile:
		return {"rect": viewport_rect, "source": "non_mobile_fallback"}

	var display_safe_area := DisplayServer.get_display_safe_area()
	var display_rect := Rect2(Vector2(display_safe_area.position), Vector2(display_safe_area.size))
	if not TouchHUD.is_valid_safe_rect(display_rect):
		return {"rect": viewport_rect, "source": "invalid_display_fallback"}

	var screen_to_hud := touch_hud.get_screen_transform().affine_inverse()
	var mapped_safe_rect := TouchHUD.map_rect(display_rect, screen_to_hud)
	var clipped_safe_rect := mapped_safe_rect.intersection(viewport_rect)
	if not TouchHUD.is_valid_safe_rect(clipped_safe_rect):
		return {"rect": viewport_rect, "source": "offscreen_display_fallback"}
	return {"rect": clipped_safe_rect, "source": "display_safe_area"}


func _on_safe_area_changed(next_safe_rect: Rect2, source: String) -> void:
	safe_rect = next_safe_rect
	safe_area_source = source
	_reset_active_pointer_for_layout()
	_apply_safe_area_layout(next_safe_rect)
	print("MAIN_SAFE_AREA_LAYOUT source=%s safe_rect=%s" % [source, next_safe_rect])


func _reset_active_pointer_for_layout() -> void:
	active_pointer_id = -1
	active_touch_target = 0
	active_result_button = null
	frontend_active_button = null
	if touch_hud != null:
		touch_hud.clear_active_pointer()


func _apply_safe_area_layout(next_safe_rect: Rect2) -> void:
	var root: Control = $HUD/Root
	var viewport_size := root.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport_rect().size
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var effective_safe_rect := next_safe_rect.intersection(viewport_rect)
	if not TouchHUD.is_valid_safe_rect(effective_safe_rect):
		effective_safe_rect = viewport_rect
	var top_bar := get_node("HUD/Root/TopBar") as Control
	top_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_bar.position = Vector2(effective_safe_rect.position.x + 16.0, effective_safe_rect.position.y + 12.0)
	top_bar.size = Vector2(maxf(effective_safe_rect.size.x - 32.0, 1.0), 92.0)

	var tutorial_top := effective_safe_rect.position.y + 108.0
	var tutorial_bottom := minf(effective_safe_rect.end.y - 8.0, tutorial_top + 56.0)
	if tutorial_bottom <= tutorial_top:
		tutorial_bottom = tutorial_top + 1.0
	if tut_label != null:
		tut_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		tut_label.position = Vector2(effective_safe_rect.position.x + 16.0, tutorial_top)
		tut_label.size = Vector2(maxf(effective_safe_rect.size.x - 32.0, 1.0), tutorial_bottom - tutorial_top)

	var metrics := TouchHUD.layout_metrics(viewport_size, effective_safe_rect)
	var hud_panel_rect: Rect2 = metrics["panel_rect"]
	if help_label != null:
		var help_bottom := hud_panel_rect.position.y - 8.0
		var help_top := maxf(tutorial_bottom + 8.0, help_bottom - 40.0)
		if help_top >= help_bottom:
			help_top = maxf(effective_safe_rect.position.y, help_bottom - 1.0)
		help_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		help_label.position = Vector2(effective_safe_rect.position.x + 16.0, help_top)
		help_label.size = Vector2(maxf(effective_safe_rect.size.x - 32.0, 1.0), maxf(help_bottom - help_top, 1.0))

	var result_size := Vector2(
		minf(600.0, maxf(effective_safe_rect.size.x - 32.0, 1.0)),
		minf(420.0, maxf(effective_safe_rect.size.y - 32.0, 1.0))
	)
	result_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	result_panel.position = effective_safe_rect.position + (effective_safe_rect.size - result_size) * 0.5
	result_panel.size = result_size


func _make_hud_btn(p_name: String, text: String, parent: Control) -> Button:
	var b := Button.new()
	b.name = p_name
	b.text = text
	b.custom_minimum_size = Vector2(120, 32)
	parent.add_child(b)
	return b


func _on_touch_card_selected(index: int) -> void:
	if _plan_editable():
		_select_op(index)
		if touch_feedback_enabled and audio_feedback != null:
			audio_feedback.beep("select")
		if haptics_enabled:
			Input.vibrate_handheld(18)


func _input(event: InputEvent) -> void:
	if frontend_overlay != null and frontend_overlay.visible and event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		# The tutorial overlay only owns its own buttons. During the guide the
		# highlighted map and HUD remain live so the player can perform the step.
		var tutorial_touch := guide_layer != null and guide_layer.visible
		if not tutorial_touch or _frontend_button_at(touch.position) != null:
			_handle_frontend_screen_touch(touch)
			get_viewport().set_input_as_handled()
			return
	if not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.canceled:
		if touch.index == active_pointer_id:
			active_pointer_id = -1
			active_touch_target = 0
			active_result_button = null
			if touch_hud != null:
				touch_hud.cancel_screen_touch()
			get_viewport().set_input_as_handled()
		return
	if touch.pressed:
		if active_pointer_id != -1:
			get_viewport().set_input_as_handled()
			return
		active_pointer_id = touch.index
		active_touch_target = 0
		active_result_button = null
		if touch_hud != null and touch_hud.handle_screen_touch(touch.position, true):
			active_touch_target = 1
			get_viewport().set_input_as_handled()
			return
		if result_panel.visible:
			for button in [battlefield_button, continue_button]:
				if button.visible and not button.disabled and button.get_global_rect().has_point(touch.position):
					active_result_button = button
					active_touch_target = 2
					get_viewport().set_input_as_handled()
					return
		if phase == Phase.SETUP:
			_handle_setup_click(_screen_to_world(touch.position))
		get_viewport().set_input_as_handled()
		return
	# Release: activate only the button that claimed this pointer on press.
	if touch.index == active_pointer_id:
		if active_touch_target == 1 and touch_hud != null:
			touch_hud.handle_screen_touch(touch.position, false)
		elif active_touch_target == 2 and active_result_button != null:
			var button := active_result_button
			active_result_button = null
			if is_instance_valid(button) and button.visible and not button.disabled and button.get_global_rect().has_point(touch.position):
				button.emit_signal("pressed")
		active_pointer_id = -1
		active_touch_target = 0
		get_viewport().set_input_as_handled()


func _frontend_button_at(point: Vector2) -> Button:
	var buttons := get_tree().get_nodes_in_group("frontend_button")
	for i in range(buttons.size() - 1, -1, -1):
		var button := buttons[i] as Button
		if button != null and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
			return button
	return null


func _handle_frontend_screen_touch(touch: InputEventScreenTouch) -> void:
	if touch.canceled:
		frontend_active_button = null
		active_pointer_id = -1
		active_touch_target = 0
		return
	if touch.pressed:
		if frontend_active_button != null:
			return
		frontend_active_button = _frontend_button_at(touch.position)
		active_pointer_id = touch.index
		active_touch_target = 3
		return
	if touch.index != active_pointer_id:
		return
	var button := frontend_active_button
	frontend_active_button = null
	active_pointer_id = -1
	active_touch_target = 0
	if button != null and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(touch.position):
		button.emit_signal("pressed")


func _on_touch_facing(delta_deg: float) -> void:
	if _plan_editable() and selected != null and selected.visible:
		selected.rotate_by(delta_deg)
		_advance_tutorial_to(2)
		_update_hud()


func _on_log_requested() -> void:
	if touch_hud == null:
		return
	print("LOG_REQUEST open=%s return=%s phase=%s result_visible=%s active_pointer=%s" % [touch_hud.is_event_log_open(), touch_hud.is_log_return_to_result(), phase, result_panel.visible, active_pointer_id])
	if touch_hud.is_event_log_open():
		var return_to_result := touch_hud.is_log_return_to_result()
		touch_hud.close_event_log()
		if return_to_result and (phase == Phase.FAILED or phase == Phase.WON or phase == Phase.REPLAY):
			result_panel.visible = true
		return
	touch_hud.open_event_log(false)


func _on_battlefield_view_pressed() -> void:
	if not result_panel.visible or touch_hud == null:
		return
	result_panel.visible = false
	touch_hud.open_event_log(true)


func _on_aim_pressed() -> void:
	if not _plan_editable() or selected == null or not selected.visible:
		return
	aim_mode = not aim_mode
	if aim_mode:
		tool = Tool.DEPLOY
	status_label.text = "点地图设置 %s 朝向" % selected.display_name if aim_mode else "已取消点地图瞄准"
	_update_hud()


func _load_progress() -> void:
	save_state = save_store.load_state(progress_path)
	var id := str(save_state.get("level_id", "yard"))
	level_index = int(save_state.get("level_index", LEVEL_ORDER.find(id)))
	if level_index < 0:
		level_index = 0
	level_index = mini(level_index, LEVEL_ORDER.size() - 1)
	loop_index = maxi(1, int(save_state.get("loop", 1)))
	intel_paths.clear()
	for raw_path in save_state.get("intel_paths", []) as Array:
		if raw_path is PackedVector2Array and (raw_path as PackedVector2Array).size() >= 2:
			intel_paths.append(raw_path as PackedVector2Array)
	best_stars = save_state.get("best_stars", {}).duplicate(true)
	level_failures = save_state.get("failure_counts", {}).duplicate(true)
	var raw_plan: Dictionary = save_state.get("last_plan", {})
	last_plan.clear()
	last_plan.deployments = raw_plan.get("deployments", []).duplicate(true)
	var loaded_tripwire_positions: Array[Vector2] = []
	for raw_position in raw_plan.get("tripwire_positions", []) as Array:
		if raw_position is Vector2:
			loaded_tripwire_positions.append(raw_position as Vector2)
	last_plan.tripwire_positions = loaded_tripwire_positions
	last_plan.door_locked = bool(raw_plan.get("door_locked", false))
	door_locked = last_plan.door_locked
	tutorial_seen = bool(save_state.get("tutorial_seen", false))
	var settings: Dictionary = save_state.get("settings", {})
	settings_volume = clampf(float(settings.get("volume", 0.75)), 0.0, 1.0)
	haptics_enabled = bool(settings.get("haptics", true))
	touch_feedback_enabled = bool(settings.get("touch_feedback", true))
	if audio_feedback != null:
		audio_feedback.configure(settings_volume)


func _save_progress() -> int:
	_capture_plan()
	save_state = {
		"level_id": level.level_id if level else "yard",
		"level_index": level_index,
		"loop": loop_index,
		"intel_paths": intel_paths,
		"last_plan": {
			"deployments": last_plan.deployments,
			"tripwire_positions": last_plan.tripwire_positions,
			"door_locked": last_plan.door_locked,
		},
		"best_stars": best_stars,
		"failure_counts": level_failures,
		"tutorial_seen": tutorial_seen,
		"settings": {
			"volume": settings_volume,
			"haptics": haptics_enabled,
			"touch_feedback": touch_feedback_enabled,
			"language": "zh-CN",
		},
	}
	var save_error := save_store.save_state(save_state, progress_path)
	print("SAVE_PROGRESS_RESULT path=%s cfg_save=%s file_exists=%s note=%s" % [progress_path, save_error, FileAccess.file_exists(progress_path), save_store.last_note])
	if save_error != OK:
		push_error("SAVE_PROGRESS_FAILED path=%s error=%s" % [progress_path, save_error])
	return save_error


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
		level.door_blocks_route if (level.door_cell.x >= 0 and effective_door_locked) else ""
	)
	for e in geo_errs:
		push_error("LEVEL_GEO %s: %s" % [level.level_id, e])
	escape_world = grid.cell_to_world_center(level.escape_cell)
	escape_marker.position = escape_world
	map_draw.set("grid", grid)
	map_draw.queue_redraw()
	_build_route_world()
	_build_cover_slots()
	_build_operators()
	_draw_fixed_routes()
	_build_ambush_zone_visual()
	_build_door_marker()
	_start_setup(keep_intel, restore_plan)
	if touch_hud != null:
		touch_hud.close_event_log()


func _build_route_world() -> void:
	route_world.clear()
	for key in level.route_cells.keys():
		route_world[key] = _cells_to_world(level.route_cells[key])


func _cells_to_world(cells: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for c in cells:
		out.append(grid.cell_to_world_center(c as Vector2i))
	return out


func _all_routes() -> Array:
	var out: Array = []
	for key in route_world.keys():
		out.append(route_world[key])
	if door_locked and not level.alternate_route_cells.is_empty():
		out.append(_cells_to_world(level.alternate_route_cells))
	return out


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
		covers.add_child(slot)
		cover_slots.append(slot)
		id += 1


func _make_slot(id: int, text: String, pos: Vector2) -> CoverSlot:
	var s := CoverSlot.new()
	s.position = pos
	var pad := Polygon2D.new()
	pad.name = "Pad"
	pad.polygon = PackedVector2Array([
		Vector2(-18, -12), Vector2(-10, -18), Vector2(18, -12), Vector2(18, 12), Vector2(-10, 18), Vector2(-18, 12)
	])
	pad.color = Color(0.22, 0.58, 0.42, 0.42)
	s.add_child(pad)
	var edge := Line2D.new()
	edge.name = "CoverEdge"
	edge.width = 3.0
	edge.default_color = Color(0.56, 0.8, 0.66, 0.95)
	edge.points = PackedVector2Array([Vector2(-14, -12), Vector2(14, -12)])
	s.add_child(edge)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = text
	tag.position = Vector2(-40, 16)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(0.65, 0.85, 0.7))
	s.add_child(tag)
	s.setup(id, text, 0.0)
	return s


func _build_operators() -> void:
	for o in operators:
		if is_instance_valid(o):
			o.queue_free()
	operators.clear()
	var defs := [
		{"id": 1, "name": "队员甲"},
		{"id": 2, "name": "队员乙"},
		{"id": 3, "name": "队员丙"},
	]
	for d in defs:
		var op := _make_operator(int(d["id"]), str(d["name"]))
		entities.add_child(op)
		op.setup(int(d["id"]), str(d["name"]))
		op.died.connect(_on_operator_died)
		op.visible = false
		operators.append(op)
	selected = operators[0]
	_refresh_selection_visual()


func _make_operator(id: int, pname: String) -> OperatorUnit:
	var op := OperatorUnit.new()
	op.op_id = id
	op.display_name = pname
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(0, -13), Vector2(9, -3), Vector2(7, 11), Vector2(-7, 11), Vector2(-9, -3)
	])
	body.color = Color(0.2, 0.72, 0.72)
	op.add_child(body)
	var outline := Line2D.new()
	outline.name = "Outline"
	outline.width = 2.0
	outline.default_color = Color(0.78, 1.0, 0.94, 0.9)
	outline.points = PackedVector2Array([Vector2(0, -13), Vector2(9, -3), Vector2(7, 11), Vector2(-7, 11), Vector2(-9, -3), Vector2(0, -13)])
	op.add_child(outline)
	var weapon := Polygon2D.new()
	weapon.name = "Weapon"
	weapon.polygon = PackedVector2Array([Vector2(-2, -17), Vector2(2, -17), Vector2(2, -4), Vector2(-2, -4)])
	weapon.color = Color(0.82, 0.9, 0.88)
	op.add_child(weapon)
	var cone := Polygon2D.new()
	cone.name = "Cone"
	op.add_child(cone)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = pname
	tag.position = Vector2(-28, -30)
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	op.add_child(tag)
	return op


func _draw_fixed_routes() -> void:
	for c in routes_draw.get_children():
		c.queue_free()
	var colors := {
		"main": Color(0.9, 0.4, 0.35, 0.35),
		"flank": Color(0.95, 0.55, 0.2, 0.3),
	}
	var labels := {"main": "主路线", "flank": "侧翼路线"}
	for key in route_world.keys():
		var col: Color = colors.get(key, Color(0.7, 0.7, 0.4, 0.3))
		_add_route_line(route_world[key], col, str(labels.get(key, key)))
	if not level.alternate_route_cells.is_empty():
		_add_route_line(
			_cells_to_world(level.alternate_route_cells),
			Color(0.55, 0.4, 0.85, 0.28),
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
	var poly := Polygon2D.new()
	poly.name = "AmbushZone"
	var r := level.ambush_zone
	poly.polygon = PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x, 0),
		r.position + r.size,
		r.position + Vector2(0, r.size.y),
	])
	poly.color = Color(0.95, 0.85, 0.2, 0.12)
	routes_draw.add_child(poly)
	ambush_zone_poly = poly
	var tag := Label.new()
	tag.text = "伏击区"
	tag.position = r.position + Vector2(8, 4)
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35, 0.7))
	routes_draw.add_child(tag)


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
	pad.polygon = PackedVector2Array([
		Vector2(-10, -14), Vector2(10, -14), Vector2(10, 14), Vector2(-10, 14)
	])
	pad.color = Color(0.55, 0.4, 0.25, 0.7)
	n.add_child(pad)
	var tag := Label.new()
	tag.text = "门"
	tag.position = Vector2(-10, -28)
	tag.add_theme_font_size_override("font_size", 12)
	n.add_child(tag)
	routes_draw.add_child(n)
	door_marker = n
	_refresh_door_visual()


func _refresh_door_visual() -> void:
	if door_marker == null or not is_instance_valid(door_marker):
		return
	var pad := door_marker.get_node_or_null("Polygon2D") as Polygon2D
	if pad == null and door_marker.get_child_count() > 0:
		pad = door_marker.get_child(0) as Polygon2D
	if pad:
		pad.color = Color(0.85, 0.25, 0.2, 0.85) if door_locked else Color(0.55, 0.4, 0.25, 0.7)
	if door_button:
		door_button.text = "门: 锁闭 (B)" if door_locked else "门: 畅通 (B)"
		door_button.visible = level != null and level.door_cell.x >= 0


func _handle_back_pressed() -> void:
	if touch_hud != null and touch_hud.is_event_log_open():
		var return_to_result := touch_hud.is_log_return_to_result()
		touch_hud.close_event_log()
		if return_to_result:
			result_panel.visible = true
		return
	if frontend_overlay != null and frontend_overlay.visible:
		if guide_layer != null and guide_layer.visible:
			_guide_skip()
		elif menu_panel != null and menu_panel.visible:
			_save_progress()
			get_tree().quit()
		else:
			_close_overlay_to_return()
		return
	if phase == Phase.WATCHING:
		if not sim.paused:
			sim.toggle_pause()
			lifecycle_paused = true
			status_label.text = "已暂停。再次点击继续观看，计划仍然锁死。"
			_update_hud()
			return
		_save_progress()
		_show_main_menu()
		return
	_save_progress()
	_show_main_menu()


func _start_setup(keep_intel: bool, restore_plan: bool) -> void:
	phase = Phase.SETUP
	plan_locked = false
	tool = Tool.DEPLOY
	aim_mode = false
	active_pointer_id = -1
	fail_reason = ""
	pending_result = ""
	run_id += 1
	sim.reset()
	battle_log.clear()
	pending_spawns.clear()
	all_spawns_done = false
	_clear_enemies()
	_clear_tripwires()
	_clear_loot()
	_clear_return_fx()
	if not keep_intel:
		intel_paths.clear()
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
	if touch_hud != null:
		touch_hud.close_event_log()
	result_panel.visible = false
	_update_event_log()
	_update_hud()


func _on_clear_pressed() -> void:
	if not _plan_editable():
		return
	aim_mode = false
	_clear_deployments()
	status_label.text = "已收回部署（记忆与绊索保留）"
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


func _capture_plan() -> void:
	last_plan.clear()
	for op in operators:
		if op.visible and op.slot != null:
			last_plan.deployments.append({
				"op_id": op.op_id,
				"slot_id": op.slot.slot_id,
				"facing": op.facing_deg,
				"fire_mode": op.fire_mode,
				"has_ammo_pack": op.has_ammo_pack,
			})
	last_plan.tripwire_positions.clear()
	for t in tripwires:
		if is_instance_valid(t):
			last_plan.tripwire_positions.append(t.position)
	last_plan.door_locked = door_locked


func _restore_last_plan() -> void:
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
	status_label.text = "已恢复上轮计划（满血满弹）"


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
	if not _plan_editable():
		return
	aim_mode = false
	if tool == Tool.TRIPWIRE:
		if not tripwires.is_empty():
			_clear_tripwires()
			status_label.text = "已撤回绊索"
		else:
			status_label.text = "已取消绊索工具"
		tool = Tool.DEPLOY
	else:
		tool = Tool.TRIPWIRE
		status_label.text = "在路线线段附近放绊索（再点按钮可撤回）"
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_handle_back_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("reset_run"):
		# R is a preparation-only restart.  Consume it after the alarm as a
		# deliberate no-op so it cannot clear intel/plan or reopen SETUP.
		get_viewport().set_input_as_handled()
		if not _plan_editable():
			return
		loop_index = 1
		intel_paths.clear()
		last_plan.clear()
		_start_setup(false, false)
		return

	if phase == Phase.WATCHING:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_P, KEY_SPACE:
					_on_pause_pressed()
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

	if not _plan_editable():
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
			KEY_D, KEY_E:
				if selected and selected.visible:
					selected.rotate_by(15.0)
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
		_handle_setup_click(_screen_to_world(get_viewport().get_mouse_position()))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if selected and selected.visible and not selected.locked:
			var v := _screen_to_world(get_viewport().get_mouse_position()) - selected.global_position
			selected.set_facing(rad_to_deg(atan2(v.y, v.x)))
		get_viewport().set_input_as_handled()
		return


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _select_op(idx: int) -> void:
	if not _plan_editable() or idx < 0 or idx >= operators.size():
		return
	selected = operators[idx]
	tool = Tool.DEPLOY
	aim_mode = false
	tool_button.text = "工具: 部署队员"
	_refresh_selection_visual()
	_refresh_mode_pack_buttons()
	status_label.text = "已选择 %s（能力相同）— 点掩体部署，右键朝向" % selected.display_name
	_update_hud()


func _refresh_selection_visual() -> void:
	for op in operators:
		if op.body:
			op.body.color = Color(0.95, 0.85, 0.35) if op == selected and op.visible else Color(0.35, 0.65, 0.95)


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
	if not _plan_editable():
		return
	var map_rect := Rect2(AmbushGrid.WORLD_ORIGIN, Vector2(AmbushGrid.COLS * AmbushGrid.TILE, AmbushGrid.ROWS * AmbushGrid.TILE))
	if not map_rect.has_point(world_pos):
		return
	if aim_mode:
		if selected != null and selected.visible and not selected.locked:
			var to_point := world_pos - selected.global_position
			if to_point.length_squared() > 1.0:
				selected.set_facing(rad_to_deg(atan2(to_point.y, to_point.x)))
				aim_mode = false
				_advance_tutorial_to(2)
				status_label.text = "%s 已按地图点调整射界" % selected.display_name
				_update_hud()
		return
	if tool == Tool.TRIPWIRE:
		_try_place_tripwire(world_pos)
		return
	var slot := _nearest_slot(world_pos, MAP_TOUCH_HIT_RADIUS)
	if slot:
		_deploy_selected_to(slot, true)
		return
	for op in operators:
		if op.visible and op.global_position.distance_to(world_pos) <= 20.0:
			selected = op
			_refresh_selection_visual()
			_refresh_mode_pack_buttons()
			status_label.text = "已选择 %s" % op.display_name
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
	if not _plan_editable() or slot == null or selected == null:
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
	_advance_tutorial_to(1)
	if announce:
		status_label.text = "%s →「%s」弹%d 掩体减伤60%%" % [selected.display_name, slot.label_text, selected.ammo]
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
	_advance_tutorial_to(3)
	status_label.text = "绊索已埋伏"
	_update_hud()


func _near_any_route_segment(pos: Vector2, max_dist: float) -> bool:
	for route in _all_routes():
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
		Vector2(-10, -3), Vector2(10, -3), Vector2(10, 3), Vector2(-10, 3)
	])
	visual.color = Color(0.85, 0.8, 0.35)
	t.add_child(visual)
	return t


func _deployed_count() -> int:
	var n := 0
	for op in operators:
		if op.visible and op.slot != null:
			n += 1
	return n


func _on_mode_pressed() -> void:
	if not _plan_editable() or selected == null or not selected.visible:
		return
	selected.cycle_fire_mode()
	_advance_tutorial_to(3)
	_refresh_mode_pack_buttons()
	status_label.text = "%s 开火模式：%s" % [selected.display_name, selected.fire_mode_label()]
	_update_hud()


func _on_pack_pressed() -> void:
	if not _plan_editable() or level == null or not level.has_ammo_pack:
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
	_advance_tutorial_to(3)
	_refresh_mode_pack_buttons()
	_update_hud()


func _on_door_pressed() -> void:
	if not _plan_editable() or level == null or level.door_cell.x < 0:
		return
	door_locked = not door_locked
	grid.set_door_state(level.door_cell, door_locked)
	map_draw.queue_redraw()
	_refresh_door_visual()
	status_label.text = "门已锁闭 — 侧翼改走备用接近" if door_locked else "门保持畅通"
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
	if not _plan_editable():
		return
	if _deployed_count() < 1:
		status_label.text = "至少部署一名队员到掩体"
		return
	if tutorial_active:
		# The alarm is the final guided action. Close the overlay before the
		# locked watch phase so it cannot cover the battle or event log.
		_guide_skip()
	_capture_plan()
	aim_mode = false
	active_pointer_id = -1
	run_id += 1
	plan_locked = true
	var this_run := run_id
	phase = Phase.WATCHING
	sim.reset()
	battle_log.clear()
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
			op.lock_plan()
	if audio_feedback != null:
		audio_feedback.beep("alarm")
	battle_log.add_event(0, "door", -1, -1, Vector2.ZERO, {"locked": door_locked})
	_queue_spawns(this_run)
	status_label.text = "方案锁死 — 暂停/变速仅改变观看。跑掉或全灭均失败。"
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
	if door_locked and route_name == level.door_blocks_route and not level.alternate_route_cells.is_empty():
		return _cells_to_world(level.alternate_route_cells)
	if route_world.has(route_name):
		return route_world[route_name]
	# fallback first route
	for key in route_world.keys():
		return route_world[key]
	return PackedVector2Array()


func _spawn_one(spec: Dictionary) -> void:
	var e := _make_enemy(int(spec["id"]))
	entities.add_child(e)
	var route := _route_for_spawn(str(spec["route"]))
	e.setup(int(spec["id"]), route, grid, int(spec["loot"]))
	e.return_fired.connect(_on_return_fired)
	enemies.append(e)
	e.activate()
	battle_log.add_event(sim.tick, "spawn", e.label_id, -1, e.global_position)
	_update_event_log()


func _make_enemy(id: int) -> EnemyRunner:
	var e := EnemyRunner.new()
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([Vector2(0, -12), Vector2(10, -2), Vector2(7, 10), Vector2(-7, 10), Vector2(-10, -2)])
	body.color = Color(0.9, 0.32, 0.18)
	e.add_child(body)
	var outline := Line2D.new()
	outline.name = "Outline"
	outline.width = 2.0
	outline.default_color = Color(1.0, 0.76, 0.48, 0.9)
	outline.points = PackedVector2Array([Vector2(0, -12), Vector2(10, -2), Vector2(7, 10), Vector2(-7, 10), Vector2(-10, -2), Vector2(0, -12)])
	e.add_child(outline)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "敌%d" % id
	tag.position = Vector2(-12, -34)
	tag.add_theme_font_size_override("font_size", 12)
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
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(1.0, 0.55, 0.15, 0.85)
	line.points = PackedVector2Array([from.global_position, to.global_position])
	entities.add_child(line)
	return_fire_fx.append(line)
	if audio_feedback != null:
		audio_feedback.beep("enemy_fire")
	# Tween owned by the line so level reloads don't leave dangling captures.
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.2)
	tw.tween_callback(line.queue_free)


func _process(delta: float) -> void:
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

	# 4) Enemy move — escape commits in the same step the last waypoint is reached
	for enemy in enemies:
		if enemy.alive and enemy.active:
			enemy.sim_step(SimClock.TICK_DT)
		if phase != Phase.WATCHING:
			_finish_sim_tick()
			return

	# 5) Tripwire checks (fixed-step only; never from Tripwire._process)
	if phase == Phase.WATCHING:
		for tw in tripwires:
			if is_instance_valid(tw):
				tw.sim_check(enemies)
			if phase != Phase.WATCHING:
				_finish_sim_tick()
				return

	# 6) Operator fire — log confirmed shot before damage so terminal includes it
	if phase == Phase.WATCHING:
		for op in operators:
			if not op.visible or not op.locked or not op.alive:
				continue
			var best: EnemyRunner = null
			var best_d := INF
			for enemy in enemies:
				if not enemy.alive or not enemy.active:
					continue
				if not op.can_engage(enemy.global_position, grid):
					continue
				var d := op.global_position.distance_to(enemy.global_position)
				if d < best_d - 0.01 or (absf(d - best_d) <= 0.01 and best != null and enemy.label_id < best.label_id):
					best_d = d
					best = enemy
				elif best == null:
					best_d = d
					best = enemy
			if best != null and op.shot_cd <= 0.0 and op.can_engage(best.global_position, grid):
				battle_log.add_event(sim.tick, "fire", op.op_id, best.label_id, op.global_position)
				if op.try_fire(best, grid):
					_spawn_shot_fx(op.global_position, best.global_position, Color(0.28, 0.96, 0.82, 0.95))
					if audio_feedback != null:
						audio_feedback.beep("friendly_fire")
					if op.ammo <= 0:
						battle_log.add_event(sim.tick, "empty", op.op_id)
						if audio_feedback != null:
							audio_feedback.beep("empty")
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
	sim.advance()
	_flush_pending_result()


func _flush_pending_result() -> void:
	if pending_result == "fail":
		pending_result = ""
		_show_fail_result()
	elif pending_result == "win":
		pending_result = ""
		_show_win_result()

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
	return {"ops": ops, "enemies": ens}


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
			if audio_feedback != null:
				audio_feedback.beep("loot")
			status_label.text = "%s 搜刮 +%d弹" % [op.display_name, gained]
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
	intel_paths.append(path)
	_redraw_ghosts()
	if audio_feedback != null:
		audio_feedback.beep("escape")
	pending_result = "fail"


func _on_enemy_died(enemy: EnemyRunner) -> void:
	if phase != Phase.WATCHING and pending_result == "":
		return
	if phase == Phase.WATCHING or pending_result != "":
		battle_log.add_event(sim.tick, "kill", enemy.label_id)
	_spawn_loot_at(enemy.global_position, enemy.loot_ammo)
	if audio_feedback != null:
		audio_feedback.beep("hit")
	_update_event_log()


func _on_operator_died(op: OperatorUnit) -> void:
	if phase != Phase.WATCHING:
		return
	battle_log.add_event(sim.tick, "op_down", op.op_id)
	status_label.text = "%s 阵亡 — 敌军还击（需 LOS）" % op.display_name
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
			intel_paths.append(e.recorded.duplicate())
	_redraw_ghosts()
	if audio_feedback != null:
		audio_feedback.beep("fail")
	pending_result = "fail"


func _show_fail_result() -> void:
	result_panel.visible = true
	level_failures[level.level_id] = int(level_failures.get(level.level_id, 0)) + 1
	var lines := battle_log.summary_lines(10)
	var summary := "\n".join(lines)
	var reason_zh := "逃逸" if fail_reason == "escape" else "全灭"
	var fact := "有敌人走出封锁区；这条路线已留下为幽灵线。" if fail_reason == "escape" else "小队已失去全部战斗力；本轮计划会被保留。"
	var advice := "下一世可沿幽灵线补一名队员、收窄射界，或在路线前段放置绊索。" if fail_reason == "escape" else "下一世可调整到保护方向正确的掩体，缩短暴露射线，或改为入伏再打并准备弹包。"
	result_label.text = "第 %d 世失败（%s）。\n%s\n\n建议：%s\n\n穿梭后恢复上轮计划，满血满弹。\n\n—— 事件摘要 ——\n%s" % [loop_index, reason_zh, fact, advice, summary]
	continue_button.text = "带着情报穿梭回去"
	status_label.text = "%s — 穿梭" % reason_zh
	_update_event_log()
	_update_hud()
	_save_progress()


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
	pending_result = "win"


func _show_win_result() -> void:
	result_panel.visible = true
	last_stars = _calculate_stars()
	best_stars[level.level_id] = maxi(int(best_stars.get(level.level_id, 0)), last_stars)
	last_rating = "★".repeat(last_stars) + "☆".repeat(3 - last_stars)
	var lines := battle_log.summary_lines(8)
	var has_next := level_index + 1 < LEVEL_ORDER.size()
	if has_next:
		result_label.text = "零逃逸。埋伏成立。  %s\n用了 %d 世。\n\n%s\n\n—— 事件 ——\n%s" % [
			last_rating,
			loop_index, level.teaching, "\n".join(lines)
		]
		continue_button.text = "下一关"
	else:
		result_label.text = "全部关卡封锁完成。  %s\n总世数记忆保留于存档。\n\n%s" % [last_rating, "\n".join(lines)]
		continue_button.text = "再玩一局（清空记忆）"
	status_label.text = "计划奏效"
	if audio_feedback != null:
		audio_feedback.beep("success")
	_save_progress()
	_update_event_log()
	_update_hud()


func _calculate_stars() -> int:
	var survivors := _living_ops()
	if survivors >= 3:
		return 3
	if survivors >= 2:
		return 2
	return 1


func _spawn_shot_fx(from: Vector2, to: Vector2, color: Color) -> void:
	# Presentation is transient: combat has already been settled by SimClock.
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = color
	line.points = PackedVector2Array([from, to])
	line.z_index = 5
	entities.add_child(line)
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(0, -5), Vector2(5, 0), Vector2(0, 5)])
	flash.color = Color(1.0, 0.9, 0.55, 0.95)
	flash.global_position = to
	flash.z_index = 6
	entities.add_child(flash)
	var tw := line.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tw.tween_property(line, "modulate:a", 0.0, 0.12)
	tw.tween_callback(line.queue_free)
	var flash_tw := flash.create_tween()
	flash_tw.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	flash_tw.tween_property(flash, "scale", Vector2(1.9, 1.9), 0.08)
	flash_tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)
	flash_tw.tween_callback(flash.queue_free)


func _on_continue_pressed() -> void:
	# Result actions reopen a fresh preparation phase only from a terminal
	# result and only while the prior plan is still explicitly locked.
	if not plan_locked or (phase != Phase.FAILED and phase != Phase.WON and phase != Phase.REPLAY):
		return
	if phase == Phase.FAILED:
		loop_index += 1
		_start_setup(true, true)
	elif phase == Phase.WON:
		if level_index + 1 < LEVEL_ORDER.size():
			level_index += 1
			_load_level(LEVEL_ORDER[level_index], false, false)
			_save_progress()
		else:
			level_index = 0
			_load_level(LEVEL_ORDER[0], false, false)
			_save_progress()
	elif phase == Phase.REPLAY:
		_start_setup(true, true)


func _plan_editable() -> bool:
	return phase == Phase.SETUP and not plan_locked

func _redraw_ghosts() -> void:
	for c in ghosts.get_children():
		c.queue_free()
	var gi := 0
	var start_i := maxi(intel_paths.size() - 3, 0)
	for i in range(start_i, intel_paths.size()):
		var path: PackedVector2Array = intel_paths[i]
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.35, 0.75, 1.0, 0.55 - minf(0.15, float(gi) * 0.05))
		line.points = path
		ghosts.add_child(line)
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
	var lines := battle_log.summary_lines(14)
	if touch_hud != null:
		touch_hud.set_event_lines(lines)
		return
	if event_log == null:
		return
	var text := "[b]事件日志[/b]\n" + "\n".join(lines)
	if event_log is RichTextLabel:
		(event_log as RichTextLabel).text = text
	elif event_log is Label:
		(event_log as Label).text = "\n".join(lines)


func _update_hud() -> void:
	var lv_title := level.title if level else "AMBUSH LOOP"
	title_label.text = "AMBUSH LOOP  ·  第 %d 世" % loop_index
	if level_label:
		level_label.text = lv_title
	if tut_label and level:
		tut_label.text = level.tutorial if phase == Phase.SETUP else level.teaching
	intel_label.text = "漏网记忆：%d   |   %s" % [intel_paths.size(), _ammo_summary()]
	var dep := _deployed_count()
	if phase == Phase.SETUP:
		help_label.text = "准备：点掩体（%d/3）| 1/2/3选人 | A/D射界 | F开火模式 | G弹包 | B锁门 | Tab绊索\n空格拉警报。R清空记忆。「收回部署」只清空队员位。" % dep
	elif phase == Phase.WATCHING:
		var spd := "暂停" if sim.paused else ("2×" if sim.speed >= 1.5 else "1×")
		help_label.text = "锁死看戏 t=%.1fs [%s]：冷却独立；还击需LOS；伏击区触发入伏；搜尸最近+LOS。" % [sim.time_sec(), spd]
	elif phase == Phase.FAILED:
		help_label.text = "失败原因：%s。改朝向/掩体/开火条件后再警报。" % fail_reason
	elif phase == Phase.WON:
		help_label.text = "战前准备决定战斗。"
	elif phase == Phase.REPLAY:
		help_label.text = "复盘：只读事件，不重演模拟。"
	_refresh_door_visual()
	_refresh_mode_pack_buttons()
	if touch_hud != null:
		var card_data: Array = []
		var selected_index := -1
		for i in operators.size():
			var op: OperatorUnit = operators[i]
			var card := op.display_name
			if op.visible:
				card += "\n" + ("阵亡" if not op.alive else ("部署\n%d弹" % op.ammo))
			else:
				card += "\n空位"
			card_data.append(card)
			if op == selected:
				selected_index = i
		touch_hud.update_display(
			card_data,
			selected_index,
			phase == Phase.SETUP,
			phase == Phase.WATCHING,
			level != null and level.door_cell.x >= 0,
			door_locked,
			mode_button.text if mode_button != null else "开火模式",
			pack_button.text if pack_button != null else "弹包",
			("工具: 部署队员" if tool == Tool.DEPLOY else "工具: 绊索（再点撤回）"),
			aim_mode,
			sim.paused,
			sim.speed
		)
