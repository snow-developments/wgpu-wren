#pragma once

#include <wren.h>

#include "lib/file.h"

typedef struct WrenApp WrenApp;

typedef struct WrenAppConfig {
  String name;
  String entry;
  WrenConfiguration* vm;
} WrenAppConfig;

WrenApp* wrenAppNew(WrenAppConfig config);
/**
 * @returns Whether the app's event loop should exit.
 * @see `wrenAppRun`
 */
typedef bool (*Callback)(void* userData);
int wrenAppRun(WrenApp* app, Callback callback, void* userData);
