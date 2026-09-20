shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D pixel_atlas : source_color, filter_nearest, repeat_disable;
uniform bool loop_clip = false;
uniform float clip_bottom = -10000.0;
uniform float clip_top = 10000.0;
uniform bool portal_clip = false;
uniform vec3 portal_origin = vec3(0.0);
uniform vec3 portal_normal = vec3(0.0,1.0,0.0);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	if (loop_clip && (world_position.y < clip_bottom || world_position.y > clip_top)) { discard; }
	if (portal_clip && dot(world_position - portal_origin,portal_normal) < 0.0) { discard; }
	ALBEDO = texture(pixel_atlas, UV).rgb;
}
