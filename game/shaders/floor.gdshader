shader_type canvas_item;
// Perspective ground plane ("Mode 7"): each screen row samples a top-down tile at the
// depth that row lies at, so the floor recedes to the horizon, scrolls with parallax
// and fades into haze. At the `lane` row one floor pixel is one screen pixel.

uniform sampler2D floor_tex : filter_nearest, repeat_enable;
uniform float cam = 0.0;          // world x of the screen's left edge, at the lane
uniform float horizon = 232.0;    // screen y of the horizon
uniform float lane = 300.0;       // screen y of the rover's lane
uniform float top = 232.0;        // screen y of this rect's top edge
uniform vec2 size = vec2(640.0, 128.0);
uniform float depth_k = 3.0;      // floor texels per screen row at the lane (camera pitch)
uniform float tile = 128.0;
uniform vec4 haze : source_color = vec4(0.1, 0.1, 0.14, 1.0);
uniform float haze_max = 0.8;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	const float BAYER[16] = float[16](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);
	vec2 px = floor(UV * size);
	float y = top + px.y + 0.5;
	float h = lane - horizon;
	float s = h / max(y - horizon, 0.5);
	float wx = cam + 320.0 + (px.x + 0.5 - 320.0) * s;
	float wz = s * h * depth_k;
	vec4 c = texture(floor_tex, vec2(wx, wz) / tile);
	int bi = int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4;
	float fog = clamp((s - 1.0) / 9.0, 0.0, 1.0);
	fog = floor(fog * 6.0 + BAYER[bi] / 16.0) / 6.0 * haze_max;
	COLOR = vec4(mix(c.rgb * tint.rgb, haze.rgb, fog), 1.0);
}
