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
const UPGRADE_KEYS: Array[String] = ["analytics", "efficiency"]

class Upgrade:
    var key: String
    var label: String
    var description: String
    var ops_cost: int
    var effect: Callable
    var applied: bool = false

var total_paperclips: int = 0
var unsold_inventory: int = 0
var funds: float = 100.0
var wire: int = 1000
var price: float = 0.25
var marketing_level: int = 0
var marketing_cost: float = MARKETING_BASE_COST
var autoclippers: int = 0
var autoclipper_cost: float = AUTOCLIPPER_BASE_COST

var production_accumulator: float = 0.0
var sales_accumulator: float = 0.0
var demand_buffer: float = 0.0

var processors: int = 1
var memory_banks: int = 1
var operations: float = 0.0
var ops_capacity: int = BASE_OPS_CAPACITY
var processor_cost: float = PROCESSOR_BASE_COST
var memory_cost: float = MEMORY_BASE_COST

var demand_bonus: float = 0.0
var clipper_rate_bonus: float = 0.0

var labels: Dictionary[String, Label] = {}
var buttons: Dictionary[String, Button] = {}
var upgrade_buttons: Dictionary[String, Button] = {}
var upgrades: Array[Upgrade] = []

func _ready() -> void:
    build_ui()
    setup_upgrades()
    refresh_ui()

func build_ui() -> void:
    var margin: MarginContainer = MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.offset_left = 24
    margin.offset_top = 16
    margin.offset_right = -24
    margin.offset_bottom = -16
    add_child(margin)

    var root: VBoxContainer = VBoxContainer.new()
    root.add_theme_constant_override("separation", 14)
    margin.add_child(root)

    var title: Label = Label.new()
    title.text = "Universal Paperclips"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    root.add_child(title)

    var stats_box: GridContainer = GridContainer.new()
    stats_box.columns = 2
    stats_box.add_theme_constant_override("h_separation", 12)
    stats_box.add_theme_constant_override("v_separation", 6)
    root.add_child(stats_box)

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
    root.add_child(make_row)

    var make_button: Button = Button.new()
    make_button.text = "Make paperclip"
    make_button.pressed.connect(_on_make_clip_pressed)
    buttons["make"] = make_button
    make_row.add_child(make_button)

    var auto_button: Button = Button.new()
    auto_button.pressed.connect(_on_buy_autoclipper_pressed)
    buttons["autoclipper"] = auto_button
    make_row.add_child(auto_button)

    var wire_button: Button = Button.new()
    wire_button.pressed.connect(_on_buy_wire_pressed)
    buttons["wire"] = wire_button
    make_row.add_child(wire_button)

    var price_box: HBoxContainer = HBoxContainer.new()
    price_box.alignment = BoxContainer.ALIGNMENT_CENTER
    price_box.add_theme_constant_override("separation", 6)
    root.add_child(price_box)

    var price_label: Label = Label.new()
    price_label.text = "Adjust price"
    price_box.add_child(price_label)

    var minus_button: Button = Button.new()
    minus_button.text = "-"
    minus_button.pressed.connect(func(): adjust_price(-PRICE_STEP))
    buttons["price_down"] = minus_button
    price_box.add_child(minus_button)

    var current_price: Label = Label.new()
    current_price.text = "$0.25"
    labels["current_price"] = current_price
    price_box.add_child(current_price)

    var plus_button: Button = Button.new()
    plus_button.text = "+"
    plus_button.pressed.connect(func(): adjust_price(PRICE_STEP))
    buttons["price_up"] = plus_button
    price_box.add_child(plus_button)

    var marketing_row: HBoxContainer = HBoxContainer.new()
    marketing_row.add_theme_constant_override("separation", 8)
    root.add_child(marketing_row)

    var marketing_button: Button = Button.new()
    marketing_button.pressed.connect(_on_buy_marketing_pressed)
    buttons["marketing"] = marketing_button
    marketing_row.add_child(marketing_button)

    var demand_label: Label = Label.new()
    demand_label.text = "Demand: -- clips / sec"
    labels["demand"] = demand_label
    marketing_row.add_child(demand_label)

    var computing_panel: VBoxContainer = VBoxContainer.new()
    computing_panel.add_theme_constant_override("separation", 6)
    root.add_child(computing_panel)

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

    var upgrade_panel: VBoxContainer = VBoxContainer.new()
    upgrade_panel.add_theme_constant_override("separation", 4)
    root.add_child(upgrade_panel)

    var upgrade_title: Label = Label.new()
    upgrade_title.text = "Upgrades"
    upgrade_title.add_theme_font_size_override("font_size", 18)
    upgrade_panel.add_child(upgrade_title)

    var upgrade_container: VBoxContainer = VBoxContainer.new()
    upgrade_container.add_theme_constant_override("separation", 4)
    upgrade_panel.add_child(upgrade_container)
    for key: String in UPGRADE_KEYS:
        var button: Button = Button.new()
        upgrade_buttons[key] = button
        button.pressed.connect(func(): _on_upgrade_pressed(key))
        upgrade_container.add_child(button)

    var log_label: Label = Label.new()
    log_label.text = "First phase: build clips, manage wire, set prices, invest in computing, and buy marketing, AutoClippers, and upgrades."
    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    root.add_child(log_label)

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
    var analytics: Upgrade = Upgrade.new()
    analytics.key = "analytics"
    analytics.label = "Sales analytics"
    analytics.description = "+0.25 base demand (costs ops)"
    analytics.ops_cost = 200
    analytics.effect = func():
        demand_bonus += 0.25
    upgrades.append(analytics)

    var efficiency: Upgrade = Upgrade.new()
    efficiency.key = "efficiency"
    efficiency.label = "Clipper efficiency"
    efficiency.description = "+10% AutoClipper speed"
    efficiency.ops_cost = 250
    efficiency.effect = func():
        clipper_rate_bonus += 0.1
    upgrades.append(efficiency)

func _process(delta: float) -> void:
    production_accumulator += delta * float(autoclippers) * AUTOCLIPPER_RATE * (1.0 + clipper_rate_bonus)
    while production_accumulator >= 1.0:
        if not make_clip():
            production_accumulator = 0.0
            break
        production_accumulator -= 1.0

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
    var demand_rate: float = get_demand_per_second()
    demand_buffer += demand_rate * elapsed
    var potential_sales: int = int(floor(demand_buffer))
    demand_buffer -= float(potential_sales)
    var actual_sales: int = min(unsold_inventory, potential_sales)
    if actual_sales <= 0:
        return
    unsold_inventory -= actual_sales
    funds += float(actual_sales) * price

func get_demand_per_second() -> float:
    var base_demand: float = 0.7 + float(marketing_level) * 0.35 + demand_bonus
    var price_factor: float = clamp(1.6 - price * 0.9, 0.0, 2.0)
    var inventory_pressure: float = clamp(1.0 - float(unsold_inventory) / 750.0, 0.2, 1.0)
    return base_demand * price_factor * inventory_pressure

func adjust_price(amount: float) -> void:
    price = clamp(price + amount, MIN_PRICE, MAX_PRICE)
    price = snapped(price, 0.01)

func _on_make_clip_pressed() -> void:
    make_clip()

func _on_buy_wire_pressed() -> void:
    if funds < WIRE_BASE_COST:
        return
    funds -= WIRE_BASE_COST
    wire += WIRE_BUNDLE

func _on_buy_marketing_pressed() -> void:
    if funds < marketing_cost:
        return
    funds -= marketing_cost
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
    ops_capacity = BASE_OPS_CAPACITY + memory_banks * 150
    memory_cost = round(memory_cost * 1.18 * 100.0) / 100.0

func format_currency(value: float) -> String:
    return "$%.2f" % value

func accumulate_operations(delta: float) -> void:
    var ops_rate: float = float(processors) * (OPS_PER_PROCESSOR + float(memory_banks) * OPS_MEMORY_FACTOR)
    operations = min(operations + ops_rate * delta, float(ops_capacity))

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
    for upgrade in upgrades:
        if upgrade.key == key:
            return upgrade
    push_error("Unknown upgrade key: %s" % key)
    return upgrades[0]

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

    labels["current_price"].text = format_currency(price)
    labels["demand"].text = "Demand: %.2f clips / sec" % get_demand_per_second()
    labels["processors"].text = str(processors)
    labels["memory"].text = str(memory_banks)
    labels["ops"].text = "%.0f / %d ops" % [operations, ops_capacity]

    buttons["make"].disabled = wire <= 0
    buttons["wire"].text = "Buy wire (" + format_currency(WIRE_BASE_COST) + ")"
    buttons["wire"].disabled = funds < WIRE_BASE_COST

    buttons["marketing"].text = "Launch marketing (" + format_currency(marketing_cost) + ")"
    buttons["marketing"].disabled = funds < marketing_cost

    buttons["autoclipper"].text = "Buy AutoClipper (" + format_currency(autoclipper_cost) + ")"
    buttons["autoclipper"].disabled = funds < autoclipper_cost or wire <= 0

    buttons["processor"].text = "Buy processor (" + format_currency(processor_cost) + ")"
    buttons["processor"].disabled = funds < processor_cost
    buttons["memory"].text = "Buy memory (" + format_currency(memory_cost) + ")"
    buttons["memory"].disabled = funds < memory_cost

    for upgrade in upgrades:
        var button: Button = upgrade_buttons[upgrade.key]
        button.disabled = upgrade.applied or operations < float(upgrade.ops_cost)
        var label: String = "%s - %s" % [upgrade.label, upgrade.description]
        label += " (" + str(upgrade.ops_cost) + " ops)"
        if upgrade.applied:
            label += " [purchased]"
        button.text = label

    buttons["price_down"].disabled = price <= MIN_PRICE
    buttons["price_up"].disabled = price >= MAX_PRICE
