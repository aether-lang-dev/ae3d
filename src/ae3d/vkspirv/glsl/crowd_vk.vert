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
layout(set = 0, binding = 1) uniform sampler2D textureSampler;
layout(set = 0, binding = 2) uniform sampler2D shadowMap;
layout(set = 0, binding = 3) uniform sampler2D normalMap;
layout(set = 0, binding = 4) uniform sampler2D poseBank;

#ifdef AE3D_PULL
// The cluster cut's draw of a crowd (ae3d.vkclusterlod), Vulkan alone: no
// vertex input. Each index is a figure's slot in its tier's stream above
// pullVertexBits bits of its mesh's vertex, and the vertex, its skin and
// the figure are read from the buffers at set 1 -- nine floats a vertex,
// three vec4s of skin, twenty floats a figure, as the vertex input reads
// them -- so one draw takes every figure at the detail its distance needs.
layout(std430, set = 1, binding = 0) readonly buffer PulledVertices { float pulledVertex[]; };
layout(std430, set = 1, binding = 1) readonly buffer PulledSkin { vec4 pulledSkin[]; };
layout(std430, set = 1, binding = 2) readonly buffer PulledFigures { float pulledFigure[]; };
vec3 inPosition;
vec2 inTexCoord;
vec3 inNormal;
mat4 instanceModel;
vec3 instanceColor;
vec4 inJoints;
vec4 inWeights;
float inOcclusion;
float instancePhase;
#else
layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inTexCoord;
layout(location = 2) in vec3 inNormal;
layout(location = 3) in mat4 instanceModel; // per-instance placement (3,4,5,6)
layout(location = 7) in vec3 instanceColor; // per-instance tint
layout(location = 8) in vec4 inJoints;      // the four bones a vertex hangs off
layout(location = 9) in vec4 inWeights;     // how much of each
layout(location = 10) in float inOcclusion;
layout(location = 11) in float instancePhase; // where in the walk this one is, 0..1
#endif






// The baked walk: bones*4 texels wide (four texels a bone matrix), `frames`
// rows tall. Sampled by exact texel, never filtered between poses.



// The crowd's far tier as impostors: the figure baked into an atlas of
// impostorCols views around it by impostorRows frames of its walk, and each
// instance an upright quad turned to the camera, impostorWidth by
// impostorHeight metres, showing the cell for the angle the camera sees it
// from and the frame its phase is at. Twenty thousand figures at a hundred
// and sixty-eight triangles are three million; as impostors they are forty
// thousand, and the horde can be twenty times the size.






// Last frame, for the motion vectors. A figure's previous slot in the
// stream is not its own -- the sort reorders every frame -- so where it
// was is worked out: it walked crowdTravel metres along its facing since
// last frame, and its walk was crowdPhaseStep earlier in the cycle.




layout(location = 0) out vec2 fragTexCoord;
layout(location = 1) out vec3 Normal;
layout(location = 2) out vec3 FragPos;
layout(location = 3) out vec3 InstanceColor;
layout(location = 4) out vec4 FragPosLightSpace;
layout(location = 5) out float Occlusion;
layout(location = 6) out vec4 ClipNow;
layout(location = 7) out vec4 ClipPrev;
layout(location = 8) out vec3 BindPos;
// A crowd's cut is the whole figure's: no joints of its own (#556).
layout(location = 9) out float ClipLimb;
layout(location = 10) out vec2 MaskUV;
layout(location = 11) out float ParticleAlpha;
layout(location = 12) out vec3 FlipNext;

// The bone's matrix at a frame, read as its four columns from the bank.
mat4 boneAt(int bone, int frame) {
    int x = bone * 4;
    return mat4(texelFetch(poseBank, ivec2(x + 0, frame), 0),
                texelFetch(poseBank, ivec2(x + 1, frame), 0),
                texelFetch(poseBank, ivec2(x + 2, frame), 0),
                texelFetch(poseBank, ivec2(x + 3, frame), 0));
}

// The vertex's four-bone skinning matrix at one baked frame.
mat4 skinAt(int frame) {
    return inWeights.x * boneAt(int(inJoints.x), frame)
         + inWeights.y * boneAt(int(inJoints.y), frame)
         + inWeights.z * boneAt(int(inJoints.z), frame)
         + inWeights.w * boneAt(int(inJoints.w), frame);
}

#ifdef AE3D_PULL
void pull() {
    uint bits = uint(pullVertexBits);
    uint v = uint(gl_VertexIndex) & ((1u << bits) - 1u);
    uint f = (uint(gl_VertexIndex) >> bits) * 20u;
    uint at = v * 9u;
    inPosition = vec3(pulledVertex[at], pulledVertex[at + 1u], pulledVertex[at + 2u]);
    inTexCoord = vec2(pulledVertex[at + 3u], pulledVertex[at + 4u]);
    inNormal = vec3(pulledVertex[at + 5u], pulledVertex[at + 6u], pulledVertex[at + 7u]);
    inOcclusion = pulledVertex[at + 8u];
    inJoints = pulledSkin[v * 3u];
    inWeights = pulledSkin[v * 3u + 1u];
    instanceModel = mat4(pulledFigure[f], pulledFigure[f + 1u], pulledFigure[f + 2u], pulledFigure[f + 3u],
                         pulledFigure[f + 4u], pulledFigure[f + 5u], pulledFigure[f + 6u], pulledFigure[f + 7u],
                         pulledFigure[f + 8u], pulledFigure[f + 9u], pulledFigure[f + 10u], pulledFigure[f + 11u],
                         pulledFigure[f + 12u], pulledFigure[f + 13u], pulledFigure[f + 14u], pulledFigure[f + 15u]);
    instanceColor = vec3(pulledFigure[f + 16u], pulledFigure[f + 17u], pulledFigure[f + 18u]);
    instancePhase = pulledFigure[f + 19u];
}
#endif

// The vertex's skinning matrix at a phase of the walk. The phase lands
// between two baked poses; blend them, so the walk is continuous instead
// of snapping frame to frame. The clip loops, so the frame after the last
// is the first.
mat4 skinAtPhase(float phase) {
    float fpos = fract(phase) * float(poseBankFrames);
    int frame0 = int(floor(fpos));
    float blend = fpos - float(frame0);
    if (frame0 < 0) { frame0 = 0; blend = 0.0; }
    if (frame0 >= poseBankFrames) { frame0 = poseBankFrames - 1; blend = 0.0; }
    int frame1 = frame0 + 1;
    if (frame1 >= poseBankFrames) { frame1 = 0; }
    return skinAt(frame0) * (1.0 - blend) + skinAt(frame1) * blend;
}

void main() {
#ifdef AE3D_PULL
    pull();
#endif
    BindPos = inPosition;
    ClipLimb = 1.0;
    MaskUV = inTexCoord;
    Occlusion = inOcclusion;
    ParticleAlpha = 1.0;
    FlipNext = vec3(0.0, 0.0, -1.0);
    mat4 modelMatrix = model * instanceModel;
    // The way the figure faces, which is the way it walks.
    vec3 walking = normalize(vec3(modelMatrix[0].x, 0.0, modelMatrix[0].z));

    if (impostor) {
        // Where the figure stands and which way it faces: the instance
        // matrix's origin and its local +X, on the ground plane -- the
        // crowd's yaw is measured from +X, and a figure walking that way is
        // at yaw zero, so the bake's first column is the figure seen from
        // its own +X.
        vec3 origin = vec3(modelMatrix[3]);
        vec3 facing = normalize(vec3(modelMatrix[0].x, 0.0, modelMatrix[0].z));
        vec3 toEye = viewPos - origin;
        vec3 level = normalize(vec3(toEye.x, 0.0, toEye.z));
        // The angle the camera sees the figure from, measured around its
        // facing: the cell column, with the bake's first view from the front.
        float angle = atan(dot(level, vec3(-facing.z, 0.0, facing.x)), dot(level, facing));
        float turn = fract(angle / 6.28318530718 + 1.0);
        int column = int(floor(turn * float(impostorCols) + 0.5)) % impostorCols;
        int row = int(floor(fract(instancePhase) * float(impostorRows))) % impostorRows;
        // An upright quad facing the eye: the mesh's x across it, y up it.
        vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), level));
        vec3 world = origin + right * (inPosition.x * impostorWidth) + vec3(0.0, inPosition.y * impostorHeight, 0.0);
        FragPos = world;
        // The picture's normals were baked in the figure's own frame; the
        // fragment turns them into the world by the facing, carried here.
        Normal = facing;
        // The cell in the atlas. The atlas is written with row 0 at its top
        // and loaded flipped, as every texture is, so a row counts down from
        // the top of texture space.
        fragTexCoord = vec2((float(column) + inTexCoord.x) / float(impostorCols),
                            1.0 - (float(row) + (1.0 - inTexCoord.y)) / float(impostorRows));
        InstanceColor = instanceColor;
        FragPosLightSpace = lightSpaceMatrix * vec4(world, 1.0);
        ClipNow = viewProjection * vec4(world, 1.0);
        ClipPrev = prevViewProjection * vec4(world - walking * crowdTravel, 1.0);
        gl_Position = ClipNow;
        return;
    }

    mat4 skin = skinAtPhase(instancePhase);
    vec4 posed = skin * vec4(inPosition, 1.0);
    vec3 posedNormal = mat3(skin) * inNormal;

    FragPos = vec3(modelMatrix * posed);
    Normal = normalize(mat3(modelMatrix) * posedNormal);
    fragTexCoord = inTexCoord;
    InstanceColor = instanceColor;
    FragPosLightSpace = lightSpaceMatrix * vec4(FragPos, 1.0);
    ClipNow = viewProjection * modelMatrix * posed;
    // Last frame: the same vertex a step back in the walk, the figure a
    // step back along its way.
    vec4 posedPrev = skinAtPhase(instancePhase - crowdPhaseStep) * vec4(inPosition, 1.0);
    vec4 worldPrev = modelMatrix * posedPrev;
    worldPrev.xyz -= walking * crowdTravel;
    ClipPrev = prevViewProjection * worldPrev;
    gl_Position = ClipNow;
}
