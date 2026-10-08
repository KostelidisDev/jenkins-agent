# syntax=docker/dockerfile:1

ARG INBOUND_AGENT_TAG=3391.va_37fa_a_305d6d-4-alpine-jdk25
ARG DOCKER_CLI_TAG=29.8.2-cli-alpine3.24

FROM docker:${DOCKER_CLI_TAG} AS docker-cli

FROM jenkins/inbound-agent:${INBOUND_AGENT_TAG}

USER root
RUN apk add --no-cache procps flock zip

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins

USER jenkins

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["pgrep", "-f", "agent.jar"]
