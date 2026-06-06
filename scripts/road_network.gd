scripts/road_network.gd
## Hierarchical road system: Highways → Major → Minor → Alleys
## Inspired by GTA5's Los Santos road layout analysis
extends Node3D

class_name RoadNetwork

# Road hierarchy (like GTA5's road types)
enum RoadType {
	HIGHWAY,      # Raised highway / freeway (outer ring)
	ARTERIAL,     # Major 4-lane city roads
	COLLECTOR,    # 2-lane secondary streets
	LOCAL,        # Narrow side streets
	ALLEY,        # Back alleys between blocks
}

const ROAD_CONFIG = {
	RoadType.HIGHWAY: {
		"width": 24.0,
		"height_raise": 4.0,  # Elevated above city
		"color": Color(0.28, 0.28, 0.28),
		"median_width": 3.0,
	},
	RoadType.ARTERIAL: {
		"width": 18.0,
		"height_raise": 0.0,
		"color": Color(0.22, 0.22, 0.22),
		"median_width": 0.0,
	},
	RoadType.COLLECTOR: {
		"width": 12.0,
		"height_raise": 0.0,
		"color": Color(0.20, 0.20, 0.20),
		"median_width": 0.0,
	},
	RoadType.LOCAL: {
		"width": 8.0,
		"height_raise": 0.0,
		"color": Color(0.18, 0.18, 0.18),
		"median_width": 0.0,
	},
	RoadType.ALLEY: {
		"width": 4.5,
		"height_raise": 0.0,
		"color": Color(0.16, 0.16, 0.16),
		"median_width": 0.0,
	},
}

const ROAD_H = 0.3  # Road surface height above ground

var rng: RandomNumberGenerator
var road_shader: Shader

func build_network(world_size: int, rng_ref: RandomNumberGenerator) -> void:
	rng = rng_ref
	road_shader = load("res://shaders/road_surface.gdshader")

	var half = world_size / 2

	# ── HIGHWAY OUTER RING ──────────────────────────────────
	# Ring road around the city (like GTA's highway loop)
	var hw_offset = half - 80
	_build_elevated_highway_ring(hw_offset)

	# ── ARTERIAL GRID (every 200m) ──────────────────────────
	var arterial_spacing = 200
	for x in range(-half, half + 1, arterial_spacing):
		_build_road_segment(
			Vector3(x, ROAD_H, 0),
			Vector3(ROAD_CONFIG[RoadType.ARTERIAL]["width"], ROAD_H, float(world_size)),
			RoadType.ARTERIAL,
			true  # vertical
		)
	for z in range(-half, half + 1, arterial_spacing):
		_build_road_segment(
			Vector3(0, ROAD_H, z),
			Vector3(float(world_size), ROAD_H, ROAD_CONFIG[RoadType.ARTERIAL]["width"]),
			RoadType.ARTERIAL,
			false
		)

	# ── COLLECTOR GRID (every 100m inside arterials) ─────────
	var collector_spacing = 100
	for x in range(-half + 50, half, arterial_spacing):
		for z in range(-half, half + 1, collector_spacing):
			var start = Vector3(x, ROAD_H, z - collector_spacing * 0.5)
			_build_road_segment(
				Vector3(x, ROAD_H, z),
				Vector3(ROAD_CONFIG[RoadType.COLLECTOR]["width"], ROAD_H, float(collector_spacing)),
				RoadType.COLLECTOR,
				true
			)

	for z in range(-half + 50, half, arterial_spacing):
		for x in range(-half, half + 1, collector_spacing):
			_build_road_segment(
				Vector3(x, ROAD_H, z),
				Vector3(float(collector_spacing), ROAD_H, ROAD_CONFIG[RoadType.COLLECTOR]["width"]),
				RoadType.COLLECTOR,
				false
			)

	# ── INTERSECTIONS ────────────────────────────────────────
	# Fill intersection boxes so no gap between perpendicular roads
	_build_intersections(world_size, arterial_spacing, RoadType.ARTERIAL)
	_build_intersections(world_size, collector_spacing, RoadType.COLLECTOR)

	# ── SIDEWALKS ────────────────────────────────────────────
	_build_sidewalk_network(world_size, arterial_spacing)

func _build_road_segment(pos: Vector3, size: Vector3, road_type: RoadType, is_longitudinal: bool) -> void:
	var config = ROAD_CONFIG[road_type]
	var body = StaticBody3D.new()
	body.transform.origin = pos

	# Collision
	var shape = BoxShape3D.new()
	shape.size = size
	var col = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)

	# Mesh with road shader
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mi.mesh = box

	# Apply road shader material
	var mat = ShaderMaterial.new()
	mat.shader = road_shader
	mat.set_shader_parameter("asphalt_color", config["color"])
	mat.set_shader_parameter("road_width", config["width"])
	mat.set_shader_parameter("is_highway", road_type == RoadType.HIGHWAY)
	mi.material_override = mat
	body.add_child(mi)

	add_child(body)

	# Road edge curbs
	if road_type != RoadType.HIGHWAY:
		_add_curbs(pos, size, config["width"], is_longitudinal)

	# Median strip for arterials
	if config["median_width"] > 0:
		_add_median(pos, size, config["median_width"], is_longitudinal)

func _build_elevated_highway_ring(offset: float) -> void:
	var hw = float(ROAD_CONFIG[RoadType.HIGHWAY]["width"])
	var elevation = ROAD_CONFIG[RoadType.HIGHWAY]["height_raise"]
	var road_size_h = hw * 2.0  # Total size including both lanes

	# Highway spans entire world length, elevated
	var hw_y = ROAD_H + elevation

	# North and South highway segments
	for sign in [-1, 1]:
		var z_pos = offset * sign
		var highway_seg = StaticBody3D.new()
		highway_seg.transform.origin = Vector3(0, hw_y, z_pos)

		var shape = BoxShape3D.new()
		var seg_size = Vector3(offset * 2.0, ROAD_H, hw)
		shape.size = seg_size
		var col = CollisionShape3D.new()
		col.shape = shape
		highway_seg.add_child(col)

		var mi = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = seg_size
		mi.mesh = box
		mi.material_override = _make_highway_mat()
		highway_seg.add_child(mi)
		add_child(highway_seg)

		# Support pillars every 20m
		_add_highway_pillars(Vector3(0, 0, z_pos), offset * 2.0, elevation, hw, false)

	# East and West highway segments
	for sign in [-1, 1]:
		var x_pos = offset * sign
		var highway_seg = StaticBody3D.new()
		highway_seg.transform.origin = Vector3(x_pos, hw_y, 0)

		var shape = BoxShape3D.new()
		var seg_size = Vector3(hw, ROAD_H, offset * 2.0)
		shape.size = seg_size
		var col = CollisionShape3D.new()
		col.shape = shape
		highway_seg.add_child(col)

		var mi = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = seg_size
		mi.mesh = box
		mi.material_override = _make_highway_mat()
		highway_seg.add_child(mi)
		add_child(highway_seg)

		_add_highway_pillars(Vector3(x_pos, 0, 0), offset * 2.0, elevation, hw, true)

func _add_highway_pillars(origin: Vector3, road_length: float, elevation: float, road_width: float, is_z_axis: bool) -> void:
	var pillar_spacing = 20.0
	var pillar_mat = StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.55, 0.55, 0.55)

	var count = int(road_length / pillar_spacing)
	for i in range(count):
		var t = -road_length * 0.5 + i * pillar_spacing + pillar_spacing * 0.5
		var pos: Vector3
		if is_z_axis:
			pos = Vector3(origin.x, elevation * 0.5, t)
		else:
			pos = Vector3(t, elevation * 0.5, origin.z)

		# Two pillars per span (one each side of road)
		for side in [-1, 1]:
			var pillar_mi = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.6
			cyl.bottom_radius = 0.8
			cyl.height = elevation
			pillar_mi.mesh = cyl
			pillar_mi.material_override = pillar_mat

			var offset = Vector3(side * road_width * 0.35, 0, 0) if not is_z_axis else Vector3(0, 0, side * road_width * 0.35)
			pillar_mi.transform.origin = pos + offset
			add_child(pillar_mi)

func _add_curbs(road_pos: Vector3, road_size: Vector3, road_width: float, is_longitudinal: bool) -> void:
	var curb_mat = StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.72, 0.72, 0.72)  # Light grey concrete

	var curb_h = 0.15
	var curb_w = 0.35

	for side in [-1, 1]:
		var curb = MeshInstance3D.new()
		var box = BoxMesh.new()
		var curb_size: Vector3
		var curb_pos: Vector3

		if is_longitudinal:
			curb_size = Vector3(curb_w, curb_h, road_size.z)
			curb_pos = Vector3(
				road_pos.x + side * (road_width * 0.5 + curb_w * 0.5),
				road_pos.y + curb_h * 0.5,
				road_pos.z
			)
		else:
			curb_size = Vector3(road_size.x, curb_h, curb_w)
			curb_pos = Vector3(
				road_pos.x,
				road_pos.y + curb_h * 0.5,
				road_pos.z + side * (road_width * 0.5 + curb_w * 0.5)
			)

		box.size = curb_size
		curb.mesh = box
		curb.material_override = curb_mat
		curb.transform.origin = curb_pos
		add_child(curb)

func _add_median(road_pos: Vector3, road_size: Vector3, median_width: float, is_longitudinal: bool) -> void:
	var median_mat = StandardMaterial3D.new()
	median_mat.albedo_color = Color(0.28, 0.52, 0.22)  # Grass median

	var median = MeshInstance3D.new()
	var box = BoxMesh.new()
	var ms: Vector3
	if is_longitudinal:
		ms = Vector3(median_width, 0.05, road_size.z)
	else:
		ms = Vector3(road_size.x, 0.05, median_width)
	box.size = ms
	median.mesh = box
	median.material_override = median_mat
	median.transform.origin = road_pos + Vector3(0, 0.05, 0)
	add_child(median)

func _build_intersections(world_size: int, spacing: int, road_type: RoadType) -> void:
	var half = world_size / 2
	var config = ROAD_CONFIG[road_type]
	var w = config["width"]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = config["color"]

	for x in range(-half, half + 1, spacing):
		for z in range(-half, half + 1, spacing):
			var intersection = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(w, ROAD_H, w)
			intersection.mesh = box
			intersection.material_override = mat
			intersection.transform.origin = Vector3(x, ROAD_H, z)
			add_child(intersection)

func _build_sidewalk_network(world_size: int, block_spacing: int) -> void:
	var sidewalk_mat = StandardMaterial3D.new()
	sidewalk_mat.albedo_color = Color(0.75, 0.73, 0.70)  # Light concrete

	var half = world_size / 2
	var arterial_w = ROAD_CONFIG[RoadType.ARTERIAL]["width"]
	var sidewalk_w = 4.0

	# Sidewalk strips parallel to arterials
	for x in range(-half, half + 1, block_spacing):
		for side in [-1, 1]:
			var sw = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(sidewalk_w, 0.25, float(world_size))
			sw.mesh = box
			sw.material_override = sidewalk_mat
			sw.transform.origin = Vector3(
				x + side * (arterial_w * 0.5 + sidewalk_w * 0.5),
				0.25 * 0.5 + ROAD_H,
				0
			)
			add_child(sw)

	for z in range(-half, half + 1, block_spacing):
		for side in [-1, 1]:
			var sw = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(float(world_size), 0.25, sidewalk_w)
			sw.mesh = box
			sw.material_override = sidewalk_mat
			sw.transform.origin = Vector3(
				0,
				0.25 * 0.5 + ROAD_H,
				z + side * (arterial_w * 0.5 + sidewalk_w * 0.5)
			)
			add_child(sw)

func _make_highway_mat() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = ROAD_CONFIG[RoadType.HIGHWAY]["color"]
	return mat
