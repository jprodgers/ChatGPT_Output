@icon("res://icon.svg")
class_name CellularAutomataHub
extends Control

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const EDGE_WRAP: int = 0
const EDGE_BOUNCE: int = 1
const EDGE_FALLOFF: int = 2

var cell_size: int = 2
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

var gol_rate: float = 0.01
var gol_accumulator: float = 0.0
var gol_enabled: bool = false
var gol_every_ant_steps: int = 100
var gol_trigger_from_ants: bool = true

var ants: Array[Vector2i] = []
var ant_directions: Array[int] = []
var ant_colors: Array[Color] = []
var ant_step_counter: int = 0

var seed_fill: float = 0.5

var global_rate: float = 1.0

var ui_ready: bool = false
var is_paused: bool = false

var step_requested: bool = false

@onready var grid_view: TextureRect = TextureRect.new()
@onready var info_label: Label = Label.new()
@onready var view_container: Panel = Panel.new()

@onready var wolfram_rate_spin: SpinBox = SpinBox.new()
@onready var ant_rate_spin: SpinBox = SpinBox.new()
@onready var gol_rate_spin: SpinBox = SpinBox.new()
@onready var gol_every_spin: SpinBox = SpinBox.new()
@onready var cell_size_spin: SpinBox = SpinBox.new()
@onready var rule_spin: SpinBox = SpinBox.new()
@onready var edge_option: OptionButton = OptionButton.new()
@onready var alive_picker: ColorPickerButton = ColorPickerButton.new()
@onready var dead_picker: ColorPickerButton = ColorPickerButton.new()
@onready var ant_color_picker: ColorPickerButton = ColorPickerButton.new()
@onready var ant_count_spin: SpinBox = SpinBox.new()
@onready var fill_spin: SpinBox = SpinBox.new()

func _ready() -> void:
    set_process(true)
    build_ui()
    update_grid_size()
    render_grid()

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
    play_button.text = "Pause"
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
    controls_column.add_child(build_collapsible_section("Wolfram", build_wolfram_controls()))
    controls_column.add_child(build_collapsible_section("Langton's Ant", build_ant_controls()))
    controls_column.add_child(build_collapsible_section("Game of Life", build_gol_controls()))

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

    ui_ready = true

func build_collapsible_section(title: String, content: Control) -> VBoxContainer:
    var wrapper: VBoxContainer = VBoxContainer.new()
    wrapper.add_theme_constant_override("separation", 4)

    var header: Button = Button.new()
    header.text = title
    header.toggle_mode = true
    header.button_pressed = true
    wrapper.add_child(header)

    var holder: VBoxContainer = VBoxContainer.new()
    holder.add_theme_constant_override("separation", 6)
    holder.add_child(content)
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
        render_grid()
    )
    box.add_child(clear_button)

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
    ant_count_spin.value = 10
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

    var chain_row: HBoxContainer = HBoxContainer.new()
    var chain_label: Label = Label.new()
    chain_label.text = "Every N ant steps"
    chain_row.add_child(chain_label)
    var chain_toggle: CheckBox = CheckBox.new()
    chain_toggle.button_pressed = gol_trigger_from_ants
    chain_toggle.toggled.connect(func(v: bool) -> void:
        gol_trigger_from_ants = v
        gol_every_spin.editable = v
    )
    chain_row.add_child(chain_toggle)
    gol_every_spin.min_value = 1
    gol_every_spin.max_value = 10000
    gol_every_spin.step = 1
    gol_every_spin.value = gol_every_ant_steps
    gol_every_spin.value_changed.connect(func(v: float) -> void: gol_every_ant_steps = int(v))
    gol_every_spin.editable = gol_trigger_from_ants
    chain_row.add_child(gol_every_spin)
    box.add_child(chain_row)

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
        wolfram_row = 0
        clear_ants()
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
    ant_step_counter = 0

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

    ant_step_counter += 1
    if gol_trigger_from_ants and gol_every_ant_steps > 0 and ant_step_counter % gol_every_ant_steps == 0:
        step_game_of_life()

func step_game_of_life() -> void:
    var next_state: PackedByteArray = PackedByteArray()
    next_state.resize(grid.size())
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
                if neighbors == 2 or neighbors == 3:
                    new_val = 1
                else:
                    new_val = 0
            else:
                if neighbors == 3:
                    new_val = 1
                else:
                    new_val = 0
            next_state[y * grid_size.x + x] = new_val
    grid = next_state

func render_grid() -> void:
    if grid_size.x <= 0 or grid_size.y <= 0:
        return
    var img: Image = Image.create(grid_size.x * cell_size, grid_size.y * cell_size, false, Image.FORMAT_RGBA8)
    var ant_map: Dictionary = {}
    for i in range(ants.size()):
        ant_map[ants[i]] = ant_colors[i]
    for y in range(grid_size.y):
        for x in range(grid_size.x):
            var color: Color
            if grid[y * grid_size.x + x] == 1:
                color = alive_color
            else:
                color = dead_color
            if ant_map.has(Vector2i(x, y)):
                color = ant_map[Vector2i(x, y)]
            for oy in range(cell_size):
                for ox in range(cell_size):
                    img.set_pixel(x * cell_size + ox, y * cell_size + oy, color)
    var tex: ImageTexture = ImageTexture.create_from_image(img)
    grid_view.texture = tex

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
        step_requested = false
    else:
        var scaled_delta: float = delta * max(global_rate, 0.0)
        updated = process_wolfram(scaled_delta) or updated
        updated = process_ants(scaled_delta) or updated
        updated = process_game_of_life(scaled_delta) or updated

    if updated:
        render_grid()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        update_grid_size()
        render_grid()
