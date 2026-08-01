# Execution server contract tests

This suite characterizes the execution server exclusively through its HTTP API. It does not
import server code, inspect server files, or start a particular implementation.

The target must provide the current `College Football 2025` dataset and be listening before the
tests start. From this repository, start the current implementation with `nix run ..#python-server`
while the working directory is `python-server/`.

Run the TypeScript suite from this directory with Node.js 22 or newer. The HTTP driver, request
sequencing, failure channel, and cleanup are implemented with Effect:

```sh
npm ci
npm run check
npm test
```

Without Node.js installed globally, run it from the repository root through Nix:

```sh
nix shell nixpkgs#nodejs_22 -c npm --prefix server-contract-tests ci
nix shell nixpkgs#nodejs_22 -c npm --prefix server-contract-tests test
```

Set `DATALK_SERVER_URL` to test another implementation or address:

```sh
DATALK_SERVER_URL=http://127.0.0.1:9000 npm test
```

The two-minute execution-timeout test is skipped by default. Enable it explicitly with
`RUN_SLOW_CONTRACT_TESTS=1`.

Tests use unique chat IDs, run serially, and destroy environments through the public API. The
checked-in response strings are intentional compatibility expectations, including current error
and formatting quirks.

The driver closes each HTTP connection to remain reliable through port forwarding. Dataset reads
and environment lifecycle requests are retried once after transport failures because they are
idempotent; code execution is never retried.
