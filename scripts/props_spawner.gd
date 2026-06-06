## scripts/props_spawner.gd
## Street props: lampposts, benches, trash bins, fire hydrants,
## mailboxes, bus stops, newspaper stands, tree guards, planters
## Inspired by GTA5 and RDR2 environmental micro-detail density
extends Node3D

class_name PropsSpawner

var rng: RandomNumberGenerator

func spawn_all(world_size: int, block_spacing: int, road_width: float, rng_ref: RandomNumberGenerator) -> void:
	rng = rng_ref
	var half = world_size / 2
	var sidewalk_offset = road_width * 0.5 + 2.0  # Place props on sidewalk

	# ── LAMPPOSTS along every road ─────────────────────────────
	var lamp_spacing = 25.0
	for x in range(-half, half + 1, block_spacing):
		var z = -half
		while z < half:
			_spawn_lamppost(Vector3(x + sidewalk_offset + 0.5, 0, z))
			_spawn_lamppost(Vector3(x - sidewalk_offset - 0.5, 0, z))
			z += lamp_spacing + rng.randf_range(-3.0, 3.0)

	for z_road in range(-half, half + 1, block_spacing):
		var x = -half
		while x < half:
			_spawn_lamppost(Vector3(x, 0, z_road + sidewalk_offset + 0.5))
			_spawn_lamppost(Vector3(x, 0, z_road - sidewalk_offset - 0.5))
			x += lamp_spacing + rng.randf_range(-3.0, 3.0)

	# ── BENCHES, TRASH BINS, HYDRANTS on sidewalks ─────────────
	for x in range(-half, half + 1, block_spacing):
		for z in range(-half, half, 35):
			if rng.randf() < 0.6:
				_spawn_bench(Vector3(x + sidewalk_offset, 0.25, z + rng.randf_range(-10, 10)))
			if rng.randf() < 0.5:
				_spawn_trash_bin(Vector3(x - sidewalk_offset, 0, z + rng.randf_range(-8, 8)))
			if rng.randf() < 0.35:
				_spawn_fire_hydrant(Vector3(x + sidewalk_offset, 0, z + rng.randf_range(-5, 5) - 12.0))

	# ── BUS STOPS every ~300m ──────────────────────────────────
	for x in range(-half, half + 1, block_spacing):
		for z in range(-half, half, 300):
			if rng.randf() < 0.7:
				_spawn_bus_stop(Vector3(x + sidewalk_offset, 0, z))

	# ── TRAFFIC LIGHTS at intersections ───────────────────────
	for x in range(-half, half + 1, block_spacing):
		for z_road in range(-half, half + 1, block_spacing):
			if rng.randf() < 0.8:
				_spawn_traffic_light_set(Vector3(x, 0, z_road))

	# ── NEWSPAPER STANDS, MAILBOXES ────────────────────────────
	for x in range(-half + 20, half, block_spacing):
		for z in range(-half + 20, half, 80):
			if rng.randf() < 0.4:
				_spawn_newspaper_stand(Vector3(x + sidewalk_offset, 0.25, z))
			if rng.randf() < 0.5:
				_spawn_mailbox(Vector3(x - sidewalk_offset, 0, z + 20))

	# ── PLANTER BOXES, TREE GUARDS ─────────────────────────────
	for x in range(-half, half + 1, block_spacing):
		for z in range(-half, half, 50):
			if rng.randf() < 0.5:
				_spawn_tree_guard(Vector3(x + sidewalk_offset, 0, z + rng.randf_range(-15, 15)))

# ─────────────── PROP BUILDERS ─────────────────────────────────

func _spawn_lamppost(pos: Vector3) -> void:
	var root = Node3D.new()
	root.transform.origin = pos

	var mat_pole = _solid_mat(Color(0.3, 0.3, 0.35))
	var mat_head = _solid_mat(Color(0.2, 0.2, 0.25))

	# Pole
	var pole = _make_cyl(Vector3(0, 3.5, 0), 0.08, 0.1, 7.0, mat_pole)
	root.add_child(pole)

	# Arm
	var arm = _make_box(Vector3(0.6, 7.2, 0), Vector3(1.2, 0.12, 0.12), mat_pole)
	root.add_child(arm)

	# Light head
	var head = _make_box(Vector3(1.0, 7.0, 0), Vector3(0.4, 0.2, 0.35), mat_head)
	root.add_child(head)

	# Actual OmniLight
	var light = OmniLight3D.new()
	light.transform.origin = Vector3(1.0, 6.8, 0)
	light.light_color = Color(1.0, 0.88, 0.65)  # Warm sodium vapor
	light.light_energy = 1.8
	light.omni_range = 30.0
	light.shadow_enabled = false  # Performance
	root.add_child(light)

	add_child(root)

func _spawn_bench(pos: Vector3) -> void:
	var root = Node3D.new()
	root.transform.origin = pos

	var mat_wood = _solid_mat(Color(0.55, 0.35, 0.2))
	var mat_iron = _solid_mat(Color(0.25, 0.25, 0.25))

	# Seat
	var seat = _make_box(Vector3(0, 0, 0), Vector3(1.6, 0.08, 0.5), mat_wood)
	root.add_child(seat)

	# Backrest
	var back = _make_box(Vector3(0, 0.35, -0.2), Vector3(1.6, 0.5, 0.06), mat_wood)
	root.add_child(back)

	# Legs (4)
	for lx in [-0.65, 0.65]:
		for lz in [-0.18, 0.18]:
			var leg = _make_box(Vector3(lx, -0.22, lz), Vector3(0.06, 0.45, 0.06), mat_iron)
			root.add_child(leg)

	add_child(root)

func _spawn_trash_bin(pos: Vector3) -> void:
	var root = Node3D.new()
	root.transform.origin = pos

	var mat = _solid_mat(Color(0.25, 0.4, 0.25))  # Dark green NYC-style

	var bin_body = _make_cyl(Vector3(0, 0.45, 0), 0.2, 0.25, 0.9, mat)
	root.add_child(bin_body)

	var lid = _make_cyl(Vector3(0, 0.92, 0), 0.22, 0.22, 0.08, _solid_mat(Color(0.2, 0.2, 0.2)))
	root.add_child(lid)

	add_child(root)

func _spawn_fire_hydrant(pos: Vector3) -> void:
	var root = Node3D.new()
	root.transform.origin = pos

	var mat = _solid_mat(Color(0.85, 0.15, 0.1))  # Red hydrant

	var body = _make_cyl(Vector3(0, 0.25, 0), 0.12, 0.15, 0.5, mat)
	root.add_child(body)

	# Side caps
	for side in [-1, 1]:
		var cap = _make_box(Vector3(side * 0.2, 0.22, 0), Vector3(0.1, 0.12, 0.12), mat)
		root.add_child(cap)

	var top = _make_cyl(Vector3(0, 0.53, 0), 0.08, 0.08, 0.12, _solid_mat(Color(0.6, 0.6, 0.6)))
	root.add_child(top)

	add_child(root)

func _spawn_bus_stop(pos: Vector3) -> void:
	var root = Node3D.new()
	root.transform.origin = pos

	var mat_frame = _solid_mat(Color(0.3, 0.35, 0.4))
	var mat_glass = _solid_mat(Color(0.5, 0.65, 0.8))
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.albedo_color.a = 0.5

	# Back panel
	var back = _make_box(Vector3(0, 1.5, -0.05), Vector3(2.4, 2.8, 0.06), mat_glass)
	root.add_child(back)

	# Side panel
	var side = _make_box(Vector3(1.15, 1.5, 0.5), Vector3(0.06, 2.8, 1.2), mat_glass)
	root.add_child(side)

	# Roof
	var roof = _make_box(Vector3(0, 2.95, 0.5), Vector3(2.5, 0.08, 1.3), mat_frame)
	root.add_child(roof)

	# Frame posts
	for fx in [-1.15, 1.15]:
		var post = _make_box(Vector3(fx, 1.5, 0.5), Vector3(0.08, 2.8, 0.08), mat_frame)
		root.add_child(post)

	# Bench inside
	var bench = _make_box(Vector3(0, 0.5, 0.3), Vector3(1.8, 0.1, 0.4), _solid_mat(Color(0.4, 0.35, 0.3)))
	root.add_child(bench)

	add_child(root)

func _spawn_traffic_light_set(pos: Vector3) -> void:
	# Place 4 traffic lights at intersection corners
	var offsets = [
		Vector3(12, 0, 12),
		Vector3(-12, 0, 12),
		Vector3(12, 0, -12),
		Vector3(-12, 0, -12)
	]
	for off in offsets:
		if rng.randf() > 0.5:
			_spawn_single_traffic_light(pos + off)

func _spawn_single_traffic_light(pos: Vector3) -> void:
	var root = Node3D.new()
	root.transform.origin = pos

	var mat_pole = _solid_mat(Color(0.3, 0.3, 0.3))

	# Pole
	var pole = _make_box(Vector3(0, 2.75, 0), Vector3(0.12, 5.5, 0.12), mat_pole)
	root.add_child(pole)

	# Horizontal arm
	var arm = _make_box(Vector3(-1.2, 5.5, 0), Vector3(2.4, 0.1, 0.1), mat_pole)
	root.add_child(arm)

	# Light housing
	var housing = _make_box(Vector3(-1.2, 5.0, 0), Vector3(0.3, 0.8, 0.25), _solid_mat(Color(0.15, 0.15, 0.15)))
	root.add_child(housing)

	# Light bulbs (red/yellow/green)
	var colors = [Color(0.9, 0.1, 0.1), Color(0.9, 0.75, 0.1), Color(0.1, 0.8, 0.2)]
	for i in range(3):
		var bulb = _make_box(
			Vector3(-1.2, 5.3 - i * 0.25, -0.13),
			Vector3(0.12, 0.12, 0.05),
			_solid_mat(colors[i])
		)
		root.add_child(bulb)

	add_child(root)

func _spawn_newspaper_stand(pos: Vector3) -> void:
	var root = Node3D.new()
	root.transform.origin = pos

	var mat = _solid_mat(Color(0.7, 0.6, 0.1))  # Yellow vending machine
	var body = _make_box(Vector3(0, 0.4, 0), Vector3(0.5, 0.8, 0.35), mat)
	root.add_child(body)

	var top = _make_box(Vector3(0, 0.82, 0), Vector3(0.52, 0.06, 0.37), _solid_mat(Color(0.3, 0.3, 0.3)))
	root.add_child(top)

	add_child(root)

func _spawn_mailbox(pos: Vector3) -> void:
	var root = Node3D.new()
	root.transform.origin = pos

	var mat = _solid_mat(Color(0.15, 0.25, 0.7))  # USPS blue
	var body = _make_box(Vector3(0, 0.55, 0), Vector3(0.45, 0.9, 0.55), mat)
	root.add_child(body)

	var dome = _make_cyl(Vector3(0, 1.05, 0), 0.23, 0.23, 0.2, mat)
	root.add_child(dome)

	# Slot
	var slot = _make_box(Vector3(0, 0.7, 0.28), Vector3(0.2, 0.04, 0.02), _solid_mat(Color(0.1, 0.1, 0.1)))
	root.add_child(slot)

	add_child(root)

func _spawn_tree_guard(pos: Vector3) -> void:
	var root = Node3D.new()
	root.transform.origin = pos

	var mat = _solid_mat(Color(0.3, 0.3, 0.3))

	# Four sides of tree guard
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var guard = _make_box(
			Vector3(sin(angle) * 0.55, 0.2, cos(angle) * 0.55),
			Vector3(0.06, 0.4, 0.9),
			mat
		)
		guard.rotation.y = angle
		root.add_child(guard)

	add_child(root)

# ─────────────── MESH HELPERS ──────────────────────────────────

func _make_box(offset: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.transform.origin = offset
	var box = BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	return mi

func _make_cyl(offset: Vector3, top_r: float, bot_r: float, h: float, material: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.transform.origin = offset
	var cyl = CylinderMesh.new()
	cyl.top_radius = top_r
	cyl.bottom_radius = bot_r
	cyl.height = h
	mi.mesh = cyl
	mi.material_override = material
	return mi

func _solid_mat(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat
