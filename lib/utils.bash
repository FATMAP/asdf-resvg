#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/RazrFalcon/resvg"
TOOL_NAME="resvg"
TOOL_TEST="resvg"

fail() {
  echo -e "asdf-$TOOL_NAME: [ERR] $*"
  exit 1
}

log() {
  echo -e "asdf-$TOOL_NAME: [INFO] $*"
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_all_versions() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o -E 'refs/tags/v[0-9.]+$' | cut -d/ -f3- | sed 's/^v//'
}

extract() {
  local archive_path=$1
  local target_dir=$2

  tar -xf "$archive_path" -C "$target_dir" --strip-components=1 || fail "Could not extract $archive_path"
}

get_source_download_url() {
  local version=$1

  if [[ "$version" =~ ^[0-9]+\.* ]]; then
    # if version is a release number, form a tag name out of it.
    echo "${GH_REPO}/archive/refs/tags/v${version}.tar.gz"
  else
    # otherwise it can be a branch name or commit sha
    echo "https://github.com/llvm/llvm-project/archive/${version}.tar.gz"
  fi
}

download_source() {
  local version filepath url

  version="$1"
  filepath="$2"

  url=$(get_source_download_url "$version")
  curl "${curl_opts[@]}" -o "$filepath" "$url" || fail "Could not download $url"
  return 0
}

source_download_and_extract() {
  # Puts the extracted files in $ASDF_DOWNLOAD_PATH/src

  local version=$1
  local download_dir=$2

  local extract_dir="${download_dir}/src"
  mkdir -p "$extract_dir"

  local download_file="${download_dir}/${TOOL_NAME}-${version}-src.tar.gz"

  if download_source "$version" "${download_file}"; then
    extract "${download_file}" "${extract_dir}"
    rm "${download_file}"
    return 0
  fi

  rm -rf "${extract_dir}"
  return 1
}

download_and_extract() {

  local install_type="$1"
  local version="$2"
  local download_dir="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
    # TODO: support refs
  fi

  ## Source Download & Extract
  source_download_and_extract "$version" "${download_dir}"
}

source_build_install() {

  local src_dir="$1"
  local build_dir="$2"
  local install_path="$3"
  (
    set -e  # Not sure why, but it doesn't have an effect, so we sprinkle those
            # "|| exit 1" statements.
    cd "${src_dir}" || exit 1
    cargo build --release || exit 1
    mkdir -p "${install_path}/bin" || exit 1
    cp -fp "${src_dir}/target/release/resvg" "${install_path}/bin/" || exit 1
  )
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path/bin"

    source_build_install "$ASDF_DOWNLOAD_PATH"/src "$ASDF_DOWNLOAD_PATH/build" "$install_path"

    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    log "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
