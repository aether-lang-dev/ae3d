#include "ae3d.h"
#include "internal.h"
#include "vulkan_shaders.h"
#include "vulkan_uniforms.h"
#include "../dlss/streamline.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <vulkan/vulkan.h>

#define AE3D_VK_FRAMES 2
/* Asked for at binding 4 in place of a texture handle: the camera depth. */
#define AE3D_VK_AUX_SCENE_DEPTH (-1)
/* Timestamps a frame: start, after shadow, after scene, after post. */
/* Eight timestamps a frame: the start, and the end of the shadow pass, the
   camera-depth prepass, the sky, the opaque draws, the occlusion, the
   transparent draws (the scene pass's end) and the post chain. */
#define AE3D_VK_STAMPS 8
#define AE3D_VK_STAGES 8
/* A cached descriptor set whose texture has been destroyed. Not zero: zero is
   a texture handle nothing uses, and not -1 alone, which reads as an error. */
#define AE3D_VK_SET_FREE (-2)
/* The shadow atlas: four cascades of 2048 texels, two by two
   (ae3d.cascades' ATLAS and SIZE, #469). */
#define AE3D_VK_SHADOW_SIZE 4096
/* The lamps' atlas: eight by eight faces of 512 texels
   (ae3d.lampshadows' ATLAS, FACE and ACROSS). */
#define AE3D_VK_LAMP_SHADOW_SIZE 4096
#define AE3D_VK_PROGRAM_SCENE 0
#define AE3D_VK_PROGRAM_WATER 1
#define AE3D_VK_PROGRAM_COUNT 2
#define AE3D_VK_DRAWS_PER_FRAME 4096
#define AE3D_VK_MAX_TEXTURES 256
#define AE3D_VK_SKIN_STRIDE (8 * (unsigned)sizeof(float))
#define AE3D_VK_STRIDE (9 * (int)sizeof(float))

/* An Aether module's part of the frame (#402), and when in the frame's
   end it records: what measures the scene, then what draws over it, then
   what reads the finished picture (AE3D_VK_STAGE_*). */
#define AE3D_VK_HOOKS 8
#define AE3D_VK_STAGE_MEASURE 0
#define AE3D_VK_STAGE_DRAW 1
#define AE3D_VK_STAGE_READ 2
typedef struct {
    void (*record)(void *);
    void (*collect)(void *);
    void (*release)(void *);
    void *context;
    int stage;
} ae3d_vk_hooks;

/* The instance, the surface and the device are ae3d.vkdevice's; what the
   backend calls on them it loads through the same vkGetInstanceProcAddr
   when it adopts them. */
#define AE3D_VK_INSTANCE_FUNCS(X) \
    X(vkGetPhysicalDeviceProperties) \
    X(vkGetPhysicalDeviceQueueFamilyProperties) \
    X(vkGetPhysicalDeviceMemoryProperties) \
    X(vkGetDeviceProcAddr) \
    X(vkGetPhysicalDeviceProperties2)

// Only present when a surface extension was enabled. An offscreen device asks
// for none, so these are loaded but never required.
#define AE3D_VK_SURFACE_FUNCS(X) \
    X(vkGetPhysicalDeviceSurfaceCapabilitiesKHR) \
    X(vkGetPhysicalDeviceSurfaceFormatsKHR) \
    X(vkGetPhysicalDeviceSurfacePresentModesKHR)

#define AE3D_VK_DEVICE_FUNCS(X) \
    X(vkGetDeviceQueue) \
    X(vkDeviceWaitIdle) \
    X(vkQueueWaitIdle) \
    X(vkCreateImage) \
    X(vkDestroyImage) \
    X(vkGetImageMemoryRequirements) \
    X(vkBindImageMemory) \
    X(vkCreateImageView) \
    X(vkDestroyImageView) \
    X(vkAllocateMemory) \
    X(vkFreeMemory) \
    X(vkMapMemory) \
    X(vkUnmapMemory) \
    X(vkCreateBuffer) \
    X(vkDestroyBuffer) \
    X(vkGetBufferMemoryRequirements) \
    X(vkBindBufferMemory) \
    X(vkCreateRenderPass) \
    X(vkDestroyRenderPass) \
    X(vkCreateFramebuffer) \
    X(vkDestroyFramebuffer) \
    X(vkCreateShaderModule) \
    X(vkDestroyShaderModule) \
    X(vkCreatePipelineLayout) \
    X(vkDestroyPipelineLayout) \
    X(vkCreateGraphicsPipelines) \
    X(vkDestroyPipeline) \
    X(vkCreateCommandPool) \
    X(vkDestroyCommandPool) \
    X(vkAllocateCommandBuffers) \
    X(vkFreeCommandBuffers) \
    X(vkBeginCommandBuffer) \
    X(vkEndCommandBuffer) \
    X(vkResetCommandBuffer) \
    X(vkCmdBeginRenderPass) \
    X(vkCmdEndRenderPass) \
    X(vkCmdBindPipeline) \
    X(vkCmdBindVertexBuffers) \
    X(vkCmdBindIndexBuffer) \
    X(vkCmdDrawIndexed) \
    X(vkCmdDrawIndexedIndirect) \
    X(vkCmdDispatch)     X(vkCmdClearColorImage) \
    X(vkCmdFillBuffer) \
    X(vkCmdUpdateBuffer) \
    X(vkCreateComputePipelines) \
    X(vkCmdPushConstants) \
    X(vkCmdSetViewport) \
    X(vkCmdSetScissor) \
    X(vkCmdClearAttachments) \
    X(vkCmdClearDepthStencilImage) \
    X(vkCmdCopyBuffer) \
    X(vkCreateDescriptorSetLayout) \
    X(vkDestroyDescriptorSetLayout) \
    X(vkCreateDescriptorPool) \
    X(vkDestroyDescriptorPool) \
    X(vkAllocateDescriptorSets) \
    X(vkResetDescriptorPool) \
    X(vkUpdateDescriptorSets) \
    X(vkCmdBindDescriptorSets) \
    X(vkCreateSampler) \
    X(vkDestroySampler) \
    X(vkCmdPipelineBarrier) \
    X(vkCmdCopyBufferToImage) \
    X(vkCmdCopyImageToBuffer) \
    X(vkCmdBlitImage) \
    X(vkCmdCopyImage) \
    X(vkCreateSemaphore) \
    X(vkDestroySemaphore) \
    X(vkCreateFence) \
    X(vkDestroyFence) \
    X(vkWaitForFences) \
    X(vkResetFences) \
    X(vkQueueSubmit) \
    X(vkCreateQueryPool) \
    X(vkDestroyQueryPool) \
    X(vkCmdResetQueryPool) \
    X(vkCmdWriteTimestamp) \
    X(vkGetQueryPoolResults)

// Swapchain entry points come from the device extension an offscreen device
// does not enable, so they are loaded the same way and required the same way.
#define AE3D_VK_SWAPCHAIN_FUNCS(X) \
    X(vkCreateSwapchainKHR) \
    X(vkDestroySwapchainKHR) \
    X(vkGetSwapchainImagesKHR) \
    X(vkAcquireNextImageKHR) \
    X(vkQueuePresentKHR)

#define AE3D_VK_DECLARE(name) static PFN_##name ae3d_##name;
AE3D_VK_INSTANCE_FUNCS(AE3D_VK_DECLARE)
AE3D_VK_SURFACE_FUNCS(AE3D_VK_DECLARE)
AE3D_VK_DEVICE_FUNCS(AE3D_VK_DECLARE)
AE3D_VK_SWAPCHAIN_FUNCS(AE3D_VK_DECLARE)
#undef AE3D_VK_DECLARE

typedef struct {
    VkBuffer vertex_buffer;
    VkDeviceMemory vertex_memory;
    VkBuffer index_buffer;
    VkDeviceMemory index_memory;
    /* Joints and weights, for a mesh that has them. A mesh that does not
       allocates nothing here and is drawn by a pipeline whose vertex input
       does not name the binding. */
    VkBuffer skin_buffer;
    VkDeviceMemory skin_memory;
    int skinned;
    unsigned index_count;
    int in_use;
    /* An instance stream that moves every frame is written in place into a
       ring of host-visible buffers, one per frame in flight, and the frame's
       draws bind that frame's. Nothing is waited for and nothing destroyed:
       the slot a frame writes was last read by the frame whose fence
       frame_begin already waited on. Made on the first update, sized to the
       largest stream seen. */
    VkBuffer ring[AE3D_VK_FRAMES];
    /* An instance stream of points: eight floats an instance, drawn through
       the point pipelines, whose second binding strides by that. */
    int points;
    VkDeviceMemory ring_memory[AE3D_VK_FRAMES];
    void *ring_mapped[AE3D_VK_FRAMES];
    VkDeviceSize ring_size;
    int streaming;
} ae3d_vk_mesh;

typedef struct {
    VkImage image;
    VkDeviceMemory memory;
    VkImageView view;
    VkSampler sampler;
    int width;
    int height;
    int in_use;
    int mip_levels;   /* a scene texture with a mip chain: its sampler takes the LOD bias */
} ae3d_vk_texture;

typedef struct {
    VkBuffer buffer;
    VkDeviceMemory memory;
    unsigned char *mapped;
    unsigned stride;
    unsigned capacity;
    unsigned used;
} ae3d_vk_uniform_ring;

/* The scene's clustered lamps for one frame slot (#468): the lamps and the
   cells' lists ae3d.lightgrid builds, written by ae3d.vulkan into mapped,
   coherent memory before the slot's draws, and read by the scene fragment
   shader as storage buffers at bindings 6 and 7. Grown in place when a
   scene needs more, once the slot's fence has passed. */
typedef struct {
    VkBuffer buffer;
    VkDeviceMemory memory;
    void *mapped;
    VkDeviceSize size;
} ae3d_vk_cluster_buffer;

/* What a slot's buffers start at: enough for a street of lamps without a
   regrow, a few kilobytes against the scene's megabytes. */
#define AE3D_VK_CLUSTER_LIGHT_BYTES (256 * 5 * 16)
#define AE3D_VK_CLUSTER_WORD_BYTES (65536 * 4)

static struct {
    VkInstance instance;
    VkSurfaceKHR surface;
    VkPhysicalDevice physical;
    VkDevice device;
    VkQueue graphics_queue;
    VkQueue present_queue;
    unsigned graphics_family;
    unsigned present_family;
    VkPhysicalDeviceMemoryProperties memory_properties;

    VkSwapchainKHR swapchain;
    VkFormat color_format;
    VkColorSpaceKHR color_space;
    VkPresentModeKHR present_mode;
    VkExtent2D extent;
    unsigned image_count;
    VkImage *images;
    VkImageView *image_views;
    VkFramebuffer *framebuffers;

    VkFormat depth_format;
    VkImage depth_image;
    VkDeviceMemory depth_memory;
    VkImageView depth_view;

    VkSampleCountFlagBits samples;
    VkImage colour_image;
    VkDeviceMemory colour_memory;
    VkImageView colour_view;
    /* The motion vectors, the scene pass's second colour attachment: the
       multisampled image it draws into, and the resolved one (a texture, so
       the temporal passes sample it) -- the only one when there is one
       sample. R16G16, texture-space units. */
    VkFormat velocity_format;
    /* The scene is drawn at render_extent -- the swapchain's extent times
       render_scale, 1 unless asked otherwise -- into targets of that size,
       and the composite draws it to the swapchain at the swapchain's. An
       upscaler (DLSS) sits between the two. */
    VkExtent2D render_extent;
    double render_scale;
    float lod_bias;      /* the scene textures' mip bias for the render scale */
    /* Ray queries: the device has them (extensions and features on), and
       the frame slots' top-level structures ae3d.vkrays built, which the
       scene's descriptor sets bind at binding 5. */
    int ray_query;
    VkAccelerationStructureKHR tlas[AE3D_VK_FRAMES];
    /* DLSS (native/ae3d_dlss.h): asked for before the loader opened, so
       Streamline's interposer is the loader; whether the device runs it;
       the mode in force; the frame-size image it writes, kept in
       shader-read layout between frames (undefined until the first); and
       the camera the frame was drawn with, for its reprojection. */
    int dlss_loaded;
    int dlss_supported;
    int dlss_mode;
    int dlss_output;
    int dlss_output_fresh;
    int dlss_reset;
    int dlss_failed;     /* an evaluation refused: off, and said so */
    unsigned dlss_frame;
    ae3d_dlss_camera dlss_camera;
    int dlss_camera_set;
    VkImage velocity_image;
    VkDeviceMemory velocity_memory;
    VkImageView velocity_view;
    int velocity_texture;
    int capture_bypass;                /* a capture channel: no effects this frame */

    VkRenderPass render_pass;
    VkRenderPass scene_pass;
    VkRenderPass post_pass;
    VkRenderPass shadow_pass;
    /* The lamps' own shadows (ae3d.lampshadows, #490): one depth atlas of
       their cube faces, kept from frame to frame -- a face is drawn again
       only when what stands in it changes, so the pass loads the atlas and
       clears just the tiles it draws. It outlives the swapchain. */
    VkRenderPass lamp_pass;
    VkImage lamp_image;
    VkDeviceMemory lamp_memory;
    VkImageView lamp_view;
    VkSampler lamp_sampler;
    VkFramebuffer lamp_framebuffer;
    /* And the static layer under it: what stands still, drawn when it
       changes and copied into the atlas above tile by tile, with what
       moves drawn over the copy (ae3d.lampshadows). */
    VkImage lamp_static_image;
    VkDeviceMemory lamp_static_memory;
    VkImageView lamp_static_view;
    VkFramebuffer lamp_static_framebuffer;
    int lamp_generation;
    /* Whether the cascades' atlas has been through its pass since it was
       made: until then it is in no layout the lit pass may sample, and a
       frame whose key light is a lamp draws no cascade. */
    int shadow_ready;
    VkFramebuffer shadow_framebuffer;
    VkImage shadow_image;
    VkDeviceMemory shadow_memory;
    VkImageView shadow_view;
    VkSampler shadow_sampler;
    VkPipeline shadow_pipeline;
    int normal_map;
    VkPipeline skinned_shadow_pipeline;
    VkPipeline water_pipeline[2];
    VkPipeline water_pipeline_blend;
    int program;
    int shadow_enabled;
    // Screen-space reflection: a camera-space depth prepass, sampled by the SSR
    // post pass to reflect on-screen geometry onto wet surfaces. Off unless a
    // scene asks for it, so the default render pays nothing and cannot break;
    // the target is built the first time it is turned on. The depth is single-
    // sample and sampleable by construction (the shadow map's pattern), which
    // is why it does not have to resolve the multisampled scene depth.
    int ssr_enabled;
    /* The scene pass in two halves, when something reads the scene's depth:
       the first ends after the opaque draws with the frame's depth kept and
       readable, the resolve copies it into the camera-depth image, and the
       second loads what the first drew and goes on with the occlusion and
       the transparent draws. Compatible with the whole pass, so every
       pipeline built for that serves in these. */
    VkRenderPass render_pass_first, render_pass_rest;
    VkRenderPass scene_pass_first, scene_pass_rest;
    int depth_split;      /* this frame is drawn in two halves */
    int depth_resolved;   /* ...and the resolve has run: the second half is open or next */
    VkPipeline depth_resolve_pipeline;
    VkDescriptorSet depth_resolve_set[AE3D_VK_FRAMES];
    VkRenderPass camdepth_pass;
    VkFramebuffer camdepth_framebuffer;
    VkImage camdepth_image;
    VkDeviceMemory camdepth_memory;
    VkImageView camdepth_view;
    VkSampler camdepth_sampler;
    int camdepth_width;
    int camdepth_height;
    int pass_open;
    int in_shadow_pass;
    /* Whether something other than the reflection wants the camera depth
       drawn: a water surface reading the ground under it. */
    int scene_depth_wanted;
    VkDescriptorSet ssr_set[AE3D_VK_FRAMES];
    int ssr_set_built;
    float ssr_road_height;
    float ssr_strength;
    // Ambient occlusion from the same camera depth: a fullscreen multiply
    // drawn into the scene pass after the opaque geometry, before anything
    // transparent, with its own descriptor sets since the reflection's are
    // written for the post stage with the scene colour bound.
    int ssao_enabled;
    float ssao_radius;
    float ssao_intensity;
    VkPipeline ssao_pipeline;
    VkDescriptorSet ssao_set[AE3D_VK_FRAMES];
    // The reflective composite writes here rather than to the swapchain, so the
    // ordinary bloom/fxaa composite can then read it and bloom the mirrored
    // lamps too. It is a single-sample colour target that ends the pass in
    // sampler-read layout, built and torn down with the camera-depth target.
    VkRenderPass ssr_pass;
    VkFramebuffer ssr_framebuffer;
    int ssr_reflect_texture;
    /* Temporal anti-aliasing: the frame folded into a history, in two
       textures written in turn -- this frame's result from the last
       frame's -- through the same post-format pass the reflection uses.
       The history is empty at the start and after a resize. */
    int taa_enabled;
    VkPipeline taa_pipeline;
    int taa_texture[2];
    VkFramebuffer taa_framebuffer[2];
    VkDescriptorSet taa_set[2][AE3D_VK_FRAMES];
    int taa_history_valid;
    int taa_current;
    float scene_clear[4];
    VkFramebuffer scene_framebuffer;
    VkFramebuffer *post_framebuffers;
    int post_texture;
    VkPipeline post_pipelines[4];
    VkPipeline sky_pipeline;
    int screen_quad;
    int fxaa;
    int bloom;
    int post_active;

    /* GPU time per pass. Four timestamps a frame -- start, after the shadow
       pass, after the scene pass, after post -- in one pool, read back when
       the frame's fence says the GPU has finished with them, which is
       AE3D_VK_FRAMES frames later and never a wait. */
    VkQueryPool timestamps;
    double timestamp_ms;          /* milliseconds per tick, from the device */
    unsigned max_image_2d;        /* the widest 2D image the device creates */
    /* Meshes' uploads and structures recorded together and submitted once
       (ae3d_vk_flush_uploads) rather than a submit and a wait each: a
       scene of 250 distinct meshes waited on the queue 750 times. The
       copies are ae3d.vkmesh's, recorded into the batch; a mesh's
       structure is built into it here, when the mesh is adopted. */
    VkCommandBuffer batch;        /* the recording batch, or null */
    VkBuffer *batch_kept;         /* its staging and its structures' scratch, freed at the flush */
    VkDeviceMemory *batch_kept_memory;
    int batch_kept_count, batch_kept_capacity;
    int timestamps_usable;        /* the graphics queue reports valid bits */
    int stamped[AE3D_VK_FRAMES];  /* this frame's four stamps were all written */
    int stamp_next;               /* how many of this frame's stamps are written */
    double pass_ms[AE3D_VK_STAGES];

    /* What a frame costs in changes of mind, the same way the OpenGL backend
       counts them. A pipeline bound twice in a row is bound once. */
    VkPipeline bound_pipeline;
    int bound_texture;
    int bound_normal;
    int pipeline_binds;
    int set_binds;
    VkPipelineLayout pipeline_layout;
    // Indexed by whether back faces are culled. Cull mode is fixed at pipeline
    // creation before Vulkan 1.3 and the loader targets 1.1, so the two states
    // are two pipelines rather than one dynamic state.
    VkPipeline pipeline[2];
    VkPipeline pipeline_blend;
    VkPipeline skinned_pipeline[2];
    VkPipeline skinned_pipeline_blend;
    /* A crowd: instanced and skinned, every instance posed from the pose bank
       at its own phase. Its own vertex shader, so its own pipelines, and a
       depth variant for the shadow pass. */
    VkPipeline crowd_pipeline[2];
    VkPipeline crowd_pipeline_blend;
    VkPipeline crowd_shadow_pipeline;
    /* Point instances: the scene pipelines again over a second binding of
       eight floats an instance, and a depth variant for the shadow pass. */
    VkPipeline point_pipeline[2];
    VkPipeline point_pipeline_blend;
    VkPipeline point_shadow_pipeline;
    /* The pose bank the next draws are posed from, as a texture handle; zero
       between crowds. Part of the descriptor set's key, at binding 4. */
    int pose_bank;
    int cull;
    VkDescriptorSetLayout set_layout;
    VkDescriptorPool descriptor_pool;
    VkCommandPool command_pool;

    ae3d_vk_uniform_ring uniforms[AE3D_VK_FRAMES];
    ae3d_vk_cluster_buffer cluster_lights[AE3D_VK_FRAMES];
    ae3d_vk_cluster_buffer cluster_words[AE3D_VK_FRAMES];
    VkDescriptorSet sets[AE3D_VK_FRAMES][AE3D_VK_MAX_TEXTURES];
    int set_texture[AE3D_VK_FRAMES][AE3D_VK_MAX_TEXTURES];
    int set_normal[AE3D_VK_FRAMES][AE3D_VK_MAX_TEXTURES];
    int set_bank[AE3D_VK_FRAMES][AE3D_VK_MAX_TEXTURES];
    int set_count[AE3D_VK_FRAMES];

    ae3d_vk_texture textures[AE3D_VK_MAX_TEXTURES];
    int default_texture;

    // One block per program, the way OpenGL gives every program its own uniform
    // state. Sharing one would let a model's uniforms leak into the next draw
    // that uses a different program, since the two blocks share member names.
    ae3d_vk_scene scene[AE3D_VK_PROGRAM_COUNT];
    int blend;
    int draw_calls;
    float bloom_threshold;
    float bloom_intensity;
    VkBuffer identity_instance;
    VkDeviceMemory identity_instance_memory;
    /* One unused joint and weight, for the draws whose pipeline strides zero
       through it. */
    VkBuffer empty_skin;
    VkDeviceMemory empty_skin_memory;

    VkCommandBuffer command_buffers[AE3D_VK_FRAMES];
    VkSemaphore image_available[AE3D_VK_FRAMES];
    VkSemaphore render_finished[AE3D_VK_FRAMES];
    VkFence in_flight[AE3D_VK_FRAMES];

    unsigned frame;
    unsigned image_index;
    int recording;
    int needs_resize;
    int pending_width;
    int pending_height;

    ae3d_vk_mesh *meshes;
    int mesh_capacity;

    VkDeviceMemory offscreen_memory;   /* the offscreen target's image's */
    int offscreen;

    // Whether a windowed frame can be read back (ae3d.vkreadback copies it
    // when a capture is asked for).
    int can_capture;      /* the surface allows a transfer-source swapchain */
    /* The Aether modules' parts of the frame (ae3d_vk_add_frame_hooks,
       #402): each recorded after the frame's last pass, collected once its
       fence has passed, released with the swapchain it was sized to. */
    ae3d_vk_hooks hooks[AE3D_VK_HOOKS];
    int hook_count;

    int ready;
} vk;

static char g_vk_error[512] = "vulkan not initialised";

static int ae3d_vk_fail(const char *message) {
    snprintf(g_vk_error, sizeof(g_vk_error), "%s", message);
    return 0;
}

static int ae3d_vk_fail_code(const char *message, VkResult result) {
    snprintf(g_vk_error, sizeof(g_vk_error), "%s (VkResult %d)", message, (int)result);
    return 0;
}

const char *ae3d_vk_last_error(void) { return g_vk_error; }

/* The vkGetInstanceProcAddr the device was made through: the loader's,
   or Streamline's interposer when DLSS was asked for (ae3d.vkdevice). */
static PFN_vkGetInstanceProcAddr g_gipa;

static int ae3d_vk_load_instance(void) {
    PFN_vkGetInstanceProcAddr gipa = g_gipa;
    if (!gipa) return ae3d_vk_fail("vkGetInstanceProcAddr unavailable");

#define AE3D_VK_LOAD_INSTANCE(name) \
    ae3d_##name = (PFN_##name)gipa(vk.instance, #name); \
    if (!ae3d_##name) return ae3d_vk_fail("missing " #name);
    AE3D_VK_INSTANCE_FUNCS(AE3D_VK_LOAD_INSTANCE)
#undef AE3D_VK_LOAD_INSTANCE

#define AE3D_VK_LOAD_SURFACE(name) ae3d_##name = (PFN_##name)gipa(vk.instance, #name);
    AE3D_VK_SURFACE_FUNCS(AE3D_VK_LOAD_SURFACE)
#undef AE3D_VK_LOAD_SURFACE

    if (!vk.offscreen) {
#define AE3D_VK_NEED_SURFACE(name) if (!ae3d_##name) return ae3d_vk_fail("missing " #name);
        AE3D_VK_SURFACE_FUNCS(AE3D_VK_NEED_SURFACE)
#undef AE3D_VK_NEED_SURFACE
    }
    return 1;
}

static int ae3d_vk_load_device(void) {
#define AE3D_VK_LOAD_DEVICE(name) \
    ae3d_##name = (PFN_##name)ae3d_vkGetDeviceProcAddr(vk.device, #name); \
    if (!ae3d_##name) return ae3d_vk_fail("missing " #name);
    AE3D_VK_DEVICE_FUNCS(AE3D_VK_LOAD_DEVICE)
#undef AE3D_VK_LOAD_DEVICE

#define AE3D_VK_LOAD_SWAPCHAIN(name) ae3d_##name = (PFN_##name)ae3d_vkGetDeviceProcAddr(vk.device, #name);
    AE3D_VK_SWAPCHAIN_FUNCS(AE3D_VK_LOAD_SWAPCHAIN)
#undef AE3D_VK_LOAD_SWAPCHAIN

    if (!vk.offscreen) {
#define AE3D_VK_NEED_SWAPCHAIN(name) if (!ae3d_##name) return ae3d_vk_fail("missing " #name);
        AE3D_VK_SWAPCHAIN_FUNCS(AE3D_VK_NEED_SWAPCHAIN)
#undef AE3D_VK_NEED_SWAPCHAIN
    }
    return 1;
}

/* The device ae3d.vkdevice made for the frame, adopted: the instance,
   the window's surface (null offscreen), the physical device, the logical
   one and its two queue families, whether it traces rays and whether DLSS
   was loaded for it. The backend's entry points are loaded through `gipa`,
   the one the device was made through, and what it reads of the device --
   its limits, its memory kinds, whether its graphics queue keeps time --
   is read here. The settings a program made before the device (shadows,
   the post chain, the render scale) and the Aether modules' frame hooks
   are kept; the rest of the backend's state starts empty. The device is
   ae3d.vkdevice's to destroy, after ae3d_vk_shutdown. */
int ae3d_vk_adopt_device(void *gipa, void *instance, void *surface, void *physical, void *device,
                         int graphics_family, int present_family, int ray_query, int dlss_loaded) {
    int shadows = vk.shadow_enabled;
    int fxaa = vk.fxaa, bloom = vk.bloom;
    float bloom_threshold = vk.bloom_threshold, bloom_intensity = vk.bloom_intensity;
    double render_scale = vk.render_scale;
    ae3d_vk_hooks hooks[AE3D_VK_HOOKS];
    int hook_count = vk.hook_count;
    VkPhysicalDeviceProperties properties;
    VkQueueFamilyProperties *families;
    unsigned family_count = 0;

    if (vk.ready) return ae3d_vk_fail("the backend already has a device");
    if (!gipa || !instance || !physical || !device) return ae3d_vk_fail("no device to adopt");
    memcpy(hooks, vk.hooks, sizeof(hooks));
    memset(&vk, 0, sizeof(vk));
    memcpy(vk.hooks, hooks, sizeof(hooks));
    vk.hook_count = hook_count;
    vk.shadow_enabled = shadows;
    vk.render_scale = render_scale;
    vk.fxaa = fxaa;
    vk.bloom = bloom;
    vk.bloom_threshold = bloom_threshold;
    vk.bloom_intensity = bloom_intensity;

    g_gipa = (PFN_vkGetInstanceProcAddr)gipa;
    vk.instance = (VkInstance)instance;
    vk.surface = (VkSurfaceKHR)surface;
    vk.offscreen = surface == NULL;
    vk.physical = (VkPhysicalDevice)physical;
    vk.device = (VkDevice)device;
    vk.graphics_family = (unsigned)graphics_family;
    vk.present_family = (unsigned)present_family;
    vk.ray_query = ray_query ? 1 : 0;
    vk.dlss_loaded = dlss_loaded ? 1 : 0;
    if (!ae3d_vk_load_instance() || !ae3d_vk_load_device()) {
        vk.device = VK_NULL_HANDLE;
        return 0;
    }

    ae3d_vkGetPhysicalDeviceProperties(vk.physical, &properties);
    vk.timestamp_ms = (double)properties.limits.timestampPeriod / 1000000.0;
    vk.max_image_2d = properties.limits.maxImageDimension2D;
    ae3d_vkGetPhysicalDeviceMemoryProperties(vk.physical, &vk.memory_properties);
    ae3d_vkGetPhysicalDeviceQueueFamilyProperties(vk.physical, &family_count, NULL);
    families = family_count ? (VkQueueFamilyProperties *)calloc(family_count, sizeof(VkQueueFamilyProperties)) : NULL;
    if (families) {
        ae3d_vkGetPhysicalDeviceQueueFamilyProperties(vk.physical, &family_count, families);
        if (vk.graphics_family < family_count) {
            vk.timestamps_usable = families[vk.graphics_family].timestampValidBits > 0;
        }
        free(families);
    }
    ae3d_vkGetDeviceQueue(vk.device, vk.graphics_family, 0, &vk.graphics_queue);
    ae3d_vkGetDeviceQueue(vk.device, vk.present_family, 0, &vk.present_queue);
    return 1;
}

static int ae3d_vk_memory_type(unsigned bits, VkMemoryPropertyFlags wanted) {
    unsigned i;
    for (i = 0; i < vk.memory_properties.memoryTypeCount; i++) {
        if ((bits & (1u << i)) &&
            (vk.memory_properties.memoryTypes[i].propertyFlags & wanted) == wanted) {
            return (int)i;
        }
    }
    return -1;
}

static int ae3d_vk_create_buffer(VkDeviceSize size, VkBufferUsageFlags usage,
                                 VkMemoryPropertyFlags properties,
                                 VkBuffer *buffer, VkDeviceMemory *memory) {
    VkBufferCreateInfo info;
    VkMemoryRequirements requirements;
    VkMemoryAllocateInfo allocation;
    VkMemoryAllocateFlagsInfo address_flags;
    int type;
    VkResult result;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    info.size = size;
    info.usage = usage;
    info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

    result = ae3d_vkCreateBuffer(vk.device, &info, NULL, buffer);
    if (result != VK_SUCCESS) return ae3d_vk_fail_code("vkCreateBuffer failed", result);

    ae3d_vkGetBufferMemoryRequirements(vk.device, *buffer, &requirements);
    type = ae3d_vk_memory_type(requirements.memoryTypeBits, properties);
    if (type < 0) {
        ae3d_vkDestroyBuffer(vk.device, *buffer, NULL);
        *buffer = VK_NULL_HANDLE;
        return ae3d_vk_fail("no compatible memory type");
    }

    memset(&allocation, 0, sizeof(allocation));
    allocation.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocation.allocationSize = requirements.size;
    allocation.memoryTypeIndex = (unsigned)type;
    /* A buffer the rays address by its device address needs its memory
       allocated for that. */
    memset(&address_flags, 0, sizeof(address_flags));
    address_flags.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
    address_flags.flags = VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;
    if (usage & VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT) allocation.pNext = &address_flags;

    result = ae3d_vkAllocateMemory(vk.device, &allocation, NULL, memory);
    if (result != VK_SUCCESS) {
        ae3d_vkDestroyBuffer(vk.device, *buffer, NULL);
        *buffer = VK_NULL_HANDLE;
        return ae3d_vk_fail_code("vkAllocateMemory failed", result);
    }
    ae3d_vkBindBufferMemory(vk.device, *buffer, *memory, 0);
    return 1;
}

/* The batch's command buffer, begun the first time something is recorded
   into it. */
static VkCommandBuffer ae3d_vk_batch_command(void) {
    VkCommandBufferAllocateInfo allocation;
    VkCommandBufferBeginInfo begin;
    if (vk.batch) return vk.batch;
    memset(&allocation, 0, sizeof(allocation));
    allocation.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    allocation.commandPool = vk.command_pool;
    allocation.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocation.commandBufferCount = 1;
    if (ae3d_vkAllocateCommandBuffers(vk.device, &allocation, &vk.batch) != VK_SUCCESS) {
        vk.batch = VK_NULL_HANDLE;
        return VK_NULL_HANDLE;
    }
    memset(&begin, 0, sizeof(begin));
    begin.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    ae3d_vkBeginCommandBuffer(vk.batch, &begin);
    return vk.batch;
}

/* A buffer the batch reads -- a structure's scratch, ae3d.vkmesh's staging
   -- kept until the batch has run. */
static void ae3d_vk_batch_keep_buffer(VkBuffer buffer, VkDeviceMemory memory) {
    if (vk.batch_kept_count == vk.batch_kept_capacity) {
        int grown = vk.batch_kept_capacity ? vk.batch_kept_capacity * 2 : 64;
        VkBuffer *buffers = (VkBuffer *)realloc(vk.batch_kept, (size_t)grown * sizeof(VkBuffer));
        VkDeviceMemory *memories;
        if (!buffers) return;
        vk.batch_kept = buffers;
        memories = (VkDeviceMemory *)realloc(vk.batch_kept_memory, (size_t)grown * sizeof(VkDeviceMemory));
        if (!memories) return;
        vk.batch_kept_memory = memories;
        vk.batch_kept_capacity = grown;
    }
    vk.batch_kept[vk.batch_kept_count] = buffer;
    vk.batch_kept_memory[vk.batch_kept_count] = memory;
    vk.batch_kept_count++;
}

/* Counts the flushes, for as long as the process runs (a reset of the
   backend does not reset it): staging ae3d.vkmesh took before the last
   one is gone. */
static int g_batch_serial = 0;

/* The batch for ae3d.vkmesh: its command buffer, begun if it was not
   (null when it could not be); a staging buffer to keep until the batch
   has run; and which flush is next, so it knows when what it staged in
   has been freed. */
void *ae3d_vk_batch_commands(void) { return (void *)ae3d_vk_batch_command(); }
void ae3d_vk_batch_keep(void *buffer, void *memory) {
    ae3d_vk_batch_keep_buffer((VkBuffer)buffer, (VkDeviceMemory)memory);
}
int ae3d_vk_batch_serial(void) { return g_batch_serial; }

/* Submit what the batch recorded and wait for it once, then free the
   staging and scratch it kept. Called before a frame is begun and before
   one is submitted (the frame reads what the batch wrote), before a mesh
   is freed (the batch may name its buffers) and at shutdown. Nothing to
   do when nothing was recorded. */
void ae3d_vk_flush_uploads(void) {
    int i;
    if (vk.batch) {
        VkSubmitInfo submit;
        ae3d_vkEndCommandBuffer(vk.batch);
        memset(&submit, 0, sizeof(submit));
        submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submit.commandBufferCount = 1;
        submit.pCommandBuffers = &vk.batch;
        ae3d_vkQueueSubmit(vk.graphics_queue, 1, &submit, VK_NULL_HANDLE);
        ae3d_vkQueueWaitIdle(vk.graphics_queue);
        ae3d_vkFreeCommandBuffers(vk.device, vk.command_pool, 1, &vk.batch);
        vk.batch = VK_NULL_HANDLE;
    }
    /* Staging still mapped is unmapped by freeing it. */
    for (i = 0; i < vk.batch_kept_count; i++) {
        ae3d_vkDestroyBuffer(vk.device, vk.batch_kept[i], NULL);
        ae3d_vkFreeMemory(vk.device, vk.batch_kept_memory[i], NULL);
    }
    vk.batch_kept_count = 0;
    g_batch_serial++;
}

// Uploads through a host-visible staging buffer so the resident copy stays
// device-local: on a discrete GPU that is the difference between reading vertices
// over PCIe every frame and reading them from VRAM.
static int ae3d_vk_upload_buffer(const void *data, VkDeviceSize size,
                                 VkBufferUsageFlags usage,
                                 VkBuffer *buffer, VkDeviceMemory *memory) {
    VkBuffer staging = VK_NULL_HANDLE;
    VkDeviceMemory staging_memory = VK_NULL_HANDLE;
    VkCommandBufferAllocateInfo allocation;
    VkCommandBufferBeginInfo begin;
    VkCommandBuffer command = VK_NULL_HANDLE;
    VkSubmitInfo submit;
    VkBufferCopy region;
    void *mapped = NULL;

    if (!ae3d_vk_create_buffer(size, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                               VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                               &staging, &staging_memory)) {
        return 0;
    }
    if (ae3d_vkMapMemory(vk.device, staging_memory, 0, size, 0, &mapped) != VK_SUCCESS) {
        ae3d_vkDestroyBuffer(vk.device, staging, NULL);
        ae3d_vkFreeMemory(vk.device, staging_memory, NULL);
        return ae3d_vk_fail("vkMapMemory failed");
    }
    memcpy(mapped, data, (size_t)size);
    ae3d_vkUnmapMemory(vk.device, staging_memory);

    if (!ae3d_vk_create_buffer(size, usage | VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                               VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, buffer, memory)) {
        ae3d_vkDestroyBuffer(vk.device, staging, NULL);
        ae3d_vkFreeMemory(vk.device, staging_memory, NULL);
        return 0;
    }

    memset(&allocation, 0, sizeof(allocation));
    allocation.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    allocation.commandPool = vk.command_pool;
    allocation.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocation.commandBufferCount = 1;
    ae3d_vkAllocateCommandBuffers(vk.device, &allocation, &command);

    memset(&begin, 0, sizeof(begin));
    begin.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    ae3d_vkBeginCommandBuffer(command, &begin);

    memset(&region, 0, sizeof(region));
    region.size = size;
    ae3d_vkCmdCopyBuffer(command, staging, *buffer, 1, &region);
    ae3d_vkEndCommandBuffer(command);

    memset(&submit, 0, sizeof(submit));
    submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submit.commandBufferCount = 1;
    submit.pCommandBuffers = &command;
    ae3d_vkQueueSubmit(vk.graphics_queue, 1, &submit, VK_NULL_HANDLE);
    ae3d_vkQueueWaitIdle(vk.graphics_queue);

    ae3d_vkFreeCommandBuffers(vk.device, vk.command_pool, 1, &command);
    ae3d_vkDestroyBuffer(vk.device, staging, NULL);
    ae3d_vkFreeMemory(vk.device, staging_memory, NULL);
    return 1;
}

static int ae3d_vk_create_image(int width, int height, int mip_levels, VkFormat format,
                                VkSampleCountFlagBits samples, VkImageUsageFlags usage,
                                VkImageAspectFlags aspect, VkImageTiling tiling,
                                VkMemoryPropertyFlags properties,
                                VkImage *image, VkDeviceMemory *memory, VkImageView *view);
void ae3d_vk_texture_destroy(int handle);

static void ae3d_vk_destroy_shadow_target(void);
static void ae3d_vk_destroy_camdepth_target(void);
static void ae3d_vk_destroy_dlss_output(void);
static int ae3d_vk_texture_sampler(ae3d_vk_texture *texture);
static void ae3d_vk_rebias_samplers(void);
static int ae3d_vk_create_dlss_output(void);
static int ae3d_vk_run_dlss(int source);
static void ae3d_vk_clip_correct(const double *m, double *c);
static void ae3d_vk_mat4_mul(const double *a, const double *b, double *out);
static int ae3d_vk_mat4_invert(const double *c, double *inv);
static VkPipeline ae3d_vk_pipeline_for(int handle, int points);
static int ae3d_vk_instances_are_points(int instance_handle, int instance_count);

static void ae3d_vk_destroy_swapchain(void) {
    unsigned i;

    for (i = 0; i < (unsigned)vk.hook_count; i++) {
        if (vk.hooks[i].release) vk.hooks[i].release(vk.hooks[i].context);
    }

    if (vk.framebuffers) {
        for (i = 0; i < vk.image_count; i++) {
            if (vk.framebuffers[i]) ae3d_vkDestroyFramebuffer(vk.device, vk.framebuffers[i], NULL);
        }
        free(vk.framebuffers);
        vk.framebuffers = NULL;
    }
    if (vk.image_views) {
        for (i = 0; i < vk.image_count; i++) {
            if (vk.image_views[i]) ae3d_vkDestroyImageView(vk.device, vk.image_views[i], NULL);
        }
        free(vk.image_views);
        vk.image_views = NULL;
    }
    // An offscreen target's image is owned here, unlike a swapchain's, which
    // the swapchain owns and destroys with itself. (The buffers a frame is
    // read back into are ae3d.vkreadback's, released by its hook above.)
    if (vk.offscreen && vk.images && vk.images[0]) {
        ae3d_vkDestroyImage(vk.device, vk.images[0], NULL);
        if (vk.offscreen_memory) {
            ae3d_vkFreeMemory(vk.device, vk.offscreen_memory, NULL);
            vk.offscreen_memory = VK_NULL_HANDLE;
        }
    }
    free(vk.images);
    vk.images = NULL;

    if (vk.post_framebuffers) {
        for (i = 0; i < vk.image_count; i++) {
            if (vk.post_framebuffers[i]) {
                ae3d_vkDestroyFramebuffer(vk.device, vk.post_framebuffers[i], NULL);
            }
        }
        free(vk.post_framebuffers);
        vk.post_framebuffers = NULL;
    }
    ae3d_vk_destroy_shadow_target();
    ae3d_vk_destroy_camdepth_target();
    if (vk.scene_framebuffer) {
        ae3d_vkDestroyFramebuffer(vk.device, vk.scene_framebuffer, NULL);
        vk.scene_framebuffer = VK_NULL_HANDLE;
    }
    if (vk.post_texture) {
        ae3d_vk_texture_destroy(vk.post_texture);
        vk.post_texture = 0;
    }

    if (vk.colour_view) { ae3d_vkDestroyImageView(vk.device, vk.colour_view, NULL); vk.colour_view = VK_NULL_HANDLE; }
    if (vk.colour_image) { ae3d_vkDestroyImage(vk.device, vk.colour_image, NULL); vk.colour_image = VK_NULL_HANDLE; }
    if (vk.colour_memory) { ae3d_vkFreeMemory(vk.device, vk.colour_memory, NULL); vk.colour_memory = VK_NULL_HANDLE; }
    if (vk.velocity_view) { ae3d_vkDestroyImageView(vk.device, vk.velocity_view, NULL); vk.velocity_view = VK_NULL_HANDLE; }
    if (vk.velocity_image) { ae3d_vkDestroyImage(vk.device, vk.velocity_image, NULL); vk.velocity_image = VK_NULL_HANDLE; }
    if (vk.velocity_memory) { ae3d_vkFreeMemory(vk.device, vk.velocity_memory, NULL); vk.velocity_memory = VK_NULL_HANDLE; }
    if (vk.velocity_texture) { ae3d_vk_texture_destroy(vk.velocity_texture); vk.velocity_texture = 0; }
    if (vk.depth_view) { ae3d_vkDestroyImageView(vk.device, vk.depth_view, NULL); vk.depth_view = VK_NULL_HANDLE; }
    if (vk.depth_image) { ae3d_vkDestroyImage(vk.device, vk.depth_image, NULL); vk.depth_image = VK_NULL_HANDLE; }
    if (vk.depth_memory) { ae3d_vkFreeMemory(vk.device, vk.depth_memory, NULL); vk.depth_memory = VK_NULL_HANDLE; }

    if (vk.swapchain && ae3d_vkDestroySwapchainKHR) {
        ae3d_vkDestroySwapchainKHR(vk.device, vk.swapchain, NULL);
        vk.swapchain = VK_NULL_HANDLE;
    }
    vk.image_count = 0;
}

/* The seam the Vulkan backend's move into Aether goes through (#402): an
   Aether module registers what it records into the frame and when, and
   reads the handles it records with. Everything here is the C state's; the
   module owns what it makes with them and frees it in its release. Hooks
   run by their stage -- the meter's reading of the scene (MEASURE), then
   the overlay drawn over it (DRAW), then the readback of what is shown
   (READ) -- and in the order they were added within one; 0 when there is
   no room for another. A hook added without a stage reads. */
int ae3d_vk_add_frame_hooks_at(int stage, void *record, void *collect, void *release, void *context) {
    ae3d_vk_hooks *h;
    int at;
    if (vk.hook_count >= AE3D_VK_HOOKS) return 0;
    at = vk.hook_count;
    while (at > 0 && vk.hooks[at - 1].stage > stage) {
        vk.hooks[at] = vk.hooks[at - 1];
        at--;
    }
    vk.hook_count++;
    h = &vk.hooks[at];
    h->record = (void (*)(void *))record;
    h->collect = (void (*)(void *))collect;
    h->release = (void (*)(void *))release;
    h->context = context;
    h->stage = stage;
    return 1;
}

int ae3d_vk_add_frame_hooks(void *record, void *collect, void *release, void *context) {
    return ae3d_vk_add_frame_hooks_at(AE3D_VK_STAGE_READ, record, collect, release, context);
}

/* Whether the backend is up, and a frame slot's last submission waited
   for: what a module that reads a frame back waits on before it reads. */
int ae3d_vk_ready(void) { return vk.ready ? 1 : 0; }
void ae3d_vk_frame_wait(int slot) {
    if (!vk.ready || slot < 0 || slot >= AE3D_VK_FRAMES) return;
    ae3d_vkWaitForFences(vk.device, 1, &vk.in_flight[slot], VK_TRUE, UINT64_MAX);
}
/* Whether the frame's image holds blue before red (a BGRA swapchain). */
int ae3d_vk_frame_bgr(void) {
    return (vk.color_format == VK_FORMAT_B8G8R8A8_UNORM || vk.color_format == VK_FORMAT_B8G8R8A8_SRGB) ? 1 : 0;
}

/* The frame being recorded: its command buffer, its slot among the frames
   in flight, how many there are, and the image it finishes in -- the
   offscreen target, or the swapchain image it acquired. */
void *ae3d_vk_frame_commands(void) { return (void *)vk.command_buffers[vk.frame]; }
int ae3d_vk_frame_slot(void) { return (int)vk.frame; }
int ae3d_vk_frames_in_flight(void) { return AE3D_VK_FRAMES; }
void *ae3d_vk_frame_image(void) {
    if (!vk.images) return NULL;
    return (void *)(vk.offscreen ? vk.images[0] : vk.images[vk.image_index]);
}
/* Its view and format, for a hook that draws into it (ae3d.vkoverlay):
   the image is in the layout the last pass left it -- presenting, or
   transfer-source offscreen -- and a pass of the hook's own loads it. */
void *ae3d_vk_frame_view(void) {
    if (!vk.image_views) return NULL;
    return (void *)(vk.offscreen ? vk.image_views[0] : vk.image_views[vk.image_index]);
}
int ae3d_vk_frame_format(void) { return (int)vk.color_format; }
/* (Its size: ae3d_vk_frame_width and _height, below.) Whether the frame's
   image can be copied from: an offscreen target always
   is; a swapchain's only when its usage allowed it. A windowed frame's
   image is presenting when the hooks see it, and goes back to presenting. */
int ae3d_vk_frame_offscreen(void) { return vk.offscreen ? 1 : 0; }
int ae3d_vk_frame_copyable(void) { return (vk.offscreen || vk.can_capture) ? 1 : 0; }

static int ae3d_vk_choose_surface_format(void) {
    VkSurfaceFormatKHR *formats;
    if (vk.offscreen) {
        vk.color_format = VK_FORMAT_R8G8B8A8_UNORM;
        vk.color_space = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;
        vk.present_mode = VK_PRESENT_MODE_FIFO_KHR;
        vk.depth_format = VK_FORMAT_D32_SFLOAT;
        return 1;
    }
    {
    VkPresentModeKHR *modes;
    unsigned count = 0, i;

    ae3d_vkGetPhysicalDeviceSurfaceFormatsKHR(vk.physical, vk.surface, &count, NULL);
    if (count == 0) return ae3d_vk_fail("surface reports no formats");
    formats = (VkSurfaceFormatKHR *)calloc(count, sizeof(VkSurfaceFormatKHR));
    if (!formats) return ae3d_vk_fail("out of memory");
    ae3d_vkGetPhysicalDeviceSurfaceFormatsKHR(vk.physical, vk.surface, &count, formats);

    vk.color_format = formats[0].format;
    vk.color_space = formats[0].colorSpace;
    for (i = 0; i < count; i++) {
        if (formats[i].format == VK_FORMAT_B8G8R8A8_UNORM &&
            formats[i].colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            vk.color_format = formats[i].format;
            vk.color_space = formats[i].colorSpace;
            break;
        }
    }
    free(formats);

    count = 0;
    vk.present_mode = VK_PRESENT_MODE_FIFO_KHR;
    ae3d_vkGetPhysicalDeviceSurfacePresentModesKHR(vk.physical, vk.surface, &count, NULL);
    if (count > 0) {
        modes = (VkPresentModeKHR *)calloc(count, sizeof(VkPresentModeKHR));
        if (modes) {
            ae3d_vkGetPhysicalDeviceSurfacePresentModesKHR(vk.physical, vk.surface, &count, modes);
            free(modes);
        }
    }

    vk.depth_format = VK_FORMAT_D32_SFLOAT;
    }
    return 1;
}

/* The motion-vector target beside the depth: the multisampled image the
   scene draws into when the frame is multisampled, and the resolved one as
   a texture, point sampled -- a vector is not blended between pixels. */
static int ae3d_vk_create_velocity(void) {
    ae3d_vk_texture *texture = NULL;
    VkSamplerCreateInfo sampler;
    int slot;

    vk.velocity_format = VK_FORMAT_R16G16_SFLOAT;
    if (vk.samples != VK_SAMPLE_COUNT_1_BIT) {
        if (!ae3d_vk_create_image((int)vk.render_extent.width, (int)vk.render_extent.height, 1, vk.velocity_format,
                                  vk.samples, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT |
                                  VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT,
                                  VK_IMAGE_ASPECT_COLOR_BIT, VK_IMAGE_TILING_OPTIMAL,
                                  VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                                  &vk.velocity_image, &vk.velocity_memory, &vk.velocity_view)) {
            return 0;
        }
    }
    for (slot = 0; slot < AE3D_VK_MAX_TEXTURES; slot++) {
        if (!vk.textures[slot].in_use) { texture = &vk.textures[slot]; break; }
    }
    if (!texture) return ae3d_vk_fail("texture table full");
    if (!ae3d_vk_create_image((int)vk.render_extent.width, (int)vk.render_extent.height, 1, vk.velocity_format,
                              VK_SAMPLE_COUNT_1_BIT,
                              VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
                              VK_IMAGE_ASPECT_COLOR_BIT, VK_IMAGE_TILING_OPTIMAL,
                              VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                              &texture->image, &texture->memory, &texture->view)) {
        return 0;
    }
    memset(&sampler, 0, sizeof(sampler));
    sampler.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    sampler.magFilter = VK_FILTER_NEAREST;
    sampler.minFilter = VK_FILTER_NEAREST;
    sampler.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
    sampler.maxLod = 1.0f;
    if (ae3d_vkCreateSampler(vk.device, &sampler, NULL, &texture->sampler) != VK_SUCCESS) {
        return ae3d_vk_fail("velocity vkCreateSampler failed");
    }
    texture->width = (int)vk.render_extent.width;
    texture->height = (int)vk.render_extent.height;
    texture->in_use = 1;
    vk.velocity_texture = slot + 1;
    return 1;
}

/* The resolved motion vectors of the last frame drawn, as a texture handle;
   0 before the first frame. What the temporal passes and an upscaler read. */
int ae3d_vk_velocity_texture(void) { return vk.velocity_texture; }

static int ae3d_vk_create_depth(void) {
    VkImageCreateInfo image;
    VkMemoryRequirements requirements;
    VkMemoryAllocateInfo allocation;
    VkImageViewCreateInfo view;
    int type;
    VkResult result;

    memset(&image, 0, sizeof(image));
    image.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    image.imageType = VK_IMAGE_TYPE_2D;
    image.format = vk.depth_format;
    image.extent.width = vk.render_extent.width;
    image.extent.height = vk.render_extent.height;
    image.extent.depth = 1;
    image.mipLevels = 1;
    image.arrayLayers = 1;
    image.samples = vk.samples;
    image.tiling = VK_IMAGE_TILING_OPTIMAL;
    /* Sampled as well: the depth resolve reads it after the opaque draws. */
    image.usage = VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;
    image.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    image.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

    result = ae3d_vkCreateImage(vk.device, &image, NULL, &vk.depth_image);
    if (result != VK_SUCCESS) return ae3d_vk_fail_code("depth vkCreateImage failed", result);

    ae3d_vkGetImageMemoryRequirements(vk.device, vk.depth_image, &requirements);
    type = ae3d_vk_memory_type(requirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    if (type < 0) return ae3d_vk_fail("no device-local memory for the depth buffer");

    memset(&allocation, 0, sizeof(allocation));
    allocation.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocation.allocationSize = requirements.size;
    allocation.memoryTypeIndex = (unsigned)type;
    result = ae3d_vkAllocateMemory(vk.device, &allocation, NULL, &vk.depth_memory);
    if (result != VK_SUCCESS) return ae3d_vk_fail_code("depth vkAllocateMemory failed", result);
    ae3d_vkBindImageMemory(vk.device, vk.depth_image, vk.depth_memory, 0);

    memset(&view, 0, sizeof(view));
    view.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    view.image = vk.depth_image;
    view.viewType = VK_IMAGE_VIEW_TYPE_2D;
    view.format = vk.depth_format;
    view.subresourceRange.aspectMask = VK_IMAGE_ASPECT_DEPTH_BIT;
    view.subresourceRange.levelCount = 1;
    view.subresourceRange.layerCount = 1;
    result = ae3d_vkCreateImageView(vk.device, &view, NULL, &vk.depth_view);
    if (result != VK_SUCCESS) return ae3d_vk_fail_code("depth vkCreateImageView failed", result);
    return ae3d_vk_create_velocity();
}

// The offscreen equivalent of a swapchain: one image the pass resolves into,
// which is then copied to a host-visible buffer for the caller to read.
/* The scene's own extent: the frame's times the render scale, never less
   than a pixel. Set whenever the frame's is. */
static void ae3d_vk_scale_extent(void) {
    double scale = vk.render_scale > 0.0 && vk.render_scale < 1.0 ? vk.render_scale : 1.0;
    vk.render_extent.width = (unsigned)((double)vk.extent.width * scale + 0.5);
    vk.render_extent.height = (unsigned)((double)vk.extent.height * scale + 0.5);
    if (vk.render_extent.width < 1) vk.render_extent.width = 1;
    if (vk.render_extent.height < 1) vk.render_extent.height = 1;
}

/* The scene is drawn smaller than the frame: the post chain is then what
   scales it up, so it runs whether or not an effect asked for it. */
static int ae3d_vk_scaled(void) {
    return vk.render_extent.width != vk.extent.width || vk.render_extent.height != vk.extent.height;
}

static int ae3d_vk_create_offscreen_target(int width, int height) {
    if (width < 1) width = 1;
    if (height < 1) height = 1;
    vk.extent.width = (unsigned)width;
    vk.extent.height = (unsigned)height;
    ae3d_vk_scale_extent();

    vk.image_count = 1;
    vk.images = (VkImage *)calloc(1, sizeof(VkImage));
    vk.image_views = (VkImageView *)calloc(1, sizeof(VkImageView));
    if (!vk.images || !vk.image_views) return ae3d_vk_fail("out of memory");

    if (!ae3d_vk_create_image(width, height, 1, vk.color_format, VK_SAMPLE_COUNT_1_BIT,
                              VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
                              VK_IMAGE_ASPECT_COLOR_BIT, VK_IMAGE_TILING_OPTIMAL,
                              VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                              &vk.images[0], &vk.offscreen_memory, &vk.image_views[0])) {
        return 0;
    }

    if (vk.samples != VK_SAMPLE_COUNT_1_BIT) {
        if (!ae3d_vk_create_image((int)vk.render_extent.width, (int)vk.render_extent.height, 1,
                                  vk.color_format, vk.samples,
                                  VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
                                  VK_IMAGE_ASPECT_COLOR_BIT, VK_IMAGE_TILING_OPTIMAL,
                                  VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                                  &vk.colour_image, &vk.colour_memory, &vk.colour_view)) {
            return 0;
        }
    }
    return ae3d_vk_create_depth();
}

static int ae3d_vk_create_swapchain(int width, int height) {
    VkSurfaceCapabilitiesKHR capabilities;
    VkSwapchainCreateInfoKHR info;
    unsigned queue_families[2];
    unsigned desired;
    unsigned i;
    VkResult result;

    ae3d_vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vk.physical, vk.surface, &capabilities);

    if (capabilities.currentExtent.width != 0xFFFFFFFFu) {
        vk.extent = capabilities.currentExtent;
    } else {
        vk.extent.width = (unsigned)width;
        vk.extent.height = (unsigned)height;
        if (vk.extent.width < capabilities.minImageExtent.width) vk.extent.width = capabilities.minImageExtent.width;
        if (vk.extent.height < capabilities.minImageExtent.height) vk.extent.height = capabilities.minImageExtent.height;
        if (vk.extent.width > capabilities.maxImageExtent.width) vk.extent.width = capabilities.maxImageExtent.width;
        if (vk.extent.height > capabilities.maxImageExtent.height) vk.extent.height = capabilities.maxImageExtent.height;
    }
    if (vk.extent.width == 0 || vk.extent.height == 0) return ae3d_vk_fail("surface has zero extent");
    ae3d_vk_scale_extent();

    desired = capabilities.minImageCount + 1;
    if (capabilities.maxImageCount > 0 && desired > capabilities.maxImageCount) {
        desired = capabilities.maxImageCount;
    }

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    info.surface = vk.surface;
    info.minImageCount = desired;
    info.imageFormat = vk.color_format;
    info.imageColorSpace = vk.color_space;
    info.imageExtent = vk.extent;
    info.imageArrayLayers = 1;
    info.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    // Reading a finished frame back -- for a snapshot, or for the agent to see
    // what it drew -- means copying the swapchain image, which needs it to be a
    // transfer source. Nearly every surface allows it; where one does not the
    // capture path stays off rather than failing to create the swapchain.
    vk.can_capture = (capabilities.supportedUsageFlags
                      & VK_IMAGE_USAGE_TRANSFER_SRC_BIT) ? 1 : 0;
    if (vk.can_capture) info.imageUsage |= VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
    info.preTransform = capabilities.currentTransform;
    info.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    info.presentMode = vk.present_mode;
    info.clipped = VK_TRUE;

    if (vk.graphics_family != vk.present_family) {
        queue_families[0] = vk.graphics_family;
        queue_families[1] = vk.present_family;
        info.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
        info.queueFamilyIndexCount = 2;
        info.pQueueFamilyIndices = queue_families;
    } else {
        info.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    }

    result = ae3d_vkCreateSwapchainKHR(vk.device, &info, NULL, &vk.swapchain);
    if (result != VK_SUCCESS) return ae3d_vk_fail_code("vkCreateSwapchainKHR failed", result);

    ae3d_vkGetSwapchainImagesKHR(vk.device, vk.swapchain, &vk.image_count, NULL);
    vk.images = (VkImage *)calloc(vk.image_count, sizeof(VkImage));
    vk.image_views = (VkImageView *)calloc(vk.image_count, sizeof(VkImageView));
    if (!vk.images || !vk.image_views) return ae3d_vk_fail("out of memory");
    ae3d_vkGetSwapchainImagesKHR(vk.device, vk.swapchain, &vk.image_count, vk.images);

    for (i = 0; i < vk.image_count; i++) {
        VkImageViewCreateInfo view;
        memset(&view, 0, sizeof(view));
        view.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        view.image = vk.images[i];
        view.viewType = VK_IMAGE_VIEW_TYPE_2D;
        view.format = vk.color_format;
        view.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        view.subresourceRange.levelCount = 1;
        view.subresourceRange.layerCount = 1;
        result = ae3d_vkCreateImageView(vk.device, &view, NULL, &vk.image_views[i]);
        if (result != VK_SUCCESS) return ae3d_vk_fail_code("vkCreateImageView failed", result);
    }

    if (vk.samples != VK_SAMPLE_COUNT_1_BIT) {
        if (!ae3d_vk_create_image((int)vk.render_extent.width, (int)vk.render_extent.height, 1, vk.color_format,
                                  vk.samples, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT |
                                  VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT,
                                  VK_IMAGE_ASPECT_COLOR_BIT, VK_IMAGE_TILING_OPTIMAL,
                                  VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                                  &vk.colour_image, &vk.colour_memory, &vk.colour_view)) {
            return 0;
        }
    }
    return ae3d_vk_create_depth();
}

/* `part`: 0 the whole scene in one pass; 1 its first half, which keeps its
   colour and depth and ends with the depth readable by a shader; 2 the rest,
   which loads both and finishes the frame. */
static int ae3d_vk_build_render_pass(VkImageLayout present_layout, int part, VkRenderPass *out) {
    VkAttachmentDescription attachments[5];
    VkAttachmentReference colour_refs[2], depth_ref, resolve_refs[2];
    VkSubpassDescription subpass;
    VkSubpassDependency dependencies[2];
    VkRenderPassCreateInfo info;
    int multisampled = vk.samples != VK_SAMPLE_COUNT_1_BIT;
    unsigned count = multisampled ? 5u : 3u;

    memset(attachments, 0, sizeof(attachments));

    // Attachment 0 is what the subpass draws into: the multisampled image when
    // MSAA is on, otherwise the presentable image itself.
    attachments[0].format = vk.color_format;
    attachments[0].samples = vk.samples;
    attachments[0].loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    attachments[0].storeOp = multisampled ? VK_ATTACHMENT_STORE_OP_DONT_CARE
                                          : VK_ATTACHMENT_STORE_OP_STORE;
    attachments[0].stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachments[0].stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachments[0].initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    attachments[0].finalLayout = multisampled ? VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
                                              : present_layout;

    attachments[1].format = vk.depth_format;
    attachments[1].samples = vk.samples;
    attachments[1].loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    attachments[1].storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachments[1].stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachments[1].stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachments[1].initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    attachments[1].finalLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

    // Attachment 2 is the motion vectors, drawn beside the colour: the
    // multisampled image when MSAA is on, otherwise the texture itself, which
    // the temporal passes sample when the pass is done.
    attachments[2].format = vk.velocity_format;
    attachments[2].samples = vk.samples;
    attachments[2].loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    attachments[2].storeOp = multisampled ? VK_ATTACHMENT_STORE_OP_DONT_CARE
                                          : VK_ATTACHMENT_STORE_OP_STORE;
    attachments[2].stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachments[2].stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachments[2].initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    attachments[2].finalLayout = multisampled ? VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
                                              : VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

    // 3 and 4, when MSAA is on: what the colour and the vectors resolve to.
    attachments[3].format = vk.color_format;
    attachments[3].samples = VK_SAMPLE_COUNT_1_BIT;
    attachments[3].loadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachments[3].storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    attachments[3].stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachments[3].stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachments[3].initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    attachments[3].finalLayout = present_layout;

    attachments[4].format = vk.velocity_format;
    attachments[4].samples = VK_SAMPLE_COUNT_1_BIT;
    attachments[4].loadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachments[4].storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    attachments[4].stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachments[4].stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachments[4].initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    attachments[4].finalLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

    memset(colour_refs, 0, sizeof(colour_refs));
    colour_refs[0].attachment = 0;
    colour_refs[0].layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
    colour_refs[1].attachment = 2;
    colour_refs[1].layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    memset(&depth_ref, 0, sizeof(depth_ref));
    depth_ref.attachment = 1;
    depth_ref.layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

    memset(resolve_refs, 0, sizeof(resolve_refs));
    resolve_refs[0].attachment = 3;
    resolve_refs[0].layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
    resolve_refs[1].attachment = 4;
    resolve_refs[1].layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    if (part == 1) {
        /* The first half keeps what it drew for the second: the colour and
           the vectors stay in their attachment layout, the depth ends
           readable. The multisampled images are not resolved yet; the
           second half does that once, at the end. */
        attachments[0].storeOp = VK_ATTACHMENT_STORE_OP_STORE;
        attachments[0].finalLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        attachments[1].storeOp = VK_ATTACHMENT_STORE_OP_STORE;
        attachments[1].finalLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL;
        attachments[2].storeOp = VK_ATTACHMENT_STORE_OP_STORE;
        attachments[2].finalLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        attachments[3].storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
        attachments[3].finalLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        attachments[4].storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
        attachments[4].finalLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        resolve_refs[0].attachment = VK_ATTACHMENT_UNUSED;
        resolve_refs[1].attachment = VK_ATTACHMENT_UNUSED;
    } else if (part == 2) {
        attachments[0].loadOp = VK_ATTACHMENT_LOAD_OP_LOAD;
        attachments[0].initialLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        attachments[1].loadOp = VK_ATTACHMENT_LOAD_OP_LOAD;
        attachments[1].initialLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL;
        attachments[2].loadOp = VK_ATTACHMENT_LOAD_OP_LOAD;
        attachments[2].initialLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
    }

    memset(&subpass, 0, sizeof(subpass));
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 2;
    subpass.pColorAttachments = colour_refs;
    subpass.pDepthStencilAttachment = &depth_ref;
    if (multisampled) subpass.pResolveAttachments = resolve_refs;

    memset(dependencies, 0, sizeof(dependencies));
    dependencies[0].srcSubpass = VK_SUBPASS_EXTERNAL;
    dependencies[0].dstSubpass = 0;
    dependencies[0].srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT |
                                   VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
    dependencies[0].dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT |
                                   VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
    dependencies[0].dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT |
                                    VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
    /* The same dependencies for all three passes, whole and halves: the
       pipelines are made against the whole pass and draw in the halves too,
       and passes that differ in their dependencies are not compatible (the
       validation layer counted thousands of draws against it, #405). What
       the second half needs -- after the resolve read the depth and the
       first half wrote both -- is waited for in the whole pass as well,
       which costs it nothing it would notice. */
    dependencies[0].srcStageMask |= VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT |
                                    VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT;
    dependencies[0].srcAccessMask = VK_ACCESS_SHADER_READ_BIT |
                                    VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT |
                                    VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
    dependencies[0].dstAccessMask |= VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                                     VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT;
    /* The first half's depth, written here, is read by the resolve's shader
       (and, the dependencies being the same in all three, the others').
       With no post chain this pass is the frame's last, and what it leaves
       in the frame's image -- the colour and its final transition -- is
       copied out by the readback (ae3d.vkreadback): a transfer read, which
       has to wait for them as the shader's reads do, or the copy races the
       pass that wrote the frame (#458). */
    dependencies[1].srcSubpass = 0;
    dependencies[1].dstSubpass = VK_SUBPASS_EXTERNAL;
    dependencies[1].srcStageMask = VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT |
                                   VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependencies[1].srcAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT |
                                    VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
    dependencies[1].dstStageMask = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT |
                                   VK_PIPELINE_STAGE_TRANSFER_BIT;
    dependencies[1].dstAccessMask = VK_ACCESS_SHADER_READ_BIT |
                                    VK_ACCESS_TRANSFER_READ_BIT;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    info.attachmentCount = count;
    info.pAttachments = attachments;
    info.subpassCount = 1;
    info.pSubpasses = &subpass;
    info.dependencyCount = 2;
    info.pDependencies = dependencies;

    if (ae3d_vkCreateRenderPass(vk.device, &info, NULL, out) != VK_SUCCESS) {
        return ae3d_vk_fail("vkCreateRenderPass failed");
    }
    return 1;
}

// Depth written as colour, so the main pass samples it like any other texture.
// The attachment ends in shader-read layout, which is what lets the very next
// pass in the same submission read it without a barrier of its own.
/* A depth-only pass's dependencies. In: its clear and the layout transition
   from UNDEFINED wait for the previous frame's sampling of the image and its
   last depth write, which on one queue are otherwise unordered against them
   (#410). Out: the depth written here is read by a fragment shader after. */
static void ae3d_vk_depth_pass_dependencies(VkSubpassDependency *dependencies) {
    memset(dependencies, 0, 2 * sizeof(VkSubpassDependency));
    dependencies[0].srcSubpass = VK_SUBPASS_EXTERNAL;
    dependencies[0].dstSubpass = 0;
    dependencies[0].srcStageMask = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT |
                                   VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT;
    dependencies[0].srcAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
    dependencies[0].dstStageMask = VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT |
                                   VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT;
    dependencies[0].dstAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT |
                                    VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
    dependencies[1].srcSubpass = 0;
    dependencies[1].dstSubpass = VK_SUBPASS_EXTERNAL;
    dependencies[1].srcStageMask = VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT;
    dependencies[1].srcAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
    dependencies[1].dstStageMask = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
    dependencies[1].dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
}

static int ae3d_vk_build_shadow_pass(void) {
    VkAttachmentDescription attachments[2];
    VkAttachmentReference colour_ref, depth_ref;
    VkSubpassDescription subpass;
    VkSubpassDependency dependencies[2];
    VkRenderPassCreateInfo info;

    // Depth, and nothing else. The pass used to write gl_FragCoord.z into an
    // R32_SFLOAT colour attachment beside a depth attachment holding that same
    // number, and then throw the depth away: every shadow texel written twice
    // and one of the two read. The depth image is what is sampled now.
    memset(attachments, 0, sizeof(attachments));
    attachments[0].format = vk.depth_format;
    attachments[0].samples = VK_SAMPLE_COUNT_1_BIT;
    attachments[0].loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    attachments[0].storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    attachments[0].stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachments[0].stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachments[0].initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    // Left in the layout the descriptor asks for. Binding 2 holds the default
    // white texture when shadows are off, so both the shadow map and that
    // colour image have to be readable through the same declared layout.
    attachments[0].finalLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

    memset(&colour_ref, 0, sizeof(colour_ref));

    memset(&depth_ref, 0, sizeof(depth_ref));
    depth_ref.attachment = 0;
    depth_ref.layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

    memset(&subpass, 0, sizeof(subpass));
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 0;
    subpass.pDepthStencilAttachment = &depth_ref;

    // The write to wait on is the depth store, not a colour one.
    ae3d_vk_depth_pass_dependencies(dependencies);

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    info.attachmentCount = 1;
    info.pAttachments = attachments;
    info.subpassCount = 1;
    info.pSubpasses = &subpass;
    info.dependencyCount = 2;
    info.pDependencies = dependencies;

    if (ae3d_vkCreateRenderPass(vk.device, &info, NULL, &vk.shadow_pass) != VK_SUCCESS) {
        return ae3d_vk_fail("shadow vkCreateRenderPass failed");
    }
    return 1;
}

/* The lamps' atlas pass: the shadow pass's depth attachment, but loaded
   rather than cleared -- the tiles not drawn this frame keep what they
   hold -- and readable on the way in as on the way out. Compatible with the
   shadow pass, so the shadow pipelines draw in both. */
static int ae3d_vk_build_lamp_pass(void) {
    VkAttachmentDescription attachment;
    VkAttachmentReference depth_ref;
    VkSubpassDescription subpass;
    VkSubpassDependency dependencies[2];
    VkRenderPassCreateInfo info;

    memset(&attachment, 0, sizeof(attachment));
    attachment.format = vk.depth_format;
    attachment.samples = VK_SAMPLE_COUNT_1_BIT;
    attachment.loadOp = VK_ATTACHMENT_LOAD_OP_LOAD;
    attachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    attachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachment.initialLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    attachment.finalLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

    memset(&depth_ref, 0, sizeof(depth_ref));
    depth_ref.attachment = 0;
    depth_ref.layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

    memset(&subpass, 0, sizeof(subpass));
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.pDepthStencilAttachment = &depth_ref;

    ae3d_vk_depth_pass_dependencies(dependencies);

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    info.attachmentCount = 1;
    info.pAttachments = &attachment;
    info.subpassCount = 1;
    info.pSubpasses = &subpass;
    info.dependencyCount = 2;
    info.pDependencies = dependencies;
    if (ae3d_vkCreateRenderPass(vk.device, &info, NULL, &vk.lamp_pass) != VK_SUCCESS) {
        return ae3d_vk_fail("lamp shadow vkCreateRenderPass failed");
    }
    return 1;
}

// The camera-space depth prepass, for screen-space reflection. The same
// depth-only pass the shadow map uses -- a single-sample depth attachment
// cleared, stored, and left readable -- but rendered from the camera rather
// than the light, so the SSR post pass can sample the scene's own depth.
static int ae3d_vk_build_camdepth_pass(void) {
    VkAttachmentDescription attachment;
    VkAttachmentReference depth_ref;
    VkSubpassDescription subpass;
    VkSubpassDependency dependencies[2];
    VkRenderPassCreateInfo info;

    memset(&attachment, 0, sizeof(attachment));
    attachment.format = vk.depth_format;
    attachment.samples = VK_SAMPLE_COUNT_1_BIT;
    attachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    attachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    attachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    attachment.finalLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

    memset(&depth_ref, 0, sizeof(depth_ref));
    depth_ref.attachment = 0;
    depth_ref.layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

    memset(&subpass, 0, sizeof(subpass));
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 0;
    subpass.pDepthStencilAttachment = &depth_ref;

    ae3d_vk_depth_pass_dependencies(dependencies);

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    info.attachmentCount = 1;
    info.pAttachments = &attachment;
    info.subpassCount = 1;
    info.pSubpasses = &subpass;
    info.dependencyCount = 2;
    info.pDependencies = dependencies;

    if (ae3d_vkCreateRenderPass(vk.device, &info, NULL, &vk.camdepth_pass) != VK_SUCCESS) {
        return ae3d_vk_fail("camera-depth vkCreateRenderPass failed");
    }
    return 1;
}

static void ae3d_vk_destroy_camdepth_target(void) {
    int frame, index;
    /* Sets that bound the depth at binding 4 name a view about to go. */
    for (frame = 0; frame < AE3D_VK_FRAMES; frame++) {
        for (index = 0; index < vk.set_count[frame]; index++) {
            if (vk.set_bank[frame][index] == AE3D_VK_AUX_SCENE_DEPTH) {
                vk.set_texture[frame][index] = AE3D_VK_SET_FREE;
            }
        }
    }
    if (vk.camdepth_framebuffer) {
        ae3d_vkDestroyFramebuffer(vk.device, vk.camdepth_framebuffer, NULL);
        vk.camdepth_framebuffer = VK_NULL_HANDLE;
    }
    if (vk.camdepth_sampler) {
        ae3d_vkDestroySampler(vk.device, vk.camdepth_sampler, NULL);
        vk.camdepth_sampler = VK_NULL_HANDLE;
    }
    if (vk.camdepth_view) {
        ae3d_vkDestroyImageView(vk.device, vk.camdepth_view, NULL);
        vk.camdepth_view = VK_NULL_HANDLE;
    }
    if (vk.camdepth_image) {
        ae3d_vkDestroyImage(vk.device, vk.camdepth_image, NULL);
        vk.camdepth_image = VK_NULL_HANDLE;
    }
    if (vk.camdepth_memory) {
        ae3d_vkFreeMemory(vk.device, vk.camdepth_memory, NULL);
        vk.camdepth_memory = VK_NULL_HANDLE;
    }
    vk.camdepth_width = 0;
    vk.camdepth_height = 0;
    if (vk.ssr_framebuffer) {
        ae3d_vkDestroyFramebuffer(vk.device, vk.ssr_framebuffer, NULL);
        vk.ssr_framebuffer = VK_NULL_HANDLE;
    }
    if (vk.ssr_reflect_texture) {
        ae3d_vk_texture_destroy(vk.ssr_reflect_texture);
        vk.ssr_reflect_texture = 0;
    }
    {
        int k, f;
        for (k = 0; k < 2; k++) {
            if (vk.taa_framebuffer[k]) {
                ae3d_vkDestroyFramebuffer(vk.device, vk.taa_framebuffer[k], NULL);
                vk.taa_framebuffer[k] = VK_NULL_HANDLE;
            }
            if (vk.taa_texture[k]) {
                ae3d_vk_texture_destroy(vk.taa_texture[k]);
                vk.taa_texture[k] = 0;
            }
            for (f = 0; f < AE3D_VK_FRAMES; f++) vk.taa_set[k][f] = VK_NULL_HANDLE;
        }
        vk.taa_history_valid = 0;
    }
    // The SSR sets sample this target; force them to be reallocated and
    // rewritten against the new one when SSR is next drawn.
    {
        int f;
        for (f = 0; f < AE3D_VK_FRAMES; f++) {
            vk.ssr_set[f] = VK_NULL_HANDLE; vk.ssao_set[f] = VK_NULL_HANDLE;
            vk.depth_resolve_set[f] = VK_NULL_HANDLE;
        }
    }
}

// Built at the swapchain's size, the first time SSR is turned on and again
// whenever the swapchain is remade at a new size.
static int ae3d_vk_create_camdepth_target(int width, int height) {
    VkSamplerCreateInfo sampler;
    VkImageView attachments[1];
    VkFramebufferCreateInfo info;

    if (!ae3d_vk_create_image(width, height, 1, vk.depth_format, VK_SAMPLE_COUNT_1_BIT,
                              VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
                              VK_IMAGE_ASPECT_DEPTH_BIT, VK_IMAGE_TILING_OPTIMAL,
                              VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                              &vk.camdepth_image, &vk.camdepth_memory, &vk.camdepth_view)) {
        return 0;
    }

    memset(&sampler, 0, sizeof(sampler));
    sampler.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    sampler.magFilter = VK_FILTER_NEAREST;
    sampler.minFilter = VK_FILTER_NEAREST;
    sampler.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
    sampler.maxLod = 1.0f;
    if (ae3d_vkCreateSampler(vk.device, &sampler, NULL, &vk.camdepth_sampler) != VK_SUCCESS) {
        return ae3d_vk_fail("camera-depth vkCreateSampler failed");
    }

    attachments[0] = vk.camdepth_view;
    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    info.renderPass = vk.camdepth_pass;
    info.attachmentCount = 1;
    info.pAttachments = attachments;
    info.width = (unsigned)width;
    info.height = (unsigned)height;
    info.layers = 1;
    if (ae3d_vkCreateFramebuffer(vk.device, &info, NULL, &vk.camdepth_framebuffer) != VK_SUCCESS) {
        return ae3d_vk_fail("camera-depth vkCreateFramebuffer failed");
    }
    vk.camdepth_width = width;
    vk.camdepth_height = height;

    // The intermediate the reflective composite writes into: a colour target
    // the ordinary composite then samples, sized to match, filtered linearly so
    // the bloom that reads it can blur across it.
    {
        ae3d_vk_texture *reflect = NULL;
        VkSamplerCreateInfo rsampler;
        VkImageView rattach[1];
        VkFramebufferCreateInfo rinfo;
        int slot;

        for (slot = 0; slot < AE3D_VK_MAX_TEXTURES; slot++) {
            if (!vk.textures[slot].in_use) { reflect = &vk.textures[slot]; break; }
        }
        if (!reflect) return ae3d_vk_fail("texture table full");

        if (!ae3d_vk_create_image(width, height, 1, vk.color_format, VK_SAMPLE_COUNT_1_BIT,
                                  VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
                                  VK_IMAGE_ASPECT_COLOR_BIT, VK_IMAGE_TILING_OPTIMAL,
                                  VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                                  &reflect->image, &reflect->memory, &reflect->view)) {
            return 0;
        }

        memset(&rsampler, 0, sizeof(rsampler));
        rsampler.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
        rsampler.magFilter = VK_FILTER_LINEAR;
        rsampler.minFilter = VK_FILTER_LINEAR;
        rsampler.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        rsampler.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        rsampler.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        rsampler.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR;
        rsampler.maxLod = 1.0f;
        if (ae3d_vkCreateSampler(vk.device, &rsampler, NULL, &reflect->sampler) != VK_SUCCESS) {
            return ae3d_vk_fail("ssr-reflect vkCreateSampler failed");
        }
        reflect->width = width;
        reflect->height = height;
        reflect->in_use = 1;
        vk.ssr_reflect_texture = slot + 1;

        rattach[0] = reflect->view;
        memset(&rinfo, 0, sizeof(rinfo));
        rinfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        rinfo.renderPass = vk.ssr_pass;
        rinfo.attachmentCount = 1;
        rinfo.pAttachments = rattach;
        rinfo.width = (unsigned)width;
        rinfo.height = (unsigned)height;
        rinfo.layers = 1;
        if (ae3d_vkCreateFramebuffer(vk.device, &rinfo, NULL, &vk.ssr_framebuffer) != VK_SUCCESS) {
            return ae3d_vk_fail("ssr-reflect vkCreateFramebuffer failed");
        }
    }
    if (vk.taa_enabled && vk.ssr_pass) {
        int k;
        for (k = 0; k < 2; k++) {
            ae3d_vk_texture *tex = NULL;
            VkSamplerCreateInfo tsampler;
            VkImageView tattach[1];
            VkFramebufferCreateInfo tinfo;
            int slot;
            for (slot = 0; slot < AE3D_VK_MAX_TEXTURES; slot++) {
                if (!vk.textures[slot].in_use) { tex = &vk.textures[slot]; break; }
            }
            if (!tex) return ae3d_vk_fail("texture table full");
            if (!ae3d_vk_create_image(width, height, 1, vk.color_format, VK_SAMPLE_COUNT_1_BIT,
                                      VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
                                      VK_IMAGE_ASPECT_COLOR_BIT, VK_IMAGE_TILING_OPTIMAL,
                                      VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                                      &tex->image, &tex->memory, &tex->view)) {
                return 0;
            }
            memset(&tsampler, 0, sizeof(tsampler));
            tsampler.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
            tsampler.magFilter = VK_FILTER_LINEAR;
            tsampler.minFilter = VK_FILTER_LINEAR;
            tsampler.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
            tsampler.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
            tsampler.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
            tsampler.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR;
            tsampler.maxLod = 1.0f;
            if (ae3d_vkCreateSampler(vk.device, &tsampler, NULL, &tex->sampler) != VK_SUCCESS) {
                return ae3d_vk_fail("taa vkCreateSampler failed");
            }
            tex->width = width;
            tex->height = height;
            tex->in_use = 1;
            vk.taa_texture[k] = slot + 1;

            tattach[0] = tex->view;
            memset(&tinfo, 0, sizeof(tinfo));
            tinfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            tinfo.renderPass = vk.ssr_pass;
            tinfo.attachmentCount = 1;
            tinfo.pAttachments = tattach;
            tinfo.width = (unsigned)width;
            tinfo.height = (unsigned)height;
            tinfo.layers = 1;
            if (ae3d_vkCreateFramebuffer(vk.device, &tinfo, NULL, &vk.taa_framebuffer[k]) != VK_SUCCESS) {
                return ae3d_vk_fail("taa vkCreateFramebuffer failed");
            }
        }
        vk.taa_history_valid = 0;
        vk.taa_current = 0;
    }
    return 1;
}

/* Temporal anti-aliasing on or off. It reads the scene's depth, so the
   target that holds it is made the same way, with the two history textures
   beside it; and it composites through the post chain, which is turned on
   by it. */
void ae3d_vk_set_taa(int on) {
    on = on ? 1 : 0;
    if (vk.taa_enabled == on) return;
    vk.taa_enabled = on;
    if (!vk.ready) return;
    ae3d_vkDeviceWaitIdle(vk.device);
    ae3d_vk_destroy_camdepth_target();
    if (on || vk.ssr_enabled || vk.ssao_enabled || vk.scene_depth_wanted) {
        ae3d_vk_create_camdepth_target((int)vk.render_extent.width, (int)vk.render_extent.height);
    }
}

int ae3d_vk_taa(void) { return vk.taa_enabled; }

/* Whether this frame's temporal pass will fold a history in, or take the
   frame as it is: what the blend uniform is set from. */
int ae3d_vk_taa_history(void) { return vk.taa_enabled && vk.taa_history_valid; }

// The composite pass reads what the scene pass produced, so it takes a single
// resolved colour attachment and no depth.
static int ae3d_vk_build_post_pass(VkImageLayout present_layout, VkRenderPass *out) {
    VkAttachmentDescription attachment;
    VkAttachmentReference colour_ref;
    VkSubpassDescription subpass;
    VkSubpassDependency dependency;
    VkSubpassDependency handed[2];
    VkRenderPassCreateInfo info;

    memset(&attachment, 0, sizeof(attachment));
    attachment.format = vk.color_format;
    attachment.samples = VK_SAMPLE_COUNT_1_BIT;
    attachment.loadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    attachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    attachment.finalLayout = present_layout;

    memset(&colour_ref, 0, sizeof(colour_ref));
    colour_ref.attachment = 0;
    colour_ref.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    memset(&subpass, 0, sizeof(subpass));
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &colour_ref;

    /* What it samples was written as an attachment before it, and what it
       writes -- cleared of nothing, from UNDEFINED -- was written and read
       by the passes of the frame before: both orders, or the layout
       transition races the last frame's reads (#410). */
    memset(&dependency, 0, sizeof(dependency));
    dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
    dependency.dstSubpass = 0;
    dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT |
                              VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
    dependency.srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
    dependency.dstStageMask = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT |
                              VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstAccessMask = VK_ACCESS_SHADER_READ_BIT |
                               VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
    /* And out: what it wrote is sampled by the next pass or blitted and
       copied by the meter and the capture, after its final transition. */
    handed[0] = dependency;
    memset(&handed[1], 0, sizeof(handed[1]));
    handed[1].srcSubpass = 0;
    handed[1].dstSubpass = VK_SUBPASS_EXTERNAL;
    handed[1].srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    handed[1].srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
    handed[1].dstStageMask = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT | VK_PIPELINE_STAGE_TRANSFER_BIT;
    handed[1].dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_TRANSFER_READ_BIT;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    info.attachmentCount = 1;
    info.pAttachments = &attachment;
    info.subpassCount = 1;
    info.pSubpasses = &subpass;
    info.dependencyCount = 2;
    info.pDependencies = handed;

    if (ae3d_vkCreateRenderPass(vk.device, &info, NULL, out) != VK_SUCCESS) {
        return ae3d_vk_fail("post vkCreateRenderPass failed");
    }
    return 1;
}

// Two passes over the same attachment descriptions: one ends in the layout the
// display wants, the other in the layout a sampler wants. They stay compatible,
// so the scene pipelines are valid in either.
static int ae3d_vk_create_render_pass(void) {
    VkImageLayout present_layout = vk.offscreen ? VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
                                                : VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
    if (!ae3d_vk_build_render_pass(present_layout, 0, &vk.render_pass)) return 0;
    if (!ae3d_vk_build_render_pass(present_layout, 1, &vk.render_pass_first)) return 0;
    if (!ae3d_vk_build_render_pass(present_layout, 2, &vk.render_pass_rest)) return 0;
    if (!ae3d_vk_build_render_pass(VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, 0, &vk.scene_pass)) return 0;
    if (!ae3d_vk_build_render_pass(VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, 1, &vk.scene_pass_first)) return 0;
    if (!ae3d_vk_build_render_pass(VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, 2, &vk.scene_pass_rest)) return 0;
    if (!ae3d_vk_build_shadow_pass()) return 0;
    if (!ae3d_vk_build_lamp_pass()) return 0;
    if (!ae3d_vk_build_camdepth_pass()) return 0;
    // The reflective composite writes into an off-screen colour target the
    // final composite then samples, so its pass ends in sampler-read layout;
    // it stays compatible with the swapchain post pass, so one set of post
    // pipelines is valid in either.
    if (!ae3d_vk_build_post_pass(VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, &vk.ssr_pass)) return 0;
    return ae3d_vk_build_post_pass(present_layout, &vk.post_pass);
}

// The scene renders into a sampled image when post-processing is on, and the
// composite pass reads it. It is registered as an ordinary texture so the
// existing descriptor cache binds it with no second code path.
// The map, its own depth buffer, and the sampler the main pass reads it with.
// How many shadow targets the backend is holding. A rebuild makes a fresh one,
// so the old one has to go with the swapchain it was built alongside; this is
// what a test can watch to know that it did.
static int g_shadow_targets;

int ae3d_vk_live_shadow_targets(void) { return g_shadow_targets; }

static void ae3d_vk_destroy_shadow_target(void) {
    if (vk.shadow_framebuffer || vk.shadow_image) g_shadow_targets--;
    if (vk.shadow_framebuffer) {
        ae3d_vkDestroyFramebuffer(vk.device, vk.shadow_framebuffer, NULL);
        vk.shadow_framebuffer = VK_NULL_HANDLE;
    }
    if (vk.shadow_sampler) {
        ae3d_vkDestroySampler(vk.device, vk.shadow_sampler, NULL);
        vk.shadow_sampler = VK_NULL_HANDLE;
    }
    if (vk.shadow_view) {
        ae3d_vkDestroyImageView(vk.device, vk.shadow_view, NULL);
        vk.shadow_view = VK_NULL_HANDLE;
    }
    if (vk.shadow_image) {
        ae3d_vkDestroyImage(vk.device, vk.shadow_image, NULL);
        vk.shadow_image = VK_NULL_HANDLE;
    }
    if (vk.shadow_memory) {
        ae3d_vkFreeMemory(vk.device, vk.shadow_memory, NULL);
        vk.shadow_memory = VK_NULL_HANDLE;
    }
}

static int ae3d_vk_create_shadow_target(void) {
    VkSamplerCreateInfo sampler;
    VkImageView attachments[2];
    VkFramebufferCreateInfo info;

    // One image: the depth attachment is also what the lit pass samples.
    if (!ae3d_vk_create_image(AE3D_VK_SHADOW_SIZE, AE3D_VK_SHADOW_SIZE, 1,
                              vk.depth_format, VK_SAMPLE_COUNT_1_BIT,
                              VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT |
                              VK_IMAGE_USAGE_SAMPLED_BIT,
                              VK_IMAGE_ASPECT_DEPTH_BIT, VK_IMAGE_TILING_OPTIMAL,
                              VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                              &vk.shadow_image, &vk.shadow_memory, &vk.shadow_view)) {
        return 0;
    }

    memset(&sampler, 0, sizeof(sampler));
    sampler.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    sampler.magFilter = VK_FILTER_NEAREST;
    sampler.minFilter = VK_FILTER_NEAREST;
    sampler.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
    sampler.maxLod = 1.0f;
    if (ae3d_vkCreateSampler(vk.device, &sampler, NULL, &vk.shadow_sampler) != VK_SUCCESS) {
        return ae3d_vk_fail("shadow vkCreateSampler failed");
    }

    attachments[0] = vk.shadow_view;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    info.renderPass = vk.shadow_pass;
    info.attachmentCount = 1;
    info.pAttachments = attachments;
    info.width = AE3D_VK_SHADOW_SIZE;
    info.height = AE3D_VK_SHADOW_SIZE;
    info.layers = 1;
    if (ae3d_vkCreateFramebuffer(vk.device, &info, NULL, &vk.shadow_framebuffer) != VK_SUCCESS) {
        return ae3d_vk_fail("shadow vkCreateFramebuffer failed");
    }
    vk.shadow_ready = 0;
    g_shadow_targets++;
    return 1;
}

static VkCommandBuffer ae3d_vk_begin_once(void);
static void ae3d_vk_end_once(VkCommandBuffer command);

static void ae3d_vk_destroy_lamp_image(VkImage *image, VkDeviceMemory *memory, VkImageView *view,
                                       VkFramebuffer *framebuffer) {
    if (*framebuffer) ae3d_vkDestroyFramebuffer(vk.device, *framebuffer, NULL);
    if (*view) ae3d_vkDestroyImageView(vk.device, *view, NULL);
    if (*image) ae3d_vkDestroyImage(vk.device, *image, NULL);
    if (*memory) ae3d_vkFreeMemory(vk.device, *memory, NULL);
    *framebuffer = VK_NULL_HANDLE;
    *view = VK_NULL_HANDLE;
    *image = VK_NULL_HANDLE;
    *memory = VK_NULL_HANDLE;
}

static void ae3d_vk_destroy_lamp_target(void) {
    ae3d_vk_destroy_lamp_image(&vk.lamp_image, &vk.lamp_memory, &vk.lamp_view, &vk.lamp_framebuffer);
    ae3d_vk_destroy_lamp_image(&vk.lamp_static_image, &vk.lamp_static_memory, &vk.lamp_static_view,
                               &vk.lamp_static_framebuffer);
    if (vk.lamp_sampler) ae3d_vkDestroySampler(vk.device, vk.lamp_sampler, NULL);
    vk.lamp_sampler = VK_NULL_HANDLE;
}

/* One of the lamps' two atlases: its image, drawn into by the lamps' pass
   and copied from and to a tile at a time, and its framebuffer; cleared to
   the far plane and left readable, the layout the pass takes it in and
   leaves it in. */
static int ae3d_vk_make_lamp_image(VkImage *image, VkDeviceMemory *memory, VkImageView *view,
                                   VkFramebuffer *framebuffer) {
    VkFramebufferCreateInfo info;
    VkImageMemoryBarrier barrier;
    VkClearDepthStencilValue cleared;
    VkImageSubresourceRange range;
    VkCommandBuffer once;

    if (!ae3d_vk_create_image(AE3D_VK_LAMP_SHADOW_SIZE, AE3D_VK_LAMP_SHADOW_SIZE, 1,
                              vk.depth_format, VK_SAMPLE_COUNT_1_BIT,
                              VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT |
                              VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
                              VK_IMAGE_ASPECT_DEPTH_BIT, VK_IMAGE_TILING_OPTIMAL,
                              VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, image, memory, view)) {
        return 0;
    }

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    info.renderPass = vk.lamp_pass;
    info.attachmentCount = 1;
    info.pAttachments = view;
    info.width = AE3D_VK_LAMP_SHADOW_SIZE;
    info.height = AE3D_VK_LAMP_SHADOW_SIZE;
    info.layers = 1;
    if (ae3d_vkCreateFramebuffer(vk.device, &info, NULL, framebuffer) != VK_SUCCESS) {
        return ae3d_vk_fail("lamp shadow vkCreateFramebuffer failed");
    }

    memset(&range, 0, sizeof(range));
    range.aspectMask = VK_IMAGE_ASPECT_DEPTH_BIT;
    range.levelCount = 1;
    range.layerCount = 1;
    once = ae3d_vk_begin_once();
    if (!once) return ae3d_vk_fail("lamp shadow: no command buffer to clear it with");
    memset(&barrier, 0, sizeof(barrier));
    barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier.image = *image;
    barrier.subresourceRange = range;
    barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    ae3d_vkCmdPipelineBarrier(once, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT,
                              0, 0, NULL, 0, NULL, 1, &barrier);
    cleared.depth = 1.0f;
    cleared.stencil = 0;
    ae3d_vkCmdClearDepthStencilImage(once, *image, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &cleared, 1, &range);
    barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT |
                            VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT | VK_ACCESS_TRANSFER_READ_BIT;
    ae3d_vkCmdPipelineBarrier(once, VK_PIPELINE_STAGE_TRANSFER_BIT,
                              VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT | VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT |
                              VK_PIPELINE_STAGE_TRANSFER_BIT,
                              0, 0, NULL, 0, NULL, 1, &barrier);
    ae3d_vk_end_once(once);
    return 1;
}

/* The lamps' atlases, made once when the backend starts and kept: their
   size is their own, not the window's. Every time they are made the
   generation moves on, so what remembers which faces they hold
   (ae3d.vulkan) forgets them. */
static int ae3d_vk_create_lamp_target(void) {
    VkSamplerCreateInfo sampler;

    if (!ae3d_vk_make_lamp_image(&vk.lamp_image, &vk.lamp_memory, &vk.lamp_view, &vk.lamp_framebuffer)) return 0;
    if (!ae3d_vk_make_lamp_image(&vk.lamp_static_image, &vk.lamp_static_memory, &vk.lamp_static_view,
                                 &vk.lamp_static_framebuffer)) {
        return 0;
    }
    memset(&sampler, 0, sizeof(sampler));
    sampler.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    sampler.magFilter = VK_FILTER_NEAREST;
    sampler.minFilter = VK_FILTER_NEAREST;
    sampler.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
    sampler.maxLod = 1.0f;
    if (ae3d_vkCreateSampler(vk.device, &sampler, NULL, &vk.lamp_sampler) != VK_SUCCESS) {
        return ae3d_vk_fail("lamp shadow vkCreateSampler failed");
    }
    vk.lamp_generation++;
    return 1;
}

static int ae3d_vk_create_post_target(void) {
    ae3d_vk_texture *texture = NULL;
    VkSamplerCreateInfo sampler;
    VkImageView attachments[5];
    VkFramebufferCreateInfo info;
    int multisampled = vk.samples != VK_SAMPLE_COUNT_1_BIT;
    unsigned i;
    int slot;

    for (slot = 0; slot < AE3D_VK_MAX_TEXTURES; slot++) {
        if (!vk.textures[slot].in_use) { texture = &vk.textures[slot]; break; }
    }
    if (!texture) return ae3d_vk_fail("texture table full");

    if (!ae3d_vk_create_image((int)vk.render_extent.width, (int)vk.render_extent.height, 1, vk.color_format,
                              VK_SAMPLE_COUNT_1_BIT,
                              VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
                              VK_IMAGE_ASPECT_COLOR_BIT, VK_IMAGE_TILING_OPTIMAL,
                              VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                              &texture->image, &texture->memory, &texture->view)) {
        return 0;
    }

    memset(&sampler, 0, sizeof(sampler));
    sampler.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    sampler.magFilter = VK_FILTER_LINEAR;
    sampler.minFilter = VK_FILTER_LINEAR;
    sampler.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR;
    sampler.maxLod = 1.0f;
    if (ae3d_vkCreateSampler(vk.device, &sampler, NULL, &texture->sampler) != VK_SUCCESS) {
        return ae3d_vk_fail("post vkCreateSampler failed");
    }

    texture->width = (int)vk.render_extent.width;
    texture->height = (int)vk.render_extent.height;
    texture->in_use = 1;
    vk.post_texture = slot + 1;

    if (multisampled) {
        attachments[0] = vk.colour_view;
        attachments[1] = vk.depth_view;
        attachments[2] = vk.velocity_view;
        attachments[3] = texture->view;
        attachments[4] = vk.textures[vk.velocity_texture - 1].view;
    } else {
        attachments[0] = texture->view;
        attachments[1] = vk.depth_view;
        attachments[2] = vk.textures[vk.velocity_texture - 1].view;
    }

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    info.renderPass = vk.scene_pass;
    info.attachmentCount = multisampled ? 5u : 3u;
    info.pAttachments = attachments;
    info.width = vk.render_extent.width;
    info.height = vk.render_extent.height;
    info.layers = 1;
    if (ae3d_vkCreateFramebuffer(vk.device, &info, NULL, &vk.scene_framebuffer) != VK_SUCCESS) {
        return ae3d_vk_fail("scene vkCreateFramebuffer failed");
    }

    /* The composite's framebuffers are the swapchain's images at the frame's
       own size: what scales the scene up when it was drawn smaller. */
    vk.post_framebuffers = (VkFramebuffer *)calloc(vk.image_count, sizeof(VkFramebuffer));
    if (!vk.post_framebuffers) return ae3d_vk_fail("out of memory");
    info.width = vk.extent.width;
    info.height = vk.extent.height;
    for (i = 0; i < vk.image_count; i++) {
        info.renderPass = vk.post_pass;
        info.attachmentCount = 1;
        info.pAttachments = &vk.image_views[i];
        if (ae3d_vkCreateFramebuffer(vk.device, &info, NULL, &vk.post_framebuffers[i]) != VK_SUCCESS) {
            return ae3d_vk_fail("post vkCreateFramebuffer failed");
        }
    }
    return 1;
}

static int ae3d_vk_create_framebuffers(void) {
    unsigned i;

    vk.framebuffers = (VkFramebuffer *)calloc(vk.image_count, sizeof(VkFramebuffer));
    if (!vk.framebuffers) return ae3d_vk_fail("out of memory");

    /* Drawn into straight, without the post chain, only when the scene is
       the frame's size: their depth and vectors are the scene's, and an
       attachment smaller than the framebuffer is not allowed. Scaled, the
       post chain always runs and these stay null. */
    for (i = 0; i < vk.image_count && !ae3d_vk_scaled(); i++) {
        VkImageView attachments[5];
        VkFramebufferCreateInfo info;
        VkResult result;
        int multisampled = vk.samples != VK_SAMPLE_COUNT_1_BIT;

        if (multisampled) {
            attachments[0] = vk.colour_view;
            attachments[1] = vk.depth_view;
            attachments[2] = vk.velocity_view;
            attachments[3] = vk.image_views[i];
            attachments[4] = vk.textures[vk.velocity_texture - 1].view;
        } else {
            attachments[0] = vk.image_views[i];
            attachments[1] = vk.depth_view;
            attachments[2] = vk.textures[vk.velocity_texture - 1].view;
        }

        memset(&info, 0, sizeof(info));
        info.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        info.renderPass = vk.render_pass;
        info.attachmentCount = multisampled ? 5u : 3u;
        info.pAttachments = attachments;
        info.width = vk.extent.width;
        info.height = vk.extent.height;
        info.layers = 1;

        result = ae3d_vkCreateFramebuffer(vk.device, &info, NULL, &vk.framebuffers[i]);
        if (result != VK_SUCCESS) return ae3d_vk_fail_code("vkCreateFramebuffer failed", result);
    }
    if (!ae3d_vk_create_shadow_target()) return 0;
    return ae3d_vk_create_post_target();
}

static VkShaderModule ae3d_vk_shader(const unsigned char *bytes, unsigned length) {
    VkShaderModuleCreateInfo info;
    VkShaderModule module = VK_NULL_HANDLE;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    info.codeSize = length;
    info.pCode = (const unsigned *)(const void *)bytes;
    if (ae3d_vkCreateShaderModule(vk.device, &info, NULL, &module) != VK_SUCCESS) return VK_NULL_HANDLE;
    return module;
}


/* The multisampling asked for before the backend starts: the most the
   frame takes, 4 unless told otherwise; 0 or 1 is none, which is what an
   upscaler wants, since a resolved pixel has no sub-pixel detail left. */
static int g_samples_wanted = 4;
void ae3d_vk_set_samples(int samples) { g_samples_wanted = samples; }

static VkSampleCountFlagBits ae3d_vk_pick_samples(void) {
    VkPhysicalDeviceProperties properties;
    VkSampleCountFlags counts;

    ae3d_vkGetPhysicalDeviceProperties(vk.physical, &properties);
    counts = properties.limits.framebufferColorSampleCounts &
             properties.limits.framebufferDepthSampleCounts;
    if (g_samples_wanted >= 4 && (counts & VK_SAMPLE_COUNT_4_BIT)) return VK_SAMPLE_COUNT_4_BIT;
    if (g_samples_wanted >= 2 && (counts & VK_SAMPLE_COUNT_2_BIT)) return VK_SAMPLE_COUNT_2_BIT;
    return VK_SAMPLE_COUNT_1_BIT;
}

static int ae3d_vk_create_image(int width, int height, int mip_levels, VkFormat format,
                                VkSampleCountFlagBits samples, VkImageUsageFlags usage,
                                VkImageAspectFlags aspect, VkImageTiling tiling,
                                VkMemoryPropertyFlags properties,
                                VkImage *image, VkDeviceMemory *memory, VkImageView *view) {
    VkImageCreateInfo info;
    VkMemoryRequirements requirements;
    VkMemoryAllocateInfo allocation;
    int type;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    info.imageType = VK_IMAGE_TYPE_2D;
    info.format = format;
    info.extent.width = (unsigned)width;
    info.extent.height = (unsigned)height;
    info.extent.depth = 1;
    info.mipLevels = (unsigned)mip_levels;
    info.arrayLayers = 1;
    info.samples = samples;
    info.tiling = tiling;
    info.usage = usage;
    info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    info.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

    if (ae3d_vkCreateImage(vk.device, &info, NULL, image) != VK_SUCCESS) {
        return ae3d_vk_fail("vkCreateImage failed");
    }

    ae3d_vkGetImageMemoryRequirements(vk.device, *image, &requirements);
    type = ae3d_vk_memory_type(requirements.memoryTypeBits, properties);
    if (type < 0) return ae3d_vk_fail("no memory type for an image");

    memset(&allocation, 0, sizeof(allocation));
    allocation.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocation.allocationSize = requirements.size;
    allocation.memoryTypeIndex = (unsigned)type;
    if (ae3d_vkAllocateMemory(vk.device, &allocation, NULL, memory) != VK_SUCCESS) {
        return ae3d_vk_fail("image vkAllocateMemory failed");
    }
    ae3d_vkBindImageMemory(vk.device, *image, *memory, 0);

    if (view) {
        VkImageViewCreateInfo view_info;
        memset(&view_info, 0, sizeof(view_info));
        view_info.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        view_info.image = *image;
        view_info.viewType = VK_IMAGE_VIEW_TYPE_2D;
        view_info.format = format;
        view_info.subresourceRange.aspectMask = aspect;
        view_info.subresourceRange.levelCount = (unsigned)mip_levels;
        view_info.subresourceRange.layerCount = 1;
        if (ae3d_vkCreateImageView(vk.device, &view_info, NULL, view) != VK_SUCCESS) {
            return ae3d_vk_fail("image vkCreateImageView failed");
        }
    }
    return 1;
}

// One command buffer, submitted and waited on. Used by uploads and layout
// transitions, which happen outside the frame loop.
static VkCommandBuffer ae3d_vk_begin_once(void) {
    VkCommandBufferAllocateInfo allocation;
    VkCommandBufferBeginInfo begin;
    VkCommandBuffer command = VK_NULL_HANDLE;

    memset(&allocation, 0, sizeof(allocation));
    allocation.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    allocation.commandPool = vk.command_pool;
    allocation.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocation.commandBufferCount = 1;
    if (ae3d_vkAllocateCommandBuffers(vk.device, &allocation, &command) != VK_SUCCESS) return VK_NULL_HANDLE;

    memset(&begin, 0, sizeof(begin));
    begin.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    ae3d_vkBeginCommandBuffer(command, &begin);
    return command;
}

static void ae3d_vk_end_once(VkCommandBuffer command) {
    VkSubmitInfo submit;
    if (!command) return;
    ae3d_vkEndCommandBuffer(command);
    memset(&submit, 0, sizeof(submit));
    submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submit.commandBufferCount = 1;
    submit.pCommandBuffers = &command;
    ae3d_vkQueueSubmit(vk.graphics_queue, 1, &submit, VK_NULL_HANDLE);
    ae3d_vkQueueWaitIdle(vk.graphics_queue);
    ae3d_vkFreeCommandBuffers(vk.device, vk.command_pool, 1, &command);
}

/* A scene texture's sampler, with the mip chain and the LOD bias of the
   moment: the scene drawn smaller than the frame for an upscaler picks a
   coarser mip than the frame's pixels deserve, and the detail lost there
   is detail the upscaler never gets to reconstruct; the bias, log2 of the
   scale, keeps the mip the frame's own. Remade for every texture when the
   scale changes (ae3d_vk_rebias_samplers). */
static int ae3d_vk_texture_sampler(ae3d_vk_texture *texture) {
    VkSamplerCreateInfo sampler;
    if (texture->sampler) { ae3d_vkDestroySampler(vk.device, texture->sampler, NULL); texture->sampler = VK_NULL_HANDLE; }
    memset(&sampler, 0, sizeof(sampler));
    sampler.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    sampler.magFilter = VK_FILTER_LINEAR;
    sampler.minFilter = VK_FILTER_LINEAR;
    sampler.addressModeU = VK_SAMPLER_ADDRESS_MODE_REPEAT;
    sampler.addressModeV = VK_SAMPLER_ADDRESS_MODE_REPEAT;
    sampler.addressModeW = VK_SAMPLER_ADDRESS_MODE_REPEAT;
    sampler.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR;
    sampler.maxLod = (float)texture->mip_levels;
    sampler.mipLodBias = vk.lod_bias;
    if (ae3d_vkCreateSampler(vk.device, &sampler, NULL, &texture->sampler) != VK_SUCCESS) {
        return ae3d_vk_fail("vkCreateSampler failed");
    }
    return 1;
}

/* Every scene texture's sampler remade at the LOD bias the render scale
   asks for, and the descriptor sets that named the old samplers let go. */
static void ae3d_vk_rebias_samplers(void) {
    int slot, frame, index;
    float bias = 0.0f;
    if (vk.render_extent.width && vk.extent.width && vk.render_extent.width < vk.extent.width) {
        bias = (float)(log((double)vk.render_extent.width / (double)vk.extent.width) / log(2.0));
    }
    if (bias == vk.lod_bias) return;
    vk.lod_bias = bias;
    if (!vk.device) return;
    ae3d_vkDeviceWaitIdle(vk.device);
    for (slot = 0; slot < AE3D_VK_MAX_TEXTURES; slot++) {
        ae3d_vk_texture *texture = &vk.textures[slot];
        if (!texture->in_use || texture->mip_levels <= 0) continue;
        ae3d_vk_texture_sampler(texture);
    }
    for (frame = 0; frame < AE3D_VK_FRAMES; frame++) {
        for (index = 0; index < vk.set_count[frame]; index++) vk.set_texture[frame][index] = AE3D_VK_SET_FREE;
    }
}

/* A texture ae3d.vktexture made -- its image, memory and view, uploaded
   and left readable by the shaders -- into the table, with the sampler its
   kind is drawn with: a scene texture's linear, repeating, over its mip
   chain at the frame's LOD bias (0); an RGBA one's linear and repeating
   with no mips (1); a float one's nearest and clamped, fetched by exact
   texel (2). The handle, or 0 when the table is full or the sampler would
   not make, the image then destroyed. */
int ae3d_vk_texture_adopt(void *image, void *memory, void *view, int width, int height, int mip_levels, int kind) {
    ae3d_vk_texture *texture = NULL;
    VkSamplerCreateInfo sampler;
    int slot, handle = 0;

    if (!vk.device || !image) return 0;
    for (slot = 0; slot < AE3D_VK_MAX_TEXTURES; slot++) {
        if (!vk.textures[slot].in_use) { texture = &vk.textures[slot]; handle = slot + 1; break; }
    }
    if (!texture) {
        ae3d_vk_fail("texture table full");
        ae3d_vkDestroyImageView(vk.device, (VkImageView)view, NULL);
        ae3d_vkDestroyImage(vk.device, (VkImage)image, NULL);
        ae3d_vkFreeMemory(vk.device, (VkDeviceMemory)memory, NULL);
        return 0;
    }
    memset(texture, 0, sizeof(*texture));
    texture->image = (VkImage)image;
    texture->memory = (VkDeviceMemory)memory;
    texture->view = (VkImageView)view;
    texture->width = width;
    texture->height = height;
    if (kind == 0) {
        texture->mip_levels = mip_levels;
        if (!ae3d_vk_texture_sampler(texture)) goto fail;
    } else {
        memset(&sampler, 0, sizeof(sampler));
        sampler.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
        sampler.magFilter = kind == 2 ? VK_FILTER_NEAREST : VK_FILTER_LINEAR;
        sampler.minFilter = kind == 2 ? VK_FILTER_NEAREST : VK_FILTER_LINEAR;
        sampler.addressModeU = kind == 2 ? VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE : VK_SAMPLER_ADDRESS_MODE_REPEAT;
        sampler.addressModeV = sampler.addressModeU;
        sampler.addressModeW = sampler.addressModeU;
        sampler.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
        sampler.maxLod = 0.0f;
        if (ae3d_vkCreateSampler(vk.device, &sampler, NULL, &texture->sampler) != VK_SUCCESS) {
            ae3d_vk_fail("vkCreateSampler failed");
            goto fail;
        }
    }
    texture->in_use = 1;
    return handle;
fail:
    ae3d_vkDestroyImageView(vk.device, texture->view, NULL);
    ae3d_vkDestroyImage(vk.device, texture->image, NULL);
    ae3d_vkFreeMemory(vk.device, texture->memory, NULL);
    memset(texture, 0, sizeof(*texture));
    return 0;
}

/* The one-off command buffer uploads are recorded into, for an Aether
   module (ae3d.vktexture): begun, and submitted and waited on. */
void *ae3d_vk_once_begin(void) { return (void *)ae3d_vk_begin_once(); }
void ae3d_vk_once_end(void *commands) { ae3d_vk_end_once((VkCommandBuffer)commands); }

void ae3d_vk_texture_destroy(int handle) {
    ae3d_vk_texture *texture;
    int frame, index;

    if (!vk.device || handle < 1 || handle > AE3D_VK_MAX_TEXTURES) return;
    texture = &vk.textures[handle - 1];
    if (!texture->in_use) return;
    ae3d_vkDeviceWaitIdle(vk.device);

    /* Descriptor sets are cached against the texture handle, and handles are
       reused: a set written for the image being destroyed here would be handed
       to whichever texture is created in this slot next, naming an image view
       that no longer exists. A hardware driver has usually survived reading
       one; lavapipe dereferences it, which is where this was found. The sets
       go back on the free list and are written again when they are claimed.
       A set names three images, and is keyed on all three: one whose normal
       map or pose bank this was is as stale as one whose colour it was, and
       was handed out as current as soon as another texture took the handle
       (the validation layer counted 36 draws through a destroyed view and
       sampler in tests/test_backend_parity). */
    for (frame = 0; frame < AE3D_VK_FRAMES; frame++) {
        for (index = 0; index < vk.set_count[frame]; index++) {
            if (vk.set_texture[frame][index] == handle || vk.set_normal[frame][index] == handle ||
                vk.set_bank[frame][index] == handle) {
                vk.set_texture[frame][index] = AE3D_VK_SET_FREE;
            }
        }
    }
    if (texture->sampler) ae3d_vkDestroySampler(vk.device, texture->sampler, NULL);
    if (texture->view) ae3d_vkDestroyImageView(vk.device, texture->view, NULL);
    if (texture->image) ae3d_vkDestroyImage(vk.device, texture->image, NULL);
    if (texture->memory) ae3d_vkFreeMemory(vk.device, texture->memory, NULL);
    memset(texture, 0, sizeof(*texture));
}

static int ae3d_vk_cluster_make(ae3d_vk_cluster_buffer *b, VkDeviceSize size);

static int ae3d_vk_create_descriptors(void) {
    VkDescriptorSetLayoutBinding bindings[9];
    VkDescriptorSetLayoutCreateInfo layout;
    VkDescriptorPoolSize sizes[4];
    VkDescriptorPoolCreateInfo pool;
    VkPhysicalDeviceProperties properties;
    unsigned alignment, stride;
    int frame;

    memset(bindings, 0, sizeof(bindings));
    bindings[0].binding = 0;
    bindings[0].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC;
    bindings[0].descriptorCount = 1;
    bindings[0].stageFlags = VK_SHADER_STAGE_VERTEX_BIT | VK_SHADER_STAGE_FRAGMENT_BIT;
    bindings[1].binding = 1;
    bindings[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    bindings[1].descriptorCount = 1;
    bindings[1].stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;

    // The shadow map the fragment shader declares. OpenGL fills it from its
    // depth pass; here it holds the default texture until Vulkan has one, which
    // reads as fully lit and keeps the two backends agreeing.
    bindings[2].binding = 2;
    bindings[2].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    bindings[2].descriptorCount = 1;
    bindings[2].stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;

    // The normal map. A material without one binds the default texture, whose
    // flat colour the shader never reads, because hasNormalMap is off.
    bindings[3].binding = 3;
    bindings[3].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    bindings[3].descriptorCount = 1;
    bindings[3].stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;

    // The pose bank: a float texture of baked bone palettes the crowd vertex
    // shader fetches by (bone, frame). Read in the vertex stage, which is
    // what sets this binding apart from the other three.
    bindings[4].binding = 4;
    bindings[4].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    bindings[4].descriptorCount = 1;
    bindings[4].stageFlags = VK_SHADER_STAGE_VERTEX_BIT | VK_SHADER_STAGE_FRAGMENT_BIT;

    // The clustered lamps (#468): the lamps at 6 and the cells' lists at 7,
    // storage buffers the scene fragment shader indexes.
    bindings[5].binding = 6;
    bindings[5].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    bindings[5].descriptorCount = 1;
    bindings[5].stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
    bindings[6].binding = 7;
    bindings[6].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    bindings[6].descriptorCount = 1;
    bindings[6].stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;

    // The lamps' shadow atlas (#490), which the scene fragment shader
    // samples for every lamp with a cube of its own.
    bindings[7].binding = 8;
    bindings[7].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    bindings[7].descriptorCount = 1;
    bindings[7].stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
    // The scene's acceleration structure at 5, for the rays the fragment
    // traces; only where the device traces, since a layout naming a
    // descriptor type the device has no extension for is refused -- so it
    // is last in the list, and left off it where there are no rays.
    bindings[8].binding = 5;
    bindings[8].descriptorType = VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR;
    bindings[8].descriptorCount = 1;
    bindings[8].stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;

    memset(&layout, 0, sizeof(layout));
    layout.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    layout.bindingCount = vk.ray_query ? 9 : 8;
    layout.pBindings = bindings;
    if (ae3d_vkCreateDescriptorSetLayout(vk.device, &layout, NULL, &vk.set_layout) != VK_SUCCESS) {
        return ae3d_vk_fail("vkCreateDescriptorSetLayout failed");
    }

    memset(sizes, 0, sizeof(sizes));
    sizes[0].type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC;
    sizes[0].descriptorCount = AE3D_VK_FRAMES * AE3D_VK_MAX_TEXTURES;
    sizes[1].type = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    sizes[1].descriptorCount = AE3D_VK_FRAMES * AE3D_VK_MAX_TEXTURES * 5;
    sizes[2].type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    sizes[2].descriptorCount = AE3D_VK_FRAMES * AE3D_VK_MAX_TEXTURES * 2;
    sizes[3].type = VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR;
    sizes[3].descriptorCount = AE3D_VK_FRAMES * AE3D_VK_MAX_TEXTURES;

    memset(&pool, 0, sizeof(pool));
    pool.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
    pool.maxSets = AE3D_VK_FRAMES * AE3D_VK_MAX_TEXTURES;
    pool.poolSizeCount = vk.ray_query ? 4 : 3;
    pool.pPoolSizes = sizes;
    if (ae3d_vkCreateDescriptorPool(vk.device, &pool, NULL, &vk.descriptor_pool) != VK_SUCCESS) {
        return ae3d_vk_fail("vkCreateDescriptorPool failed");
    }

    // Every draw gets its own slice of one mapped buffer, bound with a dynamic
    // offset, so a frame's uniforms are written once and never reallocated.
    ae3d_vkGetPhysicalDeviceProperties(vk.physical, &properties);
    alignment = (unsigned)properties.limits.minUniformBufferOffsetAlignment;
    if (alignment == 0) alignment = 1;
    stride = (AE3D_VK_SCENE_SIZE + alignment - 1) / alignment * alignment;

    for (frame = 0; frame < AE3D_VK_FRAMES; frame++) {
        ae3d_vk_uniform_ring *ring = &vk.uniforms[frame];
        void *mapped = NULL;
        ring->stride = stride;
        ring->capacity = AE3D_VK_DRAWS_PER_FRAME;
        if (!ae3d_vk_create_buffer((VkDeviceSize)stride * AE3D_VK_DRAWS_PER_FRAME,
                                   VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                                   VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                                   &ring->buffer, &ring->memory)) {
            return 0;
        }
        if (ae3d_vkMapMemory(vk.device, ring->memory, 0, VK_WHOLE_SIZE, 0, &mapped) != VK_SUCCESS) {
            return ae3d_vk_fail("uniform vkMapMemory failed");
        }
        ring->mapped = (unsigned char *)mapped;
        if (!ae3d_vk_cluster_make(&vk.cluster_lights[frame], AE3D_VK_CLUSTER_LIGHT_BYTES) ||
            !ae3d_vk_cluster_make(&vk.cluster_words[frame], AE3D_VK_CLUSTER_WORD_BYTES)) {
            return 0;
        }
    }
    return 1;
}

/* A cluster buffer `size` bytes long, host-visible, coherent and mapped,
   zeroed so a slot drawn before its first write lists no lamps. */
static int ae3d_vk_cluster_make(ae3d_vk_cluster_buffer *b, VkDeviceSize size) {
    void *mapped = NULL;
    if (!ae3d_vk_create_buffer(size, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
                               VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                               &b->buffer, &b->memory)) {
        return 0;
    }
    if (ae3d_vkMapMemory(vk.device, b->memory, 0, VK_WHOLE_SIZE, 0, &mapped) != VK_SUCCESS) {
        return ae3d_vk_fail("cluster vkMapMemory failed");
    }
    memset(mapped, 0, (size_t)size);
    b->mapped = mapped;
    b->size = size;
    return 1;
}

static void ae3d_vk_cluster_destroy(ae3d_vk_cluster_buffer *b) {
    if (b->mapped) ae3d_vkUnmapMemory(vk.device, b->memory);
    if (b->buffer) ae3d_vkDestroyBuffer(vk.device, b->buffer, NULL);
    if (b->memory) ae3d_vkFreeMemory(vk.device, b->memory, NULL);
    memset(b, 0, sizeof(*b));
}

/* The two cluster buffers of `frame` into a set's bindings 6 and 7. */
static void ae3d_vk_write_clusters(VkDescriptorSet set, int frame) {
    VkDescriptorBufferInfo infos[2];
    VkWriteDescriptorSet writes[2];
    memset(infos, 0, sizeof(infos));
    infos[0].buffer = vk.cluster_lights[frame].buffer;
    infos[0].range = VK_WHOLE_SIZE;
    infos[1].buffer = vk.cluster_words[frame].buffer;
    infos[1].range = VK_WHOLE_SIZE;
    memset(writes, 0, sizeof(writes));
    writes[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[0].dstSet = set;
    writes[0].dstBinding = 6;
    writes[0].descriptorCount = 1;
    writes[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    writes[0].pBufferInfo = &infos[0];
    writes[1] = writes[0];
    writes[1].dstBinding = 7;
    writes[1].pBufferInfo = &infos[1];
    ae3d_vkUpdateDescriptorSets(vk.device, 2, writes, 0, NULL);
}

/* This frame slot's cluster buffers, grown to hold `light_bytes` and
   `word_bytes` when they do not. Called by ae3d.vulkan after
   ae3d_vk_frame_begin, when the slot's last submission has finished, so a
   buffer can be remade under it; every set of the slot is then pointed at
   the new one. 0 when a buffer could not be made. */
int ae3d_vk_clusters_reserve(long light_bytes, long word_bytes) {
    int frame = (int)vk.frame;
    int grew = 0;
    int index;
    ae3d_vk_cluster_buffer *lights = &vk.cluster_lights[frame];
    ae3d_vk_cluster_buffer *words = &vk.cluster_words[frame];
    if (!vk.ready) return 0;
    if ((VkDeviceSize)light_bytes > lights->size) {
        VkDeviceSize size = lights->size ? lights->size : AE3D_VK_CLUSTER_LIGHT_BYTES;
        while (size < (VkDeviceSize)light_bytes) size *= 2;
        ae3d_vk_cluster_destroy(lights);
        if (!ae3d_vk_cluster_make(lights, size)) return 0;
        grew = 1;
    }
    if ((VkDeviceSize)word_bytes > words->size) {
        VkDeviceSize size = words->size ? words->size : AE3D_VK_CLUSTER_WORD_BYTES;
        while (size < (VkDeviceSize)word_bytes) size *= 2;
        ae3d_vk_cluster_destroy(words);
        if (!ae3d_vk_cluster_make(words, size)) return 0;
        grew = 1;
    }
    if (grew) {
        for (index = 0; index < vk.set_count[frame]; index++) {
            ae3d_vk_write_clusters(vk.sets[frame][index], frame);
        }
    }
    return 1;
}

/* Where this frame slot's lamps and lists are written. */
void *ae3d_vk_clusters_lights(void) { return vk.cluster_lights[vk.frame].mapped; }
void *ae3d_vk_clusters_words(void) { return vk.cluster_words[vk.frame].mapped; }

/* A set is keyed on the pair of images it binds, not on the colour alone: two
   materials can share a colour and differ in their normal map, and keying on
   one of them hands the second the first one's surface. */
static VkDescriptorSet ae3d_vk_set_for(int frame, int texture_handle, int normal_handle,
                                       int bank_handle) {
    VkDescriptorSetAllocateInfo allocation;
    VkDescriptorSet set = VK_NULL_HANDLE;
    VkDescriptorBufferInfo buffer;
    VkDescriptorImageInfo image;
    VkDescriptorImageInfo shadow;
    VkDescriptorImageInfo bumps;
    VkDescriptorImageInfo bank;
    VkDescriptorImageInfo lamps;
    VkWriteDescriptorSet writes[7];
    VkWriteDescriptorSetAccelerationStructureKHR structure;
    unsigned write_count = 5;
    ae3d_vk_texture *texture;
    ae3d_vk_texture *normal;
    ae3d_vk_texture *poses;
    int index;

    int reuse = -1;

    if (normal_handle < 1 || normal_handle > AE3D_VK_MAX_TEXTURES ||
        !vk.textures[normal_handle - 1].in_use) {
        normal_handle = vk.default_texture;
    }
    /* Binding 4 is whichever auxiliary image the draw needs: a crowd's pose
       bank by its texture handle, or the camera depth for a water surface,
       asked for as AE3D_VK_AUX_SCENE_DEPTH. */
    if (bank_handle == AE3D_VK_AUX_SCENE_DEPTH) {
        if (!vk.camdepth_view || !vk.camdepth_sampler) bank_handle = vk.default_texture;
    } else if (bank_handle < 1 || bank_handle > AE3D_VK_MAX_TEXTURES ||
               !vk.textures[bank_handle - 1].in_use) {
        bank_handle = vk.default_texture;
    }
    for (index = 0; index < vk.set_count[frame]; index++) {
        if (vk.set_texture[frame][index] == texture_handle &&
            vk.set_normal[frame][index] == normal_handle &&
            vk.set_bank[frame][index] == bank_handle) return vk.sets[frame][index];
        /* Left behind by a texture that was destroyed. The set is still
           allocated and can be written again, which is what keeps a scene that
           swaps textures from exhausting the pool. */
        if (vk.set_texture[frame][index] == AE3D_VK_SET_FREE && reuse < 0) reuse = index;
    }
    if (reuse < 0 && vk.set_count[frame] >= AE3D_VK_MAX_TEXTURES) return VK_NULL_HANDLE;

    texture = &vk.textures[texture_handle - 1];
    if (!texture->in_use) return VK_NULL_HANDLE;
    normal = &vk.textures[normal_handle - 1];
    poses = bank_handle == AE3D_VK_AUX_SCENE_DEPTH ? NULL : &vk.textures[bank_handle - 1];

    if (reuse >= 0) {
        set = vk.sets[frame][reuse];
    } else {
        memset(&allocation, 0, sizeof(allocation));
        allocation.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        allocation.descriptorPool = vk.descriptor_pool;
        allocation.descriptorSetCount = 1;
        allocation.pSetLayouts = &vk.set_layout;
        if (ae3d_vkAllocateDescriptorSets(vk.device, &allocation, &set) != VK_SUCCESS) {
            return VK_NULL_HANDLE;
        }
    }

    memset(&buffer, 0, sizeof(buffer));
    buffer.buffer = vk.uniforms[frame].buffer;
    buffer.offset = 0;
    buffer.range = AE3D_VK_SCENE_SIZE;

    memset(&image, 0, sizeof(image));
    image.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    image.imageView = texture->view;
    image.sampler = texture->sampler;

    memset(writes, 0, sizeof(writes));
    writes[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[0].dstSet = set;
    writes[0].dstBinding = 0;
    writes[0].descriptorCount = 1;
    writes[0].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC;
    writes[0].pBufferInfo = &buffer;
    writes[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[1].dstSet = set;
    writes[1].dstBinding = 1;
    writes[1].descriptorCount = 1;
    writes[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writes[1].pImageInfo = &image;

    memset(&bumps, 0, sizeof(bumps));
    bumps.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    bumps.imageView = normal->view;
    bumps.sampler = normal->sampler;
    writes[3].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[3].dstSet = set;
    writes[3].dstBinding = 3;
    writes[3].descriptorCount = 1;
    writes[3].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writes[3].pImageInfo = &bumps;

    // Binding 2 is the shadow map. With shadows off it holds the default white
    // texture, which reads as nothing occluded.
    memset(&shadow, 0, sizeof(shadow));
    shadow.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    if (vk.shadow_enabled && vk.shadow_view) {
        shadow.imageView = vk.shadow_view;
        shadow.sampler = vk.shadow_sampler;
    } else {
        shadow.imageView = vk.textures[vk.default_texture - 1].view;
        shadow.sampler = vk.textures[vk.default_texture - 1].sampler;
    }

    writes[2].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[2].dstSet = set;
    writes[2].dstBinding = 2;
    writes[2].descriptorCount = 1;
    writes[2].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writes[2].pImageInfo = &shadow;

    // Binding 4 is the pose bank the crowd vertex shader reads its bones
    // from; a draw that is not a crowd binds the default texture there and
    // never samples it.
    memset(&bank, 0, sizeof(bank));
    bank.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    if (poses) {
        bank.imageView = poses->view;
        bank.sampler = poses->sampler;
    } else {
        bank.imageView = vk.camdepth_view;
        bank.sampler = vk.camdepth_sampler;
    }
    writes[4].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[4].dstSet = set;
    writes[4].dstBinding = 4;
    writes[4].descriptorCount = 1;
    writes[4].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writes[4].pImageInfo = &bank;

    /* Binding 5 is the scene's acceleration structure, this frame's: what
       the fragment traces its rays through where the device traces. */
    if (vk.ray_query && vk.tlas[frame]) {
        memset(&structure, 0, sizeof(structure));
        structure.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_ACCELERATION_STRUCTURE_KHR;
        structure.accelerationStructureCount = 1;
        structure.pAccelerationStructures = &vk.tlas[frame];
        writes[5].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writes[5].pNext = &structure;
        writes[5].dstSet = set;
        writes[5].dstBinding = 5;
        writes[5].descriptorCount = 1;
        writes[5].descriptorType = VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR;
        write_count = 6;
    }
    /* Binding 8 is the lamps' shadow atlas, or the default texture before
       it is made; the shader reads it only where a lamp has a slot. */
    memset(&lamps, 0, sizeof(lamps));
    lamps.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    if (vk.lamp_view) {
        lamps.imageView = vk.lamp_view;
        lamps.sampler = vk.lamp_sampler;
    } else {
        lamps.imageView = vk.textures[vk.default_texture - 1].view;
        lamps.sampler = vk.textures[vk.default_texture - 1].sampler;
    }
    writes[write_count].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[write_count].dstSet = set;
    writes[write_count].dstBinding = 8;
    writes[write_count].descriptorCount = 1;
    writes[write_count].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writes[write_count].pImageInfo = &lamps;
    write_count++;
    ae3d_vkUpdateDescriptorSets(vk.device, write_count, writes, 0, NULL);
    ae3d_vk_write_clusters(set, frame);

    index = reuse >= 0 ? reuse : vk.set_count[frame]++;
    vk.sets[frame][index] = set;
    vk.set_texture[frame][index] = texture_handle;
    vk.set_normal[frame][index] = normal_handle;
    vk.set_bank[frame][index] = bank_handle;
    return set;
}

void ae3d_vk_scene_set_float(int offset, double value) {
    ae3d_vk_set_float(&vk.scene[vk.program], offset, (float)value);
}

void ae3d_vk_scene_set_int(int offset, int value) {
    ae3d_vk_set_int(&vk.scene[vk.program], offset, value);
}

void ae3d_vk_scene_set_vec3(int offset, double x, double y, double z) {
    ae3d_vk_set_vec3(&vk.scene[vk.program], offset, x, y, z);
}

void ae3d_vk_scene_set_mat4(int offset, const double *m) {
    if (!m) return;
    ae3d_vk_set_mat4(&vk.scene[vk.program], offset, m);
}

/* The bone palette, which is already the floats the block wants: std140 gives
   a mat4 array a stride of 64 bytes, which is the matrix itself, so the run
   copies whole rather than a matrix at a time. */
void ae3d_vk_scene_set_mat4v(int offset, int count, const void *values) {
    ae3d_vk_scene *block = &vk.scene[vk.program];
    size_t bytes = (size_t)count * 16 * sizeof(float);
    if (!values || count <= 0 || offset < 0) return;
    if ((size_t)offset + bytes > sizeof(block->bytes)) return;
    memcpy(block->bytes + offset, values, bytes);
}

// Vulkan clip space puts y downward and z in [0, 1] while the engine's matrices
// are OpenGL-shaped, so the correction is folded in here rather than making
// every caller keep two projections. It applies to whichever matrix reaches
// clip space last, the combined view-projection for the scene and the
// projection alone for the skybox, which multiplies the two in the shader.
void ae3d_vk_scene_set_clip_mat4(int offset, const double *m) {
    double corrected[16];
    int column;
    if (!m) return;
    for (column = 0; column < 4; column++) {
        corrected[column * 4 + 0] = m[column * 4 + 0];
        corrected[column * 4 + 1] = -m[column * 4 + 1];
        corrected[column * 4 + 2] = 0.5 * (m[column * 4 + 2] + m[column * 4 + 3]);
        corrected[column * 4 + 3] = m[column * 4 + 3];
    }
    ae3d_vk_set_mat4(&vk.scene[vk.program], offset, corrected);
}

/* The inverse of the clip-corrected view-projection, for the SSR shader to
 * rebuild a world position from a screen pixel and its depth. It must invert
 * the SAME matrix the vertex stage used (the corrected one above, mapping world
 * to Vulkan NDC: y down, z in 0..1), so the correction is applied first and the
 * result inverted. Column-major throughout, matching the rest of the block. */
/* The Vulkan clip correction (y down, z in 0..1) applied to a column-major
   OpenGL-shaped matrix that reaches clip space. */
static void ae3d_vk_clip_correct(const double *m, double *c) {
    int column;
    for (column = 0; column < 4; column++) {
        c[column * 4 + 0] = m[column * 4 + 0];
        c[column * 4 + 1] = -m[column * 4 + 1];
        c[column * 4 + 2] = 0.5 * (m[column * 4 + 2] + m[column * 4 + 3]);
        c[column * 4 + 3] = m[column * 4 + 3];
    }
}

/* out = a * b, column-major. */
static void ae3d_vk_mat4_mul(const double *a, const double *b, double *out) {
    int r, c, k;
    for (c = 0; c < 4; c++) {
        for (r = 0; r < 4; r++) {
            double sum = 0.0;
            for (k = 0; k < 4; k++) sum += a[k * 4 + r] * b[c * 4 + k];
            out[c * 4 + r] = sum;
        }
    }
}

/* The inverse of a column-major matrix; 0 when it has none. */
static int ae3d_vk_mat4_invert(const double *c, double *inv) {
    double det;
    int i;
    inv[0]  =  c[5]*c[10]*c[15] - c[5]*c[11]*c[14] - c[9]*c[6]*c[15] + c[9]*c[7]*c[14] + c[13]*c[6]*c[11] - c[13]*c[7]*c[10];
    inv[4]  = -c[4]*c[10]*c[15] + c[4]*c[11]*c[14] + c[8]*c[6]*c[15] - c[8]*c[7]*c[14] - c[12]*c[6]*c[11] + c[12]*c[7]*c[10];
    inv[8]  =  c[4]*c[9]*c[15]  - c[4]*c[11]*c[13] - c[8]*c[5]*c[15] + c[8]*c[7]*c[13] + c[12]*c[5]*c[11] - c[12]*c[7]*c[9];
    inv[12] = -c[4]*c[9]*c[14]  + c[4]*c[10]*c[13] + c[8]*c[5]*c[14] - c[8]*c[6]*c[13] - c[12]*c[5]*c[10] + c[12]*c[6]*c[9];
    inv[1]  = -c[1]*c[10]*c[15] + c[1]*c[11]*c[14] + c[9]*c[2]*c[15] - c[9]*c[3]*c[14] - c[13]*c[2]*c[11] + c[13]*c[3]*c[10];
    inv[5]  =  c[0]*c[10]*c[15] - c[0]*c[11]*c[14] - c[8]*c[2]*c[15] + c[8]*c[3]*c[14] + c[12]*c[2]*c[11] - c[12]*c[3]*c[10];
    inv[9]  = -c[0]*c[9]*c[15]  + c[0]*c[11]*c[13] + c[8]*c[1]*c[15] - c[8]*c[3]*c[13] - c[12]*c[1]*c[11] + c[12]*c[3]*c[9];
    inv[13] =  c[0]*c[9]*c[14]  - c[0]*c[10]*c[13] - c[8]*c[1]*c[14] + c[8]*c[2]*c[13] + c[12]*c[1]*c[10] - c[12]*c[2]*c[9];
    inv[2]  =  c[1]*c[6]*c[15]  - c[1]*c[7]*c[14]  - c[5]*c[2]*c[15] + c[5]*c[3]*c[14] + c[13]*c[2]*c[7]  - c[13]*c[3]*c[6];
    inv[6]  = -c[0]*c[6]*c[15]  + c[0]*c[7]*c[14]  + c[4]*c[2]*c[15] - c[4]*c[3]*c[14] - c[12]*c[2]*c[7]  + c[12]*c[3]*c[6];
    inv[10] =  c[0]*c[5]*c[15]  - c[0]*c[7]*c[13]  - c[4]*c[1]*c[15] + c[4]*c[3]*c[13] + c[12]*c[1]*c[7]  - c[12]*c[3]*c[5];
    inv[14] = -c[0]*c[5]*c[14]  + c[0]*c[6]*c[13]  + c[4]*c[1]*c[14] - c[4]*c[2]*c[13] - c[12]*c[1]*c[6]  + c[12]*c[2]*c[5];
    inv[3]  = -c[1]*c[6]*c[11]  + c[1]*c[7]*c[10]  + c[5]*c[2]*c[11] - c[5]*c[3]*c[10] - c[9]*c[2]*c[7]   + c[9]*c[3]*c[6];
    inv[7]  =  c[0]*c[6]*c[11]  - c[0]*c[7]*c[10]  - c[4]*c[2]*c[11] + c[4]*c[3]*c[10] + c[8]*c[2]*c[7]   - c[8]*c[3]*c[6];
    inv[11] = -c[0]*c[5]*c[11]  + c[0]*c[7]*c[9]   + c[4]*c[1]*c[11] - c[4]*c[3]*c[9]  - c[8]*c[1]*c[7]   + c[8]*c[3]*c[5];
    inv[15] =  c[0]*c[5]*c[10]  - c[0]*c[6]*c[9]   - c[4]*c[1]*c[10] + c[4]*c[2]*c[9]  + c[8]*c[1]*c[6]   - c[8]*c[2]*c[5];
    det = c[0]*inv[0] + c[1]*inv[4] + c[2]*inv[8] + c[3]*inv[12];
    if (det > -1e-12 && det < 1e-12) return 0;
    det = 1.0 / det;
    for (i = 0; i < 16; i++) inv[i] *= det;
    return 1;
}

void ae3d_vk_scene_set_inv_viewproj(int offset, const double *m) {
    double c[16], inv[16];
    if (!m) return;
    ae3d_vk_clip_correct(m, c);
    if (!ae3d_vk_mat4_invert(c, inv)) { ae3d_vk_set_mat4(&vk.scene[vk.program], offset, c); return; }
    ae3d_vk_set_mat4(&vk.scene[vk.program], offset, inv);
}

// A model's own uniforms arrive by name. The offset is resolved once and cached
// on the uniform, so the strcmp walk happens the first time a name is seen and
// never again.
int ae3d_vk_scene_offset(const char *name) {
    return ae3d_vk_uniform_offset(name);
}

/* A float array as ae3d.core lays one out (FloatValues): the values, 32-bit,
   then their count. Read here directly: the arrays are Aether's (#398). */
typedef struct {
    float *values;
    int count;
} ae3d_farr;

static int ae3d_farr_count(void *handle) { return handle ? ((ae3d_farr *)handle)->count : 0; }

static double ae3d_farr_get(void *handle, int i) {
    ae3d_farr *arr = (ae3d_farr *)handle;
    if (!arr || i < 0 || i >= arr->count) return 0.0;
    return arr->values[i];
}

// std140 gives every array element a 16-byte slot whatever it holds, so a wave
// table cannot be memcpy'd in as a flat run of floats.
void ae3d_vk_scene_set_float_array(int offset, void *handle) {
    int count = ae3d_farr_count(handle);
    int i;
    if (offset < 0 || count <= 0) return;
    for (i = 0; i < count; i++) {
        ae3d_vk_set_float(&vk.scene[vk.program], offset + i * 16, (float)ae3d_farr_get(handle, i));
    }
}

void ae3d_vk_scene_set_vec3_array(int offset, void *handle) {
    int count = ae3d_farr_count(handle) / 3;
    int i;
    if (offset < 0 || count <= 0) return;
    for (i = 0; i < count; i++) {
        ae3d_vk_set_vec3(&vk.scene[vk.program], offset + i * 16, ae3d_farr_get(handle, i * 3),
                         ae3d_farr_get(handle, i * 3 + 1), ae3d_farr_get(handle, i * 3 + 2));
    }
}

void ae3d_vk_set_blend(int on) { vk.blend = on; }

/* Which normal map the next draws use. Renderer state rather than a draw
   argument, the way the blend and the program already are: a material sets it
   once and every draw of that material reads it. */
void ae3d_vk_set_normal_map(int handle) { vk.normal_map = handle; }

// Every pipeline shares the scene's vertex input and descriptor set layout, so
// a pass differs only in its shaders and its depth and blend state. Attributes a
// shader ignores cost nothing, which is why the fullscreen and skybox passes can
// be described by the same vertex input as the scene.
static VkPipeline ae3d_vk_build_pipeline(VkShaderModule vertex_module,
                                        VkShaderModule fragment_module, int blend,
                                        int depth_test, int depth_write,
                                        VkRenderPass render_pass, int cull,
                                        int skinned, int points) {
    VkPipelineShaderStageCreateInfo stages[2];
    VkVertexInputBindingDescription bindings[3];
    VkVertexInputAttributeDescription attributes[12];
    VkPipelineVertexInputStateCreateInfo vertex_input;
    VkPipelineInputAssemblyStateCreateInfo assembly;
    VkPipelineViewportStateCreateInfo viewport_state;
    VkPipelineRasterizationStateCreateInfo raster;
    VkPipelineMultisampleStateCreateInfo multisample;
    VkPipelineDepthStencilStateCreateInfo depth;
    VkPipelineColorBlendAttachmentState blend_attachment, blend_attachments[2];
    VkPipelineColorBlendStateCreateInfo colour_blend;
    VkPipelineDynamicStateCreateInfo dynamic;
    VkDynamicState dynamic_states[2];
    VkGraphicsPipelineCreateInfo info;
    VkPipeline pipeline = VK_NULL_HANDLE;
    int i;

    memset(bindings, 0, sizeof(bindings));
    memset(stages, 0, sizeof(stages));
    stages[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    stages[0].module = vertex_module;
    stages[0].pName = "main";
    stages[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    stages[1].module = fragment_module;
    stages[1].pName = "main";

    // Binding 0 is the mesh, binding 1 is the per-instance matrix and colour,
    // the same split the OpenGL backend uses for its instanced attributes.
    memset(bindings, 0, sizeof(bindings));
    bindings[0].binding = 0;
    bindings[0].stride = AE3D_VK_STRIDE;
    bindings[0].inputRate = VK_VERTEX_INPUT_RATE_VERTEX;
    bindings[1].binding = 1;
    bindings[1].stride = 16 * (unsigned)sizeof(float) + 4 * (unsigned)sizeof(float);
    /* Points: position and scale, colour, phase -- eight floats. The matrix's
       other three columns are named at offset zero, since the input has to
       describe every attribute the shader declares, and a point draw never
       reads them. */
    if (points) bindings[1].stride = 8 * (unsigned)sizeof(float);
    bindings[1].inputRate = VK_VERTEX_INPUT_RATE_INSTANCE;

    memset(attributes, 0, sizeof(attributes));
    attributes[0].location = 0;
    attributes[0].binding = 0;
    attributes[0].format = VK_FORMAT_R32G32B32_SFLOAT;
    attributes[0].offset = 0;
    attributes[1].location = 1;
    attributes[1].binding = 0;
    attributes[1].format = VK_FORMAT_R32G32_SFLOAT;
    attributes[1].offset = 3 * (unsigned)sizeof(float);
    attributes[2].location = 2;
    attributes[2].binding = 0;
    attributes[2].format = VK_FORMAT_R32G32B32_SFLOAT;
    attributes[2].offset = 5 * (unsigned)sizeof(float);
    /* Baked occlusion, in the vertex rather than a binding of its own, so no
       pipeline has to know whether a mesh has any. */
    attributes[10].location = 10;
    attributes[10].binding = 0;
    attributes[10].format = VK_FORMAT_R32_SFLOAT;
    attributes[10].offset = 8 * (unsigned)sizeof(float);
    for (i = 0; i < 4; i++) {
        attributes[3 + i].location = (unsigned)(3 + i);
        attributes[3 + i].binding = 1;
        attributes[3 + i].format = VK_FORMAT_R32G32B32A32_SFLOAT;
        attributes[3 + i].offset = points ? 0u : (unsigned)(i * 4 * (int)sizeof(float));
    }
    attributes[7].location = 7;
    attributes[7].binding = 1;
    attributes[7].format = VK_FORMAT_R32G32B32_SFLOAT;
    attributes[7].offset = (points ? 4u : 16u) * (unsigned)sizeof(float);
    /* The instance's phase in its walk, in the float after its colour that
       the stream always carried and nothing read. Every pipeline names it;
       only the crowd's shaders read it. */
    attributes[11].location = 11;
    attributes[11].binding = 1;
    attributes[11].format = VK_FORMAT_R32_SFLOAT;
    attributes[11].offset = (points ? 7u : 19u) * (unsigned)sizeof(float);

    /* Vulkan has no equivalent of leaving an attribute disabled: the vertex
       input has to describe every input the shader reads, and one shader
       serves both kinds of draw. So both pipelines name the binding, and what
       differs is the stride -- the skinned one steps through a joint and
       weight per vertex, the plain one strides zero and every vertex reads the
       same unused element out of a buffer that is one element long. That is
       what makes an unskinned mesh cost nothing: no skin buffer, no allocation
       that scales with the mesh, and a branch the shader does not take. */
    bindings[2].binding = 2;
    bindings[2].stride = skinned ? AE3D_VK_SKIN_STRIDE : 0;
    bindings[2].inputRate = VK_VERTEX_INPUT_RATE_VERTEX;
    attributes[8].location = 8;
    attributes[8].binding = 2;
    attributes[8].format = VK_FORMAT_R32G32B32A32_SFLOAT;
    attributes[8].offset = 0;
    attributes[9].location = 9;
    attributes[9].binding = 2;
    attributes[9].format = VK_FORMAT_R32G32B32A32_SFLOAT;
    attributes[9].offset = 4 * (unsigned)sizeof(float);

    memset(&vertex_input, 0, sizeof(vertex_input));
    vertex_input.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    vertex_input.vertexBindingDescriptionCount = 3;
    vertex_input.pVertexBindingDescriptions = bindings;
    vertex_input.vertexAttributeDescriptionCount = 12;
    vertex_input.pVertexAttributeDescriptions = attributes;

    memset(&assembly, 0, sizeof(assembly));
    assembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    assembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    memset(&viewport_state, 0, sizeof(viewport_state));
    viewport_state.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewport_state.viewportCount = 1;
    viewport_state.scissorCount = 1;

    memset(&raster, 0, sizeof(raster));
    raster.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    raster.polygonMode = VK_POLYGON_MODE_FILL;
    raster.cullMode = cull ? VK_CULL_MODE_BACK_BIT : VK_CULL_MODE_NONE;
    raster.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
    raster.lineWidth = 1.0f;

    memset(&multisample, 0, sizeof(multisample));
    multisample.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    multisample.rasterizationSamples = vk.samples;
    /* Every pass but the scene's draws single-sampled: the post passes
       (the composite, and the one the SSR and the temporal pass share), the
       shadow map and the camera depth. The temporal pass's pipeline, made
       against the SSR's pass with the scene's four samples, drew into a
       one-sample target on every frame the validation layer watched (#405). */
    if (render_pass == vk.post_pass || render_pass == vk.ssr_pass || render_pass == vk.shadow_pass ||
        render_pass == vk.camdepth_pass) {
        multisample.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;
    }

    memset(&depth, 0, sizeof(depth));
    depth.sType = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
    depth.depthTestEnable = depth_test ? VK_TRUE : VK_FALSE;
    depth.depthWriteEnable = depth_write ? VK_TRUE : VK_FALSE;
    depth.depthCompareOp = VK_COMPARE_OP_LESS_OR_EQUAL;
    depth.maxDepthBounds = 1.0f;

    memset(&blend_attachment, 0, sizeof(blend_attachment));
    blend_attachment.blendEnable = blend ? VK_TRUE : VK_FALSE;
    blend_attachment.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA;
    blend_attachment.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
    /* 2 is a multiply: what is drawn scales what is there, which is how the
       occlusion pass darkens the opaque scene under it. */
    if (blend == 2) {
        blend_attachment.srcColorBlendFactor = VK_BLEND_FACTOR_DST_COLOR;
        blend_attachment.dstColorBlendFactor = VK_BLEND_FACTOR_ZERO;
    }
    blend_attachment.colorBlendOp = VK_BLEND_OP_ADD;
    blend_attachment.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE;
    blend_attachment.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO;
    blend_attachment.alphaBlendOp = VK_BLEND_OP_ADD;
    blend_attachment.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
                                      VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;

    /* The second attachment is the scene pass's motion vectors: written
       as they are, never blended, by every draw that has them -- the
       occlusion composite (the multiply) draws over the scene with no
       motion of its own, and its writes are masked off. */
    blend_attachments[0] = blend_attachment;
    memset(&blend_attachments[1], 0, sizeof(blend_attachments[1]));
    blend_attachments[1].colorWriteMask = blend == 2 ? 0
                                        : (VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT);

    memset(&colour_blend, 0, sizeof(colour_blend));
    colour_blend.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    // As many blend attachments as the subpass has colour attachments, which
    // for the shadow pass is none: it writes depth and nothing else; the
    // scene pass has its colour and its motion vectors.
    colour_blend.attachmentCount = (render_pass == vk.shadow_pass || render_pass == vk.camdepth_pass) ? 0
                                 : (render_pass == vk.render_pass ? 2 : 1);
    colour_blend.pAttachments = blend_attachments;

    dynamic_states[0] = VK_DYNAMIC_STATE_VIEWPORT;
    dynamic_states[1] = VK_DYNAMIC_STATE_SCISSOR;
    memset(&dynamic, 0, sizeof(dynamic));
    dynamic.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    dynamic.dynamicStateCount = 2;
    dynamic.pDynamicStates = dynamic_states;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    info.stageCount = 2;
    info.pStages = stages;
    info.pVertexInputState = &vertex_input;
    info.pInputAssemblyState = &assembly;
    info.pViewportState = &viewport_state;
    info.pRasterizationState = &raster;
    info.pMultisampleState = &multisample;
    info.pDepthStencilState = render_pass == vk.post_pass ? NULL : &depth;
    info.pColorBlendState = &colour_blend;
    info.pDynamicState = &dynamic;
    info.layout = vk.pipeline_layout;
    info.renderPass = render_pass;
    info.subpass = 0;

    if (ae3d_vkCreateGraphicsPipelines(vk.device, VK_NULL_HANDLE, 1, &info, NULL, &pipeline) != VK_SUCCESS) {
        return VK_NULL_HANDLE;
    }
    return pipeline;
}

// The sky is drawn behind everything with depth writes off, and the composite
// passes have no depth at all, matching what the OpenGL backend sets by hand.
// Only the passthrough composite is required: an effect that fails to build
// falls back to it and the scene still reaches the screen, which is what the
// OpenGL backend does when one of its effect programs fails to compile.
static int ae3d_vk_create_pass_pipelines(void) {
    struct { const unsigned char *vert; unsigned vert_size;
             const unsigned char *frag; unsigned frag_size;
             int blend, depth_test, depth_write, required, cull;
             VkRenderPass pass; VkPipeline *out; } builds[] = {
        { ae3d_vk_sky_vert_spv, sizeof(ae3d_vk_sky_vert_spv),
          ae3d_vk_sky_frag_spv, sizeof(ae3d_vk_sky_frag_spv),
          0, 1, 0, 0, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_screen_vert_spv, sizeof(ae3d_vk_screen_vert_spv),
          ae3d_vk_passthrough_frag_spv, sizeof(ae3d_vk_passthrough_frag_spv),
          0, 0, 0, 1, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_screen_vert_spv, sizeof(ae3d_vk_screen_vert_spv),
          ae3d_vk_fxaa_frag_spv, sizeof(ae3d_vk_fxaa_frag_spv),
          0, 0, 0, 0, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_screen_vert_spv, sizeof(ae3d_vk_screen_vert_spv),
          ae3d_vk_bloom_frag_spv, sizeof(ae3d_vk_bloom_frag_spv),
          0, 0, 0, 0, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_depth_vert_spv, sizeof(ae3d_vk_depth_vert_spv),
          ae3d_vk_depth_frag_spv, sizeof(ae3d_vk_depth_frag_spv),
          0, 1, 1, 1, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_water_vert_spv, sizeof(ae3d_vk_water_vert_spv),
          ae3d_vk_water_frag_spv, sizeof(ae3d_vk_water_frag_spv),
          0, 1, 1, 1, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_water_vert_spv, sizeof(ae3d_vk_water_vert_spv),
          ae3d_vk_water_frag_spv, sizeof(ae3d_vk_water_frag_spv),
          1, 1, 0, 1, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_water_vert_spv, sizeof(ae3d_vk_water_vert_spv),
          ae3d_vk_water_frag_spv, sizeof(ae3d_vk_water_frag_spv),
          0, 1, 1, 1, 1, VK_NULL_HANDLE, NULL },
        { ae3d_vk_depth_vert_spv, sizeof(ae3d_vk_depth_vert_spv),
          ae3d_vk_depth_frag_spv, sizeof(ae3d_vk_depth_frag_spv),
          0, 1, 1, 1, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_screen_vert_spv, sizeof(ae3d_vk_screen_vert_spv),
          ae3d_vk_ssr_frag_spv, sizeof(ae3d_vk_ssr_frag_spv),
          0, 0, 0, 0, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_crowd_depth_vert_spv, sizeof(ae3d_vk_crowd_depth_vert_spv),
          ae3d_vk_depth_frag_spv, sizeof(ae3d_vk_depth_frag_spv),
          0, 1, 1, 0, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_screen_vert_spv, sizeof(ae3d_vk_screen_vert_spv),
          ae3d_vk_ssao_frag_spv, sizeof(ae3d_vk_ssao_frag_spv),
          2, 0, 0, 0, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_depth_vert_spv, sizeof(ae3d_vk_depth_vert_spv),
          ae3d_vk_depth_frag_spv, sizeof(ae3d_vk_depth_frag_spv),
          0, 1, 1, 0, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_screen_vert_spv, sizeof(ae3d_vk_screen_vert_spv),
          ae3d_vk_depth_resolve_frag_spv, sizeof(ae3d_vk_depth_resolve_frag_spv),
          0, 1, 1, 0, 0, VK_NULL_HANDLE, NULL },
        { ae3d_vk_screen_vert_spv, sizeof(ae3d_vk_screen_vert_spv),
          ae3d_vk_taa_frag_spv, sizeof(ae3d_vk_taa_frag_spv),
          0, 0, 0, 0, 0, VK_NULL_HANDLE, NULL },
    };
    unsigned i;

    builds[0].pass = vk.render_pass; builds[0].out = &vk.sky_pipeline;
    builds[1].pass = vk.post_pass;   builds[1].out = &vk.post_pipelines[0];
    builds[2].pass = vk.post_pass;   builds[2].out = &vk.post_pipelines[1];
    builds[3].pass = vk.post_pass;   builds[3].out = &vk.post_pipelines[2];
    builds[4].pass = vk.shadow_pass; builds[4].out = &vk.shadow_pipeline;
    builds[8].pass = vk.shadow_pass; builds[8].out = &vk.skinned_shadow_pipeline;
    builds[5].pass = vk.render_pass; builds[5].out = &vk.water_pipeline[0];
    builds[6].pass = vk.render_pass; builds[6].out = &vk.water_pipeline_blend;
    builds[7].pass = vk.render_pass; builds[7].out = &vk.water_pipeline[1];
    builds[9].pass = vk.post_pass;   builds[9].out = &vk.post_pipelines[3];
    builds[10].pass = vk.shadow_pass; builds[10].out = &vk.crowd_shadow_pipeline;
    builds[11].pass = vk.render_pass; builds[11].out = &vk.ssao_pipeline;
    builds[12].pass = vk.shadow_pass; builds[12].out = &vk.point_shadow_pipeline;
    /* The depth resolve draws into the camera-depth pass, depth only, from
       the frame's multisampled depth -- or a plain copy of it when the
       frame has one sample. */
    if (vk.samples == VK_SAMPLE_COUNT_1_BIT) {
        builds[13].frag = ae3d_vk_depth_copy_frag_spv;
        builds[13].frag_size = sizeof(ae3d_vk_depth_copy_frag_spv);
    }
    builds[13].pass = vk.camdepth_pass; builds[13].out = &vk.depth_resolve_pipeline;
    builds[14].pass = vk.ssr_pass; builds[14].out = &vk.taa_pipeline;

    for (i = 0; i < sizeof(builds) / sizeof(builds[0]); i++) {
        VkShaderModule vertex_module = ae3d_vk_shader(builds[i].vert, builds[i].vert_size);
        VkShaderModule fragment_module = ae3d_vk_shader(builds[i].frag, builds[i].frag_size);
        if (!vertex_module || !fragment_module) return ae3d_vk_fail("pass vkCreateShaderModule failed");
        int skinned = (builds[i].out == &vk.skinned_shadow_pipeline
                       || builds[i].out == &vk.crowd_shadow_pipeline);
        int points = builds[i].out == &vk.point_shadow_pipeline;
        *builds[i].out = ae3d_vk_build_pipeline(vertex_module, fragment_module, builds[i].blend,
                                                builds[i].depth_test, builds[i].depth_write,
                                                builds[i].pass, builds[i].cull, skinned, points);
        ae3d_vkDestroyShaderModule(vk.device, vertex_module, NULL);
        ae3d_vkDestroyShaderModule(vk.device, fragment_module, NULL);
        if (!*builds[i].out && builds[i].required) {
            return ae3d_vk_fail("pass vkCreateGraphicsPipelines failed");
        }
    }
    return 1;
}

static int ae3d_vk_create_pipeline(void) {
    VkShaderModule vertex_module, fragment_module;
    VkPipelineLayoutCreateInfo layout;
    int cull;

    vertex_module = ae3d_vk_shader(ae3d_vk_scene_vert_spv, (unsigned)sizeof(ae3d_vk_scene_vert_spv));
    /* The fragment that traces its shadow rays where the device traces;
       the same source without them everywhere else. */
    if (vk.ray_query) {
        fragment_module = ae3d_vk_shader(ae3d_vk_scene_rq_frag_spv, (unsigned)sizeof(ae3d_vk_scene_rq_frag_spv));
    } else {
        fragment_module = ae3d_vk_shader(ae3d_vk_scene_frag_spv, (unsigned)sizeof(ae3d_vk_scene_frag_spv));
    }
    if (!vertex_module || !fragment_module) return ae3d_vk_fail("scene vkCreateShaderModule failed");

    memset(&layout, 0, sizeof(layout));
    layout.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    layout.setLayoutCount = 1;
    layout.pSetLayouts = &vk.set_layout;
    if (ae3d_vkCreatePipelineLayout(vk.device, &layout, NULL, &vk.pipeline_layout) != VK_SUCCESS) {
        ae3d_vkDestroyShaderModule(vk.device, vertex_module, NULL);
        ae3d_vkDestroyShaderModule(vk.device, fragment_module, NULL);
        return ae3d_vk_fail("vkCreatePipelineLayout failed");
    }

    // A transparent surface is never culled: you see through it to its own far
    // side, so removing that side removes something the frame should show. The
    // OpenGL backend turns culling off for the transparent pass for the same
    // reason, which is why only the opaque pipeline comes in two variants.
    vk.pipeline_blend = ae3d_vk_build_pipeline(vertex_module, fragment_module, 1, 1, 0,
                                               vk.render_pass, 0, 0, 0);
    vk.skinned_pipeline_blend = ae3d_vk_build_pipeline(vertex_module, fragment_module, 1, 1, 0,
                                                       vk.render_pass, 0, 1, 0);
    for (cull = 0; cull < 2; cull++) {
        vk.pipeline[cull] = ae3d_vk_build_pipeline(vertex_module, fragment_module, 1, 1, 1,
                                                   vk.render_pass, cull, 0, 0);
        vk.skinned_pipeline[cull] = ae3d_vk_build_pipeline(vertex_module, fragment_module, 1, 1, 1,
                                                           vk.render_pass, cull, 1, 0);
        if (!vk.pipeline[cull] || !vk.skinned_pipeline[cull]) {
            ae3d_vkDestroyShaderModule(vk.device, vertex_module, NULL);
            ae3d_vkDestroyShaderModule(vk.device, fragment_module, NULL);
            return ae3d_vk_fail("vkCreateGraphicsPipelines failed");
        }
    }
    if (!vk.pipeline_blend || !vk.skinned_pipeline_blend) {
        ae3d_vkDestroyShaderModule(vk.device, vertex_module, NULL);
        ae3d_vkDestroyShaderModule(vk.device, fragment_module, NULL);
        return ae3d_vk_fail("vkCreateGraphicsPipelines failed");
    }
    /* Points: not required, a device that will not build them draws a point
       stream through the matrix pipelines, at the stride of a matrix, which
       is wrong but not a crash; the parity test says which it is. */
    vk.point_pipeline_blend = ae3d_vk_build_pipeline(vertex_module, fragment_module, 1, 1, 0,
                                                     vk.render_pass, 0, 0, 1);
    for (cull = 0; cull < 2; cull++) {
        vk.point_pipeline[cull] = ae3d_vk_build_pipeline(vertex_module, fragment_module, 1, 1, 1,
                                                         vk.render_pass, cull, 0, 1);
    }
    ae3d_vkDestroyShaderModule(vk.device, vertex_module, NULL);

    // The crowd: the same fragment shader after a vertex shader that poses
    // each instance from the pose bank. Not required: a device that will not
    // build it draws a crowd unposed instead of not at all.
    vertex_module = ae3d_vk_shader(ae3d_vk_crowd_vert_spv, (unsigned)sizeof(ae3d_vk_crowd_vert_spv));
    if (vertex_module) {
        vk.crowd_pipeline_blend = ae3d_vk_build_pipeline(vertex_module, fragment_module, 1, 1, 0,
                                                         vk.render_pass, 0, 1, 0);
        for (cull = 0; cull < 2; cull++) {
            vk.crowd_pipeline[cull] = ae3d_vk_build_pipeline(vertex_module, fragment_module, 1, 1, 1,
                                                             vk.render_pass, cull, 1, 0);
        }
        ae3d_vkDestroyShaderModule(vk.device, vertex_module, NULL);
    }
    ae3d_vkDestroyShaderModule(vk.device, fragment_module, NULL);
    return ae3d_vk_create_pass_pipelines();
}

/* What makes a scene texture from RGBA bytes: ae3d.vktexture's, installed by
   the renderer before the backend starts (textures are made in Aether, #402)
   and kept across it, since the default texture is made while it starts. */
static int (*g_texture_maker)(int, int, const void *) = NULL;

void ae3d_vk_set_texture_maker(void *maker) {
    g_texture_maker = (int (*)(int, int, const void *))maker;
}

// A white pixel and one identity instance, so a draw with no texture and no
// instance buffer still has something to bind: the shader always samples and
// always reads an instance matrix.
static int ae3d_vk_create_defaults(void) {
    unsigned char white[4];
    float identity[20];
    int i;

    white[0] = 255; white[1] = 255; white[2] = 255; white[3] = 255;
    if (!g_texture_maker) return ae3d_vk_fail("no texture maker (ae3d.vktexture installs one)");
    vk.default_texture = g_texture_maker(1, 1, white);
    if (!vk.default_texture) return ae3d_vk_fail("could not create the default texture");

    memset(identity, 0, sizeof(identity));
    identity[0] = 1.0f; identity[5] = 1.0f; identity[10] = 1.0f; identity[15] = 1.0f;
    identity[16] = 1.0f; identity[17] = 1.0f; identity[18] = 1.0f;

    for (i = 0; i < 16; i++) {
        if (identity[i] != identity[i]) return ae3d_vk_fail("identity is not finite");
    }
    if (!ae3d_vk_upload_buffer(identity, sizeof(identity), VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
                               &vk.identity_instance, &vk.identity_instance_memory)) {
        return 0;
    }
    {
        float empty[8];
        memset(empty, 0, sizeof(empty));
        if (!ae3d_vk_upload_buffer(empty, sizeof(empty), VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
                                   &vk.empty_skin, &vk.empty_skin_memory)) {
            return 0;
        }
    }
    return 1;
}

static int ae3d_vk_create_commands(void) {
    VkCommandPoolCreateInfo pool;
    VkCommandBufferAllocateInfo allocation;
    VkSemaphoreCreateInfo semaphore;
    VkFenceCreateInfo fence;
    unsigned i;
    VkResult result;

    memset(&pool, 0, sizeof(pool));
    pool.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    pool.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    pool.queueFamilyIndex = vk.graphics_family;
    result = ae3d_vkCreateCommandPool(vk.device, &pool, NULL, &vk.command_pool);
    if (result != VK_SUCCESS) return ae3d_vk_fail_code("vkCreateCommandPool failed", result);

    memset(&allocation, 0, sizeof(allocation));
    allocation.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    allocation.commandPool = vk.command_pool;
    allocation.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocation.commandBufferCount = AE3D_VK_FRAMES;
    result = ae3d_vkAllocateCommandBuffers(vk.device, &allocation, vk.command_buffers);
    if (result != VK_SUCCESS) return ae3d_vk_fail_code("vkAllocateCommandBuffers failed", result);

    memset(&semaphore, 0, sizeof(semaphore));
    semaphore.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
    memset(&fence, 0, sizeof(fence));
    fence.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fence.flags = VK_FENCE_CREATE_SIGNALED_BIT;

    for (i = 0; i < AE3D_VK_FRAMES; i++) {
        if (ae3d_vkCreateSemaphore(vk.device, &semaphore, NULL, &vk.image_available[i]) != VK_SUCCESS ||
            ae3d_vkCreateSemaphore(vk.device, &semaphore, NULL, &vk.render_finished[i]) != VK_SUCCESS ||
            ae3d_vkCreateFence(vk.device, &fence, NULL, &vk.in_flight[i]) != VK_SUCCESS) {
            return ae3d_vk_fail("could not create frame synchronisation objects");
        }
        vk.stamped[i] = 0;
    }

    if (vk.timestamps_usable) {
        VkQueryPoolCreateInfo pool;
        memset(&pool, 0, sizeof(pool));
        pool.sType = VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO;
        pool.queryType = VK_QUERY_TYPE_TIMESTAMP;
        pool.queryCount = AE3D_VK_FRAMES * AE3D_VK_STAMPS;
        if (ae3d_vkCreateQueryPool(vk.device, &pool, NULL, &vk.timestamps) != VK_SUCCESS) {
            /* Not fatal: a frame without a timer still draws. */
            vk.timestamps = VK_NULL_HANDLE;
            vk.timestamps_usable = 0;
        }
    }
    return 1;
}

/* One timestamp, at the next slot of this frame's four. Bottom of pipe, so
   the stamp lands when everything recorded before it has finished. */
static void ae3d_vk_stamp(void) {
    if (!vk.timestamps || vk.stamp_next >= AE3D_VK_STAMPS) return;
    ae3d_vkCmdWriteTimestamp(vk.command_buffers[vk.frame], VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
                             vk.timestamps, vk.frame * AE3D_VK_STAMPS + (unsigned)vk.stamp_next);
    vk.stamp_next++;
}

/* Writes every stamp up to and including this one. A pass that did not run
   gets two stamps in the same place and costs nothing, rather than being
   charged for whatever ran instead of it. */
static void ae3d_vk_stamp_through(int index) {
    while (vk.stamp_next <= index) ae3d_vk_stamp();
}

/* Reads back the stamps this frame slot wrote last time round. Called after
   the slot's fence has been waited on, so the results exist and nothing here
   waits for the GPU. */
static void ae3d_vk_collect_stamps(void) {
    unsigned long long ticks[AE3D_VK_STAMPS];
    int i;
    if (!vk.stamped[vk.frame]) return;
    vk.stamped[vk.frame] = 0;
    if (ae3d_vkGetQueryPoolResults(vk.device, vk.timestamps, vk.frame * AE3D_VK_STAMPS, AE3D_VK_STAMPS,
                                   sizeof(ticks), ticks, sizeof(ticks[0]),
                                   VK_QUERY_RESULT_64_BIT) != VK_SUCCESS) {
        return;
    }
    /* The three a frame has always been split into -- shadow, scene, post --
       and the scene's own split: camera depth, sky, opaque, occlusion,
       transparent. The scene is the whole of stamps 1 to 6. */
#define AE3D_VK_SPAN(a, b) (ticks[b] >= ticks[a] ? (double)(ticks[b] - ticks[a]) * vk.timestamp_ms : 0.0)
    vk.pass_ms[0] = AE3D_VK_SPAN(0, 1);
    vk.pass_ms[1] = AE3D_VK_SPAN(1, 6);
    vk.pass_ms[2] = AE3D_VK_SPAN(6, 7);
    vk.pass_ms[3] = AE3D_VK_SPAN(1, 2);
    vk.pass_ms[4] = AE3D_VK_SPAN(2, 3);
    vk.pass_ms[5] = AE3D_VK_SPAN(3, 4);
    vk.pass_ms[6] = AE3D_VK_SPAN(4, 5);
    vk.pass_ms[7] = AE3D_VK_SPAN(5, 6);
#undef AE3D_VK_SPAN
    (void)i;
}

/* What a stage of the last finished frame cost on the device, in
   milliseconds: 0 shadow, 1 scene (all of 3 to 7), 2 post, 3 camera depth,
   4 sky, 5 opaque, 6 occlusion, 7 transparent. */
double ae3d_vk_pass_ms(int pass) {
    if (pass < 0 || pass >= AE3D_VK_STAGES) return 0.0;
    return vk.pass_ms[pass];
}

int ae3d_vk_pipeline_binds(void) { return vk.pipeline_binds; }
int ae3d_vk_set_binds(void) { return vk.set_binds; }

// A null window means offscreen: no surface, no swapchain, and the frame is
// read back rather than presented. That is what lets the editor host the
// Vulkan renderer inside a toolkit that owns the real window.
int ae3d_vk_init(int width, int height) {
    if (vk.ready) return 1;
    /* Whether shadows and post-processing are wanted are settings rather
       than device state, and a program sets them before the device exists:
       ae3d_vk_adopt_device keeps them, and the Aether modules' frame hooks
       (ae3d.vkmeter switches itself on when the engine asks, which can be
       before the device is made), as it clears the rest. */
    if (!vk.device) return ae3d_vk_fail("no device (ae3d.vkdevice makes it)");
    vk.samples = ae3d_vk_pick_samples();
    if (!ae3d_vk_choose_surface_format()) return 0;
    if (vk.offscreen) {
        if (!ae3d_vk_create_offscreen_target(width, height)) return 0;
    } else {
        if (!ae3d_vk_create_swapchain(width, height)) return 0;
    }
    if (!ae3d_vk_create_render_pass()) return 0;
    if (!ae3d_vk_create_framebuffers()) return 0;
    if (!ae3d_vk_create_commands()) return 0;
    /* The lamps' atlas is cleared through a one-off command buffer, so it
       is made once there is a pool to take one from, and before any set
       is written: every scene set names it. */
    if (!ae3d_vk_create_lamp_target()) return 0;
    if (!ae3d_vk_create_descriptors()) return 0;
    if (!ae3d_vk_create_defaults()) return 0;
    if (!ae3d_vk_create_pipeline()) return 0;
    if (vk.dlss_loaded) {
        vk.dlss_supported = ae3d_dlss_supported((void *)vk.physical);
        if (!vk.dlss_supported) fprintf(stderr, "ae3d: DLSS: %s\n", ae3d_dlss_last_error());
    }

    snprintf(g_vk_error, sizeof(g_vk_error), "%s", "");
    vk.ready = 1;
    return 1;
}

// Offscreen has no surface, so it rebuilds the image it renders into rather
// than a swapchain. Taking the surface path here dereferenced a null surface.
static int ae3d_vk_rebuild_swapchain(int width, int height) {
    unsigned frame;

    ae3d_vkDeviceWaitIdle(vk.device);

    // Descriptor sets are cached per texture and the rebuild destroys the
    // post-processing texture, so a set handed out before the resize would name
    // an image that no longer exists. The cache goes with the images.
    if (vk.descriptor_pool) ae3d_vkResetDescriptorPool(vk.device, vk.descriptor_pool, 0);
    for (frame = 0; frame < AE3D_VK_FRAMES; frame++) vk.set_count[frame] = 0;

    ae3d_vk_destroy_swapchain();
    ae3d_vk_destroy_dlss_output();
    if (vk.offscreen) {
        if (!ae3d_vk_create_offscreen_target(width, height)) return 0;
    } else {
        if (!ae3d_vk_create_swapchain(width, height)) return 0;
    }
    if (!ae3d_vk_create_framebuffers()) return 0;
    ae3d_vk_rebias_samplers();
    if (vk.dlss_mode) {
        /* The frame's size may have changed: the mode's render size with it. */
        unsigned rw = 0, rh = 0;
        if (ae3d_dlss_optimal(vk.dlss_mode, vk.extent.width, vk.extent.height, &rw, &rh) &&
            ae3d_dlss_set_options(vk.dlss_mode, vk.extent.width, vk.extent.height)) {
            double scale = (double)rw / (double)vk.extent.width;
            if (scale > 1.0) scale = 1.0;
            if (scale < 0.25) scale = 0.25;
            if (scale != vk.render_scale) {
                vk.render_scale = scale;
                ae3d_vk_destroy_swapchain();
                if (vk.offscreen) { if (!ae3d_vk_create_offscreen_target(width, height)) return 0; }
                else if (!ae3d_vk_create_swapchain(width, height)) return 0;
                if (!ae3d_vk_create_framebuffers()) return 0;
                ae3d_vk_rebias_samplers();
            }
        }
        if (!ae3d_vk_create_dlss_output()) return 0;
    }
    vk.needs_resize = 0;
    return 1;
}

void ae3d_vk_resize(int width, int height) {
    if (!vk.ready) return;
    vk.needs_resize = 1;
    vk.pending_width = width;
    vk.pending_height = height;
}

// The scene pass is opened by the first scene draw rather than here, so a
// shadow pass can be recorded into the same command buffer ahead of it. Vulkan
// forbids nesting render passes, and a shadow map has to be finished before the
// pass that samples it starts.
static void ae3d_vk_open_scene_pass(void) {
    VkRenderPassBeginInfo pass;
    VkClearValue clears[3];
    VkViewport viewport;
    VkRect2D scissor;

    if (vk.pass_open) return;
    /* A cascades' atlas no pass has run over yet -- the key light has been
       a lamp since it was made -- is taken through one, empty, so the lit
       pass samples a cleared map in the layout it reads it in. */
    if (vk.shadow_enabled && vk.shadow_framebuffer && !vk.shadow_ready && ae3d_vk_shadow_begin()) {
        ae3d_vk_shadow_end();
    }
    ae3d_vk_stamp_through(1);

    memset(clears, 0, sizeof(clears));
    clears[0].color.float32[0] = vk.scene_clear[0];
    clears[0].color.float32[1] = vk.scene_clear[1];
    clears[0].color.float32[2] = vk.scene_clear[2];
    clears[0].color.float32[3] = vk.scene_clear[3];
    clears[1].depthStencil.depth = 1.0f;

    memset(&pass, 0, sizeof(pass));
    pass.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    pass.renderPass = vk.post_active ? vk.scene_pass : vk.render_pass;
    if (vk.depth_split) {
        if (vk.depth_resolved) pass.renderPass = vk.post_active ? vk.scene_pass_rest : vk.render_pass_rest;
        else pass.renderPass = vk.post_active ? vk.scene_pass_first : vk.render_pass_first;
    }
    pass.framebuffer = vk.post_active ? vk.scene_framebuffer : vk.framebuffers[vk.image_index];
    pass.renderArea.extent = vk.render_extent;
    /* The third clear is the motion vectors', zero: a pixel nothing draws
       has not moved. */
    pass.clearValueCount = 3;
    pass.pClearValues = clears;
    ae3d_vkCmdBeginRenderPass(vk.command_buffers[vk.frame], &pass, VK_SUBPASS_CONTENTS_INLINE);

    memset(&viewport, 0, sizeof(viewport));
    viewport.width = (float)vk.render_extent.width;
    viewport.height = (float)vk.render_extent.height;
    viewport.maxDepth = 1.0f;
    ae3d_vkCmdSetViewport(vk.command_buffers[vk.frame], 0, 1, &viewport);

    memset(&scissor, 0, sizeof(scissor));
    scissor.extent = vk.render_extent;
    ae3d_vkCmdSetScissor(vk.command_buffers[vk.frame], 0, 1, &scissor);
    vk.pass_open = 1;
}

int ae3d_vk_frame_begin(double r, double g, double b, double a) {
    VkCommandBufferBeginInfo begin;
    VkResult result;

    if (!vk.ready || vk.recording) return 0;
    ae3d_vk_flush_uploads();

    if (vk.needs_resize) {
        if (!ae3d_vk_rebuild_swapchain(vk.pending_width, vk.pending_height)) return 0;
    }

    ae3d_vkWaitForFences(vk.device, 1, &vk.in_flight[vk.frame], VK_TRUE, UINT64_MAX);
    ae3d_vk_collect_stamps();
    {
        int h;
        for (h = 0; h < vk.hook_count; h++) {
            if (vk.hooks[h].collect) vk.hooks[h].collect(vk.hooks[h].context);
        }
    }

    if (vk.offscreen) {
        vk.image_index = 0;
    } else {
        result = ae3d_vkAcquireNextImageKHR(vk.device, vk.swapchain, UINT64_MAX,
                                            vk.image_available[vk.frame], VK_NULL_HANDLE,
                                            &vk.image_index);
        if (result == VK_ERROR_OUT_OF_DATE_KHR) {
            if (!ae3d_vk_rebuild_swapchain((int)vk.extent.width, (int)vk.extent.height)) return 0;
            return 0;
        }
        if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR) {
            return ae3d_vk_fail_code("vkAcquireNextImageKHR failed", result);
        }
    }

    ae3d_vkResetFences(vk.device, 1, &vk.in_flight[vk.frame]);
    ae3d_vkResetCommandBuffer(vk.command_buffers[vk.frame], 0);

    memset(&begin, 0, sizeof(begin));
    begin.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    ae3d_vkBeginCommandBuffer(vk.command_buffers[vk.frame], &begin);

    vk.stamp_next = 0;
    if (vk.timestamps) {
        ae3d_vkCmdResetQueryPool(vk.command_buffers[vk.frame], vk.timestamps,
                                 vk.frame * AE3D_VK_STAMPS, AE3D_VK_STAMPS);
        ae3d_vk_stamp();
    }
    vk.bound_pipeline = VK_NULL_HANDLE;
    vk.bound_texture = -1;
    vk.bound_normal = -1;
    vk.pipeline_binds = 0;
    vk.set_binds = 0;

    vk.scene_clear[0] = (float)r;
    vk.scene_clear[1] = (float)g;
    vk.scene_clear[2] = (float)b;
    vk.scene_clear[3] = (float)a;

    /* A capture channel is the surfaces' own numbers -- albedo, normals,
       motion -- and no effect over them: the post chain, the reflections
       and the occlusion stand down while one is read. */
    vk.post_active = (ae3d_vk_scaled() || (!vk.capture_bypass && (vk.fxaa || vk.bloom || vk.ssr_enabled || vk.taa_enabled)))
                     && vk.screen_quad > 0 && vk.post_texture > 0;
    vk.pass_open = 0;
    vk.in_shadow_pass = 0;
    /* Two halves when something reads the scene's depth this frame: the
       renderer says what wants it before the frame (ae3d_vk_set_scene_depth,
       the occlusion, the reflection), and the target is made at the size of
       the swapchain, here, so the first frame that needs it has it. */
    vk.depth_split = 0;
    vk.depth_resolved = 0;
    if ((vk.ssr_enabled || vk.scene_depth_wanted || vk.ssao_enabled || vk.taa_enabled || vk.dlss_mode) && vk.depth_resolve_pipeline) {
        if (!vk.camdepth_framebuffer ||
            vk.camdepth_width != (int)vk.render_extent.width ||
            vk.camdepth_height != (int)vk.render_extent.height) {
            ae3d_vkDeviceWaitIdle(vk.device);
            ae3d_vk_destroy_camdepth_target();
            ae3d_vk_create_camdepth_target((int)vk.render_extent.width, (int)vk.render_extent.height);
        }
        vk.depth_split = vk.camdepth_framebuffer != VK_NULL_HANDLE;
    }

    vk.uniforms[vk.frame].used = 0;
    vk.draw_calls = 0;
    vk.recording = 1;
    return 1;
}

/* Whether a frame is being recorded, and whether a pass is open in it: when
   ae3d.vkrays and ae3d.vkcrowd may record their builds and sorts, which go
   before any pass. */
int ae3d_vk_recording(void) { return vk.recording; }
int ae3d_vk_pass_open(void) { return vk.pass_open; }

/* The top-level structure ae3d.vkrays built for frame slot `frame`, which
   the scene's descriptor sets bind at binding 5 (null: it has none, remade
   or gone). Every set, of both slots, is written again when next claimed:
   the sets of the frame before named the structure that was. */
void ae3d_vk_set_scene_structure(int frame, void *structure) {
    int f, index;
    if (frame < 0 || frame >= AE3D_VK_FRAMES) return;
    vk.tlas[frame] = (VkAccelerationStructureKHR)structure;
    for (f = 0; f < AE3D_VK_FRAMES; f++) {
        for (index = 0; index < vk.set_count[f]; index++) vk.set_texture[f][index] = AE3D_VK_SET_FREE;
    }
}

int ae3d_vk_draw_calls(void) { return vk.draw_calls; }

int ae3d_vk_sample_count(void) { return (int)vk.samples; }

// Vulkan clip space puts y downward and z in [0, 1]; the engine's matrices are
// OpenGL-shaped, so the correction is folded into the MVP here rather than

// One draw takes a slice of the frame's uniform buffer, so the scene block the
// caller has been filling is snapshotted per draw rather than shared.
static void ae3d_vk_draw_pipeline(VkPipeline pipeline, int handle, int texture_handle,
                                  int instance_handle, int instance_count) {
    /* Whether the pipeline names binding 2 is decided by the mesh, which is
       what chose the pipeline: the two cannot disagree. */
    ae3d_vk_uniform_ring *ring;
    VkDescriptorSet set;
    VkDeviceSize offsets[1];
    ae3d_vk_mesh *mesh;
    unsigned slot;
    unsigned dynamic_offset;

    if (!vk.recording || handle <= 0 || handle > vk.mesh_capacity) return;
    ae3d_vk_open_scene_pass();
    mesh = &vk.meshes[handle - 1];
    if (!mesh->in_use || mesh->index_count == 0) return;

    if (texture_handle < 1 || texture_handle > AE3D_VK_MAX_TEXTURES) texture_handle = vk.default_texture;
    if (!vk.textures[texture_handle - 1].in_use) texture_handle = vk.default_texture;

    ring = &vk.uniforms[vk.frame];
    if (ring->used >= ring->capacity) return;
    slot = ring->used++;
    dynamic_offset = slot * ring->stride;
    memcpy(ring->mapped + dynamic_offset, vk.scene[vk.program].bytes, AE3D_VK_SCENE_SIZE);

    set = ae3d_vk_set_for((int)vk.frame, texture_handle, vk.normal_map, vk.pose_bank);
    if (set == VK_NULL_HANDLE) return;

    if (pipeline != vk.bound_pipeline) {
        ae3d_vkCmdBindPipeline(vk.command_buffers[vk.frame], VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);
        vk.bound_pipeline = pipeline;
        vk.pipeline_binds++;
    }
    /* The set is bound every draw because its dynamic offset moves every
       draw; what is counted is the material behind it changing. */
    if (texture_handle != vk.bound_texture || vk.normal_map != vk.bound_normal) {
        vk.bound_texture = texture_handle;
        vk.bound_normal = vk.normal_map;
        vk.set_binds++;
    }
    ae3d_vkCmdBindDescriptorSets(vk.command_buffers[vk.frame], VK_PIPELINE_BIND_POINT_GRAPHICS,
                                 vk.pipeline_layout, 0, 1, &set, 1, &dynamic_offset);

    offsets[0] = 0;
    ae3d_vkCmdBindVertexBuffers(vk.command_buffers[vk.frame], 0, 1, &mesh->vertex_buffer, offsets);

    if (instance_handle > 0 && instance_handle <= vk.mesh_capacity && instance_count > 0) {
        ae3d_vk_mesh *instances = &vk.meshes[instance_handle - 1];
        if (instances->in_use) {
            ae3d_vkCmdBindVertexBuffers(vk.command_buffers[vk.frame], 1, 1,
                                        &instances->vertex_buffer, offsets);
        }
    } else {
        ae3d_vkCmdBindVertexBuffers(vk.command_buffers[vk.frame], 1, 1,
                                    &vk.identity_instance, offsets);
        instance_count = 1;
    }

    if (mesh->skinned && mesh->skin_buffer) {
        ae3d_vkCmdBindVertexBuffers(vk.command_buffers[vk.frame], 2, 1,
                                    &mesh->skin_buffer, offsets);
    } else {
        ae3d_vkCmdBindVertexBuffers(vk.command_buffers[vk.frame], 2, 1,
                                    &vk.empty_skin, offsets);
    }

    ae3d_vkCmdBindIndexBuffer(vk.command_buffers[vk.frame], mesh->index_buffer, 0, VK_INDEX_TYPE_UINT32);
    ae3d_vkCmdDrawIndexed(vk.command_buffers[vk.frame], mesh->index_count,
                          (unsigned)instance_count, 0, 0, 0);
    vk.draw_calls++;
}

/* The draw of a mesh with an instance stream and an instance count the
   device wrote: the stream at binding 1, the count read from the draw
   command at `offset` in `draws`. The pipeline is the one the mesh and
   the pose bank would have chosen for a lit draw, or the crowd's shadow
   one in the shadow pass. */
static void ae3d_vk_draw_pipeline_indirect(int handle, int texture_handle, VkBuffer instances,
                                           VkBuffer draws, VkDeviceSize offset, int shadow) {
    ae3d_vk_uniform_ring *ring;
    VkDescriptorSet set;
    VkDeviceSize offsets[1];
    ae3d_vk_mesh *mesh;
    VkPipeline pipeline;
    unsigned slot, dynamic_offset;

    if (!vk.recording || handle <= 0 || handle > vk.mesh_capacity) return;
    if (!shadow) ae3d_vk_open_scene_pass();
    mesh = &vk.meshes[handle - 1];
    if (!mesh->in_use || mesh->index_count == 0) return;
    if (shadow) {
        pipeline = vk.pose_bank > 0 && vk.crowd_shadow_pipeline ? vk.crowd_shadow_pipeline
                 : (mesh->skinned && vk.skinned_shadow_pipeline ? vk.skinned_shadow_pipeline : vk.shadow_pipeline);
        vk.program = AE3D_VK_PROGRAM_SCENE;
    } else {
        pipeline = ae3d_vk_pipeline_for(handle, 0);
    }
    if (!pipeline) return;
    if (texture_handle < 1 || texture_handle > AE3D_VK_MAX_TEXTURES) texture_handle = vk.default_texture;
    if (!vk.textures[texture_handle - 1].in_use) texture_handle = vk.default_texture;

    ring = &vk.uniforms[vk.frame];
    if (ring->used >= ring->capacity) return;
    slot = ring->used++;
    dynamic_offset = slot * ring->stride;
    memcpy(ring->mapped + dynamic_offset, vk.scene[vk.program].bytes, AE3D_VK_SCENE_SIZE);
    set = ae3d_vk_set_for((int)vk.frame, texture_handle, vk.normal_map, vk.pose_bank);
    if (set == VK_NULL_HANDLE) return;
    if (pipeline != vk.bound_pipeline) {
        ae3d_vkCmdBindPipeline(vk.command_buffers[vk.frame], VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);
        vk.bound_pipeline = pipeline;
        vk.pipeline_binds++;
    }
    ae3d_vkCmdBindDescriptorSets(vk.command_buffers[vk.frame], VK_PIPELINE_BIND_POINT_GRAPHICS,
                                 vk.pipeline_layout, 0, 1, &set, 1, &dynamic_offset);
    offsets[0] = 0;
    ae3d_vkCmdBindVertexBuffers(vk.command_buffers[vk.frame], 0, 1, &mesh->vertex_buffer, offsets);
    ae3d_vkCmdBindVertexBuffers(vk.command_buffers[vk.frame], 1, 1, &instances, offsets);
    if (mesh->skinned && mesh->skin_buffer) {
        ae3d_vkCmdBindVertexBuffers(vk.command_buffers[vk.frame], 2, 1, &mesh->skin_buffer, offsets);
    } else {
        ae3d_vkCmdBindVertexBuffers(vk.command_buffers[vk.frame], 2, 1, &vk.empty_skin, offsets);
    }
    ae3d_vkCmdBindIndexBuffer(vk.command_buffers[vk.frame], mesh->index_buffer, 0, VK_INDEX_TYPE_UINT32);
    ae3d_vkCmdDrawIndexedIndirect(vk.command_buffers[vk.frame], draws, offset, 1, 5 * sizeof(unsigned));
    vk.draw_calls++;
}

/* The draw of an instance stream by the count a command on the device
   holds -- a tier of ae3d.vkcrowd's crowd: `instances` at binding 1, the
   command at `offset` in `draws`. In the shadow pass (`shadow`) only, and
   with the crowd's depth pipeline, where one draws. */
void ae3d_vk_draw_indirect(int mesh_handle, int texture_handle, void *instances, void *draws,
                           long long offset, int shadow) {
    if (shadow && (!vk.shadow_pipeline || !vk.in_shadow_pass)) return;
    ae3d_vk_draw_pipeline_indirect(mesh_handle, texture_handle, (VkBuffer)instances, (VkBuffer)draws,
                                   (VkDeviceSize)offset, shadow);
}

// Which family of pipelines the next draws use. A program the backend does not
// have falls back to the scene one, which is what the OpenGL backend does with
// a shader that fails to compile.
void ae3d_vk_set_program(int program) {
    vk.program = (program >= 0 && program < AE3D_VK_PROGRAM_COUNT) ? program : AE3D_VK_PROGRAM_SCENE;
}

int ae3d_vk_program_count(void) { return AE3D_VK_PROGRAM_COUNT; }

void ae3d_vk_set_face_culling(int on) { vk.cull = on ? 1 : 0; }

static int ae3d_vk_instances_are_points(int instance_handle, int instance_count) {
    if (instance_count <= 0 || instance_handle <= 0 || instance_handle > vk.mesh_capacity) return 0;
    return vk.meshes[instance_handle - 1].in_use && vk.meshes[instance_handle - 1].points;
}

/* The pipeline a lit draw of `handle` takes: by the mesh (skinned or not),
   the pose bank (a crowd), the program (water), the instances (points) and
   the blend state. */
static VkPipeline ae3d_vk_pipeline_for(int handle, int points) {
    VkPipeline opaque = vk.pipeline[vk.cull];
    VkPipeline blended = vk.pipeline_blend;
    int skinned = handle > 0 && handle <= vk.mesh_capacity && vk.meshes[handle - 1].skinned;

    if (points && vk.point_pipeline[vk.cull] && vk.point_pipeline_blend) {
        opaque = vk.point_pipeline[vk.cull];
        blended = vk.point_pipeline_blend;
    } else if (vk.program == AE3D_VK_PROGRAM_WATER && vk.water_pipeline[vk.cull]
        && vk.water_pipeline_blend) {
        opaque = vk.water_pipeline[vk.cull];
        blended = vk.water_pipeline_blend;
    } else if (skinned && vk.pose_bank > 0 && vk.crowd_pipeline[vk.cull]
               && vk.crowd_pipeline_blend) {
        opaque = vk.crowd_pipeline[vk.cull];
        blended = vk.crowd_pipeline_blend;
    } else if (skinned && vk.skinned_pipeline[vk.cull] && vk.skinned_pipeline_blend) {
        opaque = vk.skinned_pipeline[vk.cull];
        blended = vk.skinned_pipeline_blend;
    }
    return vk.blend ? blended : opaque;
}

void ae3d_vk_draw(int handle, int texture_handle, int instance_handle, int instance_count) {
    ae3d_vk_draw_pipeline(ae3d_vk_pipeline_for(handle, ae3d_vk_instances_are_points(instance_handle, instance_count)),
                          handle, texture_handle, instance_handle, instance_count);
}

/* The widest texture the device creates, a side; 0 before a device. */
int ae3d_vk_max_texture_size(void) { return (int)vk.max_image_2d; }

// A flat sky needs no geometry: the clear colour already fills every pixel the
// scene does not cover, so only a textured sky is drawn.
void ae3d_vk_draw_sky(int mesh_handle, int texture_handle, int weather_handle, int shape_handle) {
    int normal_was = vk.normal_map;
    int bank_was = vk.pose_bank;
    if (!vk.sky_pipeline || texture_handle <= 0) return;
    vk.program = AE3D_VK_PROGRAM_SCENE;
    /* The clouds' weather at binding 3 and their shape at 4, where a model
       draw keeps its normal map and its pose bank. */
    vk.normal_map = weather_handle;
    vk.pose_bank = shape_handle;
    ae3d_vk_draw_pipeline(vk.sky_pipeline, mesh_handle, texture_handle, 0, 1);
    vk.normal_map = normal_was;
    vk.pose_bank = bank_was;
    ae3d_vk_stamp_through(3);
}

/* The sky is done, drawn or not: the renderer says so before the opaque
   draws, so a frame with no sky to draw does not charge the opaque draws
   to the sky -- the stamp the sky draw would have written is written
   here, at the same moment, and the sky stage reads zero. */
void ae3d_vk_mark_sky_done(void) {
    if (!vk.recording) return;
    ae3d_vk_open_scene_pass();
    ae3d_vk_stamp_through(3);
}

/* The opaque draws are done: the renderer says so before the occlusion and
   the transparent draws, so the stamps split them. */
void ae3d_vk_mark_opaque_done(void) {
    if (!vk.recording) return;
    ae3d_vk_open_scene_pass();
    ae3d_vk_stamp_through(4);
}

void ae3d_vk_set_screen_quad(int mesh_handle) { vk.screen_quad = mesh_handle; }

// Descriptor sets are cached per texture, so binding 2 keeps whatever image it
// was written with. Toggling shadows rewrites it on every set already handed
// out, otherwise the scene would sample the previous state forever.
void ae3d_vk_set_shadows(int on) {
    VkDescriptorImageInfo shadow;
    VkWriteDescriptorSet write;
    int frame;
    int index;

    on = on ? 1 : 0;
    if (vk.shadow_enabled == on) return;
    vk.shadow_enabled = on;
    if (!vk.ready) return;

    ae3d_vkDeviceWaitIdle(vk.device);

    memset(&shadow, 0, sizeof(shadow));
    shadow.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    if (vk.shadow_enabled && vk.shadow_view) {
        shadow.imageView = vk.shadow_view;
        shadow.sampler = vk.shadow_sampler;
    } else {
        shadow.imageView = vk.textures[vk.default_texture - 1].view;
        shadow.sampler = vk.textures[vk.default_texture - 1].sampler;
    }

    for (frame = 0; frame < AE3D_VK_FRAMES; frame++) {
        for (index = 0; index < vk.set_count[frame]; index++) {
            memset(&write, 0, sizeof(write));
            write.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
            write.dstSet = vk.sets[frame][index];
            write.dstBinding = 2;
            write.descriptorCount = 1;
            write.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            write.pImageInfo = &shadow;
            ae3d_vkUpdateDescriptorSets(vk.device, 1, &write, 0, NULL);
        }
    }
}

int ae3d_vk_shadows(void) { return vk.shadow_enabled; }

// Turn screen-space reflection on or off. The camera-depth target it samples is
// built the first time it is turned on, and rebuilt if the swapchain has since
// been remade at a different size, so a scene that never asks for SSR allocates
// nothing. The march itself is wired on top of this in a later step; for now
// this owns the target's lifetime.
void ae3d_vk_set_ssr(int on) {
    on = on ? 1 : 0;
    vk.ssr_enabled = on;
    if (!vk.ready || !on) return;
    if (!vk.camdepth_framebuffer ||
        vk.camdepth_width != (int)vk.render_extent.width ||
        vk.camdepth_height != (int)vk.render_extent.height) {
        ae3d_vkDeviceWaitIdle(vk.device);
        ae3d_vk_destroy_camdepth_target();
        ae3d_vk_create_camdepth_target((int)vk.render_extent.width, (int)vk.render_extent.height);
    }
}

int ae3d_vk_ssr(void) { return vk.ssr_enabled; }

/* While a capture channel is read, no effect runs over the frame. */
void ae3d_vk_set_capture_bypass(int on) { vk.capture_bypass = on ? 1 : 0; }

/* Ambient occlusion on or off, with how far a thing shadows its neighbours
   (metres) and how dark that goes. The camera depth it reads is the
   reflection's target, made the same way when it is first wanted. */
void ae3d_vk_set_ssao(int on, double radius, double intensity) {
    on = on ? 1 : 0;
    vk.ssao_enabled = on;
    vk.ssao_radius = (float)radius;
    vk.ssao_intensity = (float)intensity;
    if (!vk.ready || !on) return;
    if (!vk.camdepth_framebuffer ||
        vk.camdepth_width != (int)vk.render_extent.width ||
        vk.camdepth_height != (int)vk.render_extent.height) {
        ae3d_vkDeviceWaitIdle(vk.device);
        ae3d_vk_destroy_camdepth_target();
        ae3d_vk_create_camdepth_target((int)vk.render_extent.width, (int)vk.render_extent.height);
    }
}

int ae3d_vk_ssao(void) { return vk.ssao_enabled; }
double ae3d_vk_ssao_radius(void) { return vk.ssao_radius; }
double ae3d_vk_ssao_intensity(void) { return vk.ssao_intensity; }

/* The one-pixel white texture every set falls back to, for a draw that has
   to bind an image it does not read: the sky drawn from the sun. */
int ae3d_vk_default_texture(void) { return vk.default_texture; }

/* The camera depth drawn for its own sake: a water surface reads the scene's
   depth under it for its shore, whether or not the road reflects. The same
   target the reflection uses, made the same way. */
void ae3d_vk_set_scene_depth(int on) {
    on = on ? 1 : 0;
    vk.scene_depth_wanted = on;
    if (!vk.ready || !on) return;
    if (!vk.camdepth_framebuffer ||
        vk.camdepth_width != (int)vk.render_extent.width ||
        vk.camdepth_height != (int)vk.render_extent.height) {
        ae3d_vkDeviceWaitIdle(vk.device);
        ae3d_vk_destroy_camdepth_target();
        ae3d_vk_create_camdepth_target((int)vk.render_extent.width, (int)vk.render_extent.height);
    }
}

/* Whether the depth the occlusion, the reflection and the water read will
   be there this frame: the frame is drawn in two halves with the resolve
   between them. */
int ae3d_vk_scene_depth_ready(void) {
    return vk.depth_split && vk.camdepth_framebuffer != VK_NULL_HANDLE && vk.camdepth_view != VK_NULL_HANDLE;
}

// The pass leaves the map in shader-read layout, so the scene pass that follows
// in the same command buffer samples it without a barrier of its own.
int ae3d_vk_shadow_begin(void) {
    VkRenderPassBeginInfo pass;
    VkClearValue clears[2];
    VkViewport viewport;
    VkRect2D scissor;

    if (!vk.recording || !vk.shadow_enabled || !vk.shadow_framebuffer) return 0;
    if (vk.pass_open) return 0;

    memset(clears, 0, sizeof(clears));
    clears[0].depthStencil.depth = 1.0f;

    memset(&pass, 0, sizeof(pass));
    pass.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    pass.renderPass = vk.shadow_pass;
    pass.framebuffer = vk.shadow_framebuffer;
    /* The pass leaves the atlas readable, whatever it draws. */
    vk.shadow_ready = 1;
    pass.renderArea.extent.width = AE3D_VK_SHADOW_SIZE;
    pass.renderArea.extent.height = AE3D_VK_SHADOW_SIZE;
    pass.clearValueCount = 1;
    pass.pClearValues = clears;
    ae3d_vkCmdBeginRenderPass(vk.command_buffers[vk.frame], &pass, VK_SUBPASS_CONTENTS_INLINE);

    memset(&viewport, 0, sizeof(viewport));
    viewport.width = (float)AE3D_VK_SHADOW_SIZE;
    viewport.height = (float)AE3D_VK_SHADOW_SIZE;
    viewport.maxDepth = 1.0f;
    ae3d_vkCmdSetViewport(vk.command_buffers[vk.frame], 0, 1, &viewport);

    memset(&scissor, 0, sizeof(scissor));
    scissor.extent.width = AE3D_VK_SHADOW_SIZE;
    scissor.extent.height = AE3D_VK_SHADOW_SIZE;
    ae3d_vkCmdSetScissor(vk.command_buffers[vk.frame], 0, 1, &scissor);
    vk.in_shadow_pass = 1;
    vk.pass_open = 1;
    return 1;
}

/* The lamps' atlas pass (ae3d.lampshadows): opened on the atlas as it
   was left, for lamp_shadow_tile to clear and draw a face at a time, and
   closed by ae3d_vk_shadow_end like the shadow pass. */
int ae3d_vk_lamp_shadow_begin(void) {
    VkRenderPassBeginInfo pass;

    if (!vk.recording || !vk.lamp_framebuffer) return 0;
    if (vk.pass_open) return 0;
    memset(&pass, 0, sizeof(pass));
    pass.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    pass.renderPass = vk.lamp_pass;
    pass.framebuffer = vk.lamp_framebuffer;
    pass.renderArea.extent.width = AE3D_VK_LAMP_SHADOW_SIZE;
    pass.renderArea.extent.height = AE3D_VK_LAMP_SHADOW_SIZE;
    ae3d_vkCmdBeginRenderPass(vk.command_buffers[vk.frame], &pass, VK_SUBPASS_CONTENTS_INLINE);
    vk.in_shadow_pass = 1;
    vk.pass_open = 1;
    return 1;
}

/* A face's tile of the lamps' atlas: the draws that follow land in it, and
   it is cleared to the far plane first, the rest of the atlas left. */
void ae3d_vk_lamp_shadow_tile(int x, int y, int size) {
    VkClearAttachment clear;
    VkClearRect rect;
    if (!vk.recording || !vk.in_shadow_pass) return;
    ae3d_vk_shadow_viewport(x, y, size);
    memset(&clear, 0, sizeof(clear));
    clear.aspectMask = VK_IMAGE_ASPECT_DEPTH_BIT;
    clear.clearValue.depthStencil.depth = 1.0f;
    memset(&rect, 0, sizeof(rect));
    rect.rect.offset.x = x;
    rect.rect.offset.y = y;
    rect.rect.extent.width = (unsigned)size;
    rect.rect.extent.height = (unsigned)size;
    rect.layerCount = 1;
    ae3d_vkCmdClearAttachments(vk.command_buffers[vk.frame], 1, &clear, 1, &rect);
}

/* The lamps' static layer's pass: as the atlas's, on the layer beneath. */
int ae3d_vk_lamp_static_begin(void) {
    VkRenderPassBeginInfo pass;

    if (!vk.recording || !vk.lamp_static_framebuffer) return 0;
    if (vk.pass_open) return 0;
    memset(&pass, 0, sizeof(pass));
    pass.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    pass.renderPass = vk.lamp_pass;
    pass.framebuffer = vk.lamp_static_framebuffer;
    pass.renderArea.extent.width = AE3D_VK_LAMP_SHADOW_SIZE;
    pass.renderArea.extent.height = AE3D_VK_LAMP_SHADOW_SIZE;
    ae3d_vkCmdBeginRenderPass(vk.command_buffers[vk.frame], &pass, VK_SUBPASS_CONTENTS_INLINE);
    vk.in_shadow_pass = 1;
    vk.pass_open = 1;
    return 1;
}

/* `count` tiles of `size` texels, their corners at `corners` (x then y,
   from the atlas's first row), copied from the static layer into the
   atlas the shader reads: outside any pass, after the static layer's pass
   wrote them and before the atlas's pass draws what moves over them. */
void ae3d_vk_lamp_copy(const int *corners, int count, int size) {
    VkImageMemoryBarrier barriers[2];
    VkImageCopy *regions;
    VkCommandBuffer commands;
    int i;

    if (!vk.recording || vk.pass_open || count <= 0 || !corners) return;
    regions = (VkImageCopy *)calloc((size_t)count, sizeof(VkImageCopy));
    if (!regions) return;
    for (i = 0; i < count; i++) {
        regions[i].srcSubresource.aspectMask = VK_IMAGE_ASPECT_DEPTH_BIT;
        regions[i].srcSubresource.layerCount = 1;
        regions[i].dstSubresource = regions[i].srcSubresource;
        regions[i].srcOffset.x = corners[i * 2];
        regions[i].srcOffset.y = corners[i * 2 + 1];
        regions[i].dstOffset = regions[i].srcOffset;
        regions[i].extent.width = (unsigned)size;
        regions[i].extent.height = (unsigned)size;
        regions[i].extent.depth = 1;
    }
    commands = vk.command_buffers[vk.frame];

    /* The static layer, written by its pass, is read by the copy; the atlas,
       read by last frame's lit pass and written by its own pass, is
       written by it. */
    memset(barriers, 0, sizeof(barriers));
    barriers[0].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barriers[0].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barriers[0].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barriers[0].subresourceRange.aspectMask = VK_IMAGE_ASPECT_DEPTH_BIT;
    barriers[0].subresourceRange.levelCount = 1;
    barriers[0].subresourceRange.layerCount = 1;
    barriers[1] = barriers[0];
    barriers[0].image = vk.lamp_static_image;
    barriers[0].oldLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barriers[0].newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    barriers[0].srcAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
    barriers[0].dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    barriers[1].image = vk.lamp_image;
    barriers[1].oldLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barriers[1].newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barriers[1].srcAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT | VK_ACCESS_SHADER_READ_BIT;
    barriers[1].dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    ae3d_vkCmdPipelineBarrier(commands,
                              VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT | VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT |
                              VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
                              VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, NULL, 0, NULL, 2, barriers);
    ae3d_vkCmdCopyImage(commands, vk.lamp_static_image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                        vk.lamp_image, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, (unsigned)count, regions);
    /* Back to the layout both passes and the lit pass take them in: the
       atlas's copied depths for the draws over them and the lit pass's
       reads, the static layer's reads done before its pass writes it
       again. */
    barriers[0].oldLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    barriers[0].newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barriers[0].srcAccessMask = 0;
    barriers[0].dstAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT |
                                VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
    barriers[1].oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barriers[1].newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barriers[1].srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    barriers[1].dstAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT |
                                VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT | VK_ACCESS_SHADER_READ_BIT;
    ae3d_vkCmdPipelineBarrier(commands, VK_PIPELINE_STAGE_TRANSFER_BIT,
                              VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT |
                              VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                              0, 0, NULL, 0, NULL, 2, barriers);
    free(regions);
}

/* How many times the atlas has been made: its faces hold nothing drawn
   before the last. */
int ae3d_vk_lamp_shadow_generation(void) { return vk.lamp_generation; }

/* The tile of the atlas the next shadow draws land in: `size` texels a
   side from (x, y), measured from the atlas's first row -- a cascade's
   tile (#469). */
void ae3d_vk_shadow_viewport(int x, int y, int size) {
    VkViewport viewport;
    VkRect2D scissor;
    if (!vk.recording || !vk.in_shadow_pass) return;
    memset(&viewport, 0, sizeof(viewport));
    viewport.x = (float)x;
    viewport.y = (float)y;
    viewport.width = (float)size;
    viewport.height = (float)size;
    viewport.maxDepth = 1.0f;
    ae3d_vkCmdSetViewport(vk.command_buffers[vk.frame], 0, 1, &viewport);
    memset(&scissor, 0, sizeof(scissor));
    scissor.offset.x = x;
    scissor.offset.y = y;
    scissor.extent.width = (unsigned)size;
    scissor.extent.height = (unsigned)size;
    ae3d_vkCmdSetScissor(vk.command_buffers[vk.frame], 0, 1, &scissor);
}

void ae3d_vk_shadow_draw(int mesh_handle, int instance_handle, int instance_count) {
    VkPipeline pipeline = vk.shadow_pipeline;
    if (!vk.shadow_pipeline || !vk.in_shadow_pass) return;
    if (ae3d_vk_instances_are_points(instance_handle, instance_count) && vk.point_shadow_pipeline) {
        pipeline = vk.point_shadow_pipeline;
    } else if (mesh_handle > 0 && mesh_handle <= vk.mesh_capacity
        && vk.meshes[mesh_handle - 1].skinned && vk.skinned_shadow_pipeline) {
        pipeline = vk.skinned_shadow_pipeline;
        /* A crowd casts from the poses its bank gives each instance, or
           its shadows would stand in the bind pose under walking figures. */
        if (vk.pose_bank > 0 && vk.crowd_shadow_pipeline) pipeline = vk.crowd_shadow_pipeline;
    }
    vk.program = AE3D_VK_PROGRAM_SCENE;
    ae3d_vk_draw_pipeline(pipeline, mesh_handle, vk.default_texture,
                          instance_handle, instance_count);
}

void ae3d_vk_shadow_end(void) {
    VkViewport viewport;
    VkRect2D scissor;

    if (!vk.recording || !vk.in_shadow_pass) return;
    ae3d_vkCmdEndRenderPass(vk.command_buffers[vk.frame]);
    vk.in_shadow_pass = 0;
    vk.pass_open = 0;
    ae3d_vk_stamp_through(1);

    memset(&viewport, 0, sizeof(viewport));
    viewport.width = (float)vk.render_extent.width;
    viewport.height = (float)vk.render_extent.height;
    viewport.maxDepth = 1.0f;
    ae3d_vkCmdSetViewport(vk.command_buffers[vk.frame], 0, 1, &viewport);

    memset(&scissor, 0, sizeof(scissor));
    scissor.extent = vk.render_extent;
    ae3d_vkCmdSetScissor(vk.command_buffers[vk.frame], 0, 1, &scissor);
}

// The camera-space depth prepass. Same shape as the shadow pass -- begin the
// depth-only pass, draw the casters (with the camera view-projection in the
// light-space slot the depth shader reads), end -- into the full-size camdepth
// target the SSR pass samples. Only when SSR is on and the target exists.
static void ae3d_vk_draw_screen_with(VkPipeline pipeline, VkDescriptorSet *set_slot,
                                     VkImageView view, VkSampler sampler, VkImageLayout layout,
                                     VkImageView third, VkSampler third_sampler);

/* The scene's depth, as the opaque draws left it, resolved into the camera-
   depth image the occlusion, the reflection and the water read. Called by
   the renderer between its opaque and its transparent draws: the first half
   of the scene pass is ended, the frame's depth -- multisampled, so not a
   thing a blit can copy -- is drawn into the target through the resolve
   shader, and the second half opens at the next draw. Nothing when no one
   reads the depth this frame. It used to be a prepass that drew the whole
   visible scene again, depth only, before the sky: a second pass over every
   triangle, and one that could not draw a picture of a figure (an impostor)
   or a near figure's real silhouette without paying for it again. */
int ae3d_vk_resolve_scene_depth(void) {
    VkRenderPassBeginInfo pass;
    VkClearValue clear;
    VkViewport viewport;
    VkRect2D scissor;

    if (!vk.recording || !vk.depth_split || vk.depth_resolved) return 0;
    if (!vk.camdepth_framebuffer || !vk.depth_resolve_pipeline) return 0;
    ae3d_vk_open_scene_pass();
    ae3d_vkCmdEndRenderPass(vk.command_buffers[vk.frame]);
    vk.pass_open = 0;
    vk.depth_resolved = 1;

    memset(&clear, 0, sizeof(clear));
    clear.depthStencil.depth = 1.0f;
    memset(&pass, 0, sizeof(pass));
    pass.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    pass.renderPass = vk.camdepth_pass;
    pass.framebuffer = vk.camdepth_framebuffer;
    pass.renderArea.extent = vk.render_extent;
    pass.clearValueCount = 1;
    pass.pClearValues = &clear;
    ae3d_vkCmdBeginRenderPass(vk.command_buffers[vk.frame], &pass, VK_SUBPASS_CONTENTS_INLINE);
    vk.pass_open = 1;

    memset(&viewport, 0, sizeof(viewport));
    viewport.width = (float)vk.render_extent.width;
    viewport.height = (float)vk.render_extent.height;
    viewport.maxDepth = 1.0f;
    ae3d_vkCmdSetViewport(vk.command_buffers[vk.frame], 0, 1, &viewport);
    memset(&scissor, 0, sizeof(scissor));
    scissor.extent = vk.render_extent;
    ae3d_vkCmdSetScissor(vk.command_buffers[vk.frame], 0, 1, &scissor);

    ae3d_vk_set_int(&vk.scene[AE3D_VK_PROGRAM_SCENE], AE3D_VK_OFF_DEPTHSAMPLECOUNT, (int)vk.samples);
    vk.program = AE3D_VK_PROGRAM_SCENE;
    ae3d_vk_draw_screen_with(vk.depth_resolve_pipeline, &vk.depth_resolve_set[(int)vk.frame],
                             vk.depth_view, vk.camdepth_sampler,
                             VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL, VK_NULL_HANDLE, VK_NULL_HANDLE);
    ae3d_vkCmdEndRenderPass(vk.command_buffers[vk.frame]);
    vk.pass_open = 0;
    return 1;
}

void ae3d_vk_set_post(int fxaa, int bloom, double threshold, double intensity) {
    vk.fxaa = fxaa;
    vk.bloom = bloom;
    vk.bloom_threshold = (float)threshold;
    vk.bloom_intensity = (float)intensity;
}

int ae3d_vk_post_active(void) { return vk.post_active; }

/* The bloom intensity on its own, so a caller can read it, dial it out to see
 * what the bloom is worth, and put it back, without knowing the other post
 * parameters the scene set. Every bloom term scales by it, so zero is off with
 * the pipeline otherwise unchanged. */
void ae3d_vk_set_bloom_intensity(double intensity) {
    vk.bloom_intensity = (float)intensity;
}

double ae3d_vk_bloom_intensity(void) { return vk.bloom_intensity; }

// Post parameters are written here rather than by the caller because the scene
// draws share this block and a material's own bloom settings would otherwise be
// what the composite pass read.
// The sky, the shadow pass and the composites all read the scene program's
// block. Whichever program the last model selected is still current here, and a
// composite reading the water block gets nonsense for its edge thresholds.
void ae3d_vk_set_ssr_params(double road_height, double strength) {
    vk.ssr_road_height = (float)road_height;
    vk.ssr_strength = (float)strength;
}

// The SSR composite draw. Its own descriptor set puts the scene colour at
// binding 1 and the camera depth at binding 2 (where the scene sets keep the
// shadow map), and it reads the same uniform block as everything else, so the
// SSR shader gets viewProjection, invViewProjection and the road parameters
// the frame set. Written every draw because both images are remade on resize.
/* A full-screen draw with `view` at binding 1 -- the colour source of a
   composite, or the frame's depth for the resolve -- the camera depth at 2
   and at 3 `third` (the temporal pass's history) or the default texture. */
static void ae3d_vk_draw_screen_with(VkPipeline pipeline, VkDescriptorSet *set_slot,
                                     VkImageView view, VkSampler sampler, VkImageLayout layout,
                                     VkImageView third, VkSampler third_sampler) {
    VkDescriptorSetAllocateInfo alloc;
    VkDescriptorBufferInfo buffer;
    VkDescriptorImageInfo scene_img, depth_img, def_img, velocity_img;
    VkWriteDescriptorSet writes[5];
    VkDeviceSize offsets[1];
    ae3d_vk_uniform_ring *ring;
    ae3d_vk_mesh *mesh;
    VkDescriptorSet set;
    unsigned slot, dynamic_offset;

    if (!pipeline || vk.screen_quad <= 0 || vk.screen_quad > vk.mesh_capacity) return;
    if (!vk.camdepth_view || !view || !sampler) return;
    mesh = &vk.meshes[vk.screen_quad - 1];
    if (!mesh->in_use || mesh->index_count == 0) return;

    if (!*set_slot) {
        memset(&alloc, 0, sizeof(alloc));
        alloc.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        alloc.descriptorPool = vk.descriptor_pool;
        alloc.descriptorSetCount = 1;
        alloc.pSetLayouts = &vk.set_layout;
        if (ae3d_vkAllocateDescriptorSets(vk.device, &alloc, &set) != VK_SUCCESS) return;
        *set_slot = set;
    }
    set = *set_slot;

    ring = &vk.uniforms[vk.frame];
    if (ring->used >= ring->capacity) return;
    slot = ring->used++;
    dynamic_offset = slot * ring->stride;
    memcpy(ring->mapped + dynamic_offset, vk.scene[AE3D_VK_PROGRAM_SCENE].bytes, AE3D_VK_SCENE_SIZE);

    memset(&buffer, 0, sizeof(buffer));
    buffer.buffer = ring->buffer;
    buffer.offset = 0;
    buffer.range = AE3D_VK_SCENE_SIZE;

    memset(&scene_img, 0, sizeof(scene_img));
    scene_img.imageLayout = layout;
    scene_img.imageView = view;
    scene_img.sampler = sampler;

    memset(&depth_img, 0, sizeof(depth_img));
    depth_img.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    depth_img.imageView = vk.camdepth_view;
    depth_img.sampler = vk.camdepth_sampler;

    memset(&def_img, 0, sizeof(def_img));
    def_img.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    def_img.imageView = third ? third : vk.textures[vk.default_texture - 1].view;
    def_img.sampler = third_sampler ? third_sampler : vk.textures[vk.default_texture - 1].sampler;

    /* Binding 4 is the frame's motion vectors, for the temporal pass. */
    memset(&velocity_img, 0, sizeof(velocity_img));
    velocity_img.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    velocity_img.imageView = vk.velocity_texture ? vk.textures[vk.velocity_texture - 1].view
                                                 : vk.textures[vk.default_texture - 1].view;
    velocity_img.sampler = vk.velocity_texture ? vk.textures[vk.velocity_texture - 1].sampler
                                               : vk.textures[vk.default_texture - 1].sampler;

    memset(writes, 0, sizeof(writes));
    writes[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[0].dstSet = set; writes[0].dstBinding = 0; writes[0].descriptorCount = 1;
    writes[0].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC;
    writes[0].pBufferInfo = &buffer;
    writes[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[1].dstSet = set; writes[1].dstBinding = 1; writes[1].descriptorCount = 1;
    writes[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writes[1].pImageInfo = &scene_img;
    writes[2].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[2].dstSet = set; writes[2].dstBinding = 2; writes[2].descriptorCount = 1;
    writes[2].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writes[2].pImageInfo = &depth_img;
    writes[3].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[3].dstSet = set; writes[3].dstBinding = 3; writes[3].descriptorCount = 1;
    writes[3].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writes[3].pImageInfo = &def_img;
    writes[4].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[4].dstSet = set; writes[4].dstBinding = 4; writes[4].descriptorCount = 1;
    writes[4].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writes[4].pImageInfo = &velocity_img;
    ae3d_vkUpdateDescriptorSets(vk.device, 5, writes, 0, NULL);

    if (pipeline != vk.bound_pipeline) {
        ae3d_vkCmdBindPipeline(vk.command_buffers[vk.frame], VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);
        vk.bound_pipeline = pipeline;
        vk.pipeline_binds++;
    }
    ae3d_vkCmdBindDescriptorSets(vk.command_buffers[vk.frame], VK_PIPELINE_BIND_POINT_GRAPHICS,
                                 vk.pipeline_layout, 0, 1, &set, 1, &dynamic_offset);
    offsets[0] = 0;
    ae3d_vkCmdBindVertexBuffers(vk.command_buffers[vk.frame], 0, 1, &mesh->vertex_buffer, offsets);
    ae3d_vkCmdBindVertexBuffers(vk.command_buffers[vk.frame], 1, 1, &vk.identity_instance, offsets);
    ae3d_vkCmdBindVertexBuffers(vk.command_buffers[vk.frame], 2, 1, &vk.empty_skin, offsets);
    ae3d_vkCmdBindIndexBuffer(vk.command_buffers[vk.frame], mesh->index_buffer, 0, VK_INDEX_TYPE_UINT32);
    ae3d_vkCmdDrawIndexed(vk.command_buffers[vk.frame], mesh->index_count, 1, 0, 0, 0);
    vk.draw_calls++;
}

static void ae3d_vk_draw_screen(VkPipeline pipeline, VkDescriptorSet *set_slot, int colour_texture) {
    ae3d_vk_texture *scene_tex;
    if (colour_texture <= 0 || colour_texture > AE3D_VK_MAX_TEXTURES) return;
    scene_tex = &vk.textures[colour_texture - 1];
    if (!scene_tex->in_use) return;
    ae3d_vk_draw_screen_with(pipeline, set_slot, scene_tex->view, scene_tex->sampler,
                             VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, VK_NULL_HANDLE, VK_NULL_HANDLE);
}

/* The texel of what the post passes sample: the scene's size for the
   passes over the scene, the frame's once an upscaler has written it. */
static void ae3d_vk_set_texel(unsigned width, unsigned height) {
    float texel[2];
    texel[0] = width ? 1.0f / (float)width : 0.0f;
    texel[1] = height ? 1.0f / (float)height : 0.0f;
    memcpy(vk.scene[AE3D_VK_PROGRAM_SCENE].bytes + AE3D_VK_OFF_TEXELSIZE, texel, sizeof(texel));
}

// The post uniforms live in the shared scene block, so both the reflective
// composite and the ordinary one read them; set them once before either draws.
static void ae3d_vk_setup_post_uniforms(void) {
    ae3d_vk_set_texel(vk.render_extent.width, vk.render_extent.height);
    ae3d_vk_set_float(&vk.scene[AE3D_VK_PROGRAM_SCENE], AE3D_VK_OFF_BLOOMTHRESHOLD, vk.bloom_threshold);
    ae3d_vk_set_float(&vk.scene[AE3D_VK_PROGRAM_SCENE], AE3D_VK_OFF_BLOOMINTENSITY, vk.bloom_intensity);
    ae3d_vk_set_float(&vk.scene[AE3D_VK_PROGRAM_SCENE], AE3D_VK_OFF_EDGETHRESHOLD, 0.125f);
    ae3d_vk_set_float(&vk.scene[AE3D_VK_PROGRAM_SCENE], AE3D_VK_OFF_EDGETHRESHOLDMIN, 0.0625f);
    ae3d_vk_set_float(&vk.scene[AE3D_VK_PROGRAM_SCENE], AE3D_VK_OFF_SUBPIXELQUALITY, 0.75f);
    ae3d_vk_set_float(&vk.scene[AE3D_VK_PROGRAM_SCENE], AE3D_VK_OFF_SSRROADHEIGHT, vk.ssr_road_height);
    ae3d_vk_set_float(&vk.scene[AE3D_VK_PROGRAM_SCENE], AE3D_VK_OFF_SSRSTRENGTH, vk.ssr_strength);
    vk.program = AE3D_VK_PROGRAM_SCENE;
}

// The occlusion, over the opaque scene: a multiply drawn inside the scene
// pass with depth off, reading the camera depth the prepass drew. Nothing
// when the occlusion is off, the prepass did not run, or the pipeline did
// not build; the scene is then simply not darkened.
void ae3d_vk_draw_ssao(void) {
    if (!vk.recording || !vk.ssao_enabled || !vk.ssao_pipeline || vk.capture_bypass) return;
    if (!vk.camdepth_view || !vk.camdepth_framebuffer || vk.default_texture <= 0) return;
    ae3d_vk_open_scene_pass();
    ae3d_vk_set_float(&vk.scene[AE3D_VK_PROGRAM_SCENE], AE3D_VK_OFF_SSAORADIUS, vk.ssao_radius);
    ae3d_vk_set_float(&vk.scene[AE3D_VK_PROGRAM_SCENE], AE3D_VK_OFF_SSAOINTENSITY, vk.ssao_intensity);
    ae3d_vk_draw_screen(vk.ssao_pipeline, &vk.ssao_set[(int)vk.frame], vk.default_texture);
    ae3d_vk_stamp_through(5);
}

// The ordinary composite: bloom, else fxaa, else a straight copy, reading the
// given colour source -- the scene directly, or the reflected intermediate when
// SSR ran a stage before it.
static void ae3d_vk_draw_composite(int source_texture) {
    int index = vk.bloom && vk.post_pipelines[2] ? 2 : (vk.fxaa && vk.post_pipelines[1] ? 1 : 0);
    /* AE3D_VK_SHOW_DEPTH=1 composites the resolved scene depth in place of
       the frame: what the occlusion, the reflection and the water read,
       looked at. */
    if (getenv("AE3D_VK_SHOW_DEPTH") && vk.camdepth_view && vk.camdepth_sampler && vk.post_pipelines[0]) {
        static VkDescriptorSet show_set[AE3D_VK_FRAMES];
        ae3d_vk_draw_screen_with(vk.post_pipelines[0], &show_set[(int)vk.frame], vk.camdepth_view,
                                 vk.camdepth_sampler, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                                 VK_NULL_HANDLE, VK_NULL_HANDLE);
        return;
    }
    ae3d_vk_draw_pipeline(vk.post_pipelines[index], vk.screen_quad, source_texture, 0, 1);
}

int ae3d_vk_frame_end(void) {
    VkSubmitInfo submit;
    VkPresentInfoKHR present;
    VkPipelineStageFlags wait_stage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    VkResult result;
    int frame_slot = (int)vk.frame;

    if (!vk.recording) return 0;
    /* A model added while the frame was recorded is drawn by it: its
       buffers are written before the frame is submitted. */
    ae3d_vk_flush_uploads();

    ae3d_vk_open_scene_pass();
    ae3d_vkCmdEndRenderPass(vk.command_buffers[vk.frame]);
    vk.pass_open = 0;
    ae3d_vk_stamp_through(6);

    if (vk.post_active) {
        VkRenderPassBeginInfo pass;
        VkViewport viewport;
        VkRect2D scissor;
        // The reflective stage runs when SSR is on and its off-screen targets
        // are built. It mirrors the scene into the intermediate; the ordinary
        // composite then reads that instead of the scene colour, so the bloom
        // it does picks up the mirrored lamps as well.
        int ssr_now = vk.ssr_enabled && vk.post_pipelines[3] &&
                      vk.ssr_framebuffer && vk.camdepth_framebuffer &&
                      vk.ssr_reflect_texture > 0;
        int source;

        memset(&viewport, 0, sizeof(viewport));
        viewport.width = (float)vk.render_extent.width;
        viewport.height = (float)vk.render_extent.height;
        viewport.maxDepth = 1.0f;
        memset(&scissor, 0, sizeof(scissor));
        scissor.extent = vk.render_extent;

        ae3d_vk_setup_post_uniforms();

        if (ssr_now) {
            memset(&pass, 0, sizeof(pass));
            pass.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
            pass.renderPass = vk.ssr_pass;
            pass.framebuffer = vk.ssr_framebuffer;
            pass.renderArea.extent = vk.render_extent;
            ae3d_vkCmdBeginRenderPass(vk.command_buffers[vk.frame], &pass, VK_SUBPASS_CONTENTS_INLINE);
            vk.pass_open = 1;
            ae3d_vkCmdSetViewport(vk.command_buffers[vk.frame], 0, 1, &viewport);
            ae3d_vkCmdSetScissor(vk.command_buffers[vk.frame], 0, 1, &scissor);
            ae3d_vk_draw_screen(vk.post_pipelines[3], &vk.ssr_set[frame_slot], vk.post_texture);
            ae3d_vkCmdEndRenderPass(vk.command_buffers[vk.frame]);
            vk.pass_open = 0;
        }

        source = ssr_now ? vk.ssr_reflect_texture : vk.post_texture;

        /* DLSS, in the temporal pass's place: the scene at its size, its
           depth and its motion vectors into the frame at the frame's. */
        if (vk.dlss_mode) {
            int upscaled = ae3d_vk_run_dlss(source);
            if (upscaled) {
                source = upscaled;
                /* The composite samples the frame-size output now. */
                ae3d_vk_set_texel(vk.extent.width, vk.extent.height);
            }
        }

        /* The temporal pass: this frame folded into the history, written
           into the other history texture, which the composite then reads
           and the next frame reads back as its history. */
        if (!vk.dlss_mode && vk.taa_enabled && vk.taa_pipeline && vk.taa_framebuffer[0] && vk.taa_framebuffer[1] &&
            vk.camdepth_framebuffer && source > 0) {
            int cur = vk.taa_current;
            int old = 1 - cur;
            ae3d_vk_texture *history = &vk.textures[vk.taa_texture[old] - 1];
            ae3d_vk_texture *src = &vk.textures[source - 1];
            ae3d_vk_set_float(&vk.scene[AE3D_VK_PROGRAM_SCENE], AE3D_VK_OFF_TAABLEND,
                              vk.taa_history_valid ? 0.1f : 1.0f);
            memset(&pass, 0, sizeof(pass));
            pass.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
            pass.renderPass = vk.ssr_pass;
            pass.framebuffer = vk.taa_framebuffer[cur];
            pass.renderArea.extent = vk.render_extent;
            ae3d_vkCmdBeginRenderPass(vk.command_buffers[vk.frame], &pass, VK_SUBPASS_CONTENTS_INLINE);
            vk.pass_open = 1;
            ae3d_vkCmdSetViewport(vk.command_buffers[vk.frame], 0, 1, &viewport);
            ae3d_vkCmdSetScissor(vk.command_buffers[vk.frame], 0, 1, &scissor);
            /* With no history yet (the first frame, or after a resize) the
               pass weighs it at nothing, and the frame itself is bound in its
               place: the history texture has never been written, and binding
               it undefined was an error on every such frame (#405). */
            if (!vk.taa_history_valid) history = src;
            ae3d_vk_draw_screen_with(vk.taa_pipeline, &vk.taa_set[cur][frame_slot],
                                     src->view, src->sampler, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                                     history->view, history->sampler);
            ae3d_vkCmdEndRenderPass(vk.command_buffers[vk.frame]);
            vk.pass_open = 0;
            source = vk.taa_texture[cur];
            vk.taa_history_valid = 1;
            vk.taa_current = old;
        }

        /* The composite, at the frame's own size: the scene drawn smaller
           is scaled up by the sampling here. */
        viewport.width = (float)vk.extent.width;
        viewport.height = (float)vk.extent.height;
        scissor.extent = vk.extent;
        memset(&pass, 0, sizeof(pass));
        pass.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        pass.renderPass = vk.post_pass;
        pass.framebuffer = vk.post_framebuffers[vk.image_index];
        pass.renderArea.extent = vk.extent;
        ae3d_vkCmdBeginRenderPass(vk.command_buffers[vk.frame], &pass, VK_SUBPASS_CONTENTS_INLINE);
        vk.pass_open = 1;
        ae3d_vkCmdSetViewport(vk.command_buffers[vk.frame], 0, 1, &viewport);
        ae3d_vkCmdSetScissor(vk.command_buffers[vk.frame], 0, 1, &scissor);
        ae3d_vk_draw_composite(source);
        ae3d_vkCmdEndRenderPass(vk.command_buffers[vk.frame]);
        vk.pass_open = 0;
    }

    // The Aether modules' parts, by stage: its light measured (ae3d.vkmeter),
    // the overlay drawn over it (ae3d.vkoverlay), the frame read back
    // (ae3d.vkreadback). An offscreen frame's image is left in
    // transfer-source layout by its pass; a windowed one's each moves from
    // presenting and back.
    {
        int h;
        for (h = 0; h < vk.hook_count; h++) {
            if (vk.hooks[h].record) vk.hooks[h].record(vk.hooks[h].context);
        }
    }

    ae3d_vk_stamp_through(7);
    vk.stamped[vk.frame] = vk.stamp_next == AE3D_VK_STAMPS;
    ae3d_vkEndCommandBuffer(vk.command_buffers[vk.frame]);

    memset(&submit, 0, sizeof(submit));
    submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    if (!vk.offscreen) {
        submit.waitSemaphoreCount = 1;
        submit.pWaitSemaphores = &vk.image_available[vk.frame];
        submit.pWaitDstStageMask = &wait_stage;
        submit.signalSemaphoreCount = 1;
        submit.pSignalSemaphores = &vk.render_finished[vk.frame];
    }
    submit.commandBufferCount = 1;
    submit.pCommandBuffers = &vk.command_buffers[vk.frame];

    result = ae3d_vkQueueSubmit(vk.graphics_queue, 1, &submit, vk.in_flight[vk.frame]);
    if (result != VK_SUCCESS) {
        vk.recording = 0;
        return ae3d_vk_fail_code("vkQueueSubmit failed", result);
    }

    // Nothing waits here. A frame read back lands in its own slot's buffer,
    // and whoever asks for the pixels waits for it then (ae3d_vk_frame_wait);
    // a program that renders without reading never stalls at all. Reusing
    // this frame's command buffer is already gated on its fence in
    // ae3d_vk_frame_begin.
    if (vk.offscreen) {
        vk.frame = (vk.frame + 1) % AE3D_VK_FRAMES;
        vk.recording = 0;
        return 1;
    }

    memset(&present, 0, sizeof(present));
    present.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    present.waitSemaphoreCount = 1;
    present.pWaitSemaphores = &vk.render_finished[vk.frame];
    present.swapchainCount = 1;
    present.pSwapchains = &vk.swapchain;
    present.pImageIndices = &vk.image_index;

    result = ae3d_vkQueuePresentKHR(vk.present_queue, &present);
    if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR) {
        vk.needs_resize = 1;
        vk.pending_width = (int)vk.extent.width;
        vk.pending_height = (int)vk.extent.height;
    } else if (result != VK_SUCCESS) {
        vk.recording = 0;
        return ae3d_vk_fail_code("vkQueuePresentKHR failed", result);
    }

    vk.frame = (vk.frame + 1) % AE3D_VK_FRAMES;
    vk.recording = 0;
    return 1;
}

/* The finished frame, at an address that does not move.

   Readback is double buffered, so the mapped memory the frame landed in
   alternates: handing that out means the caller is given a different pointer
   every frame for what is, to it, the same image. Anything that keeps work
   against the buffer it was given -- a canvas that uploads the image it is
   drawing, say -- then redoes that work on every frame and on every buffer,
   and never hits what it cached. Copying two megabytes costs a fifth of a
   millisecond; in ae3d's own editor, not copying cost a hundred and fifty. */
/* The size of the frame being drawn, in pixels: the swapchain's extent. */
int ae3d_vk_frame_width(void) { return (int)vk.extent.width; }
int ae3d_vk_frame_height(void) { return (int)vk.extent.height; }
/* The size the scene is drawn at: the frame's times the render scale. */
int ae3d_vk_render_width(void) { return (int)vk.render_extent.width; }
int ae3d_vk_render_height(void) { return (int)vk.render_extent.height; }

/* Draw the scene at `scale` of the frame's size (0.25..1), the composite
   scaling it up: the frame's cost is the scene's pixels. The targets are
   remade at the next frame. Returns the scale in force. */
double ae3d_vk_set_render_scale(double scale) {
    if (scale > 1.0) scale = 1.0;
    if (scale < 0.25) scale = 0.25;
    if (vk.render_scale == scale) return scale;
    vk.render_scale = scale;
    if (vk.ready) {
        vk.needs_resize = 1;
        vk.pending_width = (int)vk.extent.width;
        vk.pending_height = (int)vk.extent.height;
    }
    return scale;
}
double ae3d_vk_render_scale(void) { return vk.render_scale > 0.0 ? vk.render_scale : 1.0; }

/* DLSS runs here: the runtime loaded and the device fit for it. */
int ae3d_vk_dlss_available(void) { return vk.ready && vk.dlss_loaded && vk.dlss_supported; }

/* The frame-size image DLSS writes, sampled by the composite. Made when a
   mode is set, remade with the frame. */
static void ae3d_vk_destroy_dlss_output(void) {
    if (vk.dlss_output) { ae3d_vk_texture_destroy(vk.dlss_output); vk.dlss_output = 0; }
}

static int ae3d_vk_create_dlss_output(void) {
    ae3d_vk_texture *texture = NULL;
    VkSamplerCreateInfo sampler;
    int slot;
    for (slot = 0; slot < AE3D_VK_MAX_TEXTURES; slot++) {
        if (!vk.textures[slot].in_use) { texture = &vk.textures[slot]; break; }
    }
    if (!texture) return ae3d_vk_fail("texture table full");
    if (!ae3d_vk_create_image((int)vk.extent.width, (int)vk.extent.height, 1, VK_FORMAT_R8G8B8A8_UNORM,
                              VK_SAMPLE_COUNT_1_BIT,
                              VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT |
                              VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
                              VK_IMAGE_ASPECT_COLOR_BIT, VK_IMAGE_TILING_OPTIMAL,
                              VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                              &texture->image, &texture->memory, &texture->view)) {
        return 0;
    }
    memset(&sampler, 0, sizeof(sampler));
    sampler.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    sampler.magFilter = VK_FILTER_LINEAR;
    sampler.minFilter = VK_FILTER_LINEAR;
    sampler.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR;
    sampler.maxLod = 1.0f;
    if (ae3d_vkCreateSampler(vk.device, &sampler, NULL, &texture->sampler) != VK_SUCCESS) {
        return ae3d_vk_fail("dlss vkCreateSampler failed");
    }
    texture->width = (int)vk.extent.width;
    texture->height = (int)vk.extent.height;
    texture->in_use = 1;
    vk.dlss_output = slot + 1;
    vk.dlss_output_fresh = 1;
    vk.dlss_reset = 1;
    return 1;
}

/* DLSS at `mode` (native/ae3d_dlss.h: 0 off, 1 performance, 2 balanced,
   3 quality, 4 ultra performance, 5 ultra quality, 6 DLAA): the scene is
   drawn at the render size the mode wants for the frame's size and DLSS
   writes the frame from it, in place of the temporal pass. Returns the
   mode in force: 0 where DLSS is not available. */
int ae3d_vk_set_dlss(int mode) {
    unsigned rw = 0, rh = 0;
    if (mode <= 0 || !ae3d_vk_dlss_available()) {
        if (vk.dlss_mode) {
            vk.dlss_mode = 0;
            ae3d_vk_set_render_scale(1.0);
            ae3d_vkDeviceWaitIdle(vk.device);
            ae3d_vk_destroy_dlss_output();
        }
        return 0;
    }
    if (!ae3d_dlss_optimal(mode, vk.extent.width, vk.extent.height, &rw, &rh)) {
        ae3d_vk_fail(ae3d_dlss_last_error());
        return 0;
    }
    if (!ae3d_dlss_set_options(mode, vk.extent.width, vk.extent.height)) {
        ae3d_vk_fail(ae3d_dlss_last_error());
        return 0;
    }
    vk.dlss_mode = mode;
    /* The mode's render size, as a scale of the frame; DLSS takes any size
       between the mode's least and most, so a pixel of rounding is fine. */
    ae3d_vk_set_render_scale((double)rw / (double)vk.extent.width);
    ae3d_vkDeviceWaitIdle(vk.device);
    ae3d_vk_destroy_dlss_output();
    if (!ae3d_vk_create_dlss_output()) { vk.dlss_mode = 0; return 0; }
    return mode;
}

int ae3d_vk_dlss(void) { return vk.dlss_mode; }
int ae3d_vk_dlss_failed(void) { return vk.dlss_failed; }

/* The camera the frame is drawn with, for DLSS to reproject by: the view
   and the unjittered projection, last frame's pair, the jitter in texture
   space, the lens, and where the camera stands and looks. Matrices are
   column-major, OpenGL-shaped; the Vulkan clip correction is applied here. */
void ae3d_vk_dlss_camera(const double *view, const double *projection,
                         const double *prev_view, const double *prev_projection,
                         double jitter_x, double jitter_y,
                         double near_plane, double far_plane, double fov, double aspect,
                         const double *position, const double *up, const double *right, const double *forward) {
    double proj_c[16], inv_proj[16], vp[16], inv_vp[16], pvp[16], c2p[16], p2c[16];
    double view_c[16], prev_proj_c[16];
    int i;
    ae3d_dlss_camera *cam = &vk.dlss_camera;
    if (!view || !projection || !prev_view || !prev_projection) return;
    ae3d_vk_clip_correct(projection, proj_c);
    ae3d_vk_clip_correct(prev_projection, prev_proj_c);
    memcpy(view_c, view, sizeof(view_c));
    ae3d_vk_mat4_mul(proj_c, view_c, vp);
    ae3d_vk_mat4_mul(prev_proj_c, prev_view, pvp);
    if (!ae3d_vk_mat4_invert(proj_c, inv_proj)) memcpy(inv_proj, proj_c, sizeof(inv_proj));
    if (!ae3d_vk_mat4_invert(vp, inv_vp)) memcpy(inv_vp, vp, sizeof(inv_vp));
    /* This frame's clip to last frame's: through the world. */
    ae3d_vk_mat4_mul(pvp, inv_vp, c2p);
    if (!ae3d_vk_mat4_invert(c2p, p2c)) memcpy(p2c, c2p, sizeof(p2c));
    for (i = 0; i < 16; i++) {
        cam->view_to_clip[i] = (float)proj_c[i];
        cam->clip_to_view[i] = (float)inv_proj[i];
        cam->clip_to_prev_clip[i] = (float)c2p[i];
        cam->prev_clip_to_clip[i] = (float)p2c[i];
    }
    /* The jitter in pixels of the render size; the motion vectors are in
       texture space, from where a pixel is to where it was: DLSS wants
       them the other way round and in that space. */
    cam->jitter_x = (float)(jitter_x * (double)vk.render_extent.width);
    cam->jitter_y = (float)(jitter_y * (double)vk.render_extent.height);
    cam->mvec_scale_x = -1.0f;
    cam->mvec_scale_y = -1.0f;
    for (i = 0; i < 3; i++) {
        cam->position[i] = (float)position[i];
        cam->up[i] = (float)up[i];
        cam->right[i] = (float)right[i];
        cam->forward[i] = (float)forward[i];
    }
    cam->near_plane = (float)near_plane;
    cam->far_plane = (float)far_plane;
    cam->fov = (float)fov;
    cam->aspect = (float)aspect;
    cam->depth_inverted = 0;
    cam->reset = vk.dlss_reset;
    vk.dlss_camera_set = 1;
}

/* The upscale, recorded between the scene's passes and the composite: the
   frame's constants and its four images tagged, evaluated into the output,
   which the composite then samples. Returns the texture to composite from,
   or 0 when DLSS did not run this frame. The renderer's bound state is
   forgotten afterwards, since the evaluation bound its own. */
static int ae3d_vk_run_dlss(int source) {
    ae3d_dlss_image depth, motion, colour_in, colour_out;
    ae3d_vk_texture *src, *out, *vel;
    VkCommandBuffer command = vk.command_buffers[vk.frame];
    if (!vk.dlss_mode || !vk.dlss_output || !vk.velocity_texture || !vk.camdepth_view) return 0;
    if (source <= 0 || source > AE3D_VK_MAX_TEXTURES || !vk.dlss_camera_set) return 0;
    if (!vk.depth_resolved) return 0;
    src = &vk.textures[source - 1];
    out = &vk.textures[vk.dlss_output - 1];
    vel = &vk.textures[vk.velocity_texture - 1];

    if (vk.dlss_output_fresh) {
        /* The output starts in no layout; it is kept shader-readable
           between frames, and DLSS moves it to what it writes through and
           back. */
        VkImageMemoryBarrier barrier;
        memset(&barrier, 0, sizeof(barrier));
        barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        barrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        barrier.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.image = out->image;
        barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        barrier.subresourceRange.levelCount = 1;
        barrier.subresourceRange.layerCount = 1;
        barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        ae3d_vkCmdPipelineBarrier(command, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                                  0, 0, NULL, 0, NULL, 1, &barrier);
        vk.dlss_output_fresh = 0;
    }

    if (!ae3d_dlss_begin_frame(vk.dlss_frame++)) { ae3d_vk_fail(ae3d_dlss_last_error()); return 0; }
    if (!ae3d_dlss_set_constants(&vk.dlss_camera)) { ae3d_vk_fail(ae3d_dlss_last_error()); return 0; }
    vk.dlss_reset = 0;

    memset(&depth, 0, sizeof(depth));
    depth.image = (void *)vk.camdepth_image;
    depth.memory = (void *)vk.camdepth_memory;
    depth.view = (void *)vk.camdepth_view;
    depth.layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    depth.width = vk.render_extent.width;
    depth.height = vk.render_extent.height;
    depth.format = (unsigned)vk.depth_format;
    depth.usage = VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;

    memset(&motion, 0, sizeof(motion));
    motion.image = (void *)vel->image;
    motion.memory = (void *)vel->memory;
    motion.view = (void *)vel->view;
    motion.layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    motion.width = vk.render_extent.width;
    motion.height = vk.render_extent.height;
    motion.format = (unsigned)vk.velocity_format;
    motion.usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;

    memset(&colour_in, 0, sizeof(colour_in));
    colour_in.image = (void *)src->image;
    colour_in.memory = (void *)src->memory;
    colour_in.view = (void *)src->view;
    colour_in.layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    colour_in.width = vk.render_extent.width;
    colour_in.height = vk.render_extent.height;
    colour_in.format = (unsigned)vk.color_format;
    colour_in.usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;

    memset(&colour_out, 0, sizeof(colour_out));
    colour_out.image = (void *)out->image;
    colour_out.memory = (void *)out->memory;
    colour_out.view = (void *)out->view;
    colour_out.layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    colour_out.width = vk.extent.width;
    colour_out.height = vk.extent.height;
    colour_out.format = (unsigned)VK_FORMAT_R8G8B8A8_UNORM;
    colour_out.usage = VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT |
                       VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;

    if (!ae3d_dlss_tag(&depth, &motion, &colour_in, &colour_out, (void *)command) ||
        !ae3d_dlss_evaluate((void *)command)) {
        /* A frame DLSS would not take: said once, and the frame is drawn
           as it was, at the scene's size, from here on. */
        fprintf(stderr, "ae3d: DLSS off: %s" "\n", ae3d_dlss_last_error());
        ae3d_vk_fail(ae3d_dlss_last_error());
        vk.dlss_mode = 0;
        vk.dlss_failed = 1;
        return 0;
    }
    vk.bound_pipeline = VK_NULL_HANDLE;
    vk.bound_texture = 0;
    vk.bound_normal = 0;
    return vk.dlss_output;
}

int ae3d_vk_offscreen_width(void) { return vk.offscreen ? (int)vk.extent.width : 0; }
int ae3d_vk_offscreen_height(void) { return vk.offscreen ? (int)vk.extent.height : 0; }

/* Windowed capture: read a presented frame back the way the offscreen path
   reads its target. The staging buffers are made on first use, sized to the
   swapchain extent, and freed with the swapchain. */

/* The pose bank the draws after this are posed from, as the handle of a
   float texture made by ae3d_vk_texture_create_float, or zero for none.
   A crowd draw is a skinned draw with a bank bound. */
void ae3d_vk_set_pose_bank(int texture_handle) { vk.pose_bank = texture_handle; }

/* A free slot of the mesh table, which grows when every one is taken, and
   its handle; null when it could not grow. */
static ae3d_vk_mesh *ae3d_vk_mesh_slot(int *handle) {
    int i, grown;
    ae3d_vk_mesh *fresh;
    for (i = 0; i < vk.mesh_capacity; i++) {
        if (!vk.meshes[i].in_use) { *handle = i + 1; return &vk.meshes[i]; }
    }
    grown = vk.mesh_capacity ? vk.mesh_capacity * 2 : 16;
    fresh = (ae3d_vk_mesh *)realloc(vk.meshes, (size_t)grown * sizeof(ae3d_vk_mesh));
    if (!fresh) { ae3d_vk_fail("out of memory"); return NULL; }
    memset(fresh + vk.mesh_capacity, 0, (size_t)(grown - vk.mesh_capacity) * sizeof(ae3d_vk_mesh));
    vk.meshes = fresh;
    *handle = vk.mesh_capacity + 1;
    vk.mesh_capacity = grown;
    return &vk.meshes[*handle - 1];
}

/* A mesh ae3d.vkmesh made -- its vertex and index buffers, and its skin's
   where it has one, device-local, their copies recorded into the upload
   batch -- into the table the draws read. The handle, or 0 when the table
   could not grow, the buffers then destroyed once the batch that names
   them has run. */
int ae3d_vk_mesh_adopt(void *vertex_buffer, void *vertex_memory, void *index_buffer, void *index_memory,
                       void *skin_buffer, void *skin_memory, int index_count) {
    ae3d_vk_mesh *slot;
    int handle = 0;

    if (!vk.device || !vertex_buffer || !index_buffer) return 0;
    slot = ae3d_vk_mesh_slot(&handle);
    if (!slot) {
        ae3d_vk_flush_uploads();
        ae3d_vkDestroyBuffer(vk.device, (VkBuffer)vertex_buffer, NULL);
        ae3d_vkFreeMemory(vk.device, (VkDeviceMemory)vertex_memory, NULL);
        ae3d_vkDestroyBuffer(vk.device, (VkBuffer)index_buffer, NULL);
        ae3d_vkFreeMemory(vk.device, (VkDeviceMemory)index_memory, NULL);
        if (skin_buffer) {
            ae3d_vkDestroyBuffer(vk.device, (VkBuffer)skin_buffer, NULL);
            ae3d_vkFreeMemory(vk.device, (VkDeviceMemory)skin_memory, NULL);
        }
        return 0;
    }
    memset(slot, 0, sizeof(*slot));
    slot->vertex_buffer = (VkBuffer)vertex_buffer;
    slot->vertex_memory = (VkDeviceMemory)vertex_memory;
    slot->index_buffer = (VkBuffer)index_buffer;
    slot->index_memory = (VkDeviceMemory)index_memory;
    slot->skin_buffer = (VkBuffer)skin_buffer;
    slot->skin_memory = (VkDeviceMemory)skin_memory;
    slot->skinned = skin_buffer != NULL;
    slot->index_count = (unsigned)index_count;
    slot->in_use = 1;
    return handle;
}

/* The slots of the mesh table in use, meshes and instance streams: what
   tests/test_vk_mesh counts a release by. */
int ae3d_vk_mesh_count(void) {
    int i, live = 0;
    for (i = 0; i < vk.mesh_capacity; i++) live += vk.meshes[i].in_use != 0;
    return live;
}

/* A failure an Aether module of the backend's met, for ae3d_vk_last_error. */
void ae3d_vk_set_error(const char *message) { ae3d_vk_fail(message); }

// The instance stream is interleaved into the layout the pipeline declares: a
// matrix then a colour, one vertex-input binding stepping per instance.
// One matrix and one colour per instance, in the layout the vertex shader
// declares. Both the first upload and every later refresh build it the same way.
/* The stream packed into `packed`, sixteen floats of matrix and four of
   colour an instance, as the pipeline's second vertex binding reads it. */
typedef struct {
    float *packed;
    const float *matrices, *colours, *phases;
    int has_colours;
} ae3d_vk_pack_job;

static void ae3d_vk_pack_instances_run(void *ctx, int start, int end) {
    ae3d_vk_pack_job *job = (ae3d_vk_pack_job *)ctx;
    float *packed = job->packed;
    int i;
    for (i = start; i < end; i++) {
        memcpy(packed + (size_t)i * 20, job->matrices + (size_t)i * 16, 16 * sizeof(float));
        if (job->has_colours && job->colours) {
            memcpy(packed + (size_t)i * 20 + 16, job->colours + (size_t)i * 3, 3 * sizeof(float));
        } else {
            packed[i * 20 + 16] = 1.0f;
            packed[i * 20 + 17] = 1.0f;
            packed[i * 20 + 18] = 1.0f;
        }
        /* The phase rides in the float after the colour; the crowd vertex
           shader reads it, nothing else does. */
        packed[i * 20 + 19] = job->phases ? job->phases[i] : 0.0f;
    }
}

/* Eighty bytes an instance into the mapped ring: forty megabytes a frame
   for half a million figures, which is a memory copy worth every core. */
static void ae3d_vk_pack_instances_into(float *packed, void *instances, int count) {
    ae3d_vk_pack_job job;
    job.packed = packed;
    job.matrices = ae3d_inst_matrix_data(instances);
    job.colours = ae3d_inst_color_data(instances);
    job.phases = ae3d_inst_has_phases(instances) ? ae3d_inst_phase_data(instances) : NULL;
    job.has_colours = ae3d_inst_has_colors(instances);
    ae3d_jobs_for(count, 8192, ae3d_vk_pack_instances_run, &job);
}

static float *ae3d_vk_pack_instances(void *instances, int count) {
    float *packed = (float *)malloc((size_t)count * 20 * sizeof(float));
    if (!packed) return NULL;
    ae3d_vk_pack_instances_into(packed, instances, count);
    return packed;
}

// An instance stream that has been moved or recoloured since it was uploaded.
// Without this the buffer is written once, when the model is registered, and a
// particle that moves or a block that changes colour never reaches the GPU.
static void ae3d_vk_free_ring(ae3d_vk_mesh *slot) {
    unsigned i;
    for (i = 0; i < AE3D_VK_FRAMES; i++) {
        if (slot->ring_mapped[i]) ae3d_vkUnmapMemory(vk.device, slot->ring_memory[i]);
        if (slot->ring[i]) ae3d_vkDestroyBuffer(vk.device, slot->ring[i], NULL);
        if (slot->ring_memory[i]) ae3d_vkFreeMemory(vk.device, slot->ring_memory[i], NULL);
        slot->ring[i] = VK_NULL_HANDLE;
        slot->ring_memory[i] = VK_NULL_HANDLE;
        slot->ring_mapped[i] = NULL;
    }
    slot->ring_size = 0;
    slot->streaming = 0;
}

/* The ring for a stream of `bytes`, made or regrown. Growing waits for the
   device once, since every slot of the old ring may be in flight; a stream
   that keeps its size never waits again. */
static int ae3d_vk_ensure_ring(ae3d_vk_mesh *slot, VkDeviceSize bytes) {
    unsigned i;
    if (slot->streaming && slot->ring_size >= bytes) return 1;

    ae3d_vkDeviceWaitIdle(vk.device);
    if (slot->streaming) {
        /* Regrowing: the bound buffer is one of the ring's, which the ring
           frees. Destroying it here as well destroyed it twice, and the
           driver fell over on the second when a stream grew. */
        slot->vertex_buffer = VK_NULL_HANDLE;
        slot->vertex_memory = VK_NULL_HANDLE;
    }
    ae3d_vk_free_ring(slot);
    /* The device-local buffer the first upload made is not read again. */
    if (slot->vertex_buffer) ae3d_vkDestroyBuffer(vk.device, slot->vertex_buffer, NULL);
    if (slot->vertex_memory) ae3d_vkFreeMemory(vk.device, slot->vertex_memory, NULL);
    slot->vertex_buffer = VK_NULL_HANDLE;
    slot->vertex_memory = VK_NULL_HANDLE;

    for (i = 0; i < AE3D_VK_FRAMES; i++) {
        if (!ae3d_vk_create_buffer(bytes, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
                                   VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT
                                       | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                                   &slot->ring[i], &slot->ring_memory[i])) {
            ae3d_vk_free_ring(slot);
            return 0;
        }
        if (ae3d_vkMapMemory(vk.device, slot->ring_memory[i], 0, bytes, 0,
                             &slot->ring_mapped[i]) != VK_SUCCESS) {
            slot->ring_mapped[i] = NULL;
            ae3d_vk_free_ring(slot);
            return ae3d_vk_fail("vkMapMemory failed for an instance ring");
        }
    }
    slot->ring_size = bytes;
    slot->streaming = 1;
    return 1;
}

int ae3d_vk_update_instances(int handle, void *instances) {
    ae3d_vk_mesh *slot;
    int count = ae3d_inst_count(instances);
    VkDeviceSize bytes;

    if (!vk.ready || handle <= 0 || handle > vk.mesh_capacity || count <= 0) return 0;
    slot = &vk.meshes[handle - 1];
    if (!slot->in_use) return 0;

    if (ae3d_inst_is_points(instances)) {
        /* A point stream is already the bytes the binding reads: one copy
           into this frame's slot of the ring, no packing. */
        const float *points = ae3d_inst_point_data(instances);
        if (!points) return 0;
        bytes = (VkDeviceSize)count * 8 * sizeof(float);
        if (!ae3d_vk_ensure_ring(slot, bytes)) return 0;
        memcpy(slot->ring_mapped[vk.frame], points, (size_t)bytes);
        slot->vertex_buffer = slot->ring[vk.frame];
        slot->points = 1;
        return 1;
    }

    /* Packed straight into this frame's slot of the ring, which this
       frame's draws then bind. The first update turns the stream over from
       the device-local buffer of the upload to the ring; from then on an
       update is one pass over the instances into mapped memory, where it
       used to be a wait for the whole device, a destroy and a staged upload
       of a fresh buffer every frame. */
    bytes = (VkDeviceSize)count * 20 * sizeof(float);
    if (!ae3d_vk_ensure_ring(slot, bytes)) return 0;
    ae3d_vk_pack_instances_into((float *)slot->ring_mapped[vk.frame], instances, count);
    slot->vertex_buffer = slot->ring[vk.frame];
    return 1;
}

int ae3d_vk_upload_instances(void *instances) {
    const float *matrices = ae3d_inst_matrix_data(instances);
    int count = ae3d_inst_count(instances);
    ae3d_vk_mesh *slot = NULL;
    float *packed;
    int handle = 0;
    int points = ae3d_inst_is_points(instances);

    if (points) matrices = ae3d_inst_point_data(instances);
    if (!vk.device || !matrices || count <= 0) { ae3d_vk_fail("no instances"); return 0; }

    slot = ae3d_vk_mesh_slot(&handle);
    if (!slot) return 0;

    if (points) {
        if (!ae3d_vk_upload_buffer((void *)matrices, (VkDeviceSize)count * 8 * sizeof(float),
                                   VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
                                   &slot->vertex_buffer, &slot->vertex_memory)) {
            return 0;
        }
        slot->points = 1;
        slot->index_count = 0;
        slot->in_use = 1;
        return handle;
    }

    packed = ae3d_vk_pack_instances(instances, count);
    if (!packed) { ae3d_vk_fail("out of memory"); return 0; }

    if (!ae3d_vk_upload_buffer(packed, (VkDeviceSize)count * 20 * sizeof(float),
                               VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
                               &slot->vertex_buffer, &slot->vertex_memory)) {
        free(packed);
        return 0;
    }
    free(packed);

    slot->points = 0;
    slot->index_count = 0;
    slot->in_use = 1;
    return handle;
}

void ae3d_vk_free_mesh(int handle) {
    ae3d_vk_mesh *mesh;

    if (!vk.ready || handle <= 0 || handle > vk.mesh_capacity) return;
    mesh = &vk.meshes[handle - 1];
    if (!mesh->in_use) return;

    ae3d_vk_flush_uploads();
    ae3d_vkDeviceWaitIdle(vk.device);
    if (mesh->streaming) {
        /* The bound buffer is one of the ring's; the ring frees it. */
        mesh->vertex_buffer = VK_NULL_HANDLE;
        mesh->vertex_memory = VK_NULL_HANDLE;
        ae3d_vk_free_ring(mesh);
    }
    ae3d_vkDestroyBuffer(vk.device, mesh->vertex_buffer, NULL);
    ae3d_vkFreeMemory(vk.device, mesh->vertex_memory, NULL);
    ae3d_vkDestroyBuffer(vk.device, mesh->index_buffer, NULL);
    ae3d_vkFreeMemory(vk.device, mesh->index_memory, NULL);
    if (mesh->skin_buffer) {
        ae3d_vkDestroyBuffer(vk.device, mesh->skin_buffer, NULL);
        ae3d_vkFreeMemory(vk.device, mesh->skin_memory, NULL);
    }
    memset(mesh, 0, sizeof(*mesh));
}

void ae3d_vk_shutdown(void) {
    unsigned i;

    if (!vk.ready) return;
    ae3d_vk_flush_uploads();
    free(vk.batch_kept);
    free(vk.batch_kept_memory);
    vk.batch_kept = NULL;
    vk.batch_kept_memory = NULL;
    vk.batch_kept_capacity = 0;
    ae3d_vkDeviceWaitIdle(vk.device);

    for (i = 0; i < (unsigned)vk.mesh_capacity; i++) {
        if (vk.meshes[i].in_use) {
            if (vk.meshes[i].streaming) {
                vk.meshes[i].vertex_buffer = VK_NULL_HANDLE;
                vk.meshes[i].vertex_memory = VK_NULL_HANDLE;
                ae3d_vk_free_ring(&vk.meshes[i]);
            }
            ae3d_vkDestroyBuffer(vk.device, vk.meshes[i].vertex_buffer, NULL);
            ae3d_vkFreeMemory(vk.device, vk.meshes[i].vertex_memory, NULL);
            ae3d_vkDestroyBuffer(vk.device, vk.meshes[i].index_buffer, NULL);
            ae3d_vkFreeMemory(vk.device, vk.meshes[i].index_memory, NULL);
            if (vk.meshes[i].skin_buffer) {
                ae3d_vkDestroyBuffer(vk.device, vk.meshes[i].skin_buffer, NULL);
                ae3d_vkFreeMemory(vk.device, vk.meshes[i].skin_memory, NULL);
            }
        }
    }
    free(vk.meshes);
    vk.meshes = NULL;
    vk.mesh_capacity = 0;

    if (vk.timestamps) {
        ae3d_vkDestroyQueryPool(vk.device, vk.timestamps, NULL);
        vk.timestamps = VK_NULL_HANDLE;
    }
    for (i = 0; i < AE3D_VK_FRAMES; i++) {
        if (vk.image_available[i]) ae3d_vkDestroySemaphore(vk.device, vk.image_available[i], NULL);
        if (vk.render_finished[i]) ae3d_vkDestroySemaphore(vk.device, vk.render_finished[i], NULL);
        if (vk.in_flight[i]) ae3d_vkDestroyFence(vk.device, vk.in_flight[i], NULL);
    }
    for (i = 0; i < AE3D_VK_MAX_TEXTURES; i++) {
        ae3d_vk_texture *texture = &vk.textures[i];
        if (!texture->in_use) continue;
        if (texture->sampler) ae3d_vkDestroySampler(vk.device, texture->sampler, NULL);
        if (texture->view) ae3d_vkDestroyImageView(vk.device, texture->view, NULL);
        if (texture->image) ae3d_vkDestroyImage(vk.device, texture->image, NULL);
        if (texture->memory) ae3d_vkFreeMemory(vk.device, texture->memory, NULL);
        memset(texture, 0, sizeof(*texture));
    }

    for (i = 0; i < AE3D_VK_FRAMES; i++) {
        ae3d_vk_uniform_ring *ring = &vk.uniforms[i];
        if (ring->mapped) ae3d_vkUnmapMemory(vk.device, ring->memory);
        if (ring->buffer) ae3d_vkDestroyBuffer(vk.device, ring->buffer, NULL);
        if (ring->memory) ae3d_vkFreeMemory(vk.device, ring->memory, NULL);
        memset(ring, 0, sizeof(*ring));
        ae3d_vk_cluster_destroy(&vk.cluster_lights[i]);
        ae3d_vk_cluster_destroy(&vk.cluster_words[i]);
    }

    if (vk.identity_instance) ae3d_vkDestroyBuffer(vk.device, vk.identity_instance, NULL);
    if (vk.identity_instance_memory) ae3d_vkFreeMemory(vk.device, vk.identity_instance_memory, NULL);
    if (vk.empty_skin) ae3d_vkDestroyBuffer(vk.device, vk.empty_skin, NULL);
    if (vk.empty_skin_memory) ae3d_vkFreeMemory(vk.device, vk.empty_skin_memory, NULL);

    if (vk.descriptor_pool) ae3d_vkDestroyDescriptorPool(vk.device, vk.descriptor_pool, NULL);
    if (vk.set_layout) ae3d_vkDestroyDescriptorSetLayout(vk.device, vk.set_layout, NULL);

    if (vk.command_pool) ae3d_vkDestroyCommandPool(vk.device, vk.command_pool, NULL);
    for (i = 0; i < 2; i++) {
        if (vk.pipeline[i]) ae3d_vkDestroyPipeline(vk.device, vk.pipeline[i], NULL);
        if (vk.water_pipeline[i]) ae3d_vkDestroyPipeline(vk.device, vk.water_pipeline[i], NULL);
        if (vk.crowd_pipeline[i]) ae3d_vkDestroyPipeline(vk.device, vk.crowd_pipeline[i], NULL);
    }
    if (vk.pipeline_blend) ae3d_vkDestroyPipeline(vk.device, vk.pipeline_blend, NULL);
    if (vk.water_pipeline_blend) ae3d_vkDestroyPipeline(vk.device, vk.water_pipeline_blend, NULL);
    if (vk.crowd_pipeline_blend) ae3d_vkDestroyPipeline(vk.device, vk.crowd_pipeline_blend, NULL);
    if (vk.crowd_shadow_pipeline) ae3d_vkDestroyPipeline(vk.device, vk.crowd_shadow_pipeline, NULL);
    /* The skinned pipelines too: left alive, the device went down with them
       still made (#405). */
    for (i = 0; i < 2; i++) {
        if (vk.skinned_pipeline[i]) ae3d_vkDestroyPipeline(vk.device, vk.skinned_pipeline[i], NULL);
    }
    if (vk.skinned_pipeline_blend) ae3d_vkDestroyPipeline(vk.device, vk.skinned_pipeline_blend, NULL);
    if (vk.skinned_shadow_pipeline) ae3d_vkDestroyPipeline(vk.device, vk.skinned_shadow_pipeline, NULL);
    if (vk.sky_pipeline) ae3d_vkDestroyPipeline(vk.device, vk.sky_pipeline, NULL);
    if (vk.ssao_pipeline) ae3d_vkDestroyPipeline(vk.device, vk.ssao_pipeline, NULL);
    ae3d_vk_destroy_dlss_output();
    if (vk.depth_resolve_pipeline) ae3d_vkDestroyPipeline(vk.device, vk.depth_resolve_pipeline, NULL);
    if (vk.taa_pipeline) ae3d_vkDestroyPipeline(vk.device, vk.taa_pipeline, NULL);
    if (vk.point_pipeline_blend) ae3d_vkDestroyPipeline(vk.device, vk.point_pipeline_blend, NULL);
    if (vk.point_pipeline[0]) ae3d_vkDestroyPipeline(vk.device, vk.point_pipeline[0], NULL);
    if (vk.point_pipeline[1]) ae3d_vkDestroyPipeline(vk.device, vk.point_pipeline[1], NULL);
    if (vk.point_shadow_pipeline) ae3d_vkDestroyPipeline(vk.device, vk.point_shadow_pipeline, NULL);
    /* All four: the composite's three and the SSR's, which a loop to three
       left alive (#405). */
    for (i = 0; i < (unsigned)(sizeof(vk.post_pipelines) / sizeof(vk.post_pipelines[0])); i++) {
        if (vk.post_pipelines[i]) ae3d_vkDestroyPipeline(vk.device, vk.post_pipelines[i], NULL);
    }
    if (vk.pipeline_layout) ae3d_vkDestroyPipelineLayout(vk.device, vk.pipeline_layout, NULL);

    ae3d_vk_destroy_swapchain();
    if (vk.render_pass) ae3d_vkDestroyRenderPass(vk.device, vk.render_pass, NULL);
    if (vk.render_pass_first) ae3d_vkDestroyRenderPass(vk.device, vk.render_pass_first, NULL);
    if (vk.render_pass_rest) ae3d_vkDestroyRenderPass(vk.device, vk.render_pass_rest, NULL);
    if (vk.scene_pass) ae3d_vkDestroyRenderPass(vk.device, vk.scene_pass, NULL);
    if (vk.scene_pass_first) ae3d_vkDestroyRenderPass(vk.device, vk.scene_pass_first, NULL);
    if (vk.scene_pass_rest) ae3d_vkDestroyRenderPass(vk.device, vk.scene_pass_rest, NULL);
    if (vk.post_pass) ae3d_vkDestroyRenderPass(vk.device, vk.post_pass, NULL);
    if (vk.ssr_pass) ae3d_vkDestroyRenderPass(vk.device, vk.ssr_pass, NULL);
    if (vk.shadow_pass) ae3d_vkDestroyRenderPass(vk.device, vk.shadow_pass, NULL);
    ae3d_vk_destroy_lamp_target();
    if (vk.lamp_pass) ae3d_vkDestroyRenderPass(vk.device, vk.lamp_pass, NULL);
    if (vk.camdepth_pass) ae3d_vkDestroyRenderPass(vk.device, vk.camdepth_pass, NULL);
    if (vk.shadow_pipeline) ae3d_vkDestroyPipeline(vk.device, vk.shadow_pipeline, NULL);
    ae3d_vk_destroy_shadow_target();
    /* Streamline goes before the device it wrapped, which ae3d.vkdevice
       destroys after this, with the surface and the instance. */
    if (vk.dlss_loaded) { ae3d_dlss_shutdown(); vk.dlss_loaded = 0; vk.dlss_supported = 0; vk.dlss_mode = 0; }

    {
        /* The hooks outlive the device: installed once a process, they are
           the next device's too. */
        ae3d_vk_hooks hooks[AE3D_VK_HOOKS];
        int hook_count = vk.hook_count;
        memcpy(hooks, vk.hooks, sizeof(hooks));
        memset(&vk, 0, sizeof(vk));
        memcpy(vk.hooks, hooks, sizeof(hooks));
        vk.hook_count = hook_count;
    }
}
