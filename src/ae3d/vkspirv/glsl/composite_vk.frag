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
    float waterPlaneHeight;
    float waterLevel;
    vec3 skyColor;
    vec3 horizonColor;
    bool enableWaterReflection;
    float waterReflectionIntensity;
    int hasSkyTexture;
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
layout(set = 0, binding = 1) uniform sampler2D screenTexture;
layout(set = 0, binding = 2) uniform sampler2D shadowMap;
layout(set = 0, binding = 3) uniform sampler2D bloomTexture;

layout(location = 0) in vec2 TexCoords;
layout(location = 0) out vec4 FragColor;




// A glow around what shows bright: the bloom pyramid's widest blur of the
// light past the threshold (FRAGMENT_BLOOM_DOWN, FRAGMENT_BLOOM_UP), added
// to the light before the tone curve.



// Heat haze (#738): up to four columns of hot air over fires, each a base
// and a radius (hazeColumn) and a height, a strength and the phase its
// shimmer has risen to (hazeShape), projected by the frame's own camera;
// what is seen through one ripples, most just over the fire, rising.





vec2 haze_screen(vec3 p, out float w) {
    vec4 c = viewProjection * vec4(p, 1.0);
    w = c.w;
    return c.xy / max(c.w, 0.0001) * 0.5 + 0.5;
}

float haze_hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float haze_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(haze_hash(i), haze_hash(i + vec2(1.0, 0.0)), f.x),
               mix(haze_hash(i + vec2(0.0, 1.0)), haze_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// How far the image is pulled at `uv` by the hot air over it.
vec2 haze_offset(vec2 uv) {
    vec2 offset = vec2(0.0);
    for (int k = 0; k < 4; k++) {
        if (k >= hazeCount) break;
        float wb;
        float wt;
        vec2 b = haze_screen(hazeColumn[k].xyz, wb);
        vec2 t = haze_screen(hazeColumn[k].xyz + vec3(0.0, hazeShape[k].x, 0.0), wt);
        if (wb <= 0.0 || wt <= 0.0) continue;
        vec2 axis = t - b;
        float len2 = dot(axis, axis);
        if (len2 < 1e-10) continue;
        float along = dot(uv - b, axis) / len2;
        // Wider as it rises, as a plume spreads.
        float width = hazeColumn[k].w * abs(viewProjection[0][0]) / wb * 0.5 * (1.0 + 0.6 * along);
        float across = abs(uv.x - (b.x + axis.x * along)) / max(width, 1e-6);
        if (along < 0.0 || along > 1.0 || across > 1.0) continue;
        float amount = hazeShape[k].y * smoothstep(0.0, 0.08, along) * (1.0 - along) * (1.0 - across * across);
        vec2 q = vec2(across * 3.0 + float(k) * 7.1, along * 7.0 - hazeShape[k].z);
        vec2 n = vec2(haze_noise(q * 2.3), haze_noise(q * 2.3 + vec2(17.3, 5.9))) - 0.5;
        offset += n * amount * width * 0.18;
    }
    return offset;
}

vec3 aces(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

float srgb_encode(float c) {
    return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1.0 / 2.4) - 0.055;
}

void main() {
    vec2 at = TexCoords;
    if (hazeCount > 0 && captureChannel == 0) at += haze_offset(TexCoords);
    vec3 radiance = texture(screenTexture, at).rgb;
    if (captureChannel != 0) { FragColor = vec4(radiance, 1.0); return; }
    if (enableBloom) radiance += texture(bloomTexture, at).rgb * bloomIntensity;
    vec3 shown = aces(radiance * frameExposure);
    shown = vec3(srgb_encode(shown.r), srgb_encode(shown.g), srgb_encode(shown.b));
    // Half a step of an 8-bit target, in a pattern that does not repeat
    // across the screen, so a gradient in the dark is a grain and not bands.
    float noise = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    FragColor = vec4(shown + noise / 255.0, 1.0);
}
