#include <stdio.h>

#include <wgpu-wren.h>

String toString(const char* string) {
  String result = NilString;
  if (string == NULL) return result;
  else return (String) { strlen(string), string };
}

String intToString(const int integer) {
  int length = snprintf(NULL, 0, "%d", integer);
  char* result = calloc(length, sizeof(char*));
  sprintf(result, "%d", integer);
  return (String) { length, result };
}

String joinStrings(const char* separator, size_t argsLength, ...) {
  assert(argsLength > 0);
  assert(separator != NULL);

  size_t separatorLength = strlen(separator);

  va_list args;
  va_start(args, argsLength);

  char* result = NULL;
  for (size_t i = 0; i < argsLength; i++) {
    char* current = va_arg(args, char*);
    assert(current != NULL);

    char* preceding = result;
    result = calloc((strlen(result) + separatorLength + strlen(current)), sizeof(char*));
    strcat(result, preceding);
    strcat(result, separator);
    strcat(result, current);

    if (preceding != NULL) free(preceding);
  }

  va_end(args);
  return toString(result);
}
