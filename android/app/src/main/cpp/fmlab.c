// FMLAB Emulator per Android: motore nativo. Carica un core libretro (.so), lo fa girare su un filo suo, disegna
// con OpenGL ES 3 sulla Surface dell'app (anche i core che disegnano sulla GPU: PSP, N64, 3DS…), suona con AAudio.
// Ritmo legato al suono come su iPhone: niente scatti e niente suono che si accumula.
#include <jni.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include <unistd.h>
#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <android/log.h>
#include <android/native_window_jni.h>
#include <aaudio/AAudio.h>
#include "libretro.h"

#define LOG(...) __android_log_print(ANDROID_LOG_INFO, "FMLAB", __VA_ARGS__)

// ---- core ----------------------------------------------------------------------------------------------------
static struct {
    void *h;
    void (*init)(void); void (*deinit)(void);
    void (*get_sys)(struct retro_system_info *); void (*get_av)(struct retro_system_av_info *);
    void (*set_env)(retro_environment_t); void (*set_video)(retro_video_refresh_t);
    void (*set_audio)(retro_audio_sample_t); void (*set_batch)(retro_audio_sample_batch_t);
    void (*set_poll)(retro_input_poll_t); void (*set_state)(retro_input_state_t);
    void (*set_port)(unsigned, unsigned); void (*reset)(void); void (*run)(void);
    size_t (*ser_size)(void); bool (*ser)(void *, size_t); bool (*unser)(const void *, size_t);
    bool (*load)(const struct retro_game_info *); void (*unload)(void);
    void *(*mem_data)(unsigned); size_t (*mem_size)(unsigned);
} C;

static char G_sistema[1024], G_salvataggi[1024], G_srm[1200];
static char **G_opz; static int G_nopz;                    // chiave, valore, chiave, valore…
static enum retro_pixel_format G_formato = RETRO_PIXEL_FORMAT_0RGB1555;
static struct retro_system_av_info G_av;
static atomic_bool G_varNuove;
static struct retro_hw_render_callback G_hw; static bool G_usaHw;
static atomic_bool G_fboNuovo;

// ---- input ---------------------------------------------------------------------------------------------------
static atomic_uint G_tasti[4];
static atomic_int G_lx[4], G_ly[4];
static atomic_int G_tx, G_ty, G_tocco;

// ---- stato del filo ------------------------------------------------------------------------------------------
static pthread_t G_filo; static atomic_bool G_vivo, G_ferma, G_pausa, G_veloce, G_muto;
static pthread_mutex_t G_lock = PTHREAD_MUTEX_INITIALIZER;
static ANativeWindow *G_finestraNuova; static atomic_bool G_cambioFinestra;
static atomic_int G_filtro = 0, G_effetto = 0, G_forma = 0;   // filtro: 0 nitido 1 liscio; effetto: 0 1 righe 2 lcd; forma 0 originale 1 16:9 2 pieno
static atomic_int G_fps100;
// due schermi (DS = 1, 3DS = 2): l'immagine del core ha sopra e sotto impilati; l'app li separa e li dispone.
// disposizione: 0 automatica (verticale: uno sopra l'altro; orizzontale: affiancati), 1 sopra/sotto, 2 affiancati, 3 grande + piccolo
static atomic_int G_doppio, G_dispDoppio;
static float G_areaTocco[4];   // dove sta lo schermo da toccare, in pixel della finestra (x0, y0, x1, y1)
static float G_toccoU[2];      // parte orizzontale dell'immagine occupata dallo schermo di sotto (3DS: è più stretto)
static atomic_int G_immagini;     // fotogrammi con un'immagine vera (software o GPU)
static char G_azione[1200]; static atomic_int G_daFare;     // 1 salva stato, 2 carica stato
static atomic_int G_esito;

// ---- suono: anello come su iPhone ----------------------------------------------------------------------------
#define ANELLO (1 << 16)
static int16_t G_anello[ANELLO * 2];
static atomic_uint G_scrivi, G_leggi;
static AAudioStream *G_audio;

static size_t suoni(const int16_t *d, size_t n) {
    if (atomic_load(&G_muto)) return n;
    unsigned s = atomic_load(&G_scrivi), l = atomic_load(&G_leggi);
    size_t liberi = ANELLO - 1 - (size_t)(s - l); if (n > liberi) n = liberi;
    for (size_t i = 0; i < n; i++) { unsigned k = (s + (unsigned)i) & (ANELLO - 1); G_anello[k * 2] = d[i * 2]; G_anello[k * 2 + 1] = d[i * 2 + 1]; }
    atomic_store(&G_scrivi, s + (unsigned)n);
    return n;
}
static void suono(int16_t l, int16_t r) { int16_t c[2] = { l, r }; suoni(c, 1); }
static aaudio_data_callback_result_t richiamoAudio(AAudioStream *s, void *u, void *dati, int32_t n) {
    int16_t *o = dati; unsigned l = atomic_load(&G_leggi), w = atomic_load(&G_scrivi);
    for (int32_t i = 0; i < n; i++) {
        if (l != w) { unsigned k = l & (ANELLO - 1); o[i * 2] = G_anello[k * 2]; o[i * 2 + 1] = G_anello[k * 2 + 1]; l++; }
        else { o[i * 2] = o[i * 2 + 1] = 0; }
    }
    atomic_store(&G_leggi, l);
    return AAUDIO_CALLBACK_RESULT_CONTINUE;
}
static atomic_bool G_riapriAudio; static int G_frequenza;
static void erroreAudio(AAudioStream *s, void *u, aaudio_result_t e) { atomic_store(&G_riapriAudio, true); }   // cuffie, Bluetooth…
static void apriAudio(int frequenza) {
    G_frequenza = frequenza;
    AAudioStreamBuilder *b; if (AAudio_createStreamBuilder(&b) != AAUDIO_OK) return;
    AAudioStreamBuilder_setFormat(b, AAUDIO_FORMAT_PCM_I16); AAudioStreamBuilder_setChannelCount(b, 2);
    AAudioStreamBuilder_setSampleRate(b, frequenza); AAudioStreamBuilder_setPerformanceMode(b, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
    AAudioStreamBuilder_setDataCallback(b, richiamoAudio, NULL);
    AAudioStreamBuilder_setErrorCallback(b, erroreAudio, NULL);
    if (AAudioStreamBuilder_openStream(b, &G_audio) == AAUDIO_OK) AAudioStream_requestStart(G_audio); else G_audio = NULL;
    AAudioStreamBuilder_delete(b);
}

// ---- immagine ------------------------------------------------------------------------------------------------
static EGLDisplay G_dpy = EGL_NO_DISPLAY; static EGLContext G_ctx = EGL_NO_CONTEXT; static EGLSurface G_sup = EGL_NO_SURFACE;
static EGLConfig G_cfg; static ANativeWindow *G_finestra;
static GLuint G_tex, G_prog, G_fbo, G_fboTex, G_fboProf; static unsigned G_fboW, G_fboH;
static unsigned G_w, G_h; static bool G_nuova;
static uint16_t *G_conv; static size_t G_convCap;
static GLint U_tex, U_misura, U_effetto, U_righe, U_rgb;

static const char *VS = "#version 300 es\nlayout(location=0) in vec2 p; layout(location=1) in vec2 t; out vec2 v; void main(){ v=t; gl_Position=vec4(p,0.0,1.0); }";
static const char *FS = "#version 300 es\nprecision mediump float; in vec2 v; out vec4 c; uniform sampler2D tex; uniform int effetto; uniform vec2 righe; uniform int rgb;\n"
    "void main(){ vec4 x = texture(tex, v); if (rgb == 1) x = x.bgra; c = vec4(x.rgb, 1.0);\n"
    " if (effetto == 1) { float f = fract(v.y * righe.y); c.rgb *= f > 0.6 ? 0.68 : 1.0; }\n"
    " if (effetto == 2) { float fy = fract(v.y * righe.y), fx = fract(v.x * righe.x); c.rgb *= (fy > 0.82 || fx > 0.82) ? 0.78 : 1.0; } }";

static GLuint shader(GLenum t, const char *s) { GLuint x = glCreateShader(t); glShaderSource(x, 1, &s, NULL); glCompileShader(x); return x; }
static void preparaGL(void) {
    G_prog = glCreateProgram(); glAttachShader(G_prog, shader(GL_VERTEX_SHADER, VS)); glAttachShader(G_prog, shader(GL_FRAGMENT_SHADER, FS)); glLinkProgram(G_prog);
    U_tex = glGetUniformLocation(G_prog, "tex"); U_effetto = glGetUniformLocation(G_prog, "effetto"); U_righe = glGetUniformLocation(G_prog, "righe"); U_rgb = glGetUniformLocation(G_prog, "rgb");
    glGenTextures(1, &G_tex);
}
static bool creaContesto(void) {
    G_dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY); eglInitialize(G_dpy, NULL, NULL);
    const EGLint a[] = { EGL_RENDERABLE_TYPE, 0x40 /*EGL_OPENGL_ES3_BIT*/, EGL_SURFACE_TYPE, EGL_WINDOW_BIT | EGL_PBUFFER_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_DEPTH_SIZE, 24, EGL_STENCIL_SIZE, 8, EGL_NONE };
    EGLint n = 0; if (!eglChooseConfig(G_dpy, a, &G_cfg, 1, &n) || n == 0) return false;
    const EGLint c[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    G_ctx = eglCreateContext(G_dpy, G_cfg, EGL_NO_CONTEXT, c); if (G_ctx == EGL_NO_CONTEXT) return false;
    const EGLint pb[] = { EGL_WIDTH, 16, EGL_HEIGHT, 16, EGL_NONE };
    G_sup = eglCreatePbufferSurface(G_dpy, G_cfg, pb);
    eglMakeCurrent(G_dpy, G_sup, G_sup, G_ctx);
    preparaGL();
    return true;
}
static void cambiaFinestra(void) {
    pthread_mutex_lock(&G_lock); ANativeWindow *w = G_finestraNuova; G_finestraNuova = NULL; atomic_store(&G_cambioFinestra, false); pthread_mutex_unlock(&G_lock);
    eglMakeCurrent(G_dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (G_sup != EGL_NO_SURFACE) eglDestroySurface(G_dpy, G_sup);
    if (G_finestra) ANativeWindow_release(G_finestra);
    G_finestra = w;
    if (w) {
        EGLint formato = 0; eglGetConfigAttrib(G_dpy, G_cfg, EGL_NATIVE_VISUAL_ID, &formato);
        ANativeWindow_setBuffersGeometry(w, 0, 0, formato);
        G_sup = eglCreateWindowSurface(G_dpy, G_cfg, w, NULL);
    }
    else { const EGLint pb[] = { EGL_WIDTH, 16, EGL_HEIGHT, 16, EGL_NONE }; G_sup = eglCreatePbufferSurface(G_dpy, G_cfg, pb); }
    eglMakeCurrent(G_dpy, G_sup, G_sup, G_ctx);
    eglSwapInterval(G_dpy, 0);
}
static void fboPronto(unsigned w, unsigned h) {
    if (G_fbo && w <= G_fboW && h <= G_fboH) return;
    if (G_fbo) { glDeleteFramebuffers(1, &G_fbo); glDeleteTextures(1, &G_fboTex); glDeleteRenderbuffers(1, &G_fboProf); }
    G_fboW = w; G_fboH = h;
    glGenTextures(1, &G_fboTex); glBindTexture(GL_TEXTURE_2D, G_fboTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glGenRenderbuffers(1, &G_fboProf); glBindRenderbuffer(GL_RENDERBUFFER, G_fboProf);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, w, h);
    glGenFramebuffers(1, &G_fbo); glBindFramebuffer(GL_FRAMEBUFFER, G_fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, G_fboTex, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, G_fboProf);
}
static uintptr_t hwFbo(void) { return G_fbo; }
static retro_proc_address_t hwProc(const char *n) { return (retro_proc_address_t)eglGetProcAddress(n); }

static void video(const void *d, unsigned w, unsigned h, size_t pitch) {
    if (!w || !h) return;
    G_w = w; G_h = h; G_nuova = true;
    if (d == RETRO_HW_FRAME_BUFFER_VALID) { atomic_fetch_add(&G_immagini, 1); return; }   // il core ha disegnato nel nostro framebuffer
    if (!d) return;                                         // stessa schermata
    atomic_fetch_add(&G_immagini, 1);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);                // un core GPU può averne lasciato uno legato
    glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, G_tex); glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    if (G_formato == RETRO_PIXEL_FORMAT_XRGB8888) {
        glPixelStorei(GL_UNPACK_ROW_LENGTH, (GLint)(pitch / 4));
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, d);   // BGRA: si scambia nel disegno
    } else {
        if ((size_t)w * h > G_convCap) { G_convCap = (size_t)w * h; G_conv = realloc(G_conv, G_convCap * 2); }
        for (unsigned y = 0; y < h; y++) {
            const uint16_t *r = (const uint16_t *)((const uint8_t *)d + y * pitch); uint16_t *o = G_conv + (size_t)y * w;
            if (G_formato == RETRO_PIXEL_FORMAT_RGB565) memcpy(o, r, w * 2);
            else for (unsigned x = 0; x < w; x++) { uint16_t p = r[x]; o[x] = (uint16_t)(((p & 0x7C00) << 1) | ((p & 0x03E0) << 1) | (p & 0x1F)); }
        }
        glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB565, w, h, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, G_conv);
    }
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
}
static void disegna(void) {
    if (!G_finestra || !G_w) return;
    int Wi = ANativeWindow_getWidth(G_finestra), Hi = ANativeWindow_getHeight(G_finestra);
    float W = Wi, H = Hi;
    glBindFramebuffer(GL_FRAMEBUFFER, 0); glViewport(0, 0, Wi, Hi);
    glDisable(GL_DEPTH_TEST); glDisable(GL_STENCIL_TEST); glDisable(GL_BLEND); glDisable(GL_CULL_FACE); glDisable(GL_SCISSOR_TEST);
    glDisable(GL_POLYGON_OFFSET_FILL); glDisable(GL_RASTERIZER_DISCARD); glColorMask(1, 1, 1, 1); glDepthMask(GL_TRUE);
    glBindSampler(0, 0); glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glClearColor(0, 0, 0, 1); glClear(GL_COLOR_BUFFER_BIT);
    bool hw = G_usaHw && G_fbo;
    float u = hw ? (float)G_w / G_fboW : 1, vh = hw ? (float)G_h / G_fboH : 1;
    glUseProgram(G_prog);
    glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, hw ? G_fboTex : G_tex);
    bool liscio = atomic_load(&G_filtro) || hw || G_h >= 380;
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, liscio ? GL_LINEAR : GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glUniform1i(U_tex, 0); glUniform1i(U_effetto, atomic_load(&G_effetto)); glUniform1i(U_rgb, !hw && G_formato == RETRO_PIXEL_FORMAT_XRGB8888);
    float righe = G_h >= 700 ? G_h / 3.f : G_h >= 380 ? G_h / 2.f : (float)G_h;
    glUniform2f(U_righe, righe * (float)G_w / G_h, righe);
    glBindBuffer(GL_ARRAY_BUFFER, 0); glBindVertexArray(0);
    glEnableVertexAttribArray(0); glEnableVertexAttribArray(1);
    // un rettangolo: dove (pixel, origine in alto a sinistra) e quale parte dell'immagine (0…1, riga 0 in alto)
    #define QUADRO(x0, y0, x1, y1, a0, b0, a1, b1) do { \
        float X0 = (x0) / W * 2 - 1, X1 = (x1) / W * 2 - 1, Y0 = 1 - (y0) / H * 2, Y1 = 1 - (y1) / H * 2; \
        float va = hw && G_hw.bottom_left_origin ? vh * (1 - (b0)) : vh * (b0), vb = hw && G_hw.bottom_left_origin ? vh * (1 - (b1)) : vh * (b1); \
        const float q[] = { X0, Y1, (a0) * u, vb,  X1, Y1, (a1) * u, vb,  X0, Y0, (a0) * u, va,  X1, Y0, (a1) * u, va }; \
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 16, q); glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 16, q + 2); \
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4); } while (0)
    int doppio = atomic_load(&G_doppio);
    if (!doppio) {
        float r = G_av.geometry.aspect_ratio > 0.1f ? G_av.geometry.aspect_ratio : (float)G_w / G_h;
        int forma = atomic_load(&G_forma);
        if (forma == 1 && W > H && r < 16.f / 9) r = 16.f / 9; else if (forma == 2) r = (float)W / H;
        float w = W, h = w / r; if (h > H) { h = H; w = h * r; }
        float x0 = (W - w) / 2, y0 = H > W ? 0 : (H - h) / 2;      // in verticale in alto: i tasti stanno sotto
        QUADRO(x0, y0, x0 + w, y0 + h, 0, 0, 1, 1);
        G_areaTocco[0] = x0; G_areaTocco[1] = y0; G_areaTocco[2] = x0 + w; G_areaTocco[3] = y0 + h; G_toccoU[0] = 0; G_toccoU[1] = 1;
    } else {
        // 3DS: sopra 400×240, sotto 320×240 centrato (nell'immagine larga 400); DS: tutti e due 256×192
        float cl = doppio == 2 ? 0.1f : 0, cr = doppio == 2 ? 0.9f : 1;
        float aSu = (float)G_w / (G_h * 0.5f), aGiu = aSu * (cr - cl);
        int d = atomic_load(&G_dispDoppio); if (d == 0) d = H > W ? 1 : 2;
        float su[4], giu[4];
        if (d == 1) {                     // uno sopra l'altro
            float uu = fminf(H / 2, W / fmaxf(aSu, aGiu)), y0 = H > W ? 0 : (H - 2 * uu) / 2;
            su[0] = (W - aSu * uu) / 2; su[1] = y0; su[2] = su[0] + aSu * uu; su[3] = y0 + uu;
            giu[0] = (W - aGiu * uu) / 2; giu[1] = y0 + uu; giu[2] = giu[0] + aGiu * uu; giu[3] = y0 + 2 * uu;
        } else if (d == 2) {              // affiancati: in orizzontale i più grandi
            float uu = fminf(H, W / (aSu + aGiu)), x0 = (W - (aSu + aGiu) * uu) / 2, y0 = H > W ? 0 : (H - uu) / 2;
            su[0] = x0; su[1] = y0; su[2] = x0 + aSu * uu; su[3] = y0 + uu;
            giu[0] = su[2]; giu[1] = y0; giu[2] = giu[0] + aGiu * uu; giu[3] = y0 + uu;
        } else {                          // grande + piccolo: quello di sopra grande, quello da toccare accanto in piccolo
            float k = 0.42f, uu = fminf(H, W / (aSu + k * aGiu)), x0 = (W - (aSu + k * aGiu) * uu) / 2, y0 = H > W ? 0 : (H - uu) / 2;
            su[0] = x0; su[1] = y0; su[2] = x0 + aSu * uu; su[3] = y0 + uu;
            giu[0] = su[2]; giu[1] = y0 + uu * (1 - k); giu[2] = giu[0] + aGiu * uu * k; giu[3] = y0 + uu;
        }
        QUADRO(su[0], su[1], su[2], su[3], 0, 0, 1, 0.5f);
        QUADRO(giu[0], giu[1], giu[2], giu[3], cl, 0.5f, cr, 1);
        memcpy(G_areaTocco, giu, sizeof giu); G_toccoU[0] = cl; G_toccoU[1] = cr;
    }
    #undef QUADRO
    eglSwapBuffers(G_dpy, G_sup);
}

// ---- libretro: ambiente --------------------------------------------------------------------------------------
static char G_messaggi[4096]; static pthread_mutex_t G_lockMsg = PTHREAD_MUTEX_INITIALIZER;
static void ricorda(const char *t) {
    pthread_mutex_lock(&G_lockMsg);
    size_t n = strlen(G_messaggi), m = strlen(t);
    if (n + m + 2 >= sizeof G_messaggi) { size_t via = n + m + 2 - sizeof G_messaggi + 512; if (via > n) via = n; memmove(G_messaggi, G_messaggi + via, n - via + 1); }
    strncat(G_messaggi, t, sizeof G_messaggi - strlen(G_messaggi) - 2);
    if (m == 0 || t[m - 1] != '\n') strcat(G_messaggi, "\n");
    pthread_mutex_unlock(&G_lockMsg);
}
static void logCore(enum retro_log_level l, const char *f, ...) {
    char riga[512]; va_list a; va_start(a, f); vsnprintf(riga, sizeof riga, f, a); va_end(a);
    __android_log_print(ANDROID_LOG_INFO, "FMLAB-core", "%s", riga);
    if (l >= RETRO_LOG_WARN) ricorda(riga);     // avvisi ed errori: si mostrano se il gioco non parte
}
static bool ambiente(unsigned cmd, void *data) {
    switch (cmd & ~RETRO_ENVIRONMENT_EXPERIMENTAL) {
    case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY: *(const char **)data = G_sistema; return true;
    case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY: *(const char **)data = G_salvataggi; return true;
    case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: { enum retro_pixel_format f = *(const enum retro_pixel_format *)data; if (f > RETRO_PIXEL_FORMAT_RGB565) return false; G_formato = f; return true; }
    case RETRO_ENVIRONMENT_GET_VARIABLE: {
        struct retro_variable *v = data; v->value = NULL;
        for (int i = 0; i + 1 < G_nopz; i += 2) if (!strcmp(G_opz[i], v->key)) { v->value = G_opz[i + 1]; return true; }
        return false;
    }
    case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: *(bool *)data = atomic_exchange(&G_varNuove, false); return true;
    case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION: *(unsigned *)data = 0; return true;
    case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: ((struct retro_log_callback *)data)->log = logCore; return true;
    case RETRO_ENVIRONMENT_GET_CAN_DUPE: *(bool *)data = true; return true;
    case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS: return true;
    case RETRO_ENVIRONMENT_GET_LANGUAGE: *(unsigned *)data = RETRO_LANGUAGE_ITALIAN; return true;
    case RETRO_ENVIRONMENT_GET_FASTFORWARDING: *(bool *)data = atomic_load(&G_veloce); return true;
    case RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE: *(int *)data = 3; return true;
    case RETRO_ENVIRONMENT_SET_GEOMETRY: G_av.geometry = *(const struct retro_game_geometry *)data; return true;
    case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO: G_av = *(const struct retro_system_av_info *)data; atomic_store(&G_fboNuovo, true); return true;
    case RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER: *(unsigned *)data = RETRO_HW_CONTEXT_OPENGLES3; return true;
    case RETRO_ENVIRONMENT_SET_HW_RENDER: {
        struct retro_hw_render_callback *h = data;
        if (h->context_type != RETRO_HW_CONTEXT_OPENGLES2 && h->context_type != RETRO_HW_CONTEXT_OPENGLES3 && h->context_type != RETRO_HW_CONTEXT_OPENGLES_VERSION) {
            char t[160]; snprintf(t, sizeof t, "FMLAB: graphics type %d not available on Android (OpenGL ES only)", (int)h->context_type); ricorda(t); return false;
        }
        h->get_current_framebuffer = hwFbo; h->get_proc_address = hwProc;
        G_hw = *h; G_usaHw = true; return true;
    }
    case RETRO_ENVIRONMENT_SET_MESSAGE: { const struct retro_message *m = data; if (m && m->msg) ricorda(m->msg); return true; }
    case (RETRO_ENVIRONMENT_SET_HW_SHARED_CONTEXT & ~RETRO_ENVIRONMENT_EXPERIMENTAL): return true;
    case RETRO_ENVIRONMENT_SET_VARIABLES: case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
    case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL: case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS: case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
    case RETRO_ENVIRONMENT_SET_SUBSYSTEM_INFO: case RETRO_ENVIRONMENT_SET_MEMORY_MAPS: return true;
    default: return false;
    }
}
static void poll(void) {}
static int16_t stato(unsigned port, unsigned device, unsigned index, unsigned id) {
    if (port >= 4) return 0;
    unsigned t = atomic_load(&G_tasti[port]);
    switch (device) {
    case RETRO_DEVICE_JOYPAD: return id == RETRO_DEVICE_ID_JOYPAD_MASK ? (int16_t)t : (int16_t)((t >> id) & 1);
    case RETRO_DEVICE_ANALOG:
        if (index == RETRO_DEVICE_INDEX_ANALOG_LEFT) return (int16_t)(id == RETRO_DEVICE_ID_ANALOG_X ? atomic_load(&G_lx[port]) : atomic_load(&G_ly[port]));
        return 0;
    case RETRO_DEVICE_POINTER:
        if (port) return 0;
        if (id == RETRO_DEVICE_ID_POINTER_X) return (int16_t)atomic_load(&G_tx);
        if (id == RETRO_DEVICE_ID_POINTER_Y) return (int16_t)atomic_load(&G_ty);
        if (id == RETRO_DEVICE_ID_POINTER_PRESSED) return (int16_t)atomic_load(&G_tocco);
        return 0;
    }
    return 0;
}

// ---- salvataggi ----------------------------------------------------------------------------------------------
static uint64_t G_impronta;
static uint64_t fnv(const uint8_t *p, size_t n) { uint64_t h = 1469598103934665603ULL; for (size_t i = 0; i < n; i++) { h ^= p[i]; h *= 1099511628211ULL; } return h; }
static void leggiSram(void) {
    size_t n = C.mem_size ? C.mem_size(RETRO_MEMORY_SAVE_RAM) : 0; uint8_t *m = n ? C.mem_data(RETRO_MEMORY_SAVE_RAM) : NULL; if (!m) return;
    FILE *f = fopen(G_srm, "rb"); if (f) { fread(m, 1, n, f); fclose(f); }
    G_impronta = fnv(m, n);
}
static void scriviSram(bool forza) {
    size_t n = C.mem_size ? C.mem_size(RETRO_MEMORY_SAVE_RAM) : 0; uint8_t *m = n ? C.mem_data(RETRO_MEMORY_SAVE_RAM) : NULL; if (!m) return;
    uint64_t h = fnv(m, n); if (!forza && h == G_impronta) return;
    char tmp[1300]; snprintf(tmp, sizeof tmp, "%s.tmp", G_srm);
    FILE *f = fopen(tmp, "wb"); if (!f) return; fwrite(m, 1, n, f); fclose(f); rename(tmp, G_srm);   // mai un file a metà
    G_impronta = h;
}
static bool salvaStato(const char *p) {
    size_t n = C.ser_size(); if (!n) return false; void *b = malloc(n); bool ok = C.ser(b, n);
    if (ok) { char tmp[1300]; snprintf(tmp, sizeof tmp, "%s.tmp", p); FILE *f = fopen(tmp, "wb"); ok = f && fwrite(b, 1, n, f) == n; if (f) fclose(f); if (ok) rename(tmp, p); }
    free(b); return ok;
}
static bool caricaStato(const char *p) {
    FILE *f = fopen(p, "rb"); if (!f) return false; fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    void *b = malloc(n); bool ok = fread(b, 1, n, f) == (size_t)n; fclose(f); ok = ok && C.unser(b, n); free(b); return ok;
}

// ---- il giro del gioco ---------------------------------------------------------------------------------------
static double ora(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
static char G_gioco[1200]; static struct retro_game_info G_info; static void *G_datiGioco;

static void *giro(void *u) {
    if (!creaContesto()) { atomic_store(&G_esito, -2); return NULL; }
    if (!C.load(&G_info)) { atomic_store(&G_esito, -3); return NULL; }
    C.get_av(&G_av);
    C.set_port(0, RETRO_DEVICE_JOYPAD); C.set_port(1, RETRO_DEVICE_JOYPAD);
    if (G_usaHw) {
        unsigned w = G_av.geometry.max_width ? G_av.geometry.max_width : 2048, h = G_av.geometry.max_height ? G_av.geometry.max_height : 2048;
        fboPronto(w < 2048 ? 2048 : w, h < 2048 ? 2048 : h);
        if (G_hw.context_reset) G_hw.context_reset();
    }
    leggiSram();
    apriAudio(G_av.timing.sample_rate > 1000 ? (int)G_av.timing.sample_rate : 44100);
    atomic_store(&G_esito, 1);
    double prossimo = ora(), ultimoSalvo = ora(), conta = ora(); int fotogrammi = 0;
    while (!atomic_load(&G_ferma)) {
        if (atomic_load(&G_cambioFinestra)) cambiaFinestra();
        int fai = atomic_exchange(&G_daFare, 0);
        if (fai == 1) atomic_store(&G_esito, salvaStato(G_azione) ? 2 : -4);
        if (fai == 2) atomic_store(&G_esito, caricaStato(G_azione) ? 3 : -5);
        if (atomic_load(&G_pausa)) { usleep(20000); prossimo = ora(); disegna(); continue; }
        if (G_usaHw) { glBindFramebuffer(GL_FRAMEBUFFER, G_fbo); }
        C.run();
        if (G_nuova) { G_nuova = false; disegna(); }
        if (atomic_exchange(&G_fboNuovo, false) && G_usaHw && (G_av.geometry.max_width > G_fboW || G_av.geometry.max_height > G_fboH)) {
            fboPronto(G_av.geometry.max_width, G_av.geometry.max_height);   // più grande: il core disegna nel nuovo
        }
        if (atomic_exchange(&G_riapriAudio, false) && G_audio) {
            AAudioStream_close(G_audio); G_audio = NULL; apriAudio(G_frequenza);
        }
        fotogrammi++;
        double adesso = ora();
        if (adesso - conta >= 0.5) { atomic_store(&G_fps100, (int)(fotogrammi * 100 / (adesso - conta))); fotogrammi = 0; conta = adesso; }
        if (adesso - ultimoSalvo > 2) { scriviSram(false); ultimoSalvo = adesso; }   // il gioco ha salvato? su disco
        double fps = G_av.timing.fps > 1 ? G_av.timing.fps : 60, periodo = 1.0 / fps;
        double hz = G_av.timing.sample_rate > 1000 ? G_av.timing.sample_rate : 44100;
        unsigned coda = atomic_load(&G_scrivi) - atomic_load(&G_leggi);
        double scarto = coda / hz - 0.06, extra = coda > hz * 0.3 ? periodo * 0.25 : periodo * (scarto * 0.4 > 0.015 ? 0.015 : scarto * 0.4 < -0.015 ? -0.015 : scarto * 0.4);
        if (atomic_load(&G_veloce)) extra = -periodo * (1 - 1 / 3.0);
        prossimo += periodo + extra;
        double resta = prossimo - ora();
        if (resta > 0) usleep((useconds_t)(resta * 1e6)); else if (resta < -0.25) prossimo = ora();
    }
    scriviSram(true);
    if (G_audio) { AAudioStream_requestStop(G_audio); AAudioStream_close(G_audio); G_audio = NULL; }
    if (G_usaHw && G_hw.context_destroy) G_hw.context_destroy();
    C.unload(); C.deinit();
    eglMakeCurrent(G_dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (G_sup != EGL_NO_SURFACE) eglDestroySurface(G_dpy, G_sup); G_sup = EGL_NO_SURFACE;
    eglDestroyContext(G_dpy, G_ctx); G_ctx = EGL_NO_CONTEXT; eglTerminate(G_dpy); G_dpy = EGL_NO_DISPLAY;
    if (G_finestra) { ANativeWindow_release(G_finestra); G_finestra = NULL; }
    G_fbo = 0; G_fboW = G_fboH = 0; G_w = G_h = 0;
    return NULL;
}

// ---- JNI: dev.fmlab.controller.Motore ------------------------------------------------------------------------
#define J(nome) Java_dev_fmlab_controller_Motore_##nome
static void copia(JNIEnv *e, jstring s, char *d, size_t n) { const char *c = (*e)->GetStringUTFChars(e, s, NULL); strlcpy(d, c, n); (*e)->ReleaseStringUTFChars(e, s, c); }

JNIEXPORT jstring JNICALL J(avvia)(JNIEnv *e, jclass k, jstring core, jstring gioco, jstring sistema, jstring salvataggi, jobjectArray opzioni) {
    if (atomic_load(&G_vivo)) return (*e)->NewStringUTF(e, "busy");
    char percorso[1200]; copia(e, core, percorso, sizeof percorso); copia(e, gioco, G_gioco, sizeof G_gioco);
    copia(e, sistema, G_sistema, sizeof G_sistema); copia(e, salvataggi, G_salvataggi, sizeof G_salvataggi);
    for (int i = 0; i < G_nopz; i++) free(G_opz[i]); free(G_opz);
    G_nopz = (*e)->GetArrayLength(e, opzioni); G_opz = calloc(G_nopz + 1, sizeof(char *));
    for (int i = 0; i < G_nopz; i++) { jstring s = (*e)->GetObjectArrayElement(e, opzioni, i); const char *c = (*e)->GetStringUTFChars(e, s, NULL); G_opz[i] = strdup(c); (*e)->ReleaseStringUTFChars(e, s, c); }
    memset(&C, 0, sizeof C);
    C.h = dlopen(percorso, RTLD_NOW | RTLD_LOCAL);
    if (!C.h) return (*e)->NewStringUTF(e, dlerror());
#define S(campo, nome) C.campo = dlsym(C.h, nome); if (!C.campo) return (*e)->NewStringUTF(e, "missing " nome);
    S(init, "retro_init") S(deinit, "retro_deinit") S(get_sys, "retro_get_system_info") S(get_av, "retro_get_system_av_info")
    S(set_env, "retro_set_environment") S(set_video, "retro_set_video_refresh") S(set_audio, "retro_set_audio_sample")
    S(set_batch, "retro_set_audio_sample_batch") S(set_poll, "retro_set_input_poll") S(set_state, "retro_set_input_state")
    S(set_port, "retro_set_controller_port_device") S(reset, "retro_reset") S(run, "retro_run") S(ser_size, "retro_serialize_size")
    S(ser, "retro_serialize") S(unser, "retro_unserialize") S(load, "retro_load_game") S(unload, "retro_unload_game")
    S(mem_data, "retro_get_memory_data") S(mem_size, "retro_get_memory_size")
#undef S
    G_usaHw = false; memset(&G_hw, 0, sizeof G_hw); G_formato = RETRO_PIXEL_FORMAT_0RGB1555;
    for (int i = 0; i < 4; i++) { atomic_store(&G_tasti[i], 0); atomic_store(&G_lx[i], 0); atomic_store(&G_ly[i], 0); }
    atomic_store(&G_scrivi, 0); atomic_store(&G_leggi, 0);
    C.set_env(ambiente); C.set_video(video); C.set_audio(suono); C.set_batch(suoni); C.set_poll(poll); C.set_state(stato);
    C.init();
    struct retro_system_info si = {0}; C.get_sys(&si);
    // salvataggio: <Salvataggi>/<nome del gioco>.srm
    const char *base = strrchr(G_gioco, '/'); base = base ? base + 1 : G_gioco;
    char nome[600]; strlcpy(nome, base, sizeof nome); char *punto = strrchr(nome, '.'); if (punto) *punto = 0;
    snprintf(G_srm, sizeof G_srm, "%s/%s.srm", G_salvataggi, nome);
    memset(&G_info, 0, sizeof G_info); G_info.path = G_gioco;
    free(G_datiGioco); G_datiGioco = NULL;
    if (!si.need_fullpath) {   // il core vuole il gioco in memoria
        FILE *f = fopen(G_gioco, "rb"); if (!f) return (*e)->NewStringUTF(e, "cannot read game");
        fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET); G_datiGioco = malloc(n); fread(G_datiGioco, 1, n, f); fclose(f);
        G_info.data = G_datiGioco; G_info.size = n;
    }
    atomic_store(&G_ferma, false); atomic_store(&G_pausa, false); atomic_store(&G_esito, 0); atomic_store(&G_vivo, true);
    atomic_store(&G_immagini, 0); pthread_mutex_lock(&G_lockMsg); G_messaggi[0] = 0; pthread_mutex_unlock(&G_lockMsg);
    pthread_create(&G_filo, NULL, giro, NULL);
    for (int i = 0; i < 400 && atomic_load(&G_esito) == 0; i++) usleep(10000);   // fino a 4 s per caricare il gioco
    int es = atomic_load(&G_esito);
    if (es < 0) { atomic_store(&G_ferma, true); pthread_join(G_filo, NULL); atomic_store(&G_vivo, false); dlclose(C.h); return (*e)->NewStringUTF(e, es == -2 ? "OpenGL ES 3 not available" : "The emulator could not open this game"); }
    return NULL;
}
JNIEXPORT void JNICALL J(superficie)(JNIEnv *e, jclass k, jobject s) {
    pthread_mutex_lock(&G_lock);
    if (G_finestraNuova) ANativeWindow_release(G_finestraNuova);
    G_finestraNuova = s ? ANativeWindow_fromSurface(e, s) : NULL;
    atomic_store(&G_cambioFinestra, true);
    pthread_mutex_unlock(&G_lock);
    if (!s && atomic_load(&G_vivo)) for (int i = 0; i < 50 && atomic_load(&G_cambioFinestra); i++) usleep(5000);   // la Surface sta sparendo: si aspetta
}
JNIEXPORT void JNICALL J(tasti)(JNIEnv *e, jclass k, jint p, jint t) { if (p >= 0 && p < 4) atomic_store(&G_tasti[p], (unsigned)t); }
JNIEXPORT void JNICALL J(levetta)(JNIEnv *e, jclass k, jint p, jint x, jint y) { if (p >= 0 && p < 4) { atomic_store(&G_lx[p], x); atomic_store(&G_ly[p], y); } }
JNIEXPORT void JNICALL J(tocco)(JNIEnv *e, jclass k, jint x, jint y, jboolean giu) { atomic_store(&G_tx, x); atomic_store(&G_ty, y); atomic_store(&G_tocco, giu); }
JNIEXPORT void JNICALL J(pausa)(JNIEnv *e, jclass k, jboolean s) { atomic_store(&G_pausa, s); if (G_audio) { if (s) AAudioStream_requestPause(G_audio); else AAudioStream_requestStart(G_audio); } }
JNIEXPORT void JNICALL J(veloce)(JNIEnv *e, jclass k, jboolean s, jboolean muto) { atomic_store(&G_veloce, s); atomic_store(&G_muto, s && muto); }
JNIEXPORT void JNICALL J(immagine)(JNIEnv *e, jclass k, jint filtro, jint effetto, jint forma) { atomic_store(&G_filtro, filtro); atomic_store(&G_effetto, effetto); atomic_store(&G_forma, forma); }
JNIEXPORT jint JNICALL J(fps100)(JNIEnv *e, jclass k) { return atomic_load(&G_fps100); }
JNIEXPORT jfloat JNICALL J(rapporto)(JNIEnv *e, jclass k) { return G_av.geometry.aspect_ratio > 0.1f ? G_av.geometry.aspect_ratio : (G_h ? (float)G_w / G_h : 4.f / 3); }
static jboolean azione(JNIEnv *e, jstring p, int tipo) {
    if (!atomic_load(&G_vivo)) return false;
    copia(e, p, G_azione, sizeof G_azione); atomic_store(&G_esito, 1); atomic_store(&G_daFare, tipo);
    for (int i = 0; i < 300 && atomic_load(&G_esito) == 1; i++) usleep(10000);
    int es = atomic_load(&G_esito); return es == 2 || es == 3;
}
JNIEXPORT jboolean JNICALL J(salvaStato)(JNIEnv *e, jclass k, jstring p) { return azione(e, p, 1); }
JNIEXPORT jboolean JNICALL J(caricaStato)(JNIEnv *e, jclass k, jstring p) { return azione(e, p, 2); }
JNIEXPORT void JNICALL J(ferma)(JNIEnv *e, jclass k) {
    if (!atomic_load(&G_vivo)) return;
    atomic_store(&G_pausa, false); atomic_store(&G_ferma, true); pthread_join(G_filo, NULL); atomic_store(&G_vivo, false);
    if (C.h) dlclose(C.h); C.h = NULL;
}

JNIEXPORT jint JNICALL J(immagini)(JNIEnv *e, jclass k) { return atomic_load(&G_immagini); }
JNIEXPORT jstring JNICALL J(messaggi)(JNIEnv *e, jclass k) {
    pthread_mutex_lock(&G_lockMsg); jstring s = (*e)->NewStringUTF(e, G_messaggi); pthread_mutex_unlock(&G_lockMsg); return s;
}
JNIEXPORT jboolean JNICALL J(usaGpu)(JNIEnv *e, jclass k) { return G_usaHw; }

JNIEXPORT void JNICALL J(schermi)(JNIEnv *e, jclass k, jint doppio, jint disposizione) { atomic_store(&G_doppio, doppio); atomic_store(&G_dispDoppio, disposizione); }
/** Schermo da toccare: x0, y0, x1, y1 in pixel, poi la parte orizzontale dell'immagine (u0, u1) e se è la metà di sotto (1) o tutta (0). */
JNIEXPORT jfloatArray JNICALL J(areaTocco)(JNIEnv *e, jclass k) {
    float v[7] = { G_areaTocco[0], G_areaTocco[1], G_areaTocco[2], G_areaTocco[3], G_toccoU[0], G_toccoU[1], atomic_load(&G_doppio) ? 1.f : 0.f };
    jfloatArray a = (*e)->NewFloatArray(e, 7); (*e)->SetFloatArrayRegion(e, a, 0, 7, v); return a;
}
