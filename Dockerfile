# syntax=docker/dockerfile:1

FROM docker:29.10.0-cli-alpine3.24 AS docker-cli

FROM jenkins/inbound-agent:3391.va_37fa_a_305d6d-6-alpine-jdk25

USER root
RUN apk add --no-cache procps flock zip

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins

USER jenkins

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["pgrep", "-f", "agent.jar"]
