FROM golang:1.24.5 AS build
WORKDIR /app
ARG appVersion=""

# Copy go mod files first for better caching
COPY go.mod go.sum ./
# Download dependencies - this layer will be cached unless go.mod/go.sum change
RUN go mod download

# Copy the source code after downloading dependencies
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-X 'github.com/jkaninda/mysql-bkup/utils.Version=${appVersion}'" -o /app/mysql-bkup

FROM alpine:3.22.0
ENV TZ=UTC
ARG WORKDIR="/config"
ARG BACKUPDIR="/backup"
ARG BACKUP_TMP_DIR="/backup"
ARG TEMPLATES_DIR="/config/templates"
ARG appVersion=""
ENV VERSION=${appVersion}
LABEL org.opencontainers.image.title="mysql-bkup"
LABEL org.opencontainers.image.description="A lightweight MySQL backup and restore tool"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="Jonas Kaninda <me@jonaskaninda.com>"
LABEL org.opencontainers.image.version=${appVersion}
LABEL org.opencontainers.image.source="https://github.com/jkaninda/mysql-bkup"

RUN apk --update add --no-cache mysql-client mariadb-connector-c tzdata ca-certificates
RUN mkdir -p $WORKDIR $BACKUPDIR $TEMPLATES_DIR $BACKUP_TMP_DIR && \
     chmod a+rw $WORKDIR $BACKUPDIR $BACKUP_TMP_DIR
COPY --from=build /app/mysql-bkup /usr/local/bin/mysql-bkup
COPY ./templates/* $TEMPLATES_DIR/
RUN chmod +x /usr/local/bin/mysql-bkup && \
    ln -s /usr/local/bin/mysql-bkup /usr/local/bin/bkup

# Create backup script and make it executable
RUN printf '#!/bin/sh\n/usr/local/bin/mysql-bkup backup "$@"' > /usr/local/bin/backup && \
    chmod +x /usr/local/bin/backup
# Create restore script and make it executable
RUN printf '#!/bin/sh\n/usr/local/bin/mysql-bkup restore "$@"' > /usr/local/bin/restore && \
    chmod +x /usr/local/bin/restore
# Create migrate script and make it executable
RUN printf '#!/bin/sh\n/usr/local/bin/mysql-bkup migrate "$@"' > /usr/local/bin/migrate && \
    chmod +x /usr/local/bin/migrate

WORKDIR $WORKDIR
ENTRYPOINT ["/usr/local/bin/mysql-bkup"]
