extends Control

const PRICE_STEP: float = 0.05
const MIN_PRICE: float = 0.05
const MAX_PRICE: float = 2.0

const WIRE_BUNDLE: int = 1000
const WIRE_BASE_COST: float = 15.0
const AUTOCLIPPER_BASE_COST: float = 12.0
const MARKETING_BASE_COST: float = 100.0
const AUTOCLIPPER_RATE: float = 1.0

const PROCESSOR_BASE_COST: float = 40.0
const MEMORY_BASE_COST: float = 60.0
const OPS_PER_PROCESSOR: float = 0.35
const OPS_MEMORY_FACTOR: float = 0.15
const BASE_OPS_CAPACITY: int = 50
const AUTOCLIPPER_UNLOCK: int = 100
const COMPUTING_UNLOCK: int = 2000
const UPGRADE_KEYS: Array[String] = [
    "analytics_1",
    "analytics_2",
    "analytics_3",
    "efficiency_1",
    "efficiency_2",
    "efficiency_3",
    "bulk_wire_1",
    "bulk_wire_2",
    "marketing_insight_1",
    "marketing_insight_2",
    "price_optimizer",
    "processor_boost",
    "memory_boost"
]

class Upgrade:
    var key: String
    var label: String
    var description: String
    var ops_cost: int
    var effect: Callable
    var unlock_at_clips: int
    var prerequisite: String
    var applied: bool = false

var total_paperclips: int = 0
var total_sold: int = 0
var unsold_inventory: int = 0
var funds: float = 0.0
var wire: int = 1000
var price: float = 0.25
var marketing_level: int = 0
var marketing_cost: float = MARKETING_BASE_COST
var autoclippers: int = 0
var autoclipper_cost: float = AUTOCLIPPER_BASE_COST

var production_accumulator: float = 0.0
var sales_accumulator: float = 0.0
var demand_buffer: float = 0.0
var smoothed_demand: float = 0.0

var processors: int = 1
var memory_banks: int = 1
var operations: float = 0.0
var ops_capacity: int = BASE_OPS_CAPACITY
var processor_cost: float = PROCESSOR_BASE_COST
var memory_cost: float = MEMORY_BASE_COST

var demand_bonus: float = 0.0
var clipper_rate_bonus: float = 0.0
var wire_per_purchase: int = WIRE_BUNDLE
var marketing_discount: float = 0.0
var ops_rate_bonus: float = 0.0
var ops_capacity_bonus: int = 0
var price_sensitivity: float = 1.0

var labels: Dictionary[String, Label] = {}
var buttons: Dictionary[String, Button] = {}
var upgrade_buttons: Dictionary[String, Button] = {}
var upgrades: Array[Upgrade] = []

var computing_panel: VBoxContainer

func _ready() -> void:
    build_ui()
    setup_upgrades()
    update_ops_capacity()
    smoothed_demand = calculate_target_demand()
    refresh_ui()

func build_ui() -> void:
    var margin: MarginContainer = MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.offset_left = 32
    margin.offset_top = 20
    margin.offset_right = -32
    margin.offset_bottom = -20
    add_child(margin)

    var root: VBoxContainer = VBoxContainer.new()
    root.add_theme_constant_override("separation", 14)
    margin.add_child(root)

    var title: Label = Label.new()
    title.text = "Universal Paperclips"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    root.add_child(title)

    var content_row: HBoxContainer = HBoxContainer.new()
    content_row.add_theme_constant_override("separation", 20)
    content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(content_row)

    var left_column: VBoxContainer = VBoxContainer.new()
    left_column.add_theme_constant_override("separation", 12)
    left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_row.add_child(left_column)

    var stats_box: GridContainer = GridContainer.new()
    stats_box.columns = 2
    stats_box.add_theme_constant_override("h_separation", 12)
    stats_box.add_theme_constant_override("v_separation", 6)
    left_column.add_child(stats_box)

    add_stat_row(stats_box, "Clips made", "total")
    add_stat_row(stats_box, "Unsold inventory", "inventory")
    add_stat_row(stats_box, "Clip price", "price")
    add_stat_row(stats_box, "Funds", "funds")
    add_stat_row(stats_box, "Wire", "wire")
    add_stat_row(stats_box, "Clips / second", "production")
    add_stat_row(stats_box, "Marketing level", "marketing")
    add_stat_row(stats_box, "AutoClippers", "autoclippers")

    var make_row: HBoxContainer = HBoxContainer.new()
    make_row.add_theme_constant_override("separation", 8)
    left_column.add_child(make_row)

    var make_button: Button = Button.new()
    make_button.text = "Make paperclip"
    make_button.pressed.connect(_on_make_clip_pressed)
    buttons["make"] = make_button
    make_row.add_child(make_button)

    var auto_button: Button = Button.new()
    auto_button.pressed.connect(_on_buy_autoclipper_pressed)
    auto_button.visible = false
    buttons["autoclipper"] = auto_button
    make_row.add_child(auto_button)

    var wire_button: Button = Button.new()
    wire_button.pressed.connect(_on_buy_wire_pressed)
    buttons["wire"] = wire_button
    make_row.add_child(wire_button)

    var price_box: HBoxContainer = HBoxContainer.new()
    price_box.alignment = BoxContainer.ALIGNMENT_CENTER
    price_box.add_theme_constant_override("separation", 6)
    left_column.add_child(price_box)

    var price_label: Label = Label.new()
    price_label.text = "Adjust price"
    price_box.add_child(price_label)

    var minus_button: Button = Button.new()
    minus_button.text = "-"
    minus_button.focus_mode = Control.FOCUS_NONE
    minus_button.custom_minimum_size = Vector2(38, 28)
    minus_button.pressed.connect(func(): adjust_price(-PRICE_STEP))
    buttons["price_down"] = minus_button
    price_box.add_child(minus_button)

    var plus_button: Button = Button.new()
    plus_button.text = "+"
    plus_button.focus_mode = Control.FOCUS_NONE
    plus_button.custom_minimum_size = Vector2(38, 28)
    plus_button.pressed.connect(func(): adjust_price(PRICE_STEP))
    buttons["price_up"] = plus_button
    price_box.add_child(plus_button)

    var marketing_row: HBoxContainer = HBoxContainer.new()
    marketing_row.add_theme_constant_override("separation", 8)
    left_column.add_child(marketing_row)

    var marketing_button: Button = Button.new()
    marketing_button.pressed.connect(_on_buy_marketing_pressed)
    buttons["marketing"] = marketing_button
    marketing_row.add_child(marketing_button)

    var demand_label: Label = Label.new()
    demand_label.text = "Demand: -- clips / sec"
    labels["demand"] = demand_label
    marketing_row.add_child(demand_label)

    computing_panel = VBoxContainer.new()
    computing_panel.add_theme_constant_override("separation", 6)
    computing_panel.visible = false
    left_column.add_child(computing_panel)

    var computing_title: Label = Label.new()
    computing_title.text = "Computing"
    computing_title.add_theme_font_size_override("font_size", 18)
    computing_panel.add_child(computing_title)

    add_simple_row(computing_panel, "Processors", "processors")
    add_simple_row(computing_panel, "Memory", "memory")
    add_simple_row(computing_panel, "Operations", "ops")

    var computing_buttons: HBoxContainer = HBoxContainer.new()
    computing_buttons.add_theme_constant_override("separation", 8)
    computing_panel.add_child(computing_buttons)

    var buy_processor_button: Button = Button.new()
    buy_processor_button.pressed.connect(_on_buy_processor_pressed)
    buttons["processor"] = buy_processor_button
    computing_buttons.add_child(buy_processor_button)

    var buy_memory_button: Button = Button.new()
    buy_memory_button.pressed.connect(_on_buy_memory_pressed)
    buttons["memory"] = buy_memory_button
    computing_buttons.add_child(buy_memory_button)

    var log_label: Label = Label.new()
    log_label.text = "First phase: build clips, manage wire, set prices, invest in computing, and buy marketing, AutoClippers, and upgrades."
    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    left_column.add_child(log_label)

    var right_column: VBoxContainer = VBoxContainer.new()
    right_column.add_theme_constant_override("separation", 10)
    right_column.size_flags_horizontal = Control.SIZE_FILL
    right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_row.add_child(right_column)

    var upgrade_panel: VBoxContainer = VBoxContainer.new()
    upgrade_panel.add_theme_constant_override("separation", 6)
    upgrade_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_column.add_child(upgrade_panel)

    var upgrade_title: Label = Label.new()
    upgrade_title.text = "Upgrades"
    upgrade_title.add_theme_font_size_override("font_size", 18)
    upgrade_panel.add_child(upgrade_title)

    var upgrade_scroll: ScrollContainer = ScrollContainer.new()
    upgrade_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    upgrade_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    upgrade_scroll.custom_minimum_size = Vector2(360, 420)
    upgrade_panel.add_child(upgrade_scroll)

    var upgrade_container: VBoxContainer = VBoxContainer.new()
    upgrade_container.add_theme_constant_override("separation", 6)
    upgrade_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    upgrade_scroll.add_child(upgrade_container)
    for key: String in UPGRADE_KEYS:
        var button: Button = Button.new()
        upgrade_buttons[key] = button
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(func(): _on_upgrade_pressed(key))
        upgrade_container.add_child(button)

func add_stat_row(container: GridContainer, title: String, key: String) -> void:
    var label: Label = Label.new()
    label.text = title
    container.add_child(label)

    var value: Label = Label.new()
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    labels[key] = value
    container.add_child(value)

func add_simple_row(container: VBoxContainer, title: String, key: String) -> void:
    var row: HBoxContainer = HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    container.add_child(row)

    var label: Label = Label.new()
    label.text = title
    row.add_child(label)

    var value: Label = Label.new()
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    labels[key] = value
    row.add_child(value)

func setup_upgrades() -> void:
    upgrades.append_array([
        create_upgrade("analytics_1", "Sales analytics I", "+0.15 base demand", 120, 0, "", func(): demand_bonus += 0.15),
        create_upgrade("analytics_2", "Sales analytics II", "+0.20 base demand", 220, 8000, "analytics_1", func(): demand_bonus += 0.2),
        create_upgrade("analytics_3", "Sales analytics III", "+0.25 base demand", 320, 20000, "analytics_2", func(): demand_bonus += 0.25),
        create_upgrade("efficiency_1", "Clipper efficiency I", "+10% AutoClipper speed", 180, 600, "", func(): clipper_rate_bonus += 0.1),
        create_upgrade("efficiency_2", "Clipper efficiency II", "+12% AutoClipper speed", 260, 6000, "efficiency_1", func(): clipper_rate_bonus += 0.12),
        create_upgrade("efficiency_3", "Clipper efficiency III", "+15% AutoClipper speed", 360, 16000, "efficiency_2", func(): clipper_rate_bonus += 0.15),
        create_upgrade("bulk_wire_1", "Bulk wire spool I", "+250 wire per purchase", 150, 500, "", func(): wire_per_purchase += 250),
        create_upgrade("bulk_wire_2", "Bulk wire spool II", "+500 wire per purchase", 240, 7500, "bulk_wire_1", func(): wire_per_purchase += 500),
        create_upgrade("marketing_insight_1", "Marketing insight I", "-10% marketing costs", 200, 1200, "", func(): marketing_discount += 0.1),
        create_upgrade("marketing_insight_2", "Marketing insight II", "-12% marketing costs", 320, 9500, "marketing_insight_1", func(): marketing_discount += 0.12),
        create_upgrade("price_optimizer", "Price optimizer", "Price shifts reduce demand less", 280, 15000, "marketing_insight_2", Callable(self, "apply_price_optimizer")),
        create_upgrade("processor_boost", "Processor boost", "+15% ops/sec", 240, 6000, "", func(): ops_rate_bonus += 0.15),
        create_upgrade("memory_boost", "Memory boost", "+20 ops capacity", 210, 6000, "", Callable(self, "apply_memory_boost"))
    ])

func apply_price_optimizer() -> void:
    price_sensitivity = max(0.6, price_sensitivity - 0.15)
    demand_bonus += 0.05

func apply_memory_boost() -> void:
    ops_capacity_bonus += 20
    update_ops_capacity()

func create_upgrade(key: String, label: String, description: String, ops_cost: int, unlock_at_clips: int, prerequisite: String, effect: Callable) -> Upgrade:
    var upgrade: Upgrade = Upgrade.new()
    upgrade.key = key
    upgrade.label = label
    upgrade.description = description
    upgrade.ops_cost = ops_cost
    upgrade.effect = effect
    upgrade.unlock_at_clips = unlock_at_clips
    upgrade.prerequisite = prerequisite
    return upgrade

func _process(delta: float) -> void:
    production_accumulator += delta * float(autoclippers) * AUTOCLIPPER_RATE * (1.0 + clipper_rate_bonus)
    while production_accumulator >= 1.0:
        if not make_clip():
            production_accumulator = 0.0
            break
        production_accumulator -= 1.0

    update_demand(delta)
    sales_accumulator += delta
    if sales_accumulator >= 0.5:
        process_sales(sales_accumulator)
        sales_accumulator = 0.0

    accumulate_operations(delta)

    refresh_ui()

func make_clip() -> bool:
    if wire <= 0:
        return false
    wire -= 1
    total_paperclips += 1
    unsold_inventory += 1
    return true

func process_sales(elapsed: float) -> void:
    if unsold_inventory <= 0:
        return
    demand_buffer += smoothed_demand * elapsed
    var potential_sales: int = int(floor(demand_buffer))
    demand_buffer -= float(potential_sales)
    var actual_sales: int = min(unsold_inventory, potential_sales)
    if actual_sales <= 0:
        return
    unsold_inventory -= actual_sales
    total_sold += actual_sales
    funds += float(actual_sales) * price

func calculate_target_demand() -> float:
    var base_demand: float = 0.8 + float(marketing_level) * 0.3 + demand_bonus
    var price_factor: float = clamp(1.5 - price * 0.45 * price_sensitivity, 0.65, 1.9)
    var safe_inventory: float = max(float(unsold_inventory) - 500.0, 0.0)
    var inventory_pressure: float = clamp(1.0 - safe_inventory / 25000.0, 0.9, 1.0)
    var sold_after_threshold: float = max(float(total_sold) - 5000.0, 0.0)
    var saturation_pressure: float = 1.0 - min(sold_after_threshold / 1500000.0, 0.25)
    return max(0.15, base_demand * price_factor * inventory_pressure * saturation_pressure)

func update_demand(delta: float) -> void:
    var target: float = calculate_target_demand()
    var smoothing_factor: float = clamp(delta * 0.12, 0.0, 0.35)
    smoothed_demand = lerpf(smoothed_demand, target, smoothing_factor)

func adjust_price(amount: float) -> void:
    price = clamp(price + amount, MIN_PRICE, MAX_PRICE)
    price = snapped(price, 0.01)

func _on_make_clip_pressed() -> void:
    make_clip()

func _on_buy_wire_pressed() -> void:
    if funds < WIRE_BASE_COST:
        return
    funds -= WIRE_BASE_COST
    wire += wire_per_purchase

func _on_buy_marketing_pressed() -> void:
    var cost: float = get_effective_marketing_cost()
    if funds < cost:
        return
    funds -= cost
    marketing_level += 1
    marketing_cost = round(marketing_cost * 1.2 * 100.0) / 100.0

func _on_buy_autoclipper_pressed() -> void:
    if funds < autoclipper_cost:
        return
    funds -= autoclipper_cost
    autoclippers += 1
    autoclipper_cost = round(autoclipper_cost * 1.15 * 100.0) / 100.0

func _on_buy_processor_pressed() -> void:
    if funds < processor_cost:
        return
    funds -= processor_cost
    processors += 1
    processor_cost = round(processor_cost * 1.15 * 100.0) / 100.0

func _on_buy_memory_pressed() -> void:
    if funds < memory_cost:
        return
    funds -= memory_cost
    memory_banks += 1
    update_ops_capacity()
    memory_cost = round(memory_cost * 1.18 * 100.0) / 100.0

func format_currency(value: float) -> String:
    return "$%.2f" % value

func get_effective_marketing_cost() -> float:
    return round(marketing_cost * (1.0 - marketing_discount) * 100.0) / 100.0

func accumulate_operations(delta: float) -> void:
    var ops_rate: float = float(processors) * (OPS_PER_PROCESSOR + float(memory_banks) * OPS_MEMORY_FACTOR)
    ops_rate *= 1.0 + ops_rate_bonus
    operations = min(operations + ops_rate * delta, float(ops_capacity))

func update_ops_capacity() -> void:
    ops_capacity = BASE_OPS_CAPACITY + ops_capacity_bonus + memory_banks * 150
    operations = min(operations, float(ops_capacity))

func _on_upgrade_pressed(key: String) -> void:
    var upgrade: Upgrade = get_upgrade(key)
    if upgrade.applied:
        return
    if operations < float(upgrade.ops_cost):
        return
    operations -= float(upgrade.ops_cost)
    upgrade.applied = true
    upgrade.effect.call()

func get_upgrade(key: String) -> Upgrade:
    for upgrade: Upgrade in upgrades:
        if upgrade.key == key:
            return upgrade
    push_error("Unknown upgrade key: %s" % key)
    return upgrades[0]

func is_upgrade_unlocked(upgrade: Upgrade) -> bool:
    if total_paperclips < upgrade.unlock_at_clips:
        return false
    if upgrade.prerequisite != "":
        var prerequisite_upgrade: Upgrade = get_upgrade(upgrade.prerequisite)
        if not prerequisite_upgrade.applied:
            return false
    return true

func refresh_ui() -> void:
    labels["total"].text = str(total_paperclips)
    labels["inventory"].text = str(unsold_inventory)
    labels["price"].text = format_currency(price)
    labels["funds"].text = format_currency(funds)
    labels["wire"].text = str(wire) + " m"

    var clip_rate: float = float(autoclippers) * AUTOCLIPPER_RATE * (1.0 + clipper_rate_bonus)
    if wire <= 0:
        clip_rate = 0.0
    labels["production"].text = "%.2f" % clip_rate
    labels["marketing"].text = str(marketing_level)
    labels["autoclippers"].text = str(autoclippers)

    labels["demand"].text = "Demand: %.2f clips / sec" % smoothed_demand
    labels["processors"].text = str(processors)
    labels["memory"].text = str(memory_banks)
    labels["ops"].text = "%.0f / %d ops" % [operations, ops_capacity]

    var autoclipper_unlocked: bool = total_paperclips >= AUTOCLIPPER_UNLOCK
    buttons["autoclipper"].visible = autoclipper_unlocked
    buttons["make"].disabled = wire <= 0
    buttons["wire"].text = "Buy wire (+" + str(wire_per_purchase) + "m) (" + format_currency(WIRE_BASE_COST) + ")"
    buttons["wire"].disabled = funds < WIRE_BASE_COST

    buttons["marketing"].text = "Launch marketing (" + format_currency(get_effective_marketing_cost()) + ")"
    buttons["marketing"].disabled = funds < get_effective_marketing_cost()

    buttons["autoclipper"].text = "Buy AutoClipper (" + format_currency(autoclipper_cost) + ")"
    buttons["autoclipper"].disabled = funds < autoclipper_cost or wire <= 0

    var computing_unlocked: bool = total_paperclips >= COMPUTING_UNLOCK
    computing_panel.visible = computing_unlocked
    buttons["processor"].visible = computing_unlocked
    buttons["memory"].visible = computing_unlocked

    buttons["processor"].text = "Buy processor (" + format_currency(processor_cost) + ")"
    buttons["processor"].disabled = funds < processor_cost
    buttons["memory"].text = "Buy memory (" + format_currency(memory_cost) + ")"
    buttons["memory"].disabled = funds < memory_cost

    for upgrade: Upgrade in upgrades:
        var button: Button = upgrade_buttons[upgrade.key]
        var unlocked: bool = is_upgrade_unlocked(upgrade)
        button.visible = unlocked
        button.disabled = upgrade.applied or (operations < float(upgrade.ops_cost)) or not unlocked
        var label: String = "%s - %s" % [upgrade.label, upgrade.description]
        label += " (" + str(upgrade.ops_cost) + " ops)"
        if upgrade.applied:
            label += " [purchased]"
        button.text = label

    buttons["price_down"].disabled = price <= MIN_PRICE
    buttons["price_up"].disabled = price >= MAX_PRICE
