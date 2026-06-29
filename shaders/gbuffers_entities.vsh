#version 120

uniform mat4  shadowModelView;
uniform mat4  shadowProjection;
uniform mat4  gbufferModelViewInverse;

varying vec2  uv;
varying vec4  col;
varying vec3  norm;
varying float bl;
varying float sl;
varying vec4  shadowPos;   // เพิ่ม: entities ก็ต้องรับเงาด้วย

vec2 shadowDistort(vec2 pos) {
    float dist = length(pos);
    return pos / (dist + 0.1);
}

void main() {
    gl_Position = ftransform();

    uv   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    col  = gl_Color;
    norm = normalize(gl_NormalMatrix * gl_Normal);

    vec2 lm = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    bl = lm.x;
    sl = lm.y;

    // ── Shadow coords (เหมือน terrain.vsh ทุกประการ) ──────
    vec4 viewPos    = gl_ModelViewMatrix * gl_Vertex;
    vec4 worldPos   = gbufferModelViewInverse * viewPos;
    vec4 shadowClip = shadowProjection * shadowModelView * worldPos;

    shadowClip.xy  = shadowDistort(shadowClip.xy);   // distort ก่อน divide
    shadowClip.xyz /= shadowClip.w;
    shadowPos.xyz   = shadowClip.xyz * 0.5 + 0.5;
    shadowPos.w     = 1.0;
}
