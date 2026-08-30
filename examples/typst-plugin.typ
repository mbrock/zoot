#let zoot = plugin("/zig-out/bin/zoot-typst.wasm")
#let value = (
  project: "zoot",
  version: 3,
  enabled: true,
  owners: ("compiler-team", "docs-team", "release-engineering"),
  formatting: (
    evaluator: "recursive",
    input: "CBOR",
    output: "pretty JSON",
    preferred_width: 80,
    fallback_widths: (40, 60, 100, 120),
    preserve_unicode: true,
  ),
  environments: (
    development: (
      region: "eu-north-1",
      replicas: 1,
      debug_symbols: true,
      endpoint: "https://dev.example.invalid/api/v2/format",
    ),
    staging: (
      region: "eu-central-1",
      replicas: 2,
      debug_symbols: false,
      endpoint: "https://staging.example.invalid/api/v2/format",
    ),
    production: (
      region: "us-west-2",
      replicas: 6,
      debug_symbols: false,
      endpoint: "https://format.example.invalid/api/v2/format",
    ),
  ),
  pipelines: (
    (
      name: "build-and-test",
      triggers: ("push", "pull-request"),
      timeout_seconds: 900,
      steps: (
        (name: "compile", command: "zig build -Doptimize=ReleaseSafe"),
        (name: "unit-tests", command: "zig build test"),
        (name: "wasm", command: "zig build wasm -Doptimize=ReleaseSmall"),
      ),
    ),
    (
      name: "publish",
      triggers: ("version-tag",),
      timeout_seconds: 1800,
      steps: (
        (name: "profile", command: "make profile"),
        (name: "typst-example", command: "make typst-example"),
        (name: "upload", command: "release-tool upload zig-out/bin"),
      ),
    ),
  ),
  limits: (
    input_bytes: 1048576,
    nesting_depth: 128,
    finite_floats_only: true,
    map_keys: "UTF-8 strings",
  ),
  metadata: (
    license: "MIT",
    repository: "https://github.com/mbrock/zoot",
    keywords: ("pretty-printing", "zig", "webassembly", "typst", "cbor"),
    notes: "This deliberately long value exercises nested arrays, objects, strings, booleans, and integers.",
  ),
)
#let formatted = str(zoot.format_cbor(cbor.encode(value)))

// Make compilation itself verify that the plugin preserved the data.
#assert.eq(json(bytes(formatted)), value)

= Zoot as a Typst plugin

The value below was encoded as CBOR by Typst and formatted as JSON by Zoot's
recursive evaluator running inside Typst's WebAssembly plugin sandbox.

#raw(formatted, lang: "json", block: true)
