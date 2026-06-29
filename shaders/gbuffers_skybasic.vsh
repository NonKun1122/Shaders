#version 120

varying vec4 col;
varying vec3 dir;

void main() {
    gl_Position = ftransform();
    col = gl_Color;
    // dir ใช้สำหรับ gradient (y = up/down) และ star position hash
    dir = gl_Vertex.xyz;
}
