#version 120

// Iris option declarations
const int ENABLE_SUNMOON = 1; // [0 1]

#ifndef ENABLE_SUNMOON
#define ENABLE_SUNMOON 1
#endif

uniform sampler2D texture;
uniform int worldTime;
varying vec2 uv;
varying vec4 col;

void main() {
#if ENABLE_SUNMOON == 0
    discard;
#endif

    vec4 c = texture2D(texture, uv);
    if (c.a < 0.05) discard;

    float tod = mod(float(worldTime), 24000.0) / 24000.0;

    vec3 sunTint = vec3(1.0);
    if (tod > 0.60 && tod < 0.75) {
        float t = smoothstep(0.60, 0.75, tod);
        sunTint = mix(vec3(1.0, 0.95, 0.85), vec3(1.2, 0.55, 0.20), t);
    }

    c.rgb *= sunTint * col.rgb * 1.4;
    gl_FragColor = vec4(c.rgb, c.a * col.a);
}
