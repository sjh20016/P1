shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world_normal;
void vertex() { world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
	float light=dot(normalize(world_normal),normalize(vec3(-0.45,0.72,0.51)));
	float shade=mix(0.76,0.94,smoothstep(-0.5,0.8,light));
	vec2 edge=min(UV,vec2(1.0)-UV);
	vec2 width=max(fwidth(UV)*0.7,vec2(0.0003));
	float border=1.0-min(smoothstep(0.0,width.x,edge.x),smoothstep(0.0,width.y,edge.y));
	ALBEDO=mix(vec3(shade,shade*0.992,shade*0.968),vec3(0.12),border*0.55);
}
