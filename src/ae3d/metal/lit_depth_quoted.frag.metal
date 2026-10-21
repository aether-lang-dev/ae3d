// lit_depth: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct Cut {
    int on;
    char ae_pad0[12];
    float4 plane;
    int detached;
    float noise;
    float noise_scale;
    int joints0;
    int joints1;
    int joints2;
    char ae_pad1[8];
};
static_assert(sizeof(Cut) == 64, "Cut: std140");
static_assert(__builtin_offsetof(Cut, on) == 0, "Cut.on: std140");
static_assert(__builtin_offsetof(Cut, plane) == 16, "Cut.plane: std140");
static_assert(__builtin_offsetof(Cut, detached) == 32, "Cut.detached: std140");
static_assert(__builtin_offsetof(Cut, noise) == 36, "Cut.noise: std140");
static_assert(__builtin_offsetof(Cut, noise_scale) == 40, "Cut.noise_scale: std140");
static_assert(__builtin_offsetof(Cut, joints0) == 44, "Cut.joints0: std140");
static_assert(__builtin_offsetof(Cut, joints1) == 48, "Cut.joints1: std140");
static_assert(__builtin_offsetof(Cut, joints2) == 52, "Cut.joints2: std140");

struct Wounds {
    int count;
    char ae_pad0[12];
    float4 data[96];
    float4 layers[4];
    float core;
    char ae_pad1[12];
};
static_assert(sizeof(Wounds) == 1632, "Wounds: std140");
static_assert(__builtin_offsetof(Wounds, count) == 0, "Wounds.count: std140");
static_assert(__builtin_offsetof(Wounds, data) == 16, "Wounds.data: std140");
static_assert(__builtin_offsetof(Wounds, layers) == 1552, "Wounds.layers: std140");
static_assert(__builtin_offsetof(Wounds, core) == 1616, "Wounds.core: std140");

struct DrawBlock {
    char ae_pad0[496];
    Cut cut;
    Wounds wounds;
};
static_assert(sizeof(DrawBlock) == 2192, "DrawBlock: std140");
static_assert(__builtin_offsetof(DrawBlock, cut) == 496, "DrawBlock.cut: std140");
static_assert(__builtin_offsetof(DrawBlock, wounds) == 560, "DrawBlock.wounds: std140");

struct ae_lit_depth_in {
    float3 BindPos [[user(locn0)]];
    float ClipLimb [[user(locn1)]];
};

static float ae3d_shaders_lit_clip_hash(float3 p_in) {
    float3 p0 = fract(p_in * 0.3183099 + float3(0.71, 0.113, 0.419));
    float3 p = p0 * 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

static float ae3d_shaders_lit_clip_value_noise(float3 p) {
    float3 i = floor(p);
    float3 f0 = fract(p);
    float3 f = f0 * f0 * (float3(3.0) - f0 * 2.0);
    return mix(mix(mix(ae3d_shaders_lit_clip_hash(i + float3(0.0, 0.0, 0.0)), ae3d_shaders_lit_clip_hash(i + float3(1.0, 0.0, 0.0)), f.x), mix(ae3d_shaders_lit_clip_hash(i + float3(0.0, 1.0, 0.0)), ae3d_shaders_lit_clip_hash(i + float3(1.0, 1.0, 0.0)), f.x), f.y), mix(mix(ae3d_shaders_lit_clip_hash(i + float3(0.0, 0.0, 1.0)), ae3d_shaders_lit_clip_hash(i + float3(1.0, 0.0, 1.0)), f.x), mix(ae3d_shaders_lit_clip_hash(i + float3(0.0, 1.0, 1.0)), ae3d_shaders_lit_clip_hash(i + float3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

static bool ae3d_shaders_lit_clipped_away(float3 bind_pos, constant Cut& cut, float ClipLimb) {
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

static float3 ae3d_shaders_lit_wound_unturn(float4 q, float3 v) {
    float3 u = -q.xyz;
    float3 t = cross(u, v) * 2.0;
    return v + t * q.w + cross(u, t);
}

static float ae3d_shaders_lit_wound_depth(float3 p, constant Wounds& wounds) {
    float best = 2.0;
    for (int i = 0; i < 32; i += 1) {
        if (i >= wounds.count) {
            break;
        }
        if (wounds.data[i * 3].w > 0.5) {
            continue;
        }
        float3 r = max(wounds.data[i * 3 + 1].xyz, float3(0.0001));
        float3 local = ae3d_shaders_lit_wound_unturn(wounds.data[i * 3 + 2], p - wounds.data[i * 3].xyz) / r;
        best = min(best, length(local));
    }
    return best;
}

fragment void ae_lit_depth_fragment(
    ae_lit_depth_in ae_in [[stage_in]],
    constant DrawBlock& ae_set0 [[buffer(0)]]) {
    float3 BindPos = ae_in.BindPos;
    float ClipLimb = ae_in.ClipLimb;
    constant Cut& cut = ae_set0.cut;
    constant Wounds& wounds = ae_set0.wounds;
    if (ae3d_shaders_lit_clipped_away(BindPos, cut, ClipLimb)) {
        discard_fragment();
    }
    if (wounds.count > 0 && ae3d_shaders_lit_wound_depth(BindPos, wounds) < wounds.core) {
        discard_fragment();
    }
    // kept
}
