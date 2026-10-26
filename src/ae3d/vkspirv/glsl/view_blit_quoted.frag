#version 450
// view_blit: written by ae3d.gpu from its quote.

layout(set = 0, binding = 0) uniform sampler2D picture;

float ae3d_shaders_viewrect_srgb_encode(float x) {
    if (x <= 0.0031308) {
        return x * 12.92;
    }
    return 1.055 * pow(x, 1.0 / 2.4) - 0.055;
}

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;

void main() {
    vec4 c = texture(picture, uv);
    FragColor = vec4(vec3(ae3d_shaders_viewrect_srgb_encode(c.x), ae3d_shaders_viewrect_srgb_encode(c.y), ae3d_shaders_viewrect_srgb_encode(c.z)), c.w);
}
