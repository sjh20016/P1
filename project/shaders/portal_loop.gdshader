shader_type spatial;
render_mode cull_back;
uniform float bottom;
uniform float top;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	if (world_position.y < bottom || world_position.y > top) { discard; }
	ALBEDO = vec3(0.012, 0.015, 0.021);
	ROUGHNESS = 0.38;
}
