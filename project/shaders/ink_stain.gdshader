shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float ink_clock = 0.0;
uniform float dry_seconds = 7.0;
void fragment() {
    float age = max(ink_clock-UV2.x,0.0);
    float dry = clamp(age/dry_seconds,0.0,1.0);
    vec2 p = UV*2.0-1.0;
    float grain = fract(sin(dot(floor(UV*90.0+UV2.y*7.0),vec2(12.9898,78.233)))*43758.5453);
    if (dry>0.8 && grain<0.035 && length(p)>0.5) { discard; }
    float wet_glint = pow(max(0.0,sin(UV.x*19.0+UV.y*8.0+age*2.0)),32.0)*(1.0-dry)*0.09;
    ALBEDO = vec3(mix(0.002,0.016,dry)+wet_glint);
}
