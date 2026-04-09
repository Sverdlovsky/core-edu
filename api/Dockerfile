FROM docker.io/library/rust:1.94.0-alpine3.23 AS build

WORKDIR /srv/api

COPY api/Cargo.lock .
COPY api/Cargo.toml .
COPY api/src .

RUN cargo build --release



FROM docker.io/library/alpine:3.23

COPY --from=build /srv/api/target/release/coredu /usr/bin/coredu

RUN addgroup -g 31541 user
RUN adduser -DH -u 31541 user
USER user

EXPOSE 8080

ENTRYPOINT [ "/usr/bin/coredu" ]

