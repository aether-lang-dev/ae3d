#version 450

struct Light {
    vec3 position;
    vec3 color;
    float intensity;
    float ambientStrength;
    float temperature;
    int isDirectional;
    vec3 direction;
    float constantAtten;
    float linearAtten;
    float quadraticAtten;
    float spotCosOuter;
    float spotCosInner;
};

layout(std140, set = 0, binding = 0) uniform SceneBlock {
    Light lights[16];
    bool isInstanced;
    bool useInstanceColor;
    bool instancePoints;
    int instanceBillboard;
    vec3 viewPos;
    mat4 model;
    mat4 viewProjection;
    mat4 lightSpaceMatrix;
    mat4 prevModel;
    mat4 prevViewProjection;
    bool isSkinned;
    mat4 bones[96];
    vec4 prevBoneRows[288];
    int clipJoints0;
    int clipJoints1;
    int clipJoints2;
    vec2 jitter;
    vec2 screenSize;
    int lightCount;
    vec4 clusterDims;
    vec4 clusterDepth;
    mat4 clusterViewProjection;
    vec4 viewDepth;
    bool impostor;
    int captureChannel;
    float viewDistance;
    vec3 diffuseColor;
    vec3 specularColor;
    float metallic;
    float roughness;
    float exposure;
    float cloudCover;
    float cloudTime;
    vec3 cloudSun;
    float materialAlpha;
    float reflectivity;
    float wetness;
    float frameExposure;
    bool hasNormalMap;
    float normalStrength;
    float occlusionStrength;
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
    bool enableGlobalIllumination;
    float giIntensity;
    int giBounces;
    bool enableBloom;
    float bloomThreshold;
    float bloomIntensity;
    bool enableFog;
    float fogStart;
    float fogEnd;
    vec3 fogColor;
    float fogIntensity;
    bool enableShadows;
    bool hasShadowMap;
    float shadowIntensity;
    float shadowSoftness;
    vec3 shadowDirection;
    mat4 cascadeMatrices[4];
    vec4 cascadeSplits;
    vec4 cascadeTexelWorld;
    int cascadeCount;
    int rayShadows;
    float sunAngle;
    float rayOcclusion;
    float rayOcclusionStrength;
    float rayLampRadius;
    float rayReach;
    int rayFrame;
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
    float causticsTime;
    int lampShadowBase;
    int keyLampSlot;
    bool clipOn;
    vec4 clipPlane;
    bool clipDetached;
    float clipNoise;
    float clipNoiseScale;
    int woundCount;
    vec4 woundData[96];
    vec4 woundLayers[4];
    float woundCore;
    int damageOn;
    vec4 damageColours[4];
    vec4 damageRect;
    float damageClamp;
    mat4 projection;
    mat4 view;
    vec3 cloudSunColor;
    vec3 skySun;
    int cloudFrame;
    int skyProcedural;
    float skyOvercast;
    vec3 skyOvercastColor;
    vec2 texelSize;
    float edgeThreshold;
    float edgeThresholdMin;
    float subpixelQuality;
    mat4 invViewProjection;
    float ssrRoadHeight;
    float ssrStrength;
    float ssaoRadius;
    float ssaoIntensity;
    int depthSampleCount;
    float taaBlend;
    float time;
    float waveSpeedMultiplier;
    float waveHeightMultiplier;
    float waveRandomness;
    vec3 waveDirections[4];
    float waveAmplitudes[4];
    float waveFrequencies[4];
    float waveSpeeds[4];
    float wavePhases[4];
    float waveSteepness[4];
    vec3 lightPos;
    vec3 lightDirection;
    vec3 lightColor;
    float lightIntensity;
    vec3 waterBaseColor;
    float waterOpacity;
    bool enableFoam;
    float foamIntensity;
    float waterPlaneHeight;
    float waterLevel;
    vec3 skyColor;
    vec3 horizonColor;
    bool enableWaterReflection;
    float waterReflectionIntensity;
    int hasSkyTexture;
    int hasSceneDepth;
    float waterDepthFade;
    float waterShoreFoam;
    bool enableWaterDistortion;
    float waterDistortionIntensity;
    bool enableWaterNormalMapping;
    float waterNormalIntensity;
    int poseBankFrames;
    int impostorCols;
    int impostorRows;
    float impostorWidth;
    float impostorHeight;
    float crowdTravel;
    float crowdPhaseStep;
    vec4 shadowReach;
};
layout (location = 0) in vec3 inPosition;
layout (location = 3) in mat4 instanceModel;
layout (location = 8) in vec4 inJoints;
layout (location = 9) in vec4 inWeights;











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
                               vec4(point.xyz, 1.0));
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
