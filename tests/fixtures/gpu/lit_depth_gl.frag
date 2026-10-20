#version 410 core
// lit_depth: written by ae3d.gpu from its quote.

struct Cut {
    int on;
    vec4 plane;
    int detached;
    float noise;
    float noise_scale;
    int joints0;
    int joints1;
    int joints2;
};
struct Wounds {
    int count;
    vec4 data[96];
    vec4 layers[4];
    float core;
};
uniform Cut cut;
uniform Wounds wounds;

in vec3 BindPos;
in float ClipLimb;

float ae3d_shaders_lit_clip_hash(vec3 p_in) {
    vec3 p0 = fract(p_in * 0.3183099 + vec3(0.71, 0.113, 0.419));
    vec3 p = p0 * 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ae3d_shaders_lit_clip_value_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f0 = fract(p);
    vec3 f = f0 * f0 * (vec3(3.0) - f0 * 2.0);
    return mix(mix(mix(ae3d_shaders_lit_clip_hash(i + vec3(0.0, 0.0, 0.0)), ae3d_shaders_lit_clip_hash(i + vec3(1.0, 0.0, 0.0)), f.x), mix(ae3d_shaders_lit_clip_hash(i + vec3(0.0, 1.0, 0.0)), ae3d_shaders_lit_clip_hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y), mix(mix(ae3d_shaders_lit_clip_hash(i + vec3(0.0, 0.0, 1.0)), ae3d_shaders_lit_clip_hash(i + vec3(1.0, 0.0, 1.0)), f.x), mix(ae3d_shaders_lit_clip_hash(i + vec3(0.0, 1.0, 1.0)), ae3d_shaders_lit_clip_hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

bool ae3d_shaders_lit_clipped_away(vec3 bind_pos) {
    if (cut.on == 0) {
        return false;
    }
    bool on_limb = ClipLimb >= 0.5;
    if (cut.detached != 0 && !on_limb) {
        return true;
    }
    if (!on_limb) {
        return false;
    }
    float side0 = dot(cut.plane.xyz, bind_pos) - cut.plane.w;
    float side = side0;
    if (cut.noise > 0.0) {
        side = side0 + cut.noise * (ae3d_shaders_lit_clip_value_noise(bind_pos * cut.noise_scale) * 2.0 - 1.0);
    }
    return side > 0.0;
}

vec3 ae3d_shaders_lit_wound_unturn(vec4 q, vec3 v) {
    vec3 u = -q.xyz;
    vec3 t = cross(u, v) * 2.0;
    return v + t * q.w + cross(u, t);
}

float ae3d_shaders_lit_wound_depth(vec3 p) {
    float best = 2.0;
    for (int i = 0; i < 32; i += 1) {
        if (i >= wounds.count) {
            break;
        }
        if (wounds.data[i * 3].w > 0.5) {
            continue;
        }
        vec3 r = max(wounds.data[i * 3 + 1].xyz, vec3(0.0001));
        vec3 local = ae3d_shaders_lit_wound_unturn(wounds.data[i * 3 + 2], p - wounds.data[i * 3].xyz) / r;
        best = min(best, length(local));
    }
    return best;
}

void main() {
    if (ae3d_shaders_lit_clipped_away(BindPos)) {
        discard;
    }
    if (wounds.count > 0 && ae3d_shaders_lit_wound_depth(BindPos) < wounds.core) {
        discard;
    }
    // kept
}
