#pragma once

#include <assert.h>
#include "string.h"
#include "maybe.h"

Maybe(String)

MaybeOf(String) readFile(const char* path);
