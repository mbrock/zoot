# CBOR-to-JSON WebAssembly module

Build the module with:

```sh
zig build wasm -Doptimize=ReleaseSmall
```

The result is `zig-out/bin/zoot-cbor.wasm`. It exports its memory and four
functions:

```text
zoot_alloc(length: u32) -> pointer: u32
zoot_format_cbor(pointer: u32, length: u32) -> packed_result: u64
zoot_last_error() -> u32
zoot_free(pointer: u32, length: u32)
```

`zoot_format_cbor` returns the output pointer in the low 32 bits and its byte
length in the high 32 bits. It returns zero on failure; error 1 means invalid
or unsupported CBOR and error 2 means allocation failure. Both the input and
output buffers should be released with `zoot_free`.

```js
const { instance } = await WebAssembly.instantiate(wasmBytes);
const z = instance.exports;
const input = new Uint8Array(cborBytes);
const inputPtr = z.zoot_alloc(input.length);
new Uint8Array(z.memory.buffer, inputPtr, input.length).set(input);

const packed = z.zoot_format_cbor(inputPtr, input.length);
if (packed === 0n) throw new Error(`zoot error ${z.zoot_last_error()}`);
const outputPtr = Number(packed & 0xffffffffn);
const outputLen = Number(packed >> 32n);
const json = new TextDecoder().decode(
  new Uint8Array(z.memory.buffer, outputPtr, outputLen),
);

z.zoot_free(inputPtr, input.length);
z.zoot_free(outputPtr, outputLen);
```

Maps require text-string keys because JSON object keys are strings. CBOR byte
strings are represented as arrays of byte values. Tags are ignored while their
contained values are formatted. Non-finite floating-point values and
indefinite-length text or byte strings are rejected.

## Typst plugin

The separate `zoot-typst.wasm` artifact implements Typst's minimal plugin
protocol. Build the plugin and its example PDF with:

```sh
make typst-example
```

The example in `examples/typst-plugin.typ` uses `cbor.encode` to pass a Typst
dictionary to the plugin, checks that the returned JSON decodes to the original
value, and displays Zoot's formatted result as a JSON code block.
