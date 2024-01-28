#pragma once

#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <wren.h>

static void writeFn(WrenVM* vm, const char* text) {
  fprintf(stdout, "%s", text);
}

void errorFn(WrenVM* vm, WrenErrorType errorType,
             const char* module, const int line,
             const char* msg) {
  switch (errorType) {
    case WREN_ERROR_COMPILE: {
      fprintf(stderr, "[%s line %d] [Error] %s\n", module, line, msg);
    } break;
    case WREN_ERROR_STACK_TRACE: {
      fprintf(stderr, "[%s line %d] in %s\n", module, line, msg);
    } break;
    case WREN_ERROR_RUNTIME: {
      fprintf(stderr, "[Runtime Error] %s\n", msg);
    } break;
  }
}