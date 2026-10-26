// lit: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;
static inline float ae_mod(float x, float y) { return x - y * floor(x / y); }
static inline float2 ae_mod(float2 x, float y) { return x - y * floor(x / y); }

struct WorldLight {
    packed_float3 position;
    char ae_pad0[4];
    packed_float3 colour;
    float intensity;
    float temperature;
    int kind;
    char ae_pad1[8];
    packed_float3 direction;
    float constant_;
    float linear;
    float quadratic;
    float cos_outer;
    float cos_inner;
};
static_assert(sizeof(WorldLight) == 80, "WorldLight: std140");
static_assert(__builtin_offsetof(WorldLight, position) == 0, "WorldLight.position: std140");
static_assert(__builtin_offsetof(WorldLight, colour) == 16, "WorldLight.colour: std140");
static_assert(__builtin_offsetof(WorldLight, intensity) == 28, "WorldLight.intensity: std140");
static_assert(__builtin_offsetof(WorldLight, temperature) == 32, "WorldLight.temperature: std140");
static_assert(__builtin_offsetof(WorldLight, kind) == 36, "WorldLight.kind: std140");
static_assert(__builtin_offsetof(WorldLight, direction) == 48, "WorldLight.direction: std140");
static_assert(__builtin_offsetof(WorldLight, constant_) == 60, "WorldLight.constant_: std140");
static_assert(__builtin_offsetof(WorldLight, linear) == 64, "WorldLight.linear: std140");
static_assert(__builtin_offsetof(WorldLight, quadratic) == 68, "WorldLight.quadratic: std140");
static_assert(__builtin_offsetof(WorldLight, cos_outer) == 72, "WorldLight.cos_outer: std140");
static_assert(__builtin_offsetof(WorldLight, cos_inner) == 76, "WorldLight.cos_inner: std140");
static inline WorldLight ae_make_WorldLight(float3 position, float3 colour, float intensity, float temperature, int kind, float3 direction, float constant_, float linear, float quadratic, float cos_outer, float cos_inner) {
    WorldLight ae_r;
    ae_r.position = position;
    ae_r.colour = colour;
    ae_r.intensity = intensity;
    ae_r.temperature = temperature;
    ae_r.kind = kind;
    ae_r.direction = direction;
    ae_r.constant_ = constant_;
    ae_r.linear = linear;
    ae_r.quadratic = quadratic;
    ae_r.cos_outer = cos_outer;
    ae_r.cos_inner = cos_inner;
    return ae_r;
}

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

struct WorldState {
    WorldLight lights[16];
    int light_count;
    char ae_pad0[12];
    packed_float3 shadow_direction;
    float cloud_cover;
    float cloud_time;
    char ae_pad1[12];
    packed_float3 cloud_sun;
    float time;
    float wetness;
    float normal_strength;
    float occlusion_strength;
    int gi_off;
    int rays;
    float sun_angle;
    float ray_occlusion;
    float ray_occlusion_strength;
    float ray_lamp_radius;
    char ae_pad2[12];
};
static_assert(sizeof(WorldState) == 1392, "WorldState: std140");
static_assert(__builtin_offsetof(WorldState, lights) == 0, "WorldState.lights: std140");
static_assert(__builtin_offsetof(WorldState, light_count) == 1280, "WorldState.light_count: std140");
static_assert(__builtin_offsetof(WorldState, shadow_direction) == 1296, "WorldState.shadow_direction: std140");
static_assert(__builtin_offsetof(WorldState, cloud_cover) == 1308, "WorldState.cloud_cover: std140");
static_assert(__builtin_offsetof(WorldState, cloud_time) == 1312, "WorldState.cloud_time: std140");
static_assert(__builtin_offsetof(WorldState, cloud_sun) == 1328, "WorldState.cloud_sun: std140");
static_assert(__builtin_offsetof(WorldState, time) == 1340, "WorldState.time: std140");
static_assert(__builtin_offsetof(WorldState, wetness) == 1344, "WorldState.wetness: std140");
static_assert(__builtin_offsetof(WorldState, normal_strength) == 1348, "WorldState.normal_strength: std140");
static_assert(__builtin_offsetof(WorldState, occlusion_strength) == 1352, "WorldState.occlusion_strength: std140");
static_assert(__builtin_offsetof(WorldState, gi_off) == 1356, "WorldState.gi_off: std140");
static_assert(__builtin_offsetof(WorldState, rays) == 1360, "WorldState.rays: std140");
static_assert(__builtin_offsetof(WorldState, sun_angle) == 1364, "WorldState.sun_angle: std140");
static_assert(__builtin_offsetof(WorldState, ray_occlusion) == 1368, "WorldState.ray_occlusion: std140");
static_assert(__builtin_offsetof(WorldState, ray_occlusion_strength) == 1372, "WorldState.ray_occlusion_strength: std140");
static_assert(__builtin_offsetof(WorldState, ray_lamp_radius) == 1376, "WorldState.ray_lamp_radius: std140");

struct Damage {
    int on;
    char ae_pad0[12];
    float4 colours[4];
    float4 rect;
    float clamp;
    char ae_pad1[12];
};
static_assert(sizeof(Damage) == 112, "Damage: std140");
static_assert(__builtin_offsetof(Damage, on) == 0, "Damage.on: std140");
static_assert(__builtin_offsetof(Damage, colours) == 16, "Damage.colours: std140");
static_assert(__builtin_offsetof(Damage, rect) == 80, "Damage.rect: std140");
static_assert(__builtin_offsetof(Damage, clamp) == 96, "Damage.clamp: std140");

struct Surface {
    int shadows;
    float shadow_intensity;
    float shadow_softness;
    int clearcoat;
    float clearcoat_roughness;
    float clearcoat_intensity;
    int sheen;
    char ae_pad0[4];
    packed_float3 sheen_colour;
    float sheen_roughness;
    int transmission;
    float transmission_factor;
    int multiple_scattering;
    int energy_conservation;
    int ibl;
    float ibl_intensity;
    int volumetric;
    float volumetric_intensity;
    int volumetric_steps;
    float volumetric_scattering;
    int perlin;
    float noise_scale;
    int noise_octaves;
    float noise_intensity;
    int caustics;
    float caustics_intensity;
    float caustics_scale;
    float caustics_speed;
    float caustics_water_level;
    float caustics_depth;
};
static_assert(sizeof(Surface) == 128, "Surface: std140");
static_assert(__builtin_offsetof(Surface, shadows) == 0, "Surface.shadows: std140");
static_assert(__builtin_offsetof(Surface, shadow_intensity) == 4, "Surface.shadow_intensity: std140");
static_assert(__builtin_offsetof(Surface, shadow_softness) == 8, "Surface.shadow_softness: std140");
static_assert(__builtin_offsetof(Surface, clearcoat) == 12, "Surface.clearcoat: std140");
static_assert(__builtin_offsetof(Surface, clearcoat_roughness) == 16, "Surface.clearcoat_roughness: std140");
static_assert(__builtin_offsetof(Surface, clearcoat_intensity) == 20, "Surface.clearcoat_intensity: std140");
static_assert(__builtin_offsetof(Surface, sheen) == 24, "Surface.sheen: std140");
static_assert(__builtin_offsetof(Surface, sheen_colour) == 32, "Surface.sheen_colour: std140");
static_assert(__builtin_offsetof(Surface, sheen_roughness) == 44, "Surface.sheen_roughness: std140");
static_assert(__builtin_offsetof(Surface, transmission) == 48, "Surface.transmission: std140");
static_assert(__builtin_offsetof(Surface, transmission_factor) == 52, "Surface.transmission_factor: std140");
static_assert(__builtin_offsetof(Surface, multiple_scattering) == 56, "Surface.multiple_scattering: std140");
static_assert(__builtin_offsetof(Surface, energy_conservation) == 60, "Surface.energy_conservation: std140");
static_assert(__builtin_offsetof(Surface, ibl) == 64, "Surface.ibl: std140");
static_assert(__builtin_offsetof(Surface, ibl_intensity) == 68, "Surface.ibl_intensity: std140");
static_assert(__builtin_offsetof(Surface, volumetric) == 72, "Surface.volumetric: std140");
static_assert(__builtin_offsetof(Surface, volumetric_intensity) == 76, "Surface.volumetric_intensity: std140");
static_assert(__builtin_offsetof(Surface, volumetric_steps) == 80, "Surface.volumetric_steps: std140");
static_assert(__builtin_offsetof(Surface, volumetric_scattering) == 84, "Surface.volumetric_scattering: std140");
static_assert(__builtin_offsetof(Surface, perlin) == 88, "Surface.perlin: std140");
static_assert(__builtin_offsetof(Surface, noise_scale) == 92, "Surface.noise_scale: std140");
static_assert(__builtin_offsetof(Surface, noise_octaves) == 96, "Surface.noise_octaves: std140");
static_assert(__builtin_offsetof(Surface, noise_intensity) == 100, "Surface.noise_intensity: std140");
static_assert(__builtin_offsetof(Surface, caustics) == 104, "Surface.caustics: std140");
static_assert(__builtin_offsetof(Surface, caustics_intensity) == 108, "Surface.caustics_intensity: std140");
static_assert(__builtin_offsetof(Surface, caustics_scale) == 112, "Surface.caustics_scale: std140");
static_assert(__builtin_offsetof(Surface, caustics_speed) == 116, "Surface.caustics_speed: std140");
static_assert(__builtin_offsetof(Surface, caustics_water_level) == 120, "Surface.caustics_water_level: std140");
static_assert(__builtin_offsetof(Surface, caustics_depth) == 124, "Surface.caustics_depth: std140");

struct ShadowCascades {
    int on;
    char ae_pad0[12];
    float4x4 matrices[4];
    float4 splits;
    float4 texel_world;
    int count;
    char ae_pad1[12];
};
static_assert(sizeof(ShadowCascades) == 320, "ShadowCascades: std140");
static_assert(__builtin_offsetof(ShadowCascades, on) == 0, "ShadowCascades.on: std140");
static_assert(__builtin_offsetof(ShadowCascades, matrices) == 16, "ShadowCascades.matrices: std140");
static_assert(__builtin_offsetof(ShadowCascades, splits) == 272, "ShadowCascades.splits: std140");
static_assert(__builtin_offsetof(ShadowCascades, texel_world) == 288, "ShadowCascades.texel_world: std140");
static_assert(__builtin_offsetof(ShadowCascades, count) == 304, "ShadowCascades.count: std140");

struct Grid {
    float4 dims;
    float4 depth;
    float4x4 view_projection;
    int lamp_base;
    int key_lamp;
    char ae_pad0[8];
};
static_assert(sizeof(Grid) == 112, "Grid: std140");
static_assert(__builtin_offsetof(Grid, dims) == 0, "Grid.dims: std140");
static_assert(__builtin_offsetof(Grid, depth) == 16, "Grid.depth: std140");
static_assert(__builtin_offsetof(Grid, view_projection) == 32, "Grid.view_projection: std140");
static_assert(__builtin_offsetof(Grid, lamp_base) == 96, "Grid.lamp_base: std140");
static_assert(__builtin_offsetof(Grid, key_lamp) == 100, "Grid.key_lamp: std140");

struct Weather {
    int fog;
    float fog_start;
    float fog_end;
    char ae_pad0[4];
    packed_float3 fog_radiance;
    float fog_intensity;
};
static_assert(sizeof(Weather) == 32, "Weather: std140");
static_assert(__builtin_offsetof(Weather, fog) == 0, "Weather.fog: std140");
static_assert(__builtin_offsetof(Weather, fog_start) == 4, "Weather.fog_start: std140");
static_assert(__builtin_offsetof(Weather, fog_end) == 8, "Weather.fog_end: std140");
static_assert(__builtin_offsetof(Weather, fog_radiance) == 16, "Weather.fog_radiance: std140");
static_assert(__builtin_offsetof(Weather, fog_intensity) == 28, "Weather.fog_intensity: std140");

struct DrawBlock {
    Draw draw;
    DrawMaterial material;
    Surface shading;
    Cut cut;
    Wounds wounds;
    Damage damage;
};
static_assert(sizeof(DrawBlock) == 2304, "DrawBlock: std140");
static_assert(__builtin_offsetof(DrawBlock, draw) == 0, "DrawBlock.draw: std140");
static_assert(__builtin_offsetof(DrawBlock, material) == 240, "DrawBlock.material: std140");
static_assert(__builtin_offsetof(DrawBlock, shading) == 368, "DrawBlock.shading: std140");
static_assert(__builtin_offsetof(DrawBlock, cut) == 496, "DrawBlock.cut: std140");
static_assert(__builtin_offsetof(DrawBlock, wounds) == 560, "DrawBlock.wounds: std140");
static_assert(__builtin_offsetof(DrawBlock, damage) == 2192, "DrawBlock.damage: std140");

struct CameraBlock {
    Eye eye;
    ShadowCascades cascades;
    Grid grid;
};
static_assert(sizeof(CameraBlock) == 704, "CameraBlock: std140");
static_assert(__builtin_offsetof(CameraBlock, eye) == 0, "CameraBlock.eye: std140");
static_assert(__builtin_offsetof(CameraBlock, cascades) == 272, "CameraBlock.cascades: std140");
static_assert(__builtin_offsetof(CameraBlock, grid) == 592, "CameraBlock.grid: std140");

struct WorldBlock {
    WorldState world;
    Weather weather;
};
static_assert(sizeof(WorldBlock) == 1424, "WorldBlock: std140");
static_assert(__builtin_offsetof(WorldBlock, world) == 0, "WorldBlock.world: std140");
static_assert(__builtin_offsetof(WorldBlock, weather) == 1392, "WorldBlock.weather: std140");

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

struct MappedNormal {
    float3 normal;
    float variance;
};

struct Frame {
    float3 tangent;
    float3 bitangent;
    float3 normal;
};

struct DirectLight {
    float3 lit;
    float3 back_fill;
};

struct ClusterLamp {
    WorldLight light;
    float reach;
    int slot;
};

struct ae_lit_in {
    float4 ae_frag_coord [[position]];
    float2 fragTexCoord [[user(locn0)]];
    float3 Normal [[user(locn1)]];
    float3 FragPos [[user(locn2)]];
    float3 InstanceColor [[user(locn3)]];
    float Occlusion [[user(locn5)]];
    float4 ClipNow [[user(locn6)]];
    float4 ClipPrev [[user(locn7)]];
    float3 BindPos [[user(locn8)]];
    float ClipLimb [[user(locn9)]];
    float2 MaskUV [[user(locn10)]];
    float ParticleAlpha [[user(locn11)]];
    float3 FlipNext [[user(locn12)]];
};

struct ae_lit_frag_out {
    float4 out_colour [[color(0)]];
    float4 out_velocity [[color(1)]];
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

static float2 ae3d_shaders_lit_velocity(float4 now, float4 prev, float2 nudge) {
    if (now.w <= 0.0 || prev.w <= 0.0) {
        return float2(0.0);
    }
    float2 uv_now = now.xy / now.w * 0.5 + float2(0.5) - nudge;
    float2 uv_prev = prev.xy / prev.w * 0.5 + float2(0.5);
    return uv_now - uv_prev;
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

static float3 ae3d_shaders_lit_black_body(float kelvin) {
    float t = max(kelvin, 500.0) / 100.0;
    float g = t <= 6.6 ? 0.0 : clamp((99.4708025861 * log(t) - 161.1195681661) / 255.0, 0.0, 1.0);
    float b = t <= 19.0 ? 0.0 : clamp((138.5177312231 * log(t - 10.0) - 305.0447927307) / 255.0, 0.0, 1.0);
    return pow(float3(1.0, g, b), float3(2.2));
}

static float ae3d_shaders_lit_soft_fade(constant DrawMaterial& material, constant Eye& eye, texture2d<float> scene_depth, sampler ae_smp_scene_depth, float3 FragPos, float4 ae_frag_coord) {
    if (material.soft <= 0.0 || eye.depth_on != 1) {
        return 1.0;
    }
    float2 suv = ae_frag_coord.xy / eye.screen_size;
    float d = scene_depth.sample(ae_smp_scene_depth, suv).x;
    if (d >= 0.99999) {
        return 1.0;
    }
    float2 sp = suv * 2.0 - float2(1.0);
    float4 clip = float4(float3(sp.x, sp.y, d), 1.0);
    float4 world = (eye.inv_view_projection * clip);
    float3 behind = world.xyz / world.w;
    float gap = distance(eye.position, behind) - distance(eye.position, FragPos);
    return clamp(gap / material.soft, 0.0, 1.0);
}

static float ae3d_shaders_lit_toksvig(float len, float strength) {
    float l = clamp(len, 0.001, 1.0);
    return min((1.0 - l) / l * strength * strength, 1.0);
}

static MappedNormal ae3d_shaders_lit_tri_normal(float3 n, float strength, Tri tri, texture2d<float> normal_map, sampler ae_smp_normal_map) {
    float3 tx0 = normal_map.sample(ae_smp_normal_map, tri.x).xyz * 2.0 - float3(1.0);
    float3 ty0 = normal_map.sample(ae_smp_normal_map, tri.y).xyz * 2.0 - float3(1.0);
    float3 tz0 = normal_map.sample(ae_smp_normal_map, tri.z).xyz * 2.0 - float3(1.0);
    float variance = ae3d_shaders_lit_toksvig(length(tx0) * tri.weights.x + length(ty0) * tri.weights.y + length(tz0) * tri.weights.z, strength);
    float2 txy = tx0.xy * strength;
    float2 tyy = ty0.xy * strength;
    float2 tzy = tz0.xy * strength;
    float3 tx = float3(txy + n.zy, abs(tx0.z) * n.x);
    float3 ty = float3(tyy + n.xz, abs(ty0.z) * n.y);
    float3 tz = float3(tzy + n.xy, abs(tz0.z) * n.z);
    return MappedNormal{normalize(tx.zyx * tri.weights.x + ty.xzy * tri.weights.y + tz * tri.weights.z), variance};
}

static float3 ae3d_shaders_lit_hex_normal(Hex hx, float3 weights, texture2d<float> normal_map, sampler ae_smp_normal_map) {
    float3 s0 = normal_map.sample(ae_smp_normal_map, hx.uv0, gradient2d((hx.turn0 * hx.dx), (hx.turn0 * hx.dy))).xyz * 2.0 - float3(1.0);
    float2 t0 = (transpose(hx.turn0) * s0.xy);
    float3 n0 = float3(0.0) + float3(t0, s0.z) * weights.x;
    float3 s1 = normal_map.sample(ae_smp_normal_map, hx.uv1, gradient2d((hx.turn1 * hx.dx), (hx.turn1 * hx.dy))).xyz * 2.0 - float3(1.0);
    float2 t1 = (transpose(hx.turn1) * s1.xy);
    float3 n1 = n0 + float3(t1, s1.z) * weights.y;
    float3 s2 = normal_map.sample(ae_smp_normal_map, hx.uv2, gradient2d((hx.turn2 * hx.dx), (hx.turn2 * hx.dy))).xyz * 2.0 - float3(1.0);
    float2 t2 = (transpose(hx.turn2) * s2.xy);
    return n1 + float3(t2, s2.z) * weights.z;
}

static Frame ae3d_shaders_lit_cotangent_frame(float3 normal, float3 position, float2 uv) {
    float3 dpx = dfdx(position);
    float3 dpy = dfdy(position);
    float2 duvx = dfdx(uv);
    float2 duvy = dfdy(uv);
    float3 perp_y = cross(dpy, normal);
    float3 perp_x = cross(normal, dpx);
    float3 tangent = perp_y * duvx.x + perp_x * duvy.x;
    float3 bitangent = perp_y * duvx.y + perp_x * duvy.y;
    float handed = dot(dpx, perp_y) < 0.0 ? -1.0 : 1.0;
    float scale = handed * rsqrt(max(dot(tangent, tangent), dot(bitangent, bitangent)));
    return Frame{tangent * scale, bitangent * scale, normal};
}

static MappedNormal ae3d_shaders_lit_mapped_normal(float3 normal, float3 position, float2 uv, int tri_on, Tri tri, int hex_on, Hex hx, float3 weights, float detail_weight, constant WorldState& world, constant DrawMaterial& material, texture2d<float> normal_map, sampler ae_smp_normal_map) {
    float strength = world.normal_strength * material.normal_strength;
    if (tri_on != 0) {
        return ae3d_shaders_lit_tri_normal(normal, strength, tri, normal_map, ae_smp_normal_map);
    }
    float3 sampled0 = hex_on != 0 ? ae3d_shaders_lit_hex_normal(hx, weights, normal_map, ae_smp_normal_map) : normal_map.sample(ae_smp_normal_map, uv).xyz * 2.0 - float3(1.0);
    float variance = ae3d_shaders_lit_toksvig(length(sampled0), strength);
    float3 sampled1 = sampled0;
    if (detail_weight > 0.0) {
        float3 fine = normal_map.sample(ae_smp_normal_map, (uv * material.detail_scale)).xyz * 2.0 - float3(1.0);
        sampled1 = float3(sampled0.xy + fine.xy * detail_weight, sampled0.z);
    }
    float2 sxy = sampled1.xy * strength;
    float3 sampled = float3(sxy, sampled1.z);
    Frame fr = ae3d_shaders_lit_cotangent_frame(normal, position, uv);
    return MappedNormal{normalize((float3x3(fr.tangent, fr.bitangent, fr.normal) * sampled)), variance};
}

static float ae3d_shaders_lit_splat_cover(float3 p, constant Wounds& wounds) {
    float most = 0.0;
    for (int i = 0; i < 32; i += 1) {
        if (i >= wounds.count) {
            break;
        }
        if (wounds.data[i * 3].w < 0.5) {
            continue;
        }
        float3 r = max(wounds.data[i * 3 + 1].xyz, float3(0.0001));
        float3 local = ae3d_shaders_lit_wound_unturn(wounds.data[i * 3 + 2], p - wounds.data[i * 3].xyz) / r;
        float edge = 1.0 + 0.35 * (ae3d_shaders_lit_clip_value_noise(local * 3.0 + wounds.data[i * 3].xyz * 7.0) * 2.0 - 1.0);
        float cover = wounds.data[i * 3 + 1].w * (1.0 - smoothstep(0.8 * edge, edge, length(local)));
        most = max(most, cover);
    }
    return most;
}

static float ae3d_shaders_lit_fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

static int ae3d_shaders_lit_lattice_hash(int x, int y, int z) {
    int n0 = x + y * 57 + z * 113;
    int n = n0 << 13 ^ n0;
    return abs(n * (n * n * 15731 + 789221) + 1376312589) & 255;
}

static float3 ae3d_shaders_lit_get_gradient(int hashed) {
    int h = hashed & 15;
    float u = h < 8 ? 1.0 : -1.0;
    float v = (h & 1) == 0 ? 1.0 : -1.0;
    float w = (h & 2) == 0 ? 1.0 : -1.0;
    if (h < 4) {
        return float3(u, v, 0.0);
    } else if (h < 8) {
        return float3(u, 0.0, w);
    } else if (h < 12) {
        return float3(0.0, v, w);
    } else {
        return float3(u, v, w);
    }
}

static float ae3d_shaders_lit_lerp(float t, float a, float b) {
    return a + t * (b - a);
}

static float ae3d_shaders_lit_perlin_noise3d(float3 p) {
    int ix = int(floor(p.x));
    int iy = int(floor(p.y));
    int iz = int(floor(p.z));
    float3 f = p - float3(float(ix), float(iy), float(iz));
    float3 u = float3(ae3d_shaders_lit_fade(f.x), ae3d_shaders_lit_fade(f.y), ae3d_shaders_lit_fade(f.z));
    int n000 = ae3d_shaders_lit_lattice_hash(ix, iy, iz);
    int n001 = ae3d_shaders_lit_lattice_hash(ix, iy, iz + 1);
    int n010 = ae3d_shaders_lit_lattice_hash(ix, iy + 1, iz);
    int n011 = ae3d_shaders_lit_lattice_hash(ix, iy + 1, iz + 1);
    int n100 = ae3d_shaders_lit_lattice_hash(ix + 1, iy, iz);
    int n101 = ae3d_shaders_lit_lattice_hash(ix + 1, iy, iz + 1);
    int n110 = ae3d_shaders_lit_lattice_hash(ix + 1, iy + 1, iz);
    int n111 = ae3d_shaders_lit_lattice_hash(ix + 1, iy + 1, iz + 1);
    float d000 = dot(ae3d_shaders_lit_get_gradient(n000), f);
    float d001 = dot(ae3d_shaders_lit_get_gradient(n001), f - float3(0.0, 0.0, 1.0));
    float d010 = dot(ae3d_shaders_lit_get_gradient(n010), f - float3(0.0, 1.0, 0.0));
    float d011 = dot(ae3d_shaders_lit_get_gradient(n011), f - float3(0.0, 1.0, 1.0));
    float d100 = dot(ae3d_shaders_lit_get_gradient(n100), f - float3(1.0, 0.0, 0.0));
    float d101 = dot(ae3d_shaders_lit_get_gradient(n101), f - float3(1.0, 0.0, 1.0));
    float d110 = dot(ae3d_shaders_lit_get_gradient(n110), f - float3(1.0, 1.0, 0.0));
    float d111 = dot(ae3d_shaders_lit_get_gradient(n111), f - float3(1.0, 1.0, 1.0));
    return ae3d_shaders_lit_lerp(u.z, ae3d_shaders_lit_lerp(u.y, ae3d_shaders_lit_lerp(u.x, d000, d100), ae3d_shaders_lit_lerp(u.x, d010, d110)), ae3d_shaders_lit_lerp(u.y, ae3d_shaders_lit_lerp(u.x, d001, d101), ae3d_shaders_lit_lerp(u.x, d011, d111)));
}

static float ae3d_shaders_lit_turbulence(float3 p, int octaves) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float most = 0.0;
    for (int i = 0; i < octaves && i < 8; i += 1) {
        value = value + ae3d_shaders_lit_perlin_noise3d(p * frequency) * amplitude;
        most = most + amplitude;
        amplitude = amplitude * 0.5;
        frequency = frequency * 2.0;
    }
    return value / most;
}

static float ae3d_shaders_lit_cascade_lit(int c, float3 surface, float slope, constant ShadowCascades& cascades, float3 FragPos, texture2d<float> shadow_map, sampler ae_smp_shadow_map, constant Surface& shading) {
    float4 light_space = (cascades.matrices[c] * float4(FragPos + surface * cascades.texel_world[c] * (1.0 + slope), 1.0));
    float3 projected = light_space.xyz / light_space.w;
    float2 pxy = projected.xy * 0.5 + float2(0.5);
    float pz = projected.z;
    if (pz > 1.0) {
        return 1.0;
    }
    if (pxy.x < 0.0 || pxy.x > 1.0 || pxy.y < 0.0 || pxy.y > 1.0) {
        return 1.0;
    }
    float2 texel = float2(1.0) / float2(float(shadow_map.get_width()), float(shadow_map.get_height()));
    float radius = max(shading.shadow_softness, 1.0);
    float2 tile = float2(float((c % 2)), float((c / 2))) * 0.5;
    float2 centre = tile + pxy * 0.5;
    float2 lo = tile + texel * (radius + 0.5);
    float2 hi = tile + float2(0.5) - texel * (radius + 0.5);
    float bias = radius / (float2(float(shadow_map.get_width()), float(shadow_map.get_height())).x * 0.5);
    float lit = 0.0;
    for (int sx = -1; sx <= 1; sx += 1) {
        for (int sy = -1; sy <= 1; sy += 1) {
            float2 at = clamp(centre + float2(float(sx), float(sy)) * texel * radius, lo, hi);
            float closest = shadow_map.sample(ae_smp_shadow_map, at).x;
            lit = lit + (pz - bias > closest ? 0.0 : 1.0);
        }
    }
    return lit / 9.0;
}

static float ae3d_shaders_lit_shadow_factor(float3 Normal, constant WorldState& world, constant Eye& eye, float3 FragPos, constant ShadowCascades& cascades, constant Surface& shading, texture2d<float> shadow_map, sampler ae_smp_shadow_map) {
    float3 surface = normalize(Normal);
    float3 to_light = normalize(-world.shadow_direction);
    float facing = max(dot(surface, to_light), 0.0);
    float slope = min(sqrt(1.0 - facing * facing) / max(facing, 0.02), 32.0);
    float depth = dot(eye.depth_plane.xyz, FragPos) + eye.depth_plane.w;
    int c = -1;
    for (int i = 0; i < 4; i += 1) {
        if (i < cascades.count && depth <= cascades.splits[i]) {
            c = i;
            break;
        }
    }
    if (c < 0) {
        return 1.0;
    }
    float lit = ae3d_shaders_lit_cascade_lit(c, surface, slope, cascades, FragPos, shadow_map, ae_smp_shadow_map, shading);
    if (c + 1 < cascades.count) {
        float start = c == 0 ? 0.0 : cascades.splits[(c - 1)];
        float band = (cascades.splits[c] - start) * 0.1;
        float into = (cascades.splits[c] - depth) / max(band, 0.0001);
        if (into < 1.0) {
            lit = mix(ae3d_shaders_lit_cascade_lit(c + 1, surface, slope, cascades, FragPos, shadow_map, ae_smp_shadow_map, shading), lit, into);
        }
    }
    return mix(shading.shadow_intensity, 1.0, lit);
}

static float ae3d_shaders_lit_lamp_distance(float depth, float near, float far) {
    return near * far / (far - depth * (far - near));
}

static float ae3d_shaders_lit_lamp_shadow(int slot, float3 surface, constant Grid& grid, const device float4* cluster_lights, float3 FragPos, texture2d<float> lamp_shadow_map, sampler ae_smp_lamp_shadow_map, constant Surface& shading) {
    int base = grid.lamp_base + slot * 26;
    float4 head = cluster_lights[base];
    float4 more = cluster_lights[(base + 1)];
    float3 v = FragPos - head.xyz;
    float far = head.w;
    float strength = more.x;
    float near = more.y;
    float3 a = abs(v);
    int face = 0;
    float along = 0.0;
    if (a.x >= a.y && a.x >= a.z) {
        face = v.x > 0.0 ? 0 : 1;
        along = a.x;
    } else if (a.y >= a.z) {
        face = v.y > 0.0 ? 2 : 3;
        along = a.y;
    } else {
        face = v.z > 0.0 ? 4 : 5;
        along = a.z;
    }
    if (strength <= 0.0 || along >= far || along <= near) {
        return 1.0;
    }
    float3 to_lamp = -v / max(length(v), 0.0001);
    float facing = max(dot(surface, to_lamp), 0.0);
    float slope = min(sqrt(1.0 - facing * facing) / max(facing, 0.02), 32.0);
    float texel_world = 2.0 * along / 512.0;
    int m = base + 2 + face * 4;
    float4x4 face_matrix = float4x4(cluster_lights[m], cluster_lights[(m + 1)], cluster_lights[(m + 2)], cluster_lights[(m + 3)]);
    float4 light_space = (face_matrix * float4(FragPos + surface * texel_world * (1.0 + slope), 1.0));
    float3 projected = light_space.xyz / light_space.w;
    float2 pxy = clamp(projected.xy * 0.5 + float2(0.5), float2(0.0), float2(1.0));
    float mine = ae3d_shaders_lit_lamp_distance(projected.z, near, far);
    int tile = slot * 6 + face;
    float share = 1.0 / 8.0;
    float2 origin = float2(float((tile % 8)), float((tile / 8))) * share;
    float2 texel = float2(1.0) / float2(float(lamp_shadow_map.get_width()), float(lamp_shadow_map.get_height()));
    float radius = max(shading.shadow_softness, 1.0);
    float2 centre = origin + pxy * share;
    float2 lo = origin + texel * (radius + 0.5);
    float2 hi = origin + float2(share) - texel * (radius + 0.5);
    float bias = texel_world * 1.5;
    float lit = 0.0;
    for (int sx = -1; sx <= 1; sx += 1) {
        for (int sy = -1; sy <= 1; sy += 1) {
            float2 at = clamp(centre + float2(float(sx), float(sy)) * texel * radius, lo, hi);
            float closest = ae3d_shaders_lit_lamp_distance(lamp_shadow_map.sample(ae_smp_lamp_shadow_map, at).x, near, far);
            lit = lit + (mine - bias > closest ? 0.0 : 1.0);
        }
    }
    return mix(1.0, mix(shading.shadow_intensity, 1.0, lit / 9.0), strength);
}

static float ae3d_shaders_lit_cloud_coverage_from(float2 weather, float cover) {
    float threshold = 1.0 - cover * (0.45 + 1.1 * weather.y);
    return smoothstep(threshold, threshold + 0.5, weather.x) * 0.9;
}

static float ae3d_shaders_lit_cloud_hash(float3 p) {
    uint vx = uint(int(floor(p.x)));
    uint vy = uint(int(floor(p.y)));
    uint vz = uint(int(floor(p.z)));
    vx = vx * 0x5F356495;
    vy = vy * uint(-482951495);
    vz = vz * uint(-1496170881);
    uint n5 = (vx ^ vy ^ vz) * 0x5F356495;
    n5 = n5 ^ n5 >> 16u;
    n5 = n5 * 0x7FEB352D;
    n5 = n5 ^ n5 >> 15u;
    n5 = n5 * uint(-2073254261);
    n5 = n5 ^ n5 >> 16u;
    return float(n5) * (1.0 / 4294967296.0);
}

static float ae3d_shaders_lit_cloud_noise2(float2 x, float period, float seed) {
    float2 i = floor(x);
    float2 f0 = fract(x);
    float2 f = f0 * f0 * (float2(3.0) - f0 * 2.0);
    float2 i0 = ae_mod(i, period);
    float2 i1 = ae_mod(i + float2(1.0), period);
    float a = ae3d_shaders_lit_cloud_hash(float3(i0.x, i0.y, seed));
    float b = ae3d_shaders_lit_cloud_hash(float3(i1.x, i0.y, seed));
    float c = ae3d_shaders_lit_cloud_hash(float3(i0.x, i1.y, seed));
    float d = ae3d_shaders_lit_cloud_hash(float3(i1.x, i1.y, seed));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static float2 ae3d_shaders_lit_cloud_weather_at(float2 uv) {
    float shape = 0.0;
    float amp = 0.5;
    float freq = 6.0;
    for (int o = 0; o < 5; o += 1) {
        shape = shape + amp * ae3d_shaders_lit_cloud_noise2(uv * freq, freq, float((41 + o * 17)));
        amp = amp * 0.5;
        freq = freq * 2.0;
    }
    float shaped = clamp((shape - 0.3) / 0.4, 0.0, 1.0);
    float bank = ae3d_shaders_lit_cloud_noise2(uv * 3.0, 3.0, 8.0);
    return float2(shaped, bank);
}

static float2 ae3d_shaders_lit_cloud_weather_uv(float2 at, float t) {
    return at / 24000.0 + float2(t * 0.00012, t * 0.00004);
}

static float ae3d_shaders_lit_cloud_coverage(float2 at, float cover, float t) {
    return ae3d_shaders_lit_cloud_coverage_from(ae3d_shaders_lit_cloud_weather_at(ae3d_shaders_lit_cloud_weather_uv(at, t)), cover);
}

static float ae3d_shaders_lit_cloud_shadow(float3 world_pos, constant WorldState& world) {
    if (world.cloud_cover <= 0.0 || world.cloud_sun.y <= 0.05) {
        return 1.0;
    }
    float3 sun = normalize(world.cloud_sun);
    float up = (1400.0 + (2600.0 - 1400.0) * 0.35 - world_pos.y) / max(sun.y, 0.05);
    float2 at = world_pos.xz + sun.xz * up;
    return 1.0 - 0.65 * ae3d_shaders_lit_cloud_coverage(at, world.cloud_cover, world.cloud_time);
}

static float3 ae3d_shaders_lit_kelvin_to_rgb(float kelvin_in) {
    float kelvin = clamp(kelvin_in, 1000.0, 12000.0);
    if (kelvin < 3000.0) {
        return mix(float3(1.0, 0.4, 0.0), float3(1.0, 0.7, 0.3), (kelvin - 1000.0) / 2000.0);
    } else if (kelvin < 6500.0) {
        return mix(float3(1.0, 0.7, 0.3), float3(1.0, 1.0, 1.0), (kelvin - 3000.0) / 3500.0);
    } else {
        return mix(float3(1.0, 1.0, 1.0), float3(0.7, 0.8, 1.0), (kelvin - 6500.0) / 5500.0);
    }
}

static float ae3d_shaders_lit_distribution_ggx(float3 n, float3 h, float rough) {
    float a = rough * rough;
    float a2 = a * a;
    float ndoth = max(dot(n, h), 0.0);
    float ndoth2 = ndoth * ndoth;
    float num = a2;
    float denom0 = ndoth2 * (a2 - 1.0) + 1.0;
    float denom = 3.14159265359 * denom0 * denom0;
    float result = num / denom;
    return min(result, 10.0);
}

static float ae3d_shaders_lit_geometry_schlick_ggx(float ndotv, float rough) {
    float r = rough + 1.0;
    float k = r * r / 8.0;
    float num = ndotv;
    float denom = ndotv * (1.0 - k) + k;
    return num / denom;
}

static float ae3d_shaders_lit_geometry_smith(float3 n, float3 v, float3 l, float rough) {
    float ndotv = max(dot(n, v), 0.0);
    float ndotl = max(dot(n, l), 0.0);
    float ggx2 = ae3d_shaders_lit_geometry_schlick_ggx(ndotv, rough);
    float ggx1 = ae3d_shaders_lit_geometry_schlick_ggx(ndotl, rough);
    return ggx1 * ggx2;
}

static float3 ae3d_shaders_lit_fresnel_schlick(float cos_theta, float3 f0) {
    float inv = clamp(1.0 - cos_theta, 0.0, 1.0);
    float inv2 = inv * inv;
    float inv5 = inv2 * inv2 * inv;
    return f0 + (float3(1.0) - f0) * inv5;
}

static float3 ae3d_shaders_lit_calculate_clearcoat(float3 n, float3 v, float3 l, float3 h, float3 base_colour, constant Surface& shading) {
    if (shading.clearcoat == 0) {
        return float3(0.0);
    }
    float ndf = ae3d_shaders_lit_distribution_ggx(n, h, shading.clearcoat_roughness);
    float g = ae3d_shaders_lit_geometry_smith(n, v, l, shading.clearcoat_roughness);
    float3 f = ae3d_shaders_lit_fresnel_schlick(max(dot(h, v), 0.0), float3(0.04));
    float3 specular = f * (ndf * g) / (4.0 * max(dot(n, v), 0.0) * max(dot(n, l), 0.0) + 0.001);
    return specular * shading.clearcoat_intensity;
}

static float3 ae3d_shaders_lit_calculate_sheen(float3 n, float3 v, float3 l, float3 h, constant Surface& shading) {
    if (shading.sheen == 0) {
        return float3(0.0);
    }
    float ndoth = max(dot(n, h), 0.0);
    float d = (2.0 + shading.sheen_roughness) * pow(ndoth, shading.sheen_roughness) / (2.0 * 3.14159265359);
    return shading.sheen_colour * d * 0.25;
}

static float3 ae3d_shaders_lit_calculate_transmission(float3 n, float3 v, float3 l, float3 base_colour, constant Surface& shading) {
    if (shading.transmission == 0) {
        return float3(0.0);
    }
    float ndotv = max(dot(n, v), 0.0);
    float ndotl = max(dot(n, l), 0.0);
    float f0 = 0.04;
    float fresnel = f0 + (1.0 - f0) * pow(1.0 - ndotv, 5.0);
    float transmission = (1.0 - fresnel) * shading.transmission_factor;
    float3 transmitted = base_colour * transmission * ndotl;
    float3 scattering = base_colour * transmission * 0.1;
    return transmitted + scattering;
}

static float3 ae3d_shaders_lit_compensate_energy_loss(float3 colour, float ndotv, float rough, constant Surface& shading) {
    if (shading.multiple_scattering == 0) {
        return colour;
    }
    float compensation = 1.0 + rough * (1.0 - ndotv) * 0.2;
    return colour * compensation;
}

static float3 ae3d_shaders_lit_apply_energy_conservation(float3 diffuse, float3 specular, float3 clearcoat, float3 sheen, constant Surface& shading) {
    if (shading.energy_conservation == 0) {
        return diffuse + specular + clearcoat + sheen;
    }
    float3 total = diffuse + specular + clearcoat + sheen;
    float most = max(max(total.x, total.y), total.z);
    if (most > 1.0) {
        return total / most;
    }
    return total;
}

static DirectLight ae3d_shaders_lit_direct_light(WorldLight l, float3 norm, float3 view_dir, float3 albedo, float3 f0, float ndotv, float adjusted_roughness, float wet_mirror, float3 FragPos, constant DrawMaterial& material, constant Surface& shading) {
    float3 adjusted_colour = l.colour * ae3d_shaders_lit_kelvin_to_rgb(l.temperature);
    float3 light_dir = float3(0.0);
    float attenuation = 1.0;
    if (l.kind == 1) {
        light_dir = normalize(l.direction);
    } else {
        float3 light_vec = l.position - FragPos;
        float dist = length(light_vec);
        light_dir = light_vec / dist;
        attenuation = 1.0 / (l.constant_ + l.linear * dist + l.quadratic * dist * dist);
        if (l.kind == 2) {
            float on_axis = dot(-light_dir, normalize(l.direction));
            attenuation = attenuation * smoothstep(l.cos_outer, l.cos_inner, on_axis);
        }
    }
    float3 halfway = normalize(light_dir + view_dir);
    float3 radiance = adjusted_colour * l.intensity * attenuation;
    float ndotl_raw = dot(norm, light_dir);
    float hdotv = clamp(dot(halfway, view_dir), 0.001, 1.0);
    float ndotl = max(ndotl_raw, 0.0);
    float ndf = ae3d_shaders_lit_distribution_ggx(norm, halfway, adjusted_roughness);
    float g = ae3d_shaders_lit_geometry_smith(norm, view_dir, light_dir, adjusted_roughness);
    float3 f = ae3d_shaders_lit_fresnel_schlick(hdotv, f0);
    float3 ks = f;
    float3 kd0 = float3(1.0) - ks;
    float3 kd = kd0 * (1.0 - material.metallic);
    float3 numerator = f * (ndf * g);
    float denominator = 4.0 * ndotv * ndotl + 0.0001;
    float3 specular0 = numerator / denominator;
    float view_attenuation = pow(ndotv, 0.6);
    float mirror = max(material.reflectivity, wet_mirror);
    float3 specular1 = specular0;
    if (mirror > 0.001) {
        float grazing = 1.0 - ndotv;
        specular1 = specular0 * (mirror * (0.5 + grazing * grazing * 4.0));
    } else {
        specular1 = specular0 * (view_attenuation * 0.5);
    }
    float3 clearcoat = ae3d_shaders_lit_calculate_clearcoat(norm, view_dir, light_dir, halfway, albedo, shading);
    float3 sheen = ae3d_shaders_lit_calculate_sheen(norm, view_dir, light_dir, halfway, shading);
    float3 transmission = ae3d_shaders_lit_calculate_transmission(norm, view_dir, light_dir, albedo, shading);
    float3 specular = ae3d_shaders_lit_compensate_energy_loss(specular1, ndotv, material.roughness, shading);
    float hemisphere = max(ndotl_raw, 0.0);
    float fill = max(-ndotl_raw * 0.3, 0.0);
    float3 back_fill = adjusted_colour * fill * albedo * 0.2 * attenuation;
    float3 lit = ae3d_shaders_lit_apply_energy_conservation(kd * albedo / 3.14159265359 * radiance * hemisphere, specular * radiance * hemisphere, clearcoat * radiance * hemisphere, sheen * radiance * hemisphere, shading) + transmission;
    return DirectLight{lit, back_fill};
}

static float3 ae3d_shaders_lit_glitter(float3 n, float3 v, WorldLight l_in, float3 FragPos, constant DrawMaterial& material) {
    float3 grid = FragPos * material.glitter_grains;
    float footprint = max(length(fwidth(grid)), 1e-4);
    float level_ = max(ceil(log2(footprint)), 0.0);
    if (level_ > 7.0) {
        return float3(0.0);
    }
    float scale = exp2(level_);
    float3 cell = floor(grid / scale);
    float3 h = fract(sin(float3(dot(cell, float3(127.1, 311.7, 74.7)), dot(cell, float3(269.5, 183.3, 246.1)), dot(cell, float3(113.5, 271.9, 124.6)))) * 43758.5453);
    float chance = min(material.glitter * scale * scale, 1.0);
    if (h.x > chance) {
        return float3(0.0);
    }
    float3 l = normalize(l_in.direction);
    float lit = max(dot(n, l), 0.0);
    if (lit <= 0.0) {
        return float3(0.0);
    }
    float3 k = fract(h * 13.731 + h.yzx * 7.17);
    float3 facet = normalize(n * 0.6 + (k * 2.0 - float3(1.0)));
    float flash = pow(max(dot(facet, normalize(l + v)), 0.0), 900.0);
    return l_in.colour * ae3d_shaders_lit_kelvin_to_rgb(l_in.temperature) * l_in.intensity * flash * lit * material.glitter_strength / (scale * scale);
}

static int ae3d_shaders_lit_cluster_of(float3 p, constant Grid& grid, constant Eye& eye) {
    float4 clip = (grid.view_projection * float4(p, 1.0));
    float w = clip.w != 0.0 ? clip.w : 1.0;
    float2 ndc = clip.xy / w;
    float depth = dot(eye.depth_plane.xyz, p) + eye.depth_plane.w;
    float3 dims = grid.dims.xyz + float3(0.5);
    int dx = int(dims.x);
    int dy = int(dims.y);
    int dz = int(dims.z);
    int x = clamp(int(floor((ndc.x * 0.5 + 0.5) * float(dx))), 0, dx - 1);
    int y = clamp(int(floor((ndc.y * 0.5 + 0.5) * float(dy))), 0, dy - 1);
    int z = 0;
    if (depth > grid.depth.x) {
        z = clamp(int(floor(log(depth) * grid.depth.z + grid.depth.w)), 0, dz - 1);
    }
    return (z * dy + y) * dx + x;
}

static ClusterLamp ae3d_shaders_lit_clustered_light(int i, const device float4* cluster_lights) {
    float4 a = cluster_lights[(i * 5)];
    float4 b = cluster_lights[(i * 5 + 1)];
    float4 c = cluster_lights[(i * 5 + 2)];
    float4 d = cluster_lights[(i * 5 + 3)];
    float4 e = cluster_lights[(i * 5 + 4)];
    return ClusterLamp{ae_make_WorldLight(a.xyz, b.rgb, b.w, d.w, int((c.w + 0.5)), c.xyz, d.x, d.y, d.z, e.x, e.y), a.w, int(floor(e.z + 0.5))};
}

static float ae3d_shaders_lit_screen_occlusion(constant Eye& eye, float4 ClipPrev, texture2d<float> occlusion_map, sampler ae_smp_occlusion_map) {
    if (eye.history == 0 || ClipPrev.w <= 0.0) {
        return 1.0;
    }
    float2 uv = ClipPrev.xy / ClipPrev.w * 0.5 + float2(0.5);
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return 1.0;
    }
    float2 found = occlusion_map.sample(ae_smp_occlusion_map, uv).xy;
    if (abs(found.y - ClipPrev.w) > 0.05 * ClipPrev.w) {
        return 1.0;
    }
    return found.x;
}

static float2 ae3d_shaders_lit_oct_encode(float3 d_in) {
    float3 d = d_in / (abs(d_in.x) + abs(d_in.y) + abs(d_in.z));
    float2 p = d.xz;
    if (d.y < 0.0) {
        p = (float2(1.0) - abs(p.yx)) * float2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);
    }
    return p;
}

static float2 ae3d_shaders_lit_oct_uv(float3 d, float size) {
    return ((ae3d_shaders_lit_oct_encode(d) * 0.5 + float2(0.5)) * (size - 2.0) + float2(1.0)) / size;
}

static float3 ae3d_shaders_lit_sky_irradiance(float3 n, texture2d<float> sky_irradiance, sampler ae_smp_sky_irradiance) {
    return sky_irradiance.sample(ae_smp_sky_irradiance, ae3d_shaders_lit_oct_uv(n, 16.0)).rgb;
}

static float3 ae3d_shaders_lit_sky_reflection(float3 r, float rough, texture2d<float> sky_light, sampler ae_smp_sky_light) {
    float level_ = clamp(rough, 0.0, 1.0) * (6.0 - 1.0);
    return sky_light.sample(ae_smp_sky_light, ae3d_shaders_lit_oct_uv(r, 256.0), level(level_)).rgb;
}

static float3 ae3d_shaders_lit_sky_lit(float3 n, float3 v, float3 albedo, float3 f0, float rough, float metal_, float ndotv, constant WorldState& world, constant Surface& shading, texture2d<float> sky_irradiance, sampler ae_smp_sky_irradiance, texture2d<float> sky_light, sampler ae_smp_sky_light, texture2d<float> brdf_lut, sampler ae_smp_brdf_lut) {
    if (world.gi_off != 0) {
        return float3(0.0);
    }
    float3 f = f0 + (max(float3(1.0 - rough), f0) - f0) * pow(1.0 - ndotv, 5.0);
    float3 kd = (float3(1.0) - f) * (1.0 - metal_);
    float3 irradiance = ae3d_shaders_lit_sky_irradiance(n, sky_irradiance, ae_smp_sky_irradiance);
    float3 diffuse = kd * albedo * irradiance / 3.14159265;
    if (shading.ibl == 0) {
        return diffuse;
    }
    float2 ab = brdf_lut.sample(ae_smp_brdf_lut, float2(ndotv, rough)).xy;
    float3 specular = ae3d_shaders_lit_sky_reflection(reflect(-v, n), rough, sky_light, ae_smp_sky_light) * (f0 * ab.x + float3(ab.y));
    return diffuse + specular * shading.ibl_intensity;
}

static float3 ae3d_shaders_lit_calculate_volumetric_lighting(float3 world_pos, float3 light_pos, float3 view_pos, constant Surface& shading, constant WorldState& world) {
    if (shading.volumetric == 0) {
        return float3(0.0);
    }
    float3 to_surface = world_pos - view_pos;
    float ray_length = length(to_surface);
    if (ray_length < 0.001) {
        return float3(0.0);
    }
    float3 ray_dir = to_surface / ray_length;
    int steps = clamp(shading.volumetric_steps, 8, 32);
    float3 tint = world.lights[0].colour * ae3d_shaders_lit_kelvin_to_rgb(world.lights[0].temperature);
    float scatter = 0.0;
    float step_size = ray_length / float(steps);
    for (int i = 0; i < steps && i < 32; i += 1) {
        float3 sample_pos = view_pos + ray_dir * (step_size * (float(i) + 0.5));
        float d = length(light_pos - sample_pos);
        scatter = scatter + step_size / (1.0 + d * d * shading.volumetric_scattering);
    }
    return tint * scatter * shading.volumetric_intensity;
}

static float ae3d_shaders_lit_caustic_web(float2 uv, float t, constant Surface& shading) {
    float2 drift = float2(0.7, 0.3) * shading.caustics_speed * t;
    float a = ae3d_shaders_lit_perlin_noise3d(float3(uv + drift, t * shading.caustics_speed * 0.5));
    float b = ae3d_shaders_lit_perlin_noise3d(float3(uv * 1.7 - drift * 0.8, t * shading.caustics_speed * 0.4 + 5.3));
    return pow(clamp(1.0 - abs(a - b) * 3.0, 0.0, 1.0), 8.0);
}

static float3 ae3d_shaders_lit_caustic_light(float3 world_pos, float3 norm, constant Surface& shading, constant WorldState& world) {
    if (shading.caustics == 0) {
        return float3(0.0);
    }
    float depth = shading.caustics_water_level - world_pos.y;
    if (depth <= 0.0) {
        return float3(0.0);
    }
    float2 uv = world_pos.xz * shading.caustics_scale;
    float t = world.time;
    float2 fringe = float2(0.006, 0.004);
    float red = ae3d_shaders_lit_caustic_web(uv + fringe, t, shading) + 0.5 * ae3d_shaders_lit_caustic_web(uv * 2.3 + fringe * 2.0 + float2(11.0), t, shading);
    float green = ae3d_shaders_lit_caustic_web(uv, t, shading) + 0.5 * ae3d_shaders_lit_caustic_web(uv * 2.3 + float2(11.0), t, shading);
    float blue = ae3d_shaders_lit_caustic_web(uv - fringe, t, shading) + 0.5 * ae3d_shaders_lit_caustic_web(uv * 2.3 - fringe * 2.0 + float2(11.0), t, shading);
    float3 web = float3(red, green, blue);
    float facing = clamp(norm.y, 0.0, 1.0);
    float attenuation = exp(-depth / max(shading.caustics_depth, 0.001));
    float3 key = world.lights[0].colour * ae3d_shaders_lit_kelvin_to_rgb(world.lights[0].temperature);
    return key * world.lights[0].intensity * web * facing * attenuation * shading.caustics_intensity;
}

static float ae3d_shaders_lit_ember_hash(float3 c) {
    return fract(sin(dot(c, float3(41.3, 289.1, 157.7))) * 43758.5453);
}

static float ae3d_shaders_lit_ember_noise(float3 p) {
    float3 i = floor(p);
    float3 f0 = p - i;
    float3 f = f0 * f0 * (float3(3.0) - f0 * 2.0);
    float a = mix(mix(ae3d_shaders_lit_ember_hash(i), ae3d_shaders_lit_ember_hash(i + float3(1.0, 0.0, 0.0)), f.x), mix(ae3d_shaders_lit_ember_hash(i + float3(0.0, 1.0, 0.0)), ae3d_shaders_lit_ember_hash(i + float3(1.0, 1.0, 0.0)), f.x), f.y);
    float b = mix(mix(ae3d_shaders_lit_ember_hash(i + float3(0.0, 0.0, 1.0)), ae3d_shaders_lit_ember_hash(i + float3(1.0, 0.0, 1.0)), f.x), mix(ae3d_shaders_lit_ember_hash(i + float3(0.0, 1.0, 1.0)), ae3d_shaders_lit_ember_hash(i + float3(1.0, 1.0, 1.0)), f.x), f.y);
    return mix(a, b, f.z);
}

static float3 ae3d_shaders_lit_ember_light(float3 FragPos, constant WorldState& world, constant DrawMaterial& material) {
    float3 p = FragPos * 20.0;
    float3 i = floor(p);
    float3 f = p - i;
    float f1 = 8.0;
    float f2 = 8.0;
    float3 nearest = i;
    for (int z = -1; z <= 1; z += 1) {
        for (int y = -1; y <= 1; y += 1) {
            for (int x = -1; x <= 1; x += 1) {
                float3 o = float3(float(x), float(y), float(z));
                float3 c = i + o;
                float3 h = fract(sin(float3(dot(c, float3(127.1, 311.7, 74.7)), dot(c, float3(269.5, 183.3, 246.1)), dot(c, float3(113.5, 271.9, 124.6)))) * 43758.5453);
                float d = length(o + h - f);
                if (d < f1) {
                    f2 = f1;
                    f1 = d;
                    nearest = c;
                } else if (d < f2) {
                    f2 = d;
                }
            }
        }
    }
    float crack = 1.0 - smoothstep(0.0, 0.07, f2 - f1);
    float hn = ae3d_shaders_lit_ember_hash(nearest);
    float hot = ae3d_shaders_lit_ember_noise(nearest * 0.2) * 0.75 + hn * 0.25;
    float breath = 0.75 + 0.25 * sin(world.time * (0.9 + hn * 1.6) + hn * 37.0);
    float heat = crack * 0.3;
    if (hot < material.ember_cover) {
        heat = mix(0.55, 1.0, crack) * breath * (0.8 + 0.2 * ae3d_shaders_lit_ember_noise(p * 0.7));
    }
    float h2 = heat * heat;
    return ae3d_shaders_lit_black_body(heat * material.embers) * (h2 * h2) * material.ember_glow;
}

fragment ae_lit_frag_out ae_lit_fragment(
    ae_lit_in ae_in [[stage_in]],
    constant DrawBlock& ae_set0 [[buffer(0)]],
    constant CameraBlock& ae_set1 [[buffer(1)]],
    constant WorldBlock& ae_set2 [[buffer(4)]],
    texture2d<float> colour_map [[texture(0)]], sampler ae_smp_colour_map [[sampler(0)]],
    texture2d<float> scene_depth [[texture(2)]], sampler ae_smp_scene_depth [[sampler(2)]],
    texture2d<float> normal_map [[texture(1)]], sampler ae_smp_normal_map [[sampler(1)]],
    texture2d<float> damage_mask [[texture(3)]], sampler ae_smp_damage_mask [[sampler(3)]],
    texture2d<float> shadow_map [[texture(4)]], sampler ae_smp_shadow_map [[sampler(4)]],
    texture2d<float> lamp_shadow_map [[texture(5)]], sampler ae_smp_lamp_shadow_map [[sampler(5)]],
    texture2d<float> occlusion_map [[texture(6)]], sampler ae_smp_occlusion_map [[sampler(6)]],
    texture2d<float> sky_irradiance [[texture(9)]], sampler ae_smp_sky_irradiance [[sampler(9)]],
    texture2d<float> sky_light [[texture(7)]], sampler ae_smp_sky_light [[sampler(7)]],
    texture2d<float> brdf_lut [[texture(8)]], sampler ae_smp_brdf_lut [[sampler(8)]],
    const device float4* cluster_lights [[buffer(2)]],
    const device float* cluster_words [[buffer(3)]]) {
    ae_lit_frag_out ae_out;
    float4 ae_frag_coord = ae_in.ae_frag_coord;
    float2 fragTexCoord = ae_in.fragTexCoord;
    float3 Normal = ae_in.Normal;
    float3 FragPos = ae_in.FragPos;
    float3 InstanceColor = ae_in.InstanceColor;
    float Occlusion = ae_in.Occlusion;
    float4 ClipNow = ae_in.ClipNow;
    float4 ClipPrev = ae_in.ClipPrev;
    float3 BindPos = ae_in.BindPos;
    float ClipLimb = ae_in.ClipLimb;
    float2 MaskUV = ae_in.MaskUV;
    float ParticleAlpha = ae_in.ParticleAlpha;
    float3 FlipNext = ae_in.FlipNext;
    constant Draw& draw = ae_set0.draw;
    constant DrawMaterial& material = ae_set0.material;
    constant Surface& shading = ae_set0.shading;
    constant Cut& cut = ae_set0.cut;
    constant Wounds& wounds = ae_set0.wounds;
    constant Damage& damage = ae_set0.damage;
    constant Eye& eye = ae_set1.eye;
    constant ShadowCascades& cascades = ae_set1.cascades;
    constant Grid& grid = ae_set1.grid;
    constant WorldState& world = ae_set2.world;
    constant Weather& weather = ae_set2.weather;
    if (ae3d_shaders_lit_clipped_away(BindPos, cut, ClipLimb)) {
        discard_fragment();
    }
    float wound_at = wounds.count > 0 ? ae3d_shaders_lit_wound_depth(BindPos, wounds) : 2.0;
    if (wound_at < wounds.core) {
        discard_fragment();
    }
    float2 moved = ae3d_shaders_lit_velocity(ClipNow, ClipPrev, eye.jitter);
    int tri_on = 0;
    int hex_on = 0;
    Tri tri = Tri{float3(0.0, 1.0, 0.0), float2(0.0), float2(0.0), float2(0.0)};
    Hex hx = Hex{float2(0.0), float2(0.0), float2(0.0), float2x2(1.0, 0.0, 0.0, 1.0), float2x2(1.0, 0.0, 0.0, 1.0), float2x2(1.0, 0.0, 0.0, 1.0), float2(0.0), float2(0.0), float3(1.0, 0.0, 0.0)};
    float3 hex_weights = float3(1.0, 0.0, 0.0);
    float4 tex_colour = float4(0.0);
    if (material.triplanar > 0.0) {
        tri = ae3d_shaders_lit_tri_setup(normalize(Normal), FragPos, material.triplanar);
        tri_on = 1;
        tex_colour = ae3d_shaders_lit_tri_texture(colour_map, ae_smp_colour_map, tri);
    } else if (material.tile_breakup > 0.0) {
        hx = ae3d_shaders_lit_hex_setup(fragTexCoord, material.tile_rotation);
        hex_on = 1;
        HexColour hc = ae3d_shaders_lit_hex_texture(colour_map, ae_smp_colour_map, hx);
        tex_colour = hc.colour;
        hex_weights = hc.weights;
    } else {
        tex_colour = colour_map.sample(ae_smp_colour_map, fragTexCoord);
        if (FlipNext.z >= 0.0) {
            tex_colour = mix(tex_colour, colour_map.sample(ae_smp_colour_map, FlipNext.xy), FlipNext.z);
        }
    }
    if (tex_colour.w < material.cutout) {
        discard_fragment();
    }
    float detail_weight = 0.0;
    if (material.detail_scale > 0.0 && tri_on == 0) {
        float away = length(FragPos - eye.position);
        detail_weight = material.detail_strength * (1.0 - smoothstep(material.detail_fade * 0.5, material.detail_fade, away));
    }
    if (material.fire > 0.0) {
        float heat = clamp(tex_colour.x * InstanceColor.x, 0.0, 1.0);
        float3 glowing = ae3d_shaders_lit_black_body(heat * material.fire) * (heat * heat * heat * heat) * max(material.exposure * 0.1, 1.0);
        ae_out.out_colour = float4(glowing * material.diffuse, tex_colour.w * material.alpha * ParticleAlpha * ae3d_shaders_lit_soft_fade(material, eye, scene_depth, ae_smp_scene_depth, FragPos, ae_frag_coord));
        ae_out.out_velocity = float4(moved, 0.0, 0.0);
        return ae_out;
    }
    if (material.exposure > 10.0) {
        float glow_alpha = material.blend != 0 ? tex_colour.w * material.alpha * ParticleAlpha * ae3d_shaders_lit_soft_fade(material, eye, scene_depth, ae_smp_scene_depth, FragPos, ae_frag_coord) : 1.0;
        ae_out.out_colour = float4(material.diffuse * tex_colour.rgb * InstanceColor * (material.exposure * 0.1), glow_alpha);
        ae_out.out_velocity = float4(moved, 0.0, 0.0);
        return ae_out;
    }
    float3 norm = normalize(Normal);
    float normal_variance = 0.0;
    if (draw.impostor != 0) {
        if (tex_colour.w < 0.5) {
            discard_fragment();
        }
        float3 facing = normalize(Normal);
        float3 baked = normal_map.sample(ae_smp_normal_map, fragTexCoord).xyz * 2.0 - float3(1.0);
        norm = normalize(facing * baked.x + float3(0.0, baked.y, 0.0) + float3(-facing.z, 0.0, facing.x) * baked.z);
    } else if (material.normal_map != 0) {
        MappedNormal mn = ae3d_shaders_lit_mapped_normal(norm, FragPos, fragTexCoord, tri_on, tri, hex_on, hx, hex_weights, detail_weight, world, material, normal_map, ae_smp_normal_map);
        norm = mn.normal;
        normal_variance = mn.variance;
    }
    if (eye.capture == 1) {
        ae_out.out_colour = float4(material.diffuse * tex_colour.rgb * InstanceColor, tex_colour.w);
        ae_out.out_velocity = float4(moved, 0.0, 0.0);
        return ae_out;
    }
    if (eye.capture == 2) {
        ae_out.out_colour = float4(norm * 0.5 + float3(0.5), 1.0);
        ae_out.out_velocity = float4(moved, 0.0, 0.0);
        return ae_out;
    }
    if (eye.capture == 3) {
        float2 shown = moved * eye.screen_size / 200.0 + float2(0.5);
        ae_out.out_colour = float4(float3(shown.x, shown.y, 0.0), 1.0);
        ae_out.out_velocity = float4(moved, 0.0, 0.0);
        return ae_out;
    }
    float3 view_dir = normalize(eye.position - FragPos);
    float3 albedo0 = material.diffuse * tex_colour.rgb * InstanceColor;
    float3 albedo1 = albedo0;
    if (wounds.count > 0) {
        albedo1 = mix(albedo0, wounds.layers[0].rgb, ae3d_shaders_lit_splat_cover(BindPos, wounds));
    }
    float2 mask_at = damage.rect.xy + clamp(MaskUV, float2(damage.clamp), float2(1.0 - damage.clamp)) * float2(damage.rect.z, damage.rect.w);
    float4 damaged = damage_mask.sample(ae_smp_damage_mask, mask_at);
    float3 albedo2 = albedo1;
    if (damage.on != 0) {
        for (int k = 0; k < 4; k += 1) {
            albedo2 = mix(albedo2, damage.colours[k].rgb, clamp(damaged[k] * damage.colours[k].w, 0.0, 1.0));
        }
    }
    float3 albedo3 = albedo2;
    if (wound_at < 1.0) {
        float3 layer = wounds.layers[0].rgb;
        for (int j = 1; j < 4; j += 1) {
            if (wound_at < wounds.layers[j].w) {
                layer = wounds.layers[j].rgb;
            }
        }
        albedo3 = mix(albedo2, layer, smoothstep(1.0, 0.94, wound_at));
    }
    float3 albedo4 = albedo3;
    if (detail_weight > 0.0) {
        float3 fine = colour_map.sample(ae_smp_colour_map, (fragTexCoord * material.detail_scale)).rgb;
        float3 mean = max(colour_map.sample(ae_smp_colour_map, fragTexCoord, level(16.0)).rgb, float3(0.02));
        albedo4 = albedo3 * mix(float3(1.0), clamp(fine / mean, float3(0.0), float3(2.0)), detail_weight);
    }
    float3 albedo5 = albedo4;
    if (material.variation > 0.0) {
        float3 cell = FragPos / max(material.variation_scale, 0.01);
        float v0 = ae3d_shaders_lit_clip_value_noise(cell) * 0.65 + ae3d_shaders_lit_clip_value_noise(cell * 2.7 + float3(13.1, 7.3, 2.9)) * 0.35;
        float v1 = smoothstep(0.25, 0.75, v0);
        albedo5 = albedo4 * (1.0 + (v1 * 2.0 - 1.0) * material.variation);
    }
    float3 albedo6 = albedo5;
    if (shading.perlin != 0) {
        float3 noise_coord = FragPos * shading.noise_scale;
        float noise_value = ae3d_shaders_lit_turbulence(noise_coord, shading.noise_octaves);
        albedo6 = mix(albedo5, albedo5 * (1.0 + noise_value * 0.3), shading.noise_intensity);
    }
    float3 f0a = float3(0.04) * material.specular;
    float3 f0 = f0a;
    if (material.metallic > 0.5) {
        float3 metal_f0 = albedo6;
        if (albedo6.x > albedo6.y && albedo6.x > albedo6.z) {
            metal_f0 = mix(float3(0.95, 0.64, 0.54), albedo6, 0.7);
        } else if (albedo6.y > albedo6.x && albedo6.y > albedo6.z) {
            metal_f0 = mix(float3(0.70, 0.78, 0.74), albedo6, 0.7);
        } else if (albedo6.z > albedo6.x && albedo6.z > albedo6.y) {
            metal_f0 = mix(float3(0.66, 0.73, 0.80), albedo6, 0.7);
        } else {
            metal_f0 = mix(float3(0.95, 0.93, 0.88), albedo6, 0.7);
        }
        f0 = mix(f0a, metal_f0, material.metallic);
    } else {
        f0 = mix(f0a, albedo6, material.metallic);
    }
    float ndotv = clamp(dot(norm, view_dir), 0.001, 1.0);
    float adjusted0 = max(sqrt(material.roughness * material.roughness + normal_variance), 0.08);
    float adjusted = adjusted0;
    float wet0 = world.wetness * clamp(norm.y, 0.0, 1.0);
    float wet = wet0 * wet0;
    float wet_mirror = 0.0;
    float3 albedo = albedo6;
    if (wet > 0.001) {
        albedo = albedo6 * (1.0 - 0.35 * wet);
        adjusted = max(mix(adjusted0, 0.05, wet), 0.08);
        wet_mirror = wet * 0.7;
    } else {
        wet_mirror = 0.0;
    }
    float shaded0 = 1.0;
    if (cascades.on != 0 && shading.shadows != 0) {
        shaded0 = ae3d_shaders_lit_shadow_factor(Normal, world, eye, FragPos, cascades, shading, shadow_map, ae_smp_shadow_map);
    }
    float shaded = shaded0;
    if (grid.key_lamp >= 0 && grid.lamp_base >= 0 && shading.shadows != 0) {
        shaded = ae3d_shaders_lit_lamp_shadow(grid.key_lamp, normalize(Normal), grid, cluster_lights, FragPos, lamp_shadow_map, ae_smp_lamp_shadow_map, shading);
    }
    float sunlit = ae3d_shaders_lit_cloud_shadow(FragPos, world);
    float3 lo = float3(0.0);
    for (int i = 0; i < 16; i += 1) {
        if (i >= world.light_count) {
            break;
        }
        if (world.lights[i].kind != 1) {
            float3 gap = world.lights[i].position - FragPos;
            if (dot(gap, gap) * world.lights[i].quadratic > 64.0) {
                continue;
            }
            if (world.lights[i].kind == 2 && dot(normalize(-gap), normalize(world.lights[i].direction)) < world.lights[i].cos_outer) {
                continue;
            }
        }
        DirectLight dl = ae3d_shaders_lit_direct_light(world.lights[i], norm, view_dir, albedo, f0, ndotv, adjusted, wet_mirror, FragPos, material, shading);
        lo = lo + (i == 0 ? dl.lit * sunlit * shaded : dl.lit) + dl.back_fill;
    }
    if (material.glitter > 0.0 && world.light_count > 0 && world.lights[0].kind == 1) {
        lo = lo + ae3d_shaders_lit_glitter(norm, view_dir, world.lights[0], FragPos, material) * sunlit * shaded;
    }
    if (grid.dims.w > 0.5) {
        int cell_at = ae3d_shaders_lit_cluster_of(FragPos, grid, eye);
        int first = int((cluster_words[(cell_at * 2)] + 0.5));
        int count = int((cluster_words[(cell_at * 2 + 1)] + 0.5));
        for (int k2 = 0; k2 < count; k2 += 1) {
            ClusterLamp cl = ae3d_shaders_lit_clustered_light(int((cluster_words[(first + k2)] + 0.5)), cluster_lights);
            WorldLight lamp = cl.light;
            float3 lgap = lamp.position - FragPos;
            float far2 = dot(lgap, lgap);
            if (far2 >= cl.reach * cl.reach) {
                continue;
            }
            if (lamp.kind == 2 && dot(normalize(-lgap), normalize(lamp.direction)) < lamp.cos_outer) {
                continue;
            }
            float fade_out = 1.0 - smoothstep(0.75 * cl.reach, cl.reach, sqrt(far2));
            DirectLight ldl = ae3d_shaders_lit_direct_light(lamp, norm, view_dir, albedo, f0, ndotv, adjusted, wet_mirror, FragPos, material, shading);
            float3 lit = ldl.lit * fade_out;
            lo = lo + ldl.back_fill * fade_out;
            float shade = 1.0;
            if (cl.slot >= 0 && grid.lamp_base >= 0 && shading.shadows != 0 && dot(lit, float3(0.333)) > 0.002) {
                shade = ae3d_shaders_lit_lamp_shadow(cl.slot, normalize(Normal), grid, cluster_lights, FragPos, lamp_shadow_map, ae_smp_lamp_shadow_map, shading);
            }
            lo = lo + lit * shade;
        }
    }
    float shut = mix(1.0, Occlusion, world.occlusion_strength) * ae3d_shaders_lit_screen_occlusion(eye, ClipPrev, occlusion_map, ae_smp_occlusion_map);
    float3 colour0 = ae3d_shaders_lit_sky_lit(norm, view_dir, albedo, f0, adjusted, material.metallic, ndotv, world, shading, sky_irradiance, ae_smp_sky_irradiance, sky_light, ae_smp_sky_light, brdf_lut, ae_smp_brdf_lut) * shut + lo;
    float distance_to_camera = length(FragPos - eye.position);
    float3 volumetric = ae3d_shaders_lit_calculate_volumetric_lighting(FragPos, world.lights[0].position, eye.position, shading, world);
    float3 colour1 = colour0 + volumetric;
    float3 colour2 = colour1 + ae3d_shaders_lit_caustic_light(FragPos, norm, shading, world) * albedo;
    float3 colour3 = colour2 * material.exposure;
    float3 colour4 = colour3;
    if (material.embers > 0.0) {
        colour4 = colour3 + ae3d_shaders_lit_ember_light(FragPos, world, material);
    }
    float3 colour = colour4;
    if (weather.fog != 0) {
        float haze = smoothstep(weather.fog_start, weather.fog_end, distance_to_camera) * weather.fog_intensity;
        colour = mix(colour4, weather.fog_radiance, clamp(haze, 0.0, 1.0));
    }
    float final0 = tex_colour.w * material.alpha;
    float final1 = final0;
    if (material.alpha >= 0.99) {
        final1 = 1.0;
    }
    float final_alpha = final1;
    if (material.blend != 0) {
        final_alpha = tex_colour.w * material.alpha * ParticleAlpha * ae3d_shaders_lit_soft_fade(material, eye, scene_depth, ae_smp_scene_depth, FragPos, ae_frag_coord);
    }
    ae_out.out_colour = float4(colour, final_alpha);
    ae_out.out_velocity = float4(moved, 0.0, 0.0);
    return ae_out;
}
