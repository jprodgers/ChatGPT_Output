@icon("res://icon.svg")
class_name CellularAutomataHub
extends Control

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const EDGE_WRAP := 0
const EDGE_BOUNCE := 1
const EDGE_FALLOFF := 2

var cell_size: int = 1
var grid_size: Vector2i
var grid: PackedByteArray = PackedByteArray()

var alive_color: Color = Color.WHITE
var dead_color: Color = Color.BLACK

var edge_mode: int = EDGE_WRAP

var wolfram_rule: int = 110
var wolfram_row: int = 0
var wolfram_rate: float = 1.0
var wolfram_accumulator: float = 0.0
var wolfram_enabled: bool = true

var ant_rate: float = 1.0
var ant_accumulator: float = 0.0
var ants_enabled: bool = true

var gol_rate: float = 0.01
var gol_accumulator: float = 0.0
var gol_enabled: bool = true
var gol_every_ant_steps: int = 100

var ants: Array[Vector2i] = []
var ant_directions: Array[int] = []
var ant_colors: Array[Color] = []
var ant_step_counter: int = 0

var seed_fill: float = 0.5

var ui_ready: bool = false

@onready var grid_view: TextureRect = TextureRect.new()
@onready var info_label: Label = Label.new()

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
    random_fill_grid()
    render_grid()

func build_ui() -> void:
    var root := VBoxContainer.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 10)
    add_child(root)

    var title := Label.new()
    title.text = "Shader-friendly Cellular Automata"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 20)
    root.add_child(title)

    var info_row := HBoxContainer.new()
    info_row.add_theme_constant_override("separation", 6)
    root.add_child(info_row)

    info_label.text = "Grid ready"
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    info_row.add_child(info_label)

    var controls := HBoxContainer.new()
    controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    controls.add_theme_constant_override("separation", 12)
    root.add_child(controls)

    controls.add_child(build_grid_controls())
    controls.add_child(build_wolfram_controls())
    controls.add_child(build_ant_controls())
    controls.add_child(build_gol_controls())

    var view_container := Panel.new()
    view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    view_container.custom_minimum_size = Vector2(200, 200)
    root.add_child(view_container)

    grid_view.stretch_mode = TextureRect.STRETCH_SCALE
    grid_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    grid_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    grid_view.modulate = Color.WHITE
    view_container.add_child(grid_view)

    ui_ready = true

func build_grid_controls() -> VBoxContainer:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    var label := Label.new()
    label.text = "Grid"
    label.add_theme_font_size_override("font_size", 16)
    box.add_child(label)

    var size_row := HBoxContainer.new()
    var size_label := Label.new()
    size_label.text = "Cell size"
    size_row.add_child(size_label)
    cell_size_spin.min_value = 1
    cell_size_spin.max_value = 128
    cell_size_spin.value = cell_size
    cell_size_spin.step = 1
    cell_size_spin.value_changed.connect(func(value):
        cell_size = int(value)
        update_grid_size()
        render_grid()
    )
    size_row.add_child(cell_size_spin)
    box.add_child(size_row)

    var edge_row := HBoxContainer.new()
    var edge_label := Label.new()
    edge_label.text = "Edges"
    edge_row.add_child(edge_label)
    edge_option.add_item("Wrap", EDGE_WRAP)
    edge_option.add_item("Bounce", EDGE_BOUNCE)
    edge_option.add_item("Fall off", EDGE_FALLOFF)
    edge_option.selected = EDGE_WRAP
    edge_option.item_selected.connect(func(index): edge_mode = index)
    edge_row.add_child(edge_option)
    box.add_child(edge_row)

    var color_row := HBoxContainer.new()
    var color_label := Label.new()
    color_label.text = "Alive / Dead"
    color_row.add_child(color_label)
    alive_picker.color = alive_color
    alive_picker.color_changed.connect(func(c): alive_color = c; render_grid())
    dead_picker.color = dead_color
    dead_picker.color_changed.connect(func(c): dead_color = c; render_grid())
    color_row.add_child(alive_picker)
    color_row.add_child(dead_picker)
    box.add_child(color_row)

    var fill_row := HBoxContainer.new()
    var fill_label := Label.new()
    fill_label.text = "Seed %"
    fill_row.add_child(fill_label)
    fill_spin.min_value = 0
    fill_spin.max_value = 100
    fill_spin.step = 1
    fill_spin.value = seed_fill * 100.0
    fill_spin.value_changed.connect(func(v): seed_fill = float(v) / 100.0)
    fill_row.add_child(fill_spin)
    var seed_button := Button.new()
    seed_button.text = "Randomize"
    seed_button.pressed.connect(func(): random_fill_grid(); render_grid())
    fill_row.add_child(seed_button)
    box.add_child(fill_row)

    var clear_button := Button.new()
    clear_button.text = "Clear"
    clear_button.pressed.connect(func():
        grid.fill(0)
        render_grid()
    )
    box.add_child(clear_button)

    return box

func build_wolfram_controls() -> VBoxContainer:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    var label := Label.new()
    label.text = "Wolfram"
    label.add_theme_font_size_override("font_size", 16)
    box.add_child(label)

    var rule_row := HBoxContainer.new()
    var rule_label := Label.new()
    rule_label.text = "Rule"
    rule_row.add_child(rule_label)
    rule_spin.min_value = 0
    rule_spin.max_value = 255
    rule_spin.value = wolfram_rule
    rule_spin.value_changed.connect(func(v): wolfram_rule = int(v))
    rule_row.add_child(rule_spin)
    box.add_child(rule_row)

    var rate_row := HBoxContainer.new()
    var rate_label := Label.new()
    rate_label.text = "Steps/sec"
    rate_row.add_child(rate_label)
    wolfram_rate_spin.min_value = 0.0
    wolfram_rate_spin.max_value = 200.0
    wolfram_rate_spin.step = 0.01
    wolfram_rate_spin.value = wolfram_rate
    wolfram_rate_spin.allow_greater = true
    wolfram_rate_spin.value_changed.connect(func(v): wolfram_rate = max(0.0, v))
    rate_row.add_child(wolfram_rate_spin)
    box.add_child(rate_row)

    var buttons := HBoxContainer.new()
    var toggle := CheckBox.new()
    toggle.text = "Auto"
    toggle.button_pressed = wolfram_enabled
    toggle.toggled.connect(func(v): wolfram_enabled = v)
    buttons.add_child(toggle)
    var step := Button.new()
    step.text = "Step"
    step.pressed.connect(func(): step_wolfram(); render_grid())
    buttons.add_child(step)
    box.add_child(buttons)

    return box

func build_ant_controls() -> VBoxContainer:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    var label := Label.new()
    label.text = "Langton's Ant"
    label.add_theme_font_size_override("font_size", 16)
    box.add_child(label)

    var count_row := HBoxContainer.new()
    var count_label := Label.new()
    count_label.text = "Ants"
    count_row.add_child(count_label)
    ant_count_spin.min_value = 1
    ant_count_spin.max_value = 200
    ant_count_spin.value = 10
    count_row.add_child(ant_count_spin)
    ant_color_picker.color = Color(1, 0, 0)
    count_row.add_child(ant_color_picker)
    var spawn := Button.new()
    spawn.text = "Spawn"
    spawn.pressed.connect(func(): spawn_ants(int(ant_count_spin.value), ant_color_picker.color))
    count_row.add_child(spawn)
    box.add_child(count_row)

    var rate_row := HBoxContainer.new()
    var rate_label := Label.new()
    rate_label.text = "Steps/sec"
    rate_row.add_child(rate_label)
    ant_rate_spin.min_value = 0.0
    ant_rate_spin.max_value = 500.0
    ant_rate_spin.step = 0.01
    ant_rate_spin.value = ant_rate
    ant_rate_spin.allow_greater = true
    ant_rate_spin.value_changed.connect(func(v): ant_rate = max(0.0, v))
    rate_row.add_child(ant_rate_spin)
    box.add_child(rate_row)

    var buttons := HBoxContainer.new()
    var toggle := CheckBox.new()
    toggle.text = "Auto"
    toggle.button_pressed = ants_enabled
    toggle.toggled.connect(func(v): ants_enabled = v)
    buttons.add_child(toggle)
    var step := Button.new()
    step.text = "Step"
    step.pressed.connect(func(): step_ants(); render_grid())
    buttons.add_child(step)
    box.add_child(buttons)

    return box

func build_gol_controls() -> VBoxContainer:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    var label := Label.new()
    label.text = "Game of Life"
    label.add_theme_font_size_override("font_size", 16)
    box.add_child(label)

    var rate_row := HBoxContainer.new()
    var rate_label := Label.new()
    rate_label.text = "Steps/sec"
    rate_row.add_child(rate_label)
    gol_rate_spin.min_value = 0.0
    gol_rate_spin.max_value = 120.0
    gol_rate_spin.step = 0.001
    gol_rate_spin.value = gol_rate
    gol_rate_spin.allow_greater = true
    gol_rate_spin.value_changed.connect(func(v): gol_rate = max(0.0, v))
    rate_row.add_child(gol_rate_spin)
    box.add_child(rate_row)

    var chain_row := HBoxContainer.new()
    var chain_label := Label.new()
    chain_label.text = "Every N ant steps"
    chain_row.add_child(chain_label)
    gol_every_spin.min_value = 1
    gol_every_spin.max_value = 10000
    gol_every_spin.step = 1
    gol_every_spin.value = gol_every_ant_steps
    gol_every_spin.value_changed.connect(func(v): gol_every_ant_steps = int(v))
    chain_row.add_child(gol_every_spin)
    box.add_child(chain_row)

    var buttons := HBoxContainer.new()
    var toggle := CheckBox.new()
    toggle.text = "Auto"
    toggle.button_pressed = gol_enabled
    toggle.toggled.connect(func(v): gol_enabled = v)
    buttons.add_child(toggle)
    var step := Button.new()
    step.text = "Step"
    step.pressed.connect(func(): step_game_of_life(); render_grid())
    buttons.add_child(step)
    box.add_child(buttons)

    return box

func update_grid_size() -> void:
    if not ui_ready:
        return
    var viewport_size: Vector2i = get_viewport_rect().size
    var new_size := Vector2i(max(1, viewport_size.x / cell_size), max(1, viewport_size.y / cell_size))
    var size_changed := new_size != grid_size or grid.size() != new_size.x * new_size.y
    grid_size = new_size

    if size_changed:
        grid.resize(grid_size.x * grid_size.y)
        grid.fill(0)
        wolfram_row = 0
        ants.clear()
        ant_directions.clear()
        ant_colors.clear()
        ant_step_counter = 0
    info_label.text = "Grid: %dx%d cells @ %d px" % [grid_size.x, grid_size.y, cell_size]

func random_fill_grid() -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    for i in range(grid.size()):
        if rng.randf() < seed_fill:
            grid[i] = 1
        else:
            grid[i] = 0

func spawn_ants(count: int, color: Color) -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    for i in range(count):
        ants.append(Vector2i(rng.randi_range(0, grid_size.x - 1), rng.randi_range(0, grid_size.y - 1)))
        ant_directions.append(rng.randi_range(0, DIRS.size() - 1))
        ant_colors.append(color)
    render_grid()

func _process(delta: float) -> void:
    wolfram_accumulator += delta
    ant_accumulator += delta
    gol_accumulator += delta

    if wolfram_enabled and wolfram_rate > 0.0:
        var interval := 1.0 / wolfram_rate
        while wolfram_accumulator >= interval:
            wolfram_accumulator -= interval
            step_wolfram()
    
    if ants_enabled and ant_rate > 0.0:
        var ant_interval := 1.0 / ant_rate
        while ant_accumulator >= ant_interval:
            ant_accumulator -= ant_interval
            step_ants()

    if gol_enabled and gol_rate > 0.0:
        var gol_interval := 1.0 / gol_rate
        while gol_accumulator >= gol_interval:
            gol_accumulator -= gol_interval
            step_game_of_life()

    render_grid()

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
            var bounce_pos := pos
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

func step_wolfram() -> void:
    var source_row := (wolfram_row - 1 + grid_size.y) % grid_size.y
    for x in range(grid_size.x):
        var left := sample_cell(Vector2i(x - 1, source_row))
        var center := sample_cell(Vector2i(x, source_row))
        var right := sample_cell(Vector2i(x + 1, source_row))
        var key := (left << 2) | (center << 1) | right
        var state := (wolfram_rule >> key) & 1
        set_cell(Vector2i(x, wolfram_row), state)
    wolfram_row = (wolfram_row + 1) % grid_size.y

func step_ants() -> void:
    var remove_indices: Array[int] = []
    for i in range(ants.size()):
        var pos := ants[i]
        if pos.x < 0 or pos.x >= grid_size.x or pos.y < 0 or pos.y >= grid_size.y:
            remove_indices.append(i)
            continue

        var idx := pos.y * grid_size.x + pos.x
        var current := grid[idx]
        if current == 1:
            ant_directions[i] = (ant_directions[i] + 1) % DIRS.size()
            grid[idx] = 0
        else:
            ant_directions[i] = (ant_directions[i] + DIRS.size() - 1) % DIRS.size()
            grid[idx] = 1

        var next := pos + DIRS[ant_directions[i]]
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
        var idx := remove_indices[j]
        ants.remove_at(idx)
        ant_directions.remove_at(idx)
        ant_colors.remove_at(idx)

    ant_step_counter += 1
    if gol_every_ant_steps > 0 and ant_step_counter % gol_every_ant_steps == 0:
        step_game_of_life()

func step_game_of_life() -> void:
    var next_state := PackedByteArray()
    next_state.resize(grid.size())
    for y in range(grid_size.y):
        for x in range(grid_size.x):
            var alive := sample_cell(Vector2i(x, y))
            var neighbors := 0
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    if dx == 0 and dy == 0:
                        continue
                    neighbors += sample_cell(Vector2i(x + dx, y + dy))
            var new_val := 0
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
    var img := Image.create(grid_size.x * cell_size, grid_size.y * cell_size, false, Image.FORMAT_RGBA8)
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
    var tex := ImageTexture.create_from_image(img)
    grid_view.texture = tex

func _notification(what):
    if what == NOTIFICATION_RESIZED:
        update_grid_size()
        render_grid()
