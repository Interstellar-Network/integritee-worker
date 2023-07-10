################################################################################
# [interstellar]
# DEPRECATED: not used by https://github.com/integritee-network/worker ??
# And internally we CAN NOT compile outside container on Ubuntu 22.04 and deploy in SGX container
# based on Ubuntu 20.04 b/c of libssl versions.
#
# NOTE: this is NOT compiling; "make" MUST have been run beforehand!

# 2 containers to build:
# - one with bin/integritee-service:
# 	podman build --format docker -f Dockerfile -t ghcr.io/interstellar-network/integritee_service:dev .
# 	to publish:
# 	podman tag ghcr.io/interstellar-network/integritee_service:dev ghcr.io/interstellar-network/integritee_service:vXXX
# 	podman push ghcr.io/interstellar-network/integritee_service:vXXX
# - one with bin/integritee-cli:
# 	podman build --format docker -f Dockerfile --build-arg=BINARY_FILE=integritee-cli -t ghcr.io/interstellar-network/integritee_cli:dev .
#  	to publish:
# 	podman tag ghcr.io/interstellar-network/integritee_cli:dev ghcr.io/interstellar-network/integritee_cli:vXXX
# 	podman push ghcr.io/interstellar-network/integritee_cli:vXXX
# TODO? how to package cli/demo_interstellar.sh; do we even need it? we can probably just bash -c $(curl github.com/XXX/)

################################################################################

FROM integritee/integritee-dev:0.1.13
LABEL maintainer="zoltan@integritee.network"

# By default we warp the service
ARG BINARY_FILE=integritee-service

COPY bin/enclave.signed.so /usr/local/bin/
COPY bin/${BINARY_FILE} /usr/local/bin/integritee

# [interstellar] This is needed when using docker-compose b/c apparently integritee-service DOES NOT retry in case of timeout/node not yet ready
# (and docker-compose starts a container as soon as the previous one is started, without any service healthcheck/readiness)
COPY --from=powerman/dockerize /usr/local/bin/dockerize /usr/local/bin/dockerize

RUN chmod +x /usr/local/bin/integritee

WORKDIR /usr/local/bin
RUN touch spid.txt key.txt
RUN if [[ "x$BINARY_FILE" != "xintegritee-cli" ]] ; then ./integritee init-shard; fi
RUN if [[ "x$BINARY_FILE" != "xintegritee-cli" ]] ; then ./integritee shielding-key; fi
RUN if [[ "x$BINARY_FILE" != "xintegritee-cli" ]] ; then ./integritee signing-key; fi
RUN if [[ "x$BINARY_FILE" != "xintegritee-cli" ]] ; then ./integritee mrenclave > ~/mrenclave.b58; fi

# checks
RUN ldd /usr/local/bin/integritee && \
	/usr/local/bin/integritee --version

ENTRYPOINT ["/usr/local/bin/integritee"]
