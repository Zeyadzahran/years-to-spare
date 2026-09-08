shader_type canvas_item;

// Driven from ToxicWater's script on TimeService's clock, not the engine's
// own TIME, so the ripple freezes with the rest of the world under Stop Time.
uniform float time = 0.0;

// Reference depth for the deep -> mid -> surface color gradient. The pit this
// ships with is asymmetric (the two walls meet the ground at different
// heights), so this is a nominal mid-value rather than the exact depth at
// every X - it just has to make both ends of the slope read as believable.
uniform float depth = 150.0;
uniform float amplitude : hint_range(0.0, 20.0) = 6.0;
uniform vec4 deep_color : source_color = vec4(0.09, 0.2, 0.17, 0.95);
uniform vec4 mid_color : source_color = vec4(0.18, 0.36, 0.29, 0.92);
uniform vec4 surface_color : source_color = vec4(0.4, 0.5, 0.3, 0.88);

varying float local_x;
varying float local_y;

void vertex() {
	// The floor corners sit near Y = 0; every other vertex is the (possibly
	// sloped) surface line. A fixed band separates the two regardless of how
	// tall either wall of the pit is, so the ripple never touches the floor.
	float top_mask = 1.0 - smoothstep(-80.0, -30.0, VERTEX.y);
	float wave = sin(VERTEX.x * 0.045 + time * 1.6) * 0.6
			+ sin(VERTEX.x * 0.11 - time * 2.3) * 0.4;
	VERTEX.y += wave * amplitude * top_mask;
	local_x = VERTEX.x;
	local_y = VERTEX.y;
}

void fragment() {
	// 0 at the still floor, 1 at (or past) the rippling surface.
	float depth_ratio = clamp(-local_y / depth, 0.0, 1.0);
	vec4 col = mix(deep_color, mid_color, smoothstep(0.0, 0.55, depth_ratio));
	col = mix(col, surface_color, smoothstep(0.6, 1.0, depth_ratio));
	// Slow toxic murk so the body reads as alive, not a flat fill.
	float murk = sin(local_x * 0.08 + time * 0.8) * sin(local_y * 0.12 - time * 0.5);
	col.rgb += murk * 0.035;
	COLOR = col;
}
