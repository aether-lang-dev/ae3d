#version 450
// color_resolve: written by ae3d.gpu from its quote.

layout(std140, set = 0, binding = 0) uniform Params {
    int samples;
    float exposure;
};
layout(set = 0, binding = 1) uniform sampler2DMS colour;

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;

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
