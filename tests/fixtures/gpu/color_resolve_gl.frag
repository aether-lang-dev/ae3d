#version 410 core
// color_resolve: written by ae3d.gpu from its quote.

uniform int samples;
uniform float exposure;
uniform sampler2DMS colour;

in vec2 uv;
out vec4 FragColor;

void main() {
    vec4 sum = vec4(vec3(0.0, 0.0, 0.0), 0.0);
    float weights = 0.0;
    int s = 0;
    while (s < samples) {
        vec4 c = texelFetch(colour, ivec2(gl_FragCoord.xy), s);
        float w = 1.0 / (1.0 + dot(c.rgb * exposure, vec3(0.2126, 0.7152, 0.0722)));
        sum = sum + c * w;
        weights = weights + w;
        s = s + 1;
    }
    FragColor = sum / max(weights, 0.000001);
}
