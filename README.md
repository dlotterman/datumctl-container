# datumctl-container

A container image with [`datumctl`](https://github.com/datum-cloud/datumctl) and the Datum Cloud plugins preinstalled:
`alb`, `assistant`, `compute`, `dns`, `ipam`, `search`, and `connect` (Datum Connect tunnels).

It is based on the latest Ubuntu release and installs the latest `datumctl` release, with checksums verified.

## Build

You need [Podman](https://podman.io/) (Docker works too; swap `podman` for `docker`) and an internet connection.

1. Clone this repository and change into it:

   ```sh
   git clone <this-repo-url>
   cd datumctl-container
   ```

2. Build the image and tag it `latest`:

   ```sh
   podman build -t localhost/datumctl:latest .
   ```

3. Check that it worked:

   ```sh
   podman run --rm localhost/datumctl:latest version
   podman run --rm localhost/datumctl:latest plugin list
   ```

   You should see all seven plugins listed, including `connect`.

### Pin a specific datumctl version

By default the build uses the newest release. To use a particular one, pass its tag:

```sh
podman build -t localhost/datumctl:latest --build-arg DATUMCTL_VERSION=v1.2.3 .
```

### Rebuilding

Rebuild with `--no-cache` to pick up new releases of `datumctl` and the plugins, since cached layers would otherwise be reused:

```sh
podman build --no-cache -t localhost/datumctl:latest .
```

## Use

The image's entrypoint is `datumctl`, so arguments go straight to it:

```sh
podman run --rm localhost/datumctl:latest --help
```

To get a shell instead:

```sh
podman run -it --rm --entrypoint /bin/bash localhost/datumctl:latest
```

Log in from inside the container (no browser is available there):

```sh
datumctl login --no-browser
```

Login state is stored in `/root/.datumctl`. It is lost when a `--rm` container exits, so mount a volume to keep it:

```sh
podman run -it --rm -v datumctl-config:/root/.datumctl --entrypoint /bin/bash localhost/datumctl:latest
```

### Bind-mount your `.datumctl` folder

To share credentials and config with the host (or between containers), bind-mount a host directory onto `/root/.datumctl`:

```sh
mkdir -p ~/.datumctl
podman run -it --rm -v ~/.datumctl:/root/.datumctl:Z --entrypoint /bin/bash localhost/datumctl:latest
```

Notes:

- The folder holds `config` (current context) and `credentials.json` (your login tokens). Treat it like a password: keep it mode `700`, never commit it, and don't share it.
- **Important:** the mount replaces the container's whole `/root/.datumctl`, including the plugins installed at build time in `/root/.datumctl/plugins`. With an empty host folder, `datumctl plugin list` will show nothing and plugins such as `connect` will be missing. Either:
  - mount only the two files, which keeps the built-in plugins:

    ```sh
    touch ~/.datumctl/config ~/.datumctl/credentials.json
    podman run -it --rm \
      -v ~/.datumctl/config:/root/.datumctl/config:Z \
      -v ~/.datumctl/credentials.json:/root/.datumctl/credentials.json:Z \
      --entrypoint /bin/bash localhost/datumctl:latest
    ```

    (Run `datumctl login --no-browser` once inside to fill them in. Create the files first, or Podman will make them directories.)
  - or seed the host folder from the image once, then mount the whole thing:

    ```sh
    podman run --rm -v ~/.datumctl:/mnt:Z --entrypoint cp localhost/datumctl:latest -a /root/.datumctl/. /mnt/
    ```

- `:Z` relabels the folder for SELinux (Fedora, RHEL). It can be dropped on systems without SELinux.
- With rootless Podman, files written as root in the container are owned by your user on the host. That is what you want here. Add `--userns=keep-id` only if you run the container as a non-root user.
