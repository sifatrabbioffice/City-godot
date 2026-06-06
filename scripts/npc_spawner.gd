## scripts/npc_spawner.gd
## Pedestrian and ambient NPC system
## Like GTA5's ambient population streaming:
## - NPCs spawn/despawn based on player proximity
## - Each NPC has a wander routine on the sidewalks
## - Different pedestrian types by district
extends Node3D

class_name NpcSpawner

const MAX_NPCS = 60
const SPAWN_RADIUS = 120.0
const DESPAWN_RADIUS = 180.0
const NPC_MOVE_SPEED = 1.4  # m/s walking
const NPC_HEIGHT = 1.75

var rng = RandomNumberGenerator.new()
var active_npcs: Array = []
var player_ref: CharacterBody3D

# NPC "skin" color palettes — diversity
const SKIN_COLORS = [
	Color(0.95, 0.82, 0.72),
	Color(0.85, 0.7, 0.55),
	Color(0.72, 0.55, 0.4),
	Color(0.55, 0.38, 0.28),
	Color(0.38, 0.25, 0.18),
]

# Clothing color sets (top, bottom)
const OUTFIT_COLORS = [
	[Color(0.2, 0.2, 0.6), Color(0.1, 0.1, 0.2)],   # Blue jacket, dark jeans
	[Color(0.75, 0.75, 0.75), Color(0.3, 0.3, 0.35)], # Grey top, dark pants
	[Color(0.8, 0.3, 0.25), Color(0.2, 0.18, 0.15)],  # Red jacket, dark pants
	[Color(0.4, 0.55, 0.35), Color(0.4, 0.35, 0.25)], # Olive jacket, khaki
	[Color(0.1, 0.1, 0.1), Color(0.1, 0.1, 0.1)],     # All black
	[Color(0.85, 0.75, 0.5), Color(0.5, 0.35, 0.2)],  # Beige, brown
]

func init(player: CharacterBody3D) -> void:
	player_ref = player
	rng.randomize()

func _physics_process(delta: float) -> void:
	if player_ref == null:
		return

	var player_pos = player_ref.global_position

	# Spawn new NPCs if below max
	if active_npcs.size() < MAX_NPCS:
		_try_spawn_npc(player_pos)

	# Update existing NPCs
	var to_remove = []
	for npc_data in active_npcs:
		var npc: Node3D = npc_data["node"]
		if not is_instance_valid(npc):
			to_remove.append(npc_data)
			continue

		var dist = npc.global_position.distance_to(player_pos)

		# Despawn if too far
		if dist > DESPAWN_RADIUS:
			npc.queue_free()
			to_remove.append(npc_data)
			continue

		# Move NPC along its waypoint path
		_update_npc(npc_data, delta)

	for old in to_remove:
		active_npcs.erase(old)

func _try_spawn_npc(player_pos: Vector3) -> void:
	# Spawn on the outskirts of visible range (like GTA's streaming)
	var spawn_angle = rng.randf() * TAU
	var spawn_dist = rng.randf_range(SPAWN_RADIUS * 0.6, SPAWN_RADIUS)
	var spawn_xz = Vector2(
		player_pos.x + cos(spawn_angle) * spawn_dist,
		player_pos.z + sin(spawn_angle) * spawn_dist
	)

	# Snap to sidewalk (simplified: just check not on road center)
	var npc_pos = Vector3(spawn_xz.x, NPC_HEIGHT * 0.5 + 0.3, spawn_xz.y)

	# Give NPC a random waypoint circuit
	var npc_node = _build_npc()
	npc_node.transform.origin = npc_pos
	add_child(npc_node)

	active_npcs.append({
		"node": npc_node,
		"waypoints": _generate_waypoints(npc_pos),
		"wp_index": 0,
		"move_speed": rng.randf_range(1.1, 1.8),
		"pause_timer": 0.0,
	})

func _build_npc() -> Node3D:
	var root = Node3D.new()

	var skin = SKIN_COLORS[rng.randi() % SKIN_COLORS.size()]
	var outfit = OUTFIT_COLORS[rng.randi() % OUTFIT_COLORS.size()]

	var skin_mat = _solid_mat(skin)
	var top_mat = _solid_mat(outfit[0])
	var bot_mat = _solid_mat(outfit[1])
	var hair_mat = _solid_mat(Color(
		rng.randf_range(0.05, 0.6),
		rng.randf_range(0.03, 0.35),
		rng.randf_range(0.0, 0.2)
	))

	# Body proportions (slight random variation)
	var scale_var = rng.randf_range(0.92, 1.08)
	root.scale = Vector3(scale_var, scale_var, scale_var)

	# Head
	var head = _make_box(Vector3(0, 1.65, 0), Vector3(0.25, 0.28, 0.22), skin_mat)
	root.add_child(head)

	# Hair
	var hair = _make_box(Vector3(0, 1.8, 0), Vector3(0.27, 0.12, 0.24), hair_mat)
	root.add_child(hair)

	# Neck
	var neck = _make_cyl(Vector3(0, 1.45, 0), 0.065, 0.065, 0.15, skin_mat)
	root.add_child(neck)

	# Torso (jacket/top)
	var torso = _make_box(Vector3(0, 1.1, 0), Vector3(0.38, 0.52, 0.22), top_mat)
	root.add_child(torso)

	# Hips (pants)
	var hips = _make_box(Vector3(0, 0.72, 0), Vector3(0.34, 0.2, 0.2), bot_mat)
	root.add_child(hips)

	# Legs
	for side in [-1, 1]:
		var leg = _make_box(Vector3(side * 0.095, 0.38, 0), Vector3(0.13, 0.5, 0.14), bot_mat)
		root.add_child(leg)
		# Shoes
		var shoe = _make_box(Vector3(side * 0.095, 0.07, 0.02), Vector3(0.13, 0.1, 0.22), _solid_mat(Color(0.15, 0.12, 0.1)))
		root.add_child(shoe)

	# Arms
	for side in [-1, 1]:
		var upper_arm = _make_box(Vector3(side * 0.26, 1.1, 0), Vector3(0.1, 0.35, 0.1), top_mat)
		root.add_child(upper_arm)
		var lower_arm = _make_box(Vector3(side * 0.27, 0.78, 0), Vector3(0.09, 0.28, 0.09), skin_mat)
		root.add_child(lower_arm)

	return root

func _generate_waypoints(start: Vector3) -> Array:
	var points = []
	var current = start
	for i in range(rng.randi_range(3, 8)):
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(10.0, 60.0)
		current = current + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		points.append(current)
	points.append(start)  # Return to origin
	return points

func _update_npc(npc_data: Dictionary, delta: float) -> void:
	var npc: Node3D = npc_data["node"]
	if npc_data["pause_timer"] > 0:
		npc_data["pause_timer"] -= delta
		return

	var waypoints = npc_data["waypoints"]
	var wp_idx = npc_data["wp_index"]
	var target = waypoints[wp_idx]
	var target_xz = Vector3(target.x, npc.global_position.y, target.z)

	var to_target = target_xz - npc.global_position
	var dist = to_target.length()

	if dist < 1.5:
		# Reached waypoint — advance or pause
		npc_data["wp_index"] = (wp_idx + 1) % waypoints.size()
		if rng.randf() < 0.15:
			npc_data["pause_timer"] = rng.randf_range(0.5, 3.0)
	else:
		var dir = to_target.normalized()
		npc.global_position += dir * npc_data["move_speed"] * delta
		# Face movement direction
		if dir.length() > 0.01:
			npc.rotation.y = atan2(dir.x, dir.z)

func _make_box(offset: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.transform.origin = offset
	var box = BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	return mi

func _make_cyl(offset: Vector3, tr: float, br: float, h: float, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.transform.origin = offset
	var cyl = CylinderMesh.new()
	cyl.top_radius = tr
	cyl.bottom_radius = br
	cyl.height = h
	mi.mesh = cyl
	mi.material_override = mat
	return mi

func _solid_mat(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat
