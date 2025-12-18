@icon("res://icon.svg")
class_name CellularAutomataHub
extends Control

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const EDGE_WRAP: int = 0
const EDGE_BOUNCE: int = 1
const EDGE_FALLOFF: int = 2

const DRAW_MODE_PAINT: int = 0
const DRAW_MODE_ERASE: int = 1
const DRAW_MODE_TOGGLE: int = 2

var cell_size: int = 8
var grid_size: Vector2i = Vector2i.ZERO
var grid: PackedByteArray = PackedByteArray()

var alive_color: Color = Color.WHITE
var dead_color: Color = Color.BLACK

var edge_mode: int = EDGE_WRAP

var wolfram_rule: int = 30
var wolfram_row: int = 0
var wolfram_rate: float = 1.0
var wolfram_accumulator: float = 0.0
var wolfram_enabled: bool = false

var ant_rate: float = 1.0
var ant_accumulator: float = 0.0
var ants_enabled: bool = false

var gol_rate: float = 1.0
var gol_accumulator: float = 0.0
var gol_enabled: bool = false

var day_night_rate: float = 1.0
var day_night_accumulator: float = 0.0
var day_night_enabled: bool = false

var seeds_rate: float = 1.0
var seeds_accumulator: float = 0.0
var seeds_enabled: bool = false

var sand_rate: float = 30.0
var sand_accumulator: float = 0.0
var sand_enabled: bool = false
var sand_grid: PackedInt32Array = PackedInt32Array()
var sand_drop_amount: int = 1000
var sand_drop_at_click: bool = false

const SAND_PALETTE_PRESETS: Dictionary = {
	"Desert": [Color(0.93, 0.82, 0.57), Color(0.86, 0.67, 0.45), Color(0.71, 0.52, 0.33), Color(0.49, 0.36, 0.25)],
	"Pastel": [Color(0.91, 0.91, 0.98), Color(0.74, 0.86, 0.96), Color(0.56, 0.77, 0.93), Color(0.38, 0.69, 0.89)],
	"Neon": [Color(0.0, 1.0, 0.59), Color(0.39, 0.96, 0.99), Color(0.93, 0.2, 0.93), Color(1.0, 0.53, 0.0)],
	"Rainbow": [Color(0.55, 0.0, 0.0), Color(1.0, 0.85, 0.1), Color(0.15, 0.45, 1.0), Color(0.6, 0.25, 0.8)],
	"Sunset": [Color(0.98, 0.54, 0.2), Color(0.97, 0.8, 0.36), Color(0.89, 0.35, 0.36), Color(0.55, 0.16, 0.35)],
	"Forest": [Color(0.18, 0.35, 0.2), Color(0.31, 0.55, 0.32), Color(0.5, 0.74, 0.45), Color(0.73, 0.89, 0.64)],
	"Grayscale": [Color(0.2, 0.2, 0.2), Color(0.4, 0.4, 0.4), Color(0.6, 0.6, 0.6), Color(0.85, 0.85, 0.85)]
}
const SAND_PALETTE_ORDER: Array[String] = [
	"Desert",
	"Pastel",
	"Neon",
	"Rainbow",
	"Sunset",
	"Forest",
	"Grayscale",
	"Custom",
]
var sand_palette_name: String = "Desert"
var sand_colors: Array[Color] = []

const TURMITE_RULE_PRESETS: Array[String] = [
	"RL", # Classic Langton ant
	"RLR", # Simple oscillations
	"LR", # Symmetric turn pair
	"RLLR", # Winding paths
	"RRLL", # Space-filling drift
	"RLRR", # Spirals and rays
	"LRRL", # Dense braids
]

var turmite_rate: float = 1.0
var turmite_accumulator: float = 0.0
var turmite_enabled: bool = false
var turmite_rule: String = TURMITE_RULE_PRESETS[0]
var turmite_count: int = 1
var turmites: Array[Vector2i] = []
var turmite_directions: Array[int] = []
var turmite_colors: Array[Color] = []

var ants: Array[Vector2i] = []
var ant_directions: Array[int] = []
var ant_colors: Array[Color] = []

var seed_fill: float = 0.2
var high_density_menu_scale: float = 2.0
var auto_menu_scale: bool = true
const SIDEBAR_MIN_RATIO: float = 0.1
const SIDEBAR_MAX_RATIO: float = 0.3
@export var sidebar_target_ratio: float = 0.2
@export var sidebar_min_width: float = 260.0
@export var sidebar_base_width: float = 260.0
const SIDEBAR_BASE_FONT_SIZE: int = 14
const SIDEBAR_BASE_SIDE_SEPARATION: int = 10
const SIDEBAR_BASE_COLUMN_SEPARATION: int = 8
const SIDEBAR_BASE_INFO_SEPARATION: int = 6

var global_rate: float = 10.0

var grid_lines_enabled: bool = false
var grid_line_thickness: int = 1
var grid_line_color: Color = Color(0.2, 0.2, 0.2)

var draw_enabled: bool = false
var draw_mode: int = DRAW_MODE_PAINT
var drawing_active: bool = false

var ui_ready: bool = false
var is_paused: bool = true

var render_pending: bool = false
var render_task_ids: Array[int] = []
var render_task_result: Dictionary = {}
var render_task_mutex: Mutex = Mutex.new()

var sim_workers: Dictionary = {}
const SIM_KEYS: Array[String] = ["totalistic", "wolfram", "ants", "turmites", "sand"]

var native_automata: RefCounted = null

var step_requested: bool = false

var export_pattern: String = "user://screenshot####.png"
var export_counter: int = 0

var grid_shader: Shader = null
@onready var grid_material: ShaderMaterial = ShaderMaterial.new()
var state_texture: ImageTexture = ImageTexture.new()
var sand_texture: ImageTexture = ImageTexture.new()
var overlay_texture: ImageTexture = ImageTexture.new()
var sand_has_content: bool = false

@onready var grid_view: TextureRect = TextureRect.new()
@onready var info_label: Label = Label.new()
@onready var view_container: Panel = Panel.new()
@onready var sidebar_ref: PanelContainer = PanelContainer.new()
@onready var play_button: Button = Button.new()
@onready var help_panel: PanelContainer = PanelContainer.new()
@onready var help_label: RichTextLabel = RichTextLabel.new()

@onready var wolfram_rate_spin: SpinBox = SpinBox.new()
@onready var ant_rate_spin: SpinBox = SpinBox.new()
@onready var gol_rate_spin: SpinBox = SpinBox.new()
@onready var cell_size_spin: SpinBox = SpinBox.new()
@onready var rule_spin: SpinBox = SpinBox.new()
@onready var edge_option: OptionButton = OptionButton.new()
@onready var alive_picker: ColorPickerButton = ColorPickerButton.new()
@onready var dead_picker: ColorPickerButton = ColorPickerButton.new()
@onready var ant_color_picker: ColorPickerButton = ColorPickerButton.new()
@onready var ant_count_spin: SpinBox = SpinBox.new()
@onready var fill_spin: SpinBox = SpinBox.new()
@onready var export_pattern_edit: LineEdit = LineEdit.new()
@onready var day_night_rate_spin: SpinBox = SpinBox.new()
@onready var seeds_rate_spin: SpinBox = SpinBox.new()
@onready var turmite_rate_spin: SpinBox = SpinBox.new()
@onready var turmite_rule_option: OptionButton = OptionButton.new()
@onready var turmite_count_spin: SpinBox = SpinBox.new()
@onready var turmite_color_picker: ColorPickerButton = ColorPickerButton.new()
@onready var sand_rate_spin: SpinBox = SpinBox.new()
@onready var sand_amount_spin: SpinBox = SpinBox.new()
@onready var sand_palette_option: OptionButton = OptionButton.new()
var sand_color_pickers: Array[ColorPickerButton] = []
@onready var draw_mode_option: OptionButton = OptionButton.new()
@onready var draw_toggle: CheckBox = CheckBox.new()
@onready var sand_click_toggle: CheckBox = CheckBox.new()
@onready var grid_line_toggle: CheckBox = CheckBox.new()
@onready var grid_line_thickness_spin: SpinBox = SpinBox.new()
@onready var grid_line_color_picker: ColorPickerButton = ColorPickerButton.new()
@onready var export_dialog: FileDialog = FileDialog.new()
var root_container: HBoxContainer = null
var sidebar_layout_ref: VBoxContainer = null
var controls_column_ref: VBoxContainer = null
var info_row_ref: HBoxContainer = null

func style_picker_button(picker: ColorPickerButton) -> void:
	picker.custom_minimum_size = Vector2(32, 32)
	picker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var base: StyleBoxFlat = StyleBoxFlat.new()
	base.bg_color = Color.WHITE
	base.border_color = Color(0.2, 0.2, 0.2)
	base.border_width_left = 1
	base.border_width_right = 1
	base.border_width_top = 1
	base.border_width_bottom = 1

	var hover: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 1, 1, 0.9)

	var pressed: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.9, 0.9, 0.9)

	picker.add_theme_stylebox_override("normal", base)
	picker.add_theme_stylebox_override("hover", hover)
	picker.add_theme_stylebox_override("pressed", pressed)
	picker.add_theme_stylebox_override("focus", hover)
	picker.add_theme_stylebox_override("disabled", base)

func apply_picker_color(picker: ColorPickerButton, color: Color) -> void:
	picker.color = color
	picker.modulate = color

func show_help(text: String) -> void:
	if help_label == null or help_panel == null:
		return
	help_label.text = text
	help_panel.visible = true

func register_help(control: Control, text: String) -> void:
	if control == null:
		return
	control.tooltip_text = text
	control.mouse_entered.connect(func() -> void: show_help(text))
	control.focus_entered.connect(func() -> void: show_help(text))
	if control is BaseButton:
		var button: BaseButton = control as BaseButton
		button.pressed.connect(func() -> void: show_help(text))
	else:
		control.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				show_help(text)
		)

func enforce_integer_spin(spin: SpinBox, min_value: int = 0) -> void:
	spin.step = 1.0
	spin.rounded = true
	spin.min_value = float(min_value)
	spin.allow_lesser = false
	spin.allow_greater = true
	var edit: LineEdit = spin.get_line_edit()
	if edit == null:
		return
	edit.text = str(int(max(min_value, spin.value)))
	var cleaning: bool = false
	edit.text_changed.connect(func(text: String) -> void:
		if cleaning:
			return
		cleaning = true
		var digits: String = ""
		for ch in text:
			var char_str: String = str(ch)
			if char_str >= "0" and char_str <= "9":
				digits += char_str
		if digits == "":
			digits = str(min_value)
		while digits.length() > 1 and digits.begins_with("0"):
			digits = digits.substr(1, digits.length() - 1)
		var value: int = int(digits)
		if value < min_value:
			value = min_value
			digits = str(value)
		edit.text = digits
		edit.caret_column = edit.text.length()
		spin.value = float(value)
		cleaning = false
	)

func sand_grid_has_content() -> bool:
	for v in sand_grid:
		if v != 0:
			return true
	return false

func is_high_density_device() -> bool:
	var os_name: String = OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		return true
	var dpi: int = DisplayServer.screen_get_dpi()
	if dpi > 220:
		return true
	var size: Vector2i = DisplayServer.screen_get_size()
	return max(size.x, size.y) >= 2560

func get_sidebar_ratio() -> float:
	return clamp(sidebar_target_ratio, SIDEBAR_MIN_RATIO, SIDEBAR_MAX_RATIO)

func apply_sidebar_theme_scale(scale: float) -> void:
	if sidebar_ref != null:
		var font_size: int = int(round(SIDEBAR_BASE_FONT_SIZE * scale))
		sidebar_ref.add_theme_font_size_override("font_size", font_size)
	if sidebar_layout_ref != null:
		sidebar_layout_ref.add_theme_constant_override("separation", int(round(SIDEBAR_BASE_SIDE_SEPARATION * scale)))
	if controls_column_ref != null:
		controls_column_ref.add_theme_constant_override("separation", int(round(SIDEBAR_BASE_COLUMN_SEPARATION * scale)))
	if info_row_ref != null:
		info_row_ref.add_theme_constant_override("separation", int(round(SIDEBAR_BASE_INFO_SEPARATION * scale)))

func update_sidebar_allocation(effective_width: float = -1.0, ratio: float = -1.0) -> void:
	if sidebar_ref == null or view_container == null:
		return
	if ratio < 0.0:
		ratio = get_sidebar_ratio()
	if effective_width < 0.0:
		var viewport_size: Vector2 = Vector2(get_viewport_rect().size)
		var desired_width: float = viewport_size.x * ratio if viewport_size.x > 0.0 else sidebar_min_width
		effective_width = max(sidebar_min_width, desired_width)
	sidebar_ref.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_ref.custom_minimum_size.x = max(sidebar_min_width, effective_width)
	sidebar_ref.size_flags_stretch_ratio = ratio
	view_container.size_flags_stretch_ratio = max(0.001, 1.0 - ratio)

func update_sidebar_scale() -> void:
	if sidebar_ref == null:
		return
	var viewport_size: Vector2 = Vector2(get_viewport_rect().size)
	var ratio: float = get_sidebar_ratio()
	var desired_width: float = viewport_size.x * ratio if viewport_size.x > 0.0 else sidebar_min_width
	var effective_width: float = max(sidebar_min_width, desired_width)
	update_sidebar_allocation(effective_width, ratio)
	if not auto_menu_scale:
		sidebar_ref.scale = Vector2.ONE
		return
	if viewport_size.x <= 0.0:
		return
	var computed_scale: float = effective_width / max(1.0, sidebar_base_width)
	if is_high_density_device():
		computed_scale = max(computed_scale, high_density_menu_scale)
	var clamped: float = clamp(computed_scale, 0.75, 3.0)
	sidebar_ref.scale = Vector2(clamped, clamped)
	apply_sidebar_theme_scale(clamped)

func update_grid_line_controls() -> void:
	grid_line_thickness_spin.editable = grid_lines_enabled
	grid_line_thickness_spin.mouse_filter = Control.MOUSE_FILTER_STOP
	grid_line_color_picker.disabled = not grid_lines_enabled

func set_sand_palette_by_name(name: String) -> void:
	sand_palette_name = name
	sand_colors.clear()
	var preset: Array = SAND_PALETTE_PRESETS.get(name, [])
	for value in preset:
		if value is Color:
			sand_colors.append(value)
	while sand_colors.size() < 4:
		sand_colors.append(Color.WHITE)
	for i in range(min(sand_color_pickers.size(), sand_colors.size())):
		apply_picker_color(sand_color_pickers[i], sand_colors[i])

func _ready() -> void:
	set_process(true)
	grid_shader = load("res://shaders/grid_view.gdshader")
	if grid_shader != null:
		grid_material.shader = grid_shader
		grid_view.material = grid_material
	initialize_sim_workers()
	initialize_native_automata()
	set_sand_palette_by_name(sand_palette_name)
	build_ui()
	help_panel.visible = true
	call_deferred("initialize_grid")

func initialize_native_automata() -> void:
	if native_automata != null:
		return
	var extension_path := "res://cpp/native_automata.gdextension"
	if not FileAccess.file_exists(extension_path):
		print("[NativeAutomata] Descriptor missing at %s, using GDScript" % extension_path)
		return

	var platform_lib := ""
	match OS.get_name():
		"Windows":
			platform_lib = "res://bin/native_automata.dll"
		"macOS":
			platform_lib = "res://bin/libnative_automata.dylib"
		_:
			platform_lib = "res://bin/libnative_automata.so"

	if not FileAccess.file_exists(platform_lib):
		print("[NativeAutomata] Native library missing at %s, using GDScript (see cpp/README.md to build)" % platform_lib)
		return

	if ClassDB.class_exists("NativeAutomata"):
		var instance: Object = ClassDB.instantiate("NativeAutomata")
		if instance is RefCounted:
			native_automata = instance as RefCounted
			print("[NativeAutomata] Loaded native extension")
		else:
			print("[NativeAutomata] Failed to instantiate native extension, using GDScript")
	else:
		print("[NativeAutomata] Native extension not found, using GDScript")

func initialize_sim_workers() -> void:
	if not sim_workers.is_empty():
		return
	for key in SIM_KEYS:
		var sem: Semaphore = Semaphore.new()
		var mutex: Mutex = Mutex.new()
		var data: Dictionary = {
			"key": key,
			"semaphore": sem,
			"mutex": mutex,
			"request": {},
			"result": {},
			"busy": false,
		}
		var t: Thread = Thread.new()
		var err: int = t.start(Callable(self, "_simulation_worker").bind(data))
		if err != OK:
			push_warning("Failed to start simulation worker %s (error %d)" % [key, err])
			continue
		data["thread"] = t
		sim_workers[key] = data

func set_info_label_text(text: String) -> void:
	if info_label == null:
		return
	var suffix: String = " (GDScript fallback)"
	if native_automata != null:
		suffix = " (native C++ active)"
	info_label.text = text + suffix

func _simulation_worker(data: Dictionary) -> void:
	var sem: Semaphore = data.get("semaphore")
	var mutex: Mutex = data.get("mutex")
	if sem == null or mutex == null:
		return
	while true:
		sem.wait()
		mutex.lock()
		var request: Dictionary = data.get("request", {})
		data["request"] = {}
		mutex.unlock()
		if request.is_empty():
			continue
		if request.get("stop", false):
			break
		var fn: Callable = request.get("fn", Callable())
		var args: Array = request.get("args", [])
		var result: Dictionary = {}
		if fn.is_valid():
			result = fn.callv(args)
		mutex.lock()
		data["result"] = result
		data["busy"] = false
		mutex.unlock()

func request_render() -> void:
	render_pending = true

func _enqueue_sim_task(key: String, fn: Callable, args: Array) -> bool:
	var data: Dictionary = sim_workers.get(key, {})
	if data.is_empty():
		return false
	var mutex: Mutex = data.get("mutex", null)
	var sem: Semaphore = data.get("semaphore", null)
	if mutex == null or sem == null:
		return false
	mutex.lock()
	var busy: bool = data.get("busy", false)
	if busy:
		mutex.unlock()
		return false
	data["request"] = {"fn": fn, "args": args}
	data["busy"] = true
	data["result"] = {}
	mutex.unlock()
	sem.post()
	return true

func _take_sim_result(key: String) -> Dictionary:
	var data: Dictionary = sim_workers.get(key, {})
	if data.is_empty():
		return {}
	var mutex: Mutex = data.get("mutex", null)
	if mutex == null:
		return {}
	mutex.lock()
	var result: Dictionary = data.get("result", {})
	data["result"] = {}
	var busy: bool = data.get("busy", false)
	mutex.unlock()
	if busy:
		return {}
	return result

func _stop_sim_workers() -> void:
	for key in sim_workers.keys():
		var data: Dictionary = sim_workers[key]
		var sem: Semaphore = data.get("semaphore", null)
		var mutex: Mutex = data.get("mutex", null)
		if sem == null or mutex == null:
			continue
		mutex.lock()
		data["request"] = {"stop": true}
		mutex.unlock()
		sem.post()
		if data.has("thread") and data["thread"] is Thread:
			(data["thread"] as Thread).wait_to_finish()
	sim_workers.clear()

func _any_sim_busy() -> bool:
	for key in sim_workers.keys():
		var data: Dictionary = sim_workers[key]
		if data.get("busy", false):
			return true
	return false

func _sim_busy(key: String) -> bool:
	var data: Dictionary = sim_workers.get(key, {})
	if data.is_empty():
		return false
	return data.get("busy", false)

func _grid_sim_busy() -> bool:
	for key in sim_workers.keys():
		if key == "sand":
			continue
		var data: Dictionary = sim_workers[key]
		if data.get("busy", false):
			return true
	return false

func build_ui() -> void:
	root_container = HBoxContainer.new()
	root_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_container.add_theme_constant_override("separation", 8)
	add_child(root_container)

	sidebar_ref = PanelContainer.new()
	sidebar_ref.custom_minimum_size = Vector2(sidebar_min_width, 0)
	sidebar_ref.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_ref.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_container.add_child(sidebar_ref)

	sidebar_layout_ref = VBoxContainer.new()
	sidebar_layout_ref.add_theme_constant_override("separation", SIDEBAR_BASE_SIDE_SEPARATION)
	sidebar_ref.add_child(sidebar_layout_ref)

	var title: Label = Label.new()
	title.text = "Shader-friendly Cellular Automata"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 18)
	sidebar_layout_ref.add_child(title)

	info_row_ref = HBoxContainer.new()
	info_row_ref.add_theme_constant_override("separation", SIDEBAR_BASE_INFO_SEPARATION)
	info_row_ref.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_layout_ref.add_child(info_row_ref)

	set_info_label_text("Grid ready")
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.clip_text = true
	info_row_ref.add_child(info_label)

	play_button.text = "Play" if is_paused else "Pause"
	play_button.pressed.connect(func() -> void:
		is_paused = !is_paused
		play_button.text = "Play" if is_paused else "Pause"
	)
	info_row_ref.add_child(play_button)
	register_help(play_button, "Toggle play and pause for all simulations.")

	var step_button: Button = Button.new()
	step_button.text = "Step"
	step_button.pressed.connect(func() -> void:
		step_requested = true
	)
	info_row_ref.add_child(step_button)
	register_help(step_button, "Advance every enabled simulation by a single update without starting auto-play.")

	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_label.text = ""
	var help_margin: MarginContainer = MarginContainer.new()
	help_margin.add_theme_constant_override("margin_left", 6)
	help_margin.add_theme_constant_override("margin_right", 6)
	help_margin.add_theme_constant_override("margin_top", 6)
	help_margin.add_theme_constant_override("margin_bottom", 6)
	help_margin.add_child(help_label)
	help_panel.visible = false
	help_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_panel.add_child(help_margin)
	sidebar_layout_ref.add_child(help_panel)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_layout_ref.add_child(scroll)

	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.filters = ["*.png"]
	export_dialog.title = "Export grid PNG"
	export_dialog.transient = true
	export_dialog.use_native_dialog = true
	export_dialog.file_selected.connect(func(path: String) -> void:
		export_pattern = path
		export_pattern_edit.text = path
		export_grid_image(path)
	)
	add_child(export_dialog)

	controls_column_ref = VBoxContainer.new()
	controls_column_ref.add_theme_constant_override("separation", SIDEBAR_BASE_COLUMN_SEPARATION)
	scroll.add_child(controls_column_ref)

	controls_column_ref.add_child(build_collapsible_section("Grid", build_grid_controls(), "Control grid size, edge wrapping, colors, drawing, and update speed for every simulation."))
	controls_column_ref.add_child(build_collapsible_section("Export", build_export_controls(), "Set a filename pattern and export the current view to a PNG file."))
	controls_column_ref.add_child(build_collapsible_section("Wolfram", build_wolfram_controls(), "1D cellular automaton using Wolfram rules. Seed a row, then press Step or enable Auto to watch the rows accumulate."))
	controls_column_ref.add_child(build_collapsible_section("Langton's Ant", build_ant_controls(), "Spawn ants that turn right on black and left on white, flipping the cell each time. Use Auto to let them roam or Step for manual moves."))
	controls_column_ref.add_child(build_collapsible_section("Turmite", build_turmite_controls(), "Generalized Langton ants that follow custom turn rules. Spawn turmites, then Step or enable Auto to see their trails."))
	controls_column_ref.add_child(build_collapsible_section("Game of Life", build_gol_controls(), "Conway's Game of Life. Set a step rate, seed the grid, then Auto or Step to evolve the pattern."))
	controls_column_ref.add_child(build_collapsible_section("Day & Night", build_day_night_controls(), "Day & Night variant of Life with symmetric rules. Seed the grid, then Step or Auto to run the simulation."))
	controls_column_ref.add_child(build_collapsible_section("Seeds", build_seeds_controls(), "Seeds automaton (birth on 2, no survival). Populate the grid and use Step or Auto to advance."))
	controls_column_ref.add_child(build_collapsible_section("Sandpile", build_sand_controls(), "Toppling sandpile. Drop sand piles and run steps to watch grains cascade. Auto keeps the pile flowing."))

	view_container = Panel.new()
	view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_container.custom_minimum_size = Vector2(200, 200)
	view_container.clip_contents = true
	root_container.add_child(view_container)

	grid_view.stretch_mode = TextureRect.STRETCH_SCALE
	grid_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grid_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grid_view.modulate = Color.WHITE
	grid_view.mouse_filter = Control.MOUSE_FILTER_STOP
	view_container.mouse_filter = Control.MOUSE_FILTER_STOP
	view_container.add_child(grid_view)

	grid_view.gui_input.connect(on_grid_gui_input)

	view_container.resized.connect(func() -> void:
		update_grid_size()
		request_render()
	)

	update_sidebar_allocation()
	update_grid_line_controls()

	ui_ready = true
	update_sidebar_scale()

func initialize_grid() -> void:
	update_grid_size()
	request_render()

func build_collapsible_section(title: String, content: Control, help_text: String = "") -> VBoxContainer:
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 4)

	var header: Button = Button.new()
	header.text = title
	header.toggle_mode = true
	header.button_pressed = false
	if not help_text.is_empty():
		register_help(header, help_text)
	wrapper.add_child(header)

	var holder: VBoxContainer = VBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	holder.add_child(content)
	holder.visible = header.button_pressed
	wrapper.add_child(holder)

	header.toggled.connect(func(pressed: bool) -> void:
		holder.visible = pressed
	)

	return wrapper

func build_grid_controls() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var size_row: HBoxContainer = HBoxContainer.new()
	var size_label: Label = Label.new()
	size_label.text = "Cell size"
	size_row.add_child(size_label)
	cell_size_spin.min_value = 1
	cell_size_spin.max_value = 128
	cell_size_spin.value = cell_size
	cell_size_spin.step = 1
	cell_size_spin.value_changed.connect(func(value: float) -> void:
		cell_size = int(value)
		update_grid_size()
		request_render()
	)
	size_row.add_child(cell_size_spin)
	register_help(cell_size_spin, "Set the pixel size of each cell. Larger values make the grid coarser and easier to see.")
	box.add_child(size_row)

	var global_rate_row: HBoxContainer = HBoxContainer.new()
	var global_rate_label: Label = Label.new()
	global_rate_label.text = "Updates/sec"
	global_rate_row.add_child(global_rate_label)
	var global_rate_spin: SpinBox = SpinBox.new()
	global_rate_spin.min_value = 0.0
	global_rate_spin.max_value = 5000.0
	enforce_integer_spin(global_rate_spin, 0)
	global_rate_spin.value = global_rate
	global_rate_spin.value_changed.connect(func(v: float) -> void: global_rate = max(0.0, v))
	global_rate_row.add_child(global_rate_spin)
	register_help(global_rate_spin, "Set the global updates per second multiplier using whole numbers.")
	box.add_child(global_rate_row)

	var edge_row: HBoxContainer = HBoxContainer.new()
	var edge_label: Label = Label.new()
	edge_label.text = "Edges"
	edge_row.add_child(edge_label)
	edge_option.add_item("Wrap", EDGE_WRAP)
	edge_option.add_item("Bounce", EDGE_BOUNCE)
	edge_option.add_item("Fall off", EDGE_FALLOFF)
	edge_option.selected = EDGE_WRAP
	edge_option.item_selected.connect(func(index: int) -> void: edge_mode = index)
	edge_row.add_child(edge_option)
	register_help(edge_option, "Choose how edges behave: wrap around, bounce ants/turmites, or fall off into empty space.")
	box.add_child(edge_row)

	var color_row: HBoxContainer = HBoxContainer.new()
	var color_label: Label = Label.new()
	color_label.text = "Alive / Dead"
	color_row.add_child(color_label)
	style_picker_button(alive_picker)
	apply_picker_color(alive_picker, alive_color)
	alive_picker.color_changed.connect(func(c: Color) -> void:
		alive_color = c
		apply_picker_color(alive_picker, c)
		request_render()
	)
	style_picker_button(dead_picker)
	apply_picker_color(dead_picker, dead_color)
	dead_picker.color_changed.connect(func(c: Color) -> void:
		dead_color = c
		apply_picker_color(dead_picker, c)
		request_render()
	)
	color_row.add_child(alive_picker)
	color_row.add_child(dead_picker)
	register_help(alive_picker, "Pick the color used for live cells across all automata.")
	register_help(dead_picker, "Pick the color used for empty/dead cells.")
	box.add_child(color_row)

	var grid_line_row: HBoxContainer = HBoxContainer.new()
	var grid_line_label: Label = Label.new()
	grid_line_label.text = "Grid lines"
	grid_line_row.add_child(grid_line_label)
	grid_line_toggle.text = "Show"
	grid_line_toggle.button_pressed = grid_lines_enabled
	grid_line_toggle.toggled.connect(func(v: bool) -> void:
		grid_lines_enabled = v
		update_grid_line_controls()
		request_render()
	)
	grid_line_row.add_child(grid_line_toggle)
	grid_line_thickness_spin.min_value = 1
	grid_line_thickness_spin.max_value = 16
	grid_line_thickness_spin.step = 1
	grid_line_thickness_spin.value = grid_line_thickness
	grid_line_thickness_spin.value_changed.connect(func(v: float) -> void:
		grid_line_thickness = int(v)
		request_render()
	)
	grid_line_row.add_child(grid_line_thickness_spin)
	style_picker_button(grid_line_color_picker)
	apply_picker_color(grid_line_color_picker, grid_line_color)
	grid_line_color_picker.color_changed.connect(func(c: Color) -> void:
		grid_line_color = c
		apply_picker_color(grid_line_color_picker, c)
		request_render()
	)
	grid_line_row.add_child(grid_line_color_picker)
	register_help(grid_line_toggle, "Show or hide a grid overlay on the simulation view.")
	register_help(grid_line_thickness_spin, "Adjust the thickness of the grid overlay lines.")
	register_help(grid_line_color_picker, "Choose the color used for grid overlay lines.")
	box.add_child(grid_line_row)

	var draw_row: HBoxContainer = HBoxContainer.new()
	var draw_label: Label = Label.new()
	draw_label.text = "Draw"
	draw_row.add_child(draw_label)
	draw_toggle.text = "Enable"
	draw_toggle.button_pressed = draw_enabled
	draw_toggle.toggled.connect(func(enabled: bool) -> void:
		draw_enabled = enabled
		drawing_active = false
	)
	draw_row.add_child(draw_toggle)
	draw_mode_option.clear()
	draw_mode_option.add_item("Paint", DRAW_MODE_PAINT)
	draw_mode_option.add_item("Erase", DRAW_MODE_ERASE)
	draw_mode_option.add_item("Toggle", DRAW_MODE_TOGGLE)
	draw_mode_option.select(draw_mode)
	draw_mode_option.item_selected.connect(func(index: int) -> void:
		draw_mode = draw_mode_option.get_item_id(index)
	)
	draw_row.add_child(draw_mode_option)
	register_help(draw_toggle, "Enable freehand drawing on the grid. Hold left click (or touch) to paint while enabled.")
	register_help(draw_mode_option, "Choose whether drawing paints live cells, erases them, or toggles the current state.")
	box.add_child(draw_row)

	var fill_row: HBoxContainer = HBoxContainer.new()
	var fill_label: Label = Label.new()
	fill_label.text = "Seed %"
	fill_row.add_child(fill_label)
	fill_spin.min_value = 0
	fill_spin.max_value = 100
	fill_spin.step = 1
	fill_spin.value = seed_fill * 100.0
	fill_spin.value_changed.connect(func(v: float) -> void: seed_fill = float(v) / 100.0)
	fill_row.add_child(fill_spin)
	var seed_button: Button = Button.new()
	seed_button.text = "Randomize"
	seed_button.pressed.connect(func() -> void: random_fill_grid(); request_render())
	fill_row.add_child(seed_button)
	register_help(fill_spin, "Set the percentage of cells that start alive when seeding or resetting certain automata.")
	register_help(seed_button, "Fill the grid randomly using the Seed % value.")
	box.add_child(fill_row)

	var clear_button: Button = Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(func() -> void:
		grid.fill(0)
		clear_ants()
		clear_turmites()
		clear_sand()
		request_render()
	)
	box.add_child(clear_button)
	register_help(clear_button, "Wipe the grid, sand, ants, and turmites to start fresh.")

	return box

func build_export_controls() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var pattern_row: HBoxContainer = HBoxContainer.new()
	var pattern_label: Label = Label.new()
	pattern_label.text = "Filename"
	pattern_row.add_child(pattern_label)
	export_pattern_edit.text = export_pattern
	export_pattern_edit.placeholder_text = "user://screenshot####.png"
	export_pattern_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_pattern_edit.text_changed.connect(func(text: String) -> void:
		export_pattern = text
	)
	pattern_row.add_child(export_pattern_edit)
	register_help(export_pattern_edit, "Set the filename or pattern for exports. Use '#' characters to insert an auto-incremented number.")
	box.add_child(pattern_row)

	var export_row: HBoxContainer = HBoxContainer.new()
	var export_button: Button = Button.new()
	export_button.text = "Export PNG"
	export_button.pressed.connect(func() -> void:
		if Engine.has_singleton("JavaScriptBridge"):
			export_grid_image(resolve_export_path())
		else:
			var suggested: String = resolve_export_path()
			export_dialog.current_file = suggested.get_file()
			var dir: String = suggested.get_base_dir()
			if dir == "" or dir == ".":
				dir = ProjectSettings.globalize_path("user://")
			export_dialog.current_path = dir
			export_dialog.popup_centered()
	)
	export_row.add_child(export_button)
	var hint: Label = Label.new()
	hint.text = "Use # for numbering"
	export_row.add_child(hint)
	register_help(export_button, "Save the current view as a PNG. In the editor, a file picker will open; on the web build, it downloads directly.")
	box.add_child(export_row)

	return box

func build_wolfram_controls() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var rule_row: HBoxContainer = HBoxContainer.new()
	var rule_label: Label = Label.new()
	rule_label.text = "Rule"
	rule_row.add_child(rule_label)
	rule_spin.min_value = 0
	rule_spin.max_value = 255
	rule_spin.value = wolfram_rule
	rule_spin.value_changed.connect(func(v: float) -> void: wolfram_rule = int(v))
	rule_row.add_child(rule_spin)
	register_help(rule_spin, "Pick a Wolfram elementary rule (0-255). Classic fractals start at 30 and 110.")
	box.add_child(rule_row)

	var rate_row: HBoxContainer = HBoxContainer.new()
	var rate_label: Label = Label.new()
	rate_label.text = "Steps/update"
	rate_row.add_child(rate_label)
	wolfram_rate_spin.min_value = 0.0
	wolfram_rate_spin.max_value = 200.0
	enforce_integer_spin(wolfram_rate_spin, 0)
	wolfram_rate_spin.value = wolfram_rate
	wolfram_rate_spin.allow_greater = true
	wolfram_rate_spin.value_changed.connect(func(v: float) -> void: wolfram_rate = max(0.0, v))
	rate_row.add_child(wolfram_rate_spin)
	register_help(wolfram_rate_spin, "Set how many Wolfram rows to generate each global update (whole numbers only).")
	box.add_child(rate_row)

	var buttons: HBoxContainer = HBoxContainer.new()
	var toggle: CheckBox = CheckBox.new()
	toggle.text = "Auto"
	toggle.button_pressed = wolfram_enabled
	toggle.toggled.connect(func(v: bool) -> void: wolfram_enabled = v)
	buttons.add_child(toggle)
	var step: Button = Button.new()
	step.text = "Step"
	step.pressed.connect(func() -> void: step_wolfram(); request_render())
	buttons.add_child(step)
	register_help(toggle, "Continuously generate new Wolfram rows at the selected rate.")
	register_help(step, "Generate a single Wolfram row using the active rule and seed.")
	box.add_child(buttons)

	var seed_row: HBoxContainer = HBoxContainer.new()
	var random_seed: Button = Button.new()
	random_seed.text = "Seed top row"
	random_seed.pressed.connect(func() -> void: seed_wolfram_row(true); request_render())
	seed_row.add_child(random_seed)
	var center_seed: Button = Button.new()
	center_seed.text = "Center dot"
	center_seed.pressed.connect(func() -> void: seed_wolfram_row(false); request_render())
	seed_row.add_child(center_seed)
	register_help(random_seed, "Fill the top row randomly using the Seed % value, then start stepping.")
	register_help(center_seed, "Place a single live cell in the center of the top row for symmetric patterns.")
	box.add_child(seed_row)

	var fill_row: HBoxContainer = HBoxContainer.new()
	var fill_button: Button = Button.new()
	fill_button.text = "Fill screen"
	fill_button.pressed.connect(func() -> void:
		fill_wolfram_screen()
		request_render()
	)
	fill_row.add_child(fill_button)
	register_help(fill_button, "Advance the Wolfram automaton until every row is filled once.")
	box.add_child(fill_row)

	return box

func build_ant_controls() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var count_row: HBoxContainer = HBoxContainer.new()
	var count_label: Label = Label.new()
	count_label.text = "Ants"
	count_row.add_child(count_label)
	ant_count_spin.min_value = 1
	ant_count_spin.max_value = 200
	ant_count_spin.value = 1
	count_row.add_child(ant_count_spin)
	style_picker_button(ant_color_picker)
	apply_picker_color(ant_color_picker, Color(1, 0, 0))
	ant_color_picker.color_changed.connect(func(c: Color) -> void:
		apply_picker_color(ant_color_picker, c)
	)
	count_row.add_child(ant_color_picker)
	var spawn: Button = Button.new()
	spawn.text = "Spawn"
	spawn.pressed.connect(func() -> void: spawn_ants(int(ant_count_spin.value), ant_color_picker.color))
	count_row.add_child(spawn)
	register_help(ant_count_spin, "Choose how many ants to add when spawning.")
	register_help(ant_color_picker, "Pick the trail color used for newly spawned ants.")
	register_help(spawn, "Spawn Langton's ants at random positions with the selected color.")
	box.add_child(count_row)

	var rate_row: HBoxContainer = HBoxContainer.new()
	var rate_label: Label = Label.new()
	rate_label.text = "Steps/update"
	rate_row.add_child(rate_label)
	ant_rate_spin.min_value = 0.0
	ant_rate_spin.max_value = 500.0
	enforce_integer_spin(ant_rate_spin, 0)
	ant_rate_spin.value = ant_rate
	ant_rate_spin.allow_greater = true
	ant_rate_spin.value_changed.connect(func(v: float) -> void: ant_rate = max(0.0, v))
	rate_row.add_child(ant_rate_spin)
	register_help(ant_rate_spin, "Steps each ant takes per global update (whole numbers only).")
	box.add_child(rate_row)

	var buttons: HBoxContainer = HBoxContainer.new()
	var toggle: CheckBox = CheckBox.new()
	toggle.text = "Auto"
	toggle.button_pressed = ants_enabled
	toggle.toggled.connect(func(v: bool) -> void: ants_enabled = v)
	buttons.add_child(toggle)
	var step: Button = Button.new()
	step.text = "Step"
	step.pressed.connect(func() -> void: step_ants(); request_render())
	buttons.add_child(step)
	register_help(toggle, "Let all spawned ants move continuously at the chosen rate.")
	register_help(step, "Move all ants forward by one step.")
	box.add_child(buttons)

	var clear_row: HBoxContainer = HBoxContainer.new()
	var clear_button: Button = Button.new()
	clear_button.text = "Clear ants"
	clear_button.pressed.connect(func() -> void: clear_ants(); request_render())
	clear_row.add_child(clear_button)
	register_help(clear_button, "Remove every ant and reset their timers.")
	box.add_child(clear_row)

	return box

func build_gol_controls() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var rate_row: HBoxContainer = HBoxContainer.new()
	var rate_label: Label = Label.new()
	rate_label.text = "Steps/update"
	rate_row.add_child(rate_label)
	gol_rate_spin.min_value = 0.0
	gol_rate_spin.max_value = 120.0
	enforce_integer_spin(gol_rate_spin, 0)
	gol_rate_spin.value = gol_rate
	gol_rate_spin.allow_greater = true
	gol_rate_spin.value_changed.connect(func(v: float) -> void: gol_rate = max(0.0, v))
	rate_row.add_child(gol_rate_spin)
	register_help(gol_rate_spin, "Number of Game of Life steps performed per global update (whole numbers only).")
	box.add_child(rate_row)

	var buttons: HBoxContainer = HBoxContainer.new()
	var toggle: CheckBox = CheckBox.new()
	toggle.text = "Auto"
	toggle.button_pressed = gol_enabled
	toggle.toggled.connect(func(v: bool) -> void: gol_enabled = v)
	buttons.add_child(toggle)
	var step: Button = Button.new()
	step.text = "Step"
	step.pressed.connect(func() -> void: step_game_of_life(); request_render())
	buttons.add_child(step)
	register_help(toggle, "Continuously evolve the Game of Life grid at the selected rate.")
	register_help(step, "Advance the Game of Life by one generation.")
	box.add_child(buttons)

	return box

func build_day_night_controls() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var rate_row: HBoxContainer = HBoxContainer.new()
	var rate_label: Label = Label.new()
	rate_label.text = "Steps/update"
	rate_row.add_child(rate_label)
	day_night_rate_spin.min_value = 0.0
	day_night_rate_spin.max_value = 120.0
	enforce_integer_spin(day_night_rate_spin, 0)
	day_night_rate_spin.value = day_night_rate
	day_night_rate_spin.allow_greater = true
	day_night_rate_spin.value_changed.connect(func(v: float) -> void: day_night_rate = max(0.0, v))
	rate_row.add_child(day_night_rate_spin)
	register_help(day_night_rate_spin, "Steps run for the Day & Night rules per global update (whole numbers only).")
	box.add_child(rate_row)

	var buttons: HBoxContainer = HBoxContainer.new()
	var toggle: CheckBox = CheckBox.new()
	toggle.text = "Auto"
	toggle.button_pressed = day_night_enabled
	toggle.toggled.connect(func(v: bool) -> void: day_night_enabled = v)
	buttons.add_child(toggle)
	var step: Button = Button.new()
	step.text = "Step"
	step.pressed.connect(func() -> void: step_day_night(); request_render())
	buttons.add_child(step)
	register_help(toggle, "Run Day & Night continuously at the selected rate.")
	register_help(step, "Advance Day & Night by a single step.")
	box.add_child(buttons)

	return box

func build_seeds_controls() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var rate_row: HBoxContainer = HBoxContainer.new()
	var rate_label: Label = Label.new()
	rate_label.text = "Steps/update"
	rate_row.add_child(rate_label)
	seeds_rate_spin.min_value = 0.0
	seeds_rate_spin.max_value = 120.0
	enforce_integer_spin(seeds_rate_spin, 0)
	seeds_rate_spin.value = seeds_rate
	seeds_rate_spin.allow_greater = true
	seeds_rate_spin.value_changed.connect(func(v: float) -> void: seeds_rate = max(0.0, v))
	rate_row.add_child(seeds_rate_spin)
	register_help(seeds_rate_spin, "Steps per global update for the Seeds automaton (whole numbers only).")
	box.add_child(rate_row)

	var buttons: HBoxContainer = HBoxContainer.new()
	var toggle: CheckBox = CheckBox.new()
	toggle.text = "Auto"
	toggle.button_pressed = seeds_enabled
	toggle.toggled.connect(func(v: bool) -> void: seeds_enabled = v)
	buttons.add_child(toggle)
	var step: Button = Button.new()
	step.text = "Step"
	step.pressed.connect(func() -> void: step_seeds(); request_render())
	buttons.add_child(step)
	register_help(toggle, "Run the Seeds automaton continuously at the chosen step rate.")
	register_help(step, "Advance the Seeds automaton by one generation.")
	box.add_child(buttons)

	return box

func build_sand_controls() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var palette_row: HBoxContainer = HBoxContainer.new()
	var palette_label: Label = Label.new()
	palette_label.text = "Palette"
	palette_row.add_child(palette_label)
	sand_palette_option.clear()
	for name in SAND_PALETTE_ORDER:
		sand_palette_option.add_item(str(name))
	sand_palette_option.select(max(0, SAND_PALETTE_ORDER.find(sand_palette_name)))
	sand_palette_option.item_selected.connect(func(index: int) -> void:
		var name: String = sand_palette_option.get_item_text(index)
		set_sand_palette_by_name(name)
		request_render()
	)
	palette_row.add_child(sand_palette_option)
	register_help(sand_palette_option, "Choose a predefined sand color palette or switch to Custom when tweaking individual levels.")
	box.add_child(palette_row)

	sand_color_pickers.clear()
	for i in range(4):
		var color_row: HBoxContainer = HBoxContainer.new()
		var color_label: Label = Label.new()
		color_label.text = "Level %d" % i
		color_row.add_child(color_label)
		var picker: ColorPickerButton = ColorPickerButton.new()
		style_picker_button(picker)
		var picker_color: Color = sand_colors[i] if sand_colors.size() > i else Color.WHITE
		apply_picker_color(picker, picker_color)
		picker.color_changed.connect(func(c: Color) -> void:
			if sand_colors.size() <= i:
				sand_colors.resize(i + 1)
			sand_colors[i] = c
			sand_palette_name = "Custom"
			sand_palette_option.select(max(0, SAND_PALETTE_ORDER.find("Custom")))
			apply_picker_color(picker, c)
			request_render()
		)
		sand_color_pickers.append(picker)
		color_row.add_child(picker)
		register_help(picker, "Set the color for sand level %d. Switching colors makes the palette Custom." % i)
		box.add_child(color_row)

	var amount_row: HBoxContainer = HBoxContainer.new()
	var amount_label: Label = Label.new()
	amount_label.text = "Center sand"
	amount_row.add_child(amount_label)
	sand_amount_spin.min_value = 1
	sand_amount_spin.max_value = 1000000
	sand_amount_spin.step = 1
	sand_amount_spin.value = sand_drop_amount
	sand_amount_spin.value_changed.connect(func(v: float) -> void: sand_drop_amount = int(v))
	amount_row.add_child(sand_amount_spin)
	var drop_button: Button = Button.new()
	drop_button.text = "Drop"
	drop_button.pressed.connect(func() -> void:
		add_sand_to_center(sand_drop_amount)
		request_render()
	)
	amount_row.add_child(drop_button)
	register_help(sand_amount_spin, "How many grains to add when dropping sand into the center or at a click.")
	register_help(drop_button, "Drop the configured sand amount into the center of the grid.")
	box.add_child(amount_row)

	var click_row: HBoxContainer = HBoxContainer.new()
	sand_click_toggle.text = "Drop at click"
	sand_click_toggle.button_pressed = sand_drop_at_click
	sand_click_toggle.toggled.connect(func(v: bool) -> void:
		sand_drop_at_click = v
	)
	click_row.add_child(sand_click_toggle)
	register_help(sand_click_toggle, "When enabled, left-click on the grid to add a sand pile at the cursor.")
	box.add_child(click_row)

	var rate_row: HBoxContainer = HBoxContainer.new()
	var rate_label: Label = Label.new()
	rate_label.text = "Steps/update"
	rate_row.add_child(rate_label)
	sand_rate_spin.min_value = 0.0
	sand_rate_spin.max_value = 240.0
	enforce_integer_spin(sand_rate_spin, 0)
	sand_rate_spin.allow_greater = true
	sand_rate_spin.value = sand_rate
	sand_rate_spin.value_changed.connect(func(v: float) -> void: sand_rate = max(0.0, v))
	rate_row.add_child(sand_rate_spin)
	register_help(sand_rate_spin, "Number of sandpile relaxation steps per global update (whole numbers only).")
	box.add_child(rate_row)

	var buttons: HBoxContainer = HBoxContainer.new()
	var toggle: CheckBox = CheckBox.new()
	toggle.text = "Auto"
	toggle.button_pressed = sand_enabled
	toggle.toggled.connect(func(v: bool) -> void: sand_enabled = v)
	buttons.add_child(toggle)
	var step: Button = Button.new()
	step.text = "Step"
	step.pressed.connect(func() -> void:
		step_sand()
		request_render()
	)
	buttons.add_child(step)
	var clear_button: Button = Button.new()
	clear_button.text = "Clear sand"
	clear_button.pressed.connect(func() -> void:
		clear_sand()
		request_render()
	)
	buttons.add_child(clear_button)
	register_help(toggle, "Continuously settle the sandpile using the selected step rate.")
	register_help(step, "Perform a single sandpile relaxation step.")
	register_help(clear_button, "Remove all sand grains from the grid.")
	box.add_child(buttons)

	return box

func build_turmite_controls() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var rule_row: HBoxContainer = HBoxContainer.new()
	var rule_label: Label = Label.new()
	rule_label.text = "Rule"
	rule_row.add_child(rule_label)
	turmite_rule_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turmite_rule_option.focus_mode = Control.FOCUS_CLICK
	turmite_rule_option.clear()
	for preset in TURMITE_RULE_PRESETS:
		turmite_rule_option.add_item(preset)
	turmite_rule_option.select(max(0, TURMITE_RULE_PRESETS.find(turmite_rule)))
	turmite_rule_option.item_selected.connect(func(index: int) -> void:
		var choice: String = TURMITE_RULE_PRESETS[index]
		turmite_rule = choice
	)
	rule_row.add_child(turmite_rule_option)
	register_help(turmite_rule_option, "Pick a turn rule sequence for turmites. Each letter sets how turmites turn when landing on a state.")
	box.add_child(rule_row)

	var spawn_row: HBoxContainer = HBoxContainer.new()
	var count_label: Label = Label.new()
	count_label.text = "Turmites"
	spawn_row.add_child(count_label)
	turmite_count_spin.min_value = 1
	turmite_count_spin.max_value = 200
	turmite_count_spin.value = turmite_count
	turmite_count_spin.step = 1
	turmite_count_spin.value_changed.connect(func(v: float) -> void: turmite_count = int(v))
	spawn_row.add_child(turmite_count_spin)
	style_picker_button(turmite_color_picker)
	apply_picker_color(turmite_color_picker, Color(0, 0.6, 1))
	turmite_color_picker.color_changed.connect(func(c: Color) -> void:
		apply_picker_color(turmite_color_picker, c)
	)
	spawn_row.add_child(turmite_color_picker)
	var spawn_button: Button = Button.new()
	spawn_button.text = "Spawn"
	spawn_button.pressed.connect(func() -> void: spawn_turmites(turmite_count, turmite_color_picker.color))
	spawn_row.add_child(spawn_button)
	register_help(turmite_count_spin, "How many turmites to spawn at random positions.")
	register_help(turmite_color_picker, "Choose the trail color for new turmites.")
	register_help(spawn_button, "Spawn turmites using the selected count, rule, and color.")
	box.add_child(spawn_row)

	var rate_row: HBoxContainer = HBoxContainer.new()
	var rate_label: Label = Label.new()
	rate_label.text = "Steps/update"
	rate_row.add_child(rate_label)
	turmite_rate_spin.min_value = 0.0
	turmite_rate_spin.max_value = 500.0
	enforce_integer_spin(turmite_rate_spin, 0)
	turmite_rate_spin.value = turmite_rate
	turmite_rate_spin.allow_greater = true
	turmite_rate_spin.value_changed.connect(func(v: float) -> void: turmite_rate = max(0.0, v))
	rate_row.add_child(turmite_rate_spin)
	register_help(turmite_rate_spin, "Steps per update for every turmite (whole numbers only).")
	box.add_child(rate_row)

	var buttons: HBoxContainer = HBoxContainer.new()
	var toggle: CheckBox = CheckBox.new()
	toggle.text = "Auto"
	toggle.button_pressed = turmite_enabled
	toggle.toggled.connect(func(v: bool) -> void: turmite_enabled = v)
	buttons.add_child(toggle)
	var step: Button = Button.new()
	step.text = "Step"
	step.pressed.connect(func() -> void: step_turmites(false); request_render())
	buttons.add_child(step)
	var clear_button: Button = Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(func() -> void:
		clear_turmites()
		request_render()
	)
	buttons.add_child(clear_button)
	register_help(toggle, "Run all turmites continuously at the selected rate.")
	register_help(step, "Advance every turmite by one step.")
	register_help(clear_button, "Remove all turmites and their state.")
	box.add_child(buttons)

	return box

func update_grid_size() -> void:
	if not ui_ready:
		return
	var viewport_size: Vector2i = Vector2i(view_container.get_rect().size) if view_container != null else Vector2i(get_viewport_rect().size)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2i(get_viewport_rect().size)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	var new_size: Vector2i = Vector2i(
		max(1, int((viewport_size.x + cell_size - 1) / cell_size)),
		max(1, int((viewport_size.y + cell_size - 1) / cell_size))
	)
	var size_changed: bool = new_size != grid_size or grid.size() != new_size.x * new_size.y
	if size_changed:
		var old_size: Vector2i = grid_size
		var old_grid: PackedByteArray = grid.duplicate()
		var old_sand: PackedInt32Array = sand_grid.duplicate()
		grid_size = new_size

		var new_grid: PackedByteArray = PackedByteArray()
		new_grid.resize(grid_size.x * grid_size.y)
		new_grid.fill(0)
		var new_sand: PackedInt32Array = PackedInt32Array()
		new_sand.resize(grid_size.x * grid_size.y)
		new_sand.fill(0)

		var copy_w: int = min(old_size.x, grid_size.x)
		var copy_h: int = min(old_size.y, grid_size.y)
		if copy_w > 0 and copy_h > 0:
			for y in range(copy_h):
				for x in range(copy_w):
					var old_idx: int = y * old_size.x + x
					var new_idx: int = y * grid_size.x + x
					new_grid[new_idx] = old_grid[old_idx]
					new_sand[new_idx] = old_sand[old_idx]

		grid = new_grid
		sand_grid = new_sand

		wolfram_row = min(wolfram_row, grid_size.y)
		for i in range(ants.size()):
			ants[i] = wrap_position(ants[i])
		for i in range(turmites.size()):
			turmites[i] = wrap_position(turmites[i])
	else:
		grid_size = new_size
	set_info_label_text("Grid: %dx%d cells @ %d px" % [grid_size.x, grid_size.y, cell_size])
	if size_changed:
		request_render()

func random_fill_grid() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(grid.size()):
		if rng.randf() < seed_fill:
			grid[i] = 1
		else:
			grid[i] = 0
	wolfram_row = 0
	request_render()

func seed_wolfram_row(randomize: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	grid.fill(0)
	var top_row: int = 0
	for x in range(grid_size.x):
		var idx: int = top_row * grid_size.x + x
		grid[idx] = 1 if (randomize and rng.randf() < seed_fill) else 0
	if not randomize and grid_size.x > 0:
		var center: int = grid_size.x / 2
		grid[top_row * grid_size.x + center] = 1
	wolfram_row = 1
	request_render()

func spawn_ants(count: int, color: Color) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(count):
		ants.append(Vector2i(rng.randi_range(0, grid_size.x - 1), rng.randi_range(0, grid_size.y - 1)))
		ant_directions.append(rng.randi_range(0, DIRS.size() - 1))
		ant_colors.append(color)
	request_render()

func clear_ants() -> void:
	ants.clear()
	ant_directions.clear()
	ant_colors.clear()
	ant_accumulator = 0.0
	request_render()

func wrap_position(pos: Vector2i) -> Vector2i:
	return Vector2i(posmod(pos.x, grid_size.x), posmod(pos.y, grid_size.y))

func sample_cell(pos: Vector2i) -> int:
	if pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y:
		return grid[pos.y * grid_size.x + pos.x]

	match edge_mode:
		EDGE_WRAP:
			pos = wrap_position(pos)
			return grid[pos.y * grid_size.x + pos.x]
		EDGE_BOUNCE:
			var bounce_pos: Vector2i = pos
			if bounce_pos.x < 0:
				bounce_pos.x = -bounce_pos.x - 1
			elif bounce_pos.x >= grid_size.x:
				bounce_pos.x = grid_size.x - (bounce_pos.x - grid_size.x) - 1
			if bounce_pos.y < 0:
				bounce_pos.y = -bounce_pos.y - 1
			elif bounce_pos.y >= grid_size.y:
				bounce_pos.y = grid_size.y - (bounce_pos.y - grid_size.y) - 1
			bounce_pos.x = clamp(bounce_pos.x, 0, grid_size.x - 1)
			bounce_pos.y = clamp(bounce_pos.y, 0, grid_size.y - 1)
			return grid[bounce_pos.y * grid_size.x + bounce_pos.x]
		EDGE_FALLOFF:
			return 0
	return 0

func set_cell(pos: Vector2i, value: int) -> void:
	if pos.x < 0 or pos.x >= grid_size.x or pos.y < 0 or pos.y >= grid_size.y:
		return
	grid[pos.y * grid_size.x + pos.x] = clamp(value, 0, 1)

func erase_cell_contents(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= grid_size.x or pos.y < 0 or pos.y >= grid_size.y:
		return false
	var changed: bool = false
	var idx: int = pos.y * grid_size.x + pos.x
	if grid[idx] != 0:
		grid[idx] = 0
		changed = true
	if sand_grid.size() > idx and sand_grid[idx] != 0:
		sand_grid[idx] = 0
		changed = true
	changed = remove_ants_at(pos) or changed
	changed = remove_turmites_at(pos) or changed
	return changed

func apply_draw_action(pos: Vector2i) -> bool:
	if draw_mode == DRAW_MODE_ERASE:
		return erase_cell_contents(pos)
	if pos.x < 0 or pos.x >= grid_size.x or pos.y < 0 or pos.y >= grid_size.y:
		return false
	var idx: int = pos.y * grid_size.x + pos.x
	var changed: bool = false
	if draw_mode == DRAW_MODE_TOGGLE:
		var new_val: int = 1 if grid[idx] == 0 else 0
		if grid[idx] != new_val:
			grid[idx] = new_val
			changed = true
	elif grid[idx] != 1:
		grid[idx] = 1
		changed = true

	if sand_grid.size() > idx and sand_grid[idx] != 0:
		sand_grid[idx] = 0
		sand_has_content = sand_grid_has_content()
		changed = true

	changed = remove_ants_at(pos) or changed
	changed = remove_turmites_at(pos) or changed
	return changed

func local_to_cell(local_pos: Vector2) -> Vector2i:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return Vector2i(-1, -1)
	var size: Vector2 = grid_view.size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2i(-1, -1)
	var gx: int = int(floor(local_pos.x / size.x * float(grid_size.x)))
	var gy: int = int(floor(local_pos.y / size.y * float(grid_size.y)))
	return Vector2i(clamp(gx, 0, grid_size.x - 1), clamp(gy, 0, grid_size.y - 1))

func handle_draw_input(global_pos: Vector2) -> bool:
	var rect: Rect2 = grid_view.get_global_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return false
	if not rect.has_point(global_pos):
		return false
	var local: Vector2 = global_pos - rect.position
	var pos: Vector2i = local_to_cell(local)
	if pos.x < 0 or pos.y < 0:
		return false
	var changed: bool = apply_draw_action(pos)
	if changed:
		request_render()
	return changed

func handle_draw_local(local_pos: Vector2) -> bool:
	var pos: Vector2i = local_to_cell(local_pos)
	if pos.x < 0 or pos.y < 0:
		return false
	var changed: bool = apply_draw_action(pos)
	if changed:
		request_render()
	return changed

func process_wolfram(delta: float) -> bool:
	if not wolfram_enabled or wolfram_rate <= 0.0:
		return false
	wolfram_accumulator += delta
	var interval: float = 1.0 / wolfram_rate
	var stepped: bool = false
	while wolfram_accumulator >= interval:
		step_wolfram()
		wolfram_accumulator -= interval
		stepped = true
	return stepped

func process_ants(delta: float) -> bool:
	if not ants_enabled or ant_rate <= 0.0 or ants.is_empty():
		return false
	ant_accumulator += delta
	var interval: float = 1.0 / ant_rate
	var stepped: bool = false
	while ant_accumulator >= interval:
		step_ants()
		ant_accumulator -= interval
		stepped = true
	return stepped

func process_game_of_life(delta: float) -> bool:
	if not gol_enabled or gol_rate <= 0.0:
		return false
	gol_accumulator += delta
	var interval: float = 1.0 / gol_rate
	var stepped: bool = false
	while gol_accumulator >= interval:
		step_game_of_life()
		gol_accumulator -= interval
		stepped = true
	return stepped

func process_day_night(delta: float) -> bool:
	if not day_night_enabled or day_night_rate <= 0.0:
		return false
	day_night_accumulator += delta
	var interval: float = 1.0 / day_night_rate
	var stepped: bool = false
	while day_night_accumulator >= interval:
		step_day_night()
		day_night_accumulator -= interval
		stepped = true
	return stepped

func process_seeds(delta: float) -> bool:
	if not seeds_enabled or seeds_rate <= 0.0:
		return false
	seeds_accumulator += delta
	var interval: float = 1.0 / seeds_rate
	var stepped: bool = false
	while seeds_accumulator >= interval:
		step_seeds()
		seeds_accumulator -= interval
		stepped = true
	return stepped

func process_turmites(delta: float) -> bool:
	if not turmite_enabled or turmite_rate <= 0.0 or turmites.is_empty():
		return false
	turmite_accumulator += delta
	var interval: float = 1.0 / turmite_rate
	var stepped: bool = false
	while turmite_accumulator >= interval:
		step_turmites(false)
		turmite_accumulator -= interval
		stepped = true
	return stepped

func process_sand(delta: float) -> bool:
	if not sand_enabled or sand_rate <= 0.0:
		return false
	sand_accumulator += delta
	var interval: float = 1.0 / sand_rate
	var stepped: bool = false
	while sand_accumulator >= interval:
		step_sand()
		sand_accumulator -= interval
		stepped = true
	return stepped

func step_wolfram(allow_wrap: bool = true) -> void:
	step_wolfram_with_workers(allow_wrap, true)

func step_wolfram_with_workers(allow_wrap: bool, use_workers: bool) -> void:
	if native_automata != null and native_automata.has_method("step_wolfram"):
		var native_result: Dictionary = native_automata.call("step_wolfram", grid, grid_size, wolfram_rule, wolfram_row, edge_mode, allow_wrap)
		if native_result.has("grid") and native_result["grid"] is PackedByteArray:
			grid = native_result["grid"]
		if native_result.has("row"):
			wolfram_row = int(native_result.get("row", wolfram_row))
		if native_result.get("changed", true):
			request_render()
		return
	if use_workers and not _grid_sim_busy():
		var args: Array = [grid.duplicate(), grid_size, wolfram_rule, wolfram_row, edge_mode, allow_wrap]
		if _enqueue_sim_task("wolfram", Callable(self, "sim_job_wolfram"), args):
			return
	if grid_size.y <= 0:
		return
	if allow_wrap and grid_size.y > 0:
		wolfram_row = wolfram_row % grid_size.y
	if wolfram_row >= grid_size.y and not allow_wrap:
		return

	var source_row: int = 0
	if wolfram_row <= 0:
		source_row = grid_size.y - 1 if allow_wrap else 0
	else:
		source_row = wolfram_row - 1
	for x in range(grid_size.x):
		var left: int = sample_cell(Vector2i(x - 1, source_row))
		var center: int = sample_cell(Vector2i(x, source_row))
		var right: int = sample_cell(Vector2i(x + 1, source_row))
		var key: int = (left << 2) | (center << 1) | right
		var state: int = (wolfram_rule >> key) & 1
		set_cell(Vector2i(x, wolfram_row), state)
	wolfram_row = (wolfram_row + 1) % grid_size.y if allow_wrap else wolfram_row + 1
	request_render()

func fill_wolfram_screen() -> void:
	if grid_size.y <= 0:
		return
	if wolfram_row <= 0:
		wolfram_row = 1
	var remaining: int = max(0, grid_size.y - wolfram_row)
	for _i in range(remaining):
		step_wolfram_with_workers(false, false)
	wolfram_enabled = false
	wolfram_accumulator = 0.0
	request_render()

func step_ants() -> void:
	if native_automata != null and native_automata.has_method("step_ants"):
		var native_result: Dictionary = native_automata.call("step_ants", grid, grid_size, edge_mode, ants, ant_directions, ant_colors)
		if native_result.has("grid") and native_result["grid"] is PackedByteArray:
			grid = native_result["grid"]
		if native_result.has("ants") and native_result["ants"] is Array:
			ants = native_result["ants"]
		if native_result.has("directions") and native_result["directions"] is Array:
			ant_directions = native_result["directions"]
		if native_result.has("colors") and native_result["colors"] is Array:
			ant_colors = native_result["colors"]
		if native_result.get("changed", true):
			request_render()
		return
	if not _grid_sim_busy():
		var args: Array = [grid.duplicate(), grid_size, edge_mode, ants.duplicate(), ant_directions.duplicate(), ant_colors.duplicate()]
		if _enqueue_sim_task("ants", Callable(self, "sim_job_ants"), args):
			return
	var remove_indices: Array[int] = []
	for i in range(ants.size()):
		var pos: Vector2i = ants[i]
		if pos.x < 0 or pos.x >= grid_size.x or pos.y < 0 or pos.y >= grid_size.y:
			remove_indices.append(i)
			continue

		var idx: int = pos.y * grid_size.x + pos.x
		var current: int = grid[idx]
		if current == 1:
			ant_directions[i] = (ant_directions[i] + 1) % DIRS.size()
			grid[idx] = 0
		else:
			ant_directions[i] = (ant_directions[i] + DIRS.size() - 1) % DIRS.size()
			grid[idx] = 1

		var next: Vector2i = pos + DIRS[ant_directions[i]]
		if edge_mode == EDGE_WRAP:
			next = wrap_position(next)
		elif edge_mode == EDGE_BOUNCE:
			if next.x < 0 or next.x >= grid_size.x or next.y < 0 or next.y >= grid_size.y:
				ant_directions[i] = (ant_directions[i] + 2) % DIRS.size()
				next = pos + DIRS[ant_directions[i]]
				next.x = clamp(next.x, 0, grid_size.x - 1)
				next.y = clamp(next.y, 0, grid_size.y - 1)
		elif edge_mode == EDGE_FALLOFF:
			if next.x < 0 or next.x >= grid_size.x or next.y < 0 or next.y >= grid_size.y:
				remove_indices.append(i)
				continue
		ants[i] = next

	for j in range(remove_indices.size() - 1, -1, -1):
		var idx: int = remove_indices[j]
		ants.remove_at(idx)
		ant_directions.remove_at(idx)
		ant_colors.remove_at(idx)
	if not ants.is_empty() or not remove_indices.is_empty():
		request_render()

func step_game_of_life() -> void:
	step_totalistic([3], [2, 3])

func step_day_night() -> void:
	step_totalistic([3, 6, 7, 8], [3, 4, 6, 7, 8])

func step_seeds() -> void:
	step_totalistic([2], [])

func step_totalistic(birth: Array[int], survive: Array[int]) -> void:
	if native_automata != null and native_automata.has_method("step_totalistic"):
		var native_result: Dictionary = native_automata.call("step_totalistic", grid, grid_size, birth, survive, edge_mode)
		if native_result.has("grid") and native_result["grid"] is PackedByteArray:
			grid = native_result["grid"]
			if native_result.get("changed", true):
				request_render()
			return
	if not _grid_sim_busy():
		var args: Array = [grid.duplicate(), grid_size, birth.duplicate(), survive.duplicate(), edge_mode]
		if _enqueue_sim_task("totalistic", Callable(self, "sim_job_totalistic"), args):
			return

	var next_state: PackedByteArray = PackedByteArray()
	next_state.resize(grid.size())
	var birth_set: Array[int] = birth
	var survive_set: Array[int] = survive
	var changed: bool = false
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var alive: int = sample_cell(Vector2i(x, y))
			var neighbors: int = 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					neighbors += sample_cell(Vector2i(x + dx, y + dy))
			var new_val: int = 0
			if alive == 1:
				if survive_set.has(neighbors):
					new_val = 1
			else:
				if birth_set.has(neighbors):
					new_val = 1
			var idx: int = y * grid_size.x + x
			next_state[idx] = new_val
			if not changed and new_val != grid[idx]:
				changed = true
	grid = next_state
	if changed:
		request_render()

func spawn_turmites(count: int, color: Color) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(count):
		turmites.append(Vector2i(rng.randi_range(0, grid_size.x - 1), rng.randi_range(0, grid_size.y - 1)))
		turmite_directions.append(rng.randi_range(0, DIRS.size() - 1))
		turmite_colors.append(color)
	request_render()

func clear_turmites() -> void:
	turmites.clear()
	turmite_directions.clear()
	turmite_colors.clear()
	turmite_accumulator = 0.0
	request_render()

func remove_ants_at(pos: Vector2i) -> bool:
	var removed: bool = false
	var i: int = ants.size() - 1
	while i >= 0:
		if ants[i] == pos:
			ants.remove_at(i)
			ant_directions.remove_at(i)
			ant_colors.remove_at(i)
			removed = true
		i -= 1
	if removed and ants.is_empty():
		ant_accumulator = 0.0
	return removed

func remove_turmites_at(pos: Vector2i) -> bool:
	var removed: bool = false
	var i: int = turmites.size() - 1
	while i >= 0:
		if turmites[i] == pos:
			turmites.remove_at(i)
			turmite_directions.remove_at(i)
			turmite_colors.remove_at(i)
			removed = true
		i -= 1
	if removed and turmites.is_empty():
		turmite_accumulator = 0.0
	return removed

func step_turmites(use_workers: bool = true) -> void:
	if native_automata != null and native_automata.has_method("step_turmites"):
		var native_result: Dictionary = native_automata.call("step_turmites", grid, grid_size, edge_mode, turmites, turmite_directions, turmite_colors, turmite_rule)
		if native_result.has("grid") and native_result["grid"] is PackedByteArray:
			grid = native_result["grid"]
		if native_result.has("ants") and native_result["ants"] is Array:
			turmites = native_result["ants"]
		if native_result.has("directions") and native_result["directions"] is Array:
			turmite_directions = native_result["directions"]
		if native_result.has("colors") and native_result["colors"] is Array:
			turmite_colors = native_result["colors"]
		if native_result.get("changed", true):
			request_render()
		return
	if use_workers and not _grid_sim_busy():
		var args: Array = [grid.duplicate(), grid_size, edge_mode, turmites.duplicate(), turmite_directions.duplicate(), turmite_colors.duplicate(), turmite_rule]
		if _enqueue_sim_task("turmites", Callable(self, "sim_job_turmites"), args):
			return
	var remove_indices: Array[int] = []
	var rule_upper: String = turmite_rule.to_upper()
	if rule_upper.length() < 2:
		rule_upper = "RL"
	for i in range(turmites.size()):
		var pos: Vector2i = turmites[i]
		if pos.x < 0 or pos.x >= grid_size.x or pos.y < 0 or pos.y >= grid_size.y:
			remove_indices.append(i)
			continue

		var idx: int = pos.y * grid_size.x + pos.x
		var current: int = grid[idx]
		var rule_idx: int = clamp(current, 0, rule_upper.length() - 1)
		var turn: String = rule_upper[rule_idx]
		if turn == "R":
			turmite_directions[i] = (turmite_directions[i] + 1) % DIRS.size()
		else:
			turmite_directions[i] = (turmite_directions[i] + DIRS.size() - 1) % DIRS.size()

		grid[idx] = 1 - current

		var next: Vector2i = pos + DIRS[turmite_directions[i]]
		if edge_mode == EDGE_WRAP:
			next = wrap_position(next)
		elif edge_mode == EDGE_BOUNCE:
			if next.x < 0 or next.x >= grid_size.x or next.y < 0 or next.y >= grid_size.y:
				turmite_directions[i] = (turmite_directions[i] + 2) % DIRS.size()
				next = pos + DIRS[turmite_directions[i]]
				next.x = clamp(next.x, 0, grid_size.x - 1)
				next.y = clamp(next.y, 0, grid_size.y - 1)
		elif edge_mode == EDGE_FALLOFF:
			if next.x < 0 or next.x >= grid_size.x or next.y < 0 or next.y >= grid_size.y:
				remove_indices.append(i)
				continue

		turmites[i] = next

	for j in range(remove_indices.size() - 1, -1, -1):
		var remove_idx: int = remove_indices[j]
		turmites.remove_at(remove_idx)
		turmite_directions.remove_at(remove_idx)
		turmite_colors.remove_at(remove_idx)
	if not turmites.is_empty() or not remove_indices.is_empty():
		request_render()

func add_sand_at(pos: Vector2i, amount: int) -> void:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return
	if pos.x < 0 or pos.x >= grid_size.x or pos.y < 0 or pos.y >= grid_size.y:
		return
	if sand_grid.size() != grid_size.x * grid_size.y:
		sand_grid.resize(grid_size.x * grid_size.y)
		sand_grid.fill(0)
	var idx: int = pos.y * grid_size.x + pos.x
	if idx >= 0 and idx < sand_grid.size():
		sand_grid[idx] += max(0, amount)
		sand_has_content = sand_grid_has_content()
		request_render()

func add_sand_to_center(amount: int) -> void:
	var center: Vector2i = Vector2i(grid_size.x / 2, grid_size.y / 2)
	add_sand_at(center, amount)

func clear_sand() -> void:
	var expected: int = grid_size.x * grid_size.y
	if sand_grid.size() != expected:
		sand_grid.resize(expected)
	sand_grid.fill(0)
	sand_accumulator = 0.0
	sand_has_content = false
	request_render()

func step_sand() -> void:
	if sand_grid.size() != grid_size.x * grid_size.y:
		sand_grid.resize(grid_size.x * grid_size.y)
		sand_grid.fill(0)
	if native_automata != null and native_automata.has_method("step_sand"):
		var native_result: Dictionary = native_automata.call("step_sand", sand_grid, grid_size, edge_mode)
		if native_result.has("grid") and native_result["grid"] is PackedInt32Array:
			sand_grid = native_result["grid"]
			sand_has_content = sand_grid_has_content()
			if native_result.get("changed", false):
				request_render()
			return
	if not _sim_busy("sand"):
		var args: Array = [sand_grid.duplicate(), grid_size, edge_mode]
		if _enqueue_sim_task("sand", Callable(self, "sim_job_sand"), args):
			return

	var updates: Array[Vector2i] = []
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var idx: int = y * grid_size.x + x
			if sand_grid[idx] >= 4:
				updates.append(Vector2i(x, y))
	if updates.is_empty():
		sand_has_content = sand_grid_has_content()
		return

	for pos in updates:
		var idx: int = pos.y * grid_size.x + pos.x
		sand_grid[idx] -= 4
		for dir in DIRS:
			var next: Vector2i = pos + dir
			match edge_mode:
				EDGE_WRAP:
					next = wrap_position(next)
				EDGE_BOUNCE:
					next.x = clamp(next.x, 0, grid_size.x - 1)
					next.y = clamp(next.y, 0, grid_size.y - 1)
				EDGE_FALLOFF:
					if next.x < 0 or next.x >= grid_size.x or next.y < 0 or next.y >= grid_size.y:
						continue
			var nidx: int = next.y * grid_size.x + next.x
			sand_grid[nidx] += 1
	sand_has_content = sand_grid_has_content()
	if not updates.is_empty():
		request_render()

func build_grid_image_from_data(size: Vector2i, data: PackedByteArray) -> Image:
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_R8)
	if data.size() == size.x * size.y:
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(data.size())
		for i in range(data.size()):
			bytes[i] = 255 if data[i] != 0 else 0
		img.set_data(size.x, size.y, false, Image.FORMAT_R8, bytes)
	return img

func build_sand_image_from_data(size: Vector2i, data: PackedInt32Array, palette: Array[Color]) -> Dictionary:
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_R8)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size.x * size.y)
	var palette_size: int = max(1, palette.size())
	var has_content: bool = false
	var data_size: int = data.size()
	for i in range(bytes.size()):
		var value: int = 0
		if i < data_size:
			value = data[i]
		if value > 0:
			has_content = true
		var encoded: int = 0
		if value > 0:
			encoded = min(value, palette_size)
		bytes[i] = encoded
	img.set_data(size.x, size.y, false, Image.FORMAT_R8, bytes)
	return {"image": img, "has_content": has_content}

func build_overlay_image_from_data(size: Vector2i, ant_pos: Array[Vector2i], ant_cols: Array[Color], turmite_pos: Array[Vector2i], turmite_cols: Array[Color]) -> Image:
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for i in range(ant_pos.size()):
		var pos: Vector2i = ant_pos[i]
		if pos.x >= 0 and pos.x < size.x and pos.y >= 0 and pos.y < size.y:
			img.set_pixel(pos.x, pos.y, ant_cols[i])
	for i in range(turmite_pos.size()):
		var pos: Vector2i = turmite_pos[i]
		if pos.x >= 0 and pos.x < size.x and pos.y >= 0 and pos.y < size.y:
			img.set_pixel(pos.x, pos.y, turmite_cols[i])
	return img

func capture_render_state() -> Dictionary:
	return {
		"grid_size": grid_size,
		"grid": grid,
		"sand_grid": sand_grid.duplicate(),
		"sand_colors": sand_colors.duplicate(true),
		"ants": ants.duplicate(true),
		"ant_colors": ant_colors.duplicate(true),
		"turmites": turmites.duplicate(true),
		"turmite_colors": turmite_colors.duplicate(true),
	}

func build_render_component(params: Dictionary, component: String) -> Dictionary:
	var size: Vector2i = params.get("grid_size", Vector2i.ZERO)
	var grid_data: PackedByteArray = params.get("grid", PackedByteArray())
	var sand_data: PackedInt32Array = params.get("sand_grid", PackedInt32Array())
	var palette: Array = params.get("sand_colors", [])
	var ant_pos: Array = params.get("ants", [])
	var ant_cols: Array = params.get("ant_colors", [])
	var turmite_pos: Array = params.get("turmites", [])
	var turmite_cols: Array = params.get("turmite_colors", [])

	var result: Dictionary = {}
	if component == "grid":
		result[component] = build_grid_image_from_data(size, grid_data)
	elif component == "sand":
		var sand_render: Dictionary = build_sand_image_from_data(size, sand_data, palette)
		result[component] = sand_render.get("image", null)
		result["sand_has_content"] = sand_render.get("has_content", false)
	elif component == "overlay":
		result[component] = build_overlay_image_from_data(size, ant_pos, ant_cols, turmite_pos, turmite_cols)

	render_task_mutex.lock()
	for key in result.keys():
		render_task_result[key] = result[key]
	render_task_mutex.unlock()

	return result

func start_render_task() -> void:
	if render_task_ids.size() > 0:
		return
	if grid_size.x <= 0 or grid_size.y <= 0:
		render_pending = false
		return
	var params: Dictionary = capture_render_state()
	render_task_mutex.lock()
	render_task_result.clear()
	render_task_mutex.unlock()

	var components: Array[String] = ["grid", "sand", "overlay"]
	for component in components:
		var task_id: int = WorkerThreadPool.add_task(Callable(self, "build_render_component").bind(params, component), false, "render_" + component)
		render_task_ids.append(task_id)
	render_pending = false

func apply_render_result(result: Dictionary) -> void:
	var img: Image = result.get("grid", null)
	var sand_img: Image = result.get("sand", null)
	var overlay_img: Image = result.get("overlay", null)
	sand_has_content = result.get("sand_has_content", sand_has_content)

	if img != null:
		state_texture = update_image_texture(state_texture, img)
	if sand_img != null:
		sand_texture = update_image_texture(sand_texture, sand_img)
	if overlay_img != null:
		overlay_texture = update_image_texture(overlay_texture, overlay_img)

	if state_texture != null:
		grid_view.texture = state_texture
	if grid_material.shader != null:
		grid_material.set_shader_parameter("state_tex", state_texture)
		grid_material.set_shader_parameter("sand_tex", sand_texture)
		grid_material.set_shader_parameter("overlay_tex", overlay_texture)
		grid_material.set_shader_parameter("alive_color", alive_color)
		grid_material.set_shader_parameter("dead_color", dead_color)
		grid_material.set_shader_parameter("sand_palette", sand_colors)
		grid_material.set_shader_parameter("sand_palette_size", sand_colors.size())
		grid_material.set_shader_parameter("sand_visible", sand_enabled or sand_has_content)
		grid_material.set_shader_parameter("grid_lines_enabled", grid_lines_enabled)
		grid_material.set_shader_parameter("grid_line_color", grid_line_color)
		grid_material.set_shader_parameter("grid_line_thickness", float(grid_line_thickness))
		grid_material.set_shader_parameter("cell_size", float(cell_size))
		grid_view.queue_redraw()
	layout_grid_view(Vector2i(grid_size.x, grid_size.y))

func take_render_result() -> Dictionary:
	render_task_mutex.lock()
	var result: Dictionary = render_task_result.duplicate(true)
	render_task_result.clear()
	render_task_mutex.unlock()
	return result

func render_grid_sync() -> void:
	var result: Dictionary = {}
	var params: Dictionary = capture_render_state()
	var components: Array[String] = ["grid", "sand", "overlay"]
	for component in components:
		result.merge(build_render_component(params, component))
	apply_render_result(result)

func update_image_texture(tex: ImageTexture, img: Image) -> ImageTexture:
	if tex == null:
		return ImageTexture.create_from_image(img)
	if tex.get_width() != img.get_width() or tex.get_height() != img.get_height():
		tex = ImageTexture.create_from_image(img)
	else:
		tex.update(img)
	return tex

func _apply_sim_results() -> bool:
	var changed: bool = false
	var to_vector2_array := func(raw: Array) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for v in raw:
			if v is Vector2i:
				out.append(v)
		return out
	var to_color_array := func(raw: Array) -> Array[Color]:
		var out: Array[Color] = []
		for v in raw:
			if v is Color:
				out.append(v)
		return out
	var to_int_array := func(raw: Array) -> Array[int]:
		var out: Array[int] = []
		for v in raw:
			out.append(int(v))
		return out
	var wolfram_result: Dictionary = _take_sim_result("wolfram")
	if not wolfram_result.is_empty():
		if wolfram_result.has("grid") and wolfram_result["grid"] is PackedByteArray:
			grid = wolfram_result["grid"]
		if wolfram_result.has("row"):
			wolfram_row = int(wolfram_result.get("row", wolfram_row))
		if wolfram_result.get("changed", true):
			changed = true
	var totalistic_result: Dictionary = _take_sim_result("totalistic")
	if not totalistic_result.is_empty():
		if totalistic_result.has("grid") and totalistic_result["grid"] is PackedByteArray:
			grid = totalistic_result["grid"]
		if totalistic_result.get("changed", true):
			changed = true
	var ants_result: Dictionary = _take_sim_result("ants")
	if not ants_result.is_empty():
		if ants_result.has("grid") and ants_result["grid"] is PackedByteArray:
			grid = ants_result["grid"]
		if ants_result.has("ants") and ants_result["ants"] is Array:
			ants = to_vector2_array.call(ants_result["ants"])
		if ants_result.has("directions") and ants_result["directions"] is Array:
			ant_directions = to_int_array.call(ants_result["directions"])
		if ants_result.has("colors") and ants_result["colors"] is Array:
			ant_colors = to_color_array.call(ants_result["colors"])
		if ants_result.get("changed", true):
			changed = true
	var turmite_result: Dictionary = _take_sim_result("turmites")
	if not turmite_result.is_empty():
		if turmite_result.has("grid") and turmite_result["grid"] is PackedByteArray:
			grid = turmite_result["grid"]
		if turmite_result.has("ants") and turmite_result["ants"] is Array:
			turmites = to_vector2_array.call(turmite_result["ants"])
		if turmite_result.has("directions") and turmite_result["directions"] is Array:
			turmite_directions = to_int_array.call(turmite_result["directions"])
		if turmite_result.has("colors") and turmite_result["colors"] is Array:
			turmite_colors = to_color_array.call(turmite_result["colors"])
		if turmite_result.get("changed", true):
			changed = true
	var sand_result: Dictionary = _take_sim_result("sand")
	if not sand_result.is_empty():
		if sand_result.has("grid") and sand_result["grid"] is PackedInt32Array:
			sand_grid = sand_result["grid"]
			sand_has_content = sand_grid_has_content()
		if sand_result.get("changed", false):
			changed = true
	return changed

func layout_grid_view(tex_size: Vector2i) -> void:
	if view_container == null:
		return
	var container_size: Vector2 = view_container.get_rect().size
	if tex_size.x <= 0 or tex_size.y <= 0:
		return

	var display_size: Vector2 = Vector2(tex_size) * float(cell_size)
	grid_view.scale = Vector2.ONE
	grid_view.size = display_size
	grid_view.custom_minimum_size = display_size
	var offset: Vector2 = Vector2.ZERO
	if display_size.x < container_size.x:
		offset.x = (container_size.x - display_size.x) * 0.5
	if display_size.y < container_size.y:
		offset.y = (container_size.y - display_size.y) * 0.5
	grid_view.position = offset

func export_grid_image(path: String) -> void:
	if grid_size.x <= 0 or grid_size.y <= 0:
		set_info_label_text("Export failed (empty grid)")
		return
	render_grid_sync()
	var img: Image = build_export_image()
	img.resize(grid_size.x * cell_size, grid_size.y * cell_size, Image.INTERPOLATE_NEAREST)
	if grid_lines_enabled and grid_line_thickness > 0:
		draw_grid_lines_on_image(img)
	if Engine.has_singleton("JavaScriptBridge"):
		var buffer: PackedByteArray = img.save_png_to_buffer()
		if buffer.size() > 0:
			JavaScriptBridge.download_buffer(buffer, resolve_web_export_filename(path), "image/png")
			export_counter += 1
			set_info_label_text("Exported: %s" % resolve_web_export_filename(path))
		else:
			set_info_label_text("Export failed (empty buffer)")
	else:
		var abs_path: String = ProjectSettings.globalize_path(path)
		var dir_path: String = abs_path.get_base_dir()
		if dir_path != "" and dir_path != ".":
			DirAccess.make_dir_recursive_absolute(dir_path)
		var err: int = img.save_png(abs_path)
		if err == OK:
			export_counter += 1
			set_info_label_text("Exported: %s" % abs_path)
		else:
			set_info_label_text("Export failed (%d)" % err)
	request_render()

func build_export_image() -> Image:
	var img: Image = Image.create(grid_size.x, grid_size.y, false, Image.FORMAT_RGBA8)
	var palette_size: int = max(1, sand_colors.size())
	var sand_visible: bool = sand_enabled or sand_has_content
	var overlay_map: Dictionary = {}
	for i in range(ants.size()):
		overlay_map[ants[i]] = ant_colors[i]
	for i in range(turmites.size()):
		overlay_map[turmites[i]] = turmite_colors[i]
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var idx: int = y * grid_size.x + x
			var color: Color = dead_color if grid[idx] == 0 else alive_color
			if sand_visible and idx < sand_grid.size():
				var raw: int = sand_grid[idx]
				if raw > 0:
					var palette_idx: int = clamp(min(raw, palette_size) - 1, 0, palette_size - 1)
					color = sand_colors[palette_idx]
			var pos: Vector2i = Vector2i(x, y)
			if overlay_map.has(pos):
				color = overlay_map[pos]
			img.set_pixel(x, y, color)
	return img

func draw_grid_lines_on_image(img: Image) -> void:
	var width: int = img.get_width()
	var height: int = img.get_height()
	for gx in range(grid_size.x + 1):
		var start_x: int = gx * cell_size
		for t in range(grid_line_thickness):
			var px: int = start_x + t
			if px >= width:
				continue
			for py in range(height):
				img.set_pixel(px, py, grid_line_color)
	for gy in range(grid_size.y + 1):
		var start_y: int = gy * cell_size
		for t in range(grid_line_thickness):
			var py: int = start_y + t
			if py >= height:
				continue
			for px in range(width):
				img.set_pixel(px, py, grid_line_color)

static func _compute_totalistic_secondary(grid_in: PackedByteArray, grid_size_in: Vector2i, birth: Array, survive: Array, edge_mode_in: int) -> Dictionary:
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "changed": false}
	var next_state: PackedByteArray = PackedByteArray()
	next_state.resize(grid_in.size())
	var birth_set: Array = birth
	var survive_set: Array = survive
	var changed: bool = false
	for y in range(grid_size_in.y):
		for x in range(grid_size_in.x):
			var alive: int = _sample_cell_secondary(grid_in, grid_size_in, edge_mode_in, x, y)
			var neighbors: int = 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					neighbors += _sample_cell_secondary(grid_in, grid_size_in, edge_mode_in, x + dx, y + dy)
			var new_val: int = 0
			if alive == 1:
				if survive_set.has(neighbors):
					new_val = 1
			else:
				if birth_set.has(neighbors):
					new_val = 1
			var idx: int = y * grid_size_in.x + x
			next_state[idx] = new_val
			if not changed and new_val != grid_in[idx]:
				changed = true
	return {"grid": next_state, "changed": changed}

static func _sample_cell_secondary(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, x: int, y: int) -> int:
	if x >= 0 and x < grid_size_in.x and y >= 0 and y < grid_size_in.y:
		return grid_in[y * grid_size_in.x + x]
	match edge_mode_in:
		EDGE_WRAP:
			var nx: int = posmod(x, grid_size_in.x)
			var ny: int = posmod(y, grid_size_in.y)
			return grid_in[ny * grid_size_in.x + nx]
		EDGE_BOUNCE:
			var bounce_x: int = x
			var bounce_y: int = y
			if bounce_x < 0:
				bounce_x = -bounce_x - 1
			elif bounce_x >= grid_size_in.x:
				bounce_x = grid_size_in.x - (bounce_x - grid_size_in.x) - 1
			if bounce_y < 0:
				bounce_y = -bounce_y - 1
			elif bounce_y >= grid_size_in.y:
				bounce_y = grid_size_in.y - (bounce_y - grid_size_in.y) - 1
			bounce_x = clamp(bounce_x, 0, grid_size_in.x - 1)
			bounce_y = clamp(bounce_y, 0, grid_size_in.y - 1)
			return grid_in[bounce_y * grid_size_in.x + bounce_x]
		_:
			return 0

static func _compute_wolfram_secondary(grid_in: PackedByteArray, grid_size_in: Vector2i, rule: int, row: int, edge_mode_in: int, allow_wrap: bool) -> Dictionary:
	if grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "row": row, "changed": false}
	var wolfram_row_local: int = row
	if allow_wrap and grid_size_in.y > 0:
		wolfram_row_local = wolfram_row_local % grid_size_in.y
	if wolfram_row_local >= grid_size_in.y and not allow_wrap:
		return {"grid": grid_in, "row": wolfram_row_local, "changed": false}
	var next_state: PackedByteArray = grid_in
	var source_row: int = 0
	if wolfram_row_local <= 0:
		source_row = grid_size_in.y - 1 if allow_wrap else 0
	else:
		source_row = wolfram_row_local - 1
	var changed: bool = true
	for x in range(grid_size_in.x):
		var left: int = _sample_cell_secondary(grid_in, grid_size_in, edge_mode_in, x - 1, source_row)
		var center: int = _sample_cell_secondary(grid_in, grid_size_in, edge_mode_in, x, source_row)
		var right: int = _sample_cell_secondary(grid_in, grid_size_in, edge_mode_in, x + 1, source_row)
		var key: int = (left << 2) | (center << 1) | right
		var state: int = (rule >> key) & 1
		next_state[wolfram_row_local * grid_size_in.x + x] = state
	var next_row: int = wolfram_row_local + 1
	if allow_wrap:
		next_row = (wolfram_row_local + 1) % grid_size_in.y
	return {"grid": next_state, "row": next_row, "changed": changed}

static func _compute_ants_secondary(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, ants_in: Array, dirs_in: Array, colors_in: Array) -> Dictionary:
	var count: int = min(ants_in.size(), dirs_in.size())
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y or count <= 0:
		return {"grid": grid_in, "ants": ants_in, "directions": dirs_in, "colors": colors_in, "changed": false}
	var next_grid: PackedByteArray = grid_in
	var next_ants: Array = []
	var next_dirs: Array = []
	var next_colors: Array = []
	var changed: bool = false
	for i in range(count):
		var pos: Vector2i = ants_in[i]
		if pos.x < 0 or pos.x >= grid_size_in.x or pos.y < 0 or pos.y >= grid_size_in.y:
			changed = true
			continue
		var dir: int = int(dirs_in[i]) % DIRS.size()
		if dir < 0:
			dir += DIRS.size()
		var idx: int = pos.y * grid_size_in.x + pos.x
		var current: int = next_grid[idx]
		if current == 1:
			dir = (dir + 1) % DIRS.size()
			next_grid[idx] = 0
		else:
			dir = (dir + DIRS.size() - 1) % DIRS.size()
			next_grid[idx] = 1
		var next: Vector2i = pos + DIRS[dir]
		match edge_mode_in:
			EDGE_WRAP:
				next = Vector2i(posmod(next.x, grid_size_in.x), posmod(next.y, grid_size_in.y))
			EDGE_BOUNCE:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					dir = (dir + 2) % DIRS.size()
					next = pos + DIRS[dir]
					next.x = clamp(next.x, 0, grid_size_in.x - 1)
					next.y = clamp(next.y, 0, grid_size_in.y - 1)
			EDGE_FALLOFF:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					changed = true
					continue
		if not changed and (pos != next or dir != int(dirs_in[i]) or next_grid[idx] != current):
			changed = true
		next_ants.append(next)
		next_dirs.append(dir)
		if i < colors_in.size():
			next_colors.append(colors_in[i])
		else:
			next_colors.append(Color.WHITE)
	return {"grid": next_grid, "ants": next_ants, "directions": next_dirs, "colors": next_colors, "changed": changed}

static func _compute_turmites_secondary(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, ants_in: Array, dirs_in: Array, colors_in: Array, rule: String) -> Dictionary:
	var count: int = min(ants_in.size(), dirs_in.size())
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y or count <= 0:
		return {"grid": grid_in, "ants": ants_in, "directions": dirs_in, "colors": colors_in, "changed": false}
	var next_grid: PackedByteArray = grid_in
	var rule_upper: String = rule.to_upper()
	if rule_upper.length() < 2:
		rule_upper = "RL"
	var next_ants: Array = []
	var next_dirs: Array = []
	var next_colors: Array = []
	var changed: bool = false
	for i in range(count):
		var pos: Vector2i = ants_in[i]
		if pos.x < 0 or pos.x >= grid_size_in.x or pos.y < 0 or pos.y >= grid_size_in.y:
			changed = true
			continue
		var dir: int = int(dirs_in[i]) % DIRS.size()
		if dir < 0:
			dir += DIRS.size()
		var idx: int = pos.y * grid_size_in.x + pos.x
		var current: int = next_grid[idx]
		var rule_idx: int = clamp(current, 0, rule_upper.length() - 1)
		var turn: String = rule_upper[rule_idx]
		if turn == "R":
			dir = (dir + 1) % DIRS.size()
		else:
			dir = (dir + DIRS.size() - 1) % DIRS.size()
		next_grid[idx] = 1 - current
		var next: Vector2i = pos + DIRS[dir]
		match edge_mode_in:
			EDGE_WRAP:
				next = Vector2i(posmod(next.x, grid_size_in.x), posmod(next.y, grid_size_in.y))
			EDGE_BOUNCE:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					dir = (dir + 2) % DIRS.size()
					next = pos + DIRS[dir]
					next.x = clamp(next.x, 0, grid_size_in.x - 1)
					next.y = clamp(next.y, 0, grid_size_in.y - 1)
			EDGE_FALLOFF:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					changed = true
					continue
		if not changed and (pos != next or dir != int(dirs_in[i]) or next_grid[idx] != current):
			changed = true
		next_ants.append(next)
		next_dirs.append(dir)
		if i < colors_in.size():
			next_colors.append(colors_in[i])
		else:
			next_colors.append(Color.WHITE)
	return {"grid": next_grid, "ants": next_ants, "directions": next_dirs, "colors": next_colors, "changed": changed}

static func _compute_sand_secondary(grid_in: PackedInt32Array, grid_size_in: Vector2i, edge_mode_in: int) -> Dictionary:
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "changed": false}
	var updates: Array[Vector2i] = []
	for y in range(grid_size_in.y):
		for x in range(grid_size_in.x):
			var idx: int = y * grid_size_in.x + x
			if grid_in[idx] >= 4:
				updates.append(Vector2i(x, y))
	if updates.is_empty():
		return {"grid": grid_in, "changed": false}
	var next: PackedInt32Array = grid_in
	for pos in updates:
		var idx: int = pos.y * grid_size_in.x + pos.x
		next[idx] -= 4
		for dir in DIRS:
			var npos: Vector2i = pos + dir
			match edge_mode_in:
				EDGE_WRAP:
					npos = Vector2i(posmod(npos.x, grid_size_in.x), posmod(npos.y, grid_size_in.y))
				EDGE_BOUNCE:
					npos.x = clamp(npos.x, 0, grid_size_in.x - 1)
					npos.y = clamp(npos.y, 0, grid_size_in.y - 1)
				EDGE_FALLOFF:
					if npos.x < 0 or npos.x >= grid_size_in.x or npos.y < 0 or npos.y >= grid_size_in.y:
						continue
			var nidx: int = npos.y * grid_size_in.x + npos.x
			next[nidx] += 1
	return {"grid": next, "changed": true}

static func _compute_totalistic(grid_in: PackedByteArray, grid_size_in: Vector2i, birth: Array, survive: Array, edge_mode_in: int) -> Dictionary:
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "changed": false}
	var next_state: PackedByteArray = PackedByteArray()
	next_state.resize(grid_in.size())
	var birth_set: Array = birth
	var survive_set: Array = survive
	var changed: bool = false
	for y in range(grid_size_in.y):
		for x in range(grid_size_in.x):
			var alive: int = _sample_cell(grid_in, grid_size_in, edge_mode_in, x, y)
			var neighbors: int = 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					neighbors += _sample_cell(grid_in, grid_size_in, edge_mode_in, x + dx, y + dy)
			var new_val: int = 0
			if alive == 1:
				if survive_set.has(neighbors):
					new_val = 1
			else:
				if birth_set.has(neighbors):
					new_val = 1
			var idx: int = y * grid_size_in.x + x
			next_state[idx] = new_val
			if not changed and new_val != grid_in[idx]:
				changed = true
	return {"grid": next_state, "changed": changed}

static func _sample_cell(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, x: int, y: int) -> int:
	if x >= 0 and x < grid_size_in.x and y >= 0 and y < grid_size_in.y:
		return grid_in[y * grid_size_in.x + x]
	match edge_mode_in:
		EDGE_WRAP:
			var nx: int = posmod(x, grid_size_in.x)
			var ny: int = posmod(y, grid_size_in.y)
			return grid_in[ny * grid_size_in.x + nx]
		EDGE_BOUNCE:
			var bounce_x: int = x
			var bounce_y: int = y
			if bounce_x < 0:
				bounce_x = -bounce_x - 1
			elif bounce_x >= grid_size_in.x:
				bounce_x = grid_size_in.x - (bounce_x - grid_size_in.x) - 1
			if bounce_y < 0:
				bounce_y = -bounce_y - 1
			elif bounce_y >= grid_size_in.y:
				bounce_y = grid_size_in.y - (bounce_y - grid_size_in.y) - 1
			bounce_x = clamp(bounce_x, 0, grid_size_in.x - 1)
			bounce_y = clamp(bounce_y, 0, grid_size_in.y - 1)
			return grid_in[bounce_y * grid_size_in.x + bounce_x]
		_:
			return 0

static func _compute_wolfram(grid_in: PackedByteArray, grid_size_in: Vector2i, rule: int, row: int, edge_mode_in: int, allow_wrap: bool) -> Dictionary:
	if grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "row": row, "changed": false}
	var wolfram_row_local: int = row
	if allow_wrap and grid_size_in.y > 0:
		wolfram_row_local = wolfram_row_local % grid_size_in.y
	if wolfram_row_local >= grid_size_in.y and not allow_wrap:
		return {"grid": grid_in, "row": wolfram_row_local, "changed": false}
	var next_state: PackedByteArray = grid_in
	var source_row: int = 0
	if wolfram_row_local <= 0:
		source_row = grid_size_in.y - 1 if allow_wrap else 0
	else:
		source_row = wolfram_row_local - 1
	var changed: bool = true
	for x in range(grid_size_in.x):
		var left: int = _sample_cell(grid_in, grid_size_in, edge_mode_in, x - 1, source_row)
		var center: int = _sample_cell(grid_in, grid_size_in, edge_mode_in, x, source_row)
		var right: int = _sample_cell(grid_in, grid_size_in, edge_mode_in, x + 1, source_row)
		var key: int = (left << 2) | (center << 1) | right
		var state: int = (rule >> key) & 1
		next_state[wolfram_row_local * grid_size_in.x + x] = state
	var next_row: int = wolfram_row_local + 1
	if allow_wrap:
		next_row = (wolfram_row_local + 1) % grid_size_in.y
	return {"grid": next_state, "row": next_row, "changed": changed}

static func _compute_ants(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, ants_in: Array, dirs_in: Array, colors_in: Array) -> Dictionary:
	var count: int = min(ants_in.size(), dirs_in.size())
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y or count <= 0:
		return {"grid": grid_in, "ants": ants_in, "directions": dirs_in, "colors": colors_in, "changed": false}
	var next_grid: PackedByteArray = grid_in
	var next_ants: Array = []
	var next_dirs: Array = []
	var next_colors: Array = []
	var changed: bool = false
	for i in range(count):
		var pos: Vector2i = ants_in[i]
		if pos.x < 0 or pos.x >= grid_size_in.x or pos.y < 0 or pos.y >= grid_size_in.y:
			changed = true
			continue
		var dir: int = int(dirs_in[i]) % DIRS.size()
		if dir < 0:
			dir += DIRS.size()
		var idx: int = pos.y * grid_size_in.x + pos.x
		var current: int = next_grid[idx]
		if current == 1:
			dir = (dir + 1) % DIRS.size()
			next_grid[idx] = 0
		else:
			dir = (dir + DIRS.size() - 1) % DIRS.size()
			next_grid[idx] = 1
		var next: Vector2i = pos + DIRS[dir]
		match edge_mode_in:
			EDGE_WRAP:
				next = Vector2i(posmod(next.x, grid_size_in.x), posmod(next.y, grid_size_in.y))
			EDGE_BOUNCE:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					dir = (dir + 2) % DIRS.size()
					next = pos + DIRS[dir]
					next.x = clamp(next.x, 0, grid_size_in.x - 1)
					next.y = clamp(next.y, 0, grid_size_in.y - 1)
			EDGE_FALLOFF:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					changed = true
					continue
		if not changed and (pos != next or dir != int(dirs_in[i]) or next_grid[idx] != current):
			changed = true
		next_ants.append(next)
		next_dirs.append(dir)
		if i < colors_in.size():
			next_colors.append(colors_in[i])
		else:
			next_colors.append(Color.WHITE)
	return {"grid": next_grid, "ants": next_ants, "directions": next_dirs, "colors": next_colors, "changed": changed}

static func _compute_turmites(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, ants_in: Array, dirs_in: Array, colors_in: Array, rule: String) -> Dictionary:
	var count: int = min(ants_in.size(), dirs_in.size())
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y or count <= 0:
		return {"grid": grid_in, "ants": ants_in, "directions": dirs_in, "colors": colors_in, "changed": false}
	var next_grid: PackedByteArray = grid_in
	var rule_upper: String = rule.to_upper()
	if rule_upper.length() < 2:
		rule_upper = "RL"
	var next_ants: Array = []
	var next_dirs: Array = []
	var next_colors: Array = []
	var changed: bool = false
	for i in range(count):
		var pos: Vector2i = ants_in[i]
		if pos.x < 0 or pos.x >= grid_size_in.x or pos.y < 0 or pos.y >= grid_size_in.y:
			changed = true
			continue
		var dir: int = int(dirs_in[i]) % DIRS.size()
		if dir < 0:
			dir += DIRS.size()
		var idx: int = pos.y * grid_size_in.x + pos.x
		var current: int = next_grid[idx]
		var rule_idx: int = clamp(current, 0, rule_upper.length() - 1)
		var turn: String = rule_upper[rule_idx]
		if turn == "R":
			dir = (dir + 1) % DIRS.size()
		else:
			dir = (dir + DIRS.size() - 1) % DIRS.size()
		next_grid[idx] = 1 - current
		var next: Vector2i = pos + DIRS[dir]
		match edge_mode_in:
			EDGE_WRAP:
				next = Vector2i(posmod(next.x, grid_size_in.x), posmod(next.y, grid_size_in.y))
			EDGE_BOUNCE:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					dir = (dir + 2) % DIRS.size()
					next = pos + DIRS[dir]
					next.x = clamp(next.x, 0, grid_size_in.x - 1)
					next.y = clamp(next.y, 0, grid_size_in.y - 1)
			EDGE_FALLOFF:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					changed = true
					continue
		if not changed and (pos != next or dir != int(dirs_in[i]) or next_grid[idx] != current):
			changed = true
		next_ants.append(next)
		next_dirs.append(dir)
		if i < colors_in.size():
			next_colors.append(colors_in[i])
		else:
			next_colors.append(Color.WHITE)
	return {"grid": next_grid, "ants": next_ants, "directions": next_dirs, "colors": next_colors, "changed": changed}

static func _compute_sand(grid_in: PackedInt32Array, grid_size_in: Vector2i, edge_mode_in: int) -> Dictionary:
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "changed": false}
	var updates: Array[Vector2i] = []
	for y in range(grid_size_in.y):
		for x in range(grid_size_in.x):
			var idx: int = y * grid_size_in.x + x
			if grid_in[idx] >= 4:
				updates.append(Vector2i(x, y))
	if updates.is_empty():
		return {"grid": grid_in, "changed": false}
	var next: PackedInt32Array = grid_in
	for pos in updates:
		var idx: int = pos.y * grid_size_in.x + pos.x
		next[idx] -= 4
		for dir in DIRS:
			var npos: Vector2i = pos + dir
			match edge_mode_in:
				EDGE_WRAP:
					npos = Vector2i(posmod(npos.x, grid_size_in.x), posmod(npos.y, grid_size_in.y))
				EDGE_BOUNCE:
					npos.x = clamp(npos.x, 0, grid_size_in.x - 1)
					npos.y = clamp(npos.y, 0, grid_size_in.y - 1)
				EDGE_FALLOFF:
					if npos.x < 0 or npos.x >= grid_size_in.x or npos.y < 0 or npos.y >= grid_size_in.y:
						continue
			var nidx: int = npos.y * grid_size_in.x + npos.x
			next[nidx] += 1
	return {"grid": next, "changed": true}

static func _thread_compute_totalistic(grid_in: PackedByteArray, grid_size_in: Vector2i, birth: Array, survive: Array, edge_mode_in: int) -> Dictionary:
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "changed": false}
	var next_state: PackedByteArray = PackedByteArray()
	next_state.resize(grid_in.size())
	var birth_set: Array = birth
	var survive_set: Array = survive
	var changed: bool = false
	for y in range(grid_size_in.y):
		for x in range(grid_size_in.x):
			var alive: int = _thread_sample_cell(grid_in, grid_size_in, edge_mode_in, x, y)
			var neighbors: int = 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					neighbors += _thread_sample_cell(grid_in, grid_size_in, edge_mode_in, x + dx, y + dy)
			var new_val: int = 0
			if alive == 1:
				if survive_set.has(neighbors):
					new_val = 1
			else:
				if birth_set.has(neighbors):
					new_val = 1
			var idx: int = y * grid_size_in.x + x
			next_state[idx] = new_val
			if not changed and new_val != grid_in[idx]:
				changed = true
	return {"grid": next_state, "changed": changed}

static func _thread_sample_cell(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, x: int, y: int) -> int:
	if x >= 0 and x < grid_size_in.x and y >= 0 and y < grid_size_in.y:
		return grid_in[y * grid_size_in.x + x]
	match edge_mode_in:
		EDGE_WRAP:
			var nx: int = posmod(x, grid_size_in.x)
			var ny: int = posmod(y, grid_size_in.y)
			return grid_in[ny * grid_size_in.x + nx]
		EDGE_BOUNCE:
			var bounce_x: int = x
			var bounce_y: int = y
			if bounce_x < 0:
				bounce_x = -bounce_x - 1
			elif bounce_x >= grid_size_in.x:
				bounce_x = grid_size_in.x - (bounce_x - grid_size_in.x) - 1
			if bounce_y < 0:
				bounce_y = -bounce_y - 1
			elif bounce_y >= grid_size_in.y:
				bounce_y = grid_size_in.y - (bounce_y - grid_size_in.y) - 1
			bounce_x = clamp(bounce_x, 0, grid_size_in.x - 1)
			bounce_y = clamp(bounce_y, 0, grid_size_in.y - 1)
			return grid_in[bounce_y * grid_size_in.x + bounce_x]
		_:
			return 0

static func _thread_compute_wolfram(grid_in: PackedByteArray, grid_size_in: Vector2i, rule: int, row: int, edge_mode_in: int, allow_wrap: bool) -> Dictionary:
	if grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "row": row, "changed": false}
	var wolfram_row_local: int = row
	if allow_wrap and grid_size_in.y > 0:
		wolfram_row_local = wolfram_row_local % grid_size_in.y
	if wolfram_row_local >= grid_size_in.y and not allow_wrap:
		return {"grid": grid_in, "row": wolfram_row_local, "changed": false}
	var next_state: PackedByteArray = grid_in
	var source_row: int = 0
	if wolfram_row_local <= 0:
		source_row = grid_size_in.y - 1 if allow_wrap else 0
	else:
		source_row = wolfram_row_local - 1
	var changed: bool = true
	for x in range(grid_size_in.x):
		var left: int = _thread_sample_cell(grid_in, grid_size_in, edge_mode_in, x - 1, source_row)
		var center: int = _thread_sample_cell(grid_in, grid_size_in, edge_mode_in, x, source_row)
		var right: int = _thread_sample_cell(grid_in, grid_size_in, edge_mode_in, x + 1, source_row)
		var key: int = (left << 2) | (center << 1) | right
		var state: int = (rule >> key) & 1
		next_state[wolfram_row_local * grid_size_in.x + x] = state
	var next_row: int = wolfram_row_local + 1
	if allow_wrap:
		next_row = (wolfram_row_local + 1) % grid_size_in.y
	return {"grid": next_state, "row": next_row, "changed": changed}

static func _thread_compute_ants(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, ants_in: Array, dirs_in: Array, colors_in: Array) -> Dictionary:
	var count: int = min(ants_in.size(), dirs_in.size())
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y or count <= 0:
		return {"grid": grid_in, "ants": ants_in, "directions": dirs_in, "colors": colors_in, "changed": false}
	var next_grid: PackedByteArray = grid_in
	var next_ants: Array = []
	var next_dirs: Array = []
	var next_colors: Array = []
	var changed: bool = false
	for i in range(count):
		var pos: Vector2i = ants_in[i]
		if pos.x < 0 or pos.x >= grid_size_in.x or pos.y < 0 or pos.y >= grid_size_in.y:
			changed = true
			continue
		var dir: int = int(dirs_in[i]) % DIRS.size()
		if dir < 0:
			dir += DIRS.size()
		var idx: int = pos.y * grid_size_in.x + pos.x
		var current: int = next_grid[idx]
		if current == 1:
			dir = (dir + 1) % DIRS.size()
			next_grid[idx] = 0
		else:
			dir = (dir + DIRS.size() - 1) % DIRS.size()
			next_grid[idx] = 1
		var next: Vector2i = pos + DIRS[dir]
		match edge_mode_in:
			EDGE_WRAP:
				next = Vector2i(posmod(next.x, grid_size_in.x), posmod(next.y, grid_size_in.y))
			EDGE_BOUNCE:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					dir = (dir + 2) % DIRS.size()
					next = pos + DIRS[dir]
					next.x = clamp(next.x, 0, grid_size_in.x - 1)
					next.y = clamp(next.y, 0, grid_size_in.y - 1)
			EDGE_FALLOFF:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					changed = true
					continue
		if not changed and (pos != next or dir != int(dirs_in[i]) or next_grid[idx] != current):
			changed = true
		next_ants.append(next)
		next_dirs.append(dir)
		if i < colors_in.size():
			next_colors.append(colors_in[i])
		else:
			next_colors.append(Color.WHITE)
	return {"grid": next_grid, "ants": next_ants, "directions": next_dirs, "colors": next_colors, "changed": changed}

static func _thread_compute_turmites(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, ants_in: Array, dirs_in: Array, colors_in: Array, rule: String) -> Dictionary:
	var count: int = min(ants_in.size(), dirs_in.size())
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y or count <= 0:
		return {"grid": grid_in, "ants": ants_in, "directions": dirs_in, "colors": colors_in, "changed": false}
	var next_grid: PackedByteArray = grid_in
	var rule_upper: String = rule.to_upper()
	if rule_upper.length() < 2:
		rule_upper = "RL"
	var next_ants: Array = []
	var next_dirs: Array = []
	var next_colors: Array = []
	var changed: bool = false
	for i in range(count):
		var pos: Vector2i = ants_in[i]
		if pos.x < 0 or pos.x >= grid_size_in.x or pos.y < 0 or pos.y >= grid_size_in.y:
			changed = true
			continue
		var dir: int = int(dirs_in[i]) % DIRS.size()
		if dir < 0:
			dir += DIRS.size()
		var idx: int = pos.y * grid_size_in.x + pos.x
		var current: int = next_grid[idx]
		var rule_idx: int = clamp(current, 0, rule_upper.length() - 1)
		var turn: String = rule_upper[rule_idx]
		if turn == "R":
			dir = (dir + 1) % DIRS.size()
		else:
			dir = (dir + DIRS.size() - 1) % DIRS.size()
		next_grid[idx] = 1 - current
		var next: Vector2i = pos + DIRS[dir]
		match edge_mode_in:
			EDGE_WRAP:
				next = Vector2i(posmod(next.x, grid_size_in.x), posmod(next.y, grid_size_in.y))
			EDGE_BOUNCE:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					dir = (dir + 2) % DIRS.size()
					next = pos + DIRS[dir]
					next.x = clamp(next.x, 0, grid_size_in.x - 1)
					next.y = clamp(next.y, 0, grid_size_in.y - 1)
			EDGE_FALLOFF:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					changed = true
					continue
		if not changed and (pos != next or dir != int(dirs_in[i]) or next_grid[idx] != current):
			changed = true
		next_ants.append(next)
		next_dirs.append(dir)
		if i < colors_in.size():
			next_colors.append(colors_in[i])
		else:
			next_colors.append(Color.WHITE)
	return {"grid": next_grid, "ants": next_ants, "directions": next_dirs, "colors": next_colors, "changed": changed}

static func _thread_compute_sand(grid_in: PackedInt32Array, grid_size_in: Vector2i, edge_mode_in: int) -> Dictionary:
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "changed": false}
	var updates: Array[Vector2i] = []
	for y in range(grid_size_in.y):
		for x in range(grid_size_in.x):
			var idx: int = y * grid_size_in.x + x
			if grid_in[idx] >= 4:
				updates.append(Vector2i(x, y))
	if updates.is_empty():
		return {"grid": grid_in, "changed": false}
	var next: PackedInt32Array = grid_in
	for pos in updates:
		var idx: int = pos.y * grid_size_in.x + pos.x
		next[idx] -= 4
		for dir in DIRS:
			var npos: Vector2i = pos + dir
			match edge_mode_in:
				EDGE_WRAP:
					npos = Vector2i(posmod(npos.x, grid_size_in.x), posmod(npos.y, grid_size_in.y))
				EDGE_BOUNCE:
					npos.x = clamp(npos.x, 0, grid_size_in.x - 1)
					npos.y = clamp(npos.y, 0, grid_size_in.y - 1)
				EDGE_FALLOFF:
					if npos.x < 0 or npos.x >= grid_size_in.x or npos.y < 0 or npos.y >= grid_size_in.y:
						continue
			var nidx: int = npos.y * grid_size_in.x + npos.x
			next[nidx] += 1
	return {"grid": next, "changed": true}

static func _sim_totalistic_worker(grid_in: PackedByteArray, grid_size_in: Vector2i, birth: Array, survive: Array, edge_mode_in: int) -> Dictionary:
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "changed": false}
	var next_state: PackedByteArray = PackedByteArray()
	next_state.resize(grid_in.size())
	var birth_set: Array = birth
	var survive_set: Array = survive
	var changed: bool = false
	for y in range(grid_size_in.y):
		for x in range(grid_size_in.x):
			var alive: int = _sim_sample_cell(grid_in, grid_size_in, edge_mode_in, x, y)
			var neighbors: int = 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					neighbors += _sim_sample_cell(grid_in, grid_size_in, edge_mode_in, x + dx, y + dy)
			var new_val: int = 0
			if alive == 1:
				if survive_set.has(neighbors):
					new_val = 1
			else:
				if birth_set.has(neighbors):
					new_val = 1
			var idx: int = y * grid_size_in.x + x
			next_state[idx] = new_val
			if not changed and new_val != grid_in[idx]:
				changed = true
	return {"grid": next_state, "changed": changed}

static func _sim_sample_cell(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, x: int, y: int) -> int:
	var expected: int = grid_size_in.x * grid_size_in.y
	if expected <= 0 or grid_in.size() != expected:
		return 0
	if x >= 0 and x < grid_size_in.x and y >= 0 and y < grid_size_in.y:
		var idx: int = y * grid_size_in.x + x
		if idx >= 0 and idx < grid_in.size():
			return grid_in[idx]
		return 0
	match edge_mode_in:
		EDGE_WRAP:
			var nx: int = posmod(x, grid_size_in.x)
			var ny: int = posmod(y, grid_size_in.y)
			var wrapped_idx: int = ny * grid_size_in.x + nx
			return grid_in[wrapped_idx] if wrapped_idx >= 0 and wrapped_idx < grid_in.size() else 0
		EDGE_BOUNCE:
			var bounce_x: int = x
			var bounce_y: int = y
			if bounce_x < 0:
				bounce_x = -bounce_x - 1
			elif bounce_x >= grid_size_in.x:
				bounce_x = grid_size_in.x - (bounce_x - grid_size_in.x) - 1
			if bounce_y < 0:
				bounce_y = -bounce_y - 1
			elif bounce_y >= grid_size_in.y:
				bounce_y = grid_size_in.y - (bounce_y - grid_size_in.y) - 1
			bounce_x = clamp(bounce_x, 0, grid_size_in.x - 1)
			bounce_y = clamp(bounce_y, 0, grid_size_in.y - 1)
			var bounce_idx: int = bounce_y * grid_size_in.x + bounce_x
			return grid_in[bounce_idx] if bounce_idx >= 0 and bounce_idx < grid_in.size() else 0
		_:
			return 0

static func _sim_wolfram_worker(grid_in: PackedByteArray, grid_size_in: Vector2i, rule: int, row: int, edge_mode_in: int, allow_wrap: bool) -> Dictionary:
	if grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "row": row, "changed": false}
	var wolfram_row_local: int = row
	if allow_wrap and grid_size_in.y > 0:
		wolfram_row_local = wolfram_row_local % grid_size_in.y
	if wolfram_row_local >= grid_size_in.y and not allow_wrap:
		return {"grid": grid_in, "row": wolfram_row_local, "changed": false}
	var next_state: PackedByteArray = grid_in
	var source_row: int = 0
	if wolfram_row_local <= 0:
		source_row = grid_size_in.y - 1 if allow_wrap else 0
	else:
		source_row = wolfram_row_local - 1
	var changed: bool = true
	for x in range(grid_size_in.x):
		var left: int = _sim_sample_cell(grid_in, grid_size_in, edge_mode_in, x - 1, source_row)
		var center: int = _sim_sample_cell(grid_in, grid_size_in, edge_mode_in, x, source_row)
		var right: int = _sim_sample_cell(grid_in, grid_size_in, edge_mode_in, x + 1, source_row)
		var key: int = (left << 2) | (center << 1) | right
		var state: int = (rule >> key) & 1
		next_state[wolfram_row_local * grid_size_in.x + x] = state
	var next_row: int = wolfram_row_local + 1
	if allow_wrap:
		next_row = (wolfram_row_local + 1) % grid_size_in.y
	return {"grid": next_state, "row": next_row, "changed": changed}

static func _sim_ants_worker(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, ants_in: Array, dirs_in: Array, colors_in: Array) -> Dictionary:
	var count: int = min(ants_in.size(), dirs_in.size())
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y or count <= 0:
		return {"grid": grid_in, "ants": ants_in, "directions": dirs_in, "colors": colors_in, "changed": false}
	var next_grid: PackedByteArray = grid_in
	var next_ants: Array = []
	var next_dirs: Array = []
	var next_colors: Array = []
	var changed: bool = false
	for i in range(count):
		var pos: Vector2i = ants_in[i]
		if pos.x < 0 or pos.x >= grid_size_in.x or pos.y < 0 or pos.y >= grid_size_in.y:
			changed = true
			continue
		var dir: int = int(dirs_in[i]) % DIRS.size()
		if dir < 0:
			dir += DIRS.size()
		var idx: int = pos.y * grid_size_in.x + pos.x
		var current: int = next_grid[idx]
		if current == 1:
			dir = (dir + 1) % DIRS.size()
			next_grid[idx] = 0
		else:
			dir = (dir + DIRS.size() - 1) % DIRS.size()
			next_grid[idx] = 1
		var next: Vector2i = pos + DIRS[dir]
		match edge_mode_in:
			EDGE_WRAP:
				next = Vector2i(posmod(next.x, grid_size_in.x), posmod(next.y, grid_size_in.y))
			EDGE_BOUNCE:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					dir = (dir + 2) % DIRS.size()
					next = pos + DIRS[dir]
					next.x = clamp(next.x, 0, grid_size_in.x - 1)
					next.y = clamp(next.y, 0, grid_size_in.y - 1)
			EDGE_FALLOFF:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					changed = true
					continue
		if not changed and (pos != next or dir != int(dirs_in[i]) or next_grid[idx] != current):
			changed = true
		next_ants.append(next)
		next_dirs.append(dir)
		if i < colors_in.size():
			next_colors.append(colors_in[i])
		else:
			next_colors.append(Color.WHITE)
	return {"grid": next_grid, "ants": next_ants, "directions": next_dirs, "colors": next_colors, "changed": changed}

static func _sim_turmites_worker(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, ants_in: Array, dirs_in: Array, colors_in: Array, rule: String) -> Dictionary:
	var count: int = min(ants_in.size(), dirs_in.size())
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y or count <= 0:
		return {"grid": grid_in, "ants": ants_in, "directions": dirs_in, "colors": colors_in, "changed": false}
	var next_grid: PackedByteArray = grid_in
	var rule_upper: String = rule.to_upper()
	if rule_upper.length() < 2:
		rule_upper = "RL"
	var next_ants: Array = []
	var next_dirs: Array = []
	var next_colors: Array = []
	var changed: bool = false
	for i in range(count):
		var pos: Vector2i = ants_in[i]
		if pos.x < 0 or pos.x >= grid_size_in.x or pos.y < 0 or pos.y >= grid_size_in.y:
			changed = true
			continue
		var dir: int = int(dirs_in[i]) % DIRS.size()
		if dir < 0:
			dir += DIRS.size()
		var idx: int = pos.y * grid_size_in.x + pos.x
		var current: int = next_grid[idx]
		var rule_idx: int = clamp(current, 0, rule_upper.length() - 1)
		var turn: String = rule_upper[rule_idx]
		if turn == "R":
			dir = (dir + 1) % DIRS.size()
		else:
			dir = (dir + DIRS.size() - 1) % DIRS.size()
		next_grid[idx] = 1 - current
		var next: Vector2i = pos + DIRS[dir]
		match edge_mode_in:
			EDGE_WRAP:
				next = Vector2i(posmod(next.x, grid_size_in.x), posmod(next.y, grid_size_in.y))
			EDGE_BOUNCE:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					dir = (dir + 2) % DIRS.size()
					next = pos + DIRS[dir]
					next.x = clamp(next.x, 0, grid_size_in.x - 1)
					next.y = clamp(next.y, 0, grid_size_in.y - 1)
			EDGE_FALLOFF:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					changed = true
					continue
		if not changed and (pos != next or dir != int(dirs_in[i]) or next_grid[idx] != current):
			changed = true
		next_ants.append(next)
		next_dirs.append(dir)
		if i < colors_in.size():
			next_colors.append(colors_in[i])
		else:
			next_colors.append(Color.WHITE)
	return {"grid": next_grid, "ants": next_ants, "directions": next_dirs, "colors": next_colors, "changed": changed}

static func _sim_sand_worker(grid_in: PackedInt32Array, grid_size_in: Vector2i, edge_mode_in: int) -> Dictionary:
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "changed": false}
	var updates: Array[Vector2i] = []
	for y in range(grid_size_in.y):
		for x in range(grid_size_in.x):
			var idx: int = y * grid_size_in.x + x
			if grid_in[idx] >= 4:
				updates.append(Vector2i(x, y))
	if updates.is_empty():
		return {"grid": grid_in, "changed": false}
	var next: PackedInt32Array = grid_in
	for pos in updates:
		var idx: int = pos.y * grid_size_in.x + pos.x
		next[idx] -= 4
		for dir in DIRS:
			var npos: Vector2i = pos + dir
			match edge_mode_in:
				EDGE_WRAP:
					npos = Vector2i(posmod(npos.x, grid_size_in.x), posmod(npos.y, grid_size_in.y))
				EDGE_BOUNCE:
					npos.x = clamp(npos.x, 0, grid_size_in.x - 1)
					npos.y = clamp(npos.y, 0, grid_size_in.y - 1)
				EDGE_FALLOFF:
					if npos.x < 0 or npos.x >= grid_size_in.x or npos.y < 0 or npos.y >= grid_size_in.y:
						continue
			var nidx: int = npos.y * grid_size_in.x + npos.x
			next[nidx] += 1
	return {"grid": next, "changed": true}

static func _sim_task_count(cell_count: int) -> int:
	return max(1, min(cell_count, OS.get_processor_count()))

static func _mark_sim_changed(changed_ref: Array, change_mutex: Mutex) -> void:
	if changed_ref.is_empty() or change_mutex == null:
		return
	if changed_ref[0]:
		return
	change_mutex.lock()
	changed_ref[0] = true
	change_mutex.unlock()

static func sim_job_totalistic(grid_in: PackedByteArray, grid_size_in: Vector2i, birth: Array, survive: Array, edge_mode_in: int) -> Dictionary:
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "changed": false}
	var next_state: PackedByteArray = PackedByteArray()
	next_state.resize(grid_in.size())
	var birth_set: Array = birth
	var survive_set: Array = survive
	var changed_ref: Array = [false]
	var change_mutex: Mutex = Mutex.new()
	var cell_count: int = grid_size_in.x * grid_size_in.y
	var group_id: int = WorkerThreadPool.add_group_task(
		Callable(CellularAutomataHub, "_sim_totalistic_element").bind(grid_in, grid_size_in, edge_mode_in, birth_set, survive_set, next_state, changed_ref, change_mutex),
		cell_count,
		_sim_task_count(cell_count),
		false,
		"sim_totalistic_cells"
	)
	if group_id < 0:
		return _sim_totalistic_worker(grid_in, grid_size_in, birth_set, survive_set, edge_mode_in)
	WorkerThreadPool.wait_for_group_task_completion(group_id)
	return {"grid": next_state, "changed": changed_ref[0]}

static func _sim_totalistic_element(idx: int, grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, birth_set: Array, survive_set: Array, next_state: PackedByteArray, changed_ref: Array, change_mutex: Mutex) -> void:
	var x: int = idx % grid_size_in.x
	var y: int = idx / grid_size_in.x
	var alive: int = sim_job_sample_cell(grid_in, grid_size_in, edge_mode_in, x, y)
	var neighbors: int = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			neighbors += sim_job_sample_cell(grid_in, grid_size_in, edge_mode_in, x + dx, y + dy)
	var new_val: int = 0
	if alive == 1:
		if survive_set.has(neighbors):
			new_val = 1
	else:
		if birth_set.has(neighbors):
			new_val = 1
	next_state[idx] = new_val
	if new_val != grid_in[idx]:
		_mark_sim_changed(changed_ref, change_mutex)

static func sim_job_sample_cell(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, x: int, y: int) -> int:
	var expected: int = grid_size_in.x * grid_size_in.y
	if expected <= 0 or grid_in.size() != expected:
		return 0
	if x >= 0 and x < grid_size_in.x and y >= 0 and y < grid_size_in.y:
		var idx: int = y * grid_size_in.x + x
		if idx >= 0 and idx < grid_in.size():
			return grid_in[idx]
		return 0
	match edge_mode_in:
		EDGE_WRAP:
			var nx: int = posmod(x, grid_size_in.x)
			var ny: int = posmod(y, grid_size_in.y)
			var wrapped_idx: int = ny * grid_size_in.x + nx
			return grid_in[wrapped_idx] if wrapped_idx >= 0 and wrapped_idx < grid_in.size() else 0
		EDGE_BOUNCE:
			var bounce_x: int = x
			var bounce_y: int = y
			if bounce_x < 0:
				bounce_x = -bounce_x - 1
			elif bounce_x >= grid_size_in.x:
				bounce_x = grid_size_in.x - (bounce_x - grid_size_in.x) - 1
			if bounce_y < 0:
				bounce_y = -bounce_y - 1
			elif bounce_y >= grid_size_in.y:
				bounce_y = grid_size_in.y - (bounce_y - grid_size_in.y) - 1
			bounce_x = clamp(bounce_x, 0, grid_size_in.x - 1)
			bounce_y = clamp(bounce_y, 0, grid_size_in.y - 1)
			var bounce_idx: int = bounce_y * grid_size_in.x + bounce_x
			return grid_in[bounce_idx] if bounce_idx >= 0 and bounce_idx < grid_in.size() else 0
		_:
			return 0

static func sim_job_wolfram(grid_in: PackedByteArray, grid_size_in: Vector2i, rule: int, row: int, edge_mode_in: int, allow_wrap: bool) -> Dictionary:
	var expected: int = grid_size_in.x * grid_size_in.y
	if grid_size_in.y <= 0 or grid_size_in.x <= 0 or grid_in.size() != expected:
		return {"grid": grid_in, "row": row, "changed": false}
	var wolfram_row_local: int = row
	if allow_wrap and grid_size_in.y > 0:
		wolfram_row_local = posmod(wolfram_row_local, grid_size_in.y)
	if wolfram_row_local < 0 or wolfram_row_local >= grid_size_in.y:
		return {"grid": grid_in, "row": wolfram_row_local, "changed": false}
	var next_state: PackedByteArray = grid_in.duplicate()
	var source_row: int = 0
	if wolfram_row_local <= 0:
		source_row = grid_size_in.y - 1 if allow_wrap else 0
	else:
		source_row = wolfram_row_local - 1
	if source_row < 0 or source_row >= grid_size_in.y:
		return {"grid": next_state, "row": wolfram_row_local, "changed": false}
	var changed_flag: bool = false
	for x in range(grid_size_in.x):
		var left: int = sim_job_sample_cell(grid_in, grid_size_in, edge_mode_in, x - 1, source_row)
		var center: int = sim_job_sample_cell(grid_in, grid_size_in, edge_mode_in, x, source_row)
		var right: int = sim_job_sample_cell(grid_in, grid_size_in, edge_mode_in, x + 1, source_row)
		var key: int = (left << 2) | (center << 1) | right
		var state: int = (rule >> key) & 1
		var dst: int = wolfram_row_local * grid_size_in.x + x
		if dst >= 0 and dst < next_state.size():
			if not changed_flag and next_state[dst] != state:
				changed_flag = true
			next_state[dst] = state
	var next_row: int = wolfram_row_local + 1
	if allow_wrap:
		next_row = (wolfram_row_local + 1) % grid_size_in.y
	return {"grid": next_state, "row": next_row, "changed": changed_flag}

static func sim_job_ants(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, ants_in: Array, dirs_in: Array, colors_in: Array) -> Dictionary:
	var count: int = min(ants_in.size(), dirs_in.size())
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y or count <= 0:
		return {"grid": grid_in, "ants": ants_in, "directions": dirs_in, "colors": colors_in, "changed": false}
	var next_grid: PackedByteArray = grid_in
	var next_ants: Array = []
	var next_dirs: Array = []
	var next_colors: Array = []
	var changed: bool = false
	for i in range(count):
		var pos: Vector2i = ants_in[i]
		if pos.x < 0 or pos.x >= grid_size_in.x or pos.y < 0 or pos.y >= grid_size_in.y:
			changed = true
			continue
		var dir: int = int(dirs_in[i]) % DIRS.size()
		if dir < 0:
			dir += DIRS.size()
		var idx: int = pos.y * grid_size_in.x + pos.x
		var current: int = next_grid[idx]
		if current == 1:
			dir = (dir + 1) % DIRS.size()
			next_grid[idx] = 0
		else:
			dir = (dir + DIRS.size() - 1) % DIRS.size()
			next_grid[idx] = 1
		var next: Vector2i = pos + DIRS[dir]
		match edge_mode_in:
			EDGE_WRAP:
				next = Vector2i(posmod(next.x, grid_size_in.x), posmod(next.y, grid_size_in.y))
			EDGE_BOUNCE:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					dir = (dir + 2) % DIRS.size()
					next = pos + DIRS[dir]
					next.x = clamp(next.x, 0, grid_size_in.x - 1)
					next.y = clamp(next.y, 0, grid_size_in.y - 1)
			EDGE_FALLOFF:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					changed = true
					continue
		if not changed and (pos != next or dir != int(dirs_in[i]) or next_grid[idx] != current):
			changed = true
		next_ants.append(next)
		next_dirs.append(dir)
		if i < colors_in.size():
			next_colors.append(colors_in[i])
		else:
			next_colors.append(Color.WHITE)
	return {"grid": next_grid, "ants": next_ants, "directions": next_dirs, "colors": next_colors, "changed": changed}

static func sim_job_turmites(grid_in: PackedByteArray, grid_size_in: Vector2i, edge_mode_in: int, ants_in: Array, dirs_in: Array, colors_in: Array, rule: String) -> Dictionary:
	var count: int = min(ants_in.size(), dirs_in.size())
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y or count <= 0:
		return {"grid": grid_in, "ants": ants_in, "directions": dirs_in, "colors": colors_in, "changed": false}
	var next_grid: PackedByteArray = grid_in
	var rule_upper: String = rule.to_upper()
	if rule_upper.length() < 2:
		rule_upper = "RL"
	var next_ants: Array = []
	var next_dirs: Array = []
	var next_colors: Array = []
	var changed: bool = false
	for i in range(count):
		var pos: Vector2i = ants_in[i]
		if pos.x < 0 or pos.x >= grid_size_in.x or pos.y < 0 or pos.y >= grid_size_in.y:
			changed = true
			continue
		var dir: int = int(dirs_in[i]) % DIRS.size()
		if dir < 0:
			dir += DIRS.size()
		var idx: int = pos.y * grid_size_in.x + pos.x
		var current: int = next_grid[idx]
		var rule_idx: int = clamp(current, 0, rule_upper.length() - 1)
		var turn: String = rule_upper[rule_idx]
		if turn == "R":
			dir = (dir + 1) % DIRS.size()
		else:
			dir = (dir + DIRS.size() - 1) % DIRS.size()
		next_grid[idx] = 1 - current
		var next: Vector2i = pos + DIRS[dir]
		match edge_mode_in:
			EDGE_WRAP:
				next = Vector2i(posmod(next.x, grid_size_in.x), posmod(next.y, grid_size_in.y))
			EDGE_BOUNCE:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					dir = (dir + 2) % DIRS.size()
					next = pos + DIRS[dir]
					next.x = clamp(next.x, 0, grid_size_in.x - 1)
					next.y = clamp(next.y, 0, grid_size_in.y - 1)
			EDGE_FALLOFF:
				if next.x < 0 or next.x >= grid_size_in.x or next.y < 0 or next.y >= grid_size_in.y:
					changed = true
					continue
		if not changed and (pos != next or dir != int(dirs_in[i]) or next_grid[idx] != current):
			changed = true
		next_ants.append(next)
		next_dirs.append(dir)
		if i < colors_in.size():
			next_colors.append(colors_in[i])
		else:
			next_colors.append(Color.WHITE)
	return {"grid": next_grid, "ants": next_ants, "directions": next_dirs, "colors": next_colors, "changed": changed}

static func sim_job_sand(grid_in: PackedInt32Array, grid_size_in: Vector2i, edge_mode_in: int) -> Dictionary:
	if grid_size_in.x <= 0 or grid_size_in.y <= 0 or grid_in.size() != grid_size_in.x * grid_size_in.y:
		return {"grid": grid_in, "changed": false}
	var updates: Array[Vector2i] = []
	for y in range(grid_size_in.y):
		for x in range(grid_size_in.x):
			var idx: int = y * grid_size_in.x + x
			if grid_in[idx] >= 4:
				updates.append(Vector2i(x, y))
	if updates.is_empty():
		return {"grid": grid_in, "changed": false}
	var next: PackedInt32Array = grid_in
	for pos in updates:
		var idx: int = pos.y * grid_size_in.x + pos.x
		next[idx] -= 4
		for dir in DIRS:
			var npos: Vector2i = pos + dir
			match edge_mode_in:
				EDGE_WRAP:
					npos = Vector2i(posmod(npos.x, grid_size_in.x), posmod(npos.y, grid_size_in.y))
				EDGE_BOUNCE:
					npos.x = clamp(npos.x, 0, grid_size_in.x - 1)
					npos.y = clamp(npos.y, 0, grid_size_in.y - 1)
				EDGE_FALLOFF:
					if npos.x < 0 or npos.x >= grid_size_in.x or npos.y < 0 or npos.y >= grid_size_in.y:
						continue
			var nidx: int = npos.y * grid_size_in.x + npos.x
			next[nidx] += 1
	return {"grid": next, "changed": true}

func resolve_export_path() -> String:
	var pattern: String = export_pattern
	if not pattern.contains("://"):
		pattern = "user://" + pattern
	var pad_start: int = -1
	var pad_len: int = 0
	for i in pattern.length():
		if pattern[i] == '#':
			if pad_start == -1:
				pad_start = i
			pad_len += 1
		elif pad_start != -1:
			break
	if pad_len > 0:
		var number_str: String = str(export_counter).pad_zeros(pad_len)
		pattern = pattern.substr(0, pad_start) + number_str + pattern.substr(pad_start + pad_len)
	var path: String = pattern
	if not path.begins_with("user://") and not path.begins_with("res://") and not path.begins_with("/"):
		path = "user://" + path
	return path

func resolve_web_export_filename(path: String) -> String:
	var filename: String = path.get_file()
	if filename == "":
		filename = "export.png"
	return filename

func _process(delta: float) -> void:
	if not ui_ready:
		return
	var applied_from_threads: bool = _apply_sim_results()

	var playback_active: bool = not is_paused or step_requested
	var state_changed: bool = false
	if playback_active:
		if step_requested:
			if wolfram_enabled:
				step_wolfram()
				state_changed = true
			if ants_enabled:
				step_ants()
				state_changed = true
			if gol_enabled:
				step_game_of_life()
				state_changed = true
			if day_night_enabled:
				step_day_night()
				state_changed = true
			if seeds_enabled:
				step_seeds()
				state_changed = true
			if turmite_enabled:
				step_turmites()
				state_changed = true
			if sand_enabled:
				step_sand()
				state_changed = true
		else:
			var scaled_delta: float = delta * max(global_rate, 0.0)
			state_changed = process_wolfram(scaled_delta) or state_changed
			state_changed = process_ants(scaled_delta) or state_changed
			state_changed = process_game_of_life(scaled_delta) or state_changed
			state_changed = process_day_night(scaled_delta) or state_changed
			state_changed = process_seeds(scaled_delta) or state_changed
			state_changed = process_turmites(scaled_delta) or state_changed
			state_changed = process_sand(scaled_delta) or state_changed
		step_requested = false

	if state_changed or applied_from_threads:
		request_render()

	var completed_count: int = 0
	for task_id in render_task_ids:
		if WorkerThreadPool.is_task_completed(task_id):
			completed_count += 1
	if render_task_ids.size() > 0 and completed_count == render_task_ids.size():
		var result: Dictionary = take_render_result()
		render_task_ids.clear()
		apply_render_result(result)
	if render_pending and render_task_ids.is_empty():
		start_render_task()

func on_grid_gui_input(event: InputEvent) -> void:
	var handled: bool = false
	if sand_drop_at_click and event is InputEventMouseButton:
		var sand_mouse: InputEventMouseButton = event as InputEventMouseButton
		if sand_mouse.button_index == MOUSE_BUTTON_LEFT and sand_mouse.pressed:
			var pos: Vector2i = local_to_cell(sand_mouse.position)
			if pos.x >= 0 and pos.y >= 0:
				add_sand_at(pos, sand_drop_amount)
				request_render()
				handled = true

	if not draw_enabled:
		if handled:
			accept_event()
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			drawing_active = mouse_event.pressed
			if mouse_event.pressed:
				handle_draw_local(mouse_event.position)
			handled = true
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if drawing_active and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			handle_draw_local(motion.position)
			handled = true
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		drawing_active = touch_event.pressed
		if touch_event.pressed:
			handle_draw_local(touch_event.position)
		handled = true
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drawing_active:
			handle_draw_local(drag.position)
			handled = true

	if handled:
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not draw_enabled:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			drawing_active = mouse_event.pressed
			if mouse_event.pressed:
				handle_draw_input(mouse_event.position)
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		drawing_active = touch_event.pressed
		if touch_event.pressed:
			handle_draw_input(touch_event.position)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if drawing_active and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			handle_draw_input(motion.position)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drawing_active:
			handle_draw_input(drag.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		update_grid_size()
		request_render()
	elif what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_stop_sim_workers()
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
		update_sidebar_scale()
