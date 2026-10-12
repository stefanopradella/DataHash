# Correctness suites

These classes use `matlab.unittest.TestCase` and MATLAB R2019b-compatible syntax and APIs. They require no Java, MATLAB Test add-on, Python, or MEX accelerator. Fixed-point cases additionally require installed and licensed Fixed-Point Designer support.

Run both classes from the repository root:

```matlab
results = runtests('tests');
assertSuccess(results);
```

Each class uses a path fixture to expose `src` and its algorithm folders, then restores the original path. File tests use temporary folders and close files on every exit path. The command above does not include the separate `tests/performance` folder.

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

Base64 expected strings are calculated from the stored `abc` digest vectors using Python's standard-library Base64 encoder during authoring. Python is not used when running the suite.

The `@sin` vector depends on MATLAB's `functions` metadata, including its defining class. Its expected digest was verified against DataHash v1.8.0 on R2025b. Function-handle metadata can change across MATLAB releases and definition contexts; this case may require verification against the reference version when testing another release.