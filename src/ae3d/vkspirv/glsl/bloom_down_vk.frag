#version 450

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
    int giOff;
    bool enableVolumetricLighting;
    float volumetricIntensity;
    int volumetricSteps;
    float volumetricScattering;
    bool enableFog;
    float fogStart;
    float fogEnd;
    vec3 fogRadiance;
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
    int occlusionHistory;
    int ddgiOn;
    vec4 ddgiDims;
    vec4 ddgiBase[2];
    vec4 ddgiSpacing;
    vec4 ddgiAtlas;
    mat4 projection;
    mat4 view;
    vec3 cloudSunColor;
    vec3 skySun;
    int cloudFrame;
    int skyProcedural;
    float skyOvercast;
    vec3 skyOvercastColor;
    vec3 skyFlat;
    float skyTurbidity;
    float skyLevelSize;
    float skyRoughness;
    float frameExposure;
    bool enableBloom;
    float bloomIntensity;
    vec2 texelSize;
    int bloomFirst;
    float bloomThreshold;
    int bloomTop;
    float edgeThreshold;
    float edgeThresholdMin;
    float subpixelQuality;
    int colorSampleCount;
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
layout(set = 0, binding = 1) uniform sampler2D screenTexture;

layout(location = 0) in vec2 TexCoords;
layout(location = 0) out vec4 FragColor;







vec3 tap(vec2 offset) {
    return texture(screenTexture, TexCoords + offset * texelSize).rgb;
}

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// A group of four taps, by brightness on the first level, plainly after.
vec3 group(vec3 a, vec3 b, vec3 c, vec3 d) {
    if (bloomFirst == 0) return (a + b + c + d) * 0.25;
    float wa = 1.0 / (1.0 + luma(a));
    float wb = 1.0 / (1.0 + luma(b));
    float wc = 1.0 / (1.0 + luma(c));
    float wd = 1.0 / (1.0 + luma(d));
    return (a * wa + b * wb + c * wc + d * wd) / (wa + wb + wc + wd);
}

// What of a colour's light is past the threshold, at the frame's exposure,
// eased in over a knee half the threshold wide below it.
vec3 past_threshold(vec3 c) {
    float light = luma(c) * frameExposure;
    float knee = max(bloomThreshold * 0.5, 0.0001);
    float soft = clamp(light - bloomThreshold + knee, 0.0, 2.0 * knee);
    soft = soft * soft / (4.0 * knee);
    float over = max(soft, light - bloomThreshold) / max(light, 0.0001);
    return c * over;
}

void main() {
    vec3 a = tap(vec2(-2.0, -2.0));
    vec3 b = tap(vec2( 0.0, -2.0));
    vec3 c = tap(vec2( 2.0, -2.0));
    vec3 d = tap(vec2(-1.0, -1.0));
    vec3 e = tap(vec2( 1.0, -1.0));
    vec3 f = tap(vec2(-2.0,  0.0));
    vec3 g = tap(vec2( 0.0,  0.0));
    vec3 h = tap(vec2( 2.0,  0.0));
    vec3 i = tap(vec2(-1.0,  1.0));
    vec3 j = tap(vec2( 1.0,  1.0));
    vec3 k = tap(vec2(-2.0,  2.0));
    vec3 l = tap(vec2( 0.0,  2.0));
    vec3 m = tap(vec2( 2.0,  2.0));
    vec3 sum = group(d, e, i, j) * 0.5
             + group(a, b, f, g) * 0.125 + group(b, c, g, h) * 0.125
             + group(f, g, k, l) * 0.125 + group(g, h, l, m) * 0.125;
    if (bloomFirst != 0) sum = past_threshold(sum);
    FragColor = vec4(sum, 1.0);
}
