#import <Cocoa/Cocoa.h>
#import <QuartzCore/CAMetalLayer.h>

#define GLFW_EXPOSE_NATIVE_COCOA
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

// MoltenVK draws into a CAMetalLayer, and a GLFW window's content view has none
// until one is attached here. Without this the Metal surface extension has
// nothing to bind and instance creation succeeds while surface creation fails.
// `scaled` 0 draws the layer at the window's points (a hidden window, or
// AE3D_PIXEL_SCALE=1): the frame the engine was asked for, not the
// display's pixels.
void *ae3d_vk_native_layer(void *window, int scaled) {
    NSWindow *nswindow;
    NSView *view;
    CAMetalLayer *layer;

    if (!window) return NULL;
    nswindow = glfwGetCocoaWindow((GLFWwindow *)window);
    if (!nswindow) return NULL;

    view = [nswindow contentView];
    if (!view) return NULL;

    if ([[view layer] isKindOfClass:[CAMetalLayer class]]) {
        return (__bridge void *)[view layer];
    }

    layer = [CAMetalLayer layer];
    [layer setContentsScale:(scaled ? [nswindow backingScaleFactor] : 1.0)];
    [view setLayer:layer];
    [view setWantsLayer:YES];
    return (__bridge void *)layer;
}
