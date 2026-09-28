#version 450

#ifdef VULKAN
#define VARYING(n) layout(location = n)
layout(push_constant) uniform OverlayFrame {
    vec4 overlayScreen;
    vec4 overlayStyle;
};
layout(set = 0, binding = 0) uniform sampler2D glyphAtlas;
layout(set = 0, binding = 1) uniform sampler2D imageAtlas;
#else
#define VARYING(n)
uniform vec4 overlayScreen;
uniform vec4 overlayStyle;
uniform sampler2D glyphAtlas;
uniform sampler2D imageAtlas;
#endif

VARYING(0) in vec2 atlasCoord;
VARYING(1) in vec4 colour;
VARYING(2) in float edge;

layout(location = 0) out vec4 FragColor;

void main() {
    // The field's value, and how much it changes across one screen pixel:
    // the edge is blended over that pixel whatever size the glyph is drawn
    // at, which is what keeps text sharp at 12 px and at 120 from the one
    // atlas. Both atlases are read for every quad, outside any branch, so
    // the derivatives are taken where every pixel of the quad takes them.
    float d = texture(glyphAtlas, atlasCoord).r;
    vec4 picture = texture(imageAtlas, atlasCoord);
    float w = max(fwidth(d) * 0.5, 1.0 / 255.0);
    vec3 rgb = colour.rgb;
    float alpha = colour.a;
    if (edge < -1.5) {
        // An image, premultiplied in its atlas so its filtered edge has no
        // fringe; its own colour, straight, times the tint.
        alpha = picture.a * colour.a;
        rgb = picture.a > 0.0 ? picture.rgb / picture.a * colour.rgb : vec3(0.0);
    } else if (edge >= 0.0) {
        alpha = colour.a * smoothstep(edge - w, edge + w, d);
    }
    // A target that encodes what it is given (an _SRGB swapchain) gets the
    // colour decoded first, so it shows as the display value asked for.
    if (overlayStyle.x > 0.5) rgb = pow(rgb, vec3(2.2));
    // Premultiplied: the blend is ONE, ONE_MINUS_SRC_ALPHA.
    FragColor = vec4(rgb * alpha, alpha);
}
