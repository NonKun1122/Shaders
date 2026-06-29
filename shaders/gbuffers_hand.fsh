#version 120

uniform sampler2D texture;
uniform int   worldTime;
uniform float frameTimeCounter;

varying vec2  uv;
varying vec4  col;

#ifndef NIGHT_BRIGHTNESS
#define NIGHT_BRIGHTNESS 0.3
#endif

void main() {
    vec4 albedo = texture2D(texture, uv) * col;
    if (albedo.a < 0.1) discard;

    float tod = mod(float(worldTime), 24000.0) / 24000.0;

    float dayFactor;
    if      (tod < 0.45) dayFactor = 1.0;
    else if (tod < 0.55) dayFactor = 1.0 - smoothstep(0.45, 0.55, tod);
    else if (tod > 0.95) dayFactor = smoothstep(0.95, 1.0, tod);
    else                 dayFactor = 0.0;
    float nightFactor = 1.0 - dayFactor;

    vec3 color = albedo.rgb;

    // กลางคืน: มืดลงตาม NIGHT_BRIGHTNESS แต่ไม่มืดสนิท (fill 0.15)
    float nightMul = mix(1.0, max(NIGHT_BRIGHTNESS * 0.9, 0.15), nightFactor);
    color *= nightMul;

    gl_FragColor = vec4(color, albedo.a);
}
