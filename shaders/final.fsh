#version 120

uniform sampler2D gcolor;
varying vec2 uv;

void main() {
    vec3 c = texture2D(gcolor, uv).rgb;
    gl_FragColor = vec4(c, 1.0);
}
