// mslc: compile MSL sources with Metal's own compiler, through the device
// (MTLDevice newLibraryWithSource), and fail on any diagnostic.
//
//     build/mslc FILE.metal...      # each compiled; exit 1 if any is refused
//
// The runtime compiler reports diagnostics only when a source fails, so each
// source is compiled behind pragmas that make every warning clang knows an
// error (-Weverything), less four groups that say nothing about a shader:
// C++98 compatibility, padding a struct (the std140 blocks are padded on
// purpose), the `vertex`/`fragment` keywords Metal 4 deprecates in favour of
// attributes older Metal does not take, and an unused parameter (a helper's
// own, from its quote, or a sampler handed beside a texture only read).
// That is stricter than `xcrun metal`'s default set, which needs the Metal
// Toolchain component (scripts/msl_check.sh runs it too where it is there).
// Built and run by scripts/msl_check.sh.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static NSString *const STRICT =
    @"#pragma clang diagnostic error \"-Weverything\"\n"
    @"#pragma clang diagnostic ignored \"-Wc++98-compat\"\n"
    @"#pragma clang diagnostic ignored \"-Wc++98-compat-pedantic\"\n"
    @"#pragma clang diagnostic ignored \"-Wpadded\"\n"
    @"#pragma clang diagnostic ignored \"-Wdeprecated\"\n"
    @"#pragma clang diagnostic ignored \"-Wunused-parameter\"\n";

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: mslc FILE.metal...\n");
            return 2;
        }
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            fprintf(stderr, "mslc: no Metal device\n");
            return 3;
        }
        MTLCompileOptions *options = [MTLCompileOptions new];
        int refused = 0;
        for (int i = 1; i < argc; i++) {
            NSString *path = [NSString stringWithUTF8String:argv[i]];
            NSError *error = nil;
            NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
            if (!source) {
                fprintf(stderr, "%s: cannot read it\n", argv[i]);
                refused++;
                continue;
            }
            error = nil;
            id<MTLLibrary> library = [device newLibraryWithSource:[STRICT stringByAppendingString:source]
                                                          options:options
                                                            error:&error];
            if (!library || error) {
                // Line numbers are the source's plus the pragmas' six.
                fprintf(stderr, "%s: %s\n", argv[i], error ? [[error localizedDescription] UTF8String] : "refused");
                refused++;
            } else {
                printf("%s: %lu functions\n", argv[i], (unsigned long)[[library functionNames] count]);
            }
        }
        return refused ? 1 : 0;
    }
}
