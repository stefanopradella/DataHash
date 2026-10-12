# DataHash

DataHash is a hashing utility originally developed by Jan Simon.

# Usage

Put `DataHash.m` in the current MATLAB folder or add this repository to the MATLAB path.

```matlab
hash = DataHash(data, method, inputType, outputFormat)
```

Options must be supplied in the order shown, as character vectors or scalar strings. Only trailing arguments can be omitted. By default, `method` is `MD5`, `inputType` is `array`, and `outputFormat` is lowercase `hex`. To select an output format, supply the method and input type too. Legacy options structures are no longer accepted.

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

Call `DataHash()` to inspect the available methods.

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

The fourth argument selects the output format. Here, `short` returns unpadded Base64, while `HEX` returns uppercase hexadecimal for a nested data structure.

```matlab
compactHash = DataHash(int32(1:10), 'MD5', 'array', 'short');

payload.a = uint8([]);
payload.b = {{1:10}, struct('q', uint64(415))};
nestedHash = DataHash(payload, 'SHA-1', 'array', 'HEX');
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

# Development Philosophy

DataHash is designed as a single, portable function with no dependencies beyond MATLAB itself.
Starting with version 1.9.0, DataHash requires MATLAB R2019b or later and has no JRE dependency, allowing it to run in a default MATLAB R2026b installation, where Java is no longer included by default.

Release packages for version 1.9.0 and later also provide the optional `DataHashCore` MEX accelerator. It accelerates only the hashing core, while argument parsing and serialization remain in MATLAB. If a compatible MEX binary is unavailable, DataHash uses its native MATLAB implementation, preserving the portable single-file workflow without making platform-specific binaries mandatory.

For older MATLAB releases, use v1.8.0, which requires Java and was tested on MATLAB R2009a, R2015b, R2016b, and R2018b.

# Tests

Run the correctness suites from the repository root:

```matlab
results = runtests('tests');
assertSuccess(results);
```

The classes add the source folders temporarily and restore the MATLAB path when they finish. `DataHashLegacyCompatibilityTest` contains frozen compatibility checks for DataHash v1.8.0. `DataHashTest` contains current-interface checks and additional regression coverage; add new tests to this class. Both suites run without Java. Fixed-point cases require Fixed-Point Designer and report skips when it is unavailable. Performance tests remain separate under `tests/performance`.

See [tests/README.md](tests/README.md) for suite coverage, reference versions, and compatibility limits.
