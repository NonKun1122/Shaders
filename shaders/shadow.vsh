#version 120

attribute vec4 mc_Entity;

uniform float frameTimeCounter;
uniform vec3  cameraPosition;

varying vec2 texCoord;
varying vec4 color;

#ifndef WIND_SPEED
#define WIND_SPEED 1.5
#endif
#ifndef ENABLE_WIND
#define ENABLE_WIND 1
#endif
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
    texCoord = gl_MultiTexCoord0.st;
    color    = gl_Color;

    vec4 position = gl_Vertex;
    float id = mc_Entity.x;

#if ENABLE_WIND == 1
    bool isLeaf  = (id == 18.0) || (id == 161.0);
    bool isGrass = (id == 31.0) || (id == 32.0) || (id == 37.0) || (id == 38.0);
    bool isPlant = (id == 6.0)  || (id == 59.0)  || (id == 83.0) || (id == 175.0)
                || (id == 104.0)|| (id == 105.0);
    bool isVine  = (id == 106.0);
    if (isLeaf || isGrass || isPlant || isVine) {
        float worldX = position.x + cameraPosition.x;
        float worldZ = position.z + cameraPosition.z;
        float wind   = sin(frameTimeCounter * 2.0 * WIND_SPEED + worldX * 0.5 + worldZ * 0.3);
        wind += sin(frameTimeCounter * 1.3 * WIND_SPEED + worldX * 0.3 - worldZ * 0.5) * 0.5;
        float h = smoothstep(0.0, 0.7, fract(position.y));
        position.x += wind * 0.05 * h;
        position.z += wind * 0.03 * h;
    }
#endif

    bool isWater = (id == 8.0) || (id == 9.0);
    if (isWater) {
        float worldX = position.x + cameraPosition.x;
        float worldZ = position.z + cameraPosition.z;
        float wave   = sin(frameTimeCounter * 2.0 * WAVE_SPEED + worldX * 0.8 + worldZ * 0.6) * WAVE_HEIGHT;
        wave += sin(frameTimeCounter * 1.4 * WAVE_SPEED + worldX * 0.5 - worldZ * 0.9) * (WAVE_HEIGHT * 0.5);
        position.y += wave;
    }

    vec4 clipPos = gl_ModelViewProjectionMatrix * position;
    clipPos.xy   = shadowDistort(clipPos.xy);
    gl_Position  = clipPos;
}
