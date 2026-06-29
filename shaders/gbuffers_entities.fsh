#version 120

// Iris option declarations
const int   ENABLE_DIRLIGHT  = 1;   // [0 1]
const float DAY_BRIGHTNESS   = 1.0; // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2]
const float NIGHT_BRIGHTNESS = 0.3; // [0.1 0.2 0.3 0.4 0.5 0.6 0.7]
const float TORCH_COLOR_R    = 1.0; // [0.5 0.6 0.7 0.8 0.9 1.0]
const float TORCH_COLOR_G    = 0.7; // [0.2 0.3 0.4 0.5 0.6 0.7 0.8]
const float TORCH_COLOR_B    = 0.4; // [0.0 0.1 0.2 0.3 0.4 0.5]
const float TORCH_STRENGTH   = 2.5; // [1.0 1.5 2.0 2.5 3.0 3.5 4.0]
const float SHADOW_STRENGTH  = 0.5; // [0.2 0.3 0.4 0.5 0.6 0.7 0.8]
const float SHADOW_BIAS      = 0.0015; // [0.0005 0.001 0.0015 0.002 0.003]

#ifndef ENABLE_DIRLIGHT
#define ENABLE_DIRLIGHT 1
#endif
#ifndef DAY_BRIGHTNESS
#define DAY_BRIGHTNESS 1.0
#endif
#ifndef NIGHT_BRIGHTNESS
#define NIGHT_BRIGHTNESS 0.3
#endif
#ifndef TORCH_COLOR_R
#define TORCH_COLOR_R 1.0
#endif
#ifndef TORCH_COLOR_G
#define TORCH_COLOR_G 0.7
#endif
#ifndef TORCH_COLOR_B
#define TORCH_COLOR_B 0.4
#endif
#ifndef TORCH_STRENGTH
#define TORCH_STRENGTH 2.5
#endif
#ifndef SHADOW_STRENGTH
#define SHADOW_STRENGTH 0.5
#endif
#ifndef SHADOW_BIAS
#define SHADOW_BIAS 0.0015
#endif

uniform sampler2D texture;
uniform sampler2D shadowtex0;
uniform int   worldTime;
uniform float rainStrength;

varying vec2  uv;
varying vec4  col;
varying vec3  norm;
varying float bl;
varying float sl;
varying vec4  shadowPos;

float getShadow(vec3 sp, vec3 n) {
    if (sp.x < 0.001 || sp.x > 0.999 || sp.y < 0.001 || sp.y > 0.999) return 1.0;
    if (sp.z >= 1.0) return 1.0;

    vec3  lightDir = normalize(vec3(0.55, 1.0, 0.4));
    float cosTheta = clamp(dot(n, lightDir), 0.0, 1.0);
    float bias     = mix(SHADOW_BIAS * 3.0, SHADOW_BIAS * 0.5, cosTheta);

    // 4-tap PCF
    float shadow = 0.0;
    float texel  = 1.0 / 2048.0;
    for (int x = -1; x <= 1; x += 2)
        for (int y = -1; y <= 1; y += 2)
            shadow += step(sp.z - bias,
                           texture2D(shadowtex0, sp.xy + vec2(float(x), float(y)) * texel).r);
    return shadow * 0.25;
}

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

    float sl2 = sl * sl;
    float bl2 = bl * bl;

    // ── Ambient ─────────────────────────────────────────────
    vec3 skyAmbDay   = vec3(0.65, 0.85, 1.00) * sl2 * 0.55 * DAY_BRIGHTNESS;
    vec3 skyAmbNight = vec3(0.05, 0.07, 0.18) * sl2 * 0.30 * NIGHT_BRIGHTNESS;
    vec3 moonAmb     = vec3(0.15, 0.18, 0.30) * sl2 * nightFactor * 0.20;
    vec3 skyAmb      = mix(skyAmbDay, skyAmbNight, nightFactor) + moonAmb;

    vec3  torchColor = vec3(TORCH_COLOR_R, TORCH_COLOR_G, TORCH_COLOR_B);
    float torchMul   = mix(0.5, TORCH_STRENGTH * 0.5, nightFactor);
    vec3  torchC     = torchColor * (bl2 * torchMul);
    vec3  nightFill  = vec3(0.03, 0.04, 0.07) * nightFactor;

    vec3 ambient = albedo.rgb * (skyAmb + torchC + vec3(0.015) + nightFill);

    // ── Light Direction ──────────────────────────────────────
    vec3 lightDir = mix(
        normalize(vec3( 0.55, 1.0,  0.4)),
        normalize(vec3(-0.40, 0.9, -0.3)),
        nightFactor
    );

    // ── Sun/Moon Color ────────────────────────────────────────
    vec3 sunCol;
    if      (tod < 0.06) sunCol = mix(vec3(0.90, 0.30, 0.05), vec3(1.00, 0.60, 0.10), tod / 0.06);
    else if (tod < 0.12) sunCol = mix(vec3(1.00, 0.60, 0.10), vec3(1.00, 0.98, 0.92), (tod - 0.06) / 0.06);
    else if (tod < 0.40) sunCol = vec3(1.00, 0.98, 0.92);
    else if (tod < 0.48) sunCol = mix(vec3(1.00, 0.98, 0.92), vec3(1.00, 0.60, 0.10), (tod - 0.40) / 0.08);
    else if (tod < 0.55) sunCol = mix(vec3(1.00, 0.60, 0.10), vec3(0.20, 0.22, 0.40), (tod - 0.48) / 0.07);
    else                 sunCol = vec3(0.15, 0.17, 0.35);

    // ── Diffuse + Shadow ─────────────────────────────────────
    vec3 diffuse = vec3(0.0);
#if ENABLE_DIRLIGHT == 1
    vec3  normL    = normalize(norm);
    float dirLight = max(dot(normL, lightDir), 0.0) * 0.7 + 0.3;

    float shadowVal    = getShadow(shadowPos.xyz, normL);
    float shadowStrFin = mix(SHADOW_STRENGTH, SHADOW_STRENGTH * 0.6, nightFactor);
    shadowVal = mix(1.0, shadowVal, max(dayFactor, nightFactor * 0.45) * shadowStrFin);

    float diffuseMul = mix(1.2, 0.30, nightFactor);
    diffuse = albedo.rgb * sunCol * dirLight * shadowVal * diffuseMul;
#else
    vec3 normL = normalize(norm);
    diffuse    = albedo.rgb * sunCol * dayFactor * 0.9;
#endif

    vec3 color = ambient + diffuse;

    if (rainStrength > 0.01) {
        float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
        color = mix(color, vec3(luma * 0.85), rainStrength * 0.25);
    }

    // ── Write to MRT ─────────────────────────────────────────
    gl_FragData[0] = vec4(color, albedo.a);
    gl_FragData[1] = vec4(normalize(norm) * 0.5 + 0.5, 1.0);  // normal buffer สำหรับ reflection
}
