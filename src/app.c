#include <wgpu.h>
#include <wgpu-wren.h>

#include "vm.h"

struct WrenApp {
  WrenVM* vm;
  WrenAppConfig config;
};

// See https://github.com/gfx-rs/wgpu-native/tree/v0.19.1.1
WrenApp* wrenAppNew(WrenAppConfig config) {
  if (config.vm == NULL) {
    WrenConfiguration wrenConfig;
    wrenInitConfiguration(&wrenConfig);
    config.vm = &wrenConfig;
    config.vm->writeFn = &_defaultWriteFn;
    config.vm->errorFn = &_defaultErrorFn;
  }

  WrenApp* app = malloc(sizeof(WrenApp));
  app->vm = wrenNewVM(config.vm);
  app->config = config;
  return app;
}

int wrenAppRun(WrenApp* app, Callback callback, void* userData) {
  assert(app->config.entry.cString != NULL);
  WrenVM* vm = app->vm;

  const char* module = "main";
  const char* entry = app->config.entry.cString;
  MaybeOf(String) script = readFile(entry);

  if (isNothing(script)) {
    fprintf(stderr, "%s: Could not read application entry\n", entry);
    return EXIT_FAILURE;
  }

  bool running = true;
  while (running) {
    WrenInterpretResult result = wrenInterpret(vm, module, script.value.cString);
    switch (result) {
      case WREN_RESULT_COMPILE_ERROR: {
        running = false;
        wrenFreeVM(vm);
        return EXIT_FAILURE;
      } break;
      case WREN_RESULT_RUNTIME_ERROR: {
        running = false;
      } break;
      case WREN_RESULT_SUCCESS: { /* TODO: Something special? */ } break;
    }

    if (callback != NULL) running = running && !callback(userData);
  }

  wrenFreeVM(vm);
  return 0;
}
