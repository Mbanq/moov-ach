ARG MOOV_WIRE_VERSION=

FROM moov/wire:${MOOV_WIRE_VERSION:-latest}

LABEL maintainer="Mbanq dev@mbanq.com"
