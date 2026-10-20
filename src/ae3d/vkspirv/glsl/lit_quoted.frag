#version 450
// lit: written by ae3d.gpu from its quote.

struct WorldLight {
    vec3 position;
    vec3 colour;
    float intensity;
    float temperature;
    int kind;
    vec3 direction;
    float constant;
    float linear;
    float quadratic;
    float cos_outer;
    float cos_inner;
};
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
struct Eye {
    mat4 view_projection;
    mat4 prev_view_projection;
    mat4 inv_view_projection;
    vec3 position;
    float far;
    vec2 jitter;
    vec2 screen_size;
    int depth_on;
    vec4 depth_plane;
    int history;
    int capture;
    float ray_reach;
    int ray_frame;
};
struct DrawMaterial {
    vec3 diffuse;
    vec3 specular;
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
struct Draw {
    mat4 model;
    mat4 prev_model;
    mat4 light_space;
    int instanced;
    int instance_colour;
    int points;
    int billboard;
    int flip_columns;
    int flip_rows;
    float lift;
    int skinned;
    int impostor;
};
struct WorldState {
    WorldLight lights[16];
    int light_count;
    vec3 shadow_direction;
    float cloud_cover;
    float cloud_time;
    vec3 cloud_sun;
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
};
struct Damage {
    int on;
    vec4 colours[4];
    vec4 rect;
    float clamp;
};
struct Surface {
    int shadows;
    float shadow_intensity;
    float shadow_softness;
    int clearcoat;
    float clearcoat_roughness;
    float clearcoat_intensity;
    int sheen;
    vec3 sheen_colour;
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
struct ShadowCascades {
    int on;
    mat4 matrices[4];
    vec4 splits;
    vec4 texel_world;
    int count;
};
struct Grid {
    vec4 dims;
    vec4 depth;
    mat4 view_projection;
    int lamp_base;
    int key_lamp;
};
struct Weather {
    int fog;
    float fog_start;
    float fog_end;
    vec3 fog_radiance;
    float fog_intensity;
};
layout(std140, set = 0, binding = 0) uniform DrawBlock {
    Draw draw;
    DrawMaterial material;
    Surface shading;
    Cut cut;
    Wounds wounds;
    Damage damage;
};
layout(std140, set = 1, binding = 0) uniform CameraBlock {
    Eye eye;
    ShadowCascades cascades;
    Grid grid;
};
layout(std140, set = 2, binding = 0) uniform WorldBlock {
    WorldState world;
    Weather weather;
};
layout(set = 0, binding = 1) uniform sampler2D colour_map;
layout(set = 0, binding = 4) uniform sampler2D scene_depth;
layout(set = 0, binding = 3) uniform sampler2D normal_map;
layout(set = 0, binding = 9) uniform sampler2D damage_mask;
layout(set = 1, binding = 1) uniform sampler2D shadow_map;
layout(set = 1, binding = 4) uniform sampler2D lamp_shadow_map;
layout(set = 1, binding = 5) uniform sampler2D occlusion_map;
layout(set = 2, binding = 3) uniform sampler2D sky_irradiance;
layout(set = 2, binding = 1) uniform sampler2D sky_light;
layout(set = 2, binding = 2) uniform sampler2D brdf_lut;
layout(std430, set = 1, binding = 2) readonly buffer cluster_lights_buffer { vec4 cluster_lights[]; };
layout(std430, set = 1, binding = 3) readonly buffer cluster_words_buffer { float cluster_words[]; };

struct Tri {
    vec3 weights;
    vec2 x;
    vec2 y;
    vec2 z;
};

struct Hex {
    vec2 uv0;
    vec2 uv1;
    vec2 uv2;
    mat2 turn0;
    mat2 turn1;
    mat2 turn2;
    vec2 dx;
    vec2 dy;
    vec3 weights;
};

struct HexColour {
    vec4 colour;
    vec3 weights;
};

struct MappedNormal {
    vec3 normal;
    float variance;
};

struct Frame {
    vec3 tangent;
    vec3 bitangent;
    vec3 normal;
};

struct DirectLight {
    vec3 lit;
    vec3 back_fill;
};

struct ClusterLamp {
    WorldLight light;
    float reach;
    int slot;
};

layout(location = 0) in vec2 fragTexCoord;
layout(location = 1) in vec3 Normal;
layout(location = 2) in vec3 FragPos;
layout(location = 3) in vec3 InstanceColor;
layout(location = 5) in float Occlusion;
layout(location = 6) in vec4 ClipNow;
layout(location = 7) in vec4 ClipPrev;
layout(location = 8) in vec3 BindPos;
layout(location = 9) in float ClipLimb;
layout(location = 10) in vec2 MaskUV;
layout(location = 11) in float ParticleAlpha;
layout(location = 12) in vec3 FlipNext;

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

vec2 ae3d_shaders_lit_velocity(vec4 now, vec4 prev, vec2 nudge) {
    if (now.w <= 0.0 || prev.w <= 0.0) {
        return vec2(0.0);
    }
    vec2 uv_now = now.xy / now.w * 0.5 + vec2(0.5) - nudge;
    vec2 uv_prev = prev.xy / prev.w * 0.5 + vec2(0.5);
    return uv_now - uv_prev;
}

Tri ae3d_shaders_lit_tri_setup(vec3 n, vec3 position, float metres) {
    vec3 w = pow(abs(n), vec3(4.0));
    vec3 q = position / metres;
    return Tri(w / max(w.x + w.y + w.z, 1e-6), q.zy, q.xz, q.xy);
}

vec4 ae3d_shaders_lit_tri_texture(sampler2D tex, Tri tri) {
    return texture(tex, tri.x) * tri.weights.x + texture(tex, tri.y) * tri.weights.y + texture(tex, tri.z) * tri.weights.z;
}

mat2 ae3d_shaders_lit_hex_rotation(int cx, int cy, float strength) {
    float angle0 = abs(float((cx * cy))) + abs(float((cx + cy))) + 3.14159265;
    float angle1 = mod(angle0, 6.28318531);
    float angle2 = angle1;
    if (angle1 > 3.14159265) {
        angle2 = angle1 - 6.28318531;
    }
    float angle = angle2 * strength;
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, -s, s, c);
}

vec2 ae3d_shaders_lit_hex_offset(int cx, int cy) {
    vec2 q = vec2(float(cx), float(cy));
    return fract(sin(vec2(dot(q, vec2(127.1, 311.7)), dot(q, vec2(269.5, 183.3)))) * 43758.5453);
}

Hex ae3d_shaders_lit_hex_setup(vec2 uv, float rotation) {
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
    vec2 skewed = (mat2(1.0, -0.57735027, 0.0, 1.15470054) * (uv * 3.46410162));
    int bx = int(floor(skewed.x));
    int by = int(floor(skewed.y));
    vec2 t = fract(skewed);
    float tz = 1.0 - t.x - t.y;
    float s = step(0.0, -tz);
    float s2 = 2.0 * s - 1.0;
    vec3 weights = vec3(-tz * s2, s - t.y * s2, s - t.x * s2);
    int si = int(s);
    int c0x = bx + si;
    int c0y = by + si;
    int c1x = bx + si;
    int c1y = by + (1 - si);
    int c2x = bx + (1 - si);
    int c2y = by + si;
    mat2 turn0 = ae3d_shaders_lit_hex_rotation(c0x, c0y, rotation);
    vec2 middle0 = (mat2(1.0, 0.0, 0.5, 0.86602540) * vec2(float(c0x), float(c0y))) / 3.46410162;
    vec2 uv0 = (turn0 * (uv - middle0)) + middle0 + ae3d_shaders_lit_hex_offset(c0x, c0y);
    mat2 turn1 = ae3d_shaders_lit_hex_rotation(c1x, c1y, rotation);
    vec2 middle1 = (mat2(1.0, 0.0, 0.5, 0.86602540) * vec2(float(c1x), float(c1y))) / 3.46410162;
    vec2 uv1 = (turn1 * (uv - middle1)) + middle1 + ae3d_shaders_lit_hex_offset(c1x, c1y);
    mat2 turn2 = ae3d_shaders_lit_hex_rotation(c2x, c2y, rotation);
    vec2 middle2 = (mat2(1.0, 0.0, 0.5, 0.86602540) * vec2(float(c2x), float(c2y))) / 3.46410162;
    vec2 uv2 = (turn2 * (uv - middle2)) + middle2 + ae3d_shaders_lit_hex_offset(c2x, c2y);
    return Hex(uv0, uv1, uv2, turn0, turn1, turn2, dx, dy, weights);
}

HexColour ae3d_shaders_lit_hex_texture(sampler2D tex, Hex hx) {
    vec4 c0 = textureGrad(tex, hx.uv0, (hx.turn0 * hx.dx), (hx.turn0 * hx.dy));
    vec4 c1 = textureGrad(tex, hx.uv1, (hx.turn1 * hx.dx), (hx.turn1 * hx.dy));
    vec4 c2 = textureGrad(tex, hx.uv2, (hx.turn2 * hx.dx), (hx.turn2 * hx.dy));
    vec3 luma = vec3(0.299, 0.587, 0.114);
    vec3 bright = mix(vec3(1.0), vec3(dot(c0.rgb, luma), dot(c1.rgb, luma), dot(c2.rgb, luma)), 0.6);
    vec3 w0 = bright * pow(hx.weights, vec3(7.0));
    vec3 w = w0 / max(w0.x + w0.y + w0.z, 1e-6);
    return HexColour(c0 * w.x + c1 * w.y + c2 * w.z, w);
}

vec3 ae3d_shaders_lit_black_body(float kelvin) {
    float t = max(kelvin, 500.0) / 100.0;
    float g = t <= 6.6 ? 0.0 : clamp((99.4708025861 * log(t) - 161.1195681661) / 255.0, 0.0, 1.0);
    float b = t <= 19.0 ? 0.0 : clamp((138.5177312231 * log(t - 10.0) - 305.0447927307) / 255.0, 0.0, 1.0);
    return pow(vec3(1.0, g, b), vec3(2.2));
}

float ae3d_shaders_lit_soft_fade() {
    if (material.soft <= 0.0 || eye.depth_on != 1) {
        return 1.0;
    }
    vec2 suv = gl_FragCoord.xy / eye.screen_size;
    float d = texture(scene_depth, suv).x;
    if (d >= 0.99999) {
        return 1.0;
    }
    vec2 sp = suv * 2.0 - vec2(1.0);
    vec4 clip = vec4(vec3(sp.x, sp.y, d), 1.0);
    vec4 world = (eye.inv_view_projection * clip);
    vec3 behind = world.xyz / world.w;
    float gap = distance(eye.position, behind) - distance(eye.position, FragPos);
    return clamp(gap / material.soft, 0.0, 1.0);
}

float ae3d_shaders_lit_toksvig(float len, float strength) {
    float l = clamp(len, 0.001, 1.0);
    return min((1.0 - l) / l * strength * strength, 1.0);
}

MappedNormal ae3d_shaders_lit_tri_normal(vec3 n, float strength, Tri tri) {
    vec3 tx0 = texture(normal_map, tri.x).xyz * 2.0 - vec3(1.0);
    vec3 ty0 = texture(normal_map, tri.y).xyz * 2.0 - vec3(1.0);
    vec3 tz0 = texture(normal_map, tri.z).xyz * 2.0 - vec3(1.0);
    float variance = ae3d_shaders_lit_toksvig(length(tx0) * tri.weights.x + length(ty0) * tri.weights.y + length(tz0) * tri.weights.z, strength);
    vec2 txy = tx0.xy * strength;
    vec2 tyy = ty0.xy * strength;
    vec2 tzy = tz0.xy * strength;
    vec3 tx = vec3(txy + n.zy, abs(tx0.z) * n.x);
    vec3 ty = vec3(tyy + n.xz, abs(ty0.z) * n.y);
    vec3 tz = vec3(tzy + n.xy, abs(tz0.z) * n.z);
    return MappedNormal(normalize(tx.zyx * tri.weights.x + ty.xzy * tri.weights.y + tz * tri.weights.z), variance);
}

vec3 ae3d_shaders_lit_hex_normal(Hex hx, vec3 weights) {
    vec3 s0 = textureGrad(normal_map, hx.uv0, (hx.turn0 * hx.dx), (hx.turn0 * hx.dy)).xyz * 2.0 - vec3(1.0);
    vec2 t0 = (transpose(hx.turn0) * s0.xy);
    vec3 n0 = vec3(0.0) + vec3(t0, s0.z) * weights.x;
    vec3 s1 = textureGrad(normal_map, hx.uv1, (hx.turn1 * hx.dx), (hx.turn1 * hx.dy)).xyz * 2.0 - vec3(1.0);
    vec2 t1 = (transpose(hx.turn1) * s1.xy);
    vec3 n1 = n0 + vec3(t1, s1.z) * weights.y;
    vec3 s2 = textureGrad(normal_map, hx.uv2, (hx.turn2 * hx.dx), (hx.turn2 * hx.dy)).xyz * 2.0 - vec3(1.0);
    vec2 t2 = (transpose(hx.turn2) * s2.xy);
    return n1 + vec3(t2, s2.z) * weights.z;
}

Frame ae3d_shaders_lit_cotangent_frame(vec3 normal, vec3 position, vec2 uv) {
    vec3 dpx = dFdx(position);
    vec3 dpy = dFdy(position);
    vec2 duvx = dFdx(uv);
    vec2 duvy = dFdy(uv);
    vec3 perp_y = cross(dpy, normal);
    vec3 perp_x = cross(normal, dpx);
    vec3 tangent = perp_y * duvx.x + perp_x * duvy.x;
    vec3 bitangent = perp_y * duvx.y + perp_x * duvy.y;
    float handed = dot(dpx, perp_y) < 0.0 ? -1.0 : 1.0;
    float scale = handed * inversesqrt(max(dot(tangent, tangent), dot(bitangent, bitangent)));
    return Frame(tangent * scale, bitangent * scale, normal);
}

MappedNormal ae3d_shaders_lit_mapped_normal(vec3 normal, vec3 position, vec2 uv, int tri_on, Tri tri, int hex_on, Hex hx, vec3 weights, float detail_weight) {
    float strength = world.normal_strength * material.normal_strength;
    if (tri_on != 0) {
        return ae3d_shaders_lit_tri_normal(normal, strength, tri);
    }
    vec3 sampled0 = hex_on != 0 ? ae3d_shaders_lit_hex_normal(hx, weights) : texture(normal_map, uv).xyz * 2.0 - vec3(1.0);
    float variance = ae3d_shaders_lit_toksvig(length(sampled0), strength);
    vec3 sampled1 = sampled0;
    if (detail_weight > 0.0) {
        vec3 fine = texture(normal_map, uv * material.detail_scale).xyz * 2.0 - vec3(1.0);
        sampled1 = vec3(sampled0.xy + fine.xy * detail_weight, sampled0.z);
    }
    vec2 sxy = sampled1.xy * strength;
    vec3 sampled = vec3(sxy, sampled1.z);
    Frame fr = ae3d_shaders_lit_cotangent_frame(normal, position, uv);
    return MappedNormal(normalize((mat3(fr.tangent, fr.bitangent, fr.normal) * sampled)), variance);
}

float ae3d_shaders_lit_splat_cover(vec3 p) {
    float most = 0.0;
    for (int i = 0; i < 32; i += 1) {
        if (i >= wounds.count) {
            break;
        }
        if (wounds.data[i * 3].w < 0.5) {
            continue;
        }
        vec3 r = max(wounds.data[i * 3 + 1].xyz, vec3(0.0001));
        vec3 local = ae3d_shaders_lit_wound_unturn(wounds.data[i * 3 + 2], p - wounds.data[i * 3].xyz) / r;
        float edge = 1.0 + 0.35 * (ae3d_shaders_lit_clip_value_noise(local * 3.0 + wounds.data[i * 3].xyz * 7.0) * 2.0 - 1.0);
        float cover = wounds.data[i * 3 + 1].w * (1.0 - smoothstep(0.8 * edge, edge, length(local)));
        most = max(most, cover);
    }
    return most;
}

float ae3d_shaders_lit_fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

int ae3d_shaders_lit_lattice_hash(int x, int y, int z) {
    int n0 = x + y * 57 + z * 113;
    int n = n0 << 13 ^ n0;
    return abs(n * (n * n * 15731 + 789221) + 1376312589) & 255;
}

vec3 ae3d_shaders_lit_get_gradient(int hashed) {
    int h = hashed & 15;
    float u = h < 8 ? 1.0 : -1.0;
    float v = (h & 1) == 0 ? 1.0 : -1.0;
    float w = (h & 2) == 0 ? 1.0 : -1.0;
    if (h < 4) {
        return vec3(u, v, 0.0);
    } else if (h < 8) {
        return vec3(u, 0.0, w);
    } else if (h < 12) {
        return vec3(0.0, v, w);
    } else {
        return vec3(u, v, w);
    }
}

float ae3d_shaders_lit_lerp(float t, float a, float b) {
    return a + t * (b - a);
}

float ae3d_shaders_lit_perlin_noise3d(vec3 p) {
    int ix = int(floor(p.x));
    int iy = int(floor(p.y));
    int iz = int(floor(p.z));
    vec3 f = p - vec3(float(ix), float(iy), float(iz));
    vec3 u = vec3(ae3d_shaders_lit_fade(f.x), ae3d_shaders_lit_fade(f.y), ae3d_shaders_lit_fade(f.z));
    int n000 = ae3d_shaders_lit_lattice_hash(ix, iy, iz);
    int n001 = ae3d_shaders_lit_lattice_hash(ix, iy, iz + 1);
    int n010 = ae3d_shaders_lit_lattice_hash(ix, iy + 1, iz);
    int n011 = ae3d_shaders_lit_lattice_hash(ix, iy + 1, iz + 1);
    int n100 = ae3d_shaders_lit_lattice_hash(ix + 1, iy, iz);
    int n101 = ae3d_shaders_lit_lattice_hash(ix + 1, iy, iz + 1);
    int n110 = ae3d_shaders_lit_lattice_hash(ix + 1, iy + 1, iz);
    int n111 = ae3d_shaders_lit_lattice_hash(ix + 1, iy + 1, iz + 1);
    float d000 = dot(ae3d_shaders_lit_get_gradient(n000), f);
    float d001 = dot(ae3d_shaders_lit_get_gradient(n001), f - vec3(0.0, 0.0, 1.0));
    float d010 = dot(ae3d_shaders_lit_get_gradient(n010), f - vec3(0.0, 1.0, 0.0));
    float d011 = dot(ae3d_shaders_lit_get_gradient(n011), f - vec3(0.0, 1.0, 1.0));
    float d100 = dot(ae3d_shaders_lit_get_gradient(n100), f - vec3(1.0, 0.0, 0.0));
    float d101 = dot(ae3d_shaders_lit_get_gradient(n101), f - vec3(1.0, 0.0, 1.0));
    float d110 = dot(ae3d_shaders_lit_get_gradient(n110), f - vec3(1.0, 1.0, 0.0));
    float d111 = dot(ae3d_shaders_lit_get_gradient(n111), f - vec3(1.0, 1.0, 1.0));
    return ae3d_shaders_lit_lerp(u.z, ae3d_shaders_lit_lerp(u.y, ae3d_shaders_lit_lerp(u.x, d000, d100), ae3d_shaders_lit_lerp(u.x, d010, d110)), ae3d_shaders_lit_lerp(u.y, ae3d_shaders_lit_lerp(u.x, d001, d101), ae3d_shaders_lit_lerp(u.x, d011, d111)));
}

float ae3d_shaders_lit_turbulence(vec3 p, int octaves) {
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

float ae3d_shaders_lit_cascade_lit(int c, vec3 surface, float slope) {
    vec4 light_space = (cascades.matrices[c] * vec4(FragPos + surface * cascades.texel_world[c] * (1.0 + slope), 1.0));
    vec3 projected = light_space.xyz / light_space.w;
    vec2 pxy = projected.xy * 0.5 + vec2(0.5);
    float pz = projected.z;
    if (pz > 1.0) {
        return 1.0;
    }
    if (pxy.x < 0.0 || pxy.x > 1.0 || pxy.y < 0.0 || pxy.y > 1.0) {
        return 1.0;
    }
    vec2 texel = vec2(1.0) / vec2(textureSize(shadow_map, 0));
    float radius = max(shading.shadow_softness, 1.0);
    vec2 tile = vec2(float((c % 2)), float((c / 2))) * 0.5;
    vec2 centre = tile + pxy * 0.5;
    vec2 lo = tile + texel * (radius + 0.5);
    vec2 hi = tile + vec2(0.5) - texel * (radius + 0.5);
    float bias = radius / (vec2(textureSize(shadow_map, 0)).x * 0.5);
    float lit = 0.0;
    for (int sx = -1; sx <= 1; sx += 1) {
        for (int sy = -1; sy <= 1; sy += 1) {
            vec2 at = clamp(centre + vec2(float(sx), float(sy)) * texel * radius, lo, hi);
            float closest = texture(shadow_map, at).x;
            lit = lit + (pz - bias > closest ? 0.0 : 1.0);
        }
    }
    return lit / 9.0;
}

float ae3d_shaders_lit_shadow_factor() {
    vec3 surface = normalize(Normal);
    vec3 to_light = normalize(-world.shadow_direction);
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
    float lit = ae3d_shaders_lit_cascade_lit(c, surface, slope);
    if (c + 1 < cascades.count) {
        float start = c == 0 ? 0.0 : cascades.splits[(c - 1)];
        float band = (cascades.splits[c] - start) * 0.1;
        float into = (cascades.splits[c] - depth) / max(band, 0.0001);
        if (into < 1.0) {
            lit = mix(ae3d_shaders_lit_cascade_lit(c + 1, surface, slope), lit, into);
        }
    }
    return mix(shading.shadow_intensity, 1.0, lit);
}

float ae3d_shaders_lit_lamp_distance(float depth, float near, float far) {
    return near * far / (far - depth * (far - near));
}

float ae3d_shaders_lit_lamp_shadow(int slot, vec3 surface) {
    int base = grid.lamp_base + slot * 26;
    vec4 head = cluster_lights[base];
    vec4 more = cluster_lights[(base + 1)];
    vec3 v = FragPos - head.xyz;
    float far = head.w;
    float strength = more.x;
    float near = more.y;
    vec3 a = abs(v);
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
    vec3 to_lamp = -v / max(length(v), 0.0001);
    float facing = max(dot(surface, to_lamp), 0.0);
    float slope = min(sqrt(1.0 - facing * facing) / max(facing, 0.02), 32.0);
    float texel_world = 2.0 * along / 512.0;
    int m = base + 2 + face * 4;
    mat4 face_matrix = mat4(cluster_lights[m], cluster_lights[(m + 1)], cluster_lights[(m + 2)], cluster_lights[(m + 3)]);
    vec4 light_space = (face_matrix * vec4(FragPos + surface * texel_world * (1.0 + slope), 1.0));
    vec3 projected = light_space.xyz / light_space.w;
    vec2 pxy = clamp(projected.xy * 0.5 + vec2(0.5), vec2(0.0), vec2(1.0));
    float mine = ae3d_shaders_lit_lamp_distance(projected.z, near, far);
    int tile = slot * 6 + face;
    float share = 1.0 / 8.0;
    vec2 origin = vec2(float((tile % 8)), float((tile / 8))) * share;
    vec2 texel = vec2(1.0) / vec2(textureSize(lamp_shadow_map, 0));
    float radius = max(shading.shadow_softness, 1.0);
    vec2 centre = origin + pxy * share;
    vec2 lo = origin + texel * (radius + 0.5);
    vec2 hi = origin + vec2(share) - texel * (radius + 0.5);
    float bias = texel_world * 1.5;
    float lit = 0.0;
    for (int sx = -1; sx <= 1; sx += 1) {
        for (int sy = -1; sy <= 1; sy += 1) {
            vec2 at = clamp(centre + vec2(float(sx), float(sy)) * texel * radius, lo, hi);
            float closest = ae3d_shaders_lit_lamp_distance(texture(lamp_shadow_map, at).x, near, far);
            lit = lit + (mine - bias > closest ? 0.0 : 1.0);
        }
    }
    return mix(1.0, mix(shading.shadow_intensity, 1.0, lit / 9.0), strength);
}

float ae3d_shaders_lit_cloud_coverage_from(vec2 weather, float cover) {
    float threshold = 1.0 - cover * (0.45 + 1.1 * weather.y);
    return smoothstep(threshold, threshold + 0.5, weather.x) * 0.9;
}

float ae3d_shaders_lit_cloud_hash(vec3 p) {
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

float ae3d_shaders_lit_cloud_noise2(vec2 x, float period, float seed) {
    vec2 i = floor(x);
    vec2 f0 = fract(x);
    vec2 f = f0 * f0 * (vec2(3.0) - f0 * 2.0);
    vec2 i0 = mod(i, period);
    vec2 i1 = mod(i + vec2(1.0), period);
    float a = ae3d_shaders_lit_cloud_hash(vec3(i0.x, i0.y, seed));
    float b = ae3d_shaders_lit_cloud_hash(vec3(i1.x, i0.y, seed));
    float c = ae3d_shaders_lit_cloud_hash(vec3(i0.x, i1.y, seed));
    float d = ae3d_shaders_lit_cloud_hash(vec3(i1.x, i1.y, seed));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 ae3d_shaders_lit_cloud_weather_at(vec2 uv) {
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
    return vec2(shaped, bank);
}

vec2 ae3d_shaders_lit_cloud_weather_uv(vec2 at, float t) {
    return at / 24000.0 + vec2(t * 0.00012, t * 0.00004);
}

float ae3d_shaders_lit_cloud_coverage(vec2 at, float cover, float t) {
    return ae3d_shaders_lit_cloud_coverage_from(ae3d_shaders_lit_cloud_weather_at(ae3d_shaders_lit_cloud_weather_uv(at, t)), cover);
}

float ae3d_shaders_lit_cloud_shadow(vec3 world_pos) {
    if (world.cloud_cover <= 0.0 || world.cloud_sun.y <= 0.05) {
        return 1.0;
    }
    vec3 sun = normalize(world.cloud_sun);
    float up = (1400.0 + (2600.0 - 1400.0) * 0.35 - world_pos.y) / max(sun.y, 0.05);
    vec2 at = world_pos.xz + sun.xz * up;
    return 1.0 - 0.65 * ae3d_shaders_lit_cloud_coverage(at, world.cloud_cover, world.cloud_time);
}

vec3 ae3d_shaders_lit_kelvin_to_rgb(float kelvin_in) {
    float kelvin = clamp(kelvin_in, 1000.0, 12000.0);
    if (kelvin < 3000.0) {
        return mix(vec3(1.0, 0.4, 0.0), vec3(1.0, 0.7, 0.3), (kelvin - 1000.0) / 2000.0);
    } else if (kelvin < 6500.0) {
        return mix(vec3(1.0, 0.7, 0.3), vec3(1.0, 1.0, 1.0), (kelvin - 3000.0) / 3500.0);
    } else {
        return mix(vec3(1.0, 1.0, 1.0), vec3(0.7, 0.8, 1.0), (kelvin - 6500.0) / 5500.0);
    }
}

float ae3d_shaders_lit_distribution_ggx(vec3 n, vec3 h, float rough) {
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

float ae3d_shaders_lit_geometry_schlick_ggx(float ndotv, float rough) {
    float r = rough + 1.0;
    float k = r * r / 8.0;
    float num = ndotv;
    float denom = ndotv * (1.0 - k) + k;
    return num / denom;
}

float ae3d_shaders_lit_geometry_smith(vec3 n, vec3 v, vec3 l, float rough) {
    float ndotv = max(dot(n, v), 0.0);
    float ndotl = max(dot(n, l), 0.0);
    float ggx2 = ae3d_shaders_lit_geometry_schlick_ggx(ndotv, rough);
    float ggx1 = ae3d_shaders_lit_geometry_schlick_ggx(ndotl, rough);
    return ggx1 * ggx2;
}

vec3 ae3d_shaders_lit_fresnel_schlick(float cos_theta, vec3 f0) {
    float inv = clamp(1.0 - cos_theta, 0.0, 1.0);
    float inv2 = inv * inv;
    float inv5 = inv2 * inv2 * inv;
    return f0 + (vec3(1.0) - f0) * inv5;
}

vec3 ae3d_shaders_lit_calculate_clearcoat(vec3 n, vec3 v, vec3 l, vec3 h, vec3 base_colour) {
    if (shading.clearcoat == 0) {
        return vec3(0.0);
    }
    float ndf = ae3d_shaders_lit_distribution_ggx(n, h, shading.clearcoat_roughness);
    float g = ae3d_shaders_lit_geometry_smith(n, v, l, shading.clearcoat_roughness);
    vec3 f = ae3d_shaders_lit_fresnel_schlick(max(dot(h, v), 0.0), vec3(0.04));
    vec3 specular = f * (ndf * g) / (4.0 * max(dot(n, v), 0.0) * max(dot(n, l), 0.0) + 0.001);
    return specular * shading.clearcoat_intensity;
}

vec3 ae3d_shaders_lit_calculate_sheen(vec3 n, vec3 v, vec3 l, vec3 h) {
    if (shading.sheen == 0) {
        return vec3(0.0);
    }
    float ndoth = max(dot(n, h), 0.0);
    float d = (2.0 + shading.sheen_roughness) * pow(ndoth, shading.sheen_roughness) / (2.0 * 3.14159265359);
    return shading.sheen_colour * d * 0.25;
}

vec3 ae3d_shaders_lit_calculate_transmission(vec3 n, vec3 v, vec3 l, vec3 base_colour) {
    if (shading.transmission == 0) {
        return vec3(0.0);
    }
    float ndotv = max(dot(n, v), 0.0);
    float ndotl = max(dot(n, l), 0.0);
    float f0 = 0.04;
    float fresnel = f0 + (1.0 - f0) * pow(1.0 - ndotv, 5.0);
    float transmission = (1.0 - fresnel) * shading.transmission_factor;
    vec3 transmitted = base_colour * transmission * ndotl;
    vec3 scattering = base_colour * transmission * 0.1;
    return transmitted + scattering;
}

vec3 ae3d_shaders_lit_compensate_energy_loss(vec3 colour, float ndotv, float rough) {
    if (shading.multiple_scattering == 0) {
        return colour;
    }
    float compensation = 1.0 + rough * (1.0 - ndotv) * 0.2;
    return colour * compensation;
}

vec3 ae3d_shaders_lit_apply_energy_conservation(vec3 diffuse, vec3 specular, vec3 clearcoat, vec3 sheen) {
    if (shading.energy_conservation == 0) {
        return diffuse + specular + clearcoat + sheen;
    }
    vec3 total = diffuse + specular + clearcoat + sheen;
    float most = max(max(total.x, total.y), total.z);
    if (most > 1.0) {
        return total / most;
    }
    return total;
}

DirectLight ae3d_shaders_lit_direct_light(WorldLight l, vec3 norm, vec3 view_dir, vec3 albedo, vec3 f0, float ndotv, float adjusted_roughness, float wet_mirror) {
    vec3 adjusted_colour = l.colour * ae3d_shaders_lit_kelvin_to_rgb(l.temperature);
    vec3 light_dir = vec3(0.0);
    float attenuation = 1.0;
    if (l.kind == 1) {
        light_dir = normalize(l.direction);
    } else {
        vec3 light_vec = l.position - FragPos;
        float dist = length(light_vec);
        light_dir = light_vec / dist;
        attenuation = 1.0 / (l.constant + l.linear * dist + l.quadratic * dist * dist);
        if (l.kind == 2) {
            float on_axis = dot(-light_dir, normalize(l.direction));
            attenuation = attenuation * smoothstep(l.cos_outer, l.cos_inner, on_axis);
        }
    }
    vec3 halfway = normalize(light_dir + view_dir);
    vec3 radiance = adjusted_colour * l.intensity * attenuation;
    float ndotl_raw = dot(norm, light_dir);
    float hdotv = clamp(dot(halfway, view_dir), 0.001, 1.0);
    float ndotl = max(ndotl_raw, 0.0);
    float ndf = ae3d_shaders_lit_distribution_ggx(norm, halfway, adjusted_roughness);
    float g = ae3d_shaders_lit_geometry_smith(norm, view_dir, light_dir, adjusted_roughness);
    vec3 f = ae3d_shaders_lit_fresnel_schlick(hdotv, f0);
    vec3 ks = f;
    vec3 kd0 = vec3(1.0) - ks;
    vec3 kd = kd0 * (1.0 - material.metallic);
    vec3 numerator = f * (ndf * g);
    float denominator = 4.0 * ndotv * ndotl + 0.0001;
    vec3 specular0 = numerator / denominator;
    float view_attenuation = pow(ndotv, 0.6);
    float mirror = max(material.reflectivity, wet_mirror);
    vec3 specular1 = specular0;
    if (mirror > 0.001) {
        float grazing = 1.0 - ndotv;
        specular1 = specular0 * (mirror * (0.5 + grazing * grazing * 4.0));
    } else {
        specular1 = specular0 * (view_attenuation * 0.5);
    }
    vec3 clearcoat = ae3d_shaders_lit_calculate_clearcoat(norm, view_dir, light_dir, halfway, albedo);
    vec3 sheen = ae3d_shaders_lit_calculate_sheen(norm, view_dir, light_dir, halfway);
    vec3 transmission = ae3d_shaders_lit_calculate_transmission(norm, view_dir, light_dir, albedo);
    vec3 specular = ae3d_shaders_lit_compensate_energy_loss(specular1, ndotv, material.roughness);
    float hemisphere = max(ndotl_raw, 0.0);
    float fill = max(-ndotl_raw * 0.3, 0.0);
    vec3 back_fill = adjusted_colour * fill * albedo * 0.2 * attenuation;
    vec3 lit = ae3d_shaders_lit_apply_energy_conservation(kd * albedo / 3.14159265359 * radiance * hemisphere, specular * radiance * hemisphere, clearcoat * radiance * hemisphere, sheen * radiance * hemisphere) + transmission;
    return DirectLight(lit, back_fill);
}

vec3 ae3d_shaders_lit_glitter(vec3 n, vec3 v, WorldLight l_in) {
    vec3 grid = FragPos * material.glitter_grains;
    float footprint = max(length(fwidth(grid)), 1e-4);
    float level = max(ceil(log2(footprint)), 0.0);
    if (level > 7.0) {
        return vec3(0.0);
    }
    float scale = exp2(level);
    vec3 cell = floor(grid / scale);
    vec3 h = fract(sin(vec3(dot(cell, vec3(127.1, 311.7, 74.7)), dot(cell, vec3(269.5, 183.3, 246.1)), dot(cell, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
    float chance = min(material.glitter * scale * scale, 1.0);
    if (h.x > chance) {
        return vec3(0.0);
    }
    vec3 l = normalize(l_in.direction);
    float lit = max(dot(n, l), 0.0);
    if (lit <= 0.0) {
        return vec3(0.0);
    }
    vec3 k = fract(h * 13.731 + h.yzx * 7.17);
    vec3 facet = normalize(n * 0.6 + (k * 2.0 - vec3(1.0)));
    float flash = pow(max(dot(facet, normalize(l + v)), 0.0), 900.0);
    return l_in.colour * ae3d_shaders_lit_kelvin_to_rgb(l_in.temperature) * l_in.intensity * flash * lit * material.glitter_strength / (scale * scale);
}

int ae3d_shaders_lit_cluster_of(vec3 p) {
    vec4 clip = (grid.view_projection * vec4(p, 1.0));
    float w = clip.w != 0.0 ? clip.w : 1.0;
    vec2 ndc = clip.xy / w;
    float depth = dot(eye.depth_plane.xyz, p) + eye.depth_plane.w;
    vec3 dims = grid.dims.xyz + vec3(0.5);
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

ClusterLamp ae3d_shaders_lit_clustered_light(int i) {
    vec4 a = cluster_lights[(i * 5)];
    vec4 b = cluster_lights[(i * 5 + 1)];
    vec4 c = cluster_lights[(i * 5 + 2)];
    vec4 d = cluster_lights[(i * 5 + 3)];
    vec4 e = cluster_lights[(i * 5 + 4)];
    return ClusterLamp(WorldLight(a.xyz, b.rgb, b.w, d.w, int((c.w + 0.5)), c.xyz, d.x, d.y, d.z, e.x, e.y), a.w, int(floor(e.z + 0.5)));
}

float ae3d_shaders_lit_screen_occlusion() {
    if (eye.history == 0 || ClipPrev.w <= 0.0) {
        return 1.0;
    }
    vec2 uv = ClipPrev.xy / ClipPrev.w * 0.5 + vec2(0.5);
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return 1.0;
    }
    vec2 found = texture(occlusion_map, uv).xy;
    if (abs(found.y - ClipPrev.w) > 0.05 * ClipPrev.w) {
        return 1.0;
    }
    return found.x;
}

vec2 ae3d_shaders_lit_oct_encode(vec3 d_in) {
    vec3 d = d_in / (abs(d_in.x) + abs(d_in.y) + abs(d_in.z));
    vec2 p = d.xz;
    if (d.y < 0.0) {
        p = (vec2(1.0) - abs(p.yx)) * vec2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);
    }
    return p;
}

vec2 ae3d_shaders_lit_oct_uv(vec3 d, float size) {
    return ((ae3d_shaders_lit_oct_encode(d) * 0.5 + vec2(0.5)) * (size - 2.0) + vec2(1.0)) / size;
}

vec3 ae3d_shaders_lit_sky_irradiance(vec3 n) {
    return texture(sky_irradiance, ae3d_shaders_lit_oct_uv(n, 16.0)).rgb;
}

vec3 ae3d_shaders_lit_sky_reflection(vec3 r, float rough) {
    float level = clamp(rough, 0.0, 1.0) * (6.0 - 1.0);
    return textureLod(sky_light, ae3d_shaders_lit_oct_uv(r, 256.0), level).rgb;
}

vec3 ae3d_shaders_lit_sky_lit(vec3 n, vec3 v, vec3 albedo, vec3 f0, float rough, float metal, float ndotv) {
    if (world.gi_off != 0) {
        return vec3(0.0);
    }
    vec3 f = f0 + (max(vec3(1.0 - rough), f0) - f0) * pow(1.0 - ndotv, 5.0);
    vec3 kd = (vec3(1.0) - f) * (1.0 - metal);
    vec3 irradiance = ae3d_shaders_lit_sky_irradiance(n);
    vec3 diffuse = kd * albedo * irradiance / 3.14159265;
    if (shading.ibl == 0) {
        return diffuse;
    }
    vec2 ab = texture(brdf_lut, vec2(ndotv, rough)).xy;
    vec3 specular = ae3d_shaders_lit_sky_reflection(reflect(-v, n), rough) * (f0 * ab.x + vec3(ab.y));
    return diffuse + specular * shading.ibl_intensity;
}

vec3 ae3d_shaders_lit_calculate_volumetric_lighting(vec3 world_pos, vec3 light_pos, vec3 view_pos) {
    if (shading.volumetric == 0) {
        return vec3(0.0);
    }
    vec3 to_surface = world_pos - view_pos;
    float ray_length = length(to_surface);
    if (ray_length < 0.001) {
        return vec3(0.0);
    }
    vec3 ray_dir = to_surface / ray_length;
    int steps = clamp(shading.volumetric_steps, 8, 32);
    vec3 tint = world.lights[0].colour * ae3d_shaders_lit_kelvin_to_rgb(world.lights[0].temperature);
    float scatter = 0.0;
    float step_size = ray_length / float(steps);
    for (int i = 0; i < steps && i < 32; i += 1) {
        vec3 sample_pos = view_pos + ray_dir * (step_size * (float(i) + 0.5));
        float d = length(light_pos - sample_pos);
        scatter = scatter + step_size / (1.0 + d * d * shading.volumetric_scattering);
    }
    return tint * scatter * shading.volumetric_intensity;
}

float ae3d_shaders_lit_caustic_web(vec2 uv, float t) {
    vec2 drift = vec2(0.7, 0.3) * shading.caustics_speed * t;
    float a = ae3d_shaders_lit_perlin_noise3d(vec3(uv + drift, t * shading.caustics_speed * 0.5));
    float b = ae3d_shaders_lit_perlin_noise3d(vec3(uv * 1.7 - drift * 0.8, t * shading.caustics_speed * 0.4 + 5.3));
    return pow(clamp(1.0 - abs(a - b) * 3.0, 0.0, 1.0), 8.0);
}

vec3 ae3d_shaders_lit_caustic_light(vec3 world_pos, vec3 norm) {
    if (shading.caustics == 0) {
        return vec3(0.0);
    }
    float depth = shading.caustics_water_level - world_pos.y;
    if (depth <= 0.0) {
        return vec3(0.0);
    }
    vec2 uv = world_pos.xz * shading.caustics_scale;
    float t = world.time;
    vec2 fringe = vec2(0.006, 0.004);
    float red = ae3d_shaders_lit_caustic_web(uv + fringe, t) + 0.5 * ae3d_shaders_lit_caustic_web(uv * 2.3 + fringe * 2.0 + vec2(11.0), t);
    float green = ae3d_shaders_lit_caustic_web(uv, t) + 0.5 * ae3d_shaders_lit_caustic_web(uv * 2.3 + vec2(11.0), t);
    float blue = ae3d_shaders_lit_caustic_web(uv - fringe, t) + 0.5 * ae3d_shaders_lit_caustic_web(uv * 2.3 - fringe * 2.0 + vec2(11.0), t);
    vec3 web = vec3(red, green, blue);
    float facing = clamp(norm.y, 0.0, 1.0);
    float attenuation = exp(-depth / max(shading.caustics_depth, 0.001));
    vec3 key = world.lights[0].colour * ae3d_shaders_lit_kelvin_to_rgb(world.lights[0].temperature);
    return key * world.lights[0].intensity * web * facing * attenuation * shading.caustics_intensity;
}

float ae3d_shaders_lit_ember_hash(vec3 c) {
    return fract(sin(dot(c, vec3(41.3, 289.1, 157.7))) * 43758.5453);
}

float ae3d_shaders_lit_ember_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f0 = p - i;
    vec3 f = f0 * f0 * (vec3(3.0) - f0 * 2.0);
    float a = mix(mix(ae3d_shaders_lit_ember_hash(i), ae3d_shaders_lit_ember_hash(i + vec3(1.0, 0.0, 0.0)), f.x), mix(ae3d_shaders_lit_ember_hash(i + vec3(0.0, 1.0, 0.0)), ae3d_shaders_lit_ember_hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
    float b = mix(mix(ae3d_shaders_lit_ember_hash(i + vec3(0.0, 0.0, 1.0)), ae3d_shaders_lit_ember_hash(i + vec3(1.0, 0.0, 1.0)), f.x), mix(ae3d_shaders_lit_ember_hash(i + vec3(0.0, 1.0, 1.0)), ae3d_shaders_lit_ember_hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
    return mix(a, b, f.z);
}

vec3 ae3d_shaders_lit_ember_light() {
    vec3 p = FragPos * 20.0;
    vec3 i = floor(p);
    vec3 f = p - i;
    float f1 = 8.0;
    float f2 = 8.0;
    vec3 nearest = i;
    for (int z = -1; z <= 1; z += 1) {
        for (int y = -1; y <= 1; y += 1) {
            for (int x = -1; x <= 1; x += 1) {
                vec3 o = vec3(float(x), float(y), float(z));
                vec3 c = i + o;
                vec3 h = fract(sin(vec3(dot(c, vec3(127.1, 311.7, 74.7)), dot(c, vec3(269.5, 183.3, 246.1)), dot(c, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
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
layout(location = 0) out vec4 out_colour;
layout(location = 1) out vec2 out_velocity;

void main() {
    if (ae3d_shaders_lit_clipped_away(BindPos)) {
        discard;
    }
    float wound_at = wounds.count > 0 ? ae3d_shaders_lit_wound_depth(BindPos) : 2.0;
    if (wound_at < wounds.core) {
        discard;
    }
    vec2 moved = ae3d_shaders_lit_velocity(ClipNow, ClipPrev, eye.jitter);
    int tri_on = 0;
    int hex_on = 0;
    Tri tri = Tri(vec3(0.0, 1.0, 0.0), vec2(0.0), vec2(0.0), vec2(0.0));
    Hex hx = Hex(vec2(0.0), vec2(0.0), vec2(0.0), mat2(1.0, 0.0, 0.0, 1.0), mat2(1.0, 0.0, 0.0, 1.0), mat2(1.0, 0.0, 0.0, 1.0), vec2(0.0), vec2(0.0), vec3(1.0, 0.0, 0.0));
    vec3 hex_weights = vec3(1.0, 0.0, 0.0);
    vec4 tex_colour = vec4(0.0);
    if (material.triplanar > 0.0) {
        tri = ae3d_shaders_lit_tri_setup(normalize(Normal), FragPos, material.triplanar);
        tri_on = 1;
        tex_colour = ae3d_shaders_lit_tri_texture(colour_map, tri);
    } else if (material.tile_breakup > 0.0) {
        hx = ae3d_shaders_lit_hex_setup(fragTexCoord, material.tile_rotation);
        hex_on = 1;
        HexColour hc = ae3d_shaders_lit_hex_texture(colour_map, hx);
        tex_colour = hc.colour;
        hex_weights = hc.weights;
    } else {
        tex_colour = texture(colour_map, fragTexCoord);
        if (FlipNext.z >= 0.0) {
            tex_colour = mix(tex_colour, texture(colour_map, FlipNext.xy), FlipNext.z);
        }
    }
    if (tex_colour.w < material.cutout) {
        discard;
    }
    float detail_weight = 0.0;
    if (material.detail_scale > 0.0 && tri_on == 0) {
        float away = length(FragPos - eye.position);
        detail_weight = material.detail_strength * (1.0 - smoothstep(material.detail_fade * 0.5, material.detail_fade, away));
    }
    if (material.fire > 0.0) {
        float heat = clamp(tex_colour.x * InstanceColor.x, 0.0, 1.0);
        vec3 glowing = ae3d_shaders_lit_black_body(heat * material.fire) * (heat * heat * heat * heat) * max(material.exposure * 0.1, 1.0);
        out_colour = vec4(glowing * material.diffuse, tex_colour.w * material.alpha * ParticleAlpha * ae3d_shaders_lit_soft_fade());
        out_velocity = moved;
        return;
    }
    if (material.exposure > 10.0) {
        float glow_alpha = material.blend != 0 ? tex_colour.w * material.alpha * ParticleAlpha * ae3d_shaders_lit_soft_fade() : 1.0;
        out_colour = vec4(material.diffuse * tex_colour.rgb * InstanceColor * (material.exposure * 0.1), glow_alpha);
        out_velocity = moved;
        return;
    }
    vec3 norm = normalize(Normal);
    float normal_variance = 0.0;
    if (draw.impostor != 0) {
        if (tex_colour.w < 0.5) {
            discard;
        }
        vec3 facing = normalize(Normal);
        vec3 baked = texture(normal_map, fragTexCoord).xyz * 2.0 - vec3(1.0);
        norm = normalize(facing * baked.x + vec3(0.0, baked.y, 0.0) + vec3(-facing.z, 0.0, facing.x) * baked.z);
    } else if (material.normal_map != 0) {
        MappedNormal mn = ae3d_shaders_lit_mapped_normal(norm, FragPos, fragTexCoord, tri_on, tri, hex_on, hx, hex_weights, detail_weight);
        norm = mn.normal;
        normal_variance = mn.variance;
    }
    if (eye.capture == 1) {
        out_colour = vec4(material.diffuse * tex_colour.rgb * InstanceColor, tex_colour.w);
        out_velocity = moved;
        return;
    }
    if (eye.capture == 2) {
        out_colour = vec4(norm * 0.5 + vec3(0.5), 1.0);
        out_velocity = moved;
        return;
    }
    if (eye.capture == 3) {
        vec2 shown = moved * eye.screen_size / 200.0 + vec2(0.5);
        out_colour = vec4(vec3(shown.x, shown.y, 0.0), 1.0);
        out_velocity = moved;
        return;
    }
    vec3 view_dir = normalize(eye.position - FragPos);
    vec3 albedo0 = material.diffuse * tex_colour.rgb * InstanceColor;
    vec3 albedo1 = albedo0;
    if (wounds.count > 0) {
        albedo1 = mix(albedo0, wounds.layers[0].rgb, ae3d_shaders_lit_splat_cover(BindPos));
    }
    vec2 mask_at = damage.rect.xy + clamp(MaskUV, vec2(damage.clamp), vec2(1.0 - damage.clamp)) * vec2(damage.rect.z, damage.rect.w);
    vec4 damaged = texture(damage_mask, mask_at);
    vec3 albedo2 = albedo1;
    if (damage.on != 0) {
        for (int k = 0; k < 4; k += 1) {
            albedo2 = mix(albedo2, damage.colours[k].rgb, clamp(damaged[k] * damage.colours[k].w, 0.0, 1.0));
        }
    }
    vec3 albedo3 = albedo2;
    if (wound_at < 1.0) {
        vec3 layer = wounds.layers[0].rgb;
        for (int j = 1; j < 4; j += 1) {
            if (wound_at < wounds.layers[j].w) {
                layer = wounds.layers[j].rgb;
            }
        }
        albedo3 = mix(albedo2, layer, smoothstep(1.0, 0.94, wound_at));
    }
    vec3 albedo4 = albedo3;
    if (detail_weight > 0.0) {
        vec3 fine = texture(colour_map, fragTexCoord * material.detail_scale).rgb;
        vec3 mean = max(textureLod(colour_map, fragTexCoord, 16.0).rgb, vec3(0.02));
        albedo4 = albedo3 * mix(vec3(1.0), clamp(fine / mean, vec3(0.0), vec3(2.0)), detail_weight);
    }
    vec3 albedo5 = albedo4;
    if (material.variation > 0.0) {
        vec3 cell = FragPos / max(material.variation_scale, 0.01);
        float v0 = ae3d_shaders_lit_clip_value_noise(cell) * 0.65 + ae3d_shaders_lit_clip_value_noise(cell * 2.7 + vec3(13.1, 7.3, 2.9)) * 0.35;
        float v1 = smoothstep(0.25, 0.75, v0);
        albedo5 = albedo4 * (1.0 + (v1 * 2.0 - 1.0) * material.variation);
    }
    vec3 albedo6 = albedo5;
    if (shading.perlin != 0) {
        vec3 noise_coord = FragPos * shading.noise_scale;
        float noise_value = ae3d_shaders_lit_turbulence(noise_coord, shading.noise_octaves);
        albedo6 = mix(albedo5, albedo5 * (1.0 + noise_value * 0.3), shading.noise_intensity);
    }
    vec3 f0a = vec3(0.04) * material.specular;
    vec3 f0 = f0a;
    if (material.metallic > 0.5) {
        vec3 metal_f0 = albedo6;
        if (albedo6.x > albedo6.y && albedo6.x > albedo6.z) {
            metal_f0 = mix(vec3(0.95, 0.64, 0.54), albedo6, 0.7);
        } else if (albedo6.y > albedo6.x && albedo6.y > albedo6.z) {
            metal_f0 = mix(vec3(0.70, 0.78, 0.74), albedo6, 0.7);
        } else if (albedo6.z > albedo6.x && albedo6.z > albedo6.y) {
            metal_f0 = mix(vec3(0.66, 0.73, 0.80), albedo6, 0.7);
        } else {
            metal_f0 = mix(vec3(0.95, 0.93, 0.88), albedo6, 0.7);
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
    vec3 albedo = albedo6;
    if (wet > 0.001) {
        albedo = albedo6 * (1.0 - 0.35 * wet);
        adjusted = max(mix(adjusted0, 0.05, wet), 0.08);
        wet_mirror = wet * 0.7;
    } else {
        wet_mirror = 0.0;
    }
    float shaded0 = 1.0;
    if (cascades.on != 0 && shading.shadows != 0) {
        shaded0 = ae3d_shaders_lit_shadow_factor();
    }
    float shaded = shaded0;
    if (grid.key_lamp >= 0 && grid.lamp_base >= 0 && shading.shadows != 0) {
        shaded = ae3d_shaders_lit_lamp_shadow(grid.key_lamp, normalize(Normal));
    }
    float sunlit = ae3d_shaders_lit_cloud_shadow(FragPos);
    vec3 lo = vec3(0.0);
    for (int i = 0; i < 16; i += 1) {
        if (i >= world.light_count) {
            break;
        }
        if (world.lights[i].kind != 1) {
            vec3 gap = world.lights[i].position - FragPos;
            if (dot(gap, gap) * world.lights[i].quadratic > 64.0) {
                continue;
            }
            if (world.lights[i].kind == 2 && dot(normalize(-gap), normalize(world.lights[i].direction)) < world.lights[i].cos_outer) {
                continue;
            }
        }
        DirectLight dl = ae3d_shaders_lit_direct_light(world.lights[i], norm, view_dir, albedo, f0, ndotv, adjusted, wet_mirror);
        lo = lo + (i == 0 ? dl.lit * sunlit * shaded : dl.lit) + dl.back_fill;
    }
    if (material.glitter > 0.0 && world.light_count > 0 && world.lights[0].kind == 1) {
        lo = lo + ae3d_shaders_lit_glitter(norm, view_dir, world.lights[0]) * sunlit * shaded;
    }
    if (grid.dims.w > 0.5) {
        int cell_at = ae3d_shaders_lit_cluster_of(FragPos);
        int first = int((cluster_words[(cell_at * 2)] + 0.5));
        int count = int((cluster_words[(cell_at * 2 + 1)] + 0.5));
        for (int k2 = 0; k2 < count; k2 += 1) {
            ClusterLamp cl = ae3d_shaders_lit_clustered_light(int((cluster_words[(first + k2)] + 0.5)));
            WorldLight lamp = cl.light;
            vec3 lgap = lamp.position - FragPos;
            float far2 = dot(lgap, lgap);
            if (far2 >= cl.reach * cl.reach) {
                continue;
            }
            if (lamp.kind == 2 && dot(normalize(-lgap), normalize(lamp.direction)) < lamp.cos_outer) {
                continue;
            }
            float fade_out = 1.0 - smoothstep(0.75 * cl.reach, cl.reach, sqrt(far2));
            DirectLight ldl = ae3d_shaders_lit_direct_light(lamp, norm, view_dir, albedo, f0, ndotv, adjusted, wet_mirror);
            vec3 lit = ldl.lit * fade_out;
            lo = lo + ldl.back_fill * fade_out;
            float shade = 1.0;
            if (cl.slot >= 0 && grid.lamp_base >= 0 && shading.shadows != 0 && dot(lit, vec3(0.333)) > 0.002) {
                shade = ae3d_shaders_lit_lamp_shadow(cl.slot, normalize(Normal));
            }
            lo = lo + lit * shade;
        }
    }
    float shut = mix(1.0, Occlusion, world.occlusion_strength) * ae3d_shaders_lit_screen_occlusion();
    vec3 colour0 = ae3d_shaders_lit_sky_lit(norm, view_dir, albedo, f0, adjusted, material.metallic, ndotv) * shut + lo;
    float distance_to_camera = length(FragPos - eye.position);
    vec3 volumetric = ae3d_shaders_lit_calculate_volumetric_lighting(FragPos, world.lights[0].position, eye.position);
    vec3 colour1 = colour0 + volumetric;
    vec3 colour2 = colour1 + ae3d_shaders_lit_caustic_light(FragPos, norm) * albedo;
    vec3 colour3 = colour2 * material.exposure;
    vec3 colour4 = colour3;
    if (material.embers > 0.0) {
        colour4 = colour3 + ae3d_shaders_lit_ember_light();
    }
    vec3 colour = colour4;
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
        final_alpha = tex_colour.w * material.alpha * ParticleAlpha * ae3d_shaders_lit_soft_fade();
    }
    out_colour = vec4(colour, final_alpha);
    out_velocity = moved;
}
