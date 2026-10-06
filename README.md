# datumctl-container

[![ci](https://github.com/dlotterman/datumctl-container/actions/workflows/ci.yml/badge.svg)](https://github.com/dlotterman/datumctl-container/actions/workflows/ci.yml)
[![build](https://github.com/dlotterman/datumctl-container/actions/workflows/build.yml/badge.svg)](https://github.com/dlotterman/datumctl-container/actions/workflows/build.yml)

[`datumctl`](https://github.com/datum-cloud/datumctl) plus the Datum Cloud plugins (`alb`, `assistant`, `compute`, `dns`, `ipam`, `search`, `connect`) in one image. It's rebuilt automatically when upstream releases change.

Image: [`dlotterman/datumctl-container`](https://hub.docker.com/r/dlotterman/datumctl-container) on Docker Hub.

Examples use [Podman](https://podman.io/). Docker works the same; just swap the command.

## Quick start

Pull the image and check it:

```sh
podman pull docker.io/dlotterman/datumctl-container:latest
podman run --rm docker.io/dlotterman/datumctl-container:latest version --client
podman run --rm docker.io/dlotterman/datumctl-container:latest plugin list
```

You should see all seven plugins.

The entrypoint is `datumctl`, so arguments go straight to it:

```sh
podman run --rm docker.io/dlotterman/datumctl-container:latest --help
```

For a shell instead:

```sh
podman run -it --rm --entrypoint /bin/bash docker.io/dlotterman/datumctl-container:latest
```

## Logging in

There's no browser in the container, so log in with:

```sh
datumctl login --no-browser
```

Login state lives in `/root/.datumctl` and disappears when a `--rm` container exits. To keep it, use a named volume:

```sh
podman run -it --rm -v datumctl-config:/root/.datumctl \
  --entrypoint /bin/bash docker.io/dlotterman/datumctl-container:latest
```

### Sharing your host's login

To reuse the credentials from your host, mount just the two files. Mounting the whole folder would hide the plugins that ship in the image.

```sh
mkdir -p ~/.datumctl
touch ~/.datumctl/config ~/.datumctl/credentials.json
podman run -it --rm \
  -v ~/.datumctl/config:/root/.datumctl/config:Z \
  -v ~/.datumctl/credentials.json:/root/.datumctl/credentials.json:Z \
  --entrypoint /bin/bash docker.io/dlotterman/datumctl-container:latest
```

- Create the files first, or Podman will make them directories.
- `credentials.json` holds your login tokens. Treat it like a password and never commit it.
- `:Z` is for SELinux (Fedora, RHEL). Drop it elsewhere.

## Building unikernel images

[`datumctl compute build`](https://www.datum.net/docs/compute/unikernels) needs a BuildKit server. The image has no Docker CLI or daemon, so run BuildKit in its own container on a shared network (it connects via `BUILDKIT_HOST`, default `tcp://buildkitd:1234`):

```sh
podman network create datum-build
podman run -d --name buildkitd --network datum-build --privileged \
  docker.io/moby/buildkit:latest --addr tcp://0.0.0.0:1234
```

Then build from a directory containing your `Dockerfile` (or `Dockerfile.datum`):

```sh
podman run --rm --network datum-build -v "$PWD":/work:Z -w /work \
  docker.io/dlotterman/datumctl-container:latest compute build .
```

Add `--output ./image.tar` to write an OCI archive. Pushing with `--push` is untested here. When you're done:

```sh
podman rm -f buildkitd && podman network rm datum-build
```

## Building the image yourself

```sh
git clone https://github.com/dlotterman/datumctl-container.git
cd datumctl-container
podman build -t localhost/datumctl:latest .
```

Use `--no-cache` to pick up new upstream releases, or `--build-arg DATUMCTL_VERSION=v1.2.3` to pin a `datumctl` version.
