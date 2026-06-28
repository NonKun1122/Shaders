#version 120
uniform int worldTime;
varying vec4 col;
varying vec3 dir;

#ifndef NIGHT_BRIGHTNESS
#define NIGHT_BRIGHTNESS 0.3
#endif

void main() {
    float tod = mod(float(worldTime), 24000.0) / 24000.0;
    float h   = clamp(normalize(dir).y, 0.0, 1.0);

    float dayFactor;
    if (tod < 0.45) dayFactor = 1.0;
    else if (tod < 0.55) dayFactor = 1.0 - smoothstep(0.45, 0.55, tod);
    else if (tod > 0.95) dayFactor = smoothstep(0.95, 1.0, tod);
    else dayFactor = 0.0;

    vec3 zenith, horizon;

    if (tod < 0.10) {
        // Sunrise: dim purple → cyan
        float t = smoothstep(0.0, 0.10, tod);
        zenith  = mix(vec3(0.10, 0.08, 0.20), vec3(0.10, 0.40, 1.00), t);
        horizon = mix(vec3(0.20, 0.10, 0.08), vec3(0.60, 1.00, 1.00), t);
    } else if (tod < 0.25) {
        // Morning
        zenith  = mix(vec3(0.10, 0.40, 1.00), vec3(0.20, 0.50, 1.00), smoothstep(0.10, 0.25, tod));
        horizon = mix(vec3(0.60, 1.00, 1.00), vec3(0.70, 1.00, 1.00), smoothstep(0.10, 0.25, tod));
    } else if (tod < 0.45) {
        // DAY: bright blue
        zenith  = vec3(0.20, 0.50, 1.00);
        horizon = vec3(0.70, 1.00, 1.00);
    } else if (tod < 0.55) {
        // Sunset: NO ORANGE - go straight to dark blue
        float t = smoothstep(0.45, 0.55, tod);
        zenith  = mix(vec3(0.20, 0.50, 1.00), vec3(0.02, 0.02, 0.12), t);
        horizon = mix(vec3(0.70, 1.00, 1.00), vec3(0.01, 0.01, 0.05), t);
    } else if (tod < 0.75) {
        // Evening: fade to night
        float t = smoothstep(0.55, 0.75, tod);
        zenith  = mix(vec3(0.02, 0.02, 0.12), vec3(0.00, 0.00, 0.05), t);
        horizon = mix(vec3(0.01, 0.01, 0.05), vec3(0.00, 0.00, 0.01), t);
    } else {
        // NIGHT: dark blue to black
        zenith  = vec3(0.00, 0.00, 0.05);   // #000005
        horizon = vec3(0.00, 0.00, 0.00);   // #000000
    }

    // Mix sky from horizon to zenith
    vec3 sky = mix(horizon, zenith, pow(h, 0.45));

    // Apply NIGHT_BRIGHTNESS only at night
    sky *= mix(1.0, NIGHT_BRIGHTNESS, 1.0 - dayFactor);

    // Stars at night - bright and visible
    float starLuma = dot(col.rgb, vec3(0.3));
    float starFactor = clamp((starLuma - 0.3) * 3.0, 0.0, 1.5) * (1.0 - dayFactor);

    gl_FragColor = vec4(sky + col.rgb * starFactor, 1.0);
}
