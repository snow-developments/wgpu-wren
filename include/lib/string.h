#pragma once

#include <assert.h>
#include <string.h>

typedef struct String {
  size_t length;
  const char* cString;
} String;

#define NilString { 0, NULL }

String toString(const char* string);
String intToString(const int integer);
String joinStrings(const char* separator, size_t argsLength, ...);
#define concatStrings(argsLength, ...) joinStrings("", argsLength, __VA_ARGS__)
