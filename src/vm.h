#pragma once

#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <wren.h>

static void writeFn(WrenVM* vm, const char* text) {
  printf("%s", text);
}

void errorFn(WrenVM* vm, WrenErrorType errorType,
             const char* module, const int line,
             const char* msg) {
  switch (errorType) {
    case WREN_ERROR_COMPILE: {
      printf("[%s line %d] [Error] %s\n", module, line, msg);
    } break;
    case WREN_ERROR_STACK_TRACE: {
      printf("[%s line %d] in %s\n", module, line, msg);
    } break;
    case WREN_ERROR_RUNTIME: {
      printf("[Runtime Error] %s\n", msg);
    } break;
  }
}
