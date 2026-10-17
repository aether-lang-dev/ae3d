#version 410 core
// ssao: written by ae3d.gpu from its quote.

uniform vec2 screen_size;
uniform mat4 inv_view_projection;
uniform float intensity;
uniform vec3 view_pos;
uniform float radius;
uniform mat4 view_projection;
uniform sampler2D depth;

vec3 ae3d_shaders_ssao_world_at(mat4 inv_view_projection, vec2 uv, float depth) {
    vec4 world = (inv_view_projection * vec4(vec3(uv.x * 2.0 - 1.0, uv.y * 2.0 - 1.0, (depth * 2.0 - 1.0)), 1.0));
    return world.xyz / world.w;
}

float ae3d_shaders_ssao_dither(vec2 pixel) {
    return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

in vec2 uv_in;
out vec4 FragColor;

void main() {
    vec2 fc = gl_FragCoord.xy;
    vec2 uv = vec2(fc.x / screen_size.x, fc.y / screen_size.y);
    float d = texture(depth, uv).x;
    vec3 p = ae3d_shaders_ssao_world_at(inv_view_projection, uv, d);
    if (d >= 0.99999 || intensity <= 0.0) {
        FragColor = vec4(vec3(1.0, 0.0, 0.0), 1.0);
        return;
    }
    vec2 px = vec2(1.0 / screen_size.x, 1.0 / screen_size.y);
    vec2 ul = uv - vec2(px.x, 0.0);
    float dl = texture(depth, ul).x;
    vec3 pl = ae3d_shaders_ssao_world_at(inv_view_projection, ul, dl);
    vec2 ur = uv + vec2(px.x, 0.0);
    float dr = texture(depth, ur).x;
    vec3 pr = ae3d_shaders_ssao_world_at(inv_view_projection, ur, dr);
    vec2 above = vec2(0.0, px.y * 1.0);
    vec2 ud = uv - above;
    float dd = texture(depth, ud).x;
    vec3 pd = ae3d_shaders_ssao_world_at(inv_view_projection, ud, dd);
    vec2 uu = uv + above;
    float du = texture(depth, uu).x;
    vec3 pu = ae3d_shaders_ssao_world_at(inv_view_projection, uu, du);
    vec3 dx = abs(dl - d) < abs(dr - d) ? p - pl : pr - p;
    vec3 dy = abs(dd - d) < abs(du - d) ? p - pd : pu - p;
    vec3 n = normalize(cross(dx, dy));
    float eye = distance(view_pos, p);
    vec3 up = abs(n.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 t = normalize(cross(up, n));
    vec3 b = cross(n, t);
    vec2 pixel = 1.0 < 0.0 ? vec2(fc.x, screen_size.y - fc.y) : fc;
    float turn = ae3d_shaders_ssao_dither(pixel) * 6.2831853;
    float occlusion = 0.0;
    float i = 0.0;
    while (i < 12.0) {
        float f = (i + 0.5) / 12.0;
        i = i + 1.0;
        float a = turn + f * 15.0796;
        float r = sqrt(f);
        float h = sqrt(1.0 - r * r);
        vec3 dir = t * (cos(a) * r) + b * (sin(a) * r) + n * h;
        float reach = radius * mix(0.1, 1.0, f * f);
        vec3 s = p + dir * reach;
        vec4 clip = (view_projection * vec4(s, 1.0));
        if (clip.w <= 0.0) {
            continue;
        }
        vec2 suv = vec2(clip.x / clip.w * 0.5 + 0.5, clip.y / clip.w * 0.5 + 0.5);
        if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
            continue;
        }
        float sd = texture(depth, suv).x;
        float scene_dist = distance(view_pos, ae3d_shaders_ssao_world_at(inv_view_projection, suv, sd));
        float sample_dist = distance(view_pos, s);
        if (sample_dist - scene_dist > 0.03 * reach + eye * 0.01) {
            occlusion = occlusion + smoothstep(0.0, 1.0, radius / max(abs(eye - scene_dist), 0.0001));
        }
    }
    occlusion = occlusion / 12.0;
    float ao = clamp(1.0 - occlusion * intensity, 0.0, 1.0);
    ao = mix(ao, 1.0, smoothstep(radius * 40.0, radius * 120.0, eye));
    FragColor = vec4(vec3(ao, (view_projection * vec4(p, 1.0)).w, 0.0), 1.0);
}
