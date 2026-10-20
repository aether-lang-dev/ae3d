#version 450
// crowd_pull_vertex: written by ae3d.gpu from its quote.

struct Throng {
    mat4 model;
    int frames;
    int impostor;
    int columns;
    int rows;
    float width;
    float height;
    float travel;
    float phase_step;
    int pull_bits;
};
struct Eye {
    mat4 view_projection;
    mat4 prev_view_projection;
    vec3 position;
};
struct Shadow {
    mat4 light_space;
};
layout(std140, set = 4, binding = 0) uniform VertexParams {
    Throng throng;
    Eye eye;
    Shadow shadow;
};
layout(set = 4, binding = 1) uniform sampler2D pose_bank;
layout(std430, set = 3, binding = 0) readonly buffer pulled_vertex_buffer { float pulled_vertex[]; };
layout(std430, set = 3, binding = 1) readonly buffer pulled_skin_buffer { vec4 pulled_skin[]; };
layout(std430, set = 3, binding = 2) readonly buffer pulled_figure_buffer { float pulled_figure[]; };

layout(location = 0) out vec2 fragTexCoord;
layout(location = 1) out vec3 Normal;
layout(location = 2) out vec3 FragPos;
layout(location = 3) out vec3 InstanceColor;
layout(location = 4) out vec4 FragPosLightSpace;
layout(location = 5) out float Occlusion;
layout(location = 6) out vec4 ClipNow;
layout(location = 7) out vec4 ClipPrev;
layout(location = 8) out vec3 BindPos;
layout(location = 9) out float ClipLimb;
layout(location = 10) out vec2 MaskUV;
layout(location = 11) out float ParticleAlpha;
layout(location = 12) out vec3 FlipNext;

mat4 ae3d_shaders_throng_bone_at(sampler2D bank, int bone, int frame) {
    int x = bone * 4;
    return mat4(texelFetch(bank, ivec2((x + 0), frame), 0), texelFetch(bank, ivec2((x + 1), frame), 0), texelFetch(bank, ivec2((x + 2), frame), 0), texelFetch(bank, ivec2((x + 3), frame), 0));
}

mat4 ae3d_shaders_throng_skin_at(sampler2D bank, vec4 joints, vec4 weights, int frame) {
    return ((((weights.x * ae3d_shaders_throng_bone_at(bank, int(joints.x), frame)) + (weights.y * ae3d_shaders_throng_bone_at(bank, int(joints.y), frame))) + (weights.z * ae3d_shaders_throng_bone_at(bank, int(joints.z), frame))) + (weights.w * ae3d_shaders_throng_bone_at(bank, int(joints.w), frame)));
}

mat4 ae3d_shaders_throng_skin_at_phase(sampler2D bank, vec4 joints, vec4 weights, float phase, int frames) {
    float fpos = fract(phase) * float(frames);
    int frame0 = int(floor(fpos));
    float blend = fpos - float(frame0);
    if (frame0 < 0) {
        frame0 = 0;
        blend = 0.0;
    }
    if (frame0 >= frames) {
        frame0 = frames - 1;
        blend = 0.0;
    }
    int frame1 = frame0 + 1;
    if (frame1 >= frames) {
        frame1 = 0;
    }
    return ((ae3d_shaders_throng_skin_at(bank, joints, weights, frame0) * (1.0 - blend)) + (ae3d_shaders_throng_skin_at(bank, joints, weights, frame1) * blend));
}

void main() {
    uint bits = uint(throng.pull_bits);
    uint vi = uint(int(gl_VertexIndex)) & (uint(1) << bits) - uint(1);
    uint f = (uint(int(gl_VertexIndex)) >> bits) * uint(20);
    uint at = vi * uint(9);
    vec3 position = vec3(pulled_vertex[at], pulled_vertex[(at + uint(1))], pulled_vertex[(at + uint(2))]);
    vec2 uv = vec2(pulled_vertex[(at + uint(3))], pulled_vertex[(at + uint(4))]);
    vec3 normal = vec3(pulled_vertex[(at + uint(5))], pulled_vertex[(at + uint(6))], pulled_vertex[(at + uint(7))]);
    float occlusion = pulled_vertex[(at + uint(8))];
    vec4 joints = pulled_skin[(vi * uint(3))];
    vec4 weights = pulled_skin[(vi * uint(3) + uint(1))];
    mat4 instance_model = mat4(pulled_figure[f], pulled_figure[(f + uint(1))], pulled_figure[(f + uint(2))], pulled_figure[(f + uint(3))], pulled_figure[(f + uint(4))], pulled_figure[(f + uint(5))], pulled_figure[(f + uint(6))], pulled_figure[(f + uint(7))], pulled_figure[(f + uint(8))], pulled_figure[(f + uint(9))], pulled_figure[(f + uint(10))], pulled_figure[(f + uint(11))], pulled_figure[(f + uint(12))], pulled_figure[(f + uint(13))], pulled_figure[(f + uint(14))], pulled_figure[(f + uint(15))]);
    vec3 instance_color = vec3(pulled_figure[(f + uint(16))], pulled_figure[(f + uint(17))], pulled_figure[(f + uint(18))]);
    float instance_phase = pulled_figure[(f + uint(19))];
    mat4 model_matrix = (throng.model * instance_model);
    vec3 walking = normalize(vec3(model_matrix[0][0], 0.0, model_matrix[0][2]));
    if (throng.impostor != 0) {
        vec3 origin = model_matrix[3].xyz;
        vec3 facing = normalize(vec3(model_matrix[0][0], 0.0, model_matrix[0][2]));
        vec3 to_eye = eye.position - origin;
        vec3 level = normalize(vec3(to_eye.x, 0.0, to_eye.z));
        float angle = atan(dot(level, vec3(-facing.z, 0.0, facing.x)), dot(level, facing));
        float turn = fract(angle / 6.28318530718 + 1.0);
        int column = int(floor(turn * float(throng.columns) + 0.5)) % throng.columns;
        int row = int(floor(fract(instance_phase) * float(throng.rows))) % throng.rows;
        vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), level));
        vec3 world = origin + right * (position.x * throng.width) + vec3(0.0, position.y * throng.height, 0.0);
        vec2 cell = vec2((float(column) + uv.x) / float(throng.columns), 1.0 - (float(row) + (1.0 - uv.y)) / float(throng.rows));
        vec4 quad_light = (shadow.light_space * vec4(world, 1.0));
        vec4 quad_now = (eye.view_projection * vec4(world, 1.0));
        vec4 quad_prev = (eye.prev_view_projection * vec4(world - walking * throng.travel, 1.0));
        gl_Position = quad_now;
        fragTexCoord = cell;
        Normal = facing;
        FragPos = world;
        InstanceColor = instance_color;
        FragPosLightSpace = quad_light;
        Occlusion = occlusion;
        ClipNow = quad_now;
        ClipPrev = quad_prev;
        BindPos = position;
        ClipLimb = 1.0;
        MaskUV = uv;
        ParticleAlpha = 1.0;
        FlipNext = vec3(0.0, 0.0, -1.0);
        return;
    }
    mat4 skin = ae3d_shaders_throng_skin_at_phase(pose_bank, joints, weights, instance_phase, throng.frames);
    vec4 posed = (skin * vec4(position, 1.0));
    vec3 posed_normal = (mat3(skin) * normal);
    vec3 frag_pos = (model_matrix * posed).xyz;
    vec3 normal_out = normalize((mat3(model_matrix) * posed_normal));
    vec4 light = (shadow.light_space * vec4(frag_pos, 1.0));
    vec4 now = ((eye.view_projection * model_matrix) * posed);
    vec4 posed_prev = (ae3d_shaders_throng_skin_at_phase(pose_bank, joints, weights, instance_phase - throng.phase_step, throng.frames) * vec4(position, 1.0));
    vec4 world_prev = (model_matrix * posed_prev);
    vec4 stepped = vec4(world_prev.xyz - walking * throng.travel, world_prev.w);
    vec4 prev = (eye.prev_view_projection * stepped);
    gl_Position = now;
    fragTexCoord = uv;
    Normal = normal_out;
    FragPos = frag_pos;
    InstanceColor = instance_color;
    FragPosLightSpace = light;
    Occlusion = occlusion;
    ClipNow = now;
    ClipPrev = prev;
    BindPos = position;
    ClipLimb = 1.0;
    MaskUV = uv;
    ParticleAlpha = 1.0;
    FlipNext = vec3(0.0, 0.0, -1.0);
}
