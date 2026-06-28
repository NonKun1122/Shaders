#version 120

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
#ifndef SHADOW_QUALITY
#define SHADOW_QUALITY 1
#endif
#ifndef ENABLE_SPECULAR
#define ENABLE_SPECULAR 1
#endif

uniform sampler2D texture;
uniform sampler2D shadowtex0;
uniform int worldTime;
uniform float rainStrength;
uniform float wetness;

varying vec2 uv;
varying vec4 col;
varying vec3 norm;
varying float bl;
varying float sl;
varying vec4 shadowPos;

// SHADOW_QUALITY 0 = ปิด PCF ใช้ single tap (เร็วที่สุด)
// SHADOW_QUALITY 1 = 4-tap PCF (ค่าเริ่มต้น สมดุล)
// SHADOW_QUALITY 2 = 9-tap PCF (สวยสุด แต่หนักกว่า)
float getShadow(vec3 sp) {
    if (sp.x < 0.0 || sp.x > 1.0 || sp.y < 0.0 || sp.y > 1.0) return 1.0;

#if SHADOW_QUALITY == 0
    // Single sample — เร็วที่สุด
    return step(sp.z - 0.001, texture2D(shadowtex0, sp.xy).r);

#elif SHADOW_QUALITY == 2
    // 9-tap PCF — นุ่มที่สุด
    float shadow = 0.0;
    float texel = 1.0 / 1024.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 offset = vec2(float(x), float(y)) * texel;
            shadow += step(sp.z - 0.001, texture2D(shadowtex0, sp.xy + offset).r);
        }
    }
    return shadow / 9.0;

#else
    // 4-tap PCF (default)
    float shadow = 0.0;
    float texel = 1.0 / 1024.0;
    for (int x = -1; x <= 1; x += 2) {
        for (int y = -1; y <= 1; y += 2) {
            vec2 offset = vec2(float(x), float(y)) * texel;
            shadow += step(sp.z - 0.001, texture2D(shadowtex0, sp.xy + offset).r);
        }
    }
    return shadow * 0.25;
#endif
}

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

    float rainDarkness = rainStrength * 0.4 + wetness * 0.2;

    // ใช้ NIGHT_BRIGHTNESS setting แล้ว
    vec3 skyAmbDay   = vec3(0.50, 0.70, 1.00) * sl2 * 0.45 * DAY_BRIGHTNESS * (1.0 - rainDarkness);
    vec3 skyAmbNight = vec3(0.05, 0.05, 0.15) * sl2 * 0.25 * NIGHT_BRIGHTNESS;
    vec3 skyAmb = mix(skyAmbDay, skyAmbNight, nightFactor);

    vec3 torchColor = vec3(TORCH_COLOR_R, TORCH_COLOR_G, TORCH_COLOR_B);
    float torchMul = mix(0.60, TORCH_STRENGTH * 0.6, nightFactor);
    vec3 torchC = torchColor * (bl2 * torchMul);

    // Night floor ปรับให้มืดลงตาม NIGHT_BRIGHTNESS
    vec3 nightFloor = vec3(0.04, 0.04, 0.10) * nightFactor * NIGHT_BRIGHTNESS * 0.5;
    vec3 ambient = albedo.rgb * (skyAmb + torchC + vec3(0.03)) + albedo.rgb * nightFloor;

    vec3 sunCol;
    if (tod < 0.10)       sunCol = mix(vec3(0.60, 0.30, 0.10), vec3(1.00, 0.85, 0.50), tod / 0.10);
    else if (tod < 0.25)  sunCol = mix(vec3(1.00, 0.85, 0.50), vec3(1.00, 0.98, 0.90), (tod - 0.10) / 0.15);
    else if (tod < 0.45)  sunCol = vec3(1.00, 0.97, 0.85);
    else if (tod < 0.55)  sunCol = mix(vec3(1.00, 0.97, 0.85), vec3(0.40, 0.30, 0.20), (tod - 0.45) / 0.10);
    else if (tod < 0.75)  sunCol = mix(vec3(0.40, 0.30, 0.20), vec3(0.05, 0.05, 0.15), (tod - 0.55) / 0.20);
    else                  sunCol = vec3(0.05, 0.05, 0.15);

    float dirLight = max(dot(norm, normalize(vec3(0.55, 1.0, 0.4))), 0.0);
    float shadow = 1.0;
    vec3 diffuse;

#if ENABLE_DIRLIGHT == 1
    if (dayFactor > 0.01) {
        shadow = getShadow(shadowPos.xyz);
        shadow = mix(1.0, shadow, dayFactor * SHADOW_STRENGTH);
    }
    dirLight = dirLight * 0.6 + 0.4;
    diffuse = albedo.rgb * sunCol * dirLight * shadow * 1.3 * (1.0 - rainDarkness * 0.3);
#else
    dirLight = dirLight * 0.5 + 0.5;
    diffuse = albedo.rgb * sunCol * dirLight * 0.8 * (1.0 - rainDarkness * 0.3);
#endif

    float spec = 0.0;
#if ENABLE_SPECULAR == 1
    if (rainStrength > 0.01 || wetness > 0.01) {
        vec3 viewDir = normalize(-vec3(gl_ModelViewMatrix[3]));
        vec3 lightDir = normalize(vec3(0.55, 1.0, 0.4));
        vec3 halfDir = normalize(lightDir + viewDir);
        spec = pow(max(dot(norm, halfDir), 0.0), 32.0) * 0.4 * (rainStrength + wetness);
    }
#endif

    vec3 color = ambient + diffuse + vec3(spec) * sunCol * dayFactor;
    color *= 1.0 - rainDarkness;

    gl_FragData[0] = vec4(color, albedo.a);
    gl_FragData[1] = vec4(norm * 0.5 + 0.5, 1.0);
}
