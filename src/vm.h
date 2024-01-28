#pragma once

#include <stdio.h>
#include <wren.h>

static void _defaultWriteFn(WrenVM* vm, const char* text) {
  fprintf(stdout, "%s", text);
}

void _defaultErrorFn(
  WrenVM* vm, WrenErrorType errorType,
  const char* module, const int line, const char* msg
) {
  switch (errorType) {
    case WREN_ERROR_COMPILE: {
      fprintf(stderr, "[%s:%d] Error: %s\n", module, line, msg);
    } break;
    case WREN_ERROR_STACK_TRACE: {
      fprintf(stderr, "[%s:%d] in %s\n", module, line, msg);
    } break;
    case WREN_ERROR_RUNTIME: {
      fprintf(stderr, "Runtime Error: %s\n", msg);
    } break;
  }
}
