## scripts/time_of_day.gd
## Dynamic day/night cycle inspired by RDR2's incredible lighting
## Sun arc, moon, sky color interpolation, atmospheric scattering simulation
extends Node3D

class_name TimeOfDay

# Time settings
@export var day_duration_seconds := 600.0  # Real-time seconds for a full day (10 min default)
@export var start_hour := 8.0              # Start at 8am

var current_hour := 8.0  # 0-24 hour system
var time_speed: float

# Node references
var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var world_env: WorldEnvironment
var sky_material: ProceduralSkyMaterial

# ── Sky color keyframes (like RDR2's sky color timeline) ──────
const SKY_COLORS = {
	0.0:  {"sky": Color(0.02, 0.02, 0.08), "horizon": Color(0.06, 0.05, 0.12), "sun_c": Color(0.0, 0.0, 0.0)},   # Midnight
	4.5:  {"sky": Color(0.05, 0.05, 0.18), "horizon": Color(0.35, 0.22, 0.15), "sun_c": Color(0.0, 0.0, 0.0)},   # Pre-dawn
	6.0:  {"sky": Color(0.55, 0.35, 0.25), "horizon": Color(0.9, 0.55, 0.2),  "sun_c": Color(1.0, 0.65, 0.3)},   # Dawn
	8.0:  {"sky": Color(0.35, 0.6, 0.9),   "horizon": Color(0.7, 0.85, 1.0),  "sun_c": Color(1.0, 0.95, 0.85)},  # Morning
	12.0: {"sky": Color(0.25, 0.5, 0.85),  "horizon": Color(0.6, 0.8, 1.0),   "sun_c": Color(1.0, 0.98, 0.95)},  # Noon
	16.0: {"sky": Color(0.3, 0.55, 0.88),  "horizon": Color(0.65, 0.82, 1.0), "sun_c": Color(1.0, 0.96, 0.85)},  # Afternoon
	18.5: {"sky": Color(0.7, 0.38, 0.18),  "horizon": Color(1.0, 0.6, 0.25),  "sun_c": Color(1.0, 0.6, 0.25)},   # Sunset (RDR2 gold)
	20.0: {"sky": Color(0.12, 0.1, 0.22),  "horizon": Color(0.4, 0.22, 0.32), "sun_c": Color(0.0, 0.0, 0.0)},   # Dusk
	22.0: {"sky": Color(0.03, 0.03, 0.1),  "horizon": Color(0.05, 0.05, 0.15),"sun_c": Color(0.0, 0.0, 0.0)},   # Night
	24.0: {"sky": Color(0.02, 0.02, 0.08), "horizon": Color(0.06, 0.05, 0.12),"sun_c": Color(0.0, 0.0, 0.0)},   # Midnight (loop)
}

func _ready() -> void:
	current_hour = start_hour
	time_speed = 24.0 / day_duration_seconds
	_setup_lights()
	_setup_sky()

func _setup_lights() -> void:
	# Sun
	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.light_energy = 2.5
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun_light.directional_shadow_max_distance = 500.0
	add_child(sun_light)

	# Moon (faint blue)
	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.light_color = Color(0.65, 0.75, 0.9)
	moon_light.light_energy = 0.0
	moon_light.shadow_enabled = false
	add_child(moon_light)

func _setup_sky() -> void:
	world_env = WorldEnvironment.new()
	var env = Environment.new()

	sky_material = ProceduralSkyMaterial.new()
	var sky = Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# SSAO for depth
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.5

	# Glow for night lights / dawn
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.5

	# Fog for atmospheric depth (like RDR2's gorgeous distance fog)
	env.fog_enabled = true
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.5

	# Tone mapping — ACES like most modern AAA games
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0

	world_env.environment = env
	add_child(world_env)

func _process(delta: float) -> void:
	current_hour += delta * time_speed
	if current_hour >= 24.0:
		current_hour -= 24.0

	_update_sun()
	_update_sky()
	_update_fog()

func _update_sun() -> void:
	# Sun arc — rises East, sets West (like real sun)
	var sun_angle = (current_hour / 24.0) * TAU - PI * 0.5
	var sun_elevation = sin(sun_angle) * 90.0  # Degrees above horizon

	var sun_dir = Vector3(
		cos(sun_angle),
		sin(sun_angle),
		0.2
	).normalized()

	sun_light.global_transform = Transform3D().looking_at(-sun_dir, Vector3.UP)

	# Sun energy — dim at horizon, bright at zenith, off at night
	var brightness = clamp(sun_elevation / 90.0, 0.0, 1.0)
	sun_light.light_energy = brightness * 2.5

	# Sun color temperature — warm at horizon, white at noon (physically accurate)
	var warmth = 1.0 - brightness * 0.7
	sun_light.light_color = Color(1.0, 1.0 - warmth * 0.25, 1.0 - warmth * 0.5)

	# Moon appears when sun is down
	var moon_dir = -sun_dir
	moon_light.global_transform = Transform3D().looking_at(-moon_dir, Vector3.UP)
	moon_light.light_energy = clamp(-sin(sun_angle) * 0.3, 0.0, 0.3)

	# Update sky sun position
	sky_material.sun_angle_min = 1.0 - brightness
	sky_material.sun_angle_max = 2.0 - brightness

func _update_sky() -> void:
	var colors = _interpolate_sky_colors(current_hour)

	sky_material.sky_top_color = colors["sky"]
	sky_material.sky_horizon_color = colors["horizon"]
	sky_material.ground_horizon_color = colors["horizon"].darkened(0.3)
	sky_material.ground_bottom_color = colors["sky"].darkened(0.6)

	if colors["sun_c"].r > 0.0:
		sky_material.sun_angle_max = 1.0
	else:
		sky_material.sun_angle_max = 0.0

	# Ambient light follows sky
	world_env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	world_env.environment.ambient_light_sky_contribution = 0.8

	# Night: slightly stronger ambient so city is visible
	if current_hour < 6.0 or current_hour > 20.0:
		world_env.environment.ambient_light_energy = 0.3
	else:
		world_env.environment.ambient_light_energy = 1.0

func _update_fog() -> void:
	var env = world_env.environment
	# Morning mist (like RDR2)
	if current_hour > 5.5 and current_hour < 9.0:
		var mist = smoothstep(5.5, 7.0, current_hour) * (1.0 - smoothstep(7.0, 9.0, current_hour))
		env.fog_density = 0.003 + mist * 0.008
		env.fog_light_color = Color(0.85, 0.75, 0.65)
	# Evening haze
	elif current_hour > 17.0 and current_hour < 20.0:
		var haze = smoothstep(17.0, 18.5, current_hour) * (1.0 - smoothstep(18.5, 20.0, current_hour))
		env.fog_density = 0.002 + haze * 0.005
		env.fog_light_color = Color(0.9, 0.6, 0.4)
	# Night
	elif current_hour < 5.5 or current_hour > 21.0:
		env.fog_density = 0.001
		env.fog_light_color = Color(0.3, 0.3, 0.5)
	else:
		env.fog_density = 0.0015
		env.fog_light_color = Color(0.75, 0.82, 0.9)

func _interpolate_sky_colors(hour: float) -> Dictionary:
	var keys = SKY_COLORS.keys()
	keys.sort()

	var prev_hour = keys[0]
	var next_hour = keys[-1]
	var prev_colors = SKY_COLORS[prev_hour]
	var next_colors = SKY_COLORS[next_hour]

	for i in range(keys.size() - 1):
		if hour >= keys[i] and hour < keys[i + 1]:
			prev_hour = keys[i]
			next_hour = keys[i + 1]
			prev_colors = SKY_COLORS[prev_hour]
			next_colors = SKY_COLORS[next_hour]
			break

	var t = (hour - prev_hour) / max(next_hour - prev_hour, 0.001)
	t = clamp(t, 0.0, 1.0)

	return {
		"sky": prev_colors["sky"].lerp(next_colors["sky"], t),
		"horizon": prev_colors["horizon"].lerp(next_colors["horizon"], t),
		"sun_c": prev_colors["sun_c"].lerp(next_colors["sun_c"], t),
	}

## Returns current time as formatted string (for HUD)
func get_time_string() -> String:
	var h = int(current_hour)
	var m = int((current_hour - h) * 60.0)
	var ampm = "AM" if h < 12 else "PM"
	var display_h = h % 12
	if display_h == 0:
		display_h = 12
	return "%d:%02d %s" % [display_h, m, ampm]

## Returns true during "night" hours (for spawning night-specific things)
func is_night() -> bool:
	return current_hour < 6.0 or current_hour > 20.0
