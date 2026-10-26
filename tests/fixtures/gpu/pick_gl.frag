#version 410 core
// pick: written by ae3d.gpu from its quote.

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
    int pick;
};
uniform Draw draw;
uniform DrawMaterial material;
uniform Cut cut;
uniform Wounds wounds;
uniform Eye eye;
uniform sampler2D colour_map;

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

in vec2 fragTexCoord;
in vec3 Normal;
in vec3 FragPos;
in vec3 BindPos;
in float ClipLimb;
in float Instance;

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
out vec4 FragColor;

void main() {
    if (ae3d_shaders_lit_clipped_away(BindPos)) {
        discard;
    }
    float wound_at = wounds.count > 0 ? ae3d_shaders_lit_wound_depth(BindPos) : 2.0;
    if (wound_at < wounds.core) {
        discard;
    }
    Tri tri = Tri(vec3(0.0, 1.0, 0.0), vec2(0.0), vec2(0.0), vec2(0.0));
    Hex hx = Hex(vec2(0.0), vec2(0.0), vec2(0.0), mat2(1.0, 0.0, 0.0, 1.0), mat2(1.0, 0.0, 0.0, 1.0), mat2(1.0, 0.0, 0.0, 1.0), vec2(0.0), vec2(0.0), vec3(1.0, 0.0, 0.0));
    vec4 tex_colour = vec4(0.0);
    if (material.triplanar > 0.0) {
        tri = ae3d_shaders_lit_tri_setup(normalize(Normal), FragPos, material.triplanar);
        tex_colour = ae3d_shaders_lit_tri_texture(colour_map, tri);
    } else if (material.tile_breakup > 0.0) {
        hx = ae3d_shaders_lit_hex_setup(fragTexCoord, material.tile_rotation);
        tex_colour = ae3d_shaders_lit_hex_texture(colour_map, hx).colour;
    } else {
        tex_colour = texture(colour_map, fragTexCoord);
    }
    if (tex_colour.w < material.cutout) {
        discard;
    }
    if (material.blend != 0 && tex_colour.w * material.alpha < 0.5) {
        discard;
    }
    vec4 ndc = (eye.view_projection * vec4(FragPos, 1.0));
    FragColor = vec4(vec3(float(draw.pick), Instance, ((ndc.z / ndc.w) * 0.5 + 0.5)), 1.0);
}
