## scripts/minimap.gd
## GTA5-style minimap with blips, district labels, and compass
## Rendered as a CanvasLayer overlay
extends CanvasLayer

class_name MinimapHUD

const MAP_SIZE = 200          # Minimap pixel size
const MAP_SCALE = 0.04        # World units per minimap pixel
const UPDATE_RATE = 0.05      # Seconds between updates

var player_ref: CharacterBody3D
var time_ref: TimeOfDay
var weather_ref: WeatherSystem
var update_timer: float = 0.0
var minimap_visible: bool = true

# UI nodes (built programmatically — no scene needed)
var panel: ColorRect
var player_dot: ColorRect
var compass: Label
var clock_label: Label
var weather_label: Label
var coords_label: Label
var speed_label: Label
var hint_label: Label
var district_label: Label

# Blip storage
var blips: Array = []

func _ready() -> void:
	layer = 10
	_build_ui()

func init(player: CharacterBody3D, time_sys: TimeOfDay, weather_sys: WeatherSystem) -> void:
	player_ref = player
	time_ref = time_sys
	weather_ref = weather_sys

func _build_ui() -> void:
	# ── MINIMAP PANEL ──────────────────────────────────────
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.85)
	bg.size = Vector2(MAP_SIZE + 4, MAP_SIZE + 4)
	bg.position = Vector2(20, 20)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	panel = ColorRect.new()
	panel.color = Color(0.08, 0.1, 0.12, 0.92)
	panel.size = Vector2(MAP_SIZE, MAP_SIZE)
	panel.position = Vector2(22, 22)
	panel.clip_contents = true
	add_child(panel)

	# Minimap border (double outline like GTA5)
	var border_outer = ColorRect.new()
	border_outer.color = Color(0.0, 0.0, 0.0, 1.0)
	border_outer.size = Vector2(MAP_SIZE + 8, MAP_SIZE + 8)
	border_outer.position = Vector2(18, 18)
	border_outer.z_index = -1
	add_child(border_outer)

	# Player dot (center of map, always)
	player_dot = ColorRect.new()
	player_dot.color = Color(0.2, 0.9, 0.3)
	player_dot.size = Vector2(8, 8)
	player_dot.position = panel.position + Vector2(MAP_SIZE / 2 - 4, MAP_SIZE / 2 - 4)
	add_child(player_dot)

	# ── TOP-RIGHT HUD CLUSTER ─────────────────────────────
	var hud_panel = ColorRect.new()
	hud_panel.color = Color(0.0, 0.0, 0.0, 0.65)
	hud_panel.size = Vector2(220, 130)
	hud_panel.position = Vector2(get_viewport().get_visible_rect().size.x - 240, 20)
	add_child(hud_panel)

	# Clock (big, GTA-style)
	clock_label = _make_label("12:00 PM", Vector2(hud_panel.position.x + 10, hud_panel.position.y + 8), 26)
	clock_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	add_child(clock_label)

	# Weather
	weather_label = _make_label("☀ Clear", Vector2(hud_panel.position.x + 10, hud_panel.position.y + 40), 16)
	weather_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	add_child(weather_label)

	# Compass
	compass = _make_label("N", Vector2(hud_panel.position.x + 10, hud_panel.position.y + 60), 18)
	compass.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	add_child(compass)

	# Speed
	speed_label = _make_label("0 km/h", Vector2(hud_panel.position.x + 10, hud_panel.position.y + 85), 16)
	speed_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	add_child(speed_label)

	# Coordinates
	coords_label = _make_label("0.0, 0.0", Vector2(hud_panel.position.x + 10, hud_panel.position.y + 108), 12)
	coords_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	add_child(coords_label)

	# ── DISTRICT LABEL (center-ish, fades in like GTA) ───
	district_label = _make_label("Downtown", Vector2(0, 0), 22)
	district_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.7))
	district_label.position = Vector2(
		get_viewport().get_visible_rect().size.x * 0.5 - 80,
		get_viewport().get_visible_rect().size.y - 80
	)
	add_child(district_label)

	# ── BOTTOM HINT BAR ───────────────────────────────────
	var hint_bg = ColorRect.new()
	hint_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	hint_bg.size = Vector2(500, 28)
	hint_bg.position = Vector2(
		get_viewport().get_visible_rect().size.x * 0.5 - 250,
		get_viewport().get_visible_rect().size.y - 36
	)
	add_child(hint_bg)

	hint_label = _make_label(
		"WASD/Stick: Move  |  Mouse/R-Stick: Look  |  Space/✕: Jump  |  Shift/L3: Sprint  |  M: Minimap",
		Vector2(hint_bg.position.x + 10, hint_bg.position.y + 5),
		12
	)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(hint_label)

func _process(delta: float) -> void:
	update_timer += delta
	if update_timer < UPDATE_RATE:
		return
	update_timer = 0.0

	if player_ref == null:
		return

	_update_clock()
	_update_weather_display()
	_update_compass()
	_update_speed()
	_update_coords()
	_update_district()

	if Input.is_action_just_pressed("toggle_minimap"):
		minimap_visible = !minimap_visible
		panel.visible = minimap_visible
		player_dot.visible = minimap_visible

func _update_clock() -> void:
	if time_ref:
		clock_label.text = time_ref.get_time_string()

func _update_weather_display() -> void:
	if weather_ref:
		var w = weather_ref.get_weather_name()
		var icon = "☀"
		match w:
			"Partly Cloudy": icon = "⛅"
			"Overcast": icon = "☁"
			"Light Rain": icon = "🌦"
			"Heavy Rain": icon = "🌧"
			"Thunderstorm": icon = "⛈"
		weather_label.text = icon + " " + w

func _update_compass() -> void:
	if player_ref:
		var arm = player_ref.get_node_or_null("SpringArm3D")
		if arm:
			var yaw = rad_to_deg(-arm.rotation.y)
			while yaw < 0: yaw += 360
			while yaw >= 360: yaw -= 360

			var dir = "N"
			if yaw > 22.5 and yaw <= 67.5: dir = "NE"
			elif yaw > 67.5 and yaw <= 112.5: dir = "E"
			elif yaw > 112.5 and yaw <= 157.5: dir = "SE"
			elif yaw > 157.5 and yaw <= 202.5: dir = "S"
			elif yaw > 202.5 and yaw <= 247.5: dir = "SW"
			elif yaw > 247.5 and yaw <= 292.5: dir = "W"
			elif yaw > 292.5 and yaw <= 337.5: dir = "NW"
			compass.text = "◈ %s  %.0f°" % [dir, yaw]

func _update_speed() -> void:
	if player_ref:
		var vel = player_ref.velocity
		var speed_ms = Vector2(vel.x, vel.z).length()
		var speed_kmh = speed_ms * 3.6
		speed_label.text = "%.0f km/h" % speed_kmh

func _update_coords() -> void:
	if player_ref:
		var p = player_ref.global_position
		coords_label.text = "%.0f, %.0f, %.0f" % [p.x, p.y, p.z]

func _update_district() -> void:
	if player_ref == null:
		return

	var p = player_ref.global_position
	var dist_name = ""

	# Determine district by position (matches city generator zones)
	var abs_x = abs(p.x)
	var abs_z = abs(p.z)
	var max_coord = max(abs_x, abs_z)

	if max_coord < 200:
		dist_name = "Downtown"
	elif max_coord < 400:
		dist_name = "Midtown"
	elif max_coord < 600:
		dist_name = "Residential District"
	elif max_coord < 800:
		dist_name = "East Side"
	elif max_coord < 900:
		dist_name = "Industrial Zone"
	else:
		dist_name = "Suburbs"

	if dist_name != district_label.text:
		district_label.text = dist_name
		# Fade animation (simple alpha tween)
		var tween = create_tween()
		tween.tween_property(district_label, "modulate:a", 1.0, 0.3)
		tween.tween_interval(3.0)
		tween.tween_property(district_label, "modulate:a", 0.0, 1.5)

func _make_label(text: String, pos: Vector2, size: int) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", size)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl
