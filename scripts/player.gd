## scripts/player.gd
## GTA5/RDR2-style third-person character controller
## Features: smooth acceleration, sprint, crouch, camera collision,
##           lean-into-movement, controller + keyboard/mouse
extends CharacterBody3D

# ── Movement parameters (tuned for GTA5-feel) ────────────────
@export var walk_speed := 5.0
@export var run_speed := 11.0
@export var sprint_speed := 18.0
@export var crouch_speed := 3.0
@export var jump_velocity := 12.0
@export var acceleration := 12.0        # Ground acceleration
@export var deceleration := 18.0        # Ground deceleration (tighter stops)
@export var air_acceleration := 4.0
@export var air_deceleration := 2.0
@export var rotation_speed := 10.0      # Body rotation toward movement

# ── Camera parameters ─────────────────────────────────────────
@export var mouse_sensitivity := 0.0018
@export var controller_sensitivity := 2.5
@export var camera_zoom_min := 3.0
@export var camera_zoom_max := 15.0
@export var camera_zoom_speed := 1.5
@export var camera_lerp_speed := 8.0    # How quickly camera catches spring arm

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ── State ─────────────────────────────────────────────────────
var is_sprinting := false
var is_crouching := false
var target_zoom := 8.0
var current_zoom := 8.0
var was_on_floor := false
var steps_since_landed := 0

# ── Body lean (RDR2-style movement lean) ─────────────────────
var body_lean_x := 0.0    # Forward/back lean
var body_lean_z := 0.0    # Side lean
var lean_speed := 4.0

# ── Footstep timer ────────────────────────────────────────────
var footstep_timer := 0.0

# ── Node references ───────────────────────────────────────────
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var head_mesh: MeshInstance3D = $HeadMesh

# ── Collision shapes ──────────────────────────────────────────
@onready var standing_col: CollisionShape3D = $StandingShape
@onready var crouch_col: CollisionShape3D = $CrouchShape

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	target_zoom = 8.0
	current_zoom = 8.0
	spring_arm.spring_length = current_zoom

	# Collision layer setup (player on layer 1)
	collision_layer = 1
	collision_mask = 1

func _input(event: InputEvent) -> void:
	# ── Mouse look ────────────────────────────────────────────
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		spring_arm.rotation.y -= event.relative.x * mouse_sensitivity
		spring_arm.rotation.x -= event.relative.y * mouse_sensitivity
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -1.3, 0.4)

	# ── Scroll wheel zoom ─────────────────────────────────────
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_zoom = max(camera_zoom_min, target_zoom - camera_zoom_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_zoom = min(camera_zoom_max, target_zoom + camera_zoom_speed)

	# ── Controller right stick look ───────────────────────────
	if event is InputEventJoypadMotion:
		var val = event.axis_value
		if abs(val) < 0.12:  # Deadzone
			return
		if event.axis == JOY_AXIS_RIGHT_X:
			spring_arm.rotation.y -= val * controller_sensitivity * get_process_delta_time()
		elif event.axis == JOY_AXIS_RIGHT_Y:
			spring_arm.rotation.x -= val * controller_sensitivity * get_process_delta_time()
			spring_arm.rotation.x = clamp(spring_arm.rotation.x, -1.3, 0.4)

	# Escape to release mouse
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	var on_floor = is_on_floor()

	# ── Gravity ───────────────────────────────────────────────
	if not on_floor:
		velocity.y -= gravity * delta
		# Slightly faster fall for GTA feel
		if velocity.y < -2.0:
			velocity.y -= gravity * 0.4 * delta

	# ── Jump ──────────────────────────────────────────────────
	if Input.is_action_just_pressed("jump") and on_floor:
		velocity.y = jump_velocity

	# ── Movement state ────────────────────────────────────────
	is_crouching = Input.is_action_pressed("crouch") and on_floor
	is_sprinting = Input.is_action_pressed("sprint") and on_floor and not is_crouching

	# Select target speed
	var target_speed: float
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed
	else:
		target_speed = run_speed

	# ── Input direction (relative to camera yaw) ──────────────
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Controller radial deadzone (GTA uses radial not per-axis)
	var input_magnitude = input_dir.length()
	if input_magnitude < 0.15:
		input_dir = Vector2.ZERO
		input_magnitude = 0.0
	else:
		# Smooth input (like GTA's analog-feel even on keyboard)
		input_magnitude = clamp(input_magnitude, 0.0, 1.0)
		input_dir = input_dir.normalized() * pow(input_magnitude, 1.0)

	var direction = Vector3.ZERO
	if input_magnitude > 0.0:
		direction = Vector3(input_dir.x, 0, input_dir.y)
		direction = direction.rotated(Vector3.UP, spring_arm.rotation.y).normalized()
		direction *= input_magnitude

	# ── Horizontal velocity (acceleration/deceleration) ───────
	var accel = acceleration if on_floor else air_acceleration
	var decel = deceleration if on_floor else air_deceleration

	if direction.length() > 0.01:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)

	# ── Body rotation (character faces movement direction) ────
	if direction.length() > 0.1:
		var target_angle = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)

	# ── Body lean (RDR2 weight-shift feel) ────────────────────
	var speed_fraction = Vector2(velocity.x, velocity.z).length() / sprint_speed
	var local_vel = velocity.rotated(Vector3.UP, -rotation.y)
	var lean_target_x = clamp(-local_vel.z / sprint_speed * 8.0, -6.0, 6.0)
	var lean_target_z = clamp(local_vel.x / sprint_speed * 4.0, -4.0, 4.0)
	body_lean_x = lerp(body_lean_x, lean_target_x, lean_speed * delta)
	body_lean_z = lerp(body_lean_z, lean_target_z, lean_speed * delta)

	if body_mesh:
		body_mesh.rotation.x = deg_to_rad(body_lean_x)
		body_mesh.rotation.z = deg_to_rad(body_lean_z)

	# ── Crouch scale ──────────────────────────────────────────
	if is_crouching:
		scale = scale.lerp(Vector3(1.0, 0.6, 1.0), 10.0 * delta)
		if spring_arm:
			spring_arm.transform.origin.y = lerp(spring_arm.transform.origin.y, 1.2, 8.0 * delta)
	else:
		scale = scale.lerp(Vector3(1.0, 1.0, 1.0), 10.0 * delta)
		if spring_arm:
			spring_arm.transform.origin.y = lerp(spring_arm.transform.origin.y, 2.0, 8.0 * delta)

	# ── Camera zoom lerp ──────────────────────────────────────
	current_zoom = lerp(current_zoom, target_zoom, camera_lerp_speed * delta)
	spring_arm.spring_length = current_zoom

	# ── Landing impact (camera bob on land) ───────────────────
	if on_floor and not was_on_floor:
		var fall_speed = abs(velocity.y)
		if fall_speed > 5.0:
			_landing_impact(fall_speed)

	was_on_floor = on_floor

	# ── Footstep bob ──────────────────────────────────────────
	var horiz_speed = Vector2(velocity.x, velocity.z).length()
	if on_floor and horiz_speed > 1.0:
		footstep_timer += delta * (horiz_speed / walk_speed) * 2.5
		var bob = sin(footstep_timer) * 0.04 * (horiz_speed / run_speed)
		if camera:
			camera.transform.origin.y = lerp(camera.transform.origin.y, bob, 10.0 * delta)
	else:
		if camera:
			camera.transform.origin.y = lerp(camera.transform.origin.y, 0.0, 8.0 * delta)

	move_and_slide()

func _landing_impact(fall_speed: float) -> void:
	# Quick camera dip on landing (like GTA/RDR2 landing feedback)
	if camera == null:
		return
	var impact_strength = clamp(fall_speed / 20.0, 0.0, 1.0) * -0.3
	var tween = create_tween()
	tween.tween_property(camera, "transform:origin:y", impact_strength, 0.06)
	tween.tween_property(camera, "transform:origin:y", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC)
