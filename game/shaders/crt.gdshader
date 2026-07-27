shader_type canvas_item;
render_mode unshaded;

// Arcade cabinet look: gentle tube curvature, scanlines, glass vignette,
// channel fringing, and a cheap bloom sampled from a blurred mip of the
// screen so the neon UI bleeds light the way a CRT does.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float curvature : hint_range(0.0, 0.2) = 0.012;
uniform float scanlines : hint_range(0.0, 0.5) = 0.10;
uniform float scan_period : hint_range(1.0, 8.0) = 3.0;
uniform float aberration : hint_range(0.0, 0.01) = 0.0014;
uniform float vignette : hint_range(0.0, 1.0) = 0.26;
uniform float bloom : hint_range(0.0, 2.0) = 0.55;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.48;
uniform float flicker : hint_range(0.0, 0.1) = 0.012;

void fragment() {
	// --- tube curvature
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	centered *= 1.0 + curvature * dot(centered, centered);
	vec2 uv = centered * 0.5 + 0.5;

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		// outside the glass — black bezel
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 dir = uv - vec2(0.5);

		// --- chromatic aberration, splitting radially
		vec3 col;
		col.r = texture(screen_tex, clamp(uv + dir * aberration, vec2(0.0), vec2(1.0))).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, clamp(uv - dir * aberration, vec2(0.0), vec2(1.0))).b;

		// --- bloom from a blurred mip: only bright pixels bleed
		vec3 blurred = textureLod(screen_tex, uv, 4.0).rgb;
		vec3 bright = max(blurred - vec3(bloom_threshold), vec3(0.0));
		col += bright * bloom;

		// --- scanlines every scan_period physical pixels
		float scan = 1.0 - scanlines * (0.5 + 0.5 * cos(FRAGCOORD.y * 6.28318 / scan_period));
		col *= scan;

		// --- slow mains hum flicker
		col *= 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 8.0));

		// --- glass vignette
		float v = smoothstep(1.30, 0.35, length(dir) * 2.0);
		col *= mix(1.0, v, vignette);

		COLOR = vec4(col, 1.0);
	}
}
