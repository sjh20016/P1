shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
varying vec3 world_normal;
void vertex() {
    world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
    float light = dot(normalize(world_normal), normalize(vec3(-0.6,0.85,-0.25)));
    float shade = mix(0.56,0.94,smoothstep(-0.5,0.8,light));
    vec2 edge = min(UV,vec2(1.0)-UV);
    vec2 width = max(fwidth(UV)*0.65,vec2(0.00001));
    float border = 1.0-min(smoothstep(0.0,width.x,edge.x),smoothstep(0.0,width.y,edge.y));
    vec3 color = mix(vec3(shade,shade*0.994,shade*0.978),vec3(0.13),border*0.42);
    float haze = smoothstep(120.0,480.0,length(VERTEX))*0.55;
    ALBEDO = mix(color,vec3(0.97,0.964,0.944),haze);
}
