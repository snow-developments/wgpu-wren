/// License: BSD-3-Clause
module peregrine;

import bindbc.glfw;
import std.stdio : stderr;
import wren;
import wgpu.api;

struct WrenAppConfig {
  string name;
  string entry;
  WrenConfiguration* vm;
  int width;
  int height;
}

private struct WrenApp {
  WrenVM* vm;
  WrenAppConfig config;
  GLFWwindow* window;
  Instance instance;
  Surface surface;
  Adapter adapter;
  Device device;

  string getSourceForModule(string name) {
    if (name == "wgpu") return "class Device {
      static name { \"" ~ device.label ~ "\" }
    }";
    return "";
  }
}

extern (C) static void _defaultWriteFn(WrenVM* vm, const char* text) {
  import std.stdio : write;
  import std.conv : to;
  import std.string : fromStringz;

  text.fromStringz.to!string.write;
}

extern (C) static void _defaultErrorFn(
  WrenVM* vm, WrenErrorType errorType,
  const char* module_, int line, const char* msg
) {
  import std.conv : to;
  import std.string : fromStringz;

  final switch (errorType) {
    case WREN_ERROR_COMPILE:
      stderr.writefln("[%s:%d] Error: %s", module_.fromStringz.to!string, line, msg.fromStringz.to!string);
      break;
    case WREN_ERROR_STACK_TRACE:
      stderr.writefln("[%s:%d] in %s", module_.fromStringz.to!string, line, msg.fromStringz.to!string);
      break;
    case WREN_ERROR_RUNTIME:
      stderr.writefln("Runtime Error: %s", msg.fromStringz.to!string);
      break;
  }
}

extern (C) WrenLoadModuleResult _loadModule(WrenVM* vm, const char* name) {
  import std.conv : to;
  import std.string : fromStringz, toStringz;

  auto app = cast(WrenApp*) wrenGetUserData(vm);
  auto result = WrenLoadModuleResult();
  result.source = app.getSourceForModule(name.fromStringz.to!string).toStringz;
  return result;
}

// See https://github.com/gfx-rs/wgpu-native/tree/v0.19.1.1
extern (C) WrenApp* wrenAppNew(WrenAppConfig config) {
  if (config.vm == null) {
    WrenConfiguration wrenConfig;
    wrenInitConfiguration(&wrenConfig);
    config.vm = &wrenConfig;
    config.vm.writeFn = &_defaultWriteFn;
    config.vm.errorFn = &_defaultErrorFn;
    config.vm.loadModuleFn = &_loadModule;
  }

  auto app = new WrenApp(wrenNewVM(config.vm), config);
  wrenSetUserData(app.vm, cast(void*) app);
  app.instance = Instance.create();

  // TODO: Check for Wayland support
  version (Wayland) glfwInitHint(GLFW_PLATFORM, GLFW_PLATFORM_WAYLAND);
  assert(glfwInit());

  glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
  glfwWindowHint(GLFW_VISIBLE, false);
  glfwWindowHint(GLFW_FOCUS_ON_SHOW, true);
  auto window = app.window = glfwCreateWindow(
      config.width, config.height, config.name.ptr, null, null);
  if (!window) {
    stderr.writeln("Could not create window.");
    glfwTerminate();
    return null;
  }

  glfwSetWindowUserPointer(window, app);
  glfwSetKeyCallback(window, &key);
  glfwSetFramebufferSizeCallback(window, &fb_resize);

  // Create WebGPU surface buffer
  Surface surface;
  version (OSX) {
    import std.exception : enforce;

    auto nativeWindow = NSWindow.from(enforce(glfwGetCocoaWindow(window), "Could not get Cocoa window!"));
    auto metalLayer = CAMetalLayer.classOf.layer;
    nativeWindow.contentView.wantsLayer = true;
    nativeWindow.contentView.layer = metalLayer;
    surface = Surface.fromMetalLayer(app.instance, metalLayer.asId);
  }
  else static assert(0, "Unsupported WebGPU target!");

  app.adapter = app.instance.requestAdapter(app.surface = surface);
  assert(app.adapter.ready);
  app.device = app.adapter.requestDevice(app.adapter.limits);
  assert(app.device.ready);

  return app;
}

extern (C) GLFWwindow* wrenAppGetWindow(WrenApp* app) { return app.window; }

alias Callback = extern (C) bool function(void *userData);
extern (C) void wrenAppRun(WrenApp* app, Callback callback, void* userData) {
  import std.file : readText;
  import std.string : format;

  auto running = true;
  assert(app.config.entry != null);
  WrenVM* vm = app.vm;

  const entry = app.config.entry;
  auto script = readText(entry);
  assert(script.length, "%s: Could not read application entry".format(entry));

  // Init script VM
  auto result = wrenInterpret(vm, entry.ptr, script.ptr);
  if (result != WREN_RESULT_SUCCESS) running = false;
  wrenEnsureSlots(vm, 1);
  assert(wrenHasVariable(vm, entry.ptr, "render".ptr), "Entry scripts must contain a render() function!");
  wrenGetVariable(vm, entry.ptr, "render".ptr, 0);
  assert(wrenGetSlotType(vm, 0) == WREN_TYPE_UNKNOWN);
  auto render = wrenGetSlotHandle(vm, 0);

  GLFWwindow* window = app.window;
  while (running && !glfwWindowShouldClose(window)) {
    if (glfwGetWindowAttrib(window, GLFW_VISIBLE) == false)
      glfwShowWindow(window);
    glfwPollEvents();

    wrenCall(vm, render);

    if (running && callback != null)
      running = running && !callback(userData);
  }

  glfwTerminate();
  wrenFreeVM(vm);
}

extern (C) nothrow static void key(GLFWwindow* window, int key, int scanCode, int action, int modifiers) {
  import std.stdio : writefln;

  assert(scanCode >= 0);
  assert(action >= 0);
  debug writefln("Key: %d, action = %d, mod = %d", key, action, modifiers);
}

extern (C) nothrow static void fb_resize(GLFWwindow* window, int width, int height) {
  assert(width);
  assert(height);
}

// mac OS interop with the Objective-C Runtime
version (OSX) {
  import core.attribute : selector;

  alias id = void*;

  alias CGDirectDisplayID = uint;
  mixin(bindGLFW_Cocoa);

  // Objective-C Runtime
  // https://developer.apple.com/documentation/objectivec/1418952-objc_getclass?language=objc
  extern (C) id objc_getClass(const(char)* name);

  /// Detect whether `T` is the `NSObject` interface.
  enum bool isNSObject(T) = __traits(isSame, T, NSObject);

  /// Converts an instance of `NSObject` to an `id`.
  id asId(NSObject obj) @trusted {
    return cast(id) obj;
  }

  extern (Objective-C):

  interface NSObject {
    import std.meta : anySatisfy;
    import std.traits : InterfacesTuple;

    extern (D) static T classOf(T)() @trusted if (anySatisfy!(isNSObject, InterfacesTuple!T)) {
      enum name = __traits(identifier, T);
      auto cls = cast(T) objc_getClass(name);
      assert(cls, "Failed to lookup Obj-C class: " ~ name);
      return cls;
    }

    extern (D) static T from(T)(id obj) @trusted if (anySatisfy!(isNSObject, InterfacesTuple!T)) {
      assert(obj !is null);
      return cast(T) obj;
    }
  }

  // https://developer.apple.com/documentation/quartzcore/calayer?language=objc
  interface CALayer : NSObject {}
  // https://developer.apple.com/documentation/quartzcore/cametallayer?language=objc
  interface CAMetalLayer : CALayer {
    CAMetalLayer layer() @selector("layer");

    extern (D) final static CAMetalLayer classOf() @trusted {
      return NSObject.classOf!CAMetalLayer;
    }
  }

  // https://developer.apple.com/documentation/appkit/nsview?language=objc
  interface NSView : NSObject {
    void wantsLayer(bool wantsLayer) @selector("setWantsLayer:");
    CALayer layer() @selector("layer");
    void layer(CALayer layer) @selector("setLayer:");
  }

  // https://developer.apple.com/documentation/appkit/nswindow?language=objc
  interface NSWindow : NSObject {
    // https://developer.apple.com/documentation/appkit/nswindow/1419160-contentview?language=objc
    NSView contentView() @selector("contentView");

    extern (D) final static NSWindow from(id obj) {
      return NSObject.from!NSWindow(obj);
    }
  }
}
