// pick: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;
static inline float ae_mod(float x, float y) { return x - y * floor(x / y); }

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

struct DrawMaterial {
    packed_float3 diffuse;
    char ae_pad0[4];
    packed_float3 specular;
    float metallic;
    float roughness;
    float exposure;
    float alpha;
    float cutout;
    float normal_strength;
    float tile_breakup;
    float tile_rotation;
    float variation;
    float variation_scale;
    float detail_scale;
    float detail_strength;
    float detail_fade;
    float fire;
    float triplanar;
    float soft;
    float glitter;
    float glitter_grains;
    float glitter_strength;
    float embers;
    float ember_cover;
    float ember_glow;
    int blend;
    float reflectivity;
    int normal_map;
};
static_assert(sizeof(DrawMaterial) == 128, "DrawMaterial: std140");
static_assert(__builtin_offsetof(DrawMaterial, diffuse) == 0, "DrawMaterial.diffuse: std140");
static_assert(__builtin_offsetof(DrawMaterial, specular) == 16, "DrawMaterial.specular: std140");
static_assert(__builtin_offsetof(DrawMaterial, metallic) == 28, "DrawMaterial.metallic: std140");
static_assert(__builtin_offsetof(DrawMaterial, roughness) == 32, "DrawMaterial.roughness: std140");
static_assert(__builtin_offsetof(DrawMaterial, exposure) == 36, "DrawMaterial.exposure: std140");
static_assert(__builtin_offsetof(DrawMaterial, alpha) == 40, "DrawMaterial.alpha: std140");
static_assert(__builtin_offsetof(DrawMaterial, cutout) == 44, "DrawMaterial.cutout: std140");
static_assert(__builtin_offsetof(DrawMaterial, normal_strength) == 48, "DrawMaterial.normal_strength: std140");
static_assert(__builtin_offsetof(DrawMaterial, tile_breakup) == 52, "DrawMaterial.tile_breakup: std140");
static_assert(__builtin_offsetof(DrawMaterial, tile_rotation) == 56, "DrawMaterial.tile_rotation: std140");
static_assert(__builtin_offsetof(DrawMaterial, variation) == 60, "DrawMaterial.variation: std140");
static_assert(__builtin_offsetof(DrawMaterial, variation_scale) == 64, "DrawMaterial.variation_scale: std140");
static_assert(__builtin_offsetof(DrawMaterial, detail_scale) == 68, "DrawMaterial.detail_scale: std140");
static_assert(__builtin_offsetof(DrawMaterial, detail_strength) == 72, "DrawMaterial.detail_strength: std140");
static_assert(__builtin_offsetof(DrawMaterial, detail_fade) == 76, "DrawMaterial.detail_fade: std140");
static_assert(__builtin_offsetof(DrawMaterial, fire) == 80, "DrawMaterial.fire: std140");
static_assert(__builtin_offsetof(DrawMaterial, triplanar) == 84, "DrawMaterial.triplanar: std140");
static_assert(__builtin_offsetof(DrawMaterial, soft) == 88, "DrawMaterial.soft: std140");
static_assert(__builtin_offsetof(DrawMaterial, glitter) == 92, "DrawMaterial.glitter: std140");
static_assert(__builtin_offsetof(DrawMaterial, glitter_grains) == 96, "DrawMaterial.glitter_grains: std140");
static_assert(__builtin_offsetof(DrawMaterial, glitter_strength) == 100, "DrawMaterial.glitter_strength: std140");
static_assert(__builtin_offsetof(DrawMaterial, embers) == 104, "DrawMaterial.embers: std140");
static_assert(__builtin_offsetof(DrawMaterial, ember_cover) == 108, "DrawMaterial.ember_cover: std140");
static_assert(__builtin_offsetof(DrawMaterial, ember_glow) == 112, "DrawMaterial.ember_glow: std140");
static_assert(__builtin_offsetof(DrawMaterial, blend) == 116, "DrawMaterial.blend: std140");
static_assert(__builtin_offsetof(DrawMaterial, reflectivity) == 120, "DrawMaterial.reflectivity: std140");
static_assert(__builtin_offsetof(DrawMaterial, normal_map) == 124, "DrawMaterial.normal_map: std140");

struct Eye {
    float4x4 view_projection;
    float4x4 prev_view_projection;
    float4x4 inv_view_projection;
    packed_float3 position;
    float far;
    float2 jitter;
    float2 screen_size;
    int depth_on;
    char ae_pad0[12];
    float4 depth_plane;
    int history;
    int capture;
    float ray_reach;
    int ray_frame;
};
static_assert(sizeof(Eye) == 272, "Eye: std140");
static_assert(__builtin_offsetof(Eye, view_projection) == 0, "Eye.view_projection: std140");
static_assert(__builtin_offsetof(Eye, prev_view_projection) == 64, "Eye.prev_view_projection: std140");
static_assert(__builtin_offsetof(Eye, inv_view_projection) == 128, "Eye.inv_view_projection: std140");
static_assert(__builtin_offsetof(Eye, position) == 192, "Eye.position: std140");
static_assert(__builtin_offsetof(Eye, far) == 204, "Eye.far: std140");
static_assert(__builtin_offsetof(Eye, jitter) == 208, "Eye.jitter: std140");
static_assert(__builtin_offsetof(Eye, screen_size) == 216, "Eye.screen_size: std140");
static_assert(__builtin_offsetof(Eye, depth_on) == 224, "Eye.depth_on: std140");
static_assert(__builtin_offsetof(Eye, depth_plane) == 240, "Eye.depth_plane: std140");
static_assert(__builtin_offsetof(Eye, history) == 256, "Eye.history: std140");
static_assert(__builtin_offsetof(Eye, capture) == 260, "Eye.capture: std140");
static_assert(__builtin_offsetof(Eye, ray_reach) == 264, "Eye.ray_reach: std140");
static_assert(__builtin_offsetof(Eye, ray_frame) == 268, "Eye.ray_frame: std140");

struct Draw {
    float4x4 model;
    float4x4 prev_model;
    float4x4 light_space;
    int instanced;
    int instance_colour;
    int points;
    int billboard;
    int flip_columns;
    int flip_rows;
    float lift;
    int skinned;
    int impostor;
    int pick;
    char ae_pad0[8];
};
static_assert(sizeof(Draw) == 240, "Draw: std140");
static_assert(__builtin_offsetof(Draw, model) == 0, "Draw.model: std140");
static_assert(__builtin_offsetof(Draw, prev_model) == 64, "Draw.prev_model: std140");
static_assert(__builtin_offsetof(Draw, light_space) == 128, "Draw.light_space: std140");
static_assert(__builtin_offsetof(Draw, instanced) == 192, "Draw.instanced: std140");
static_assert(__builtin_offsetof(Draw, instance_colour) == 196, "Draw.instance_colour: std140");
static_assert(__builtin_offsetof(Draw, points) == 200, "Draw.points: std140");
static_assert(__builtin_offsetof(Draw, billboard) == 204, "Draw.billboard: std140");
static_assert(__builtin_offsetof(Draw, flip_columns) == 208, "Draw.flip_columns: std140");
static_assert(__builtin_offsetof(Draw, flip_rows) == 212, "Draw.flip_rows: std140");
static_assert(__builtin_offsetof(Draw, lift) == 216, "Draw.lift: std140");
static_assert(__builtin_offsetof(Draw, skinned) == 220, "Draw.skinned: std140");
static_assert(__builtin_offsetof(Draw, impostor) == 224, "Draw.impostor: std140");
static_assert(__builtin_offsetof(Draw, pick) == 228, "Draw.pick: std140");

struct DrawBlock {
    Draw draw;
    DrawMaterial material;
    char ae_pad0[128];
    Cut cut;
    Wounds wounds;
};
static_assert(sizeof(DrawBlock) == 2192, "DrawBlock: std140");
static_assert(__builtin_offsetof(DrawBlock, draw) == 0, "DrawBlock.draw: std140");
static_assert(__builtin_offsetof(DrawBlock, material) == 240, "DrawBlock.material: std140");
static_assert(__builtin_offsetof(DrawBlock, cut) == 496, "DrawBlock.cut: std140");
static_assert(__builtin_offsetof(DrawBlock, wounds) == 560, "DrawBlock.wounds: std140");

struct CameraBlock {
    Eye eye;
};
static_assert(sizeof(CameraBlock) == 272, "CameraBlock: std140");
static_assert(__builtin_offsetof(CameraBlock, eye) == 0, "CameraBlock.eye: std140");

struct Tri {
    float3 weights;
    float2 x;
    float2 y;
    float2 z;
};

struct Hex {
    float2 uv0;
    float2 uv1;
    float2 uv2;
    float2x2 turn0;
    float2x2 turn1;
    float2x2 turn2;
    float2 dx;
    float2 dy;
    float3 weights;
};

struct HexColour {
    float4 colour;
    float3 weights;
};

struct ae_pick_in {
    float2 fragTexCoord [[user(locn0)]];
    float3 Normal [[user(locn1)]];
    float3 FragPos [[user(locn2)]];
    float3 BindPos [[user(locn3)]];
    float ClipLimb [[user(locn4)]];
    float Instance [[user(locn5)]];
};

struct ae_pick_frag_out {
    float4 FragColor [[color(0)]];
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

static Tri ae3d_shaders_lit_tri_setup(float3 n, float3 position, float metres) {
    float3 w = pow(abs(n), float3(4.0));
    float3 q = position / metres;
    return Tri{w / max(w.x + w.y + w.z, 1e-6), q.zy, q.xz, q.xy};
}

static float4 ae3d_shaders_lit_tri_texture(texture2d<float> tex, sampler ae_smp_tex, Tri tri) {
    return tex.sample(ae_smp_tex, tri.x) * tri.weights.x + tex.sample(ae_smp_tex, tri.y) * tri.weights.y + tex.sample(ae_smp_tex, tri.z) * tri.weights.z;
}

static float2x2 ae3d_shaders_lit_hex_rotation(int cx, int cy, float strength) {
    float angle0 = abs(float((cx * cy))) + abs(float((cx + cy))) + 3.14159265;
    float angle1 = ae_mod(angle0, 6.28318531);
    float angle2 = angle1;
    if (angle1 > 3.14159265) {
        angle2 = angle1 - 6.28318531;
    }
    float angle = angle2 * strength;
    float c = cos(angle);
    float s = sin(angle);
    return float2x2(c, -s, s, c);
}

static float2 ae3d_shaders_lit_hex_offset(int cx, int cy) {
    float2 q = float2(float(cx), float(cy));
    return fract(sin(float2(dot(q, float2(127.1, 311.7)), dot(q, float2(269.5, 183.3)))) * 43758.5453);
}

static Hex ae3d_shaders_lit_hex_setup(float2 uv, float rotation) {
    float2 dx = dfdx(uv);
    float2 dy = dfdy(uv);
    float2 skewed = (float2x2(1.0, -0.57735027, 0.0, 1.15470054) * (uv * 3.46410162));
    int bx = int(floor(skewed.x));
    int by = int(floor(skewed.y));
    float2 t = fract(skewed);
    float tz = 1.0 - t.x - t.y;
    float s = step(0.0, -tz);
    float s2 = 2.0 * s - 1.0;
    float3 weights = float3(-tz * s2, s - t.y * s2, s - t.x * s2);
    int si = int(s);
    int c0x = bx + si;
    int c0y = by + si;
    int c1x = bx + si;
    int c1y = by + (1 - si);
    int c2x = bx + (1 - si);
    int c2y = by + si;
    float2x2 turn0 = ae3d_shaders_lit_hex_rotation(c0x, c0y, rotation);
    float2 middle0 = (float2x2(1.0, 0.0, 0.5, 0.86602540) * float2(float(c0x), float(c0y))) / 3.46410162;
    float2 uv0 = (turn0 * (uv - middle0)) + middle0 + ae3d_shaders_lit_hex_offset(c0x, c0y);
    float2x2 turn1 = ae3d_shaders_lit_hex_rotation(c1x, c1y, rotation);
    float2 middle1 = (float2x2(1.0, 0.0, 0.5, 0.86602540) * float2(float(c1x), float(c1y))) / 3.46410162;
    float2 uv1 = (turn1 * (uv - middle1)) + middle1 + ae3d_shaders_lit_hex_offset(c1x, c1y);
    float2x2 turn2 = ae3d_shaders_lit_hex_rotation(c2x, c2y, rotation);
    float2 middle2 = (float2x2(1.0, 0.0, 0.5, 0.86602540) * float2(float(c2x), float(c2y))) / 3.46410162;
    float2 uv2 = (turn2 * (uv - middle2)) + middle2 + ae3d_shaders_lit_hex_offset(c2x, c2y);
    return Hex{uv0, uv1, uv2, turn0, turn1, turn2, dx, dy, weights};
}

static HexColour ae3d_shaders_lit_hex_texture(texture2d<float> tex, sampler ae_smp_tex, Hex hx) {
    float4 c0 = tex.sample(ae_smp_tex, hx.uv0, gradient2d((hx.turn0 * hx.dx), (hx.turn0 * hx.dy)));
    float4 c1 = tex.sample(ae_smp_tex, hx.uv1, gradient2d((hx.turn1 * hx.dx), (hx.turn1 * hx.dy)));
    float4 c2 = tex.sample(ae_smp_tex, hx.uv2, gradient2d((hx.turn2 * hx.dx), (hx.turn2 * hx.dy)));
    float3 luma = float3(0.299, 0.587, 0.114);
    float3 bright = mix(float3(1.0), float3(dot(c0.rgb, luma), dot(c1.rgb, luma), dot(c2.rgb, luma)), 0.6);
    float3 w0 = bright * pow(hx.weights, float3(7.0));
    float3 w = w0 / max(w0.x + w0.y + w0.z, 1e-6);
    return HexColour{c0 * w.x + c1 * w.y + c2 * w.z, w};
}

fragment ae_pick_frag_out ae_pick_fragment(
    ae_pick_in ae_in [[stage_in]],
    constant DrawBlock& ae_set0 [[buffer(0)]],
    constant CameraBlock& ae_set1 [[buffer(1)]],
    texture2d<float> colour_map [[texture(0)]], sampler ae_smp_colour_map [[sampler(0)]]) {
    ae_pick_frag_out ae_out;
    float2 fragTexCoord = ae_in.fragTexCoord;
    float3 Normal = ae_in.Normal;
    float3 FragPos = ae_in.FragPos;
    float3 BindPos = ae_in.BindPos;
    float ClipLimb = ae_in.ClipLimb;
    float Instance = ae_in.Instance;
    constant Draw& draw = ae_set0.draw;
    constant DrawMaterial& material = ae_set0.material;
    constant Cut& cut = ae_set0.cut;
    constant Wounds& wounds = ae_set0.wounds;
    constant Eye& eye = ae_set1.eye;
    if (ae3d_shaders_lit_clipped_away(BindPos, cut, ClipLimb)) {
        discard_fragment();
    }
    float wound_at = wounds.count > 0 ? ae3d_shaders_lit_wound_depth(BindPos, wounds) : 2.0;
    if (wound_at < wounds.core) {
        discard_fragment();
    }
    Tri tri = Tri{float3(0.0, 1.0, 0.0), float2(0.0), float2(0.0), float2(0.0)};
    Hex hx = Hex{float2(0.0), float2(0.0), float2(0.0), float2x2(1.0, 0.0, 0.0, 1.0), float2x2(1.0, 0.0, 0.0, 1.0), float2x2(1.0, 0.0, 0.0, 1.0), float2(0.0), float2(0.0), float3(1.0, 0.0, 0.0)};
    float4 tex_colour = float4(0.0);
    if (material.triplanar > 0.0) {
        tri = ae3d_shaders_lit_tri_setup(normalize(Normal), FragPos, material.triplanar);
        tex_colour = ae3d_shaders_lit_tri_texture(colour_map, ae_smp_colour_map, tri);
    } else if (material.tile_breakup > 0.0) {
        hx = ae3d_shaders_lit_hex_setup(fragTexCoord, material.tile_rotation);
        tex_colour = ae3d_shaders_lit_hex_texture(colour_map, ae_smp_colour_map, hx).colour;
    } else {
        tex_colour = colour_map.sample(ae_smp_colour_map, fragTexCoord);
    }
    if (tex_colour.w < material.cutout) {
        discard_fragment();
    }
    if (material.blend != 0 && tex_colour.w * material.alpha < 0.5) {
        discard_fragment();
    }
    float4 ndc = (eye.view_projection * float4(FragPos, 1.0));
    ae_out.FragColor = float4(float3(float(draw.pick), Instance, (ndc.z / ndc.w)), 1.0);
    return ae_out;
}
