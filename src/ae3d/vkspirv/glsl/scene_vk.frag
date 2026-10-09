// Modern PBR-inspired Fragment Shader
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
layout(set = 0, binding = 1) uniform sampler2D textureSampler;
layout(set = 0, binding = 2) uniform sampler2D shadowMap;
layout(set = 0, binding = 3) uniform sampler2D normalMap;
layout(set = 0, binding = 4) uniform sampler2D sceneDepth;
layout(location = 0) in vec2 fragTexCoord;
layout(location = 1) in vec3 Normal;
layout(location = 2) in vec3 FragPos;
layout(location = 3) in vec3 InstanceColor;
layout(location = 4) in vec4 FragPosLightSpace;
layout(location = 6) in vec4 ClipNow;
layout(location = 7) in vec4 ClipPrev;
layout(location = 8) in vec3 BindPos;
layout(location = 9) in float ClipLimb;
layout(location = 10) in vec2 MaskUV;
layout(location = 11) in float ParticleAlpha;
layout(location = 12) in vec3 FlipNext;
layout(location = 1) out vec2 outVelocity;


// How much of the sky this point can see, baked against the whole scene.
// Ambient is light arriving from everywhere, so it is the term this belongs
// to: without it a corner is as bright as an open wall and every surface reads
// flat wherever direct light does not reach.
layout(location = 5) in float Occlusion;




// The lights that reach everywhere: the key light and any directional
// light. The scene's lamps -- its point and spot lights, however many --
// are not here but in the clusters below.




// The scene's point and spot lights, clustered (ae3d.lightgrid, #468): the
// view is cut into clusterDims.x columns by .y rows by .z depth slices, and
// each cell lists the lamps whose reach overlaps it, so a pixel shades with
// the lamps that reach it, whichever and however many they are, and a lamp
// lights its ground wherever the camera stands. A lamp is five vec4s
// (position and reach; colour and intensity; direction and kind; the three
// attenuation terms and the colour temperature; the spot's cone), and the
// words are each cell's first index and count, then the lists. The cell of a
// point is read by clusterViewProjection and viewDepth, the matrices
// the grid was cut with, so this lookup and the CPU's cannot disagree.



// The view's depth plane: a point's depth along the view is dot(.xyz, p) +
// .w. What the clusters and the shadow's cascades find a pixel by.

#ifdef VULKAN
layout(std430, set = 0, binding = 6) readonly buffer ClusterLightBlock { vec4 clusterLightData[]; };
layout(std430, set = 0, binding = 7) readonly buffer ClusterWordBlock { float clusterWordData[]; };
vec4 cluster_light(int i) { return clusterLightData[i]; }
float cluster_word(int i) { return clusterWordData[i]; }
#else
// OpenGL 4.1 has no storage buffers: the same floats, as textures a row of
// CLUSTER_LIGHT_ROW (RGBA) and CLUSTER_WORD_ROW (R) texels.


#define CLUSTER_LIGHT_ROW 1024
#define CLUSTER_WORD_ROW 4096
vec4 cluster_light(int i) { return texelFetch(clusterLights, ivec2(i % CLUSTER_LIGHT_ROW, i / CLUSTER_LIGHT_ROW), 0); }
float cluster_word(int i) { return texelFetch(clusterWords, ivec2(i % CLUSTER_WORD_ROW, i / CLUSTER_WORD_ROW), 0).r; }
#endif
// The last quarter of a lamp's reach fades its light to nothing, so a pool
// ends in a gradient (ae3d.lightgrid's FADE_START).
#define CLUSTER_FADE_START 0.75

int cluster_of(vec3 p) {
    vec4 clip = clusterViewProjection * vec4(p, 1.0);
    float w = clip.w != 0.0 ? clip.w : 1.0;
    vec2 ndc = clip.xy / w;
    float depth = dot(viewDepth.xyz, p) + viewDepth.w;
    ivec3 dims = ivec3(clusterDims.xyz + 0.5);
    int x = clamp(int(floor((ndc.x * 0.5 + 0.5) * float(dims.x))), 0, dims.x - 1);
    int y = clamp(int(floor((ndc.y * 0.5 + 0.5) * float(dims.y))), 0, dims.y - 1);
    int z = 0;
    if (depth > clusterDepth.x) {
        z = clamp(int(floor(log(depth) * clusterDepth.z + clusterDepth.w)), 0, dims.z - 1);
    }
    return (z * dims.y + y) * dims.x + x;
}

// Lamp `i` of the clusters, as the Light the shading takes, and its reach.
Light clustered_light(int i, out float reach, out int shadowSlot) {
    vec4 a = cluster_light(i * 5);
    vec4 b = cluster_light(i * 5 + 1);
    vec4 c = cluster_light(i * 5 + 2);
    vec4 d = cluster_light(i * 5 + 3);
    vec4 e = cluster_light(i * 5 + 4);
    Light L;
    L.position = a.xyz;
    reach = a.w;
    L.color = b.rgb;
    L.intensity = b.a;
    L.direction = c.xyz;
    L.isDirectional = int(c.w + 0.5);
    L.constantAtten = d.x;
    L.linearAtten = d.y;
    L.quadraticAtten = d.z;
    L.temperature = d.w;
    L.spotCosOuter = e.x;
    L.spotCosInner = e.y;
    // The lamp's own shadow's slot (ae3d.lampshadows), or -1: -1.0 read
    // back rounds toward zero, so it is rounded from below.
    shadowSlot = int(floor(e.z + 0.5));
    return L;
}
// The crowd's far tier as pictures (see VERTEX_CROWD): a picture is cut out
// by its alpha, and its colour is the figure's albedo and its normal map
// the figure's own normals, so it is lit below by the scene's lights the
// way the mesh beside it is.

// What a bake reads back instead of the lit picture: 1 the albedo -- the
// texture, the material and the tint, the surface's own colour before any
// light -- 2 the normal, world space, packed 0..1. Zero is the picture.
// tools/bake_impostor.ae draws its atlases through these.


// How far this camera can see. Everything that fades a feature out with distance
// measures against this rather than against a number of world units, so a scene
// laid out in metres and one laid out in centimetres behave alike.






// The clouds over the scene, for the shadow they throw: cover, drift time
// and the sun's direction, the same three the sky draws them with.




// The texture's alpha under which the surface is a hole (0: never), before
// anything else is decided -- an emissive particle is cut to its disc too
// (#711).


// The texture's tiling broken up (#737): 1 samples it as hexagons, each an
// offset copy turned by up to materialTileRotation of a half turn, blended
// where they meet; 0 as it repeats.


// The albedo varied over the world in patches of materialVariationScale
// metres, by up to materialVariation either way (0: none).


// The material's own textures again at materialDetailScale times their
// frequency, by materialDetailStrength, gone by materialDetailFade metres:
// the grain a texture magnified at the feet does not have (0: none).



// Fire (#738): the texture's red is the flame's heat (0 to 1), cooled over
// a particle's life by its colour's red, and the surface glows as a black
// body at that share of materialFire kelvin, bright as its fourth power.
// 0 for a surface that is not fire.

// The material's textures taken from the world position on three planes,
// a repeat every materialTriplanar metres, blended by the way the surface
// faces (#737): slopes and cliffs without the stretch of one projection.
// 0 for its UVs.

// A soft particle (#738): faded out where what the scene drew behind it is
// nearer than materialSoft metres, so a flame or a puff that meets the
// ground melts into it instead of cutting a line across it (0: hard).





// A stored scene depth as clip-space z: OpenGL keeps depth in 0..1 for a
// clip range of -1..1, Vulkan's clip range is the 0..1 it stores.
float scene_depth_clip(float depth) {
    return depth;
}

// How much of a soft particle's alpha this fragment keeps: the gap to what
// the scene drew behind it over its softness, 1 where it is clear of it.
float soft_fade() {
    if (materialSoft <= 0.0 || hasSceneDepth != 1) return 1.0;
    vec2 suv = gl_FragCoord.xy / screenSize;
    float d = texture(sceneDepth, suv).r;
    if (d >= 0.99999) return 1.0;
    vec4 clip = vec4(suv * 2.0 - 1.0, scene_depth_clip(d), 1.0);
    vec4 world = invViewProjection * clip;
    vec3 behind = world.xyz / world.w;
    float gap = distance(viewPos, behind) - distance(viewPos, FragPos);
    return clamp(gap / materialSoft, 0.0, 1.0);
}
// How the surface goes over what is behind it (#728): 0 opaque, 1 blended by
// its alpha, 2 added to it. Only a blended one carries its texture's and its
// point's alpha out.

// How mirror-like the surface is. Zero is an ordinary matte surface whose
// highlight fades as the view grazes it. Above zero the surface reflects the
// scene's lights the way a wet road does -- brightest exactly where the view
// grazes it, so a lamp overhead smears into a bright streak down the road
// toward the viewer. Per material, so only the wet surfaces reflect.

// How wet the scene is, 0..1: rain on it. A wet surface is darker, its
// pores filled, and a mirror at a grazing angle -- the lamps smear down a
// wet road the way they never do a dry one. Upward-facing surfaces take
// it in full, walls hardly at all: water runs off them. Set by the
// weather; a scene without one is dry.

// Modern PBR Extensions
// The surface's shape rather than its colour. The tangent frame is worked out
// per pixel from the derivatives of the position and the UVs, so no tangent has
// to be stored on a vertex and nothing about the vertex format changes -- the
// cost is a handful of instructions on surfaces that have a map and nothing at
// all on those that do not.


// How much of the baked occlusion to apply. Zero is the lighting this renderer
// had before it could do this, which is what makes the difference measurable
// rather than a matter of opinion.











// Advanced Lighting Models




// No light but the direct (the global illumination off, core.GI_OFF): no
// sky's light and no bounce, what a surface the lights miss shows as.


// Volumetric Lighting





// Distance haze. The same names the water shader uses, because one scene
// has one atmosphere: a street that fades into the dark has to fade the water
// running down it by the same amount. The fog is light in the scene, so it
// is a radiance: the colour the scene was given, as it shows at an exposure
// of one, taken back through the tone curve on the CPU (core.display_radiance).






// GPU Gems Chapter 9 & 11: Shadow Volume Support with Antialiasing




// The way the light travelled when the map was drawn. The map is orthographic
// whatever kind of light cast it, so for a point light this is not the
// direction from the surface to the lamp: the offset a surface needs depends on
// the angle it makes with the map, and using the wrong one of the two striped
// every wall the map happened to graze.

// The key light's shadow in cascades (ae3d.cascades, #469): the view cut in
// depth into cascadeCount slices, each with a map of its own in one atlas,
// two by two, cascade i in the tile (i % 2, i / 2). cascadeSplits is the
// view depth each cascade ends at, cascadeTexelWorld how much of the world
// one texel of its map covers -- what a surface's offset scales by -- and
// cascadeMatrices the matrices its map was drawn with. Each is fitted so a
// moving camera moves no shadow: a sphere around its slice, whose size the
// view's angle does not change, on its own texel grid.
#define MAX_CASCADES 4




// Shadows by ray: where the Vulkan device has ray queries and the renderer
// has built the scene's acceleration structure, a ray from the surface
// toward the sun says what stands in the way, exactly, at any distance,
// with no map's texel to fit the world into. The map stays for what the
// structure does not hold (the crowd, the skinned) and for OpenGL; the
// two are combined, the darker winning. The block below is compiled into
// the Vulkan ray-query variant of this shader alone.

// The sun's angular radius in radians, for the rays: zero is a point sun
// and a hard edge; the real sun's quarter degree gives a shadow that
// sharpens toward what casts it and softens away from it, as shadows do.

// Occlusion by ray, in the screen-space pass's place while the rays are
// on: how far in metres a thing shadows what stands beside it (zero is
// off) and how dark it goes.


// The size of a lamp's face, in metres, for the rays' lamp shadows: the
// larger, the softer the shadow it throws.

// How far from the camera a pixel is traced: the shadow distance, what the
// shadow map covers when the rays are off. Past it a pixel takes no shadow
// ray, no lamp ray and no occlusion ray -- a street of half a million
// figures is a quarter of a million alpha-tested quads out there, each
// pixel of each shaded under the rest, and tracing them cost more than the
// rest of the frame for shadows no camera resolves at that range (#401).
// Zero traces everything.

// The frame's number, for the rays' spirals: each frame turns every
// pixel's taps by the golden angle, so the temporal pass folds successive
// frames into a smooth penumbra. The projection's jitter was tried for
// this and is a fraction of a pixel, which turned the taps by nothing.



// GPU Gems Chapter 5: Improved Perlin Noise Support





// GPU Gems Chapter 2: light refracted by a water surface above the geometry









layout(location = 0) out vec4 FragColor;

// Convert color temperature (Kelvin) to RGB multiplier
// Optimized color temperature to RGB conversion using lookup approximation
// The light writes how far it can see into a colour target; this compares the
// fragment's own distance against it. Sampling a neighbourhood softens the edge.
float light_depth(float clipZ) {
    return clipZ;
}

// How lit a point is in cascade `c`: 1 lit, 0 shadowed, between at an
// edge. The sample is moved off the surface along its normal by a texel of
// this cascade and more the more the surface grazes the light -- sideways
// rather than deeper into the map, since a depth bias large enough to stop
// a grazing wall striping itself lifts every shadow off the ground with
// it -- and the 3x3 taps stay inside the cascade's tile, where a tap across
// its edge would read the next cascade's depths.
float cascade_lit(int c, vec3 surface, float slope) {
    vec4 lightSpace = cascadeMatrices[c] *
        vec4(FragPos + surface * cascadeTexelWorld[c] * (1.0 + slope), 1.0);
    vec3 projected = lightSpace.xyz / lightSpace.w;
    projected.xy = projected.xy * 0.5 + 0.5;
    projected.z = light_depth(projected.z);
    if (projected.z > 1.0) {
        return 1.0;
    }
    // Outside the cascade's map sideways is outside its box, where nothing
    // was drawn: lit, not the edge texel's depth compared against whatever
    // lies there.
    if (projected.x < 0.0 || projected.x > 1.0 || projected.y < 0.0 || projected.y > 1.0) {
        return 1.0;
    }

    vec2 texel = 1.0 / vec2(textureSize(shadowMap, 0));
    // At least one texel between taps. Below that the nine samples of the
    // 3x3 land on the same texel and cost nine lookups to produce what one
    // would, and the edge is as hard as no filtering at all.
    float radius = max(shadowSoftness, 1.0);
    vec2 tile = vec2(float(c % 2), float(c / 2)) * 0.5;
    vec2 centre = tile + projected.xy * 0.5;
    vec2 lo = tile + texel * (radius + 0.5);
    vec2 hi = tile + vec2(0.5) - texel * (radius + 0.5);

    // The depth a texel of the cascade spans is the same fraction of its
    // box however large the box: a bias in texels of the cascade's own map
    // (half the atlas a side) fits every cascade alike. The offset above
    // has already taken the slope out of it.
    float bias = radius / (float(textureSize(shadowMap, 0).x) * 0.5);

    float lit = 0.0;
    for (int sx = -1; sx <= 1; sx++) {
        for (int sy = -1; sy <= 1; sy++) {
            vec2 at = clamp(centre + vec2(float(sx), float(sy)) * texel * radius, lo, hi);
            float closest = texture(shadowMap, at).r;
            lit += projected.z - bias > closest ? 0.0 : 1.0;
        }
    }
    return lit / 9.0;
}

float shadow_factor() {
    vec3 surface = normalize(Normal);
    vec3 toLight = normalize(-shadowDirection);

    // How much depth one texel spans is the tangent of the angle between the
    // surface and the map, which runs away at grazing incidence: a wall lit
    // along its length spans many texels of depth and a floor lit from
    // overhead spans almost none. Bounded, because the tangent is not.
    float facing = max(dot(surface, toLight), 0.0);
    float slope = min(sqrt(1.0 - facing * facing) / max(facing, 0.02), 32.0);

    // The pixel's cascade by its depth along the view; past the last one,
    // the shadow's range, it is lit.
    float depth = dot(viewDepth.xyz, FragPos) + viewDepth.w;
    int c = -1;
    for (int i = 0; i < MAX_CASCADES; i++) {
        if (i < cascadeCount && depth <= cascadeSplits[i]) {
            c = i;
            break;
        }
    }
    if (c < 0) {
        return 1.0;
    }
    float lit = cascade_lit(c, surface, slope);
    // Over the last tenth of a cascade the next one blends in, so where the
    // shadow's texels change size there is a gradient and no seam.
    if (c + 1 < cascadeCount) {
        float start = c == 0 ? 0.0 : cascadeSplits[c - 1];
        float band = (cascadeSplits[c] - start) * 0.1;
        float into = (cascadeSplits[c] - depth) / max(band, 0.0001);
        if (into < 1.0) {
            lit = mix(cascade_lit(c + 1, surface, slope), lit, into);
        }
    }
    return mix(shadowIntensity, 1.0, lit);
}

// The lamps' own shadows (ae3d.lampshadows, #490). A lamp is shadowed by its
// own map and by no other light's: a lamp given a slot has the six faces of
// a cube drawn around it, 90-degree views LAMP_FACE texels square, in one
// atlas LAMP_ACROSS tiles a side, slot s's face f the tile s * 6 + f. The
// slots follow the lamps in the lights' data from lampShadowBase on,
// LAMP_SLOT_VEC4S vec4s each: position and far plane; strength and near
// plane; the six faces' matrices. keyLampSlot is the key light's slot when
// the key light is a lamp -- its cascades are for the sun and the moon --
// and -1 otherwise, as lampShadowBase is where no lamp has a map.
#define LAMP_ACROSS 8
#define LAMP_FACE 512.0
#define LAMP_SLOT_VEC4S 26


#ifdef VULKAN
layout(set = 0, binding = 8) uniform sampler2D lampShadowMap;
#else

#endif

// A depth a lamp's face stores, 0 at its near plane and 1 at its far one,
// as the distance along the face's axis it stands for.
float lamp_distance(float depth, float near, float far) {
    return near * far / (far - depth * (far - near));
}

// How much of lamp slot `slot`'s light reaches this point past what stands
// in its way: 1 lit, the shadow's share of the light behind a caster, and
// the lamp's strength -- its shadow fading out where the budget of lamps
// runs out -- between. The face is the one the point lies in from the lamp.
// As with the cascades, the sample moves off the surface along its normal
// by a texel of the face at that distance, and more on a surface the lamp
// grazes; the depths are compared in metres from the lamp, since a
// perspective map's depth crowds toward its far plane.
float lamp_shadow(int slot, vec3 surface) {
    int base = lampShadowBase + slot * LAMP_SLOT_VEC4S;
    vec4 head = cluster_light(base);
    vec4 more = cluster_light(base + 1);
    vec3 v = FragPos - head.xyz;
    float far = head.w;
    float strength = more.x;
    float near = more.y;
    vec3 a = abs(v);
    int face;
    float along;
    if (a.x >= a.y && a.x >= a.z) {
        face = v.x > 0.0 ? 0 : 1;
        along = a.x;
    } else if (a.y >= a.z) {
        face = v.y > 0.0 ? 2 : 3;
        along = a.y;
    } else {
        face = v.z > 0.0 ? 4 : 5;
        along = a.z;
    }
    if (strength <= 0.0 || along >= far || along <= near) {
        return 1.0;
    }
    vec3 toLamp = -v / max(length(v), 0.0001);
    float facing = max(dot(surface, toLamp), 0.0);
    float slope = min(sqrt(1.0 - facing * facing) / max(facing, 0.02), 32.0);
    float texelWorld = 2.0 * along / LAMP_FACE;
    int m = base + 2 + face * 4;
    mat4 faceMatrix = mat4(cluster_light(m), cluster_light(m + 1), cluster_light(m + 2), cluster_light(m + 3));
    vec4 lightSpace = faceMatrix * vec4(FragPos + surface * texelWorld * (1.0 + slope), 1.0);
    vec3 projected = lightSpace.xyz / lightSpace.w;
    // A sample moved off the surface near a face's edge can leave the face;
    // it is read at the edge of the one the point lies in.
    projected.xy = clamp(projected.xy * 0.5 + 0.5, 0.0, 1.0);
    float mine = lamp_distance(light_depth(projected.z), near, far);

    int tile = slot * 6 + face;
    float share = 1.0 / float(LAMP_ACROSS);
    vec2 origin = vec2(float(tile % LAMP_ACROSS), float(tile / LAMP_ACROSS)) * share;
    vec2 texel = 1.0 / vec2(textureSize(lampShadowMap, 0));
    float radius = max(shadowSoftness, 1.0);
    vec2 centre = origin + projected.xy * share;
    vec2 lo = origin + texel * (radius + 0.5);
    vec2 hi = origin + vec2(share) - texel * (radius + 0.5);
    float bias = texelWorld * 1.5;
    float lit = 0.0;
    for (int sx = -1; sx <= 1; sx++) {
        for (int sy = -1; sy <= 1; sy++) {
            vec2 at = clamp(centre + vec2(float(sx), float(sy)) * texel * radius, lo, hi);
            float closest = lamp_distance(texture(lampShadowMap, at).r, near, far);
            lit += mine - bias > closest ? 0.0 : 1.0;
        }
    }
    return mix(1.0, mix(shadowIntensity, 1.0, lit / 9.0), strength);
}

#ifdef AE3D_RAY_QUERY
// One ray toward the sun from just off the surface: lit, or the shadow's
// share of the light. The origin steps out along the normal by a little
// more than the surface's own tessellation error, so a face does not
// shadow itself, and the ray is opaque-only and stops at its first hit. It
// meets what casts a shadow (mask bit 1: ae3d.vkrays' RAY_SHADOW), not what
// only the probes see.
bool ray_blocked_to(vec3 origin, vec3 direction, float far) {
    rayQueryEXT query;
    rayQueryInitializeEXT(query, sceneAS,
                          gl_RayFlagsTerminateOnFirstHitEXT | gl_RayFlagsOpaqueEXT,
                          0x01, origin, 0.01, direction, far);
    rayQueryProceedEXT(query);
    return rayQueryGetIntersectionTypeEXT(query, true) != gl_RayQueryCommittedIntersectionNoneEXT;
}

bool ray_blocked(vec3 origin, vec3 direction) {
    return ray_blocked_to(origin, direction, 500.0);
}

// A sun with a size: four rays into the cone the sun's disc subtends, on
// a spiral turned by a per-pixel noise and by the frame's jitter, so the
// temporal pass folds successive frames' taps into a smooth penumbra and
// a still frame reads as a fine grain rather than a band. What stands
// close to its shadow blocks every tap; what stands far blocks some.
#define SUN_TAPS 4
float ray_shadow_factor() {
    vec3 surface = normalize(Normal);
    vec3 toLight = normalize(-shadowDirection);
    if (dot(surface, toLight) <= 0.0) return shadowIntensity;
    vec3 origin = FragPos + surface * 0.02;
    if (sunAngle <= 0.0) {
        return ray_blocked(origin, toLight) ? shadowIntensity : 1.0;
    }
    vec3 side = normalize(cross(toLight, abs(toLight.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
    vec3 up = cross(side, toLight);
    float spread = tan(sunAngle);
    float grain = fract(52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y));
    float turn = 6.2831853 * fract(grain + float(rayFrame) * 0.6180339887);
    float blocked = 0.0;
    for (int i = 0; i < SUN_TAPS; i++) {
        float radius = spread * sqrt((float(i) + 0.5) / float(SUN_TAPS));
        float angle = float(i) * 2.3999632 + turn;
        vec3 direction = normalize(toLight + side * (radius * cos(angle)) + up * (radius * sin(angle)));
        if (ray_blocked(origin, direction)) blocked += 1.0;
    }
    return mix(1.0, shadowIntensity, blocked / float(SUN_TAPS));
}

// Ambient occlusion by ray: four rays into the hemisphere over the
// surface, cosine-weighted (a ray near the normal counts for the sky it
// stands for), on a spiral turned by a per-pixel noise and the frame's
// jitter as the sun's taps are, each stopped at the occlusion's reach.
// The share that hit is how much of the sky the point does not see: the
// same number the screen-space pass estimates from the depth, from the
// scene itself, with no screen edge or hidden surface to miss.
#define AO_TAPS 4
float ray_occlusion_factor() {
    vec3 surface = normalize(Normal);
    vec3 origin = FragPos + surface * 0.02;
    vec3 side = normalize(cross(surface, abs(surface.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
    vec3 up = cross(side, surface);
    float grain = fract(52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y) + 0.37);
    float turn = 6.2831853 * fract(grain + float(rayFrame) * 0.6180339887);
    float blocked = 0.0;
    for (int i = 0; i < AO_TAPS; i++) {
        float u = (float(i) + 0.5) / float(AO_TAPS);
        float sinTheta = sqrt(u);
        float cosTheta = sqrt(1.0 - u);
        float angle = float(i) * 2.3999632 + turn;
        vec3 direction = side * (cos(angle) * sinTheta) + up * (sin(angle) * sinTheta) + surface * cosTheta;
        // From a hand's breadth out: a figure is drawn from its near mesh
        // and traced against its far one, a few centimetres apart, so a
        // ray that started at the skin found the proxy and dotted every
        // figure with its own shadow.
        rayQueryEXT query;
        rayQueryInitializeEXT(query, sceneAS,
                              gl_RayFlagsTerminateOnFirstHitEXT | gl_RayFlagsOpaqueEXT,
                              0x01, origin, 0.12, direction, rayOcclusion);
        rayQueryProceedEXT(query);
        if (rayQueryGetIntersectionTypeEXT(query, true) != gl_RayQueryCommittedIntersectionNoneEXT) blocked += 1.0;
    }
    return clamp(1.0 - rayOcclusionStrength * blocked / float(AO_TAPS), 0.0, 1.0);
}

// A lamp's shadow: one ray from the surface to the lamp, stopped short of
// it, on a spot of the lamp's face picked by the pixel's noise and the
// frame's jitter -- a lamp has a size, and the temporal pass folds the
// frames into its penumbra. A lamp has no shadow map, so on the map path
// the key light's shadow stands in for every lamp's; by ray each lamp
// throws its own: the figure under the street lamp is the one thing on a
// night street the eye asks for, and it was missing.
float ray_lamp_factor(vec3 lamp, float radius) {
    vec3 surface = normalize(Normal);
    vec3 toLamp = lamp - FragPos;
    float span = length(toLamp);
    if (span < 0.05) return 1.0;
    toLamp /= span;
    if (dot(surface, toLamp) <= 0.0) return 1.0;
    vec3 side = normalize(cross(toLamp, abs(toLamp.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
    vec3 up = cross(side, toLamp);
    float grain = fract(52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y) + 0.71);
    float seed = fract(grain + float(rayFrame) * 0.6180339887);
    float turn = 6.2831853 * seed;
    float reach = radius * sqrt(fract(seed * 7.0));
    vec3 spot = lamp + side * (reach * cos(turn)) + up * (reach * sin(turn));
    vec3 direction = spot - FragPos;
    float far = length(direction);
    direction /= far;
    vec3 origin = FragPos + surface * 0.02;
    // Stopped well short of the lamp: the fitting the light hangs from --
    // its head, its arm -- stands right over it, and a ray run to the
    // light itself found the head and shadowed half the street's walls
    // with a grain.
    return ray_blocked_to(origin, direction, max(far - 0.6, 0.05)) ? shadowIntensity : 1.0;
}
#endif

vec3 kelvinToRGB(float kelvin) {
    kelvin = clamp(kelvin, 1000.0, 12000.0);
    
    // Fast approximation for common temperatures (avoids expensive pow/log)
    if (kelvin < 3000.0) {
        return mix(vec3(1.0, 0.4, 0.0), vec3(1.0, 0.7, 0.3), (kelvin - 1000.0) / 2000.0);
    } else if (kelvin < 6500.0) {
        return mix(vec3(1.0, 0.7, 0.3), vec3(1.0, 1.0, 1.0), (kelvin - 3000.0) / 3500.0);
    } else {
        return mix(vec3(1.0, 1.0, 1.0), vec3(0.7, 0.8, 1.0), (kelvin - 6500.0) / 5500.0);
    }
}

// The colour a black body glows at `kelvin`, linear, its brightest channel
// one: Helland's fit to the Planckian locus, red alone under about 1900 K
// (an ember), yellow-white toward 3000 K (a flame's core).
vec3 black_body(float kelvin) {
    float t = max(kelvin, 500.0) / 100.0;
    float g = t <= 6.6 ? 0.0 : clamp((99.4708025861 * log(t) - 161.1195681661) / 255.0, 0.0, 1.0);
    float b = t <= 19.0 ? 0.0 : clamp((138.5177312231 * log(t - 10.0) - 305.0447927307) / 255.0, 0.0, 1.0);
    return pow(vec3(1.0, g, b), vec3(2.2));
}

// Optimized Schlick's approximation for Fresnel reflectance
vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    float invCosTheta = clamp(1.0 - cosTheta, 0.0, 1.0);
    float invCosTheta2 = invCosTheta * invCosTheta;
    float invCosTheta5 = invCosTheta2 * invCosTheta2 * invCosTheta; // Faster than pow(x, 5.0)
    return F0 + (1.0 - F0) * invCosTheta5;
}

// Improved specular distribution (Blinn-Phong to GGX-like)
float distributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    
    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = 3.14159265359 * denom * denom;
    
    // Clamp the result to prevent extreme highlights
    float result = num / denom;
    return min(result, 10.0); // Prevent excessive specular concentration
}

// Geometry function for self-shadowing
float geometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    
    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    
    return num / denom;
}

float geometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = geometrySchlickGGX(NdotV, roughness);
    float ggx1 = geometrySchlickGGX(NdotL, roughness);
    
    return ggx1 * ggx2;
}

// Modern PBR Extensions

// Clearcoat BRDF (automotive paint, lacquered surfaces)
vec3 calculateClearcoat(vec3 N, vec3 V, vec3 L, vec3 H, vec3 baseColor) {
    if (!enableClearcoat) return vec3(0.0);
    
    float clearcoatNDF = distributionGGX(N, H, clearcoatRoughness);
    float clearcoatG = geometrySmith(N, V, L, clearcoatRoughness);
    vec3 clearcoatF = fresnelSchlick(max(dot(H, V), 0.0), vec3(0.04)); // Clear coat F0
    
    vec3 clearcoatSpecular = (clearcoatNDF * clearcoatG * clearcoatF) / 
                            (4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.001);
    
    return clearcoatSpecular * clearcoatIntensity;
}

// Sheen BRDF (fabric, velvet materials)
vec3 calculateSheen(vec3 N, vec3 V, vec3 L, vec3 H) {
    if (!enableSheen) return vec3(0.0);
    
    float sheenNdotH = max(dot(N, H), 0.0);
    float sheenD = (2.0 + sheenRoughness) * pow(sheenNdotH, sheenRoughness) / (2.0 * 3.14159265359);
    
    return sheenColor * sheenD * 0.25; // Sheen is typically subtle
}

// Transmission BRDF (glass, translucent materials)
vec3 calculateTransmission(vec3 N, vec3 V, vec3 L, vec3 baseColor) {
    if (!enableTransmission) return vec3(0.0);
    
    // Proper glass transmission with refraction
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    
    // Fresnel for transmission (inverted)
    float F0 = 0.04; // Glass F0
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0);
    float transmission = (1.0 - fresnel) * transmissionFactor;
    
    // Light coming through the material
    vec3 transmittedLight = baseColor * transmission * NdotL;
    
    // Add some scattering for realistic glass
    vec3 scattering = baseColor * transmission * 0.1;
    
    return transmittedLight + scattering;
}

// Multiple Scattering Energy Compensation
vec3 compensateEnergyLoss(vec3 color, float NdotV, float roughness) {
    if (!enableMultipleScattering) return color;
    
    // Approximate multiple scattering compensation
    float compensation = 1.0 + roughness * (1.0 - NdotV) * 0.2;
    return color * compensation;
}

// Energy Conservation for layered materials
vec3 applyEnergyConservation(vec3 diffuse, vec3 specular, vec3 clearcoat, vec3 sheen) {
    if (!enableEnergyConservation) return diffuse + specular + clearcoat + sheen;
    
    // Ensure total energy doesn't exceed 1.0
    vec3 totalEnergy = diffuse + specular + clearcoat + sheen;
    float maxEnergy = max(max(totalEnergy.r, totalEnergy.g), totalEnergy.b);
    
    if (maxEnergy > 1.0) {
        return totalEnergy / maxEnergy;
    }
    
    return totalEnergy;
}

// Volumetric Lighting (light shafts, fog) with distance-based optimization
vec3 calculateVolumetricLighting(vec3 worldPos, vec3 lightPos, vec3 viewPos) {
    if (!enableVolumetricLighting) return vec3(0.0);

    // Light scattered by the air between the eye and the surface -- the haze
    // that stands around a lamp on a wet night, and the whole of what makes a
    // night read as atmosphere rather than as lit objects in the dark. The view
    // ray is marched from the eye to the surface and, at each step, the lamp's
    // light that would scatter back toward the eye is added, so the glow
    // gathers where the ray passes close to the lamp and thins away from it.
    vec3 toSurface = worldPos - viewPos;
    float rayLength = length(toSurface);
    if (rayLength < 0.001) return vec3(0.0);
    vec3 rayDir = toSurface / rayLength;

    int steps = clamp(volumetricSteps, 8, 32);

    // The lamp's own colour and warmth: the haze is its light, not a grey fog.
    vec3 tint = lights[0].color * kelvinToRGB(lights[0].temperature);

    float scatter = 0.0;
    float stepSize = rayLength / float(steps);
    for (int i = 0; i < steps && i < 32; i++) {
        vec3 samplePos = viewPos + rayDir * (stepSize * (float(i) + 0.5));
        float d = length(lightPos - samplePos);
        // Concentrated near the lamp -- a metre off it is bright, ten metres a
        // faint wash -- which gathers the glow into a halo rather than lifting
        // the whole frame. scattering is that falloff, in inverse metres.
        scatter += stepSize / (1.0 + d * d * volumetricScattering);
    }
    return tint * scatter * volumetricIntensity;
}

// Simple inter-object reflections approximation
vec3 calculateInterObjectReflections(vec3 worldPos, vec3 N, vec3 V, float roughness, float metallic) {
    // Only apply to metallic surfaces with low roughness
    if (roughness > 0.5 || metallic < 0.5) return vec3(0.0);
    
    vec3 R = reflect(-V, N);
    vec3 reflectionColor = vec3(0.0);
    
    // Simple approximation: sample environment based on reflection direction
    // This creates subtle inter-object reflections without artifacts
    float reflectionStrength = (1.0 - roughness) * metallic * 0.15; // Very subtle
    
    // Use reflection direction to approximate nearby object colors
    // This is a simplified approach - in reality you'd need screen-space reflections
    vec3 envSample = vec3(0.4, 0.5, 0.6); // Neutral reflection color
    
    // Add some variation based on world position to simulate different objects
    float variation = sin(worldPos.x * 0.1) * sin(worldPos.z * 0.1) * 0.2;
    envSample += vec3(variation, variation * 0.5, variation * 0.3);
    
    reflectionColor = envSample * reflectionStrength;
    
    return reflectionColor;
}

// GPU Gems Chapter 5: Improved Perlin Noise Implementation
// Simplified GLSL version of the improved Perlin noise with quintic interpolation

// Permutation table values (simplified for GLSL)
const int PERM[256] = int[256](
    151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,
    8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,
    35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,
    134,139,48,27,166,77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,
    55,46,245,40,244,102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,
    18,169,200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,
    250,124,123,5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,
    189,28,42,223,183,170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,
    172,9,129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,
    228,251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,
    107,49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,150,254,
    138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
);

// Optimized hash function for GLSL (50% faster, no lookup table)
int hash(int x, int y, int z) {
    int n = x + y * 57 + z * 113;
    n = (n << 13) ^ n;
    return abs((n * (n * n * 15731 + 789221) + 1376312589)) & 255;
}

// Quintic interpolation (6t^5 - 15t^4 + 10t^3)
float fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Linear interpolation
float lerp(float t, float a, float b) {
    return a + t * (b - a);
}

// Gradient vectors (simplified set from GPU Gems)
vec3 getGradient(int hash) {
    int h = hash & 15;
    float u = h < 8 ? 1.0 : -1.0;
    float v = (h & 1) == 0 ? 1.0 : -1.0;
    float w = (h & 2) == 0 ? 1.0 : -1.0;
    
    if (h < 4) return vec3(u, v, 0.0);
    else if (h < 8) return vec3(u, 0.0, w);
    else if (h < 12) return vec3(0.0, v, w);
    else return vec3(u, v, w);
}

// Clouds, shared by the sky that draws them and the ground they shadow.
// A layer between CLOUD_BASE and CLOUD_TOP metres up. Where cloud is, over
// the world, is the weather field: a fractal of tileable 2D value noise
// gathered into banks by a slower one, a tile of CLOUD_TILE metres that
// repeats without a seam. The sky reads it from the weather texture the
// engine bakes from this very function (ae3d.cloudnoise); the
// ground computes it here for its cloud shadow, so the shadow under a
// cloud is the cloud. Both use the one hash, in integers, exact on both
// backends.
const float CLOUD_BASE = 1400.0;
const float CLOUD_TOP = 2600.0;
const float CLOUD_TILE = 24000.0;

float cloudHash(vec3 p) {
    uvec3 v = uvec3(ivec3(floor(p))) * uvec3(1597334677u, 3812015801u, 2798796415u);
    uint n = (v.x ^ v.y ^ v.z) * 1597334677u;
    n ^= n >> 16u;
    n *= 0x7feb352du;
    n ^= n >> 15u;
    n *= 0x846ca68bu;
    n ^= n >> 16u;
    return float(n) * (1.0 / 4294967296.0);
}

// Value noise on a 2D lattice of `period` cells to the tile, wrapped so it
// tiles; the field's seed rides in z, as the baker's does.
float cloudNoise2(vec2 x, float period, float seed) {
    vec2 i = floor(x);
    vec2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    vec2 i0 = mod(i, period);
    vec2 i1 = mod(i + 1.0, period);
    float a = cloudHash(vec3(i0.x, i0.y, seed));
    float b = cloudHash(vec3(i1.x, i0.y, seed));
    float c = cloudHash(vec3(i0.x, i1.y, seed));
    float d = cloudHash(vec3(i1.x, i1.y, seed));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// The weather over a point of the tile, uv in 0..1: x is the cloud field
// before the cover threshold, stretched over 0..1, y is the banks.
vec2 cloudWeatherAt(vec2 uv) {
    float shape = 0.0;
    float amp = 0.5;
    float freq = 6.0;
    for (int o = 0; o < 5; o++) {
        shape += amp * cloudNoise2(uv * freq, freq, float(41 + o * 17));
        amp *= 0.5;
        freq *= 2.0;
    }
    shape = clamp((shape - 0.3) / 0.4, 0.0, 1.0);
    float bank = cloudNoise2(uv * 3.0, 3.0, 8.0);
    return vec2(shape, bank);
}

// Where on the weather tile a point of the world is, with the wind's drift.
vec2 cloudWeatherUv(vec2 xz, float t) {
    return xz / CLOUD_TILE + vec2(t * 0.00012, t * 0.00004);
}

// The cover threshold over the field and the banks: 0.3 is a few
// fair-weather clouds, 0.8 an overcast with holes.
float cloudCoverageFrom(vec2 weather, float cover) {
    float threshold = 1.0 - cover * (0.45 + 1.1 * weather.y);
    // A soft ramp that stops short of one: at full coverage the cloud
    // still has its cells, and does not flatten into a sheet.
    return smoothstep(threshold, threshold + 0.5, weather.x) * 0.9;
}

// How much cloud there is over a point of the ground, 0..1, computed.
float cloudCoverage(vec2 xz, float cover, float t) {
    return cloudCoverageFrom(cloudWeatherAt(cloudWeatherUv(xz, t)), cover);
}

// The clouds' shadow at a point: the coverage over it, looked up where the
// sun's ray through it meets the cloud layer, so the shadow drifts with
// the clouds and leans with the sun. One minus most of the coverage: the
// sky still lights the ground under a cloud.
float cloudShadow(vec3 worldPos) {
    if (cloudCover <= 0.0 || cloudSun.y <= 0.05) return 1.0;
    vec3 sun = normalize(cloudSun);
    float up = (CLOUD_BASE + (CLOUD_TOP - CLOUD_BASE) * 0.35 - worldPos.y) / max(sun.y, 0.05);
    vec2 at = worldPos.xz + sun.xz * up;
    return 1.0 - 0.65 * cloudCoverage(at, cloudCover, cloudTime);
}

// Simplified 3D Perlin noise for GLSL
float perlinNoise3D(vec3 p) {
    // Find unit cube containing point
    ivec3 i = ivec3(floor(p));
    vec3 f = p - vec3(i);
    
    // Compute fade curves
    vec3 u = vec3(fade(f.x), fade(f.y), fade(f.z));
    
    // Get gradients at cube corners
    int n000 = hash(i.x, i.y, i.z);
    int n001 = hash(i.x, i.y, i.z + 1);
    int n010 = hash(i.x, i.y + 1, i.z);
    int n011 = hash(i.x, i.y + 1, i.z + 1);
    int n100 = hash(i.x + 1, i.y, i.z);
    int n101 = hash(i.x + 1, i.y, i.z + 1);
    int n110 = hash(i.x + 1, i.y + 1, i.z);
    int n111 = hash(i.x + 1, i.y + 1, i.z + 1);
    
    // Compute dot products
    float d000 = dot(getGradient(n000), f);
    float d001 = dot(getGradient(n001), f - vec3(0, 0, 1));
    float d010 = dot(getGradient(n010), f - vec3(0, 1, 0));
    float d011 = dot(getGradient(n011), f - vec3(0, 1, 1));
    float d100 = dot(getGradient(n100), f - vec3(1, 0, 0));
    float d101 = dot(getGradient(n101), f - vec3(1, 0, 1));
    float d110 = dot(getGradient(n110), f - vec3(1, 1, 0));
    float d111 = dot(getGradient(n111), f - vec3(1, 1, 1));
    
    // Interpolate
    return lerp(u.z,
        lerp(u.y,
            lerp(u.x, d000, d100),
            lerp(u.x, d010, d110)),
        lerp(u.y,
            lerp(u.x, d001, d101),
            lerp(u.x, d011, d111)));
}

// Multi-octave noise (turbulence)
float turbulence(vec3 p, int octaves) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxValue = 0.0;
    
    for (int i = 0; i < octaves && i < 8; i++) {
        value += perlinNoise3D(p * frequency) * amplitude;
        maxValue += amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value / maxValue;
}

// GPU Gems Chapter 2: the bright web a water surface casts on what lies under
// it. Two noise fields drift apart and the pattern is where they cross, which
// is what gives caustics their thin moving lines rather than smooth blobs.
// One web of the caustic pattern: where two drifting noise fields cross,
// a thin bright line, which is what the focused light off a wave crest
// draws on the floor.
float caustic_web(vec2 uv, float t) {
    vec2 drift = vec2(0.7, 0.3) * causticsSpeed * t;
    float a = perlinNoise3D(vec3(uv + drift, t * causticsSpeed * 0.5));
    float b = perlinNoise3D(vec3(uv * 1.7 - drift * 0.8, t * causticsSpeed * 0.4 + 5.3));
    return pow(clamp(1.0 - abs(a - b) * 3.0, 0.0, 1.0), 8.0);
}

vec3 caustic_light(vec3 worldPos, vec3 norm) {
    if (!enableCaustics) {
        return vec3(0.0);
    }

    float depth = causticsWaterLevel - worldPos.y;
    if (depth <= 0.0) {
        return vec3(0.0);
    }

    // Two webs, the finer one half as bright, so the pattern is a network
    // with nodes where they cross and not one set of parallel worms; and
    // each colour a hair to one side, the fringe light through water has.
    vec2 uv = worldPos.xz * causticsScale;
    float t = causticsTime;
    vec2 fringe = vec2(0.006, 0.004);
    vec3 web;
    web.r = caustic_web(uv + fringe, t) + 0.5 * caustic_web(uv * 2.3 + fringe * 2.0 + 11.0, t);
    web.g = caustic_web(uv, t) + 0.5 * caustic_web(uv * 2.3 + 11.0, t);
    web.b = caustic_web(uv - fringe, t) + 0.5 * caustic_web(uv * 2.3 - fringe * 2.0 + 11.0, t);

    // The light falls from the surface straight down, so a floor catches the
    // whole pattern, a wall catches a grazing fraction of it, and depth of
    // water swallows what is left. How fast it is swallowed is the caller's to
    // say: a scene measured in metres and one measured in centimetres cannot
    // share a fixed rate.
    float facing = clamp(norm.y, 0.0, 1.0);
    float attenuation = exp(-depth / max(causticsDepth, 0.001));

    vec3 keyColor = lights[0].color * kelvinToRGB(lights[0].temperature);
    return keyColor * lights[0].intensity * web * facing * attenuation * causticsIntensity;
}

// The tangent frame of a surface, worked out from how the position and the UVs
// change across the screen.
//
// The usual way is a tangent stored on every vertex, which means a wider vertex
// for every mesh in the scene whether or not it has a map. This costs a few
// instructions on the surfaces that do have one and nothing on the rest, and
// gets the same frame -- the derivatives of a position against the derivatives
// of its UVs are what a tangent is.
mat3 cotangent_frame(vec3 normal, vec3 position, vec2 uv) {
    vec3 dpx = dFdx(position);
    vec3 dpy = dFdy(position);
    vec2 duvx = dFdx(uv);
    vec2 duvy = dFdy(uv);

    vec3 perp_y = cross(dpy, normal);
    vec3 perp_x = cross(normal, dpx);
    vec3 tangent = perp_y * duvx.x + perp_x * duvy.x;
    vec3 bitangent = perp_y * duvx.y + perp_x * duvy.y;

    // The solve's determinant is dropped for the normalisation, but not its
    // sign: which way the screen's y runs is in it. OpenGL's runs up and
    // Vulkan's down, and without the sign the same surface got its map's
    // tangent and bitangent reversed on Vulkan -- every bump a dent, every
    // ripple on the wet road turned the other way (#494).
    float handed = dot(dpx, perp_y) < 0.0 ? -1.0 : 1.0;
    float scale = handed * inversesqrt(max(dot(tangent, tangent), dot(bitangent, bitangent)));
    return mat3(tangent * scale, bitangent * scale, normal);
}

// --- the tiling broken up: hex-tile sampling (Mikkelsen, "Practical
// Real-Time Hex-Tiling", JCGT 2022). The plane is cut into hexagons; each
// samples the texture offset at random and turned, and the three over a
// point blend by how near it is to each one's middle, sharpened toward the
// brighter so the blend keeps the texture's contrast instead of greying it.
// The derivatives are turned with the coordinates, so the mips stay right
// across the seams. Worked out once in main, read by the colour and the
// normal map alike.
bool hexOn = false;
vec3 hexWeights = vec3(1.0, 0.0, 0.0);
vec2 hexUV[3];
mat2 hexTurn[3];
vec2 hexDx = vec2(0.0);
vec2 hexDy = vec2(0.0);

vec2 hex_offset(ivec2 cell) {
    vec2 q = vec2(cell);
    return fract(sin(vec2(dot(q, vec2(127.1, 311.7)), dot(q, vec2(269.5, 183.3)))) * 43758.5453);
}

mat2 hex_rotation(ivec2 cell, float strength) {
    float angle = abs(float(cell.x * cell.y)) + abs(float(cell.x + cell.y)) + 3.14159265;
    angle = mod(angle, 6.28318531);
    if (angle > 3.14159265) angle -= 6.28318531;
    angle *= strength;
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, -s, s, c);
}

void hex_setup(vec2 uv, float rotation) {
    hexDx = dFdx(uv);
    hexDy = dFdy(uv);
    vec2 skewed = mat2(1.0, -0.57735027, 0.0, 1.15470054) * (uv * 3.46410162);
    ivec2 base = ivec2(floor(skewed));
    vec3 t = vec3(fract(skewed), 0.0);
    t.z = 1.0 - t.x - t.y;
    float s = step(0.0, -t.z);
    float s2 = 2.0 * s - 1.0;
    hexWeights = vec3(-t.z * s2, s - t.y * s2, s - t.x * s2);
    int si = int(s);
    ivec2 cells[3];
    cells[0] = base + ivec2(si, si);
    cells[1] = base + ivec2(si, 1 - si);
    cells[2] = base + ivec2(1 - si, si);
    for (int k = 0; k < 3; k++) {
        hexTurn[k] = hex_rotation(cells[k], rotation);
        vec2 middle = mat2(1.0, 0.0, 0.5, 0.86602540) * vec2(cells[k]) / 3.46410162;
        hexUV[k] = hexTurn[k] * (uv - middle) + middle + hex_offset(cells[k]);
    }
    hexOn = true;
}

vec4 hex_texture(sampler2D tex) {
    vec4 c0 = textureGrad(tex, hexUV[0], hexTurn[0] * hexDx, hexTurn[0] * hexDy);
    vec4 c1 = textureGrad(tex, hexUV[1], hexTurn[1] * hexDx, hexTurn[1] * hexDy);
    vec4 c2 = textureGrad(tex, hexUV[2], hexTurn[2] * hexDx, hexTurn[2] * hexDy);
    vec3 luma = vec3(0.299, 0.587, 0.114);
    vec3 bright = mix(vec3(1.0), vec3(dot(c0.rgb, luma), dot(c1.rgb, luma), dot(c2.rgb, luma)), 0.6);
    vec3 w = bright * pow(hexWeights, vec3(7.0));
    w /= max(w.x + w.y + w.z, 1e-6);
    hexWeights = w;
    return w.x * c0 + w.y * c1 + w.z * c2;
}

// The normal map through the same hexagons and weights, each sample's
// tilt turned back into the surface's own frame.
vec3 hex_normal() {
    vec3 n = vec3(0.0);
    for (int k = 0; k < 3; k++) {
        vec3 s = textureGrad(normalMap, hexUV[k], hexTurn[k] * hexDx, hexTurn[k] * hexDy).xyz * 2.0 - 1.0;
        s.xy = transpose(hexTurn[k]) * s.xy;
        n += hexWeights[k] * s;
    }
    return n;
}

// How much of the detail layer this fragment takes, worked out in main.
float detailWeight = 0.0;

// --- triplanar mapping (#737): the world position projected on the
// planes across x, y and z, each sampled, blended by the fourth power of
// how squarely the surface faces it.
bool triOn = false;
vec3 triWeights = vec3(0.0, 1.0, 0.0);
vec2 triX = vec2(0.0);
vec2 triY = vec2(0.0);
vec2 triZ = vec2(0.0);

void tri_setup(vec3 n, vec3 position, float metres) {
    vec3 w = pow(abs(n), vec3(4.0));
    triWeights = w / max(w.x + w.y + w.z, 1e-6);
    vec3 q = position / metres;
    triX = q.zy;
    triY = q.xz;
    triZ = q.xy;
    triOn = true;
}

vec4 tri_texture(sampler2D tex) {
    return texture(tex, triX) * triWeights.x + texture(tex, triY) * triWeights.y + texture(tex, triZ) * triWeights.z;
}

// How much a normal map's own bumps, averaged away by its mips, have to be
// put back into the roughness (Toksvig 2005): a filtered normal shorter
// than one is bumps the pixel covers, and a highlight over them spreads
// instead of sparkling. Read by main's roughness.
float normalVariance = 0.0;

float toksvig(float len, float strength) {
    float l = clamp(len, 0.001, 1.0);
    return min((1.0 - l) / l * strength * strength, 1.0);
}

// The normal maps of the three planes, each tilt laid on the surface's own
// normal by the whiteout blend (Golus, "Normal Mapping for a Triplanar
// Shader", 2017) and the three blended.
vec3 tri_normal(vec3 n, float strength) {
    vec3 tx = texture(normalMap, triX).xyz * 2.0 - 1.0;
    vec3 ty = texture(normalMap, triY).xyz * 2.0 - 1.0;
    vec3 tz = texture(normalMap, triZ).xyz * 2.0 - 1.0;
    normalVariance = toksvig(length(tx) * triWeights.x + length(ty) * triWeights.y + length(tz) * triWeights.z, strength);
    tx.xy *= strength;
    ty.xy *= strength;
    tz.xy *= strength;
    tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
    ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
    tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
    return normalize(tx.zyx * triWeights.x + ty.xzy * triWeights.y + tz.xyz * triWeights.z);
}

vec3 mapped_normal(vec3 normal, vec3 position, vec2 uv) {
    float strength = normalStrength * materialNormalStrength;
    if (triOn) return tri_normal(normal, strength);
    vec3 sampled = hexOn ? hex_normal() : texture(normalMap, uv).xyz * 2.0 - 1.0;
    normalVariance = toksvig(length(sampled), strength);
    if (detailWeight > 0.0) {
        // Whiteout blend: the fine tilt added to the coarse, the coarse kept.
        vec3 fine = texture(normalMap, uv * materialDetailScale).xyz * 2.0 - 1.0;
        sampled = vec3(sampled.xy + fine.xy * detailWeight, sampled.z);
    }
    sampled.xy *= strength;
    return normalize(cotangent_frame(normal, position, uv) * sampled);
}

// The wet's own grazing reflection at this pixel, worked out once in main
// from the wetness and the surface's facing, and read by every light.
float wetMirror = 0.0;

// One light's contribution. Everything here depends on which light is shading;
// anything that does not stays in main and is computed once.
vec3 direct_light(Light L, vec3 norm, vec3 viewDir, vec3 albedo, vec3 F0,
                  float NdotV, float adjustedRoughness, out vec3 backFill) {
    vec3 tempAdjustedLightColor = L.color * kelvinToRGB(L.temperature);

    vec3 lightDir;
    float attenuation = 1.0;
    if (L.isDirectional == 1) {
        lightDir = normalize(L.direction);
    } else {
        // High-precision point light calculation for perfect reflections
        vec3 lightVec = L.position - FragPos;
        float distance = length(lightVec);
        lightDir = lightVec / distance; // More precise than normalize()
        attenuation = 1.0 / (L.constantAtten + L.linearAtten * distance + L.quadraticAtten * distance * distance);
        if (L.isDirectional == 2) {
            // Off the cone's axis the light fades out, and past the outer
            // angle there is none.
            float onAxis = dot(-lightDir, normalize(L.direction));
            attenuation *= smoothstep(L.spotCosOuter, L.spotCosInner, onAxis);
        }
    }

    vec3 halfwayDir = normalize(lightDir + viewDir);
    vec3 radiance = tempAdjustedLightColor * L.intensity * attenuation;

    float NdotL_raw = dot(norm, lightDir);
    float HdotV = clamp(dot(halfwayDir, viewDir), 0.001, 1.0); // Avoid zero division
    float NdotL = max(NdotL_raw, 0.0);

    float NDF = distributionGGX(norm, halfwayDir, adjustedRoughness);
    float G = geometrySmith(norm, viewDir, lightDir, adjustedRoughness);
    vec3 F = fresnelSchlick(HdotV, F0);

    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= 1.0 - metallic; // Metallic surfaces don't have diffuse reflection

    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * NdotV * NdotL + 0.0001;
    vec3 specular = numerator / denominator;

    // A matte surface's highlight fades as the view grazes it. A wet or mirror
    // surface does the opposite: the grazing reflection is the brightest it
    // throws, which is why a lamp smears furthest down a wet road seen at a
    // shallow angle. reflectivity picks between the two -- zero leaves an
    // ordinary surface exactly as it was, above zero lifts the grazing
    // reflection and scales it by how wet the surface is.
    float viewAttenuation = pow(NdotV, 0.6);
    float mirror = max(reflectivity, wetMirror);
    if (mirror > 0.001) {
        float grazing = 1.0 - NdotV;
        specular *= mirror * (0.5 + grazing * grazing * 4.0);
    } else {
        specular *= viewAttenuation * 0.5;
    }

    vec3 clearcoat = calculateClearcoat(norm, viewDir, lightDir, halfwayDir, albedo);
    vec3 sheen = calculateSheen(norm, viewDir, lightDir, halfwayDir);
    vec3 transmission = calculateTransmission(norm, viewDir, lightDir, albedo);

    specular = compensateEnergyLoss(specular, NdotV, roughness);

    // Hemisphere lighting: standard NdotL for front faces, a fill for the back
    // so the terminator is not a hard cut. The fill is handed back apart: it
    // is the light's share of the sky's fill, and a shadow takes the direct
    // light only. Multiplied by the shadow with the rest, it was the whole
    // light a night ground had -- the sun under the horizon shadows
    // everything from below -- and a shadow on put the ground at two thirds
    // of its brightness with it off (#526).
    float hemisphereNdotL = max(NdotL_raw, 0.0);
    float fillLight = max(-NdotL_raw * 0.3, 0.0);
    backFill = fillLight * tempAdjustedLightColor * albedo * 0.2 * attenuation;

    vec3 lit = applyEnergyConservation(
        kD * albedo / 3.14159265359 * radiance * hemisphereNdotL,
        specular * radiance * hemisphereNdotL,
        clearcoat * radiance * hemisphereNdotL,
        sheen * radiance * hemisphereNdotL
    ) + transmission;

    return lit;
}


// Where this pixel's surface was last frame, for the temporal passes: the
// clip positions the vertex stage carried, this frame's unnudged (the
// frame is drawn through the jittered projection; the jitter is taken back
// out) less the last frame's, in texture space. A pixel nothing drew keeps
// the target's clear, zero. See docs/rendering.md, "Motion vectors".
vec2 velocity(vec4 now, vec4 prev, vec2 nudge) {
    if (now.w <= 0.0 || prev.w <= 0.0) return vec2(0.0);
    vec2 uvNow = now.xy / now.w * 0.5 + 0.5 - nudge;
    vec2 uvPrev = prev.xy / prev.w * 0.5 + 0.5;
    return uvNow - uvPrev;
}


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

// How much blood the splats lay on a bind-space point: each splat full
// inside, thinning to nothing at its edge, which wanders by a third of its
// radius as value noise so no two are the same disc; the most of any.
float splatCover(vec3 p) {
    float most = 0.0;
    for (int i = 0; i < 32; i++) {
        if (i >= woundCount) break;
        if (woundData[i * 3].w < 0.5) continue;
        vec3 r = max(woundData[i * 3 + 1].xyz, vec3(0.0001));
        vec3 local = woundUnturn(woundData[i * 3 + 2], p - woundData[i * 3].xyz) / r;
        float edge = 1.0 + 0.35 * (clipValueNoise(local * 3.0 + woundData[i * 3].xyz * 7.0) * 2.0 - 1.0);
        float cover = woundData[i * 3 + 1].w * (1.0 - smoothstep(0.8 * edge, edge, length(local)));
        most = max(most, cover);
    }
    return most;
}

// Damage (#544): a mask laid over the model's second UV set (or its
// first), four channels -- soaked blood, bruising, burning, and one spare --
// each drawing the surface toward its colour by its strength. Written on
// the CPU by splats at bind-space points (core.model_damage_splat), so it
// stays where it was put however the figure moves, and keeps every hit.


// Where the mask is read from (#560): its rectangle of the texture -- the
// whole of a model's own, or its cell of an atlas page -- and how far in
// from the cell's edges a read is clamped, so a filtered read never takes
// a neighbour's.


#ifdef VULKAN
layout(set = 0, binding = 9) uniform sampler2D damageMask;
#else

#endif

// The light from the sky (#655), what arrives from every direction: its
// reflections from the octahedral map prefiltered into roughness levels,
// the split-sum table that scales them by F0 (ae3d.skylight), and its
// irradiance onto every normal, an octahedral map of its own.
#ifdef VULKAN
layout(set = 0, binding = 10) uniform sampler2D skyLight;
layout(set = 0, binding = 11) uniform sampler2D brdfLut;
layout(set = 0, binding = 12) uniform sampler2D skyIrradiance;
layout(set = 0, binding = 13) uniform sampler2D occlusionMap;
#else




#endif
// Whether the occlusion map holds the last frame's (FRAGMENT_SSAO): one
// when the screen's occlusion is on and a frame has been drawn to find it.


// The screen's occlusion at this surface: found in the last frame's image
// where the surface was then (ClipPrev), if the depth found there is this
// surface's -- what the last frame did not show of it (a corner just come
// round, a figure just stepped aside), and a surface in front of the one
// that was there, is not occluded by what the map says.
float screen_occlusion() {
    if (occlusionHistory == 0 || ClipPrev.w <= 0.0) return 1.0;
    vec2 uv = ClipPrev.xy / ClipPrev.w * 0.5 + 0.5;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 1.0;
    vec2 found = texture(occlusionMap, uv).rg;
    if (abs(found.g - ClipPrev.w) > 0.05 * ClipPrev.w) return 1.0;
    return found.r;
}
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

vec3 sky_irradiance(vec3 n) {
    return texture(skyIrradiance, oct_uv(n, SKY_IRRADIANCE_SIZE)).rgb;
}
#ifdef AE3D_RAY_QUERY
// The probes' irradiance, where the device traces and the probes are on
// (#537): what the sky's light and every bounce of it bring to this point,
// in place of the sky's irradiance alone.
layout(set = 0, binding = 14) uniform sampler2D ddgiIrradiance;
layout(set = 0, binding = 15) uniform sampler2D ddgiDistance;
layout(set = 0, binding = 16, std430) readonly buffer DdgiState { vec4 ddgiProbeState[]; };





#define DDGI_DIMS ddgiDims
#define DDGI_BASE(c) ddgiBase[(c)].xyz
#define DDGI_SPACING(c) ddgiSpacing[(c)]
#define DDGI_ATLAS ddgiAtlas
#define DDGI_IRRADIANCE ddgiIrradiance
#define DDGI_DISTANCE ddgiDistance
#define DDGI_STATE(i) ddgiProbeState[(i)]
// v wrapped into 0 to d-1 on each axis (GLSL's % is undefined for a
// negative operand, and a grid west of the origin has negative cells).
ivec3 ddgi_wrap(ivec3 v, ivec3 d) {
    return v - d * ivec3(floor(vec3(v) / vec3(d)));
}

// The probe volume (#537, ae3d.vkddgi, whose layout this must match):
// DDGI_CASCADES grids of probes around the camera, each DDGI_DIMS probes
// DDGI_SPACING(c) apart, addressed toroidally -- a probe's slot is its
// world cell modulo the grid -- so the grid scrolls with the camera by whole
// cells and what a probe knows stays where it was learned. Each probe keeps
// its irradiance and its distance moments in octahedral texels in two
// atlases, a one-texel gutter round each, and its state -- the offset that
// moves it out of a wall, whether it is on -- in the state buffer.
//
// What a shader including this defines first: DDGI_DIMS (vec4: probes a
// side, x y z, and probes a cascade), DDGI_BASE(c) (vec3: the world cell of
// cascade c's first probe), DDGI_SPACING(c), DDGI_ATLAS (vec4: the
// irradiance atlas's size, then the distance atlas's), DDGI_IRRADIANCE and
// DDGI_DISTANCE (the atlases' samplers) and DDGI_STATE(i) (vec4 i of the
// state buffer).
#define DDGI_CASCADES 2
#define DDGI_IRR 6
#define DDGI_DIST 14

// A probe's index from its cascade and its slot in the grid.
int ddgi_index(int c, ivec3 slot) {
    ivec3 d = ivec3(DDGI_DIMS.xyz);
    return c * int(DDGI_DIMS.w) + (slot.z * d.y + slot.y) * d.x + slot.x;
}

// The slot of the probe at grid coordinate g of cascade c (0 to DDGI_DIMS-1
// from the cascade's first cell).
ivec3 ddgi_slot(int c, ivec3 g) {
    return ddgi_wrap(ivec3(DDGI_BASE(c)) + g, ivec3(DDGI_DIMS.xyz));
}

// Whether probe `index`, at grid coordinate g of cascade c, is on: traced
// since it came to its cell (its stamp's w 1, not 0, nor 2 for woken with
// its texels not yet replaced), and neither inside anything (its state's w
// 0) nor asleep, with nothing near it to light (w 2).
bool ddgi_on(int c, ivec3 g, int index) {
    vec4 stamp = DDGI_STATE(index * 2 + 1);
    return abs(DDGI_STATE(index * 2).w - 1.0) < 0.5 && abs(stamp.w - 1.0) < 0.5 && all(equal(stamp.xyz, DDGI_BASE(c) + vec3(g)));
}

// Where the probe at grid coordinate g of cascade c belongs: its cell's
// centre, not its corner, so a floor or a wall at a whole number of cells
// does not run through a row of probes.
vec3 ddgi_home(int c, ivec3 g) {
    return (DDGI_BASE(c) + vec3(g) + 0.5) * DDGI_SPACING(c);
}

// Where probe `index` stands: its home and the offset its state keeps.
vec3 ddgi_probe_position(int c, ivec3 g, int index) {
    return ddgi_home(c, g) + DDGI_STATE(index * 2).xyz;
}

// Point P in cascade c's grid coordinates, a probe at each whole number.
vec3 ddgi_grid(int c, vec3 P) {
    return P / DDGI_SPACING(c) - DDGI_BASE(c) - 0.5;
}

// The atlas texel a probe's octahedron starts at (its gutter's corner).
vec2 ddgi_corner(int index, float side) {
    int c = index / int(DDGI_DIMS.w);
    int local = index - c * int(DDGI_DIMS.w);
    ivec3 d = ivec3(DDGI_DIMS.xyz);
    int x = local % d.x;
    int y = (local / d.x) % d.y;
    int z = local / (d.x * d.y);
    return vec2(float(x + y * d.x), float(z + c * d.z)) * (side + 2.0);
}

// Where direction n is read in probe `index`'s octahedron of `side` texels.
vec2 ddgi_uv(int index, vec3 n, float side, vec2 atlas) {
    vec2 o = oct_encode(n) * 0.5 + 0.5;
    return (ddgi_corner(index, side) + 1.0 + o * side) / atlas;
}

// The irradiance onto a surface at P facing N, seen from V's side, from
// the eight probes of cascade c's cell around it: trilinear, each weighed
// by whether it faces the surface and by whether, by its distance moments,
// it can see it (Chebyshev). The irradiance the probes keep is the cosine
// average of the radiance, so pi times it is the irradiance; a weight sum of
// nothing returns -1, for the caller to take what lies beyond.
vec3 ddgi_cascade(int c, vec3 P, vec3 N, vec3 V, out float total) {
    float spacing = DDGI_SPACING(c);
    vec3 biased = P + (N * 0.2 + V * 0.8) * (0.3 * spacing);
    vec3 gridPos = ddgi_grid(c, biased);
    ivec3 g0 = ivec3(floor(gridPos));
    vec3 alpha = clamp(gridPos - vec3(g0), 0.0, 1.0);
    vec3 sum = vec3(0.0);
    total = 0.0;
    for (int i = 0; i < 8; i++) {
        ivec3 offset = ivec3(i & 1, (i >> 1) & 1, (i >> 2) & 1);
        ivec3 g = clamp(g0 + offset, ivec3(0), ivec3(DDGI_DIMS.xyz) - 1);
        int index = ddgi_index(c, ddgi_slot(c, g));
        if (!ddgi_on(c, g, index)) continue;
        vec3 probe = ddgi_probe_position(c, g, index);
        vec3 tri = mix(1.0 - alpha, alpha, vec3(offset));
        float weight = tri.x * tri.y * tri.z;
        vec3 toProbe = probe - P;
        vec3 dirToProbe = normalize(toProbe);
        float facing = (dot(dirToProbe, N) + 1.0) * 0.5;
        weight *= facing * facing + 0.2;
        vec3 fromProbe = biased - probe;
        float dist = length(fromProbe);
        vec2 moments = textureLod(DDGI_DISTANCE, ddgi_uv(index, fromProbe / max(dist, 1e-4), float(DDGI_DIST), DDGI_ATLAS.zw), 0.0).rg;
        float variance = abs(moments.x * moments.x - moments.y);
        float visible = 1.0;
        if (dist > moments.x) {
            float d = dist - moments.x;
            visible = variance / (variance + d * d);
            visible = max(visible * visible * visible, 0.0);
        }
        weight *= max(visible, 0.05);
        // Small weights crushed, so a probe that barely sees the point does
        // not tint it (Majercik et al.'s threshold).
        if (weight < 0.2) weight *= weight * weight / 0.04;
        vec3 irradiance = textureLod(DDGI_IRRADIANCE, ddgi_uv(index, N, float(DDGI_IRR), DDGI_ATLAS.xy), 0.0).rgb;
        sum += irradiance * weight;
        total += weight;
    }
    if (total <= 0.0) return vec3(0.0);
    return sum / total * 3.14159265;
}

// How far inside cascade c point P is, in cells from its nearest face: past
// one the cascade is whole; under it, the next one out takes over.
float ddgi_inside(int c, vec3 P) {
    vec3 gridPos = ddgi_grid(c, P);
    vec3 edge = min(gridPos, (DDGI_DIMS.xyz - 1.0) - gridPos);
    return min(edge.x, min(edge.y, edge.z));
}

// The probes' irradiance at P onto N, the nearest cascade that holds it
// blending into the next over its last cell, and beyond the last the
// `beyond` irradiance (the sky's) over the far cascade's last cell. From
// the near cascade out, so a point the near one holds whole reads its
// eight probes and no more.
vec3 ddgi_irradiance(vec3 P, vec3 N, vec3 V, vec3 beyond) {
    vec3 result = vec3(0.0);
    float left = 1.0;
    for (int c = 0; c < DDGI_CASCADES; c++) {
        float inside = ddgi_inside(c, P);
        if (inside <= 0.0) continue;
        float total;
        vec3 e = ddgi_cascade(c, P, N, V, total);
        if (total <= 0.0) continue;
        float share = clamp(inside, 0.0, 1.0) * left;
        result += e * share;
        left -= share;
        if (left <= 0.0) return result;
    }
    return result + beyond * left;
}
#endif

// The sky mirrored along r off a surface of `rough`: one read between the
// two levels it lies between. Every level is laid out as level 0 is (as a
// mip of it would be), so one coordinate is right at all of them.
vec3 sky_reflection(vec3 r, float rough) {
    float level = clamp(rough, 0.0, 1.0) * (SKY_LEVELS - 1.0);
    return textureLod(skyLight, oct_uv(r, SKY_SIZE), level).rgb;
}

// What the sky gives a surface: its diffuse, Lambert over the irradiance,
// and its reflection, prefiltered by the roughness and scaled by the split
// sum. A material that turns image-based lighting off keeps the diffuse.
vec3 sky_light(vec3 N, vec3 V, vec3 albedo, vec3 F0, float rough, float metal, float NdotV) {
    if (giOff != 0) return vec3(0.0);
    vec3 F = F0 + (max(vec3(1.0 - rough), F0) - F0) * pow(1.0 - NdotV, 5.0);
    vec3 kD = (vec3(1.0) - F) * (1.0 - metal);
    vec3 irradiance = sky_irradiance(N);
#ifdef AE3D_RAY_QUERY
    if (ddgiOn != 0) irradiance = ddgi_irradiance(FragPos, N, V, irradiance);
#endif
    vec3 diffuse = kD * albedo * irradiance / 3.14159265;
    if (!enableImageBasedLighting) return diffuse;
    vec2 ab = texture(brdfLut, vec2(NdotV, rough)).rg;
    vec3 specular = sky_reflection(reflect(-V, N), rough) * (F0 * ab.x + ab.y);
    return diffuse + specular * iblIntensity;
}

void main() {
    // A cut model's far side, not drawn (#545): nor its depth, which the
    // occlusion, the reflections and the water read from this pass.
    if (clippedAway(BindPos)) discard;
    // A wound's core is a hole (#543); around it, its layers.
    float woundAt = woundCount > 0 ? woundDepth(BindPos) : 2.0;
    if (woundAt < woundCore) discard;

    // Before any branch returns: every surface drawn carries its motion,
    // the glowing ones and a capture channel's frame too. An emissive
    // surface that returned without it left the vector undefined, and the
    // temporal pass dragged its history by whatever the driver left there.
    outVelocity = velocity(ClipNow, ClipPrev, jitter);

    vec4 texColor;
    if (materialTriplanar > 0.0) {
        tri_setup(normalize(Normal), FragPos, materialTriplanar);
        texColor = tri_texture(textureSampler);
    } else if (materialTileBreakup > 0.0) {
        hex_setup(fragTexCoord, materialTileRotation);
        texColor = hex_texture(textureSampler);
    } else {
        texColor = texture(textureSampler, fragTexCoord);
        if (FlipNext.z >= 0.0) texColor = mix(texColor, texture(textureSampler, FlipNext.xy), FlipNext.z);
    }
    if (texColor.a < materialCutout) discard;
    if (materialDetailScale > 0.0 && !triOn) {
        float away = length(FragPos - viewPos);
        detailWeight = materialDetailStrength * (1.0 - smoothstep(materialDetailFade * 0.5, materialDetailFade, away));
    }
    
    // An emissive surface is its own light source, so it skips shading. It does
    // not skip having a colour: this returned a hardcoded white, which made an
    // emissive model the one thing in the engine that could not be coloured --
    // diffuseColor, the texture and the per-instance tint were all discarded.
    // An accretion disc whose whole point is that its inner edge is blue-white
    // and its rim is red came out uniformly white.
    //
    // It is radiance like every lit surface beside it, so a colour brighter
    // than 1.0 (an instance colour is a float attribute, so it can carry one)
    // reaches the frame's one tone curve and rolls off to white there instead
    // of clipping per channel and shifting hue.
    //
    // exposure is the emissive strength, scaled so the 10.0 that opens this
    // branch means 1x. Below that the surface is lit normally.
    if (materialFire > 0.0) {
        float heat = clamp(texColor.r * InstanceColor.r, 0.0, 1.0);
        vec3 glowing = black_body(heat * materialFire) * (heat * heat * heat * heat) * max(exposure * 0.1, 1.0);
        FragColor = vec4(glowing * diffuseColor, texColor.a * materialAlpha * ParticleAlpha * soft_fade());
        return;
    }
    if (exposure > 10.0) {
        float glowAlpha = surfaceBlend != 0 ? texColor.a * materialAlpha * ParticleAlpha * soft_fade() : 1.0;
        FragColor = vec4(diffuseColor * texColor.rgb * InstanceColor * (exposure * 0.1), glowAlpha);
        return;
    }

    // Pre-calculate expensive operations once
    vec3 norm = normalize(Normal);
    if (impostor) {
        // The picture: cut out by its alpha, its normal read from its own
        // atlas in the figure's frame (x its facing, y up, z to its right)
        // and turned into the world by the facing the vertex carried, and
        // lit from there as any surface is.
        if (texColor.a < 0.5) discard;
        vec3 facing = normalize(Normal);
        vec3 baked = texture(normalMap, fragTexCoord).xyz * 2.0 - 1.0;
        norm = normalize(baked.x * facing + vec3(0.0, baked.y, 0.0) + baked.z * vec3(-facing.z, 0.0, facing.x));
    } else if (hasNormalMap) {
        norm = mapped_normal(norm, FragPos, fragTexCoord);
    }
    if (captureChannel == 1) {
        FragColor = vec4(diffuseColor * texColor.rgb * InstanceColor, texColor.a);
        return;
    }
    if (captureChannel == 2) {
        FragColor = vec4(norm * 0.5 + 0.5, 1.0);
        return;
    }
    // The capture channel for the motion: the vector in pixels, a hundred
    // pixels either way across the byte, so a test can read a known move.
    if (captureChannel == 3) {
        FragColor = vec4(outVelocity * screenSize / 200.0 + 0.5, 0.0, 1.0);
        return;
    }
    vec3 viewDir = normalize(viewPos - FragPos);

    // Material properties
    vec3 albedo = diffuseColor * texColor.rgb * InstanceColor; // Apply per-instance color
    // Blood splashed on the skin (#546), the outermost layer's colour.
    if (woundCount > 0) albedo = mix(albedo, woundLayers[0].rgb, splatCover(BindPos));
    // The damage the mask has kept (#544).
    vec2 maskAt = damageRect.xy + clamp(MaskUV, vec2(damageClamp), vec2(1.0 - damageClamp)) * damageRect.zw;
    vec4 damage = texture(damageMask, maskAt);
    if (damageOn != 0) {
        for (int k = 0; k < 4; k++) {
            albedo = mix(albedo, damageColours[k].rgb, clamp(damage[k] * damageColours[k].a, 0.0, 1.0));
        }
    }
    // Inside a wound, the layer it has cut down to: blood at the rim, then
    // fat, muscle, bone -- each from the share of the radius it starts at.
    if (woundAt < 1.0) {
        vec3 layer = woundLayers[0].rgb;
        for (int k = 1; k < 4; k++) {
            if (woundAt < woundLayers[k].w) layer = woundLayers[k].rgb;
        }
        albedo = mix(albedo, layer, smoothstep(1.0, 0.94, woundAt));
    }

    // The detail layer's colour, as a ratio to the texture's own mean (its
    // last mip), so it adds grain without shifting the colour.
    if (detailWeight > 0.0) {
        vec3 fine = texture(textureSampler, fragTexCoord * materialDetailScale).rgb;
        vec3 mean = max(textureLod(textureSampler, fragTexCoord, 16.0).rgb, vec3(0.02));
        albedo *= mix(vec3(1.0), clamp(fine / mean, vec3(0.0), vec3(2.0)), detailWeight);
    }

    // Patches over the world, two octaves of value noise, so a texture
    // repeated across a field is not the same from one stretch to the next.
    if (materialVariation > 0.0) {
        vec3 cell = FragPos / max(materialVariationScale, 0.01);
        float v = clipValueNoise(cell) * 0.65 + clipValueNoise(cell * 2.7 + vec3(13.1, 7.3, 2.9)) * 0.35;
        // Value noise keeps near its middle; stretched, the amount is reached.
        v = smoothstep(0.25, 0.75, v);
        albedo *= 1.0 + (v * 2.0 - 1.0) * materialVariation;
    }

    // GPU Gems Chapter 5: Apply Perlin noise for surface detail if enabled
    if (enablePerlinNoise) {
        vec3 noiseCoord = FragPos * noiseScale;
        float noiseValue = turbulence(noiseCoord, noiseOctaves);
        albedo = mix(albedo, albedo * (1.0 + noiseValue * 0.3), noiseIntensity);
    }

    // Calculate F0 (surface reflection at zero incidence) with realistic values
    // A dielectric reflects about four percent of what hits it head on, tinted
    // by the material's own specular colour, which is white unless it says so.
    vec3 F0 = vec3(0.04) * specularColor;

    // Use realistic metallic F0 values based on material color
    if (metallic > 0.5) {
        // For metals, use color-based F0 values that are more realistic
        vec3 metalF0 = albedo;

        // Enhance metallic reflectance based on color
        if (albedo.r > albedo.g && albedo.r > albedo.b) {
            // Reddish metals (copper, gold)
            metalF0 = mix(vec3(0.95, 0.64, 0.54), albedo, 0.7); // Copper-like
        } else if (albedo.g > albedo.r && albedo.g > albedo.b) {
            metalF0 = mix(vec3(0.70, 0.78, 0.74), albedo, 0.7);
        } else if (albedo.b > albedo.r && albedo.b > albedo.g) {
            metalF0 = mix(vec3(0.66, 0.73, 0.80), albedo, 0.7);
        } else {
            metalF0 = mix(vec3(0.95, 0.93, 0.88), albedo, 0.7); // Silver-like
        }

        F0 = mix(F0, metalF0, metallic);
    } else {
        F0 = mix(F0, albedo, metallic);
    }

    float NdotV = clamp(dot(norm, viewDir), 0.001, 1.0); // Avoid zero division
    // Ensure minimum roughness to prevent point light artifacts
    // The normal map's averaged-away bumps widen the lobe (Toksvig).
    float adjustedRoughness = max(sqrt(roughness * roughness + normalVariance), 0.08);
    // Rain on the surface: the flatter it lies, the more it holds. Darker,
    // smoother, and a mirror at a grazing angle.
    float wet = wetness * clamp(norm.y, 0.0, 1.0);
    wet *= wet;
    if (wet > 0.001) {
        albedo *= 1.0 - 0.35 * wet;
        adjustedRoughness = max(mix(adjustedRoughness, 0.05, wet), 0.08);
        wetMirror = wet * 0.7;
    } else {
        wetMirror = 0.0;
    }

    // The lights that reach everywhere, then the lamps of this pixel's
    // cluster.
    // A shadow takes the direct light and leaves the sky's fill alone:
    // multiplied over the whole colour, ambient included, as it was, a
    // shadow went to a third of black and the shadowed side of a hill at
    // dusk was a hole in the picture. And a light is shadowed by its own
    // map and no other's (#490): the key light by its cascades when it is
    // the sun or the moon and by its own cube when it is a lamp; a lamp of
    // the clusters by its own cube where it has one, and not at all where
    // it has none; the other directional lights, the fills, not at all. A
    // lamp shadowed by the moon's map put out the wall beside it wherever
    // the moon did not reach. The clouds' shadow is the key light's alone.
    float shaded = 1.0;
    if (hasShadowMap && enableShadows) shaded = shadow_factor();
    if (keyLampSlot >= 0 && lampShadowBase >= 0 && enableShadows) shaded = lamp_shadow(keyLampSlot, normalize(Normal));
#ifdef AE3D_RAY_QUERY
    bool traced = rayShadows == 1 && (rayReach <= 0.0 || distance(FragPos, viewPos) < rayReach);
    if (traced && enableShadows) shaded = min(shaded, ray_shadow_factor());
#endif
    float sunlit = cloudShadow(FragPos);
    vec3 Lo = vec3(0.0);
    for (int i = 0; i < 16; i++) {
        if (i >= lightCount) {
            break;
        }
        if (lights[i].isDirectional != 1) {
            // A key light that is a lamp: past its fall-off it gives this
            // pixel less than a hundredth of its light, and outside a spot's
            // cone none.
            vec3 gap = lights[i].position - FragPos;
            if (dot(gap, gap) * lights[i].quadraticAtten > 64.0) continue;
            if (lights[i].isDirectional == 2 &&
                dot(normalize(-gap), normalize(lights[i].direction)) < lights[i].spotCosOuter) continue;
        }
        vec3 backFill;
        vec3 lit = direct_light(lights[i], norm, viewDir, albedo, F0, NdotV, adjustedRoughness, backFill);
        Lo += (i == 0 ? lit * sunlit * shaded : lit) + backFill;
    }
    if (clusterDims.w > 0.5) {
        int cell = cluster_of(FragPos);
        int first = int(cluster_word(cell * 2) + 0.5);
        int count = int(cluster_word(cell * 2 + 1) + 0.5);
        for (int k = 0; k < count; k++) {
            float reach;
            int lampSlot;
            Light L = clustered_light(int(cluster_word(first + k) + 0.5), reach, lampSlot);
            vec3 gap = L.position - FragPos;
            float far2 = dot(gap, gap);
            if (far2 >= reach * reach) continue;
            if (L.isDirectional == 2 &&
                dot(normalize(-gap), normalize(L.direction)) < L.spotCosOuter) continue;
            float fade = 1.0 - smoothstep(CLUSTER_FADE_START * reach, reach, sqrt(far2));
            vec3 backFill;
            vec3 lit = direct_light(L, norm, viewDir, albedo, F0, NdotV, adjustedRoughness, backFill) * fade;
            Lo += backFill * fade;
            float shade = 1.0;
            if (lampSlot >= 0 && lampShadowBase >= 0 && enableShadows && dot(lit, vec3(0.333)) > 0.002) {
                shade = lamp_shadow(lampSlot, normalize(Normal));
            }
#ifdef AE3D_RAY_QUERY
            // By ray a lamp throws its own shadow, where it reaches: past the
            // lamp's fall-off there is no light to shadow and no ray is cast.
            if (traced && enableShadows) {
                if (dot(lit, vec3(0.333)) > 0.002) shade = ray_lamp_factor(L.position, rayLampRadius);
                else shade = 1.0;
            }
#endif
            Lo += lit * shade;
        }
    }

    // The sky's light arrives from every direction, so what a point can see
    // of the sky is exactly what scales it: the occlusion, baked, on the
    // screen and by ray,
    // belongs to this term and no other -- darkening the direct light as
    // well would put a shadow where a lamp is plainly shining.
    float shut = mix(1.0, Occlusion, occlusionStrength) * screen_occlusion();
#ifdef AE3D_RAY_QUERY
    if (traced && rayOcclusion > 0.0) shut *= ray_occlusion_factor();
#endif
    vec3 color = sky_light(norm, viewDir, albedo, F0, adjustedRoughness, metallic, NdotV) * shut + Lo;

	// Calculate distance for performance scaling (CRITICAL for voxel terrain performance)
	float distanceToCamera = length(FragPos - viewPos);
	
	// Apply modern lighting effects with distance-based LOD
	
	// Volumetric lighting (with distance LOD built-in)
	vec3 volumetric = calculateVolumetricLighting(FragPos, lights[0].position, viewPos);
	color += volumetric;
    
    color += caustic_light(FragPos, norm) * albedo;

    
    // The material's own exposure: how much light it gives back for what
    // reaches it (a particle's glow, a dimmed decal). The frame's exposure,
    // the bloom and the tone curve are the post pass's, once for the whole
    // frame, so the colour written here is radiance.
    color = color * exposure;

    // The air between the eye and the surface: the light the haze scatters
    // toward the eye in place of the surface's. Its radiance is the fog colour
    // as it shows at an exposure of one, so a scene fogged to a colour still
    // fades to that colour on the screen.
    if (enableFog) {
        float haze = smoothstep(fogStart, fogEnd, distanceToCamera) * fogIntensity;
        color = mix(color, fogRadiance, clamp(haze, 0.0, 1.0));
    }

    // Use material alpha for transparency
    float finalAlpha = texColor.a * materialAlpha;
    
    // Ensure opaque materials are fully opaque
    if (materialAlpha >= 0.99) {
        finalAlpha = 1.0; // Force fully opaque for materials that should be opaque
    }
    if (surfaceBlend != 0) finalAlpha = texColor.a * materialAlpha * ParticleAlpha * soft_fade();
    
    FragColor = vec4(color, finalAlpha);
}
