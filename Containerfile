# Always track the latest Ubuntu release; intentionally unpinned.
FROM docker.io/library/ubuntu:latest

ARG DEBIAN_FRONTEND=noninteractive
# Release tag to install (e.g. v1.2.3); empty means resolve the latest release.
ARG DATUMCTL_VERSION=

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

# Install the latest datumctl release, verified against the release checksums.
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
      amd64) arch=x86_64 ;; \
      arm64) arch=arm64 ;; \
      i386)  arch=i386 ;; \
      *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    tag="${DATUMCTL_VERSION}"; \
    if [ -z "$tag" ]; then \
      tag="$(curl -fsSLo /dev/null -w '%{url_effective}' https://github.com/datum-cloud/datumctl/releases/latest)"; \
      tag="${tag##*/}"; \
    fi; \
    base="https://github.com/datum-cloud/datumctl/releases/download/${tag}"; \
    tarball="datumctl_Linux_${arch}.tar.gz"; \
    tmp="$(mktemp -d)"; \
    cd "$tmp"; \
    curl -fsSLO "${base}/${tarball}"; \
    curl -fsSLO "${base}/datumctl_${tag#v}_checksums.txt"; \
    grep " ${tarball}\$" "datumctl_${tag#v}_checksums.txt" | sha256sum -c -; \
    tar -xzf "$tarball" datumctl; \
    install -m 0755 datumctl /usr/local/bin/datumctl; \
    cd /; \
    rm -rf "$tmp"; \
    datumctl --help >/dev/null

# Install the latest official plugins from the datum catalog.
RUN set -eux; \
    for plugin in alb assistant compute dns ipam search; do \
      datumctl plugin install "$plugin"; \
    done; \
    datumctl plugin list

# Install the Datum Connect plugin from its GitHub repo (not in the catalog).
# Workaround: the release archive ships the Rust tunnel agent under an unrendered
# template name ("datum-connect{{ if eq .Os "windows" }}.exe{{ end }}") without the
# exec bit, and `plugin install` only places the Go wrapper. Install it by hand
# when it is missing; this is a no-op once the release is fixed.
#
# Upstream only publishes prereleases (e.g. v1.0.0-preview.N), which GitHub's
# /releases/latest and `plugin install datum-cloud/connect` both ignore. Resolve
# the newest release, prereleases included, from the public releases feed. The
# feed can list a tag before its assets are uploaded, so take the newest tag
# that already has a checksums.txt.
RUN set -eux; \
    tag=; \
    for t in $(curl -fsSL https://github.com/datum-cloud/connect/releases.atom | grep -oE 'releases/tag/[^"]+' | sed 's|.*/||'); do \
      if curl -fsSIL -o /dev/null "https://github.com/datum-cloud/connect/releases/download/${t}/checksums.txt"; then tag="$t"; break; fi; \
    done; \
    test -n "$tag"; \
    datumctl plugin install "datum-cloud/connect@${tag}"; \
    plugins="${HOME}/.datumctl/plugins"; \
    if [ ! -x "${plugins}/datum-connect" ]; then \
      case "$(dpkg --print-architecture)" in \
        amd64) arch=x86_64 ;; \
        arm64) arch=arm64 ;; \
        *) echo "unsupported architecture for datum-connect: $(dpkg --print-architecture)" >&2; exit 1 ;; \
      esac; \
      base="https://github.com/datum-cloud/connect/releases/download/${tag}"; \
      tarball="datumctl-connect_Linux_${arch}.tar.gz"; \
      tmp="$(mktemp -d)"; \
      cd "$tmp"; \
      curl -fsSLO "${base}/${tarball}"; \
      curl -fsSLO "${base}/checksums.txt"; \
      grep " ${tarball}\$" checksums.txt | sha256sum -c -; \
      tar -xzf "$tarball"; \
      set -- datum-connect*; \
      [ "$#" -eq 1 ] && [ -f "$1" ]; \
      install -m 0755 "$1" "${plugins}/datum-connect"; \
      cd /; \
      rm -rf "$tmp"; \
    fi; \
    test -x "${plugins}/datum-connect"; \
    datumctl plugin list

# `datumctl compute build` talks to BuildKit directly (no docker CLI needed).
# Default to a sidecar container named "buildkitd" on a shared network; override
# with `-e BUILDKIT_HOST=...` to point elsewhere.
ENV BUILDKIT_HOST=tcp://buildkitd:1234

ENTRYPOINT ["/usr/local/bin/datumctl"]
CMD ["--help"]
