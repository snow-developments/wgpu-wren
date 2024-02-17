#pragma once

#include <GLFW/glfw3.h>
#include <stddef.h>
#include <string.h>
#include <wren.h>

// TODO: Generate this with dub: https://dlang.org/blog/2021/01/11/a-new-year-a-new-release-of-d
typedef struct WrenApp WrenApp;

typedef struct string {
  size_t length;
  const char *value;
} string;
string toString(const char *value) { return (string){strlen(value), value}; }

typedef struct WrenAppConfig {
  string name;
  string entry;
  WrenConfiguration *vm;
  int width;
  int height;
} WrenAppConfig;

enum WrenAppResult {
  WrenAppResult_success,
  WrenAppResult_badEntry
};

#if __cplusplus
extern "C" {
#endif

WrenApp *wrenAppNew(WrenAppConfig config);
GLFWwindow *wrenAppGetWindow(WrenApp* app);
/**
 * @returns Whether the app's event loop should exit.
 * @see `wrenAppRun`
 */
typedef bool (*Callback)(void *userData);
WrenAppResult wrenAppRun(WrenApp * app, Callback callback, void *userData);

#if __cplusplus
} // Extern C
#endif
