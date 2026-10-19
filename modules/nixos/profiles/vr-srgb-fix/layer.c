/* ~/nixos-config/modules/nixos/profiles/vr-srgb-fix/layer.c
 *
 * OpenXR API layer that undoes a double sRGB encode on Proton D3D11 games.
 *
 * Windows runtimes hand D3D11 apps TYPELESS swapchain textures; Proton's
 * wineopenxr hands them fully typed *_SRGB ones. Engines that write their own
 * gamma through a UNORM view (War Thunder) then get encoded a second time, so
 * the headset image is washed out while the desktop mirror looks right.
 *
 * The layer sits on the host side, between wineopenxr and the runtime (so
 * nothing inside the game's Windows process changes). On every release of an
 * 8-bit sRGB colour swapchain image it runs one sRGB->linear pass over the raw
 * bytes: copy to a UNORM scratch image, decode in a compute shader, copy back.
 * The runtime's single decode then yields the right colours.
 *
 * Implicit layer, enabled only when XR_SRGB_FIX is set in the environment.
 */
#define VK_NO_PROTOTYPES
#include <vulkan/vulkan.h>
#define XR_USE_GRAPHICS_API_VULKAN
#include <openxr/openxr.h>
#include <openxr/openxr_platform.h>
#include <openxr/openxr_loader_negotiation.h>

#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "decode.spv.h"

#define LOG(...) fprintf(stderr, "[xr-srgb-fix] " __VA_ARGS__)
#define MAX_IMAGES 8
#define MAX_SWAPCHAINS 16

static PFN_xrGetInstanceProcAddr next_gipa;
static PFN_xrCreateSession next_create_session;
static PFN_xrCreateSwapchain next_create_swapchain;
static PFN_xrDestroySwapchain next_destroy_swapchain;
static PFN_xrEnumerateSwapchainImages next_enumerate_images;
static PFN_xrAcquireSwapchainImage next_acquire;
static PFN_xrReleaseSwapchainImage next_release;

/* Vulkan state for the (single) session. */
static struct {
  int ok;
  VkInstance instance;
  VkPhysicalDevice pdev;
  VkDevice dev;
  VkQueue queue;
  uint32_t qfi;
  VkShaderModule shader;
  VkDescriptorSetLayout dsl;
  VkPipelineLayout layout;
  VkPipeline pipeline;
  VkCommandPool pool;
  VkDescriptorPool dpool;
#define F(n) PFN_##n n
  F(vkGetPhysicalDeviceMemoryProperties);
  F(vkGetDeviceQueue);
  F(vkCreateShaderModule);
  F(vkCreateDescriptorSetLayout);
  F(vkCreatePipelineLayout);
  F(vkCreateComputePipelines);
  F(vkCreateCommandPool);
  F(vkCreateDescriptorPool);
  F(vkAllocateDescriptorSets);
  F(vkFreeDescriptorSets);
  F(vkUpdateDescriptorSets);
  F(vkAllocateCommandBuffers);
  F(vkFreeCommandBuffers);
  F(vkBeginCommandBuffer);
  F(vkEndCommandBuffer);
  F(vkCmdPipelineBarrier);
  F(vkCmdCopyImage);
  F(vkCmdBindPipeline);
  F(vkCmdBindDescriptorSets);
  F(vkCmdDispatch);
  F(vkCreateImage);
  F(vkDestroyImage);
  F(vkCreateImageView);
  F(vkDestroyImageView);
  F(vkGetImageMemoryRequirements);
  F(vkAllocateMemory);
  F(vkFreeMemory);
  F(vkBindImageMemory);
  F(vkCreateFence);
  F(vkDestroyFence);
  F(vkWaitForFences);
  F(vkResetFences);
  F(vkGetFenceStatus);
  F(vkQueueSubmit);
#undef F
} vk;

struct swapchain {
  XrSwapchain handle;
  int used, ready, broken;
  uint32_t width, height, layers, count;
  VkImage images[MAX_IMAGES];
  VkCommandBuffer cmd[MAX_IMAGES];
  VkFence fence[MAX_IMAGES];
  VkImage scratch;
  VkDeviceMemory memory;
  VkImageView view;
  VkDescriptorSet set;
  uint32_t acquired[MAX_IMAGES];
  uint32_t head, tail;
};

static struct swapchain swapchains[MAX_SWAPCHAINS];
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

static struct swapchain *find(XrSwapchain h) {
  for (int i = 0; i < MAX_SWAPCHAINS; i++)
    if (swapchains[i].used && swapchains[i].handle == h) return &swapchains[i];
  return NULL;
}

static int is_srgb8(int64_t f) { return f == VK_FORMAT_R8G8B8A8_SRGB || f == VK_FORMAT_B8G8R8A8_SRGB; }

/* ---- Vulkan setup ------------------------------------------------------ */

static int setup_vulkan(const XrGraphicsBindingVulkanKHR *b) {
  void *lib = dlopen("libvulkan.so.1", RTLD_NOW | RTLD_LOCAL);
  if (!lib) { LOG("dlopen libvulkan: %s\n", dlerror()); return 0; }
  PFN_vkGetInstanceProcAddr gipa = (PFN_vkGetInstanceProcAddr)dlsym(lib, "vkGetInstanceProcAddr");
  if (!gipa) return 0;
  PFN_vkGetDeviceProcAddr gdpa = (PFN_vkGetDeviceProcAddr)gipa(b->instance, "vkGetDeviceProcAddr");
  if (!gdpa) return 0;

  vk.instance = b->instance;
  vk.pdev = b->physicalDevice;
  vk.dev = b->device;
  vk.qfi = b->queueFamilyIndex;
  vk.vkGetPhysicalDeviceMemoryProperties =
      (PFN_vkGetPhysicalDeviceMemoryProperties)gipa(b->instance, "vkGetPhysicalDeviceMemoryProperties");
#define D(n) if (!(vk.n = (PFN_##n)gdpa(vk.dev, #n))) { LOG("missing %s\n", #n); return 0; }
  D(vkGetDeviceQueue) D(vkCreateShaderModule) D(vkCreateDescriptorSetLayout) D(vkCreatePipelineLayout)
  D(vkCreateComputePipelines) D(vkCreateCommandPool) D(vkCreateDescriptorPool) D(vkAllocateDescriptorSets)
  D(vkFreeDescriptorSets) D(vkUpdateDescriptorSets) D(vkAllocateCommandBuffers) D(vkFreeCommandBuffers)
  D(vkBeginCommandBuffer) D(vkEndCommandBuffer) D(vkCmdPipelineBarrier) D(vkCmdCopyImage)
  D(vkCmdBindPipeline) D(vkCmdBindDescriptorSets) D(vkCmdDispatch) D(vkCreateImage) D(vkDestroyImage)
  D(vkCreateImageView) D(vkDestroyImageView) D(vkGetImageMemoryRequirements) D(vkAllocateMemory)
  D(vkFreeMemory) D(vkBindImageMemory) D(vkCreateFence) D(vkDestroyFence) D(vkWaitForFences)
  D(vkResetFences) D(vkGetFenceStatus) D(vkQueueSubmit)
#undef D
  if (!vk.vkGetPhysicalDeviceMemoryProperties) return 0;
  vk.vkGetDeviceQueue(vk.dev, b->queueFamilyIndex, b->queueIndex, &vk.queue);

  VkShaderModuleCreateInfo smci = {VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO, NULL, 0,
                                   sizeof(decode_spv), decode_spv};
  if (vk.vkCreateShaderModule(vk.dev, &smci, NULL, &vk.shader)) return 0;

  VkDescriptorSetLayoutBinding bind = {0, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL};
  VkDescriptorSetLayoutCreateInfo dslci = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO, NULL, 0, 1, &bind};
  if (vk.vkCreateDescriptorSetLayout(vk.dev, &dslci, NULL, &vk.dsl)) return 0;

  VkPipelineLayoutCreateInfo plci = {VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO, NULL, 0, 1, &vk.dsl, 0, NULL};
  if (vk.vkCreatePipelineLayout(vk.dev, &plci, NULL, &vk.layout)) return 0;

  VkComputePipelineCreateInfo cpci = {
      VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO, NULL, 0,
      {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, NULL, 0, VK_SHADER_STAGE_COMPUTE_BIT, vk.shader, "main", NULL},
      vk.layout, VK_NULL_HANDLE, 0};
  if (vk.vkCreateComputePipelines(vk.dev, VK_NULL_HANDLE, 1, &cpci, NULL, &vk.pipeline)) return 0;

  VkCommandPoolCreateInfo cpi = {VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO, NULL, 0, vk.qfi};
  if (vk.vkCreateCommandPool(vk.dev, &cpi, NULL, &vk.pool)) return 0;

  VkDescriptorPoolSize ps = {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, MAX_SWAPCHAINS};
  VkDescriptorPoolCreateInfo dpci = {VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO, NULL,
                                     VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT, MAX_SWAPCHAINS, 1, &ps};
  if (vk.vkCreateDescriptorPool(vk.dev, &dpci, NULL, &vk.dpool)) return 0;
  return 1;
}

static void barrier(VkCommandBuffer cb, VkImage img, uint32_t layers, VkImageLayout from, VkImageLayout to,
                    VkAccessFlags src_access, VkAccessFlags dst_access, VkPipelineStageFlags src_stage,
                    VkPipelineStageFlags dst_stage) {
  VkImageMemoryBarrier b = {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, NULL, src_access, dst_access, from, to,
                            VK_QUEUE_FAMILY_IGNORED, VK_QUEUE_FAMILY_IGNORED, img,
                            {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, layers}};
  vk.vkCmdPipelineBarrier(cb, src_stage, dst_stage, 0, 0, NULL, 0, NULL, 1, &b);
}

/* Scratch image + one pre-recorded command buffer per swapchain image. */
static int setup_swapchain(struct swapchain *s) {
  VkImageCreateInfo ici = {VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO, NULL, 0, VK_IMAGE_TYPE_2D, VK_FORMAT_R8G8B8A8_UNORM,
                           {s->width, s->height, 1}, 1, s->layers, VK_SAMPLE_COUNT_1_BIT, VK_IMAGE_TILING_OPTIMAL,
                           VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
                           VK_SHARING_MODE_EXCLUSIVE, 0, NULL, VK_IMAGE_LAYOUT_UNDEFINED};
  if (vk.vkCreateImage(vk.dev, &ici, NULL, &s->scratch)) return 0;

  VkMemoryRequirements req;
  VkPhysicalDeviceMemoryProperties props;
  vk.vkGetImageMemoryRequirements(vk.dev, s->scratch, &req);
  vk.vkGetPhysicalDeviceMemoryProperties(vk.pdev, &props);
  uint32_t type = UINT32_MAX;
  for (uint32_t i = 0; i < props.memoryTypeCount; i++)
    if ((req.memoryTypeBits & (1u << i)) && (props.memoryTypes[i].propertyFlags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)) {
      type = i;
      break;
    }
  if (type == UINT32_MAX) return 0;
  VkMemoryAllocateInfo mai = {VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO, NULL, req.size, type};
  if (vk.vkAllocateMemory(vk.dev, &mai, NULL, &s->memory)) return 0;
  if (vk.vkBindImageMemory(vk.dev, s->scratch, s->memory, 0)) return 0;

  VkImageViewCreateInfo vci = {VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO, NULL, 0, s->scratch,
                               VK_IMAGE_VIEW_TYPE_2D_ARRAY, VK_FORMAT_R8G8B8A8_UNORM, {0},
                               {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, s->layers}};
  if (vk.vkCreateImageView(vk.dev, &vci, NULL, &s->view)) return 0;

  VkDescriptorSetAllocateInfo dsai = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO, NULL, vk.dpool, 1, &vk.dsl};
  if (vk.vkAllocateDescriptorSets(vk.dev, &dsai, &s->set)) return 0;
  VkDescriptorImageInfo dii = {VK_NULL_HANDLE, s->view, VK_IMAGE_LAYOUT_GENERAL};
  VkWriteDescriptorSet w = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, NULL, s->set, 0, 0, 1,
                            VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, &dii, NULL, NULL};
  vk.vkUpdateDescriptorSets(vk.dev, 1, &w, 0, NULL);

  VkCommandBufferAllocateInfo cbai = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, NULL, vk.pool,
                                      VK_COMMAND_BUFFER_LEVEL_PRIMARY, s->count};
  if (vk.vkAllocateCommandBuffers(vk.dev, &cbai, s->cmd)) return 0;

  VkImageCopy region = {{VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, s->layers}, {0, 0, 0},
                        {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, s->layers}, {0, 0, 0}, {s->width, s->height, 1}};
  const VkImageLayout app = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL; /* layout the spec requires at release */
  const VkPipelineStageFlags all = VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, xfer = VK_PIPELINE_STAGE_TRANSFER_BIT,
                             cs = VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT;

  for (uint32_t i = 0; i < s->count; i++) {
    VkFenceCreateInfo fci = {VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, NULL, VK_FENCE_CREATE_SIGNALED_BIT};
    if (vk.vkCreateFence(vk.dev, &fci, NULL, &s->fence[i])) return 0;

    VkCommandBuffer cb = s->cmd[i];
    VkImage img = s->images[i];
    VkCommandBufferBeginInfo bi = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, NULL, 0, NULL};
    vk.vkBeginCommandBuffer(cb, &bi);
    barrier(cb, img, s->layers, app, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, VK_ACCESS_MEMORY_WRITE_BIT,
            VK_ACCESS_TRANSFER_READ_BIT, all, xfer);
    barrier(cb, s->scratch, s->layers, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 0,
            VK_ACCESS_TRANSFER_WRITE_BIT, all, xfer);
    vk.vkCmdCopyImage(cb, img, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, s->scratch,
                      VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
    barrier(cb, s->scratch, s->layers, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_GENERAL,
            VK_ACCESS_TRANSFER_WRITE_BIT, VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT, xfer, cs);
    vk.vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, vk.pipeline);
    vk.vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, vk.layout, 0, 1, &s->set, 0, NULL);
    vk.vkCmdDispatch(cb, (s->width + 7) / 8, (s->height + 7) / 8, s->layers);
    barrier(cb, s->scratch, s->layers, VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_TRANSFER_READ_BIT, cs, xfer);
    barrier(cb, img, s->layers, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            VK_ACCESS_TRANSFER_READ_BIT, VK_ACCESS_TRANSFER_WRITE_BIT, xfer, xfer);
    vk.vkCmdCopyImage(cb, s->scratch, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, img,
                      VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
    barrier(cb, img, s->layers, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, app, VK_ACCESS_TRANSFER_WRITE_BIT,
            VK_ACCESS_MEMORY_READ_BIT | VK_ACCESS_MEMORY_WRITE_BIT, xfer, all);
    if (vk.vkEndCommandBuffer(cb)) return 0;
  }
  LOG("swapchain %ux%u x%u layers, %u images: decoding on release\n", s->width, s->height, s->layers, s->count);
  return 1;
}

static void teardown_swapchain(struct swapchain *s) {
  if (s->ready) {
    for (uint32_t i = 0; i < s->count; i++) {
      vk.vkWaitForFences(vk.dev, 1, &s->fence[i], VK_TRUE, UINT64_MAX);
      vk.vkDestroyFence(vk.dev, s->fence[i], NULL);
    }
    vk.vkFreeCommandBuffers(vk.dev, vk.pool, s->count, s->cmd);
    vk.vkFreeDescriptorSets(vk.dev, vk.dpool, 1, &s->set);
    vk.vkDestroyImageView(vk.dev, s->view, NULL);
    vk.vkDestroyImage(vk.dev, s->scratch, NULL);
    vk.vkFreeMemory(vk.dev, s->memory, NULL);
  }
  memset(s, 0, sizeof(*s));
}

/* ---- OpenXR hooks ------------------------------------------------------ */

static XrResult XRAPI_CALL create_session(XrInstance inst, const XrSessionCreateInfo *ci, XrSession *session) {
  const XrBaseInStructure *n = ci->next;
  while (n && n->type != XR_TYPE_GRAPHICS_BINDING_VULKAN_KHR) n = n->next;
  XrResult r = next_create_session(inst, ci, session);
  if (r == XR_SUCCESS && n && !vk.ok) {
    vk.ok = setup_vulkan((const XrGraphicsBindingVulkanKHR *)n);
    LOG("vulkan session %s\n", vk.ok ? "ready" : "setup FAILED, passing through");
  }
  return r;
}

static XrResult XRAPI_CALL create_swapchain(XrSession session, const XrSwapchainCreateInfo *ci, XrSwapchain *out) {
  int fix = vk.ok && is_srgb8(ci->format) && (ci->usageFlags & XR_SWAPCHAIN_USAGE_COLOR_ATTACHMENT_BIT) &&
            ci->sampleCount == 1 && ci->faceCount == 1;
  XrSwapchainCreateInfo mine = *ci;
  if (fix) mine.usageFlags |= XR_SWAPCHAIN_USAGE_TRANSFER_SRC_BIT | XR_SWAPCHAIN_USAGE_TRANSFER_DST_BIT;
  XrResult r = next_create_swapchain(session, &mine, out);
  if (r != XR_SUCCESS || !fix) return r;
  pthread_mutex_lock(&lock);
  for (int i = 0; i < MAX_SWAPCHAINS; i++)
    if (!swapchains[i].used) {
      swapchains[i] = (struct swapchain){.handle = *out, .used = 1, .width = ci->width, .height = ci->height,
                                         .layers = ci->arraySize ? ci->arraySize : 1};
      break;
    }
  pthread_mutex_unlock(&lock);
  return r;
}

static XrResult XRAPI_CALL destroy_swapchain(XrSwapchain h) {
  pthread_mutex_lock(&lock);
  struct swapchain *s = find(h);
  if (s) teardown_swapchain(s);
  pthread_mutex_unlock(&lock);
  return next_destroy_swapchain(h);
}

static XrResult XRAPI_CALL enumerate_images(XrSwapchain h, uint32_t cap, uint32_t *count, XrSwapchainImageBaseHeader *imgs) {
  XrResult r = next_enumerate_images(h, cap, count, imgs);
  if (r != XR_SUCCESS || !cap || !imgs || imgs->type != XR_TYPE_SWAPCHAIN_IMAGE_VULKAN_KHR) return r;
  pthread_mutex_lock(&lock);
  struct swapchain *s = find(h);
  if (s && !s->ready && !s->broken) {
    s->count = *count;
    if (s->count > MAX_IMAGES) {
      s->broken = 1;
    } else {
      for (uint32_t i = 0; i < s->count; i++) s->images[i] = ((XrSwapchainImageVulkanKHR *)imgs)[i].image;
      s->ready = setup_swapchain(s);
      if (!s->ready) { LOG("swapchain setup FAILED, passing through\n"); s->broken = 1; }
    }
  }
  pthread_mutex_unlock(&lock);
  return r;
}

static XrResult XRAPI_CALL acquire(XrSwapchain h, const XrSwapchainImageAcquireInfo *ai, uint32_t *index) {
  XrResult r = next_acquire(h, ai, index);
  if (r != XR_SUCCESS) return r;
  pthread_mutex_lock(&lock);
  struct swapchain *s = find(h);
  if (s && s->ready) s->acquired[s->tail++ % MAX_IMAGES] = *index;
  pthread_mutex_unlock(&lock);
  return r;
}

static XrResult XRAPI_CALL release(XrSwapchain h, const XrSwapchainImageReleaseInfo *ri) {
  /* wineopenxr has flushed the game's rendering to this queue and holds the
   * queue lock across this call, so submitting here is ordered and safe. */
  static unsigned long skipped;
  pthread_mutex_lock(&lock);
  struct swapchain *s = find(h);
  if (s && s->ready && s->head != s->tail) {
    uint32_t i = s->acquired[s->head++ % MAX_IMAGES];
    /* Never block here: the game's queue lock is held, and GPU work ahead of
     * ours can depend on submissions that only happen after we return — an
     * unbounded vkWaitForFences froze War Thunder on its first frames. If this
     * image's previous pass hasn't finished, skip the fix for this frame. */
    if (vk.vkGetFenceStatus(vk.dev, s->fence[i]) == VK_SUCCESS) {
      vk.vkResetFences(vk.dev, 1, &s->fence[i]);
      VkSubmitInfo si = {VK_STRUCTURE_TYPE_SUBMIT_INFO, NULL, 0, NULL, NULL, 1, &s->cmd[i], 0, NULL};
      VkResult r = vk.vkQueueSubmit(vk.queue, 1, &si, s->fence[i]);
      if (r) { LOG("submit failed (%d), disabling\n", r); s->ready = 0; }
    } else if (++skipped & (skipped - 1)) {
      /* log on powers of two only */
    } else {
      LOG("previous pass still running, skipped %lu frame(s) so far\n", skipped);
    }
  }
  pthread_mutex_unlock(&lock);
  return next_release(h, ri);
}

static XrResult XRAPI_CALL gipa(XrInstance inst, const char *name, PFN_xrVoidFunction *fn) {
#define HOOK(n, f) if (!strcmp(name, n)) { *fn = (PFN_xrVoidFunction)f; return XR_SUCCESS; }
  HOOK("xrCreateSession", create_session)
  HOOK("xrCreateSwapchain", create_swapchain)
  HOOK("xrDestroySwapchain", destroy_swapchain)
  HOOK("xrEnumerateSwapchainImages", enumerate_images)
  HOOK("xrAcquireSwapchainImage", acquire)
  HOOK("xrReleaseSwapchainImage", release)
#undef HOOK
  return next_gipa(inst, name, fn);
}

static XrResult XRAPI_CALL create_instance(const XrInstanceCreateInfo *info, const XrApiLayerCreateInfo *li,
                                           XrInstance *inst) {
  XrApiLayerCreateInfo mine = *li;
  next_gipa = li->nextInfo->nextGetInstanceProcAddr;
  mine.nextInfo = li->nextInfo->next;
  XrResult r = li->nextInfo->nextCreateApiLayerInstance(info, &mine, inst);
  if (r != XR_SUCCESS) return r;
#define NEXT(n, v) next_gipa(*inst, n, (PFN_xrVoidFunction *)&v)
  NEXT("xrCreateSession", next_create_session);
  NEXT("xrCreateSwapchain", next_create_swapchain);
  NEXT("xrDestroySwapchain", next_destroy_swapchain);
  NEXT("xrEnumerateSwapchainImages", next_enumerate_images);
  NEXT("xrAcquireSwapchainImage", next_acquire);
  NEXT("xrReleaseSwapchainImage", next_release);
#undef NEXT
  LOG("loaded for '%s'\n", info->applicationInfo.applicationName);
  return r;
}

__attribute__((visibility("default"))) XrResult XRAPI_CALL
xrNegotiateLoaderApiLayerInterface(const XrNegotiateLoaderInfo *li, const char *name, XrNegotiateApiLayerRequest *req) {
  (void)name;
  req->layerInterfaceVersion = XR_CURRENT_LOADER_API_LAYER_VERSION;
  req->layerApiVersion = li->maxApiVersion;
  req->getInstanceProcAddr = gipa;
  req->createApiLayerInstance = create_instance;
  return XR_SUCCESS;
}
