#include <wren.h>

#include "lib/file.h"
#include "lib/string.h"

typedef struct WrenApp;

typedef struct WrenAppConfig {
  WrenConfiguration* vm;
  String name;
  String entry;
} WrenAppConfig;
