#version 120

// Iris option declarations
const int   ENABLE_DIRLIGHT  = 1;   // [0 1]
const float DAY_BRIGHTNESS   = 1.0; // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2]
const float NIGHT_BRIGHTNESS = 0.3; // [0.1 0.2 0.3 0.4 0.5 0.6 0.7]
const float TORCH_COLOR_R    = 1.0; // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2]
const float TORCH_COLOR_G    = 0.7; // [0.2 0.3 0.4 0.5 0.6 0.7 0.8]
const float TORCH_COLOR_B    = 0.4; // [0.0 0.1 0.2 0.3 0.4 0.5]
const float TORCH_STRENGTH   = 2.5; // [1.0 1.5 2.0 2.5 3.0 3.5 4.0]
const int   SHADOW_QUALITY   = 1;   // [0 1 2]
const float SHADOW_STRENGTH  = 0.5; // [0.2 0.3 0.4 0.5 0.6 0.7 0.8]
const float SHADOW_BIAS      = 0.0015; // [0.0005 0.001 0.0015 0.002 0.003 0.005]
const int   ENABLE_SPECULAR  = 1;   // [0 1]
const int   ENABLE_WIND      = 1;   // [0 1]
const float WIND_SPEED       = 1.5; // [0.5 1.0 1.5 2.0 2.5 3.0]

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
#ifndef SHADOW_QUALITY
#define SHADOW_QUALITY 1
#endif
#ifndef ENABLE_SPECULAR
#define ENABLE_SPECULAR 1
#endif

uniform sampler2D texture;
uniform sampler2D shadowtex0;
uniform int   worldTime;
uniform float rainStrength;
uniform float wetness;

varying vec2  uv;
varying vec4  col;
varying vec3  norm;
varying float bl;
varying float sl;
varying vec4  shadowPos;

// ============================================================
//  getShadow — slope-scale bias
// ============================================================
float getShadow(vec3 sp, vec3 n) {
    if (sp.x < 0.001 || sp.x > 0.999 || sp.y < 0.001 || sp.y > 0.999) return 1.0;
    if (sp.z >= 1.0) return 1.0;

    vec3  lightDir = normalize(vec3(0.55, 1.0, 0.4));
    float cosTheta = clamp(dot(n, lightDir), 0.0, 1.0);
    float bias     = mix(SHADOW_BIAS * 3.0, SHADOW_BIAS * 0.4, cosTheta);

#if SHADOW_QUALITY == 0
    return step(sp.z - bias, texture2D(shadowtex0, sp.xy).r);
#elif SHADOW_QUALITY == 2
    float shadow = 0.0;
    float texel  = 1.0 / 2048.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            shadow += step(sp.z - bias,
                           texture2D(shadowtex0, sp.xy + vec2(float(x), float(y)) * texel).r);
        }
    }
    return shadow / 9.0;
#else
    float shadow = 0.0;
    float texel  = 1.0 / 2048.0;
    for (int x = -1; x <= 1; x += 2) {
        for (int y = -1; y <= 1; y += 2) {
            shadow += step(sp.z - bias,
                           texture2D(shadowtex0, sp.xy + vec2(float(x), float(y)) * texel).r);
        }
    }
    return shadow * 0.25;
#endif
}

void main() {
    vec4 albedo = texture2D(texture, uv) * col;
    if (albedo.a < 0.1) discard;

    // ── Time of Day ─────────────────────────────────────────
    float tod = mod(float(worldTime), 24000.0) / 24000.0;

    float dayFactor;
    if      (tod < 0.45) dayFactor = 1.0;
    else if (tod < 0.55) dayFactor = 1.0 - smoothstep(0.45, 0.55, tod);
    else if (tod > 0.95) dayFactor = smoothstep(0.95, 1.0, tod);
    else                 dayFactor = 0.0;
    float nightFactor = 1.0 - dayFactor;

    // Sunrise (0.0–0.12) / Sunset (0.40–0.55) factor
    float sunriseFactor = 0.0;
    if      (tod < 0.06)  sunriseFactor = smoothstep(0.0,  0.06,  tod);
    else if (tod < 0.12)  sunriseFactor = 1.0 - smoothstep(0.06, 0.12, tod);

    float sunsetFactor = 0.0;
    if      (tod > 0.40 && tod < 0.48) sunsetFactor = smoothstep(0.40, 0.48, tod);
    else if (tod > 0.48 && tod < 0.55) sunsetFactor = 1.0 - smoothstep(0.48, 0.55, tod);

    float goldenFactor = max(sunriseFactor, sunsetFactor); // 0=กลางวัน/กลางคืน, 1=ช่วงทอง

    float sl2 = sl * sl;
    float bl2 = bl * bl;
    float rainDarkness = rainStrength * 0.4 + wetness * 0.2;

    // ── Sky Ambient ─────────────────────────────────────────
    // กลางคืนสว่างขึ้น: 0.20 แทน 0.15 + fill แสงจันทร์
    vec3 skyAmbDay   = vec3(0.70, 0.85, 1.00) * sl2 * 0.6  * DAY_BRIGHTNESS;
    vec3 skyAmbNight = vec3(0.05, 0.07, 0.18) * sl2 * 0.30 * NIGHT_BRIGHTNESS;
    // แสงจันทร์: สีขาว-น้ำเงินเย็น เพิ่ม ambient กลางคืนที่มี skylight
    vec3 moonAmb     = vec3(0.15, 0.18, 0.30) * sl2 * nightFactor * 0.25;
    vec3 skyAmb      = mix(skyAmbDay, skyAmbNight, nightFactor) + moonAmb;

    // ── Torch / Block Light ──────────────────────────────────
    // อมส้มอมขาว: R=1.0, G=0.75, B=0.45  (ลด R,เพิ่ม G,B จากเดิม 1.0/0.5/0.1)
    vec3  torchColor = vec3(TORCH_COLOR_R, TORCH_COLOR_G, TORCH_COLOR_B);
    float torchMul   = mix(0.5, TORCH_STRENGTH * 0.5, nightFactor);
    vec3  torchC     = torchColor * (bl2 * torchMul);

    // fill กลางคืนต่ำๆ (ให้ไม่มืดสนิทเมื่อไม่มีไฟ)
    vec3 nightFill = vec3(0.03, 0.04, 0.07) * nightFactor;

    vec3 ambient = albedo.rgb * (skyAmb + torchC + vec3(0.015) + nightFill);

    // ── Sun Color ────────────────────────────────────────────
    // ช่วงพระอาทิตย์ขึ้น/ตก: ส้ม-เหลือง (#FF8800 / #FFCC00)
    vec3 sunColDay      = vec3(1.00, 0.98, 0.92);   // กลางวัน: ขาวนวล
    vec3 sunColGolden   = vec3(1.00, 0.60, 0.10);   // พระอาทิตย์ขึ้น/ตก: ส้มลึก
    vec3 sunColNight    = vec3(0.20, 0.22, 0.40);   // กลางคืน: แสงจันทร์ขาว-น้ำเงิน

    vec3 sunCol;
    if (tod < 0.06) {
        // Sunrise เริ่ม: ส้มเข้มแดง → ส้มเหลือง
        float t = tod / 0.06;
        sunCol = mix(vec3(0.90, 0.30, 0.05), sunColGolden, t);
    } else if (tod < 0.12) {
        // Sunrise ปลาย: ส้มเหลือง → กลางวัน
        float t = (tod - 0.06) / 0.06;
        sunCol = mix(sunColGolden, sunColDay, t);
    } else if (tod < 0.40) {
        // กลางวันปกติ
        sunCol = sunColDay;
    } else if (tod < 0.48) {
        // Sunset เริ่ม: กลางวัน → ส้มเหลือง
        float t = (tod - 0.40) / 0.08;
        sunCol = mix(sunColDay, sunColGolden, t);
    } else if (tod < 0.55) {
        // Sunset ปลาย: ส้มเหลือง → กลางคืน
        float t = (tod - 0.48) / 0.07;
        sunCol = mix(sunColGolden, sunColNight, t);
    } else if (tod < 0.75) {
        // เย็น/ดึก: fade เข้ากลางคืน
        float t = (tod - 0.55) / 0.20;
        sunCol = mix(sunColNight, vec3(0.15, 0.17, 0.35), t);
    } else {
        sunCol = vec3(0.15, 0.17, 0.35); // กลางคืนเต็ม: แสงจันทร์
    }

    // ── Moon shadow direction ─────────────────────────────────
    // กลางวัน: แสงดวงอาทิตย์ด้านบนขวา, กลางคืน: แสงจันทร์ด้านบนซ้าย
    vec3 lightDir = mix(
        normalize(vec3( 0.55, 1.0,  0.4)),   // ดวงอาทิตย์
        normalize(vec3(-0.40, 0.9, -0.3)),   // ดวงจันทร์
        nightFactor
    );

    // ── Diffuse + Shadow ─────────────────────────────────────
    vec3  normL  = normalize(norm);
    float shadow = 1.0;
    vec3  diffuse;

#if ENABLE_DIRLIGHT == 1
    float dirLight = max(dot(normL, lightDir), 0.0);
    dirLight = dirLight * 0.7 + 0.3;

    // เงา: กลางวันตามปกติ, กลางคืนทำเงาจากแสงจันทร์ (อ่อนกว่า)
    float shadowStrengthFinal = mix(SHADOW_STRENGTH, SHADOW_STRENGTH * 0.6, nightFactor);
    shadow = getShadow(shadowPos.xyz, normL);
    shadow = mix(1.0, shadow, max(dayFactor, nightFactor * 0.5) * shadowStrengthFinal);

    // กลางวัน diffuse เต็ม, กลางคืน diffuse จากแสงจันทร์ (ลดลง)
    float diffuseMul = mix(1.2, 0.35, nightFactor);
    diffuse = albedo.rgb * sunCol * dirLight * shadow * diffuseMul * (1.0 - rainDarkness * 0.2);
#else
    float dirLight = max(dot(normL, lightDir), 0.0);
    dirLight = dirLight * 0.6 + 0.4;
    diffuse  = albedo.rgb * sunCol * dirLight * mix(0.9, 0.3, nightFactor);
#endif

    // ── Specular (wet surface) ───────────────────────────────
    float spec = 0.0;
#if ENABLE_SPECULAR == 1
    if (rainStrength > 0.01 || wetness > 0.01) {
        vec3 viewDir  = normalize(-vec3(gl_ModelViewMatrix[3]));
        vec3 halfDir  = normalize(lightDir + viewDir);
        spec = pow(max(dot(normL, halfDir), 0.0), 32.0) * 0.3 * (rainStrength + wetness);
    }
#endif

    vec3 color = ambient + diffuse + vec3(spec) * sunCol;
    color *= 1.0 - rainDarkness * 0.3;

    gl_FragData[0] = vec4(color, albedo.a);
    gl_FragData[1] = vec4(normL * 0.5 + 0.5, 1.0);
}
