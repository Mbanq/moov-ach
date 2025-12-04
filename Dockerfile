ARG MOOV_WIRE_VERSION=

FROM moov/ach:${MOOV_WIRE_VERSION:-latest}

LABEL maintainer="Mbanq dev@mbanq.com"
