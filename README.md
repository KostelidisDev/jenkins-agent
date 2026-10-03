# jenkins-agent

A Jenkins inbound (WebSocket) agent image with the Docker CLI baked in, plus a Compose file to run it next to — or away from — a Jenkins controller.

Builds on the agent can run `docker` and `docker compose` / `docker buildx` against the host's Docker daemon through the mounted socket.

## What's in the image

- Base: [`jenkins/inbound-agent`](https://hub.docker.com/r/jenkins/inbound-agent) (Alpine, JDK 25)
- Docker CLI and its plugins (compose, buildx), copied from the official `docker:*-cli` image
- `procps` and `flock`
- A health check that looks for the running `agent.jar` process

Images are published to `ghcr.io/kostelidisdev/jenkins-agent` for `linux/amd64` and `linux/arm64`.

## Quick start

1. In Jenkins, create the node: **Manage Jenkins → Nodes → New Node**, set the launch method to *Launch agent by connecting it to the controller*. Open the node page and copy the secret from the launch command.

2. Configure the agent:

   ```sh
   cp .env.example .env
   ```

   At minimum, set `JENKINS_SECRET`, `JENKINS_AGENT_NAME` (must match the node name in Jenkins), `JENKINS_URL` and `DOCKER_GID`.

   Get the host's docker group ID with:

   ```sh
   stat -c %g /var/run/docker.sock
   ```

3. Start it:

   ```sh
   docker compose up -d
   docker compose logs -f
   ```

   The node should show as connected in Jenkins within a few seconds.

## Configuration

All settings are read from `.env`.

| Variable | Default | Description |
| --- | --- | --- |
| `JENKINS_SECRET` | — (required) | Agent secret from the node's page in Jenkins |
| `JENKINS_URL` | `http://jenkins:8080` | Controller URL as seen from the agent container |
| `JENKINS_AGENT_NAME` | `amd64` | Node name; must match Jenkins |
| `JENKINS_AGENT_WORKDIR` | `/home/jenkins/agent` | Agent work directory |
| `DOCKER_GID` | `984` | Host GID owning `/var/run/docker.sock` |
| `JENKINS_NETWORK_EXTERNAL` | `true` | See [Networking](#networking) |
| `DOCKER_REGISTRY` | `ghcr.io` | Image registry |
| `DOCKER_PUBLISHER` | `kostelidisdev` | Image namespace |
| `DOCKER_TAG` | `main` | Image tag; see [Image tags](#image-tags) |
| `TZ` | `Europe/Athens` | Container time zone |
| `JENKINS_AGENT_CPU_LIMIT` | `2` | CPU limit |
| `JENKINS_AGENT_MEMORY_LIMIT` | `2G` | Memory limit |
| `JENKINS_AGENT_MEMORY_RESERVATION` | `512M` | Memory reservation |
| `JENKINS_AGENT_PIDS_LIMIT` | `4096` | Process limit |

Size the resource limits for your heaviest build. Containers that builds start through the Docker socket are siblings on the host, so these limits don't apply to them.

### Networking

The agent attaches to a Docker network named `jenkins`.

- **Same host as the controller** (`JENKINS_NETWORK_EXTERNAL=true`): the agent joins the network the Jenkins stack already created, and can reach the controller at `http://jenkins:8080`.
- **Separate host** (`JENKINS_NETWORK_EXTERNAL=false`): Compose creates the network locally. Set `JENKINS_URL` to the controller's public address.

The agent connects over WebSocket, so only the controller's HTTP(S) port needs to be reachable; the TCP agent port is not used.

### Volumes

| Volume | Mounted at | Purpose |
| --- | --- | --- |
| `jenkins-agent_agent` | `/home/jenkins/agent` | Workspaces |
| `jenkins-agent_jenkins` | `/home/jenkins/.jenkins` | Remoting cache |

## Image tags

| Tag | When it's built | Use for |
| --- | --- | --- |
| `main`, `latest` | Every push to `main` | Testing only — moves |
| `X.Y.Z`, `X.Y` | Pushing a `vX.Y.Z` git tag | Production |
| `sha-<commit>` | Every push | Pinning to an exact commit |
| `YYYYMMDD` | Weekly rebuild (Sundays) to pick up base image updates | Pinning a patched rebuild |
| `pr-<n>` | Pull requests (built, not pushed) | — |

For production, set `DOCKER_TAG` to an immutable tag rather than `main`.

## Building locally

```sh
docker build -t jenkins-agent .
```

Base image versions can be overridden with build args:

```sh
docker build \
  --build-arg INBOUND_AGENT_TAG=<tag> \
  --build-arg DOCKER_CLI_TAG=<tag> \
  -t jenkins-agent .
```

## Security

Mounting `/var/run/docker.sock` gives the agent — and every job it runs — root-equivalent access to the host. Only run trusted pipelines on this agent, and don't share the host with workloads that need isolation from them.

The container runs as the `jenkins` user with `no-new-privileges` set.
