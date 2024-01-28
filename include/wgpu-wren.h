#include <wren.h>

#include "file.h"
#include "string.h"

typedef struct WrenApp;

typedef struct WrenAppConfig {
  WrenConfiguration* vm;
  String name;
  String entry;
} WrenAppConfig;
