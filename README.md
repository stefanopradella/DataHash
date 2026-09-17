# DataHash

DataHash is a hashing utility originally developed by Jan Simon.

# Usage

Put `DataHash.m` in the current MATLAB folder or add this repository to the MATLAB path.

```matlab
hash = DataHash(data, method, inputType, outputFormat)
```

The option strings can be supplied in any order, and each is optional. By default, `method` is `MD5`, `inputType` is `array`, and `outputFormat` is lowercase `hex`.

Supported data types for `data` with `array` input:

- `int8`, `int16`, `int32`, `int64`
- `uint8`, `uint16`, `uint32`, `uint64`
- `single`, `double` (real or complex; full or sparse)
- Fixed-point `fi` arrays
- `char`, `logical`
- `cell` arrays, including nested cells
- `struct` scalars and arrays, including nested structs
- Function handles
- Strings

Supported hashing methods:

- `SHA-1`
- `SHA-256`
- `SHA-384`
- `SHA-512`
- `MD2`
- `MD5`

Available methods depend on Java; call `DataHash()` to inspect them.

Supported input types:

- `array`: The input's contents, type, and size are used to create the hash. Nested cell and struct arrays are parsed recursively. Empty arrays of different types produce different hashes.
- `file`: The input is treated as a file name, and the hash is calculated from the file's contents.
- `bin`: Only the array's binary contents are used, so empty arrays of different types produce the same hash. This mode supports nonsparse numeric, logical, or char arrays and scalar strings.
- `ascii`: Converts a char array or scalar string to `uint8`, then hashes its binary contents.

Supported output formats:

- `hex`, `HEX`: Lowercase and uppercase hexadecimal character vectors, respectively.
- `double`: Row vector of digest bytes as doubles.
- `uint8`: Row vector of digest bytes as `uint8` values.
- `base64`: Padded Base64 character vector.
- `short`: Unpadded Base64 character vector.

# Examples

Hash an empty array with the defaults: `MD5`, `array` input, and lowercase hexadecimal output.

```matlab
defaultHash = DataHash([]);
```

An additional option string selects the output format. Here, `short` returns unpadded Base64, while `HEX` returns uppercase hexadecimal for a nested data structure.

```matlab
compactHash = DataHash(int32(1:10), 'MD5', 'short');

payload.a = uint8([]);
payload.b = {{1:10}, struct('q', uint64(415))};
nestedHash = DataHash(payload, 'SHA-1', 'HEX');
```

Use `bin` when the digest should depend on the array's binary contents.

```matlab
binaryHash = DataHash(1:8, 'SHA-1', 'bin');
```

For MATLAB character data, `ascii` hashes its 8-bit values. Converting the same text to `uint8` and using `bin` gives the same SHA-256 digest.

```matlab
asciiHash = DataHash('abc', 'SHA-256', 'ascii');
byteHash = DataHash(uint8('abc'), 'SHA-256', 'bin');
assert(strcmp(asciiHash, byteHash));
```
