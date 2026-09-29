#ifndef AE3D_H
#define AE3D_H

/* The mesh and instance stores are ae3d.geometry's; the renderers read them
   through native/gpu/stores.h. These two read any field of one the way the
   renderers do, for the test that holds the two layouts together. */
int    ae3d_store_size(int which);
double ae3d_store_field(void *store, int which, int field);

/* An OpenGL entry point by name, from the process or the window system:
   what ae3d.glapi resolves every GL call it makes through (#398). */
void  *ae3d_gl_proc(const char *name);

/* The offscreen OpenGL context (native/gpu/offscreen.c): made at a size,
   current on the calling thread, and destroyed. */
void  *ae3d_offscreen_context(int width, int height);
void   ae3d_offscreen_context_destroy(void *context);

/* A parallel for over the engine's job pool (native/gpu/jobs.c): the range
   [0, count) in blocks of at least `grain` elements, done when it returns.
   The pool is ae3d.jobs; the engine installs the runner that reaches it,
   and without one the calling thread does the range alone. */
typedef void (*ae3d_job_fn)(void *ctx, int start, int end);
typedef void (*ae3d_jobs_runner_fn)(int count, int grain, ae3d_job_fn fn, void *ctx);
void ae3d_jobs_set_runner(ae3d_jobs_runner_fn runner);
void ae3d_job_call(ae3d_job_fn fn, void *ctx, int start, int end);
void ae3d_jobs_for(int count, int grain, ae3d_job_fn fn, void *ctx);

#endif
