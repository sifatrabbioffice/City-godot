// building_facade.gdshader
// Generates fake windows, ledges, and lit interiors procedurally
// Inspired by GTA5/Cyberpunk building visual design
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4 wall_color : source_color = vec4(0.65, 0.62, 0.58, 1.0);
uniform vec4 window_color : source_color = vec4(0.3, 0.4, 0.6, 1.0);
uniform vec4 window_lit : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform vec4 frame_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);

uniform float window_cols = 6.0;
uniform float window_rows = 12.0;
uniform float window_size = 0.65;
uniform float frame_width = 0.06;
uniform float light_seed = 0.0;
uniform float roughness_val = 0.7;

// Pseudo-random
float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;

	// Grid UVs for windows
	vec2 grid = uv * vec2(window_cols, window_rows);
	vec2 cell = floor(grid);
	vec2 local = fract(grid);

	float half_frame = frame_width;
	float half_win = (1.0 - window_size) * 0.5;

	bool is_frame = (local.x < half_frame || local.x > (1.0 - half_frame) ||
					 local.y < half_frame || local.y > (1.0 - half_frame));

	// Window interior check
	bool in_window = (local.x > half_win && local.x < (1.0 - half_win) &&
					  local.y > half_win && local.y < (1.0 - half_win));

	// Random lit/unlit per window cell
	float r = hash(cell + vec2(light_seed, light_seed * 1.7));
	bool lit = r > 0.35;

	// Ledge lines every 3 floors
	float ledge_freq = 3.0;
	float ledge_pos = fract(uv.y * window_rows / ledge_freq);
	bool is_ledge = ledge_pos < 0.025;

	vec4 color;
	if (is_ledge) {
		color = frame_color + vec4(0.1, 0.1, 0.1, 0.0);
	} else if (is_frame) {
		color = frame_color;
	} else if (in_window) {
		color = lit ? window_lit : window_color;
	} else {
		// Wall — add slight variation
		float wall_var = hash(floor(uv * 40.0)) * 0.05;
		color = wall_color + vec4(wall_var, wall_var, wall_var, 0.0);
	}

	ALBEDO = color.rgb;
	ROUGHNESS = roughness_val;
	METALLIC = in_window ? 0.3 : 0.0;

	// Emission for lit windows (night glow)
	if (in_window && lit) {
		EMISSION = window_lit.rgb * 0.4;
	}
}
