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
    int pointFlipbookColumns;
    int pointFlipbookRows;
    vec3 viewPos;
    mat4 model;
    mat4 viewProjection;
    mat4 lightSpaceMatrix;
    mat4 prevModel;
    mat4 prevViewProjection;
    bool isSkinned;
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
    float materialCutout;
    float materialNormalStrength;
    int surfaceBlend;
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
    int pullVertexBits;
    int poseBankFrames;
    int impostorCols;
    int impostorRows;
    float impostorWidth;
    float impostorHeight;
    float crowdTravel;
    float crowdPhaseStep;
    vec4 shadowReach;
    mat4 bones[96];
    vec4 prevBoneRows[288];
};
layout(set = 0, binding = 1) uniform sampler2D skyCapture;
layout(location = 0) out vec4 FragColor;



// The octahedral sky map (ae3d.skylight, whose arithmetic this must match):
// the upper hemisphere in the square's inner diamond, the lower folded into
// its corners, one texel of gutter around each level holding the sky just
// across the fold, so a filtered read at an edge is still the sky.
#define SKY_SIZE 256.0
#define SKY_LEVELS 6.0
#define SKY_IRRADIANCE_SIZE 16.0
vec3 oct_decode(vec2 p) {
    vec3 d = vec3(p.x, 1.0 - abs(p.x) - abs(p.y), p.y);
    if (d.y < 0.0) {
        vec2 folded = (1.0 - abs(d.zx)) * vec2(d.x >= 0.0 ? 1.0 : -1.0, d.z >= 0.0 ? 1.0 : -1.0);
        d.x = folded.x;
        d.z = folded.y;
    }
    return normalize(d);
}
vec2 oct_encode(vec3 d) {
    d /= abs(d.x) + abs(d.y) + abs(d.z);
    vec2 p = d.xz;
    if (d.y < 0.0) p = (1.0 - abs(p.yx)) * vec2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);
    return p;
}
// Where direction d is read in a level `size` texels a side.
vec2 oct_uv(vec3 d, float size) {
    return ((oct_encode(d) * 0.5 + 0.5) * (size - 2.0) + 1.0) / size;
}
vec3 oct_texel_direction(vec2 uv, float size) {
    vec2 p = ((uv * size - 1.0) / (size - 2.0)) * 2.0 - 1.0;
    if (p.x > 1.0) { p.x = 2.0 - p.x; p.y = -p.y; }
    if (p.x < -1.0) { p.x = -2.0 - p.x; p.y = -p.y; }
    if (p.y > 1.0) { p.y = 2.0 - p.y; p.x = -p.x; }
    if (p.y < -1.0) { p.y = -2.0 - p.y; p.x = -p.x; }
    return oct_decode(p);
}

void main() {
    vec3 N = oct_texel_direction(gl_FragCoord.xy / SKY_IRRADIANCE_SIZE, SKY_IRRADIANCE_SIZE);
    int level = int(log2(SKY_SIZE / SKY_IRRADIANCE_SIZE) + 0.5);
    int n = int(SKY_IRRADIANCE_SIZE);
    vec3 sum = vec3(0.0);
    float total = 0.0;
    for (int y = 0; y < n; y++) {
        for (int x = 0; x < n; x++) {
            vec2 uv = (vec2(float(x), float(y)) + 0.5) / SKY_IRRADIANCE_SIZE;
            vec2 p = clamp(((uv * SKY_SIZE - 1.0) / (SKY_SIZE - 2.0)) * 2.0 - 1.0, -1.0, 1.0);
            vec3 q = vec3(p.x, 1.0 - abs(p.x) - abs(p.y), p.y);
            if (q.y < 0.0) {
                vec2 folded = (1.0 - abs(q.zx)) * vec2(q.x >= 0.0 ? 1.0 : -1.0, q.z >= 0.0 ? 1.0 : -1.0);
                q.x = folded.x;
                q.z = folded.y;
            }
            float len = length(q);
            float angle = 1.0 / (len * len * len);
            vec3 L = q / len;
            sum += texelFetch(skyCapture, ivec2(x, y), level).rgb * max(dot(N, L), 0.0) * angle;
            total += angle;
        }
    }
    // The weights cover the sphere once: what they sum to stands for 4 pi.
    FragColor = vec4(sum * (4.0 * 3.14159265 / total), 1.0);
}
