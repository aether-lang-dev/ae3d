#version 410 core
// dof_coc: written by ae3d.gpu from its quote.

uniform vec2 texel;
uniform mat4 inv_view_projection;
uniform float focus;
uniform float aperture;
uniform float max_radius;
uniform sampler2D screen;
uniform sampler2D depth;

float ae3d_shaders_dof_disc_radius(float z, float d, float focus, float aperture, float max_radius) {
    float r = aperture;
    if (d < 0.99999) {
        r = aperture * (z - focus) / max(z, 0.0001);
    }
    return clamp(r, 0.0 - max_radius, max_radius);
}

float ae3d_shaders_dof_view_depth(mat4 inv_view_projection, vec2 uv, float d) {
    vec4 p = (inv_view_projection * vec4(vec3(uv.x * 2.0 - 1.0, uv.y * 2.0 - 1.0, (d * 2.0 - 1.0)), 1.0));
    return 1.0 / max(abs(p.w), 0.0000001);
}

float ae3d_shaders_dof_texel_disc(sampler2D depth, vec2 dsize, vec2 p, mat4 inv_view_projection, float focus, float aperture, float max_radius) {
    vec2 q = clamp(p, vec2(0.0, 0.0), dsize - vec2(1.0, 1.0));
    float d = texelFetch(depth, ivec2(q), 0).x;
    vec2 uv = (q + vec2(0.5, 0.5)) / dsize;
    return ae3d_shaders_dof_disc_radius(ae3d_shaders_dof_view_depth(inv_view_projection, uv, d), d, focus, aperture, max_radius);
}

in vec2 uv;
out vec4 FragColor;

void main() {
    vec2 q = texel * 0.25;
    vec3 c = (texture(screen, uv + vec2(-q.x, -q.y)).rgb + texture(screen, uv + vec2(q.x, -q.y)).rgb + texture(screen, uv + vec2(-q.x, q.y)).rgb + texture(screen, uv + vec2(q.x, q.y)).rgb) * 0.25;
    vec2 dsize = vec2(textureSize(depth, 0));
    vec2 b = floor(uv * dsize - vec2(0.5, 0.5));
    float r0 = ae3d_shaders_dof_texel_disc(depth, dsize, b, inv_view_projection, focus, aperture, max_radius);
    float r1 = ae3d_shaders_dof_texel_disc(depth, dsize, b + vec2(1.0, 0.0), inv_view_projection, focus, aperture, max_radius);
    float r2 = ae3d_shaders_dof_texel_disc(depth, dsize, b + vec2(0.0, 1.0), inv_view_projection, focus, aperture, max_radius);
    float r3 = ae3d_shaders_dof_texel_disc(depth, dsize, b + vec2(1.0, 1.0), inv_view_projection, focus, aperture, max_radius);
    float r = r0;
    if (abs(r1) > abs(r)) {
        r = r1;
    }
    if (abs(r2) > abs(r)) {
        r = r2;
    }
    if (abs(r3) > abs(r)) {
        r = r3;
    }
    FragColor = vec4(c, r);
}
