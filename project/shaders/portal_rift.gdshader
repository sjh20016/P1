shader_type spatial;
render_mode unshaded, cull_back;
void fragment() {
	vec2 p = floor((UV * 2.0 - 1.0) * 80.0) / 80.0;
	float r = length(p);
	if (r > 1.0) discard;
	float a = atan(p.y,p.x);
	float seam = step(0.988, sin(a * 7.0 + r * 12.0 - TIME * 1.8)) * smoothstep(0.35,0.94,r);
	vec3 ink = vec3(0.009,0.012,0.020);
	ALBEDO = ink + vec3(0.11,0.13,0.16) * seam;
}
