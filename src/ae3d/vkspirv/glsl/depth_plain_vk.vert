#version 450
#define AE3D_UNSKINNED 1

struct Light {
    vec3 position;
    vec3 color;
    float intensity;
    float temperature;
    int isDirectional;
    vec3 direction;
    float constantAtten;
    float linearAtten;
    float quadraticAtten;
    float spotCosOuter;
    float spotCosInner;
};

layout(std140, set = 0, binding = 0) uniform DrawBlock {
    mat4 model;
    mat4 prevModel;
    mat4 lightSpaceMatrix;
    bool isInstanced;
    bool useInstanceColor;
    bool instancePoints;
    int instanceBillboard;
    int pointFlipbookColumns;
    int pointFlipbookRows;
    float pointLift;
    bool isSkinned;
    bool impostor;
    vec3 diffuseColor;
    vec3 specularColor;
    float metallic;
    float roughness;
    float exposure;
    float materialAlpha;
    float materialCutout;
    float materialNormalStrength;
    float materialTileBreakup;
    float materialTileRotation;
    float materialVariation;
    float materialVariationScale;
    float materialDetailScale;
    float materialDetailStrength;
    float materialDetailFade;
    float materialFire;
    float materialTriplanar;
    float materialSoft;
    float materialGlitter;
    float materialGlitterGrains;
    float materialGlitterStrength;
    float materialEmbers;
    float materialEmberCover;
    float materialEmberGlow;
    int surfaceBlend;
    float reflectivity;
    bool hasNormalMap;
    bool enableShadows;
    float shadowIntensity;
    float shadowSoftness;
    bool enableClearcoat;
    float clearcoatRoughness;
    float clearcoatIntensity;
    bool enableSheen;
    vec3 sheenColor;
    float sheenRoughness;
    bool enableTransmission;
    float transmissionFactor;
    bool enableMultipleScattering;
    bool enableEnergyConservation;
    bool enableImageBasedLighting;
    float iblIntensity;
    bool enableVolumetricLighting;
    float volumetricIntensity;
    int volumetricSteps;
    float volumetricScattering;
    bool enablePerlinNoise;
    float noiseScale;
    int noiseOctaves;
    float noiseIntensity;
    bool enableCaustics;
    float causticsIntensity;
    float causticsScale;
    float causticsSpeed;
    float causticsWaterLevel;
    float causticsDepth;
    bool clipOn;
    vec4 clipPlane;
    bool clipDetached;
    float clipNoise;
    float clipNoiseScale;
    int clipJoints0;
    int clipJoints1;
    int clipJoints2;
    float draw_pad0;
    float draw_pad1;
    int woundCount;
    vec4 woundData[96];
    vec4 woundLayers[4];
    float woundCore;
    float draw_pad2;
    float draw_pad3;
    float draw_pad4;
    int damageOn;
    vec4 damageColours[4];
    vec4 damageRect;
    float damageClamp;
    mat4 bones[96];
    vec4 prevBoneRows[288];
};
layout(std140, set = 1, binding = 0) uniform CameraBlock {
    mat4 viewProjection;
    mat4 prevViewProjection;
    mat4 invViewProjection;
    vec3 viewPos;
    float viewDistance;
    vec2 jitter;
    vec2 screenSize;
    int hasSceneDepth;
    vec4 viewDepth;
    int occlusionHistory;
    int captureChannel;
    float rayReach;
    int rayFrame;
    bool hasShadowMap;
    mat4 cascadeMatrices[4];
    vec4 cascadeSplits;
    vec4 cascadeTexelWorld;
    int cascadeCount;
    vec4 clusterDims;
    vec4 clusterDepth;
    mat4 clusterViewProjection;
    int lampShadowBase;
    int keyLampSlot;
    float camera_pad0;
    float camera_pad1;
    int ddgiOn;
    vec4 ddgiDims;
    vec4 ddgiBase[2];
    vec4 ddgiSpacing;
    vec4 ddgiAtlas;
};
layout(std140, set = 2, binding = 0) uniform WorldBlock {
    Light lights[16];
    int lightCount;
    vec3 shadowDirection;
    float cloudCover;
    float cloudTime;
    vec3 cloudSun;
    float causticsTime;
    float wetness;
    float normalStrength;
    float occlusionStrength;
    int giOff;
    int rayShadows;
    float sunAngle;
    float rayOcclusion;
    float rayOcclusionStrength;
    float rayLampRadius;
    float world_pad0;
    float world_pad1;
    float world_pad2;
    bool enableFog;
    float fogStart;
    float fogEnd;
    vec3 fogRadiance;
    float fogIntensity;
};
layout (location = 0) in vec3 inPosition;
layout (location = 3) in mat4 instanceModel;
#ifdef AE3D_UNSKINNED
// Vulkan's plain shadow pipelines name no skin stream (ae3d.vkpipes).
const vec4 inJoints = vec4(0.0);
const vec4 inWeights = vec4(0.0);
#else
layout (location = 8) in vec4 inJoints;
layout (location = 9) in vec4 inWeights;
#endif












layout(location = 0) out vec3 BindPos;
layout(location = 1) out float ClipLimb;

// The joints a cut is kept to (#556), as three words of 32 bits: joint j is
// bit j % 32 of word j / 32. None named, the cut is the whole model's.




float clipJointOn(float joint) {
    int j = int(joint + 0.5);
    int word = j < 32 ? clipJoints0 : (j < 64 ? clipJoints1 : clipJoints2);
    return float((word >> (j & 31)) & 1);
}

// The share of the vertex's weight on the cut's joints: 1 where none are
// named or the model is not skinned. The fragment cuts where it is past
// one half, so the cut's edge across the body is the limb's own weighting.
float clipLimbOf(vec4 joints, vec4 weights) {
    if (!isSkinned || (clipJoints0 | clipJoints1 | clipJoints2) == 0) return 1.0;
    return weights.x * clipJointOn(joints.x) + weights.y * clipJointOn(joints.y)
         + weights.z * clipJointOn(joints.z) + weights.w * clipJointOn(joints.w);
}

void main() {
    BindPos = inPosition;
    ClipLimb = clipLimbOf(inJoints, inWeights);
    // The same transform the lit pass builds. Reading instanceModel alone left
    // an instanced model casting its shadow from wherever its own transform was
    // not applied.
    mat4 modelMatrix = isInstanced ? (model * instanceModel) : model;
    if (isInstanced && instancePoints) {
        vec4 point = instanceModel[0];
        modelMatrix = mat4(model[0] * point.w, model[1] * point.w, model[2] * point.w,
                           vec4(point.xyz, 1.0));
        // A billboard: the mesh turned to the eye, its +Z toward the camera
        // -- upright, spun about the world's up alone, for a streak of rain
        // that stays a streak; or full, tipped to face the eye as well, for
        // a flake. The model's own scale stays, its rotation does not.
        if (instanceBillboard > 0) {
            vec3 toEye = viewPos - point.xyz;
            vec3 up = vec3(0.0, 1.0, 0.0);
            vec3 forward;
            if (instanceBillboard == 1) {
                forward = normalize(vec3(toEye.x, 0.0, toEye.z));
            } else {
                forward = normalize(toEye);
            }
            vec3 right = normalize(cross(up, forward));
            up = cross(forward, right);
            float sx = length(vec3(model[0])) * point.w;
            float sy = length(vec3(model[1])) * point.w;
            float sz = length(vec3(model[2])) * point.w;
            modelMatrix = mat4(vec4(right * sx, 0.0), vec4(up * sy, 0.0), vec4(forward * sz, 0.0),
                               vec4(point.xyz + up * (sy * pointLift), 1.0));
        }
    }
    // And the same pose. A shadow pass that skipped this drew the bind pose,
    // so a figure threw the shadow of a mannequin standing where it started.
    vec4 posed = vec4(inPosition, 1.0);
    if (isSkinned) {
        mat4 skin = inWeights.x * bones[int(inJoints.x)]
                  + inWeights.y * bones[int(inJoints.y)]
                  + inWeights.z * bones[int(inJoints.z)]
                  + inWeights.w * bones[int(inJoints.w)];
        posed = skin * posed;
    }
    gl_Position = lightSpaceMatrix * modelMatrix * posed;
}
