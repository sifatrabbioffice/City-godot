// road_surface.gdshader
// Procedural road with lane markings, crosswalks, and asphalt texture
// Inspired by GTA5's detailed road system
shader_type spatial;
render_mode diffuse_lambert;

uniform vec4 asphalt_color : source_color = vec4(0.22, 0.22, 0.22, 1.0);
uniform vec4 line_color : source_color = vec4(0.95, 0.9, 0.3, 1.0);
uniform vec4 white_line : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float road_width = 12.0;  // meters
uniform float lane_count = 4.0;
uniform float dash_length = 3.0;
uniform float dash_gap = 3.0;
uniform bool is_highway = false;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// Asphalt base with subtle noise grain
	float grain = hash(floor(UV * 200.0)) * 0.04;
	vec4 base = asphalt_color + vec4(grain, grain, grain, 0.0);

	// Lane markings
	float lane_width = 1.0 / lane_count;
	float lane_u = fract(uv.x / lane_width);
	float center = abs(uv.x - 0.5);

	bool on_center_line = center < 0.015;
	bool on_edge_line = (uv.x < 0.02 || uv.x > 0.98);
	bool on_lane_dash = (lane_u < 0.012 || lane_u > 0.988);

	// Dashed lane dividers
	float dash_cycle = dash_length + dash_gap;
	float dash_pos = fract(uv.y * 20.0 / dash_cycle * dash_length);
	bool dash_visible = dash_pos < (dash_length / dash_cycle);

	// Crosswalk zones every ~50 units
	float crosswalk_cycle = fract(uv.y * 4.0);
	bool in_crosswalk_zone = crosswalk_cycle < 0.05;
	float crosswalk_stripe = fract(uv.x * 8.0);
	bool crosswalk_stripe_vis = crosswalk_stripe < 0.4;

	vec4 color = base;

	// Edge solid white lines
	if (on_edge_line) {
		color = white_line;
	}
	// Center yellow double line (GTA-style main roads)
	else if (on_center_line && !is_highway) {
		color = line_color;
	}
	// Lane dashes
	else if (on_lane_dash && dash_visible && !on_center_line) {
		color = white_line;
	}
	// Crosswalk
	else if (in_crosswalk_zone && crosswalk_stripe_vis) {
		color = white_line * 0.95;
	}

	ALBEDO = color.rgb;
	ROUGHNESS = 0.88;
	METALLIC = 0.0;

	// Subtle specular from rain/wetness simulation
	float wet = smoothstep(0.9, 1.0, hash(floor(uv * 5.0)));
	ROUGHNESS -= wet * 0.2;
}
