#version 120

attribute vec4 mc_Entity;

uniform float frameTimeCounter;
uniform vec3  cameraPosition;
uniform mat4  shadowModelView;
uniform mat4  shadowProjection;
uniform mat4  gbufferModelViewInverse;

varying vec2  uv;
varying vec4  col;
varying vec3  norm;
varying float bl;
varying float sl;
varying vec4  shadowPos;

#ifndef WIND_SPEED
#define WIND_SPEED 1.5
#endif
#ifndef ENABLE_WIND
#define ENABLE_WIND 1
#endif

// ============================================================
//  shadowDistort — ต้องตรงกับ shadow.vsh ทุกประการ
//  shadow.vsh: clipPos.xy = shadowDistort(clipPos.xy)
//              ก่อน perspective divide (w ≠ 1)
//  ดังนั้นเราต้อง distort บน clip.xy/clip.w (NDC จริง)
//  แล้ว rescale กลับ → เทียบเท่า distort ก่อน divide
// ============================================================
vec2 shadowDistort(vec2 pos) {
    float dist = length(pos);
    return pos / (dist + 0.1);
}

void main() {
    vec4 position = gl_Vertex;

    // ── Wind Animation ─────────────────────────────────────
#if ENABLE_WIND == 1
    float id = mc_Entity.x;
    bool isLeaf  = (id == 18.0)  || (id == 161.0);
    bool isGrass = (id == 31.0)  || (id == 32.0) || (id == 37.0) || (id == 38.0);
    bool isPlant = (id == 6.0)   || (id == 59.0) || (id == 83.0) || (id == 175.0)
                || (id == 104.0) || (id == 105.0);
    bool isVine  = (id == 106.0);

    if (isLeaf || isGrass || isPlant || isVine) {
        float worldX = position.x + cameraPosition.x;
        float worldZ = position.z + cameraPosition.z;
        float wind = sin(frameTimeCounter * 2.0 * WIND_SPEED + worldX * 0.5 + worldZ * 0.3);
        wind += sin(frameTimeCounter * 1.3 * WIND_SPEED + worldX * 0.3 - worldZ * 0.5) * 0.5;
        float heightFactor = smoothstep(0.0, 0.7, fract(position.y));
        position.x += wind * 0.05 * heightFactor;
        position.z += wind * 0.03 * heightFactor;
    }
#endif

    gl_Position = gl_ModelViewProjectionMatrix * position;

    // ── Shadow Position Calculation ────────────────────────
    // 1. model-space → view-space
    vec4 viewPos  = gl_ModelViewMatrix * position;

    // 2. view-space → world-space
    vec4 worldPos = gbufferModelViewInverse * viewPos;

    // 3. world-space → shadow clip-space (w ≠ 1 ณ จุดนี้)
    vec4 shadowClip = shadowProjection * shadowModelView * worldPos;

    // 4. distort บน clip-space xy (ก่อน divide) — ตรงกับ shadow.vsh
    //    shadow.vsh ทำ: clipPos.xy = shadowDistort(clipPos.xy)  ← clip space
    shadowClip.xy = shadowDistort(shadowClip.xy);

    // 5. perspective divide → NDC [-1, 1]
    shadowClip.xyz /= shadowClip.w;

    // 6. NDC → texture coords [0, 1]  (ไม่ต้องทำ z*0.5 พิเศษ เพราะ shadow.vsh ก็ไม่ได้ทำ)
    shadowPos.xyz = shadowClip.xyz * 0.5 + 0.5;
    shadowPos.w   = 1.0;

    // ── Varyings ───────────────────────────────────────────
    uv   = gl_MultiTexCoord0.st;
    col  = gl_Color;
    norm = gl_NormalMatrix * gl_Normal;

    vec2 lm = gl_MultiTexCoord1.st / 256.0;
    bl = lm.x;
    sl = lm.y;
}
