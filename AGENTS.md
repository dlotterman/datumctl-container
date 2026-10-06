# AGENTS.md

Container image that bundles `datumctl` and the Datum Cloud plugins (`alb`, `assistant`, `compute`, `dns`, `ipam`, `search`, `connect`).

## Layout

- `Containerfile`: the whole image definition. Based on unpinned `ubuntu:latest`, installs the latest `datumctl` release (checksum-verified), then the plugins.
- `.github/workflows/build.yml`: hourly job that rebuilds and pushes `dlotterman/datumctl-container` when a tracked upstream release changes.
- `.github/workflows/ci.yml`: on every push and PR, builds the image (amd64 and arm64, no push) and checks that all 7 plugins are listed.
- `README.md`: build and usage steps for humans.
- `.env`: local secrets, git-ignored. Never read, print, or commit it.

## Build and check

Either engine works; use `docker` in place of `podman` if you prefer.

```sh
podman build -t localhost/datumctl:latest .
podman run --rm localhost/datumctl:latest plugin list   # expect all 7 plugins, including connect
```

## Conventions

- Podman and Docker are interchangeable for building and running this image; the `Containerfile` must build with both. Don't add engine-specific features. Examples use `podman`; `docker` works by swapping the command. Tag local builds `localhost/datumctl:latest`.
- Keep the base image and release versions unpinned on purpose; don't add pins unless asked.
- Keep the `datum-connect` workaround in the `Containerfile` (the release archive ships the binary under an unrendered template name). Remove it only once upstream is fixed and a build proves `connect` still works.
- If you add a plugin or a tracked upstream repo, update both the `Containerfile` and `TRACKED_REPOS` in the workflow, plus the plugin list in `README.md`.

## Safety

- `~/.datumctl/credentials.json` holds login tokens. Don't print it, copy it into the repo, or bake it into the image.
- Don't push images or trigger the workflow unless asked.
- Tunnels and connectors created with `datumctl connect` live on Datum Cloud, not just in the container. Delete them when done.

## Known quirks

- `datumctl connect tunnel listen` rejects origins without a dot in the hostname (use e.g. `app.internal:8080`, not `app:8080`).
- `--yes` is passed through to the Rust binary, which rejects it. Omit it.
- `--detach` did not work in testing. Run the tunnel in the foreground.
