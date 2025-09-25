#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

function install_libvips() {
	if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists vips; then
		echo "libvips already installed"
		return 0
	fi

	echo "Installing libvips dependencies"

	SUDO_CMD=""
	if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
		SUDO_CMD="sudo"
	fi

	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
		# Detect Linux distribution
		if command -v apt-get >/dev/null 2>&1; then
			if grep -q "trixie" /etc/os-release 2>/dev/null; then
				$SUDO_CMD apt-get install -y --no-install-recommends \
					libvips-dev=8.16.1-1+b1 \
					libheif-dev \
					pkg-config
			else
				$SUDO_CMD apt-get install -y --no-install-recommends \
					libvips-dev \
					libheif-dev \
					pkg-config
			fi
		elif command -v pacman >/dev/null 2>&1; then
			$SUDO_CMD pacman -S --noconfirm libvips libheif pkgconf
		fi
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		if command -v brew >/dev/null 2>&1; then
			brew install vips libheif pkg-config
		fi
	fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	install_libvips
fi
