#include <stdarg.h>

#include <GLFW/glfw3.h>
#include <wgpu-wren.h>

bool render();

int main() {
  String name = toString("Triangle");
  WrenAppConfig config = { .name=name, .entry=toString("triangle.wren") };
  WrenApp* app = wrenAppNew(config);

  GLFWwindow* window;
  if (!glfwInit()) return -1;

  glfwWindowHint(GLFW_VISIBLE, false);
  glfwWindowHint(GLFW_FOCUS_ON_SHOW, true);
  window = glfwCreateWindow(640, 480, name.cString, NULL, NULL);
  if (!window) {
    glfwTerminate();
    return -1;
  }
  glfwMakeContextCurrent(window);

  int result = wrenAppRun(app, &render, window);
  glfwTerminate();
  return result;
}

bool render(GLFWwindow* window) {
  if (glfwWindowShouldClose(window)) return true;
  if (glfwGetWindowAttrib(window, GLFW_VISIBLE) == false) glfwShowWindow(window);

  glClear(GL_COLOR_BUFFER_BIT);
  glfwSwapBuffers(window);
  glfwPollEvents();

  return false;
}
