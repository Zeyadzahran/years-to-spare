shader_type canvas_item;

uniform sampler2D scrap_texture : source_color, filter_nearest, repeat_enable;
uniform float top = 501.3;
uniform float tile_width = 501.6;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

vec3 rubble_at(float u, float v) {
	vec4 front = texture(scrap_texture, vec2(u, v));
	vec4 behind = texture(scrap_texture, vec2(u + 0.5, v));
	return mix(behind.rgb, front.rgb, front.a);
}

void fragment() {
	// Overlap two upright rubble bands; fade each out where its UV wraps.
	// This extends the heap without upside-down machinery or another skyline.
	float depth = max(local_position.y - top, 0.0);
	float phase = fract(depth / 72.0);
	float other_phase = fract(phase + 0.5);
	float weight = 0.5 - 0.5 * cos(phase * 6.2831853);
	float u = local_position.x / tile_width;
	vec3 a = rubble_at(u, mix(0.735, 0.99, phase));
	vec3 b = rubble_at(u + 0.5, mix(0.735, 0.99, other_phase));
	vec3 rubble = mix(b, a, weight);
	vec3 edge = rubble_at(u, 0.99);
	COLOR = vec4(mix(edge, rubble, smoothstep(0.0, 12.0, depth)), 1.0);
}
