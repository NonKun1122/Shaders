#version 120

// Iris option declarations
const float NIGHT_BRIGHTNESS = 0.3; // [0.1 0.2 0.3 0.4 0.5 0.6 0.7]

uniform int   worldTime;
uniform float frameTimeCounter;

varying vec4 col;
varying vec3 dir;

#ifndef NIGHT_BRIGHTNESS
#define NIGHT_BRIGHTNESS 0.3
#endif

float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

void main() {
    float tod = mod(float(worldTime), 24000.0) / 24000.0;
    float h   = clamp(normalize(dir).y, 0.0, 1.0);

    // Day/Night factor
    float dayFactor;
    if      (tod < 0.45) dayFactor = 1.0;
    else if (tod < 0.55) dayFactor = 1.0 - smoothstep(0.45, 0.55, tod);
    else if (tod > 0.95) dayFactor = smoothstep(0.95, 1.0, tod);
    else                 dayFactor = 0.0;
    float nightFactor = 1.0 - dayFactor;

    // ── Sky Gradient ────────────────────────────────────────
    vec3 zenith, horizon;

    if (tod < 0.06) {
        // Sunrise เริ่ม: กลางคืน → ส้มแดง
        float t = smoothstep(0.0, 0.06, tod);
        zenith  = mix(vec3(0.000, 0.000, 0.600), vec3(0.60, 0.20, 0.05), t);
        horizon = mix(vec3(0.000, 0.000, 0.000), vec3(1.00, 0.50, 0.10), t);
    } else if (tod < 0.12) {
        // Sunrise สว่าง: ส้มแดง → ส้มทอง → ฟ้า
        float t = smoothstep(0.06, 0.12, tod);
        zenith  = mix(vec3(0.60, 0.20, 0.05), vec3(0.20, 0.40, 1.00), t);
        horizon = mix(vec3(1.00, 0.50, 0.10), vec3(0.60, 1.00, 1.00), t);
    } else if (tod < 0.40) {
        // กลางวัน: #3366FF บน → #99FFFF ล่าง
        zenith  = vec3(0.200, 0.400, 1.000);
        horizon = vec3(0.600, 1.000, 1.000);
    } else if (tod < 0.48) {
        // Sunset เริ่ม: ฟ้า → ส้มทอง
        float t = smoothstep(0.40, 0.48, tod);
        zenith  = mix(vec3(0.200, 0.400, 1.000), vec3(0.50, 0.15, 0.02), t);
        horizon = mix(vec3(0.600, 1.000, 1.000), vec3(1.00, 0.55, 0.10), t);
    } else if (tod < 0.55) {
        // Sunset ปลาย: ส้มทอง → น้ำเงินเข้ม
        float t = smoothstep(0.48, 0.55, tod);
        zenith  = mix(vec3(0.50, 0.15, 0.02), vec3(0.000, 0.000, 0.600), t);
        horizon = mix(vec3(1.00, 0.55, 0.10), vec3(0.000, 0.000, 0.000), t);
    } else if (tod < 0.75) {
        // Evening fade to night
        float t = smoothstep(0.55, 0.75, tod);
        zenith  = mix(vec3(0.000, 0.000, 0.600), vec3(0.000, 0.000, 0.600), t);
        horizon = mix(vec3(0.000, 0.000, 0.000), vec3(0.000, 0.000, 0.000), t);
    } else {
        // กลางคืน: #000099 บน → #000000 ล่าง
        zenith  = vec3(0.000, 0.000, 0.600);
        horizon = vec3(0.000, 0.000, 0.000);
    }

    vec3 sky = mix(horizon, zenith, pow(h, 0.5));

    // Night brightness scale
    sky *= mix(1.0, NIGHT_BRIGHTNESS, nightFactor);

    // ── Stars ───────────────────────────────────────────────
    if (nightFactor > 0.01) {
        float starLuma = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
        float starMask = pow(clamp((starLuma - 0.15) * 2.0, 0.0, 1.0), 2.0);

        if (starMask > 0.001) {
            vec2  starSeed = floor(normalize(dir).xz * 128.0);
            float phase    = hash(starSeed) * 6.2832;
            float speed    = 0.8 + hash(starSeed + 1.0) * 1.2;
            float twinkle  = sin(frameTimeCounter * speed + phase) * 0.35
                           + sin(frameTimeCounter * speed * 1.7 + phase * 0.6) * 0.15
                           + 0.5;
            twinkle = clamp(twinkle, 0.0, 1.0);

            float colorTone = hash(starSeed + 3.0);
            vec3 starColor  = mix(vec3(1.0, 0.95, 0.85), vec3(0.85, 0.92, 1.00), colorTone);

            sky += starColor * starMask * twinkle * 0.9 * nightFactor;
        }
    }

    gl_FragColor = vec4(clamp(sky, 0.0, 1.0), 1.0);
}
