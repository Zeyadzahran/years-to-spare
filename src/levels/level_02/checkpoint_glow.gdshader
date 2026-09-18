shader_type canvas_item;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 pipe = texture(TEXTURE, UV);
	// Only the lower (activated) atlas row glows. Keep the metal and silhouette still.
	float active = step(0.5, UV.y);
	float light = smoothstep(0.1, 0.5, min(pipe.g, pipe.b) - pipe.r);
	float pulse = 0.5 + 0.5 * sin(TIME * 3.14159265);
	vec3 dim_light = pipe.rgb * vec3(0.65, 0.7, 0.8);
	vec3 bright_light = mix(pipe.rgb, vec3(0.65, 0.95, 1.0), 0.35);
	COLOR = tint * vec4(mix(pipe.rgb, mix(dim_light, bright_light, pulse), active * light), pipe.a);
}
