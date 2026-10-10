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
    float pointLift;
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
    int hasSceneDepth;
    mat4 invViewProjection;
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
    vec3 groundAlbedo;
    vec3 groundSun;
    float frameExposure;
    bool enableBloom;
    float bloomIntensity;
    int hazeCount;
    vec4 hazeColumn[4];
    vec4 hazeShape[4];
    vec2 texelSize;
    int bloomFirst;
    float bloomThreshold;
    int bloomTop;
    float edgeThreshold;
    float edgeThresholdMin;
    float subpixelQuality;
    int colorSampleCount;
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
    float waterLevel;
    vec3 skyColor;
    vec3 horizonColor;
    bool enableWaterReflection;
    float waterReflectionIntensity;
    int hasSkyTexture;
    int waterSkyCapture;
    vec3 rippleArea;
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
// The direction a texel of a level `size` a side stands for, at texture
// coordinate uv: a gutter texel's folded back across the edge it lies past.
vec3 oct_texel_direction(vec2 uv, float size) {
    vec2 p = ((uv * size - 1.0) / (size - 2.0)) * 2.0 - 1.0;
    if (p.x > 1.0) { p.x = 2.0 - p.x; p.y = -p.y; }
    if (p.x < -1.0) { p.x = -2.0 - p.x; p.y = -p.y; }
    if (p.y > 1.0) { p.y = 2.0 - p.y; p.x = -p.x; }
    if (p.y < -1.0) { p.y = -2.0 - p.y; p.x = -p.x; }
    return oct_decode(p);
}

#define FILTER_SAMPLES 48

float radical_inverse(uint bits) {
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10;
}

void main() {
    // Laid out as level 0 is, whatever this level's size, so the scene
    // reads every level at one coordinate (sky_reflection).
    vec3 N = oct_texel_direction(gl_FragCoord.xy / skyLevelSize, SKY_SIZE);
    if (skyRoughness <= 0.0) {
        FragColor = vec4(textureLod(skyCapture, oct_uv(N, SKY_SIZE), 0.0).rgb, 1.0);
        return;
    }
    float a = skyRoughness * skyRoughness;
    vec3 up = abs(N.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(up, N));
    vec3 B = cross(N, T);
    // A texel of the capture's level 0, as solid angle: the whole sphere
    // over its inner texels.
    float texel = 4.0 * 3.14159265 / ((SKY_SIZE - 2.0) * (SKY_SIZE - 2.0));
    vec3 sum = vec3(0.0);
    float weight = 0.0;
    for (int i = 0; i < FILTER_SAMPLES; i++) {
        vec2 xi = vec2((float(i) + 0.5) / float(FILTER_SAMPLES), radical_inverse(uint(i)));
        float phi = 6.28318531 * xi.y;
        float cosTheta = sqrt((1.0 - xi.x) / (1.0 + (a * a - 1.0) * xi.x));
        float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
        vec3 H = T * (sinTheta * cos(phi)) + B * (sinTheta * sin(phi)) + N * cosTheta;
        vec3 L = 2.0 * dot(N, H) * H - N;
        float NdotL = dot(N, L);
        if (NdotL <= 0.0) continue;
        // With the view along the normal, the pdf of L is D(H) / 4.
        float d = (cosTheta * cosTheta * (a * a - 1.0) + 1.0);
        float pdf = (a * a) / (3.14159265 * d * d) / 4.0;
        float sampleAngle = 1.0 / (float(FILTER_SAMPLES) * pdf + 1e-6);
        float lod = max(0.5 * log2(sampleAngle / texel) + 1.0, 0.0);
        sum += textureLod(skyCapture, oct_uv(L, SKY_SIZE), lod).rgb * NdotL;
        weight += NdotL;
    }
    FragColor = vec4(sum / max(weight, 1e-6), 1.0);
}
