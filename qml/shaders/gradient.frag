// Spicy Lyrics' active-lyric gradient: linear-gradient(rgba(c, lit) pos%, rgba(c, unlit) pos+20%)
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float pos;        // gradient position, % (NotSung -20 … Sung 100)
    float vertical;   // 1 = top→bottom (whole lines), 0 = left→right (words)
    float lit;
    float unlit;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    float x = vertical > 0.5 ? qt_TexCoord0.y : qt_TexCoord0.x;
    float p1 = pos / 100.0;
    float a = mix(lit, unlit, clamp((x - p1) / 0.2, 0.0, 1.0));
    fragColor = c * a * qt_Opacity;
}
