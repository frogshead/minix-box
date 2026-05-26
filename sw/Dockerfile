# Buildroot host environment for building the minix-box Linux image.
# Buildroot does not build natively on macOS (needs Linux + a case-sensitive FS),
# so the whole build runs in this container. See sw/build.sh.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
		bc \
		build-essential \
		bzip2 \
		ca-certificates \
		cpio \
		file \
		git \
		libncurses-dev \
		locales \
		perl \
		python3 \
		rsync \
		sed \
		unzip \
		wget \
		xz-utils \
	&& rm -rf /var/lib/apt/lists/* \
	&& sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
	&& locale-gen
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Non-root build user (Buildroot refuses to run as root). UID/GID are matched to
# the host at build time so files in mounted volumes get sane ownership.
ARG UID=1000
ARG GID=1000
RUN groupadd -g "${GID}" build 2>/dev/null || true \
	&& useradd -m -u "${UID}" -g "${GID}" -s /bin/bash build 2>/dev/null || true \
	&& mkdir -p /build /dl \
	&& chown -R "${UID}:${GID}" /build /dl

USER build
WORKDIR /build
