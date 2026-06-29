#version 120

uniform float frameTimeCounter;
uniform vec3  cameraPosition;
uniform mat4  shadowModelView;
uniform mat4  shadowProjection;
uniform mat4  gbufferModelViewInverse;

attribute vec4 mc_Entity;

varying vec2  uv;
varying vec4  col;
varying vec3  norm;
varying vec3  viewDir;     // สำหรับ reflection
varying float bl;
varying float sl;
varying vec4  shadowPos;
varying float isWater;

#ifndef WAVE_SPEED
#define WAVE_SPEED 1.0
#endif
#ifndef WAVE_HEIGHT
#define WAVE_HEIGHT 0.06
#endif

vec2 shadowDistort(vec2 pos) {
    float dist = length(pos);
    return pos / (dist + 0.1);
}

void main() {
    vec4 position = gl_Vertex;

    isWater = ((mc_Entity.x == 8.0) || (mc_Entity.x == 9.0)) ? 1.0 : 0.0;

    if (isWater > 0.5) {
        float worldX = position.x + cameraPosition.x;
        float worldZ = position.z + cameraPosition.z;

        float wave  = sin(frameTimeCounter * 2.0 * WAVE_SPEED + worldX * 0.8 + worldZ * 0.6) * WAVE_HEIGHT;
        wave += sin(frameTimeCounter * 1.4 * WAVE_SPEED + worldX * 0.5 - worldZ * 0.9) * (WAVE_HEIGHT * 0.5);
        wave += sin(frameTimeCounter * 3.1 * WAVE_SPEED - worldX * 1.2 + worldZ * 0.4) * (WAVE_HEIGHT * 0.25);
        position.y += wave;
    }

    gl_Position = gl_ModelViewProjectionMatrix * position;

    // ── Shadow coords (ตรงกับ terrain.vsh: distort ก่อน divide) ──
    vec4 viewPos    = gl_ModelViewMatrix * position;
    vec4 worldPos   = gbufferModelViewInverse * viewPos;
    vec4 shadowClip = shadowProjection * shadowModelView * worldPos;

    shadowClip.xy  = shadowDistort(shadowClip.xy);   // distort ก่อน divide
    shadowClip.xyz /= shadowClip.w;
    shadowPos.xyz   = shadowClip.xyz * 0.5 + 0.5;
    shadowPos.w     = 1.0;

    // view direction สำหรับคำนวณ reflection ใน fsh
    viewDir = normalize((gl_ModelViewMatrix * position).xyz);

    uv   = gl_MultiTexCoord0.st;
    col  = gl_Color;
    norm = gl_NormalMatrix * gl_Normal;

    vec2 lm = gl_MultiTexCoord1.st / 256.0;
    bl = lm.x;
    sl = lm.y;
}
