#version 120

// Iris option declarations
const float WAVE_SPEED  = 1.0; // [0.5 1.0 1.5 2.0 2.5]
const float WAVE_HEIGHT = 0.06; // [0.02 0.04 0.06 0.08 0.10 0.12]

#ifndef DAY_BRIGHTNESS
#define DAY_BRIGHTNESS 1.0
#endif
#ifndef NIGHT_BRIGHTNESS
#define NIGHT_BRIGHTNESS 0.3
#endif
#ifndef SHADOW_STRENGTH
#define SHADOW_STRENGTH 0.5
#endif
#ifndef ENABLE_DIRLIGHT
#define ENABLE_DIRLIGHT 1
#endif

uniform sampler2D texture;
uniform sampler2D shadowtex0;
uniform int   worldTime;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;

varying vec2  uv;
varying vec4  col;
varying vec3  norm;
varying vec3  viewDir;
varying float bl;
varying float sl;
varying vec4  shadowPos;
varying float isWater;

float getShadow(vec3 sp, float bias) {
    if (sp.x < 0.001 || sp.x > 0.999 || sp.y < 0.001 || sp.y > 0.999) return 1.0;
    if (sp.z >= 1.0) return 1.0;
    // 4-tap PCF
    float shadow = 0.0;
    float texel  = 1.0 / 2048.0;
    for (int x = -1; x <= 1; x += 2)
        for (int y = -1; y <= 1; y += 2)
            shadow += step(sp.z - bias, texture2D(shadowtex0, sp.xy + vec2(float(x), float(y)) * texel).r);
    return shadow * 0.25;
}

void main() {
    vec4 albedo = texture2D(texture, uv) * col;

    // ── Time of Day ─────────────────────────────────────────
    float tod = mod(float(worldTime), 24000.0) / 24000.0;
    float dayFactor;
    if      (tod < 0.45) dayFactor = 1.0;
    else if (tod < 0.55) dayFactor = 1.0 - smoothstep(0.45, 0.55, tod);
    else if (tod > 0.95) dayFactor = smoothstep(0.95, 1.0, tod);
    else                 dayFactor = 0.0;
    float nightFactor = 1.0 - dayFactor;

    // Sunrise/Sunset golden factor
    float goldenFactor = 0.0;
    if (tod > 0.40 && tod < 0.48)       goldenFactor = smoothstep(0.40, 0.48, tod);
    else if (tod > 0.48 && tod < 0.55)  goldenFactor = 1.0 - smoothstep(0.48, 0.55, tod);
    else if (tod < 0.06)                 goldenFactor = smoothstep(0.0,  0.06,  tod);
    else if (tod < 0.12)                 goldenFactor = 1.0 - smoothstep(0.06, 0.12, tod);

    float sl2 = sl * sl;
    float bl2 = bl * bl;

    // ── Sun/Moon direction ────────────────────────────────────
    vec3 lightDir = mix(
        normalize(vec3( 0.55, 1.0,  0.4)),
        normalize(vec3(-0.40, 0.9, -0.3)),
        nightFactor
    );

    // ── Sun/Moon Color ────────────────────────────────────────
    vec3 sunColDay    = vec3(1.00, 0.98, 0.92);
    vec3 sunColGolden = vec3(1.00, 0.60, 0.10);
    vec3 sunColNight  = vec3(0.20, 0.22, 0.40);
    vec3 sunCol = mix(mix(sunColDay, sunColGolden, goldenFactor), sunColNight, nightFactor);

    // ── Shadow ───────────────────────────────────────────────
    float shadow = 1.0;
    float shadowStrength = mix(SHADOW_STRENGTH, SHADOW_STRENGTH * 0.6, nightFactor);
    shadow = getShadow(shadowPos.xyz, 0.001);
    shadow = mix(1.0, shadow, max(dayFactor, nightFactor * 0.4) * shadowStrength);

    // ── Normal + Reflection ──────────────────────────────────
    vec3  normL    = normalize(norm);
    vec3  viewN    = normalize(viewDir);
    vec3  reflected = reflect(viewN, normL);   // vector สะท้อน

    // Fresnel — มุมตื้นสะท้อนสูง, มุมชันโปร่งใส
    float cosV    = max(dot(-viewN, normL), 0.0);
    float fresnel = pow(1.0 - cosV, 4.0);       // 0 = มองตรง, 1 = มองเฉียง

    // ── Water Color ──────────────────────────────────────────
    // กลางวัน: น้ำเงินใส (#1A8CFF), กลางคืน: น้ำเงินเข้มจันทร์
    vec3 waterDeepDay   = vec3(0.05, 0.25, 0.75);
    vec3 waterShallDay  = vec3(0.25, 0.65, 0.95);
    vec3 waterDeepNight = vec3(0.02, 0.03, 0.18);
    vec3 waterShallNight= vec3(0.05, 0.08, 0.30);

    vec3 waterDeep  = mix(waterDeepDay,  waterDeepNight,  nightFactor);
    vec3 waterShall = mix(waterShallDay, waterShallNight, nightFactor);

    // Depth blend: ตื้น=ใส, ลึก=เข้ม (ใช้ alpha ของ texture เป็น approximation)
    float depth   = clamp(1.0 - albedo.a * 1.5, 0.0, 1.0);
    vec3  waterCol = mix(waterShall, waterDeep, depth);

    // ── Reflection color ─────────────────────────────────────
    // Approximate sky reflection: สีท้องฟ้า mix ด้วย sunCol ตาม direction
    vec3 skyReflDay   = mix(vec3(0.60, 1.00, 1.00), vec3(0.20, 0.40, 1.00), clamp(reflected.y, 0.0, 1.0));
    vec3 skyReflNight = mix(vec3(0.00, 0.00, 0.10), vec3(0.05, 0.06, 0.20), clamp(reflected.y, 0.0, 1.0));
    vec3 skyRefl      = mix(skyReflDay, skyReflNight, nightFactor);

    // เพิ่ม specular จากดวงอาทิตย์/จันทร์บนผิวน้ำ (sun glint)
    float sunGlint = pow(max(dot(reflected, lightDir), 0.0), 80.0);
    float glintMul = mix(3.0, 1.0, nightFactor);  // กลางวัน glint สว่างกว่า
    skyRefl += sunCol * sunGlint * glintMul;

    // ── Final Water Color ─────────────────────────────────────
    vec3 color;
    if (isWater > 0.5) {
        // ambient: skylight + torch + moonlight
        vec3 skyAmbDay   = vec3(0.40, 0.65, 1.00) * sl2 * 0.40 * DAY_BRIGHTNESS;
        vec3 skyAmbNight = vec3(0.05, 0.07, 0.18) * sl2 * 0.20 * NIGHT_BRIGHTNESS;
        vec3 moonAmb     = vec3(0.15, 0.20, 0.35) * sl2 * nightFactor * 0.25;
        vec3 torchC      = vec3(1.0, 0.7, 0.4) * (bl2 * mix(0.3, 1.0, nightFactor));
        vec3 waterAmb    = waterCol * (mix(skyAmbDay, skyAmbNight, nightFactor) + moonAmb + torchC + 0.01);

        // diffuse แสง
        float dirLight = max(dot(normL, lightDir), 0.0) * 0.6 + 0.4;
        vec3  waterDiff = waterCol * sunCol * dirLight * shadow * mix(1.0, 0.4, nightFactor);

        // Fresnel: blend ระหว่างน้ำโปร่งใสกับ reflection ท้องฟ้า
        vec3  waterBase = waterAmb + waterDiff;
        color = mix(waterBase, skyRefl, fresnel * 0.75);

        // Rain ripple darkening
        float rainDark = rainStrength * 0.3 + wetness * 0.1;
        color *= 1.0 - rainDark * 0.2;

    } else {
        // กระจก / บล็อกใส อื่นๆ
        vec3 skyAmb = mix(
            vec3(0.40, 0.65, 1.00) * sl2 * 0.5,
            vec3(0.05, 0.07, 0.18) * sl2 * 0.2,
            nightFactor
        );
        vec3 torchC = vec3(1.0, 0.7, 0.4) * bl2 * 0.5;
        color = albedo.rgb * (skyAmb + torchC + 0.02) + albedo.rgb * shadow * 0.6;
    }

    // ── Alpha ─────────────────────────────────────────────────
    // น้ำ: ใสขึ้น (0.45–0.65), Fresnel ด้านเอียงทึบขึ้น
    float alpha;
    if (isWater > 0.5) {
        float baseAlpha = mix(0.45, 0.65, fresnel);  // ใสขึ้นจาก 0.65 เดิม
        alpha = baseAlpha;
    } else {
        alpha = albedo.a;
    }

    gl_FragData[0] = vec4(color, alpha);
    gl_FragData[1] = vec4(normL * 0.5 + 0.5, 1.0);
}
