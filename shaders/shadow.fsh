#version 120

varying vec2 texCoord;
varying vec4 color;

uniform sampler2D texture;

void main() {
    vec4 texColor = texture2D(texture, texCoord) * color;
    if (texColor.a < 0.1) discard;
    gl_FragData[0] = texColor;
}
