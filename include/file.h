#include <assert.h>
#include <stdio.h>
// #include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "string.h"
#include "maybe.h"

Maybe(String)

MaybeOf(String) readFile(const char* path) {
  struct stat fileStats;

  if(access(path, F_OK) != 0) {
    fprintf(stderr, "%s: cannot open: No such file or directory", path);
    return nothing(String);
  }
  if(access(path, R_OK) != 0 || stat(path, &fileStats) != 0) {
    fprintf(stderr, "%s: cannot read: Insufficient permissions", path);
    return nothing(String);
  }

  FILE* file = fopen(path, "r");
  if (file == NULL) {
    fprintf(stderr, "%s: cannot open file: Unknown error", path);
    return nothing(String);
  }

  size_t fileSize = fileStats.st_size;
  char* buf = malloc(fileSize);
  size_t read = fread(buf, sizeof(char), fileSize, file);
  assert(read == fileSize);

  if (ferror(file)) {
    fprintf(stderr, "%s: I/O error reading file", path);
    return nothing(String);
  }
  if (fclose(file) != 0) {
    fprintf(stderr, "%s: cannot close '%s'", path, path);
    return nothing(String);
  }

  String contents = toString(buf);
  assert(contents.length == fileSize);

  return just(String, contents);
}
