### The editor's driver percent-encodes what it types

- **The hex field is typed into again on Aether 0.881.0 and later.** The
  editor's driver set a text field with `/widget/<id>/set_text?v=<text>`,
  the text written raw. Since Aether 0.881.0 (#3520) the HTTP client sends
  a URL's path and query and never its fragment, as RFC 3986 has it, so
  `?v=#FF0000` reached aether-ui's driver as `?v=` and the hex field was
  set to nothing. Two checks failed with it on the 0.931.0 pin (run
  44836887479, linux-editor): "a colour typed into the hex field sets the
  material" and, the material never having turned red, "the picker's
  square is painted at its hue" (top right pixel 0x016EFA). Nothing in the
  editor changed. `set_text` now percent-encodes everything past the
  unreserved characters, which aether-ui's driver decodes; a `+`, `&` or
  `%` in a typed value would have been misread the same way.
- The request line, read off a listening socket, for
  `http.post("http://127.0.0.1:P/widget/7/set_text?v=#FF0000", ...)`:
  `?v=#FF0000` on 0.880.0, `?v=` on 0.881.0 and 0.931.0; `?v=%23FF0000`
  is sent whole on all three.
- `test_script`, run on its own without ci.sh's scripts step before it,
  failed with only the loader's error. It now says which library is not
  built and the command that builds it. It still fails rather than skips:
  a script that will not open is what it is there to catch.
