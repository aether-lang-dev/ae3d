/* The program's console, kept for the agent channel (#510, log.tail and
 * log.since): every line written to stdout and stderr, with the frame it was
 * written in and, for a script's, the object whose phase wrote it.
 *
 * Every print in an Aether program goes through the C runtime's stdout and
 * stderr (println is a write to stdout), and a library cannot hook a write it
 * does not make. So the streams' file descriptors are pointed at pipes, and a
 * thread a stream reads its pipe, writes what it reads through to where the
 * stream went before (the terminal, a log), and keeps each line in a ring.
 *
 * Which frame a line belongs to is said in the stream itself: at a frame's
 * end the engine flushes both streams and writes a marker into each pipe
 * (ae3d_console_frame), so every line the frame printed is before its marker
 * and every later one after it. A line printed by another thread is the
 * frame's its bytes reached the pipe in. Which object wrote a line is said
 * the same way: the behaviours mark a script's phase as it begins and ends
 * (ae3d_console_object), into stdout's own buffer -- no call to the system
 * for it -- so a print between the marks is that object's. A marker is a
 * line that starts with ASCII 30, which no text starts with; the readers
 * take them out and pass none through.
 *
 * stdout is fully buffered while captured, and flushed each frame: what the
 * terminal shows arrives a frame at a time. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#  include <io.h>
#  include <fcntl.h>
#  include <process.h>
#  include <windows.h>
#  define ae3d_pipe(fds) _pipe((fds), 65536, _O_BINARY)
#  define ae3d_dup _dup
#  define ae3d_dup2 _dup2
#  define ae3d_read _read
#  define ae3d_write _write
#  define ae3d_close _close
typedef CRITICAL_SECTION ae3d_lock_t;
#  define ae3d_lock_init(l) InitializeCriticalSection(l)
#  define ae3d_lock(l) EnterCriticalSection(l)
#  define ae3d_unlock(l) LeaveCriticalSection(l)
#else
#  include <pthread.h>
#  include <unistd.h>
#  define ae3d_pipe(fds) pipe(fds)
#  define ae3d_dup dup
#  define ae3d_dup2 dup2
#  define ae3d_read read
#  define ae3d_write write
#  define ae3d_close close
typedef pthread_mutex_t ae3d_lock_t;
#  define ae3d_lock_init(l) pthread_mutex_init((l), NULL)
#  define ae3d_lock(l) pthread_mutex_lock(l)
#  define ae3d_unlock(l) pthread_mutex_unlock(l)
#endif

#define AE3D_CONSOLE_LINE 1024          /* a line's text kept, at most (longer ones are cut, and say so) */
#define AE3D_CONSOLE_MARK 30            /* ASCII record separator: a marker line's first byte */

typedef struct {
    long long seq;                      /* 1, 2, ... in the order kept */
    int frame;
    int stream;                         /* 1 stdout, 2 stderr */
    int object;                         /* the object whose script printed it, -1 for none */
    char text[AE3D_CONSOLE_LINE];
} ae3d_line;

typedef struct {
    int fd;                             /* the pipe's read end */
    int through;                        /* where the stream went before */
    int stream;
    int frame;                          /* the frame its next line is in */
    int object;
    char pending[AE3D_CONSOLE_LINE];    /* a line not yet ended */
    int pending_length;
    int cut;                            /* the pending line ran past AE3D_CONSOLE_LINE */
    int in_line;                        /* a line has begun and not ended */
    int in_marker;                      /* and it is a marker */
    int target;                         /* the descriptor captured: 1 or 2 */
#if defined(_WIN32)
    HANDLE thread;
#else
    pthread_t thread;
#endif
} ae3d_reader;

static ae3d_lock_t g_lock;
static ae3d_line *g_ring = NULL;
static int g_capacity = 0;
static long long g_next = 1;           /* the seq the next line kept takes */
static int g_started = 0;
static ae3d_reader g_readers[2];

static void keep(ae3d_reader *r) {
    ae3d_lock(&g_lock);
    ae3d_line *line = &g_ring[(g_next - 1) % g_capacity];
    line->seq = g_next;
    line->frame = r->frame;
    line->stream = r->stream;
    line->object = r->object;
    int n = r->pending_length;
    if (r->cut && n > AE3D_CONSOLE_LINE - 4) n = AE3D_CONSOLE_LINE - 4;
    memcpy(line->text, r->pending, (size_t)n);
    if (r->cut) { memcpy(line->text + n, "...", 3); n += 3; }
    line->text[n] = 0;
    g_next++;
    ae3d_unlock(&g_lock);
}

/* A marker line: "f<frame>" ends a frame, "o<id>" begins an object's phase
   and "o-" ends it. */
static void marker(ae3d_reader *r, const char *text, int length) {
    if (length < 2) return;
    char digits[32];
    int n = length - 1;
    if (n > 31) n = 31;
    memcpy(digits, text + 1, (size_t)n);
    digits[n] = 0;
    if (text[0] == 'f') {
        r->frame = atoi(digits) + 1;
        r->object = -1;
    } else if (text[0] == 'o') {
        r->object = digits[0] == '-' ? -1 : atoi(digits);
    }
}

/* Through to where the stream went before, every byte but the markers. */
static void pass(ae3d_reader *r, const char *bytes, int length) {
    int done = 0;
    while (done < length) {
        int wrote = (int)ae3d_write(r->through, bytes + done, (unsigned)(length - done));
        if (wrote <= 0) return;
        done += wrote;
    }
}

/* The bytes a read gave, line by line. A line is a marker when its first
   byte is AE3D_CONSOLE_MARK, wherever the reads split it: known from its
   first byte on, held back from the terminal, and read when it ends. */
static void take(ae3d_reader *r, const char *bytes, int length) {
    int start = 0;
    for (int i = 0; i <= length; i++) {
        int ends = i < length && bytes[i] == '\n';
        if (i < length && !ends) continue;
        int piece = i - start;
        if (piece > 0 || ends) {
            if (r->pending_length == 0 && !r->in_line && piece > 0) {
                r->in_marker = (unsigned char)bytes[start] == AE3D_CONSOLE_MARK;
                r->in_line = 1;
            }
            if (!r->in_marker) pass(r, bytes + start, piece + (ends ? 1 : 0));
            int room = AE3D_CONSOLE_LINE - 1 - r->pending_length;
            int copy = piece < room ? piece : room;
            if (piece > room) r->cut = 1;
            memcpy(r->pending + r->pending_length, bytes + start, (size_t)copy);
            r->pending_length += copy;
        }
        if (ends) {
            if (r->in_marker) {
                marker(r, r->pending + 1, r->pending_length - 1);
            } else {
                /* A Windows line's carriage return is not its text. */
                if (r->pending_length > 0 && r->pending[r->pending_length - 1] == '\r') r->pending_length--;
                keep(r);
            }
            r->pending_length = 0;
            r->cut = 0;
            r->in_marker = 0;
            r->in_line = 0;
        }
        start = i + 1;
    }
}

#if defined(_WIN32)
static unsigned __stdcall run_reader(void *arg) {
#else
static void *run_reader(void *arg) {
#endif
    ae3d_reader *r = (ae3d_reader *)arg;
    char bytes[4096];
    for (;;) {
        int n = (int)ae3d_read(r->fd, bytes, sizeof bytes);
        if (n <= 0) break;
        take(r, bytes, n);
    }
    return 0;
}

static int capture(ae3d_reader *r, FILE *file, int fd, int stream) {
    int fds[2];
    fflush(file);
    r->through = ae3d_dup(fd);
    if (r->through < 0) return 0;
    if (ae3d_pipe(fds) != 0) return 0;
    if (ae3d_dup2(fds[1], fd) < 0) return 0;
    ae3d_close(fds[1]);
    r->fd = fds[0];
    r->stream = stream;
    r->frame = 0;
    r->object = -1;
    r->pending_length = 0;
    r->cut = 0;
    r->in_line = 0;
    r->in_marker = 0;
    r->target = fd;
#if defined(_WIN32)
    uintptr_t thread = _beginthreadex(NULL, 0, run_reader, r, 0, NULL);
    if (thread == 0) return 0;
    r->thread = (HANDLE)thread;
#else
    if (pthread_create(&r->thread, NULL, run_reader, r) != 0) return 0;
#endif
    return 1;
}

/* The stream back where it went, and everything its pipe still holds
   through to there first: the descriptor pointed back (which closes the
   pipe's last write end), the reader drained to the end and joined. */
static void release(ae3d_reader *r, FILE *file) {
    fflush(file);
    ae3d_dup2(r->through, r->target);
#if defined(_WIN32)
    WaitForSingleObject(r->thread, INFINITE);
    CloseHandle(r->thread);
#else
    pthread_join(r->thread, NULL);
#endif
    ae3d_close(r->fd);
    ae3d_close(r->through);
}

/* The streams as they were, nothing they were given lost: at exit (a
   program's last lines -- a test's verdict -- are written after its engine
   is gone) and wherever a program asks. */
void ae3d_console_stop(void) {
    if (!g_started) return;
    g_started = 0;
    release(&g_readers[0], stdout);
    release(&g_readers[1], stderr);
}

/* Capture both streams, the last `capacity` lines kept. 1 when capturing
   (already, or now). */
int ae3d_console_start(int capacity) {
    if (g_started) return 1;
    if (capacity < 16) capacity = 16;
    g_ring = (ae3d_line *)calloc((size_t)capacity, sizeof(ae3d_line));
    if (g_ring == NULL) return 0;
    g_capacity = capacity;
    ae3d_lock_init(&g_lock);
    /* Fully buffered: the object marks are buffered writes, and the frame's
       flush sends the frame's text and its mark together. */
    setvbuf(stdout, NULL, _IOFBF, 1 << 16);
    if (!capture(&g_readers[0], stdout, 1, 1)) return 0;
    if (!capture(&g_readers[1], stderr, 2, 2)) return 0;
    g_started = 1;
    atexit(ae3d_console_stop);
    return 1;
}

int ae3d_console_started(void) { return g_started; }

/* The end of frame `frame`: what it printed is before this mark in each
   stream. */
void ae3d_console_frame(int frame) {
    if (!g_started) return;
    fprintf(stdout, "%cf%d\n", AE3D_CONSOLE_MARK, frame);
    fflush(stdout);
    fprintf(stderr, "%cf%d\n", AE3D_CONSOLE_MARK, frame);
    fflush(stderr);
}

/* A script's phase begins for object `id` (or ends, -1): what stdout gets
   until the next mark is that object's. A buffered write, no flush. */
void ae3d_console_object(int id) {
    if (!g_started) return;
    if (id < 0) fprintf(stdout, "%co-\n", AE3D_CONSOLE_MARK);
    else fprintf(stdout, "%co%d\n", AE3D_CONSOLE_MARK, id);
}

#if !defined(_WIN32)
#  include <fcntl.h>
/* A crash, from its signal handler (crash.c): the streams pointed back where
   they went, so the stack trace reaches the terminal and not a pipe whose
   reader dies with the process, and what the pipes still hold -- the
   panic's message, the last lines -- passed through first, its markers left
   out. Only async-signal-safe calls: dup2, fcntl, read, write. */
void ae3d_console_crash(void) {
    if (!g_started) return;
    g_started = 0;
    for (int k = 0; k < 2; k++) {
        ae3d_reader *r = &g_readers[k];
        ae3d_dup2(r->through, r->target);
        int flags = fcntl(r->fd, F_GETFL, 0);
        if (flags >= 0) fcntl(r->fd, F_SETFL, flags | O_NONBLOCK);
        char bytes[4096];
        int at_line_start = r->pending_length == 0;
        for (;;) {
            ssize_t n = read(r->fd, bytes, sizeof bytes);
            if (n <= 0) break;
            /* Line by line, a marker line dropped. */
            int start = 0;
            for (int i = 0; i < (int)n; i++) {
                if (bytes[i] != '\n') continue;
                int marked = at_line_start && (unsigned char)bytes[start] == AE3D_CONSOLE_MARK;
                if (!marked) { ssize_t w = write(r->target, bytes + start, (size_t)(i + 1 - start)); (void)w; }
                start = i + 1;
                at_line_start = 1;
            }
            if (start < (int)n) {
                if (!(at_line_start && (unsigned char)bytes[start] == AE3D_CONSOLE_MARK)) {
                    ssize_t w = write(r->target, bytes + start, (size_t)((int)n - start));
                    (void)w;
                }
                at_line_start = 0;
            }
        }
    }
}
#endif

/* The seq the next line kept will take: lines 1 .. next-1 have been. */
long long ae3d_console_next(void) {
    if (!g_started) return 1;
    ae3d_lock(&g_lock);
    long long n = g_next;
    ae3d_unlock(&g_lock);
    return n;
}

/* The oldest seq still kept. */
long long ae3d_console_oldest(void) {
    if (!g_started) return 1;
    ae3d_lock(&g_lock);
    long long n = g_next - g_capacity;
    if (n < 1) n = 1;
    ae3d_unlock(&g_lock);
    return n;
}

/* Line `seq` into the caller's: its frame, stream and object, and its text
   (at most `room` bytes with the terminator). 0 when it is no longer kept or
   not yet written. */
int ae3d_console_line(long long seq, int *frame, int *stream, int *object, char *text, int room) {
    if (!g_started || room <= 0) return 0;
    ae3d_lock(&g_lock);
    long long oldest = g_next - g_capacity;
    if (oldest < 1) oldest = 1;
    int ok = seq >= oldest && seq < g_next;
    if (ok) {
        ae3d_line *line = &g_ring[(seq - 1) % g_capacity];
        *frame = line->frame;
        *stream = line->stream;
        *object = line->object;
        int n = (int)strlen(line->text);
        if (n > room - 1) n = room - 1;
        memcpy(text, line->text, (size_t)n);
        text[n] = 0;
    }
    ae3d_unlock(&g_lock);
    return ok;
}
