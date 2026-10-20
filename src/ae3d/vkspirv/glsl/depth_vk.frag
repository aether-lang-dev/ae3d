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

layout(location = 0) in vec3 BindPos;
layout(location = 1) in float ClipLimb;

// The model's cut (#545): a plane in its bind space -- the vertex before it
// was skinned, carried in BindPos -- past which nothing is drawn, wandering
// by up to clipNoise metres as value noise of clipNoiseScale cells a metre.
// The same words are in the scene's fragment shader and the depth one, so a
// cut's silhouette and its shadow agree to the texel.


// A severed limb's loose copy (#556): everything off the cut's joints is
// gone too, and the plane, turned round, keeps the limb past the joint.




float clipHash(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float clipValueNoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(clipHash(i + vec3(0.0, 0.0, 0.0)), clipHash(i + vec3(1.0, 0.0, 0.0)), f.x),
                   mix(clipHash(i + vec3(0.0, 1.0, 0.0)), clipHash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
               mix(mix(clipHash(i + vec3(0.0, 0.0, 1.0)), clipHash(i + vec3(1.0, 0.0, 1.0)), f.x),
                   mix(clipHash(i + vec3(0.0, 1.0, 1.0)), clipHash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

// Whether the fragment lies past the cut. Kept to joints, the plane cuts
// only what hangs off them (ClipLimb past a half): a cut through the
// shoulder takes the arm, not the leg below the same plane (#556).
bool clippedAway(vec3 bindPos) {
    if (!clipOn) return false;
    bool onLimb = ClipLimb >= 0.5;
    if (clipDetached && !onLimb) return true;
    if (!onLimb) return false;
    float side = dot(clipPlane.xyz, bindPos) - clipPlane.w;
    if (clipNoise > 0.0) side += clipNoise * (clipValueNoise(bindPos * clipNoiseScale) * 2.0 - 1.0);
    return side > 0.0;
}

// Wounds (#543) and splats (#546): up to 32 ellipsoids in the model's bind
// space, three vec4s each -- the centre and the kind (0 a wound, 1 a
// splat), the radii along its own axes and a splat's opacity, the rotation
// (a quaternion) from those axes into bind space -- and the layers a wound
// cuts down through, rgb and the share of its radius each starts at. Inside
// woundCore of a wound's radius the skin is a hole. A splat is blood on the
// skin, the outermost layer's colour, its edge ragged by the cut's noise. The same words are in
// the scene's fragment shader and the depth one, so a hole is a hole in
// the frame, its depth and its shadow alike.





// `v` turned by the inverse of the rotation `q`.
vec3 woundUnturn(vec4 q, vec3 v) {
    vec3 u = -q.xyz;
    vec3 t = 2.0 * cross(u, v);
    return v + q.w * t + cross(u, t);
}

// How deep in the nearest wound a bind-space point is: the wound's
// ellipsoid scaled to reach it, 1 at its surface and 0 at its centre;
// 2 where it is in no wound.
float woundDepth(vec3 p) {
    float best = 2.0;
    for (int i = 0; i < 32; i++) {
        if (i >= woundCount) break;
        if (woundData[i * 3].w > 0.5) continue;
        vec3 r = max(woundData[i * 3 + 1].xyz, vec3(0.0001));
        vec3 local = woundUnturn(woundData[i * 3 + 2], p - woundData[i * 3].xyz) / r;
        best = min(best, length(local));
    }
    return best;
}

// Nothing to write. The depth attachment takes gl_FragCoord.z on its own, and
// this used to put the same number into a colour buffer beside it: a second
// full-resolution write per shadow texel that nothing read. A cut model's far
// side is dropped, so it casts no shadow of what is not drawn.
void main() {
    if (clippedAway(BindPos)) discard;
    if (woundCount > 0 && woundDepth(BindPos) < woundCore) discard;
}
