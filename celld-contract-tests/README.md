# celld storage contract tests

This suite verifies the S3 behavior celld needs from its authoritative storage backend. It uses
AWS Signature V4, path-style requests, and the same conditional `PUT` operations celld uses for
ownership and replication coordination.

The target must provide atomic conditional writes. The suite checks:

- `If-None-Match: *` create and duplicate rejection;
- ETag stability across `PUT`, `HEAD`, and `GET`;
- `If-Match` update and stale-update rejection;
- concurrent conditional-create and conditional-update serialization;
- user metadata and prefix listing.

Run it only against a disposable bucket or a bucket reserved for this contract suite. It writes
under a unique `celld-contract/` prefix and does not delete objects so failures remain inspectable.

## Local SeaweedFS

The suite passed against `chrislusf/seaweedfs:4.41` on 2026-08-09. It failed against `3.97`:
multiple concurrent `If-None-Match: *` creates succeeded. Do not use an untested or floating image
tag for celld state.

Start the pinned local gateway with Podman:

```sh
podman run --detach --rm --name datalk-seaweedfs-contract \
  --publish 127.0.0.1:8333:8333 \
  chrislusf/seaweedfs:4.41 server \
  -filer -s3 -ip=127.0.0.1 -ip.bind=0.0.0.0 \
  -master.port.grpc=19333 -filer.port.grpc=18888 -volume.port.grpc=18080 \
  -s3.port=8333 -dir=/data
```

Wait until the S3 gateway starts, then run the suite. Stop the disposable gateway when finished:

```sh
podman rm --force datalk-seaweedfs-contract
```

```sh
npm ci
CELLD_S3_ENDPOINT=http://127.0.0.1:8333 \
CELLD_S3_BUCKET=celld-contract-tests \
AWS_ACCESS_KEY_ID=celld-contract-test \
AWS_SECRET_ACCESS_KEY=celld-contract-test \
npm test
```

The test skips when `CELLD_S3_ENDPOINT` and `CELLD_S3_BUCKET` are both absent. Supplying only one
is a configuration error; supply both before relying on SeaweedFS for celld state.

Use Node.js 22 or newer. Through Nix from the repository root:

```sh
nix shell nixpkgs#nodejs_22 -c npm --prefix celld-contract-tests ci
nix shell nixpkgs#nodejs_22 -c npm --prefix celld-contract-tests test
```
