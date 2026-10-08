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
    vec2 texelSize;
    float frameExposure;
    bool enableBloom;
    float bloomThreshold;
    float bloomIntensity;
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
layout(set = 0, binding = 2) uniform sampler2D depthTexture;
layout(set = 0, binding = 3) uniform sampler2D historyTexture;
layout(set = 0, binding = 4) uniform sampler2D velocityTexture;

layout(location = 0) in vec2 TexCoords;
layout(location = 0) out vec4 FragColor;









// The frame is radiance, and a lamp is hundreds of times its neighbours: held
// and blended as it is, one bright pixel decides every pixel it reaches and
// the edge it sits on flickers. So the history is kept, clamped and blended
// in a space that shows as the screen does -- each colour over one plus how
// bright it shows (Karis) -- and taken back out after.
vec3 fold(vec3 c) {
    return c / (1.0 + dot(c * frameExposure, vec3(0.2126, 0.7152, 0.0722)));
}
vec3 unfold(vec3 c) {
    return c / max(1.0 - dot(c * frameExposure, vec3(0.2126, 0.7152, 0.0722)), 1e-4);
}

void main() {
    vec2 uv = TexCoords;
    vec2 px = 1.0 / screenSize;
    vec3 current = texture(screenTexture, uv).rgb;
    if (taaBlend >= 0.999) { FragColor = vec4(current, 1.0); return; }

    // Where this pixel's surface was on the screen last frame: the scene
    // pass wrote its motion vector, the surface's own motion and the
    // camera's, with the frame's nudge already taken out -- so a surface
    // that has not moved under a camera that has not moved finds its
    // history at the pixel's own centre, read there without the filter's
    // blur, and the nudge is what the history folds up into the
    // antialiasing. A pixel nothing drew has a vector of zero.
    vec2 motion = texture(velocityTexture, uv).xy;
    vec2 prevUV = uv - motion;
    if (prevUV.x < 0.0 || prevUV.x > 1.0 || prevUV.y < 0.0 || prevUV.y > 1.0) {
        FragColor = vec4(current, 1.0);
        return;
    }
    vec3 history = fold(texture(historyTexture, prevUV).rgb);
    vec3 now = fold(current);

    // The neighbourhood's range this frame, and the history held to it.
    vec3 low = now;
    vec3 high = now;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec3 c = fold(texture(screenTexture, uv + vec2(float(x), float(y)) * px).rgb);
            low = min(low, c);
            high = max(high, c);
        }
    }
    history = clamp(history, low, high);
    // A history that had to be moved far -- a fast pan -- is trusted less.
    float travel = length((prevUV - uv) * screenSize);
    float blend = clamp(taaBlend + travel * 0.02, taaBlend, 1.0);
    FragColor = vec4(unfold(mix(history, now, blend)), 1.0);
}
