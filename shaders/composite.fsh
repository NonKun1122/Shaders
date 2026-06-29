#version 120

// Iris option declarations
const int   ENABLE_FOG          = 1;    // [0 1]
const float FOG_DENSITY         = 0.5;  // [0.2 0.3 0.4 0.5 0.6 0.7 0.8]
const int   ENABLE_WATER_REFLECT = 1;   // [0 1]
const float WATER_REFLECT_STR   = 0.6;  // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
const float SHADOW_BIAS         = 0.0015; // [0.0005 0.001 0.0015 0.002 0.003 0.005]
const float SHADOW_DISTANCE     = 128.0;  // [64.0 96.0 128.0 160.0 192.0 256.0]
const float AMBIENT_STRENGTH    = 1.0;  // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3]
const float NIGHT_BRIGHTNESS    = 0.3;  // [0.1 0.2 0.3 0.4 0.5 0.6 0.7]
const float DAY_BRIGHTNESS      = 1.0;  // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2]

#ifndef ENABLE_FOG
#define ENABLE_FOG 1
#endif
#ifndef FOG_DENSITY
#define FOG_DENSITY 0.5
#endif
#ifndef ENABLE_WATER_REFLECT
#define ENABLE_WATER_REFLECT 1
#endif
#ifndef WATER_REFLECT_STR
#define WATER_REFLECT_STR 0.6
#endif
#ifndef SHADOW_BIAS
#define SHADOW_BIAS 0.0015
#endif
#ifndef SHADOW_DISTANCE
#define SHADOW_DISTANCE 128.0
#endif
#ifndef AMBIENT_STRENGTH
#define AMBIENT_STRENGTH 1.0
#endif
#ifndef NIGHT_BRIGHTNESS
#define NIGHT_BRIGHTNESS 0.3
#endif
#ifndef DAY_BRIGHTNESS
#define DAY_BRIGHTNESS 1.0
#endif

uniform sampler2D gcolor;       // color buffer
uniform sampler2D gnormal;      // normal buffer (MRT1)
uniform sampler2D depthtex0;    // depth
uniform sampler2D depthtex1;    // depth behind transparent (น้ำ)
uniform mat4  gbufferProjection;
uniform mat4  gbufferProjectionInverse;
uniform mat4  gbufferModelViewInverse;
uniform float near;
uniform float far;
uniform int   worldTime;
uniform float rainStrength;
uniform float wetness;
uniform vec3  cameraPosition;

varying vec2 uv;

// ── Depth Utils ──────────────────────────────────────────────
float linearDepth(float d) {
    return (2.0 * near) / (far + near - d * (far - near));
}

// NDC → view-space position
vec3 toViewPos(vec2 texcoord, float depth) {
    vec4 ndc  = vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * ndc;
    return view.xyz / view.w;
}

void main() {
    vec3  color    = texture2D(gcolor,   uv).rgb;
    vec3  normalRaw= texture2D(gnormal,  uv).rgb;
    float depth0   = texture2D(depthtex0, uv).r;  // depth ที่ surface แรก (รวมน้ำ)
    float depth1   = texture2D(depthtex1, uv).r;  // depth หลังน้ำ (พื้นท้องน้ำ)

    float tod = mod(float(worldTime), 24000.0) / 24000.0;

    float dayFactor;
    if      (tod < 0.45) dayFactor = 1.0;
    else if (tod < 0.55) dayFactor = 1.0 - smoothstep(0.45, 0.55, tod);
    else if (tod > 0.95) dayFactor = smoothstep(0.95, 1.0, tod);
    else                 dayFactor = 0.0;
    float nightFactor = 1.0 - dayFactor;

    float rainDark = rainStrength * 0.3 + wetness * 0.15;

    // ── Water Reflection ─────────────────────────────────────
    // ตรวจว่า pixel นี้เป็น "ผิวน้ำ" หรือเปล่า:
    // depth0 < depth1 หมายความว่ามีบางอย่างโปร่งใสอยู่ด้านหน้า (น้ำ)
    // และ normal ชี้ขึ้น (y > 0.6 หลัง decode) = ผิวน้ำแนวนอน
    bool isWaterSurface = false;
    vec3 waterRefl = vec3(0.0);

#if ENABLE_WATER_REFLECT == 1
    if (depth0 < 1.0 && depth1 < 1.0) {
        // decode normal จาก [0,1] → [-1,1]
        vec3 n = normalize(normalRaw * 2.0 - 1.0);

        // ผิวน้ำ: normal ชี้ขึ้นมาก (y > 0.5) และ depth0 < depth1
        if (n.y > 0.45 && depth0 < depth1 - 0.001) {
            isWaterSurface = true;

            // ── Screen-Space Reflection (SSR) ────────────────
            // view-space position ของผิวน้ำ
            vec3 viewPos = toViewPos(uv, depth0);
            vec3 viewNorm= normalize((mat3(gbufferProjection) * n));  // approx

            // view direction (จากกล้องมายัง fragment)
            vec3 viewDir  = normalize(viewPos);
            // reflection direction ใน view-space
            vec3 reflDir  = reflect(viewDir, n);

            // march: เดินตาม reflection ray ใน screen space
            vec2  reflUV    = uv;
            vec3  reflColor = vec3(0.0);
            float reflFound = 0.0;
            float stepSize  = 0.015;

            for (int i = 1; i <= 12; i++) {
                float fi      = float(i);
                // project reflection ray กลับเป็น screen UV
                vec3  sampleView = viewPos + reflDir * fi * stepSize * (1.0 + fi * 0.15);
                vec4  sampleClip = gbufferProjection * vec4(sampleView, 1.0);
                vec2  sampleUV   = sampleClip.xy / sampleClip.w * 0.5 + 0.5;

                // อยู่ในจอ?
                if (sampleUV.x < 0.01 || sampleUV.x > 0.99 ||
                    sampleUV.y < 0.01 || sampleUV.y > 0.99) break;

                float sampleDepth = texture2D(depthtex0, sampleUV).r;
                vec3  samplePos   = toViewPos(sampleUV, sampleDepth);

                // ถ้า ray ชนกับ geometry
                float diff = sampleView.z - samplePos.z;
                if (diff > 0.05 && diff < 2.5) {
                    reflColor = texture2D(gcolor, sampleUV).rgb;
                    reflFound = 1.0;
                    break;
                }
            }

            // ── Sky fallback เมื่อ SSR ไม่เจอ geometry ──────
            // สีท้องฟ้าตาม tod เป็น reflection fallback
            float goldenFactor = 0.0;
            if      (tod < 0.06)                goldenFactor = smoothstep(0.0,  0.06,  tod);
            else if (tod < 0.12)                goldenFactor = 1.0 - smoothstep(0.06, 0.12, tod);
            else if (tod > 0.40 && tod < 0.48) goldenFactor = smoothstep(0.40, 0.48, tod);
            else if (tod > 0.48 && tod < 0.55) goldenFactor = 1.0 - smoothstep(0.48, 0.55, tod);

            vec3 skyTop = mix(
                mix(vec3(0.20, 0.40, 1.00), vec3(0.60, 0.20, 0.05), goldenFactor),
                vec3(0.00, 0.00, 0.35),
                nightFactor
            );
            vec3 skyHorizon = mix(
                mix(vec3(0.60, 1.00, 1.00), vec3(1.00, 0.55, 0.10), goldenFactor),
                vec3(0.00, 0.00, 0.05),
                nightFactor
            );
            // reflect direction y: บวก = ท้องฟ้า, ลบ = ขอบฟ้า
            float skyH     = clamp(reflDir.y * 2.0, 0.0, 1.0);
            vec3  skyRefl  = mix(skyHorizon, skyTop, skyH) * mix(1.0, NIGHT_BRIGHTNESS, nightFactor);

            // เพิ่ม sun/moon glint บนน้ำ
            vec3 lightDir = mix(normalize(vec3(0.55, 1.0, 0.4)), normalize(vec3(-0.4, 0.9, -0.3)), nightFactor);
            float glint   = pow(max(dot(reflDir, lightDir), 0.0), 60.0) * mix(2.5, 0.8, nightFactor);
            vec3 glintCol = mix(vec3(1.00, 0.90, 0.70), vec3(0.80, 0.85, 1.00), nightFactor);
            skyRefl += glintCol * glint;

            // blend SSR กับ sky fallback
            reflColor = mix(skyRefl, reflColor, reflFound);

            // ── Fresnel ──────────────────────────────────────
            float cosV   = abs(dot(viewDir, n));
            float fresnel = pow(1.0 - cosV, 3.0) * 0.85 + 0.05;  // 0.05–0.90

            waterRefl = reflColor * WATER_REFLECT_STR;

            // Mix reflection เข้ากับสีน้ำเดิม
            color = mix(color, waterRefl, fresnel * WATER_REFLECT_STR);
        }
    }
#endif

    // ── Fog ──────────────────────────────────────────────────
#if ENABLE_FOG == 1
    if (depth0 < 1.0) {
        float linD = linearDepth(depth0);

        vec3 fogDayEarly = vec3(0.65, 1.00, 1.00) * DAY_BRIGHTNESS * (1.0 - rainDark);
        vec3 fogNight    = vec3(0.01, 0.01, 0.05) * NIGHT_BRIGHTNESS;

        vec3 fogCol;
        if (tod < 0.06) {
            float t = smoothstep(0.0, 0.06, tod);
            fogCol = mix(vec3(0.60, 0.20, 0.05), mix(vec3(1.00, 0.55, 0.10), fogDayEarly, t), t);
        } else if (tod < 0.12) {
            float t = smoothstep(0.06, 0.12, tod);
            fogCol = mix(mix(vec3(1.00, 0.55, 0.10), fogDayEarly, t), fogDayEarly, t);
        } else if (tod < 0.40) {
            fogCol = fogDayEarly;
        } else if (tod < 0.48) {
            float t = smoothstep(0.40, 0.48, tod);
            fogCol = mix(fogDayEarly, vec3(1.00, 0.55, 0.10), t);
        } else if (tod < 0.55) {
            float t = smoothstep(0.48, 0.55, tod);
            fogCol = mix(vec3(1.00, 0.55, 0.10), fogNight, t);
        } else {
            fogCol = fogNight;
        }

        float fogStart  = 0.7;
        float fogFactor = clamp((linD - fogStart) * 2.0, 0.0, FOG_DENSITY);
        color = mix(color, fogCol, fogFactor);
    }
#endif

    // ── Post-process ─────────────────────────────────────────
    color *= AMBIENT_STRENGTH;

    float rainDarkness = rainStrength * 0.3 + wetness * 0.15;
    color *= 1.0 - rainDarkness * 0.2;

    // Saturation boost เล็กน้อย
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, 1.15);

    // Tone mapping เบาๆ (ป้องกัน overexposure)
    color = color / (color + 0.4) * 1.4;

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
