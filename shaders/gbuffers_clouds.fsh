#version 120

// Iris option declarations
const int ENABLE_CLOUDS = 1; // [0 1]

#ifndef ENABLE_CLOUDS
#define ENABLE_CLOUDS 1
#endif

uniform sampler2D texture;
uniform int worldTime;
varying vec2 uv;
varying vec4 col;

void main() {
#if ENABLE_CLOUDS == 0
    discard;
#endif

    vec4 cloud = texture2D(texture, uv) * col;
    if (cloud.a < 0.05) discard;

    float tod = mod(float(worldTime), 24000.0) / 24000.0;

    vec3 cloudCol = cloud.rgb;
    if (tod < 0.15) {
        float t = smoothstep(0.0, 0.15, tod);
        cloudCol *= mix(vec3(0.6, 0.4, 0.5), vec3(1.0, 0.92, 0.88), t);
    } else if (tod > 0.60 && tod < 0.75) {
        float t = smoothstep(0.60, 0.75, tod);
        cloudCol *= mix(vec3(1.0, 0.92, 0.88), vec3(1.1, 0.65, 0.30), t);
    } else if (tod >= 0.75) {
        cloudCol *= vec3(0.25, 0.28, 0.38);
    }

    gl_FragColor = vec4(cloudCol, cloud.a);
}
