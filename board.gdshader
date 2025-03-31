shader_type spatial;

const float delta = 0.25;

void fragment() {
	vec4 frag_ws = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	
	vec2 ws = frag_ws.xz + 6.0;
	vec2 wsa = ws.xy - mod(ws.xy, 1.0);
	vec2 border = mod(ws + delta/2.0, 1.0);
	
	vec3 color = vec3(0);
	if (ws.y >= 6.0) { color.b = 0.5;  }
	if (ws.y <  6.0) { color.g = 0.25; }
	vec3 accent = color;
	
	if (border.x < delta || border.y < delta) {
		if (mod(wsa.x + wsa.y, 2) == 0.0) {
			accent *= 0.5;
		} else {
			accent *= 2.0;
		}
	}
	
	vec4 dist = vec4(0);
	if (border.x < delta * 0.5) {
		dist.x = border.x;
	} else if (border.x < delta) {
		dist.x = (delta - border.x);
	}
	if (border.y < delta * 0.5) {
		dist.y = border.y;
	} else if (border.y < delta) {
		dist.y = (delta - border.y);
	}
	dist /= delta * 0.5;
	
	ALBEDO.rgb = mix(color, accent, max(dist.x, dist.y));
}
