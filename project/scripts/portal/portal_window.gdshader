shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D remote_view : source_color, filter_linear, repeat_disable;

void fragment() {
	if (distance(UV, vec2(0.5)) > 0.5) { discard; }
	ALBEDO = texture(remote_view, UV).rgb;
}
