shader_type spatial;
render_mode unshaded;
uniform float pulse_strength : hint_range(0.0,0.3) = 0.085;
uniform float rim_width : hint_range(0.0,0.3) = 0.055;
uniform float motion = 0.0;
varying vec3 model_position;
void vertex() {
    float wave = sin(VERTEX.x*4.1+TIME*2.7)*sin(VERTEX.y*3.4-TIME*1.9);
    wave += 0.48*sin(VERTEX.z*7.0+TIME*3.1);
    VERTEX += NORMAL * wave * pulse_strength;
    VERTEX.y *= 1.05+motion*0.04;
    model_position = VERTEX;
}
void fragment() {
    float edge = 1.0-abs(dot(normalize(NORMAL),normalize(VIEW)));
    float rim = smoothstep(1.0-rim_width,1.0,edge);
    float sheen = pow(max(dot(normalize(NORMAL),normalize(vec3(-0.4,0.6,0.8))),0.0),48.0);
    float split = smoothstep(0.989,1.0,sin(model_position.y*27.0+model_position.x*8.0+TIME*1.1));
    split *= smoothstep(0.65,0.78,model_position.x)*0.32;
    ALBEDO = mix(vec3(0.0035),vec3(0.98,0.98,0.96),max(rim,sheen*0.17+split));
}
