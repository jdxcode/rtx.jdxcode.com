#!/bin/sh
set -eu

#region logging setup
if [ "${RTX_DEBUG-}" = "true" ] || [ "${RTX_DEBUG-}" = "1" ]; then
	debug() {
		echo "$@" >&2
	}
else
	debug() {
		:
	}
fi

if [ "${RTX_QUIET-}" = "1" ] || [ "${RTX_QUIET-}" = "true" ]; then
	info() {
		:
	}
else
	info() {
		echo "$@" >&2
	}
fi

error() {
	echo "$@" >&2
	exit 1
}
#endregion

#region environment setup
get_os() {
	os="$(uname -s)"
	if [ "$os" = Darwin ]; then
		echo "macos"
	elif [ "$os" = Linux ]; then
		echo "linux"
	else
		error "unsupported OS: $os"
	fi
}

get_arch() {
	arch="$(uname -m)"
	if [ "$arch" = x86_64 ]; then
		echo "x64"
	elif [ "$arch" = aarch64 ] || [ "$arch" = arm64 ]; then
		echo "arm64"
	else
		error "unsupported architecture: $arch"
	fi
}

get_checksum() {
	os="$(get_os)"
	arch="$(get_arch)"

	checksum_linux_x86_64="009d260a937f6267fe6e5c0a3dcd8fe344c94527a160596926dad7cb36470e73  ./rtx-v1.5.1-linux-x64.tar.gz"
	checksum_linux_arm64="1a8491038447e88692820c487e331a520ceba2e4cf834970dbe20d215ec44b25  ./rtx-v1.5.1-linux-arm64.tar.gz"
	checksum_macos_x86_64="639e33f6403601f915ecaaa8aa21330427ca6870a95d74a243b3aa76d580b66a  ./rtx-v1.5.1-macos-x64.tar.gz"
	checksum_macos_arm64="fbdb85f8cc432feb25bc3096ad5721c242b9fffb9d05f0b48f87d31fd56e8dae  ./rtx-v1.5.1-macos-arm64.tar.gz"

	if [ "$os" = "linux" ] && [ "$arch" = "x64" ]; then
		echo "$checksum_linux_x86_64"
	elif [ "$os" = "linux" ] && [ "$arch" = "arm64" ]; then
		echo "$checksum_linux_arm64"
	elif [ "$os" = "macos" ] && [ "$arch" = "x64" ]; then
		echo "$checksum_macos_x86_64"
	elif [ "$os" = "macos" ] && [ "$arch" = "arm64" ]; then
		echo "$checksum_macos_arm64"
	else
		warn "no checksum for $os-$arch"
	fi
}

#endregion

download_file() {
	url="$1"
	filename="$(basename "$url")"
	cache_dir="$(mktemp -d)"
	file="$cache_dir/$filename"

	info "rtx: installing rtx..."

	if command -v curl >/dev/null 2>&1; then
		debug ">" curl -fLlSso "$file" "$url"
		curl -fLlSso "$file" "$url"
	else
		if command -v wget >/dev/null 2>&1; then
			debug ">" wget -qO "$file" "$url"
			stderr=$(mktemp)
			wget -O "$file" "$url" >"$stderr" 2>&1 || error "wget failed: $(cat "$stderr")"
		else
			error "rtx standalone install requires curl or wget but neither is installed. Aborting."
		fi
	fi

	echo "$file"
}

install_rtx() {
  # download the tarball
  version="v1.5.1"
  os="$(get_os)"
  arch="$(get_arch)"
  xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  install_path="${RTX_INSTALL_PATH:-$xdg_data_home/rtx/bin/rtx}"
  install_dir="$(dirname "$install_path")"
  tarball_url="https://github.com/jdxcode/rtx/releases/download/${version}/rtx-${version}-${os}-${arch}.tar.gz"

  cache_file=$(download_file "$tarball_url")
  debug "rtx-setup: tarball=$cache_file"

  debug "validating checksum"
  cd "$(dirname "$cache_file")" && get_checksum | sha256sum -c >/dev/null

  # extract tarball
  mkdir -p "$install_dir"
  rm -rf "$install_path"
  cd "$(mktemp -d)"
  tar -xzf "$cache_file"
  mv rtx/bin/rtx "$install_path"
  info "rtx: installed successfully to $install_path"
}

after_finish_help() {
  case "$SHELL" in
  */zsh)
    info "rtx: run the following get started:"
    info "echo -e \"\\\neval \\\"\\\$($install_path activate -s zsh)\\\"\" >> ~/.zshrc"
    ;;
  */bash)
    info "rtx: run the following get started:"
    info "echo -e \"\\\neval \\\"\\\$($install_path activate -s bash)\\\"\" >> ~/.bashrc"
    ;;
  */fish)
    info "rtx: run the following get started:"
    info "echo -e \"\\\n$install_path activate -s fish | source\" >> ~/.config/fish/config.fish"
    ;;
  *)
    info "rtx: run \`$install_path --help\` to get started"
    ;;
  esac
}

install_rtx
after_finish_help
