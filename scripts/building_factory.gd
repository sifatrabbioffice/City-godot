## scripts/building_factory.gd
## Modular building generator inspired by GTA5, Watch Dogs, Cyberpunk
## Creates skyscrapers, mid-rise, low-rise, industrial, residential buildings
## Each building type has unique silhouettes and details
extends Node3D

class_name BuildingFactory

# ─────────────── Building Type Constants ───────────────
enum BuildingType {
	SKYSCRAPER,      # Downtown glass towers (like GTA's Maze Bank)
	OFFICE_MIDRISE,  # 6-15 floor office blocks
	APARTMENT,       # Residential brownstones/apartments
	COMMERCIAL,      # Ground-floor shops, 3-6 floors above
	INDUSTRIAL,      # Warehouses, factories
	PARKING_GARAGE,  # Open-deck car parks
	HOTEL,           # Wide footprint, uniform windows
	CHURCH,          # Cultural landmark stub
}

# ─────────────── District Presets ───────────────
# Each district controls what buildings can spawn (like GTA's zones)
const DISTRICT_PRESETS = {
	"downtown": {
		"types": [BuildingType.SKYSCRAPER, BuildingType.OFFICE_MIDRISE, BuildingType.HOTEL],
		"height_min": 30.0,
		"height_max": 120.0,
		"density": 0.9,
		"color_palette": [
			Color(0.7, 0.75, 0.85),   # Glass blue-grey
			Color(0.85, 0.82, 0.78),  # Limestone
			Color(0.3, 0.3, 0.35),    # Dark glass
			Color(0.75, 0.7, 0.65),   # Concrete
		]
	},
	"midtown": {
		"types": [BuildingType.OFFICE_MIDRISE, BuildingType.APARTMENT, BuildingType.COMMERCIAL],
		"height_min": 12.0,
		"height_max": 45.0,
		"density": 0.75,
		"color_palette": [
			Color(0.75, 0.68, 0.58),  # Brick tan
			Color(0.65, 0.62, 0.7),   # Purple-grey
			Color(0.8, 0.72, 0.62),   # Sandstone
			Color(0.6, 0.65, 0.6),    # Green-grey
		]
	},
	"residential": {
		"types": [BuildingType.APARTMENT, BuildingType.COMMERCIAL],
		"height_min": 6.0,
		"height_max": 20.0,
		"density": 0.6,
		"color_palette": [
			Color(0.78, 0.65, 0.52),  # Warm brick
			Color(0.85, 0.8, 0.72),   # Light plaster
			Color(0.7, 0.6, 0.55),    # Old brick
			Color(0.9, 0.85, 0.78),   # Cream
		]
	},
	"industrial": {
		"types": [BuildingType.INDUSTRIAL, BuildingType.PARKING_GARAGE],
		"height_min": 5.0,
		"height_max": 18.0,
		"density": 0.5,
		"color_palette": [
			Color(0.5, 0.48, 0.45),   # Industrial grey
			Color(0.6, 0.55, 0.45),   # Rust brown
			Color(0.45, 0.45, 0.5),   # Dark concrete
			Color(0.7, 0.6, 0.4),     # Yellow warehouse
		]
	},
	"suburb": {
		"types": [BuildingType.APARTMENT, BuildingType.COMMERCIAL],
		"height_min": 4.0,
		"height_max": 10.0,
		"density": 0.35,
		"color_palette": [
			Color(0.88, 0.82, 0.72),  # Suburban beige
			Color(0.75, 0.78, 0.72),  # Sage green
			Color(0.85, 0.78, 0.78),  # Dusty rose
			Color(0.78, 0.85, 0.88),  # Sky blue
		]
	}
}

var rng: RandomNumberGenerator
var facade_shader: Shader

# ─────────────── Main Build Function ───────────────
func build(
	position: Vector3,
	plot_width: float,
	plot_depth: float,
	district: String,
	rng_ref: RandomNumberGenerator
) -> Node3D:
	rng = rng_ref
	var preset = DISTRICT_PRESETS[district]
	var b_type = preset["types"][rng.randi() % preset["types"].size()]
	var height = rng.randf_range(preset["height_min"], preset["height_max"])
	var wall_color = preset["color_palette"][rng.randi() % preset["color_palette"].size()]

	match b_type:
		BuildingType.SKYSCRAPER:
			return _build_skyscraper(position, plot_width, plot_depth, height, wall_color)
		BuildingType.OFFICE_MIDRISE:
			return _build_midrise(position, plot_width, plot_depth, height, wall_color)
		BuildingType.APARTMENT:
			return _build_apartment(position, plot_width, plot_depth, height, wall_color)
		BuildingType.COMMERCIAL:
			return _build_commercial(position, plot_width, plot_depth, height, wall_color)
		BuildingType.INDUSTRIAL:
			return _build_industrial(position, plot_width, plot_depth, height, wall_color)
		BuildingType.PARKING_GARAGE:
			return _build_parking_garage(position, plot_width, plot_depth, height, wall_color)
		_:
			return _build_midrise(position, plot_width, plot_depth, height, wall_color)

# ─────────────── Skyscraper (GTA-style tower) ───────────────
func _build_skyscraper(pos: Vector3, w: float, d: float, h: float, color: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "Skyscraper"
	root.transform.origin = pos + Vector3(0, h * 0.5, 0)

	# Setback profile — narrower at top like real skyscrapers
	var sections = []
	var section_count = rng.randi_range(2, 4)
	var remaining_h = h
	var current_w = w
	var current_d = d

	for i in range(section_count):
		var section_ratio = 0.6 if i < section_count - 1 else 0.4
		var sh = remaining_h * section_ratio
		remaining_h -= sh
		sections.append({
			"height": sh,
			"width": current_w,
			"depth": current_d
		})
		current_w *= rng.randf_range(0.6, 0.85)
		current_d *= rng.randf_range(0.6, 0.85)

	# Add rooftop section
	sections.append({"height": remaining_h + 2.0, "width": current_w, "depth": current_d})

	var y_offset = -h * 0.5
	for sec in sections:
		var body = _make_collision_body(
			Vector3(0, y_offset + sec["height"] * 0.5, 0),
			Vector3(sec["width"], sec["height"], sec["depth"]),
			_make_facade_mat(color, float(rng.randi_range(4, 10)), float(rng.randi_range(8, 20)))
		)
		root.add_child(body)
		y_offset += sec["height"]

	# Antenna/spire on tallest building
	if h > 60.0:
		var spire = _make_box(
			Vector3(0, y_offset + 8.0, 0),
			Vector3(0.5, 16.0, 0.5),
			_make_solid_mat(Color(0.4, 0.4, 0.4))
		)
		root.add_child(spire)
		# Red blinking light
		var light = OmniLight3D.new()
		light.transform.origin = Vector3(0, y_offset + 16.5, 0)
		light.light_color = Color(1.0, 0.1, 0.1)
		light.light_energy = 3.0
		light.omni_range = 50.0
		root.add_child(light)

	return root

# ─────────────── Mid-Rise Office Block ───────────────
func _build_midrise(pos: Vector3, w: float, d: float, h: float, color: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "MidRise"
	root.transform.origin = pos + Vector3(0, h * 0.5, 0)

	var floors = int(h / 3.5)

	# Main body
	var body = _make_collision_body(
		Vector3(0, 0, 0),
		Vector3(w, h, d),
		_make_facade_mat(color, float(rng.randi_range(3, 7)), float(floors))
	)
	root.add_child(body)

	# Rooftop HVAC units (procedural detail)
	var hvac_count = rng.randi_range(2, 6)
	for i in range(hvac_count):
		var hx = rng.randf_range(-w * 0.3, w * 0.3)
		var hz = rng.randf_range(-d * 0.3, d * 0.3)
		var hvac = _make_box(
			Vector3(hx, h * 0.5 + 0.75, hz),
			Vector3(rng.randf_range(1.5, 3.0), 1.5, rng.randf_range(1.5, 3.0)),
			_make_solid_mat(Color(0.55, 0.55, 0.55))
		)
		root.add_child(hvac)

	# Cornice / roof parapet
	var parapet = _make_box(
		Vector3(0, h * 0.5 + 0.3, 0),
		Vector3(w + 0.5, 0.6, d + 0.5),
		_make_solid_mat(color.lightened(0.15))
	)
	root.add_child(parapet)

	return root

# ─────────────── Apartment Block ───────────────
func _build_apartment(pos: Vector3, w: float, d: float, h: float, color: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "Apartment"
	root.transform.origin = pos + Vector3(0, h * 0.5, 0)

	# Main block
	var body = _make_collision_body(
		Vector3(0, 0, 0),
		Vector3(w, h, d),
		_make_facade_mat(color, float(rng.randi_range(3, 5)), float(int(h / 3.0)))
	)
	root.add_child(body)

	# Balconies every 3 floors
	var floor_height = 3.2
	var balcony_depth = 1.2
	var floor_count = int(h / floor_height)
	for f in range(1, floor_count, 2):
		var by = -h * 0.5 + f * floor_height + floor_height * 0.5
		# Front-facing balconies
		var balcony = _make_box(
			Vector3(0, by, d * 0.5 + balcony_depth * 0.5),
			Vector3(w * rng.randf_range(0.4, 0.8), 0.2, balcony_depth),
			_make_solid_mat(Color(0.75, 0.72, 0.68))
		)
		root.add_child(balcony)

	# Ground floor - commercial awning
	var awning = _make_box(
		Vector3(0, -h * 0.5 + 2.5, d * 0.5 + 0.8),
		Vector3(w * 0.8, 0.15, 1.6),
		_make_solid_mat(Color(rng.randf_range(0.5, 0.9), 0.2, 0.2))  # Red/colored awning
	)
	root.add_child(awning)

	return root

# ─────────────── Commercial Building ───────────────
func _build_commercial(pos: Vector3, w: float, d: float, h: float, color: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "Commercial"
	root.transform.origin = pos + Vector3(0, h * 0.5, 0)

	# Upper floors
	var upper_h = h * 0.7
	var upper_body = _make_collision_body(
		Vector3(0, (h - upper_h) * 0.5, 0),
		Vector3(w, upper_h, d),
		_make_facade_mat(color, float(rng.randi_range(2, 5)), float(int(upper_h / 3.0)))
	)
	root.add_child(upper_body)

	# Ground floor with larger windows / storefront
	var ground_h = h * 0.3
	var ground_body = _make_collision_body(
		Vector3(0, -h * 0.5 + ground_h * 0.5, 0),
		Vector3(w, ground_h, d),
		_make_facade_mat(Color(0.3, 0.3, 0.35), 1.0, 1.0)  # Glass storefront
	)
	root.add_child(ground_body)

	# Signage band between ground and upper floors
	var sign_band = _make_box(
		Vector3(0, -h * 0.5 + ground_h + 0.2, d * 0.5 + 0.1),
		Vector3(w, 0.4, 0.2),
		_make_solid_mat(Color(0.15, 0.15, 0.15))
	)
	root.add_child(sign_band)

	return root

# ─────────────── Industrial Building ───────────────
func _build_industrial(pos: Vector3, w: float, d: float, h: float, color: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "Industrial"
	root.transform.origin = pos + Vector3(0, h * 0.5, 0)

	# Wide low main warehouse
	var main = _make_collision_body(
		Vector3(0, 0, 0),
		Vector3(w, h, d),
		_make_solid_mat(color)
	)
	root.add_child(main)

	# Saw-tooth roof (classic factory profile)
	var roof_sections = rng.randi_range(2, 5)
	var section_w = w / float(roof_sections)
	for rs in range(roof_sections):
		var rx = -w * 0.5 + section_w * rs + section_w * 0.5
		var roof_peak = _make_box(
			Vector3(rx, h * 0.5 + 1.5, 0),
			Vector3(section_w * 0.9, 3.0, d * 0.9),
			_make_solid_mat(color.darkened(0.1))
		)
		root.add_child(roof_peak)

	# Loading dock doors
	var dock_count = rng.randi_range(1, 3)
	for dc in range(dock_count):
		var dx = rng.randf_range(-w * 0.3, w * 0.3)
		var dock = _make_box(
			Vector3(dx, -h * 0.5 + 2.0, d * 0.5 + 0.05),
			Vector3(3.5, 4.0, 0.1),
			_make_solid_mat(Color(0.2, 0.2, 0.2))
		)
		root.add_child(dock)

	# Chimney stacks
	if rng.randf() < 0.5:
		var chimney = _make_collision_body(
			Vector3(w * 0.3, h * 0.5 + 4.0, d * 0.2),
			Vector3(1.2, 8.0, 1.2),
			_make_solid_mat(Color(0.4, 0.35, 0.3))
		)
		root.add_child(chimney)

	return root

# ─────────────── Parking Garage ───────────────
func _build_parking_garage(pos: Vector3, w: float, d: float, h: float, color: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "ParkingGarage"
	root.transform.origin = pos + Vector3(0, h * 0.5, 0)

	var deck_h = 3.0
	var deck_count = int(h / deck_h)

	for deck in range(deck_count):
		var dy = -h * 0.5 + deck * deck_h + deck_h * 0.5
		# Solid floor plate
		var floor_plate = _make_box(
			Vector3(0, dy - deck_h * 0.4, 0),
			Vector3(w, 0.4, d),
			_make_solid_mat(Color(0.6, 0.6, 0.6))
		)
		root.add_child(floor_plate)

		# Open façade banding (horizontal slabs with gaps)
		var slab = _make_box(
			Vector3(0, dy - deck_h * 0.4 + 2.2, d * 0.5),
			Vector3(w, 0.3, 0.2),
			_make_solid_mat(Color(0.55, 0.55, 0.55))
		)
		root.add_child(slab)

	# Collision for full garage
	var main = _make_collision_body(
		Vector3(0, 0, 0),
		Vector3(w, h, d),
		null  # Invisible collision only
	)
	root.add_child(main)

	return root

# ─────────────── Helper: Collision Body with Mesh ───────────────
func _make_collision_body(offset: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.transform.origin = offset

	var shape = BoxShape3D.new()
	shape.size = size
	var col = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)

	if material != null:
		var mi = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = size
		mi.mesh = box
		mi.material_override = material
		body.add_child(mi)

	return body

# Helper: mesh-only box
func _make_box(offset: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.transform.origin = offset
	var box = BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	return mi

# Helper: Shader facade material (windows via shader)
func _make_facade_mat(color: Color, cols: float, rows: float) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/building_facade.gdshader")
	mat.set_shader_parameter("wall_color", color)
	mat.set_shader_parameter("window_cols", cols)
	mat.set_shader_parameter("window_rows", rows)
	mat.set_shader_parameter("light_seed", randf())  # Random window lighting
	# Window color variation by building type
	var win_hue = Color(
		randf_range(0.25, 0.45),
		randf_range(0.35, 0.5),
		randf_range(0.6, 0.8)
	)
	mat.set_shader_parameter("window_color", win_hue)
	return mat

# Helper: Solid colored material
func _make_solid_mat(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	return mat
