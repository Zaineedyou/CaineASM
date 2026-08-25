FROM debian:bookworm-slim AS build
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential nasm pkg-config libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Makefile ./
COPY src ./src
COPY adapter ./adapter
RUN make all

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libcurl4 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --create-home caine
WORKDIR /app
COPY --from=build /app/build/caine-asm /usr/local/bin/caine-asm
USER caine
ENTRYPOINT ["/usr/local/bin/caine-asm"]
