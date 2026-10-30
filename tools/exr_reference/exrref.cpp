// A reference for ae3d's OpenEXR reader (ae3d.openexr), built against the
// official OpenEXR library. NOT part of ae3d and not built by ci.sh: ae3d
// links nothing of OpenEXR, and the reader is pure Aether. This tool is how
// the PIZ fixtures in tests/fixtures/env were written and how the decoded
// pixels they are held to were produced, kept so that both can be redone.
//
//   build:  c++ -O2 -std=c++17 tools/exr_reference/exrref.cpp -o exrref \
//             $(pkg-config --cflags --libs OpenEXR)
//   write:  exrref write out.exr WIDTH HEIGHT COMPRESSION CHANNELS PATTERN [MINX MINY]
//             COMPRESSION piz zip zips rle none b44 pxr24 dwaa
//             CHANNELS    RGBh RGBAh RGBf RGBAf Yh Yf (h half, f float)
//             PATTERN     grad hgrad grain bitramp noise noisehalf const zero sparse lowrange ramp
//                         (hgrad: grad rounded to half precision, which is what makes a FLOAT
//                         picture compress; grain: grad with a random few percent on it;
//                         bitramp: R counts up through the bit patterns, one a texel, so a
//                         block holds over 16384 different 16-bit values yet compresses)
//   dump:   exrref dump in.exr [out.f32]
//             prints "WIDTH HEIGHT H1 H2" and, when given, writes the decode
//             as RGBA float32 texels, rows top first (alpha 1 when the file
//             has none, Y spread to R, G and B), the form ae3d's hdrimage has.
//
// H1 and H2 are position-sensitive hashes of the texels' bit patterns:
// h = (h * B + word) mod P, words in order, with (B, P) = (31, 1000000007)
// and (131, 998244353); tests/test_envimage.ae computes the same two.
//
// Written from OpenEXR's public API (BSD-3-Clause, Copyright (c) Contributors
// to the OpenEXR Project); no code of it is in ae3d.
#include <ImfChannelList.h>
#include <ImfFrameBuffer.h>
#include <ImfHeader.h>
#include <ImfInputFile.h>
#include <ImfOutputFile.h>
#include <ImathBox.h>
#include <half.h>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

using namespace Imf;
using namespace Imath;

static uint64_t g_rng = 88172645463325252ull;
static uint32_t rnd() {
    g_rng ^= g_rng << 13; g_rng ^= g_rng >> 7; g_rng ^= g_rng << 17;
    return (uint32_t)(g_rng >> 11);
}

static Compression comp_of(const std::string& s) {
    if (s == "none") return NO_COMPRESSION;
    if (s == "rle") return RLE_COMPRESSION;
    if (s == "zips") return ZIPS_COMPRESSION;
    if (s == "zip") return ZIP_COMPRESSION;
    if (s == "piz") return PIZ_COMPRESSION;
    if (s == "pxr24") return PXR24_COMPRESSION;
    if (s == "b44") return B44_COMPRESSION;
    if (s == "dwaa") return DWAA_COMPRESSION;
    fprintf(stderr, "unknown compression %s\n", s.c_str());
    exit(2);
}

// A finite float with the given bits' sign and a bounded exponent.
static float finite_float_from_bits(uint32_t bits) {
    uint32_t e = (bits >> 23) & 255;
    if (e == 255) bits &= ~(1u << 23);  // not an infinity or NaN
    float f;
    memcpy(&f, &bits, 4);
    return f;
}

static float value(const std::string& pattern, int x, int y, int c, int w, int h) {
    if (pattern == "zero") return 0.0f;
    if (pattern == "const") return c == 0 ? 0.5f : (c == 1 ? 0.75f : (c == 2 ? 0.25f : 1.0f));
    if (pattern == "sparse") {
        if (((x * 7 + y * 13) % 97) == 0) return 1000.0f + (float)c;
        return 0.0f;
    }
    if (pattern == "ramp") {
        // exact in half: R = x, G = y, B = x + y, A = 1; runs of one difference
        if (c == 0) return (float)x;
        if (c == 1) return (float)y;
        if (c == 2) return (float)(x + y);
        return 1.0f;
    }
    if (pattern == "lowrange") {
        // few distinct values: the wavelet's 14-bit path
        return (float)(((x / 3 + y / 5 + c) % 9)) * 0.125f;
    }
    float u = (float)x / (float)(w > 1 ? w - 1 : 1);
    float v = (float)y / (float)(h > 1 ? h - 1 : 1);
    if (pattern == "grad" || pattern == "grain" || pattern == "hgrad") {
        float s = sinf(v * 3.14159265f) * (1.0f + 0.25f * sinf(u * 12.5f));
        float g = 1.0f;
        if (pattern == "grain") g = 1.0f + 0.05f * ((float)(rnd() & 0xffff) / 65536.0f - 0.5f);
        float r = 0.5f + 0.5f * u;
        if (c == 0) r = g * (0.05f + 4.0f * s * u);
        if (c == 1) r = g * (0.1f + 3.0f * s);
        if (c == 2) r = g * (0.2f + 8.0f * v * v);
        if (pattern == "hgrad") r = (float)half(r);
        return r;
    }
    return 0.0f;
}

static int do_write(int argc, char** argv) {
    if (argc < 8) { fprintf(stderr, "write out W H comp chans pattern [minx miny]\n"); return 2; }
    std::string out = argv[2];
    int w = atoi(argv[3]), h = atoi(argv[4]);
    Compression comp = comp_of(argv[5]);
    std::string chans = argv[6];
    std::string pattern = argv[7];
    int minx = argc > 8 ? atoi(argv[8]) : 0;
    int miny = argc > 9 ? atoi(argv[9]) : 0;
    bool use_half = chans.back() == 'h';
    std::string names = chans.substr(0, chans.size() - 1);
    Box2i win(V2i(minx, miny), V2i(minx + w - 1, miny + h - 1));
    Header header(win, win);
    header.compression() = comp;
    PixelType pt = use_half ? HALF : FLOAT;
    int n = (int)names.size();
    for (char ch : names) header.channels().insert(std::string(1, ch), Channel(pt));
    std::vector<half> hb;
    std::vector<float> fb;
    if (use_half) hb.resize((size_t)w * h * n); else fb.resize((size_t)w * h * n);
    for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
            for (int c = 0; c < n; c++) {
                size_t i = ((size_t)y * w + x) * n + c;
                if (pattern == "bitramp") {
                    size_t k = (size_t)y * w + x;
                    if (use_half) {
                        uint16_t b = (uint16_t)(k < 31744 ? k : 0x8000 + (k - 31744) % 31744);
                        half hv; hv.setBits(c == 0 ? b : (c == 1 ? 0x3c00 : half((float)x * 0.5f).bits()));
                        if (c == 3) hv = half(1.0f);
                        hb[i] = hv;
                    } else {
                        uint32_t b = 0x3f800000u + (uint32_t)k;
                        float f; memcpy(&f, &b, 4);
                        fb[i] = c == 0 ? f : (c == 1 ? 1.0f : (c == 2 ? (float)x * 0.5f : 1.0f));
                    }
                } else if (pattern == "noise") {
                    // every float / half bit pattern that is finite
                    if (use_half) { uint16_t b = rnd() & 0xffff; if (((b >> 10) & 31) == 31) b &= 0xfbff; hb[i].setBits(b); }
                    else fb[i] = finite_float_from_bits(rnd() * 2654435761u + rnd());
                } else if (pattern == "noisehalf") {
                    // exactly representable in half, spread over its whole range
                    uint16_t b = rnd() & 0xffff; if (((b >> 10) & 31) == 31) b &= 0xfbff;
                    half hv; hv.setBits(b);
                    if (use_half) hb[i] = hv; else fb[i] = (float)hv;
                } else {
                    float v = value(pattern, x, y, c, w, h);
                    if (use_half) hb[i] = half(v); else fb[i] = v;
                }
            }
    OutputFile file(out.c_str(), header);
    FrameBuffer fbuf;
    for (int c = 0; c < n; c++) {
        char* base = use_half ? (char*)(hb.data() + c) : (char*)(fb.data() + c);
        size_t xs = (use_half ? 2 : 4) * (size_t)n;
        // the data window's origin is not the array's: offset the base
        base -= (size_t)(minx) * xs + (size_t)(miny) * xs * w;
        fbuf.insert(std::string(1, names[c]), Slice(pt, base, xs, xs * w));
    }
    file.setFrameBuffer(fbuf);
    file.writePixels(h);
    return 0;
}

static int do_dump(int argc, char** argv) {
    if (argc < 3) { fprintf(stderr, "dump in.exr [out.f32]\n"); return 2; }
    InputFile file(argv[2]);
    Box2i dw = file.header().dataWindow();
    int w = dw.max.x - dw.min.x + 1, h = dw.max.y - dw.min.y + 1;
    const ChannelList& cl = file.header().channels();
    std::vector<float> px((size_t)w * h * 4, 0.0f);
    for (size_t i = 0; i < (size_t)w * h; i++) px[i * 4 + 3] = 1.0f;
    bool grey = cl.findChannel("Y") && !cl.findChannel("R");
    FrameBuffer fb;
    const char* names[4] = {"R", "G", "B", "A"};
    for (int c = 0; c < 4; c++) {
        const char* nm = grey && c < 3 ? "Y" : names[c];
        if (grey && c > 0 && c < 3) continue;  // Y read once, spread after
        if (!cl.findChannel(nm)) continue;
        char* base = (char*)(px.data() + c);
        base -= (size_t)dw.min.x * 16 + (size_t)dw.min.y * 16 * w;
        fb.insert(nm, Slice(FLOAT, base, 16, (size_t)16 * w));
    }
    file.setFrameBuffer(fb);
    file.readPixels(dw.min.y, dw.max.y);
    if (grey)
        for (size_t i = 0; i < (size_t)w * h; i++) { px[i * 4 + 1] = px[i * 4]; px[i * 4 + 2] = px[i * 4]; }
    uint64_t h1 = 0, h2 = 0;
    const uint32_t* words = (const uint32_t*)px.data();
    for (size_t i = 0; i < px.size(); i++) {
        h1 = (h1 * 31 + words[i]) % 1000000007ull;
        h2 = (h2 * 131 + words[i]) % 998244353ull;
    }
    printf("%d %d %llu %llu\n", w, h, (unsigned long long)h1, (unsigned long long)h2);
    if (argc > 3) {
        FILE* f = fopen(argv[3], "wb");
        fwrite(px.data(), 4, px.size(), f);
        fclose(f);
    }
    return 0;
}

int main(int argc, char** argv) {
    try {
        if (argc >= 2 && !strcmp(argv[1], "write")) return do_write(argc, argv);
        if (argc >= 2 && !strcmp(argv[1], "dump")) return do_dump(argc, argv);
    } catch (std::exception& e) {
        fprintf(stderr, "error: %s\n", e.what());
        return 1;
    }
    fprintf(stderr, "usage: exrref write|dump ...\n");
    return 2;
}
