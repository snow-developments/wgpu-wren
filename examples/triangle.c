#include <stdarg.h>
#include <stdio.h>

#include "../include/wgpu-wren.h"

int main(int argc, char *argv[]) {
  WrenAppConfig config = {.name = toString("Triangle"),
                          .entry = toString("triangle.wren"),
                          .width = 640,
                          .height = 480};
  return wrenAppRun(wrenAppNew(config), NULL, NULL);
}
