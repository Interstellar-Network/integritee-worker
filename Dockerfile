################################################################################
# [interstellar]
# NOTE: this is NOT compiling; "make" MUST have been run beforehand!

# 2 containers to build:
# - one with bin/integritee-service:
# 	podman build --format docker -f Dockerfile -t ghcr.io/interstellar-network/integritee_service:dev .
# 	to publish:
# 	podman tag ghcr.io/interstellar-network/integritee_service:dev ghcr.io/interstellar-network/integritee_service:vXXX
# 	podman push ghcr.io/interstellar-network/integritee_service:vXXX
# - TODO? one with bin/integritee-cli:
# 	podman build --format docker -f Dockerfile --build-arg=BINARY_FILE=integritee-cli -t ghcr.io/interstellar-network/integritee_cli:dev .
#  	to publish:
# 	podman tag ghcr.io/interstellar-network/integritee_cli:dev ghcr.io/interstellar-network/integritee_cli:vXXX
# 	podman push ghcr.io/interstellar-network/integritee_cli:vXXX
# TODO? how to package cli/demo_interstellar.sh; do we even need it? we can probably just bash -c $(curl github.com/XXX/)

################################################################################

FROM integritee/integritee-dev:0.1.9
LABEL maintainer="zoltan@integritee.network"

# By default we warp the service
ARG BINARY_FILE=integritee-service

COPY bin/enclave.signed.so bin/end.rsa bin/end.fullchain /usr/local/bin/
COPY bin/${BINARY_FILE} /usr/local/bin/integritee

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
