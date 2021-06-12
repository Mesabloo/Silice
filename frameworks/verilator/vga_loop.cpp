/*

    Silice FPGA language and compiler
    (c) Sylvain Lefebvre - @sylefeb

This work and all associated files are under the

     GNU AFFERO GENERAL PUBLIC LICENSE
        Version 3, 19 November 2007
        
A copy of the license full text is included in 
the distribution, please refer to it for details.

(header_1_0)
*/
// SL 2019-09-23

#include "VgaChip.h"

#include <mutex>
#include <thread>

#include <GL/gl.h>
#include <GL/glut.h>

// external definitions

extern VgaChip *g_VgaChip;
void step();

GLuint     g_FBtexture = 0; // OpenGL texture
std::mutex g_Mutex;         // Mutex to lock VgaChip during rendering

void simul()
{
  while (1) {
    std::lock_guard<std::mutex> lock(g_Mutex);
    step(); 
  }
}

void render()
{  
  std::lock_guard<std::mutex> lock(g_Mutex);

  if (g_VgaChip->framebufferChanged()) {

    // refresh frame
    glTexSubImage2D( GL_TEXTURE_2D,0,0,0, 640,480, GL_RGBA,GL_UNSIGNED_BYTE, 
                  g_VgaChip->framebuffer().pixels().raw());
    glBegin(GL_QUADS);
    glTexCoord2f(0.0f, 0.0f); glVertex2f(0.0f, 0.0f);
    glTexCoord2f(1.0f, 0.0f); glVertex2f(1.0f, 0.0f);
    glTexCoord2f(1.0f, 1.0f); glVertex2f(1.0f, 1.0f);
    glTexCoord2f(0.0f, 1.0f); glVertex2f(0.0f, 1.0f);
    glEnd();
    
    glutSwapBuffers();
  }

  glutPostRedisplay();
}

void vga_loop()
{
  // glut window
  int   argc=0;
  char *argv[1] = {NULL};
  glutInit(&argc, argv);
  glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE);
  glutInitWindowSize(640, 480);
  glutCreateWindow("Silice verilator framework");
  glutDisplayFunc(render);
  // prepare texture
  glGenTextures(1,&g_FBtexture);
  glBindTexture(GL_TEXTURE_2D,g_FBtexture);
  glTexImage2D( GL_TEXTURE_2D,0, GL_RGBA, 640,480,0, GL_RGBA,GL_UNSIGNED_BYTE, 
                NULL);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
  // setup rendering
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_LIGHTING);
  glDisable(GL_CULL_FACE);
  glEnable(GL_TEXTURE_2D);
  glColor3f(1.0f,1.0f,1.0f);
  // setup view
  glViewport(0,0,640,480);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glOrtho(0.0f, 1.0f, 1.0f, 0.0f, -1.0f, 1.0f);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();

  std::thread th(simul);

  // enter main loop
  glutMainLoop();
}

