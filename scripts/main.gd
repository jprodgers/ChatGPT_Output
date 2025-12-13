@icon("res://icon.svg")
class_name CellularAutomataHub
extends Control

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const EDGE_WRAP: int = 0
const EDGE_BOUNCE: int = 1
const EDGE_FALLOFF: int = 2

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

var ant_rate: float = 10.0
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

const SAND_PALETTE_PRESETS: Dictionary = {
    "Desert": [Color(0.93, 0.82, 0.57), Color(0.86, 0.67, 0.45), Color(0.71, 0.52, 0.33), Color(0.49, 0.36, 0.25)],
    "Pastel": [Color(0.91, 0.91, 0.98), Color(0.74, 0.86, 0.96), Color(0.56, 0.77, 0.93), Color(0.38, 0.69, 0.89)],
    "Neon": [Color(0.0, 1.0, 0.59), Color(0.39, 0.96, 0.99), Color(0.93, 0.2, 0.93), Color(1.0, 0.53, 0.0)],
    "Grayscale": [Color(0.2, 0.2, 0.2), Color(0.4, 0.4, 0.4), Color(0.6, 0.6, 0.6), Color(0.85, 0.85, 0.85)]
}
const SAND_PALETTE_ORDER: Array[String] = ["Desert", "Pastel", "Neon", "Grayscale", "Custom"]
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

var global_rate: float = 10.0

var ui_ready: bool = false
var is_paused: bool = true

var step_requested: bool = false

var export_pattern: String = "screenshot####.png"
var export_counter: int = 0

@onready var grid_view: TextureRect = TextureRect.new()
@onready var info_label: Label = Label.new()
@onready var view_container: Panel = Panel.new()

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

func _ready() -> void:
    set_process(true)
    sand_colors = SAND_PALETTE_PRESETS[sand_palette_name].duplicate()
    build_ui()
    call_deferred("initialize_grid")

func build_ui() -> void:
    var root: HBoxContainer = HBoxContainer.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 8)
    add_child(root)

    var sidebar: PanelContainer = PanelContainer.new()
    sidebar.custom_minimum_size = Vector2(260, 0)
    sidebar.size_flags_horizontal = Control.SIZE_FILL
    sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(sidebar)

    var sidebar_layout: VBoxContainer = VBoxContainer.new()
    sidebar_layout.add_theme_constant_override("separation", 10)
    sidebar.add_child(sidebar_layout)

    var title: Label = Label.new()
    title.text = "Shader-friendly Cellular Automata"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    title.add_theme_font_size_override("font_size", 18)
    sidebar_layout.add_child(title)

    var info_row: HBoxContainer = HBoxContainer.new()
    info_row.add_theme_constant_override("separation", 6)
    sidebar_layout.add_child(info_row)

    info_label.text = "Grid ready"
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    info_row.add_child(info_label)

    var play_button: Button = Button.new()
    play_button.text = "Play" if is_paused else "Pause"
    play_button.pressed.connect(func() -> void:
        is_paused = !is_paused
        play_button.text = "Play" if is_paused else "Pause"
    )
    info_row.add_child(play_button)

    var step_button: Button = Button.new()
    step_button.text = "Step"
    step_button.pressed.connect(func() -> void:
        step_requested = true
    )
    info_row.add_child(step_button)

    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sidebar_layout.add_child(scroll)

    var controls_column: VBoxContainer = VBoxContainer.new()
    controls_column.add_theme_constant_override("separation", 8)
    scroll.add_child(controls_column)

    controls_column.add_child(build_collapsible_section("Grid", build_grid_controls()))
    controls_column.add_child(build_collapsible_section("Export", build_export_controls()))
    controls_column.add_child(build_collapsible_section("Wolfram", build_wolfram_controls()))
    controls_column.add_child(build_collapsible_section("Langton's Ant", build_ant_controls()))
    controls_column.add_child(build_collapsible_section("Turmite", build_turmite_controls()))
    controls_column.add_child(build_collapsible_section("Game of Life", build_gol_controls()))
    controls_column.add_child(build_collapsible_section("Day & Night", build_day_night_controls()))
    controls_column.add_child(build_collapsible_section("Seeds", build_seeds_controls()))
    controls_column.add_child(build_collapsible_section("Falling Sand", build_sand_controls()))

    view_container = Panel.new()
    view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    view_container.custom_minimum_size = Vector2(200, 200)
    root.add_child(view_container)

    grid_view.stretch_mode = TextureRect.STRETCH_SCALE
    grid_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    grid_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    grid_view.set_anchors_preset(Control.PRESET_FULL_RECT)
    grid_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    grid_view.modulate = Color.WHITE
    view_container.add_child(grid_view)

    view_container.resized.connect(func() -> void:
        update_grid_size()
        render_grid()
    )

    ui_ready = true

func initialize_grid() -> void:
    update_grid_size()
    render_grid()

func build_collapsible_section(title: String, content: Control) -> VBoxContainer:
    var wrapper: VBoxContainer = VBoxContainer.new()
    wrapper.add_theme_constant_override("separation", 4)

    var header: Button = Button.new()
    header.text = title
    header.toggle_mode = true
    header.button_pressed = false
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
        render_grid()
    )
    size_row.add_child(cell_size_spin)
    box.add_child(size_row)

    var global_rate_row: HBoxContainer = HBoxContainer.new()
    var global_rate_label: Label = Label.new()
    global_rate_label.text = "Updates/sec"
    global_rate_row.add_child(global_rate_label)
    var global_rate_spin: SpinBox = SpinBox.new()
    global_rate_spin.min_value = 0.0
    global_rate_spin.max_value = 5000.0
    global_rate_spin.step = 0.1
    global_rate_spin.allow_greater = true
    global_rate_spin.value = global_rate
    global_rate_spin.value_changed.connect(func(v: float) -> void: global_rate = max(0.0, v))
    global_rate_row.add_child(global_rate_spin)
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
    box.add_child(edge_row)

    var color_row: HBoxContainer = HBoxContainer.new()
    var color_label: Label = Label.new()
    color_label.text = "Alive / Dead"
    color_row.add_child(color_label)
    alive_picker.color = alive_color
    alive_picker.color_changed.connect(func(c: Color) -> void: alive_color = c; render_grid())
    dead_picker.color = dead_color
    dead_picker.color_changed.connect(func(c: Color) -> void: dead_color = c; render_grid())
    color_row.add_child(alive_picker)
    color_row.add_child(dead_picker)
    box.add_child(color_row)

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
    seed_button.pressed.connect(func() -> void: random_fill_grid(); render_grid())
    fill_row.add_child(seed_button)
    box.add_child(fill_row)

    var clear_button: Button = Button.new()
    clear_button.text = "Clear"
    clear_button.pressed.connect(func() -> void:
        grid.fill(0)
        clear_ants()
        clear_turmites()
        clear_sand()
        render_grid()
    )
    box.add_child(clear_button)

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
    box.add_child(pattern_row)

    var export_row: HBoxContainer = HBoxContainer.new()
    var export_button: Button = Button.new()
    export_button.text = "Export PNG"
    export_button.pressed.connect(func() -> void: export_grid_image())
    export_row.add_child(export_button)
    var hint: Label = Label.new()
    hint.text = "Use # for numbering"
    export_row.add_child(hint)
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
    box.add_child(rule_row)

    var rate_row: HBoxContainer = HBoxContainer.new()
    var rate_label: Label = Label.new()
    rate_label.text = "Steps/sec"
    rate_row.add_child(rate_label)
    wolfram_rate_spin.min_value = 0.0
    wolfram_rate_spin.max_value = 200.0
    wolfram_rate_spin.step = 0.01
    wolfram_rate_spin.value = wolfram_rate
    wolfram_rate_spin.allow_greater = true
    wolfram_rate_spin.value_changed.connect(func(v: float) -> void: wolfram_rate = max(0.0, v))
    rate_row.add_child(wolfram_rate_spin)
    box.add_child(rate_row)

    var buttons: HBoxContainer = HBoxContainer.new()
    var toggle: CheckBox = CheckBox.new()
    toggle.text = "Auto"
    toggle.button_pressed = wolfram_enabled
    toggle.toggled.connect(func(v: bool) -> void: wolfram_enabled = v)
    buttons.add_child(toggle)
    var step: Button = Button.new()
    step.text = "Step"
    step.pressed.connect(func() -> void: step_wolfram(); render_grid())
    buttons.add_child(step)
    box.add_child(buttons)

    var seed_row: HBoxContainer = HBoxContainer.new()
    var random_seed: Button = Button.new()
    random_seed.text = "Seed top row"
    random_seed.pressed.connect(func() -> void: seed_wolfram_row(true); render_grid())
    seed_row.add_child(random_seed)
    var center_seed: Button = Button.new()
    center_seed.text = "Center dot"
    center_seed.pressed.connect(func() -> void: seed_wolfram_row(false); render_grid())
    seed_row.add_child(center_seed)
    box.add_child(seed_row)

    var fill_row: HBoxContainer = HBoxContainer.new()
    var fill_button: Button = Button.new()
    fill_button.text = "Fill screen"
    fill_button.pressed.connect(func() -> void:
        fill_wolfram_screen()
        render_grid()
    )
    fill_row.add_child(fill_button)
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
    ant_color_picker.color = Color(1, 0, 0)
    count_row.add_child(ant_color_picker)
    var spawn: Button = Button.new()
    spawn.text = "Spawn"
    spawn.pressed.connect(func() -> void: spawn_ants(int(ant_count_spin.value), ant_color_picker.color))
    count_row.add_child(spawn)
    box.add_child(count_row)

    var rate_row: HBoxContainer = HBoxContainer.new()
    var rate_label: Label = Label.new()
    rate_label.text = "Steps/sec"
    rate_row.add_child(rate_label)
    ant_rate_spin.min_value = 0.0
    ant_rate_spin.max_value = 500.0
    ant_rate_spin.step = 0.01
    ant_rate_spin.value = ant_rate
    ant_rate_spin.allow_greater = true
    ant_rate_spin.value_changed.connect(func(v: float) -> void: ant_rate = max(0.0, v))
    rate_row.add_child(ant_rate_spin)
    box.add_child(rate_row)

    var buttons: HBoxContainer = HBoxContainer.new()
    var toggle: CheckBox = CheckBox.new()
    toggle.text = "Auto"
    toggle.button_pressed = ants_enabled
    toggle.toggled.connect(func(v: bool) -> void: ants_enabled = v)
    buttons.add_child(toggle)
    var step: Button = Button.new()
    step.text = "Step"
    step.pressed.connect(func() -> void: step_ants(); render_grid())
    buttons.add_child(step)
    box.add_child(buttons)

    var clear_row: HBoxContainer = HBoxContainer.new()
    var clear_button: Button = Button.new()
    clear_button.text = "Clear ants"
    clear_button.pressed.connect(func() -> void: clear_ants(); render_grid())
    clear_row.add_child(clear_button)
    box.add_child(clear_row)

    return box

func build_gol_controls() -> VBoxContainer:
    var box: VBoxContainer = VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)

    var rate_row: HBoxContainer = HBoxContainer.new()
    var rate_label: Label = Label.new()
    rate_label.text = "Steps/sec"
    rate_row.add_child(rate_label)
    gol_rate_spin.min_value = 0.0
    gol_rate_spin.max_value = 120.0
    gol_rate_spin.step = 0.001
    gol_rate_spin.value = gol_rate
    gol_rate_spin.allow_greater = true
    gol_rate_spin.value_changed.connect(func(v: float) -> void: gol_rate = max(0.0, v))
    rate_row.add_child(gol_rate_spin)
    box.add_child(rate_row)

    var buttons: HBoxContainer = HBoxContainer.new()
    var toggle: CheckBox = CheckBox.new()
    toggle.text = "Auto"
    toggle.button_pressed = gol_enabled
    toggle.toggled.connect(func(v: bool) -> void: gol_enabled = v)
    buttons.add_child(toggle)
    var step: Button = Button.new()
    step.text = "Step"
    step.pressed.connect(func() -> void: step_game_of_life(); render_grid())
    buttons.add_child(step)
    box.add_child(buttons)

    return box

func build_day_night_controls() -> VBoxContainer:
    var box: VBoxContainer = VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)

    var rate_row: HBoxContainer = HBoxContainer.new()
    var rate_label: Label = Label.new()
    rate_label.text = "Steps/sec"
    rate_row.add_child(rate_label)
    day_night_rate_spin.min_value = 0.0
    day_night_rate_spin.max_value = 120.0
    day_night_rate_spin.step = 0.001
    day_night_rate_spin.value = day_night_rate
    day_night_rate_spin.allow_greater = true
    day_night_rate_spin.value_changed.connect(func(v: float) -> void: day_night_rate = max(0.0, v))
    rate_row.add_child(day_night_rate_spin)
    box.add_child(rate_row)

    var buttons: HBoxContainer = HBoxContainer.new()
    var toggle: CheckBox = CheckBox.new()
    toggle.text = "Auto"
    toggle.button_pressed = day_night_enabled
    toggle.toggled.connect(func(v: bool) -> void: day_night_enabled = v)
    buttons.add_child(toggle)
    var step: Button = Button.new()
    step.text = "Step"
    step.pressed.connect(func() -> void: step_day_night(); render_grid())
    buttons.add_child(step)
    box.add_child(buttons)

    return box

func build_seeds_controls() -> VBoxContainer:
    var box: VBoxContainer = VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)

    var rate_row: HBoxContainer = HBoxContainer.new()
    var rate_label: Label = Label.new()
    rate_label.text = "Steps/sec"
    rate_row.add_child(rate_label)
    seeds_rate_spin.min_value = 0.0
    seeds_rate_spin.max_value = 120.0
    seeds_rate_spin.step = 0.001
    seeds_rate_spin.value = seeds_rate
    seeds_rate_spin.allow_greater = true
    seeds_rate_spin.value_changed.connect(func(v: float) -> void: seeds_rate = max(0.0, v))
    rate_row.add_child(seeds_rate_spin)
    box.add_child(rate_row)

    var buttons: HBoxContainer = HBoxContainer.new()
    var toggle: CheckBox = CheckBox.new()
    toggle.text = "Auto"
    toggle.button_pressed = seeds_enabled
    toggle.toggled.connect(func(v: bool) -> void: seeds_enabled = v)
    buttons.add_child(toggle)
    var step: Button = Button.new()
    step.text = "Step"
    step.pressed.connect(func() -> void: step_seeds(); render_grid())
    buttons.add_child(step)
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
        sand_palette_name = name
        var preset: Array = SAND_PALETTE_PRESETS.get(name, [])
        if preset.size() == 4:
            sand_colors = preset.duplicate()
            for i in range(4):
                if i < sand_color_pickers.size():
                    sand_color_pickers[i].color = sand_colors[i]
        render_grid()
    )
    palette_row.add_child(sand_palette_option)
    box.add_child(palette_row)

    sand_color_pickers.clear()
    for i in range(4):
        var color_row: HBoxContainer = HBoxContainer.new()
        var color_label: Label = Label.new()
        color_label.text = "Level %d" % i
        color_row.add_child(color_label)
        var picker: ColorPickerButton = ColorPickerButton.new()
        picker.color = sand_colors[i] if sand_colors.size() > i else Color.WHITE
        picker.color_changed.connect(func(c: Color) -> void:
            if sand_colors.size() <= i:
                sand_colors.resize(i + 1)
            sand_colors[i] = c
            sand_palette_name = "Custom"
            sand_palette_option.select(max(0, SAND_PALETTE_ORDER.find("Custom")))
            render_grid()
        )
        sand_color_pickers.append(picker)
        color_row.add_child(picker)
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
        render_grid()
    )
    amount_row.add_child(drop_button)
    box.add_child(amount_row)

    var rate_row: HBoxContainer = HBoxContainer.new()
    var rate_label: Label = Label.new()
    rate_label.text = "Steps/sec"
    rate_row.add_child(rate_label)
    sand_rate_spin.min_value = 0.0
    sand_rate_spin.max_value = 240.0
    sand_rate_spin.step = 0.01
    sand_rate_spin.allow_greater = true
    sand_rate_spin.value = sand_rate
    sand_rate_spin.value_changed.connect(func(v: float) -> void: sand_rate = max(0.0, v))
    rate_row.add_child(sand_rate_spin)
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
        render_grid()
    )
    buttons.add_child(step)
    var clear_button: Button = Button.new()
    clear_button.text = "Clear sand"
    clear_button.pressed.connect(func() -> void:
        clear_sand()
        render_grid()
    )
    buttons.add_child(clear_button)
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
    turmite_color_picker.color = Color(0, 0.6, 1)
    spawn_row.add_child(turmite_color_picker)
    var spawn_button: Button = Button.new()
    spawn_button.text = "Spawn"
    spawn_button.pressed.connect(func() -> void: spawn_turmites(turmite_count, turmite_color_picker.color))
    spawn_row.add_child(spawn_button)
    box.add_child(spawn_row)

    var rate_row: HBoxContainer = HBoxContainer.new()
    var rate_label: Label = Label.new()
    rate_label.text = "Steps/sec"
    rate_row.add_child(rate_label)
    turmite_rate_spin.min_value = 0.0
    turmite_rate_spin.max_value = 500.0
    turmite_rate_spin.step = 0.01
    turmite_rate_spin.value = turmite_rate
    turmite_rate_spin.allow_greater = true
    turmite_rate_spin.value_changed.connect(func(v: float) -> void: turmite_rate = max(0.0, v))
    rate_row.add_child(turmite_rate_spin)
    box.add_child(rate_row)

    var buttons: HBoxContainer = HBoxContainer.new()
    var toggle: CheckBox = CheckBox.new()
    toggle.text = "Auto"
    toggle.button_pressed = turmite_enabled
    toggle.toggled.connect(func(v: bool) -> void: turmite_enabled = v)
    buttons.add_child(toggle)
    var step: Button = Button.new()
    step.text = "Step"
    step.pressed.connect(func() -> void: step_turmites(); render_grid())
    buttons.add_child(step)
    var clear_button: Button = Button.new()
    clear_button.text = "Clear"
    clear_button.pressed.connect(func() -> void:
        clear_turmites()
        render_grid()
    )
    buttons.add_child(clear_button)
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
    var new_size: Vector2i = Vector2i(max(1, viewport_size.x / cell_size), max(1, viewport_size.y / cell_size))
    var size_changed: bool = new_size != grid_size or grid.size() != new_size.x * new_size.y
    grid_size = new_size

    if size_changed:
        grid.resize(grid_size.x * grid_size.y)
        grid.fill(0)
        sand_grid.resize(grid_size.x * grid_size.y)
        sand_grid.fill(0)
        wolfram_row = 0
        clear_ants()
        clear_turmites()
    info_label.text = "Grid: %dx%d cells @ %d px" % [grid_size.x, grid_size.y, cell_size]

func random_fill_grid() -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.randomize()
    for i in range(grid.size()):
        if rng.randf() < seed_fill:
            grid[i] = 1
        else:
            grid[i] = 0
    wolfram_row = 0

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

func spawn_ants(count: int, color: Color) -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.randomize()
    for i in range(count):
        ants.append(Vector2i(rng.randi_range(0, grid_size.x - 1), rng.randi_range(0, grid_size.y - 1)))
        ant_directions.append(rng.randi_range(0, DIRS.size() - 1))
        ant_colors.append(color)
    render_grid()

func clear_ants() -> void:
    ants.clear()
    ant_directions.clear()
    ant_colors.clear()

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
    if not ants_enabled or ant_rate <= 0.0:
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
    if not turmite_enabled or turmite_rate <= 0.0:
        return false
    turmite_accumulator += delta
    var interval: float = 1.0 / turmite_rate
    var stepped: bool = false
    while turmite_accumulator >= interval:
        step_turmites()
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

func fill_wolfram_screen() -> void:
    if grid_size.y <= 0:
        return
    if wolfram_row <= 0:
        wolfram_row = 1
    var remaining: int = max(0, grid_size.y - wolfram_row)
    for _i in range(remaining):
        step_wolfram(false)
    wolfram_enabled = false
    wolfram_accumulator = 0.0

func step_ants() -> void:
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

func step_game_of_life() -> void:
    step_totalistic([3], [2, 3])

func step_day_night() -> void:
    step_totalistic([3, 6, 7, 8], [3, 4, 6, 7, 8])

func step_seeds() -> void:
    step_totalistic([2], [])

func step_totalistic(birth: Array[int], survive: Array[int]) -> void:
    var next_state: PackedByteArray = PackedByteArray()
    next_state.resize(grid.size())
    var birth_set: Array[int] = birth
    var survive_set: Array[int] = survive
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
            next_state[y * grid_size.x + x] = new_val
    grid = next_state

func spawn_turmites(count: int, color: Color) -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.randomize()
    for _i in range(count):
        turmites.append(Vector2i(rng.randi_range(0, grid_size.x - 1), rng.randi_range(0, grid_size.y - 1)))
        turmite_directions.append(rng.randi_range(0, DIRS.size() - 1))
        turmite_colors.append(color)
    render_grid()

func clear_turmites() -> void:
    turmites.clear()
    turmite_directions.clear()
    turmite_colors.clear()

func step_turmites() -> void:
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

func add_sand_to_center(amount: int) -> void:
    if grid_size.x <= 0 or grid_size.y <= 0:
        return
    if sand_grid.size() != grid_size.x * grid_size.y:
        sand_grid.resize(grid_size.x * grid_size.y)
        sand_grid.fill(0)
    var center: Vector2i = Vector2i(grid_size.x / 2, grid_size.y / 2)
    var idx: int = center.y * grid_size.x + center.x
    if idx >= 0 and idx < sand_grid.size():
        sand_grid[idx] += max(0, amount)

func clear_sand() -> void:
    sand_grid.fill(0)
    sand_accumulator = 0.0

func step_sand() -> void:
    if sand_grid.size() != grid_size.x * grid_size.y:
        sand_grid.resize(grid_size.x * grid_size.y)
        sand_grid.fill(0)
    var updates: Array[Vector2i] = []
    for y in range(grid_size.y):
        for x in range(grid_size.x):
            var idx: int = y * grid_size.x + x
            if sand_grid[idx] >= 4:
                updates.append(Vector2i(x, y))
    if updates.is_empty():
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

func build_grid_image() -> Image:
    var img: Image = Image.create(grid_size.x * cell_size, grid_size.y * cell_size, false, Image.FORMAT_RGBA8)
    var marker_map: Dictionary = {}
    for i in range(ants.size()):
        marker_map[ants[i]] = ant_colors[i]
    for i in range(turmites.size()):
        marker_map[turmites[i]] = turmite_colors[i]
    for y in range(grid_size.y):
        for x in range(grid_size.x):
            var sand_idx: int = y * grid_size.x + x
            var has_sand: bool = sand_idx < sand_grid.size() and sand_grid[sand_idx] > 0
            var color: Color = dead_color if grid[y * grid_size.x + x] == 0 else alive_color
            if has_sand:
                var palette_size: int = sand_colors.size()
                if palette_size > 0:
                    color = sand_colors[(sand_grid[sand_idx] % palette_size + palette_size) % palette_size]
            if marker_map.has(Vector2i(x, y)):
                color = marker_map[Vector2i(x, y)]
            for oy in range(cell_size):
                for ox in range(cell_size):
                    img.set_pixel(x * cell_size + ox, y * cell_size + oy, color)
    return img

func render_grid() -> void:
    if grid_size.x <= 0 or grid_size.y <= 0:
        return
    var img: Image = build_grid_image()
    var tex: ImageTexture = ImageTexture.create_from_image(img)
    grid_view.texture = tex

func export_grid_image() -> void:
    if grid_size.x <= 0 or grid_size.y <= 0:
        return
    var img: Image = build_grid_image()
    var path: String = resolve_export_path()
    var err: int = img.save_png(path)
    if err == OK:
        export_counter += 1
        info_label.text = "Exported: %s" % path
    else:
        info_label.text = "Export failed (%d)" % err

func resolve_export_path() -> String:
    var pattern: String = export_pattern
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

func _process(delta: float) -> void:
    if not ui_ready:
        return
    if is_paused and not step_requested:
        return

    var updated: bool = false

    if step_requested:
        if wolfram_enabled:
            step_wolfram()
            updated = true
        if ants_enabled:
            step_ants()
            updated = true
        if gol_enabled:
            step_game_of_life()
            updated = true
        if day_night_enabled:
            step_day_night()
            updated = true
        if seeds_enabled:
            step_seeds()
            updated = true
        if turmite_enabled:
            step_turmites()
            updated = true
        if sand_enabled:
            step_sand()
            updated = true
        step_requested = false
    else:
        var scaled_delta: float = delta * max(global_rate, 0.0)
        updated = process_wolfram(scaled_delta) or updated
        updated = process_ants(scaled_delta) or updated
        updated = process_game_of_life(scaled_delta) or updated
        updated = process_day_night(scaled_delta) or updated
        updated = process_seeds(scaled_delta) or updated
        updated = process_turmites(scaled_delta) or updated
        updated = process_sand(scaled_delta) or updated

    if updated:
        render_grid()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        update_grid_size()
        render_grid()
