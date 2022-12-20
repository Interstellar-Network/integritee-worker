# integritee-worker

Integritee worker for Integritee [node](https://github.com/integritee-network/integritee-node) or [parachain](https://github.com/integritee-network/parachain)

This is part of [Integritee](https://integritee.network)

## Build and Run
~~Please see our [Integritee Book](https://docs.integritee.network/4-development/4.4-sdk) to learn how to build and run this.~~

- install SGX SDK
  - You can find working but (too) specific steps in the [CI](.github/workflows/rust.yml#L170)
  - Or DIY [official guide](https://download.01.org/intel-sgx/sgx-dcap/1.11/linux/docs/Intel_SGX_SW_Installation_Guide_for_Linux.pdf)
- setup needed env vars eg `source /opt/intel/sgxsdk/environment` && `export PATH=/opt/intel/bin:$PATH`
  - NOTE: it MUST match the directory where you installed the SDK
- compile and run the tests: `make && (cd bin/ && touch spid.txt key.txt && ./integritee-service test --all)` and `cargo test --release`
  - NOTE: SGX tests MUST be run with a special exe, **NOT** using `cargo test`
  - IF you get compilation errors like:
  ```
    /home/XXX/.cargo/git/checkouts/incubator-teaclave-sgx-sdk-c63c8825343e87f0/d2d339c/sgx_unwind/../sgx_unwind/libunwind/include/pthread_compat.h:39:10: fatal error: sgx_spinlock.h: No such file or directory
     39 | #include "sgx_spinlock.h"
  ```
  It means the SDK is not properly installed and/or the env vars are not properly set.

**WIP** `PATH=/opt/intel/bin:$PATH make && (cd bin && RUST_LOG=warn RUST_BACKTRACE=1 ./integritee-service --clean-reset -P 2090 -p 9990 -r 3490 -w 2091 -h 4545 run --skip-ra --dev)`

**WIP**  `(cd cli/ && ./demo_interstellar.sh -p 9990 -P 2090)`

T  o start multiple worker and a node with one simple command: Check out [this README](local-setup/README.md).

## Docker
See [docker/README.md](docker/README.md).

## Tests

There are 3 types of tests:
- cargo tests
- enclave tests
- integration tests

### Cargo Tests
Run
```
cargo test
```

### Enclave Tests
Run

```
make
./bin/integritee-service test --all
```

### Integration Tests
See [docker/README.md](docker/README.md)

## Direct calls scalability

For direct calls, a worker runs a web-socket server inside the enclave. An important factor for scalability is the transaction throughput of a single worker instance, which is in part defined by the maximum number of concurrent socket connections possible. On Linux by default, a process can have a maximum of `1024` concurrent file descriptors (show by `ulimit -n`).
If the web-socket server hits that limit, incoming connections will be declined until one of the established connections is closed. Permanently changing the `ulimit -n` value can be done in the `/etc/security/limits.conf` configuration file. See [this](https://linuxhint.com/permanently_set_ulimit_value/) guide for more information.
