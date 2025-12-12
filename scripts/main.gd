extends Control

const PRICE_STEP := 0.05
const MIN_PRICE := 0.05
const MAX_PRICE := 2.0

const WIRE_BUNDLE := 1000
const WIRE_BASE_COST := 15.0
const AUTOCLIPPER_BASE_COST := 12.0
const MARKETING_BASE_COST := 100.0
const AUTOCLIPPER_RATE := 1.0

var total_paperclips := 0
var unsold_inventory := 0
var funds := 100.0
var wire := 1000
var price := 0.25
var marketing_level := 0
var marketing_cost := MARKETING_BASE_COST
var autoclippers := 0
var autoclipper_cost := AUTOCLIPPER_BASE_COST

var production_accumulator := 0.0
var sales_accumulator := 0.0

var labels := {}
var buttons := {}

func _ready() -> void:
    build_ui()
    refresh_ui()

func build_ui() -> void:
    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.offset_left = 24
    margin.offset_top = 16
    margin.offset_right = -24
    margin.offset_bottom = -16
    add_child(margin)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 14)
    margin.add_child(root)

    var title := Label.new()
    title.text = "Universal Paperclips"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    root.add_child(title)

    var stats_box := GridContainer.new()
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

    var make_row := HBoxContainer.new()
    make_row.add_theme_constant_override("separation", 8)
    root.add_child(make_row)

    var make_button := Button.new()
    make_button.text = "Make paperclip"
    make_button.pressed.connect(_on_make_clip_pressed)
    buttons["make"] = make_button
    make_row.add_child(make_button)

    var auto_button := Button.new()
    auto_button.pressed.connect(_on_buy_autoclipper_pressed)
    buttons["autoclipper"] = auto_button
    make_row.add_child(auto_button)

    var wire_button := Button.new()
    wire_button.pressed.connect(_on_buy_wire_pressed)
    buttons["wire"] = wire_button
    make_row.add_child(wire_button)

    var price_box := HBoxContainer.new()
    price_box.alignment = BoxContainer.ALIGNMENT_CENTER
    price_box.add_theme_constant_override("separation", 6)
    root.add_child(price_box)

    var price_label := Label.new()
    price_label.text = "Adjust price"
    price_box.add_child(price_label)

    var minus_button := Button.new()
    minus_button.text = "-"
    minus_button.pressed.connect(func(): adjust_price(-PRICE_STEP))
    buttons["price_down"] = minus_button
    price_box.add_child(minus_button)

    var current_price := Label.new()
    current_price.text = "$0.25"
    labels["current_price"] = current_price
    price_box.add_child(current_price)

    var plus_button := Button.new()
    plus_button.text = "+"
    plus_button.pressed.connect(func(): adjust_price(PRICE_STEP))
    buttons["price_up"] = plus_button
    price_box.add_child(plus_button)

    var marketing_row := HBoxContainer.new()
    marketing_row.add_theme_constant_override("separation", 8)
    root.add_child(marketing_row)

    var marketing_button := Button.new()
    marketing_button.pressed.connect(_on_buy_marketing_pressed)
    buttons["marketing"] = marketing_button
    marketing_row.add_child(marketing_button)

    var demand_label := Label.new()
    demand_label.text = "Demand: -- clips / sec"
    labels["demand"] = demand_label
    marketing_row.add_child(demand_label)

    var log_label := Label.new()
    log_label.text = "First phase: build clips, manage wire, set prices, and buy marketing and AutoClippers."
    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    root.add_child(log_label)

func add_stat_row(container: GridContainer, title: String, key: String) -> void:
    var label := Label.new()
    label.text = title
    container.add_child(label)

    var value := Label.new()
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    labels[key] = value
    container.add_child(value)

func _process(delta: float) -> void:
    production_accumulator += delta * float(autoclippers) * AUTOCLIPPER_RATE
    while production_accumulator >= 1.0:
        if not make_clip():
            production_accumulator = 0.0
            break
        production_accumulator -= 1.0

    sales_accumulator += delta
    if sales_accumulator >= 0.5:
        process_sales(sales_accumulator)
        sales_accumulator = 0.0

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
    var potential_sales: int = int(floor(demand_rate * elapsed))
    var actual_sales: int = min(unsold_inventory, potential_sales)
    if actual_sales <= 0:
        return
    unsold_inventory -= actual_sales
    funds += float(actual_sales) * price

func get_demand_per_second() -> float:
    var base_demand: float = 0.7 + float(marketing_level) * 0.35
    var price_factor: float = clamp(1.35 - price * 0.9, 0.0, 2.0)
    var inventory_pressure: float = clamp(unsold_inventory / 500.0, 0.1, 1.0)
    return (base_demand * price_factor + 0.2) * inventory_pressure

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

func format_currency(value: float) -> String:
    return "$%.2f" % value

func refresh_ui() -> void:
    labels["total"].text = str(total_paperclips)
    labels["inventory"].text = str(unsold_inventory)
    labels["price"].text = format_currency(price)
    labels["funds"].text = format_currency(funds)
    labels["wire"].text = str(wire) + " m"

    var clip_rate := float(autoclippers) * AUTOCLIPPER_RATE
    if wire <= 0:
        clip_rate = 0.0
    labels["production"].text = "%.2f" % clip_rate
    labels["marketing"].text = str(marketing_level)
    labels["autoclippers"].text = str(autoclippers)

    labels["current_price"].text = format_currency(price)
    labels["demand"].text = "Demand: %.2f clips / sec" % get_demand_per_second()

    buttons["make"].disabled = wire <= 0
    buttons["wire"].text = "Buy wire (" + format_currency(WIRE_BASE_COST) + ")"
    buttons["wire"].disabled = funds < WIRE_BASE_COST

    buttons["marketing"].text = "Launch marketing (" + format_currency(marketing_cost) + ")"
    buttons["marketing"].disabled = funds < marketing_cost

    buttons["autoclipper"].text = "Buy AutoClipper (" + format_currency(autoclipper_cost) + ")"
    buttons["autoclipper"].disabled = funds < autoclipper_cost or wire <= 0

    buttons["price_down"].disabled = price <= MIN_PRICE
    buttons["price_up"].disabled = price >= MAX_PRICE
