## scripts/weather_system.gd
## Weather state machine: Clear → Overcast → Rain → Storm → Clear
## Inspired by RDR2's weather system and transition blending
extends Node3D

class_name WeatherSystem

enum WeatherState {
	CLEAR,
	PARTLY_CLOUDY,
	OVERCAST,
	LIGHT_RAIN,
	HEAVY_RAIN,
	THUNDERSTORM,
}

# How long each weather state lasts (seconds of game time)
const STATE_DURATION = {
	WeatherState.CLEAR: Vector2(120.0, 300.0),
	WeatherState.PARTLY_CLOUDY: Vector2(60.0, 180.0),
	WeatherState.OVERCAST: Vector2(60.0, 120.0),
	WeatherState.LIGHT_RAIN: Vector2(60.0, 150.0),
	WeatherState.HEAVY_RAIN: Vector2(30.0, 90.0),
	WeatherState.THUNDERSTORM: Vector2(20.0, 60.0),
}

# Valid transitions (like a Markov chain, RDR2-style)
const TRANSITIONS = {
	WeatherState.CLEAR: [WeatherState.PARTLY_CLOUDY],
	WeatherState.PARTLY_CLOUDY: [WeatherState.CLEAR, WeatherState.OVERCAST],
	WeatherState.OVERCAST: [WeatherState.PARTLY_CLOUDY, WeatherState.LIGHT_RAIN],
	WeatherState.LIGHT_RAIN: [WeatherState.OVERCAST, WeatherState.HEAVY_RAIN],
	WeatherState.HEAVY_RAIN: [WeatherState.LIGHT_RAIN, WeatherState.THUNDERSTORM],
	WeatherState.THUNDERSTORM: [WeatherState.HEAVY_RAIN, WeatherState.OVERCAST],
}

var current_state: WeatherState = WeatherState.CLEAR
var state_timer: float = 0.0
var state_duration: float = 180.0
var transition_alpha: float = 0.0  # 0=prev state, 1=current state
var transitioning: bool = false
var transition_speed: float = 0.0033  # ~5 minute transition

# Particle systems
var rain_particles: GPUParticles3D
var rain_heavy_particles: GPUParticles3D

# References
var world_env: WorldEnvironment
var sky_mat: ProceduralSkyMaterial
var time_system: TimeOfDay

var rng = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_set_state(WeatherState.CLEAR)

func init(env_ref: WorldEnvironment, sky_ref: ProceduralSkyMaterial, time_ref: TimeOfDay) -> void:
	world_env = env_ref
	sky_mat = sky_ref
	time_system = time_ref
	_setup_rain_particles()

func _setup_rain_particles() -> void:
	# Light rain
	rain_particles = GPUParticles3D.new()
	rain_particles.name = "RainLight"
	var rain_process = ParticleProcessMaterial.new()
	rain_process.direction = Vector3(0.0, -1.0, 0.0)
	rain_process.initial_velocity_min = 20.0
	rain_process.initial_velocity_max = 30.0
	rain_process.spread = 180.0
	rain_process.gravity = Vector3(0, -15.0, 0)
	rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_process.emission_box_extents = Vector3(40.0, 1.0, 40.0)
	rain_particles.process_material = rain_process
	rain_particles.amount = 800
	rain_particles.lifetime = 1.2
	rain_particles.explosiveness = 0.0
	rain_particles.emitting = false
	rain_particles.transform.origin.y = 25.0

	var rain_mesh = QuadMesh.new()
	rain_mesh.size = Vector2(0.02, 0.35)
	var rain_mat = StandardMaterial3D.new()
	rain_mat.albedo_color = Color(0.7, 0.75, 0.85, 0.6)
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_mesh.surface_set_material(0, rain_mat)
	rain_particles.draw_mesh = rain_mesh
	add_child(rain_particles)

	# Heavy rain (more particles, faster)
	rain_heavy_particles = GPUParticles3D.new()
	rain_heavy_particles.name = "RainHeavy"
	var heavy_process = rain_process.duplicate() as ParticleProcessMaterial
	heavy_process.initial_velocity_min = 35.0
	heavy_process.initial_velocity_max = 50.0
	rain_heavy_particles.process_material = heavy_process
	rain_heavy_particles.amount = 2000
	rain_heavy_particles.lifetime = 0.8
	rain_heavy_particles.emitting = false
	rain_heavy_particles.transform.origin.y = 25.0
	rain_heavy_particles.draw_mesh = rain_mesh
	add_child(rain_heavy_particles)

func _process(delta: float) -> void:
	state_timer += delta

	# Transition alpha
	if transitioning:
		transition_alpha = min(transition_alpha + transition_speed * delta, 1.0)
		if transition_alpha >= 1.0:
			transitioning = false

	# Check state timeout → transition to next
	if state_timer >= state_duration:
		_advance_state()

	_apply_weather_visuals()

func _set_state(new_state: WeatherState) -> void:
	current_state = new_state
	state_timer = 0.0
	var dur_range = STATE_DURATION[new_state]
	state_duration = rng.randf_range(dur_range.x, dur_range.y)
	transitioning = true
	transition_alpha = 0.0

func _advance_state() -> void:
	var options = TRANSITIONS[current_state]
	var next = options[rng.randi() % options.size()]
	_set_state(next)

func _apply_weather_visuals() -> void:
	if world_env == null:
		return

	var env = world_env.environment

	match current_state:
		WeatherState.CLEAR:
			_blend_weather(env, 0.0018, 0.0, false, false)
		WeatherState.PARTLY_CLOUDY:
			_blend_weather(env, 0.002, 0.15, false, false)
		WeatherState.OVERCAST:
			_blend_weather(env, 0.004, 0.4, false, false)
		WeatherState.LIGHT_RAIN:
			_blend_weather(env, 0.007, 0.7, true, false)
		WeatherState.HEAVY_RAIN:
			_blend_weather(env, 0.012, 1.0, false, true)
		WeatherState.THUNDERSTORM:
			_blend_weather(env, 0.015, 1.0, false, true)

			# Lightning flashes
			if rng.randf() < 0.001:
				_trigger_lightning(env)

func _blend_weather(env: Environment, fog: float, cloud: float, light_rain: bool, heavy_rain: bool) -> void:
	var t = transition_alpha
	env.fog_density = lerp(env.fog_density, fog, t * 0.05)
	env.fog_light_color = env.fog_light_color.lerp(Color(0.7, 0.72, 0.78), t * 0.05)

	rain_particles.emitting = light_rain
	rain_heavy_particles.emitting = heavy_rain

func _trigger_lightning(env: Environment) -> void:
	# Quick ambient energy spike = lightning flash
	env.ambient_light_energy = 5.0
	await get_tree().create_timer(0.08).timeout
	env.ambient_light_energy = 1.0

	# Optional thunder sound would go here
	await get_tree().create_timer(rng.randf_range(0.5, 3.0)).timeout
	# Second flash
	if rng.randf() < 0.4:
		env.ambient_light_energy = 3.0
		await get_tree().create_timer(0.05).timeout
		env.ambient_light_energy = 1.0

## Follow player position (rain should be above player)
func follow_player(player_pos: Vector3) -> void:
	rain_particles.global_position = player_pos + Vector3(0, 25, 0)
	rain_heavy_particles.global_position = player_pos + Vector3(0, 25, 0)

func get_weather_name() -> String:
	match current_state:
		WeatherState.CLEAR: return "Clear"
		WeatherState.PARTLY_CLOUDY: return "Partly Cloudy"
		WeatherState.OVERCAST: return "Overcast"
		WeatherState.LIGHT_RAIN: return "Light Rain"
		WeatherState.HEAVY_RAIN: return "Heavy Rain"
		WeatherState.THUNDERSTORM: return "Thunderstorm"
	return "Unknown"
