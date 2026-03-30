FROM debian:bookworm AS builder

RUN apt update \
    && apt install -y --no-install-recommends curl wget ca-certificates build-essential \
    && mkdir -p /etc/apt/keyrings \
    && wget -qO- https://binaries2.erlang-solutions.com/GPG-KEY-pmanager.asc | tee /etc/apt/keyrings/erlang.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/erlang.asc] https://binaries2.erlang-solutions.com/debian bookworm-esl-erlang-27 contrib" | tee /etc/apt/sources.list.d/erlang.list \
    && apt update \
    && apt install -y esl-erlang

ENV GLEAM_VERSION=1.15.2

RUN <<EOT
    curl -OL https://github.com/gleam-lang/gleam/releases/download/v${GLEAM_VERSION}/gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz
    tar -xzf gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz
    rm gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz
    mv gleam /usr/local/bin/
EOT

RUN <<EOT
    sh -c "$(curl -OL https://s3.amazonaws.com/rebar3/rebar3)"
    chmod +x rebar3
    mv rebar3 /usr/local/bin/
EOT

ADD . /app
WORKDIR /app
RUN gleam export erlang-shipment

# ------------------------------------------------------- #

FROM debian:bookworm-slim AS runner

RUN apt update \
    && apt install -y --no-install-recommends wget ca-certificates sqlite3 \
    && mkdir -p /etc/apt/keyrings \
    && wget -qO- https://binaries2.erlang-solutions.com/GPG-KEY-pmanager.asc | tee /etc/apt/keyrings/erlang.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/erlang.asc] https://binaries2.erlang-solutions.com/debian bookworm-esl-erlang-27 contrib" | tee /etc/apt/sources.list.d/erlang.list \
    && apt update \
    && apt install -y --no-install-recommends esl-erlang \
    && apt clean \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/build/erlang-shipment /app
ADD ./init_sqlite_db.sh ./schema.sql /app/

RUN chmod +x /app/entrypoint.sh /app/init_sqlite_db.sh

WORKDIR /app

CMD ["/bin/sh", "-c", "/app/init_sqlite_db.sh && /app/entrypoint.sh run"]