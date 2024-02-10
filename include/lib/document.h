#pragma once

#include "string.h"
#include "maybe.h"

typedef struct Document {
  String file;
  String contents;
  size_t lineLength;
} Document;

typedef struct Position {
  int line;
  int column;
} Position;

typedef struct Span {
  String file;
  Position start;
  Position end;
} Span;

Span NoPos = { NilString, { 0, 0 }, { 0, 0 } };
Maybe(Span);

Position posToPosition(Document* document, int pos) {
  Position position;

  int line = 0;
  int col = 0;
  for (int i = 0; i <= pos; i += 1) {
    if (document->contents.cString[i] == '\n') {
      line++;
      col = 0;
    }
    else col += 1;
  }
  position.line = line;
  position.column = col;

  return position;
}

Span posToSpan(Document* document, int startPos, int endPos) {
  Position start = posToPosition(document, startPos);
  Position end = posToPosition(document, endPos);
  return (Span) { document->file, start, end };
}
