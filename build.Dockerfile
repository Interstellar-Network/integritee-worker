# syntax=docker/dockerfile:experimental
# Copyright 2021 Integritee AG
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#           http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This is a multi-stage docker file, where the first stage is used
# for building and the second deploys the built application.

################################################################################
# [interstellar]
# To be able to deploy on an Ubuntu20.04 base image(ie "integritee/integritee-dev:0.1.10")
# We MUST build inside a container[if the local host is eg ubuntu 22.04] else it FAILS with
# 	STEP 10/15: RUN if [[ "x$BINARY_FILE" != "xintegritee-cli" ]] ; then ./integritee init-shard; fi
# 	./integritee: error while loading shared libraries: libssl.so.3: cannot open shared object file: No such file or directory
#
# - cf https://github.com/integritee-network/worker/blob/master/docker/README.md#how-to-run-the-multi-validateer-docker-setup
# - make clean && rm -rf target && rm -rf enclave-runtime/target/
# - mkdir -p target/release && mkdir -p enclave-runtime/target/release
# 	NOTE: "--format docker" else "WARN[0001] SHELL is not supported for OCI image format, [/bin/bash -c] will be ignored. Must use `docker` format"
#	NOTE2: use podman that way we can use --volume at build time and not start from scratch every build
# TODO? --volume ~/.cargo:/root/.cargo:rw but FAIL with below ???
# 	info: installing component 'rustfmt'
# 	error: failed to run `rustc` to learn about target-specific information
# 	Caused by:
#   could not execute process `/usr/local/bin/sccache rustc - --crate-name ___ --print=file-names --crate-type bin --crate-type rlib --crate-type dylib --crate-type cdylib --crate-type staticlib --crate-type proc-macro --print=sysroot --print=cfg` (never executed)
#
# Probably b/c of the "bin" dir built locally using sccache
# Try caching only ~/.cargo/registry/cache cf https://github.com/Swatinem/rust-cache#cache-details
## BUILD the `integritee-service`
# - podman build -f build.Dockerfile -t integritee-worker:dev -t ghcr.io/interstellar-network/integritee_service:dev --format docker --build-arg WORKER_MODE_ARG=sidechain --volume ~/.cargo/registry/cache:/root/work/.cargo/registry/git --volume ~/.cargo/git:/root/work/.cargo/git --volume $(pwd)/target/release:/root/work/worker/target/release:rw --volume $(pwd)/enclave-runtime/target/release:/root/work/worker/enclave-runtime/target/release:rw .
# - CHECK:
#	- podman run --rm -it --name integritee_service_dev ghcr.io/interstellar-network/integritee_service:dev --clean-reset -P 2090 -p 9990 -r 3490 -w 2091 -h 4545 run --skip-ra --dev
#	- podman run --rm -it --name integritee_cli_dev --entrypoint /usr/local/bin/integritee-cli ghcr.io/interstellar-network/integritee_service:dev --help
#
## BUILD the `integritee-cli` (NOTE: it SHOULD be the previous command, only with added "--target deployed-client"; and different tags)
# - podman build --target deployed-client -f build.Dockerfile -t integritee-cli:dev -t ghcr.io/interstellar-network/integritee_cli:dev --format docker --build-arg WORKER_MODE_ARG=sidechain --volume ~/.cargo/registry/cache:/root/work/.cargo/registry/git --volume ~/.cargo/git:/root/work/.cargo/git --volume $(pwd)/target/release:/root/work/worker/target/release:rw --volume $(pwd)/enclave-runtime/target/release:/root/work/worker/enclave-runtime/target/release:rw .
# - CHECK: podman run --rm -it --entrypoint /usr/local/worker-cli/demo_interstellar.sh --env CLIENT_BIN=/usr/local/bin/integritee-cli ghcr.io/interstellar-network/integritee_cli:dev -P 2090 -p 9990 --help
#   NOTE: you should get a "connection refused"; but the executable MUST start!

### Builder Stage
##################################################
FROM integritee/integritee-dev:0.1.10 AS builder
LABEL maintainer="zoltan@integritee.network"

# set environment variables
ENV SGX_SDK /opt/sgxsdk
ENV PATH "$PATH:${SGX_SDK}/bin:${SGX_SDK}/bin/x64:/root/.cargo/bin"
ENV PKG_CONFIG_PATH "${PKG_CONFIG_PATH}:${SGX_SDK}/pkgconfig"
ENV LD_LIBRARY_PATH "${LD_LIBRARY_PATH}:${SGX_SDK}/sdk_libs"
ENV CARGO_NET_GIT_FETCH_WITH_CLI true
ENV SGX_MODE SW

ENV HOME=/root/work

ARG WORKER_MODE_ARG
ENV WORKER_MODE=$WORKER_MODE_ARG

ARG ADDITIONAL_FEATURES_ARG
ENV ADDITIONAL_FEATURES=$ADDITIONAL_FEATURES_ARG

WORKDIR $HOME/worker

# split toolchain install and COPY, that way we wont redownload the toolchain over and over
RUN rustup show

COPY . .

RUN make

RUN cargo test --release


# [interstellar] NOTE: "cached-builder" is NOT used???
### Cached Builder Stage
##################################################
# A builder stage that uses sccache to speed up local builds with docker
# Installation and setup of sccache should be moved to the integritee-dev image, so we don't
# always need to compile and install sccache on CI (where we have no caching so far).
FROM integritee/integritee-dev:0.2.1 AS builder
LABEL maintainer="zoltan@integritee.network"

# set environment variables
ENV SGX_SDK /opt/sgxsdk
ENV PATH "$PATH:${SGX_SDK}/bin:${SGX_SDK}/bin/x64:/opt/rust/bin"
ENV PKG_CONFIG_PATH "${PKG_CONFIG_PATH}:${SGX_SDK}/pkgconfig"
ENV LD_LIBRARY_PATH "${LD_LIBRARY_PATH}:${SGX_SDK}/sdk_libs"
ENV CARGO_NET_GIT_FETCH_WITH_CLI true

# Default SGX MODE is software mode
ARG SGX_MODE=SW
ENV SGX_MODE=$SGX_MODE

ARG SGX_PRODUCTION=0
ENV SGX_PRODUCTION=$SGX_PRODUCTION

ARG WORKER_FEATURES_ARG
ENV WORKER_FEATURES=$WORKER_FEATURES_ARG

ENV WORKHOME=/home/ubuntu/work
ENV HOME=/home/ubuntu

RUN rustup default stable
RUN cargo install sccache

ENV SCCACHE_CACHE_SIZE="20G"
ENV SCCACHE_DIR=$HOME/.cache/sccache
ENV RUSTC_WRAPPER="/opt/rust/bin/sccache"

ARG WORKER_MODE_ARG
ARG ADDITIONAL_FEATURES_ARG
ENV WORKER_MODE=$WORKER_MODE_ARG
ENV ADDITIONAL_FEATURES=$ADDITIONAL_FEATURES_ARG

ARG FINGERPRINT=none

ARG SGX_COMMERCIAL_KEY=enclave-runtime/Enclave_private.pem
ENV SGX_COMMERCIAL_KEY ${SGX_COMMERCIAL_KEY}

ARG SGX_PASSFILE
ENV SGX_PASSFILE ${SGX_PASSFILE}

WORKDIR $WORKHOME/worker

COPY . .

RUN --mount=type=cache,id=cargo-registry,target=/opt/rust/registry \
	--mount=type=cache,id=cargo-git,target=/opt/rust/git/db \
	--mount=type=cache,id=cargo-sccache-${WORKER_MODE}${ADDITIONAL_FEATURES},target=/home/ubuntu/.cache/sccache \
	echo ${FINGERPRINT} && make && make identity && cargo test --release && sccache --show-stats

### Base Runner Stage
### The runner needs the aesmd service for the `SGX_MODE=HW`.
######################################################
FROM oasisprotocol/aesmd:master AS runner
ENV SGX_SDK /opt/sgxsdk
ENV LD_LIBRARY_PATH "${SGX_SDK}/sdk_libs"

### Deployed CLI client
##################################################
FROM runner AS deployed-client
LABEL maintainer="zoltan@integritee.network"

ARG SCRIPT_DIR=/usr/local/worker-cli
ARG LOG_DIR=/usr/local/log

ENV SCRIPT_DIR ${SCRIPT_DIR}
ENV LOG_DIR ${LOG_DIR}

COPY --from=builder /home/ubuntu/work/worker/bin/integritee-cli /usr/local/bin
COPY ./cli/*.sh /usr/local/worker-cli/

RUN chmod +x /usr/local/bin/integritee-cli ${SCRIPT_DIR}/*.sh
RUN mkdir ${LOG_DIR}

RUN ldd /usr/local/bin/integritee-cli && \
	/usr/local/bin/integritee-cli --version

RUN apt-get update && apt-get install -y \
    curl jq \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/local/bin/integritee-cli"]


### Deployed worker service
##################################################
FROM runner AS deployed-worker
LABEL maintainer="zoltan@integritee.network"

WORKDIR /usr/local/bin

COPY --from=builder /opt/sgxsdk /opt/sgxsdk
COPY --from=builder /home/ubuntu/work/worker/bin/* ./
COPY --from=builder /lib/x86_64-linux-gnu/libsgx* /lib/x86_64-linux-gnu/
COPY --from=builder /lib/x86_64-linux-gnu/libdcap* /lib/x86_64-linux-gnu/

# cf core-primitives/enclave-api/build.rs and service/build.rs
# and /gh-actions/install-sgx-sdk/action.yml
# 	echo 'deb [signed-by=/etc/apt/keyrings/intel-sgx-keyring.asc arch=amd64] https://download.01.org/intel-sgx/sgx_repo/ubuntu jammy main' | tee /etc/apt/sources.list.d/intel-sgx.list
# 	wget -O - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | tee /etc/apt/keyrings/intel-sgx-keyring.asc > /dev/null
#  	apt-get update && sudo apt-get install -y libsgx-dcap-ql
# NOTE: libsgx_dcap_ql.so already exist; no need to overwrite
#	ln -sf $(find /usr/lib -type f -name "*sgx_dcap_ql*") /usr/lib/x86_64-linux-gnu/libsgx_dcap_ql.so
RUN find /usr/lib -type f -name "*sgx_dcap_quoteverify*" && \
	ln -sf $(find /usr/lib -type f -name "*sgx_dcap_quoteverify*") /usr/lib/x86_64-linux-gnu/libsgx_dcap_quoteverify.so

RUN touch spid.txt key.txt
RUN chmod +x /usr/local/bin/integritee-service
RUN ls -al /usr/local/bin

# checks
ENV SGX_SDK /opt/sgxsdk
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$SGX_SDK/sdk_libs
RUN ldd /usr/local/bin/integritee-service && \
	/usr/local/bin/integritee-service --version

ENTRYPOINT ["/usr/local/bin/integritee-service"]
