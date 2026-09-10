shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 paper_color : source_color = vec4(0.97,0.964,0.944,1.0);
uniform float shade_depth : hint_range(0.0,0.3) = 0.13;
varying vec3 world_normal;
void vertex() {
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    float light = dot(normalize(world_normal), normalize(vec3(-0.45,0.72,0.51)));
    float plane = smoothstep(-0.35,0.7,light);
    ALBEDO = paper_color.rgb * mix(1.0-shade_depth,1.0,plane);
}
