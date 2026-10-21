# Correctness suites

These classes use `matlab.unittest.TestCase` and MATLAB R2019b-compatible syntax and APIs. They require no Java, MATLAB Test add-on, Python, or MEX accelerator. Fixed-point cases additionally require installed and licensed Fixed-Point Designer support.

Run both classes, including the larger file streaming cases, from the repository root:

```matlab
results = runtests('tests');
assertSuccess(results);
```

To exercise the optional accelerator throughout the suites, run
`buildDataHashMex()` and add `release/` to the MATLAB path first. Accelerator
checks also locate the default binary in `release/` temporarily.

Each class uses a path fixture to expose `src` and its algorithm folders, then restores the original path. File tests use temporary folders and close files on every exit path. The command above does not include the separate `tests/performance` folder.

The 24 streaming cases are tagged `FileStreaming` and can take several minutes with the native backends. For a quick correctness run that excludes only those cases:

```matlab
suite = testsuite('tests');
suite = suite.selectIf(~matlab.unittest.selectors.HasTag('FileStreaming'));
results = run(suite);
assert(~any([results.Failed]));
```

Run the streaming cases separately with:

```matlab
results = runtests('tests/DataHashTest.m', 'Tag', 'FileStreaming');
assert(all([results.Passed]));
```

# Validation without a JVM

Run `runDataHashNoJvm.m` in a fresh process for each MATLAB release:

```sh
matlab -nojvm -batch "run('/path/to/datahash/tests/runDataHashNoJvm.m')"
```

Use the script's absolute path because MATLAB startup code can change the current folder. The runner reuses both maintained suites, verifies source and generated-file resolution, and checks essential stored vectors with source helpers absent from the path. It builds in a temporary folder, reports pass/fail/optional-skip counts, and checks path, folder, RNG, and file-handle cleanup.

For an installation without a usable Java runtime, omit `-nojvm` from the command above. If `usejava('jvm')` initially reports true, the runner attempts to construct a Java string to trigger runtime initialization, then requires `usejava('jvm')` to be false before any DataHash checks. It prints the initialization error and both JVM flags. A functioning JVM causes the runner to stop and request `-nojvm`.

# Frozen compatibility suite

`DataHashLegacyCompatibilityTest.m` checks compatibility with DataHash v1.8.0. Preserve its inputs, expected results, seed, case count, and comparisons. Put subsequent features, regressions, and additional vectors in `DataHashTest.m`.

| Coverage | Test methods |
| --- | --- |
| Known answers for numeric, char, string, cell, struct, and sparse inputs | `knownAnswer` |
| Five file inputs and equivalence with ASCII or binary memory input | `fileHash` |
| 1,000 random inputs checked across six output formats, including exact bytes, class, row shape, casing, and padding | `outputTypes` |
| Equivalent binary character and byte inputs | `charBinaryCompatibility` |
| Nine fixed-point known-answer vectors | `fixedPointKnownAnswer` |
| Fixed-point stored-integer and wide-word hexadecimal payload equivalence | `fixedPointStoredIntegerBinary`, `wideFixedPointHexBinary` |
| Distinct hashes for empty fixed-point types | `emptyFixedPointTypes` |

Random inputs are byte arrays with lengths 1–100 and values 0–255. A private `RandStream('mt19937ar', 'Seed', 0)` makes the inputs reproducible without changing the session's random-number state. Names such as `seed0Case0123` identify failures; character checks use the exact even-length subset of those inputs.

The test-only Base64 encoder maps byte groups to six-bit indices using the standard alphabet. It is independent of the production `matlab.net.base64encode` call.

Fixed-point data is constructed after an availability assumption, so unavailable support produces explicit incomplete/skipped results.

# Evolving regression suite

`DataHashTest.m` checks digest and serialization known answers, digest block boundaries, file backends, all six output formats, Base64 padding, positional defaults, character-vector/string options, aliases and casing, invalid inputs, missing files, empty binary inputs, array shape, and struct field ordering.

File streaming cases cover `2^20 - 1`, `2^20`, `2^20 + 1`, and `2 * 2^20 + 17` bytes for each algorithm. For zero-based byte offset `i`, the payload is `mod(37*i + floor(i/251) + 17, 256)`, so successive read chunks have different contents. Each case checks the file digest and binary memory digest against a stored independent answer and against each other.

The streaming answers were obtained with Java 25.0.4.1 `MessageDigest` using the SUN provider. Python 3.14.4 `hashlib` independently agreed with all MD5 and SHA answers. Both tools were used only during authoring; the tests need neither at runtime.

File-handle checks cover successful hashing, missing-file errors, and both read failure paths for all six algorithms. Temporary path fixtures shadow `fread` to throw an exception or `ferror` to report an I/O error after a real file has been opened. Fixtures restore the path and warning state; teardown closes any newly leaked handles after reporting a failed assertion, preserving handles that were already open.

Base64 expected strings are calculated from the stored `abc` digest vectors using Python's standard-library Base64 encoder during authoring. Python is not used when running the suite.

The `@sin` vector depends on MATLAB's `functions` metadata, including its defining class. Its two expected digests were verified against DataHash v1.8.0 in the same class context on R2019b and R2025b. The test selects the stored expectation using the built-in handle's file metadata, which differs between those releases. Other metadata changes still require verification against the reference version.
