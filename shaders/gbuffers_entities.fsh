#version 120

// FIX: Removed "const int ENABLE_DIRLIGHT" and "const float SHADOW_STRENGTH"
// These const declarations prevented Iris from injecting user-configured values.

#ifndef ENABLE_DIRLIGHT
#define ENABLE_DIRLIGHT 1
#endif
#ifndef DAY_BRIGHTNESS
#define DAY_BRIGHTNESS 0.85
#endif
#ifndef NIGHT_BRIGHTNESS
#define NIGHT_BRIGHTNESS 0.3
#endif
#ifndef TORCH_COLOR_R
#define TORCH_COLOR_R 1.0
#endif
#ifndef TORCH_COLOR_G
#define TORCH_COLOR_G 0.5
#endif
#ifndef TORCH_COLOR_B
#define TORCH_COLOR_B 0.1
#endif
#ifndef TORCH_STRENGTH
#define TORCH_STRENGTH 2.5
#endif
#ifndef SHADOW_STRENGTH
#define SHADOW_STRENGTH 0.5
#endif

uniform sampler2D texture;
uniform int worldTime;
uniform float rainStrength;

varying vec2 uv;
varying vec4 col;
varying vec3 norm;
varying float bl;
varying float sl;

void main() {
    vec4 albedo = texture2D(texture, uv) * col;
    if (albedo.a < 0.1) discard;

    float tod = mod(float(worldTime), 24000.0) / 24000.0;

    float dayFactor;
    if (tod < 0.45) dayFactor = 1.0;
    else if (tod < 0.55) dayFactor = 1.0 - smoothstep(0.45, 0.55, tod);
    else if (tod > 0.95) dayFactor = smoothstep(0.95, 1.0, tod);
    else dayFactor = 0.0;
    float nightFactor = 1.0 - dayFactor;

    float sl2 = sl * sl;
    float bl2 = bl * bl;

    // Use NIGHT_BRIGHTNESS setting
    vec3 skyAmbDay   = vec3(0.60, 0.85, 1.00) * sl2 * 0.65 * DAY_BRIGHTNESS;
    vec3 skyAmbNight = vec3(0.06, 0.06, 0.15) * sl2 * 0.30 * NIGHT_BRIGHTNESS;
    vec3 skyAmb = mix(skyAmbDay, skyAmbNight, nightFactor);

    vec3 torchColor = vec3(TORCH_COLOR_R, TORCH_COLOR_G, TORCH_COLOR_B);
    float torchMul = mix(0.80, TORCH_STRENGTH * 0.6, nightFactor);
    vec3 torchC = torchColor * (bl2 * torchMul);

    // Night floor darker with NIGHT_BRIGHTNESS
    vec3 nightFloor = vec3(0.08, 0.08, 0.15) * nightFactor * NIGHT_BRIGHTNESS * 0.5;
    vec3 ambient = albedo.rgb * (skyAmb + torchC + vec3(0.04)) + albedo.rgb * nightFloor;

    vec3 sunCol;
    if (tod < 0.10) {
        sunCol = mix(vec3(0.60, 0.30, 0.10), vec3(1.00, 0.90, 0.60), tod / 0.10);
    } else if (tod < 0.25) {
        sunCol = mix(vec3(1.00, 0.90, 0.60), vec3(1.00, 0.98, 0.95), (tod - 0.10) / 0.15);
    } else if (tod < 0.45) {
        sunCol = vec3(1.00, 0.98, 0.95);
    } else if (tod < 0.55) {
        sunCol = mix(vec3(1.00, 0.98, 0.95), vec3(0.40, 0.30, 0.20), (tod - 0.45) / 0.10);
    } else if (tod < 0.75) {
        sunCol = mix(vec3(0.40, 0.30, 0.20), vec3(0.08, 0.08, 0.18), (tod - 0.55) / 0.20);
    } else {
        sunCol = vec3(0.08, 0.08, 0.18);
    }

#if ENABLE_DIRLIGHT == 1
    float dirLight = max(dot(norm, normalize(vec3(0.55, 1.0, 0.4))), 0.0);
    dirLight = dirLight * 0.5 + 0.5;
    float shadowAmt = mix(0.85, 0.15, nightFactor) * SHADOW_STRENGTH;
    vec3 diffuse = albedo.rgb * sunCol * dirLight * shadowAmt;
#else
    vec3 diffuse = albedo.rgb * sunCol * mix(0.70, 0.15, nightFactor);
#endif

    vec3 color = ambient + diffuse;

    if (rainStrength > 0.01) {
        float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
        color = mix(color, vec3(luma * 0.80), rainStrength * 0.30);
    }

    gl_FragColor = vec4(color, albedo.a);
}
