zdns is a Zig wrapper around [ldns](http://www.nlnetlabs.nl/ldns/).

Only part of the API is currently wrapped, but it is enough for reading a zone file.

## Setup
1. Install `libldns`.
2. Add the following to your `build.zig` (you may need to adjust the path):
    ```zig
    step.linkLibC();
    step.linkSystemLibrary("ldns");
    step.addPackagePath("zdns", "../zdns/src/zdns.zig");
    ```
3. Import with `@import("zdns")`.
