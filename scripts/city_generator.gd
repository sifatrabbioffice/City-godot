## scripts/city_generator.gd
## District-aware procedural city generation
## Analyzes GTA5: distinct zones (Vinewood Hills, Downtown LS, Industrial, Suburbs)
## Analyzes RDR2: density variation, landmark placement, organic decay at edges
## Each district has unique visual character and building density
extends Node3D

class_name CityGenerator

const WORLD_SIZE = 2000
const HALF = WORLD_SIZE / 2
const GROUND_Y = 0.0
const BLOCK_SIZE = 200          # Arterial grid spacing
const PLOT_SUBDIVISIONS = 5     # Plots per block side (5×5 = 25 plots per block)

# Parks/open areas (like GTA5's parks and RDR2 natural areas)
const PARK_ZONES = [
	Vector2(200, -100),
	Vector2(-300, 350),
	Vector2(400, -400),
]
const PARK_RADIUS = 80.0

var rng: RandomNumberGenerator
var building_factory: BuildingFactory

# District map: returns district name based on world position
func get_district(x: float, z: float) -> String:
	var dist = sqrt(x * x + z * z)
	var angle = atan2(z, x)

	# Core zones by radius (like GTA's concentric rings)
	if dist < 200:
		return "downtown"
	elif dist < 400:
		return "midtown"
	elif dist < 600:
		# Industrial quadrant in NE
		if angle > -PI * 0.25 and angle < PI * 0.5:
			return "industrial"
		return "midtown"
	elif dist < 800:
		return "residential"
	else:
		return "suburb"

func build_city(rng_ref: RandomNumberGenerator) -> void:
	rng = rng_ref

	# Initialize building factory
	building_factory = BuildingFactory.new()
	add_child(building_factory)

	# Ground plane
	_build_ground()

	# Build each city block
	var blocks_built = 0
	for bx in range(-HALF + BLOCK_SIZE, HALF, BLOCK_SIZE):
		for bz in range(-HALF + BLOCK_SIZE, HALF, BLOCK_SIZE):
			_build_block(bx, bz)
			blocks_built += 1

	# Landmark buildings (like GTA's Maze Bank, Rockford Hills mansions)
	_build_landmarks()

	# Parks and plazas
	_build_parks()

	# Water feature (like GTA's Alamo Sea / river)
	_build_river()

	# Beach/waterfront strip along south edge
	_build_waterfront()

	print("[CityGenerator] Built %d blocks" % blocks_built)

func _build_ground() -> void:
	# Layered ground: grass base + urban concrete cap
	var grass_body = StaticBody3D.new()
	grass_body.name = "Ground"

	var grass_shape = BoxShape3D.new()
	grass_shape.size = Vector3(WORLD_SIZE, 0.5, WORLD_SIZE)
	var grass_col = CollisionShape3D.new()
	grass_col.shape = grass_shape
	grass_body.add_child(grass_col)

	var grass_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(WORLD_SIZE, 0.5, WORLD_SIZE)
	grass_mesh.mesh = box
	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.25, 0.52, 0.2)
	grass_mat.roughness = 0.95
	grass_mesh.material_override = grass_mat
	grass_body.add_child(grass_mesh)
	grass_body.transform.origin.y = -0.25
	add_child(grass_body)

func _build_block(block_x: int, block_z: int) -> void:
	var district = get_district(float(block_x), float(block_z))
	var plot_size = float(BLOCK_SIZE) / float(PLOT_SUBDIVISIONS)

	# Inner area of block (leave road + sidewalk margin)
	var road_width = 18.0
	var sidewalk = 4.5
	var margin = road_width / 2.0 + sidewalk

	# Check if this block is a park zone
	for pz_center in PARK_ZONES:
		var park_dist = Vector2(block_x - pz_center.x, block_z - pz_center.y).length()
		if park_dist < PARK_RADIUS:
			return  # Skip buildings — park system handles this

	for ix in range(PLOT_SUBDIVISIONS):
		for iz in range(PLOT_SUBDIVISIONS):
			var px = float(block_x) - float(BLOCK_SIZE) * 0.5 + plot_size * ix + plot_size * 0.5
			var pz = float(block_z) - float(BLOCK_SIZE) * 0.5 + plot_size * iz + plot_size * 0.5

			# Skip plots too close to road margins
			var local_x = abs(px - block_x)
			var local_z = abs(pz - block_z)
			if local_x < margin or local_z < margin:
				continue

			# District-based density check
			var build_chance = _get_density(district)
			if rng.randf() > build_chance:
				continue

			# Footprint is slightly randomized within plot
			var w = rng.randf_range(plot_size * 0.45, plot_size * 0.78)
			var d = rng.randf_range(plot_size * 0.45, plot_size * 0.78)

			var offset_x = rng.randf_range(-plot_size * 0.08, plot_size * 0.08)
			var offset_z = rng.randf_range(-plot_size * 0.08, plot_size * 0.08)

			var building = building_factory.build(
				Vector3(px + offset_x, 0, pz + offset_z),
				w, d, district, rng
			)
			if building:
				add_child(building)

func _get_density(district: String) -> float:
	match district:
		"downtown": return 0.90
		"midtown": return 0.72
		"residential": return 0.58
		"industrial": return 0.45
		"suburb": return 0.32
	return 0.5

func _build_landmarks() -> void:
	# Signature landmark towers (like GTA's Maze Bank Tower)
	var landmarks = [
		{"pos": Vector3(0, 0, 0),          "w": 28.0, "d": 28.0, "h": 150.0, "color": Color(0.3, 0.35, 0.4)},   # Central tower
		{"pos": Vector3(150, 0, -80),       "w": 20.0, "d": 20.0, "h": 110.0, "color": Color(0.7, 0.72, 0.75)},  # Office tower
		{"pos": Vector3(-100, 0, 120),      "w": 18.0, "d": 22.0, "h": 95.0,  "color": Color(0.4, 0.38, 0.35)},  # Mixed use tower
		{"pos": Vector3(80, 0, 150),        "w": 15.0, "d": 15.0, "h": 80.0,  "color": Color(0.25, 0.28, 0.32)}, # Glass tower
		{"pos": Vector3(-160, 0, -60),      "w": 35.0, "d": 35.0, "h": 70.0,  "color": Color(0.82, 0.78, 0.72)}, # Wide complex
	]

	for lm in landmarks:
		var body = StaticBody3D.new()
		body.transform.origin = lm["pos"] + Vector3(0, lm["h"] * 0.5, 0)

		var shape = BoxShape3D.new()
		shape.size = Vector3(lm["w"], lm["h"], lm["d"])
		var col = CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)

		var mi = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(lm["w"], lm["h"], lm["d"])
		mi.mesh = box

		# Landmark-specific shader facade
		var mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/building_facade.gdshader")
		mat.set_shader_parameter("wall_color", lm["color"])
		mat.set_shader_parameter("window_cols", 8.0)
		mat.set_shader_parameter("window_rows", float(int(lm["h"] / 4.0)))
		mat.set_shader_parameter("light_seed", 0.3)
		mi.material_override = mat
		body.add_child(mi)

		add_child(body)

		# Antenna on tallest (like GTA's Maze Bank antenna)
		if lm["h"] >= 120.0:
			var antenna = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.2
			cyl.bottom_radius = 0.4
			cyl.height = 30.0
			antenna.mesh = cyl
			var ant_mat = StandardMaterial3D.new()
			ant_mat.albedo_color = Color(0.4, 0.4, 0.4)
			antenna.material_override = ant_mat
			antenna.transform.origin = lm["pos"] + Vector3(0, lm["h"] + 15.0, 0)
			add_child(antenna)

			var blink = OmniLight3D.new()
			blink.transform.origin = lm["pos"] + Vector3(0, lm["h"] + 30.0, 0)
			blink.light_color = Color(1.0, 0.1, 0.1)
			blink.light_energy = 5.0
			blink.omni_range = 80.0
			add_child(blink)

func _build_parks() -> void:
	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.22, 0.55, 0.18)
	grass_mat.roughness = 0.95

	var path_mat = StandardMaterial3D.new()
	path_mat.albedo_color = Color(0.7, 0.67, 0.6)  # Sand/gravel path

	var tree_trunk_mat = StandardMaterial3D.new()
	tree_trunk_mat.albedo_color = Color(0.45, 0.28, 0.12)

	for park_center in PARK_ZONES:
		var pc = Vector3(park_center.x, 0.2, park_center.y)

		# Park grass
		var grass = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(PARK_RADIUS * 2.0, 0.4, PARK_RADIUS * 2.0)
		grass.mesh = box
		grass.material_override = grass_mat
		grass.transform.origin = pc
		add_child(grass)

		# Park paths (diagonal cross)
		for angle_offset in [0.0, PI * 0.5]:
			var path = MeshInstance3D.new()
			var pbox = BoxMesh.new()
			pbox.size = Vector3(4.0, 0.1, PARK_RADIUS * 2.0)
			path.mesh = pbox
			path.material_override = path_mat
			path.transform.origin = pc + Vector3(0, 0.2, 0)
			path.rotation.y = angle_offset
			add_child(path)

		# Fountain centerpiece
		_build_fountain(pc + Vector3(0, 0.3, 0))

		# Dense trees throughout park
		for t in range(rng.randi_range(15, 30)):
			var angle = rng.randf() * TAU
			var dist = rng.randf_range(10.0, PARK_RADIUS * 0.85)
			var tp = pc + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
			_spawn_park_tree(tp, tree_trunk_mat)

		# Park benches
		for b in range(rng.randi_range(4, 8)):
			var angle = rng.randf() * TAU
			var dist = rng.randf_range(5.0, 15.0)
			var bp = pc + Vector3(cos(angle) * dist, 0.4, sin(angle) * dist)
			var bench_mat = StandardMaterial3D.new()
			bench_mat.albedo_color = Color(0.5, 0.32, 0.15)
			var bench = MeshInstance3D.new()
			var bbox = BoxMesh.new()
			bbox.size = Vector3(1.8, 0.1, 0.5)
			bench.mesh = bbox
			bench.material_override = bench_mat
			bench.transform.origin = bp
			add_child(bench)

func _build_fountain(pos: Vector3) -> void:
	var stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.72, 0.68, 0.62)

	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.3, 0.55, 0.8)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color.a = 0.75
	water_mat.metallic = 0.4
	water_mat.roughness = 0.1

	# Basin
	var basin = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 5.0
	cyl.bottom_radius = 5.5
	cyl.height = 0.8
	basin.mesh = cyl
	basin.material_override = stone_mat
	basin.transform.origin = pos
	add_child(basin)

	# Water surface
	var water = MeshInstance3D.new()
	var wcyl = CylinderMesh.new()
	wcyl.top_radius = 4.6
	wcyl.bottom_radius = 4.6
	wcyl.height = 0.05
	water.mesh = wcyl
	water.material_override = water_mat
	water.transform.origin = pos + Vector3(0, 0.4, 0)
	add_child(water)

	# Center column
	var col = MeshInstance3D.new()
	var ccyl = CylinderMesh.new()
	ccyl.top_radius = 0.5
	ccyl.bottom_radius = 0.7
	ccyl.height = 2.5
	col.mesh = ccyl
	col.material_override = stone_mat
	col.transform.origin = pos + Vector3(0, 1.25, 0)
	add_child(col)

	# Top bowl
	var bowl = MeshInstance3D.new()
	var bcyl = CylinderMesh.new()
	bcyl.top_radius = 1.5
	bcyl.bottom_radius = 1.6
	bcyl.height = 0.4
	bowl.mesh = bcyl
	bowl.material_override = stone_mat
	bowl.transform.origin = pos + Vector3(0, 2.7, 0)
	add_child(bowl)

func _spawn_park_tree(pos: Vector3, trunk_mat: StandardMaterial3D) -> void:
	var height = rng.randf_range(4.0, 10.0)
	var radius = rng.randf_range(1.5, 3.5)

	# Trunk
	var trunk = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.22
	cyl.height = height * 0.6
	trunk.mesh = cyl
	trunk.material_override = trunk_mat
	trunk.transform.origin = pos + Vector3(0, height * 0.3, 0)
	add_child(trunk)

	# Foliage (layered cones for variety — like RDR2's tree silhouettes)
	var foliage_colors = [
		Color(0.1, 0.45, 0.12),
		Color(0.12, 0.4, 0.1),
		Color(0.15, 0.5, 0.15),
	]
	var leaves_mat = StandardMaterial3D.new()
	leaves_mat.albedo_color = foliage_colors[rng.randi() % foliage_colors.size()]

	var layer_count = rng.randi_range(2, 4)
	for l in range(layer_count):
		var layer = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		var layer_r = radius * (1.0 - l * 0.15)
		cone.top_radius = 0.0
		cone.bottom_radius = layer_r
		cone.height = height * 0.4
		layer.mesh = cone
		layer.material_override = leaves_mat
		layer.transform.origin = pos + Vector3(0, height * 0.55 + l * height * 0.15, 0)
		add_child(layer)

func _build_river() -> void:
	# River cutting across SW quadrant (like GTA's Los Santos River / RDR2's rivers)
	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.25, 0.45, 0.65)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color.a = 0.85
	water_mat.metallic = 0.5
	water_mat.roughness = 0.05

	# Main river channel (diagonal cut through SW)
	var river = StaticBody3D.new()
	river.transform.origin = Vector3(-500, -0.3, 500)
	river.rotation.y = PI * 0.25  # 45-degree diagonal

	var shape = BoxShape3D.new()
	shape.size = Vector3(50.0, 0.6, 1200.0)
	var col = CollisionShape3D.new()
	col.shape = shape
	river.add_child(col)

	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(50.0, 0.6, 1200.0)
	mi.mesh = box
	mi.material_override = water_mat
	river.add_child(mi)
	add_child(river)

	# Riverbank (concrete retaining walls like LA river / GTA)
	var bank_mat = StandardMaterial3D.new()
	bank_mat.albedo_color = Color(0.6, 0.58, 0.55)

	for side in [-1, 1]:
		var bank = MeshInstance3D.new()
		var bbox = BoxMesh.new()
		bbox.size = Vector3(8.0, 2.0, 1200.0)
		bank.mesh = bbox
		bank.material_override = bank_mat
		bank.transform.origin = Vector3(-500 + side * 29.0, 0.5, 500)
		bank.rotation.y = PI * 0.25
		add_child(bank)

func _build_waterfront() -> void:
	# Southern waterfront (like GTA's Del Perro/Vespucci Beach or RDR2's lakeside towns)
	var sand_mat = StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.88, 0.82, 0.65)  # Sandy beach

	var ocean_mat = StandardMaterial3D.new()
	ocean_mat.albedo_color = Color(0.2, 0.42, 0.65)
	ocean_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ocean_mat.albedo_color.a = 0.88
	ocean_mat.metallic = 0.6
	ocean_mat.roughness = 0.05

	# Beach strip
	var beach = MeshInstance3D.new()
	var bbox = BoxMesh.new()
	bbox.size = Vector3(float(WORLD_SIZE), 0.3, 80.0)
	beach.mesh = bbox
	beach.material_override = sand_mat
	beach.transform.origin = Vector3(0, 0.15, float(HALF) - 40.0)
	add_child(beach)

	# Ocean extending south
	var ocean = StaticBody3D.new()
	ocean.transform.origin = Vector3(0, -1.5, float(HALF) + 250.0)
	var ocean_shape = BoxShape3D.new()
	ocean_shape.size = Vector3(float(WORLD_SIZE), 3.0, 500.0)
	var ocol = CollisionShape3D.new()
	ocol.shape = ocean_shape
	ocean.add_child(ocol)
	var omi = MeshInstance3D.new()
	var obox = BoxMesh.new()
	obox.size = Vector3(float(WORLD_SIZE), 3.0, 500.0)
	omi.mesh = obox
	omi.material_override = ocean_mat
	ocean.add_child(omi)
	add_child(ocean)

	# Boardwalk
	var board_mat = StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.62, 0.48, 0.32)  # Wood planks

	var boardwalk = StaticBody3D.new()
	boardwalk.transform.origin = Vector3(0, 0.55, float(HALF) - 70.0)
	var bshape = BoxShape3D.new()
	bshape.size = Vector3(float(WORLD_SIZE), 0.3, 15.0)
	var bcol = CollisionShape3D.new()
	bcol.shape = bshape
	boardwalk.add_child(bcol)
	var bmi = MeshInstance3D.new()
	var bbox2 = BoxMesh.new()
	bbox2.size = Vector3(float(WORLD_SIZE), 0.3, 15.0)
	bmi.mesh = bbox2
	bmi.material_override = board_mat
	boardwalk.add_child(bmi)
	add_child(boardwalk)

	# Pier extending into ocean
	_build_pier(Vector3(0, 0, float(HALF) - 10.0), board_mat)

func _build_pier(pos: Vector3, mat: Material) -> void:
	# Pier deck
	var pier = StaticBody3D.new()
	pier.transform.origin = pos + Vector3(0, 0.6, 150.0)
	var pshape = BoxShape3D.new()
	pshape.size = Vector3(12.0, 0.4, 300.0)
	var pcol = CollisionShape3D.new()
	pcol.shape = pshape
	pier.add_child(pcol)
	var pmi = MeshInstance3D.new()
	var pbox = BoxMesh.new()
	pbox.size = Vector3(12.0, 0.4, 300.0)
	pmi.mesh = pbox
	pmi.material_override = mat
	pier.add_child(pmi)
	add_child(pier)

	# Pier railing
	for side in [-1, 1]:
		var rail = MeshInstance3D.new()
		var rbox = BoxMesh.new()
		rbox.size = Vector3(0.15, 1.0, 300.0)
		rail.mesh = rbox
		var rail_mat = StandardMaterial3D.new()
		rail_mat.albedo_color = Color(0.5, 0.4, 0.28)
		rail.material_override = rail_mat
		rail.transform.origin = pos + Vector3(side * 6.0, 1.1, 150.0)
		add_child(rail)

	# Pier pilings every 10m
	var piling_mat = StandardMaterial3D.new()
	piling_mat.albedo_color = Color(0.4, 0.35, 0.28)
	for pz in range(0, 300, 15):
		for px in [-5, 5]:
			var piling = MeshInstance3D.new()
			var pcyl = CylinderMesh.new()
			pcyl.top_radius = 0.3
			pcyl.bottom_radius = 0.4
			pcyl.height = 3.0
			piling.mesh = pcyl
			piling.material_override = piling_mat
			piling.transform.origin = pos + Vector3(float(px), -0.9, float(pz))
			add_child(piling)
