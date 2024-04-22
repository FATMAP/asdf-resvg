#!/usr/bin/env bash

set -euo pipefail

ASDF_CLANG_FORMAT_FORCE_SOURCE_INSTALL=${ASDF_CLANG_FORMAT_FORCE_SOURCE_INSTALL:-0}

# TODO: Ensure this is the correct GitHub homepage where releases can be downloaded for <YOUR TOOL>.
GH_REPO="https://github.com/llvm/llvm-project"
TOOL_NAME="clang-format"
TOOL_TEST="clang-format"

fail() {
  echo -e "asdf-$TOOL_NAME: [ERR] $*"
  exit 1
}

log() {
  echo -e "asdf-$TOOL_NAME: [INFO] $*"
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if the tool in question is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_all_versions() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o -E 'refs/tags/llvmorg-[0-9.]+$' | cut -d/ -f3- |
    sed 's/^llvmorg-//'
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
    echo "https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-${version}.tar.gz"
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

download_binary() {
  local version filepath url
  version="$1"
  filepath="$2"

  local platforms=()
  local kernel arch
  kernel="$(uname -s)"
  arch="$(uname -m)"

  case "$kernel" in
  Darwin)
    platforms=("${arch}-apple-darwin$(uname -r | cut -d . -f1).0")
    ;;
  Linux)
    platforms=("${arch}-linux-gnu")
    ;;
  esac

  log "Downloading $TOOL_NAME release $version..."
  for platform in ${platforms[*]}; do
    url="$GH_REPO/releases/download/llvmorg-${version}/clang+llvm-${version}-${platform}.tar.xz"
    log "Trying ${url} ..."
    curl "${curl_opts[@]}" -o "$filepath" -C - "$url" && return 0
  done

  return 1
}

binary_download_and_extract() {
  # Puts the extracted files in $ASDF_DOWNLOAD_PATH/bin

  local version=$1
  local download_dir=$2

  local extract_dir="${download_dir}/bin"
  mkdir -p "$extract_dir"

  local download_file="${download_dir}/${TOOL_NAME}-${version}-bin.tar.gz"

  if download_binary "$version" "${download_file}"; then
    extract "${download_file}" "${extract_dir}"

    # Some of the files in the binary archive are write-protected, so when asdf eventually tries
    # to remove that directory, rm asks a manual confirmation to delete such files. To prevent
    # that, we make all files in that archive writable.
    chmod -R u+w "${extract_dir}"

    rm "${download_file}"
    return 0
  fi

  rm -rf "${extract_dir}"
  return 1
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

  if [ "$ASDF_CLANG_FORMAT_FORCE_SOURCE_INSTALL" == 1 ]; then
    log "Skipping binary download because ASDF_CLANG_FORMAT_FORCE_SOURCE_INSTALL=1"
  else
    ## Binary Download & Extract
    if binary_download_and_extract "$version" "${download_dir}"; then
      return 0
    else
      log "Could not find a suitable binary download for $TOOL_NAME $version, falling back to source..."
    fi
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
    mkdir -p "${build_dir}" || exit 1
    cd "${build_dir}" || exit 1
    cmake -DCMAKE_BUILD_TYPE=MinSizeRel "-DCMAKE_INSTALL_PREFIX=${install_path}" \
      -DBUILD_SHARED_LIBS=OFF "-DLLVM_ENABLE_PROJECTS=clang;clang-tools-extra" \
      "${src_dir}/llvm" || exit 1
    make -j "$ASDF_CONCURRENCY" clang-format || exit 1
    mkdir -p "${install_path}/bin" || exit 1
    cp -fp "${build_dir}/bin/clang-format" "${install_path}/bin/" || exit 1
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

    if [ -d "$ASDF_DOWNLOAD_PATH"/bin ]; then

      log "Installing download binary in ${ASDF_DOWNLOAD_PATH}/bin"
      log "Should it fail to work, consider reinstalling with ASDF_CLANG_FORMAT_FORCE_SOURCE_INSTALL=1"

      # Fortunately, all binary releases seem to be built without shared libs,
      # so copying a single binary turns out to be enough.
      cp -fp "${ASDF_DOWNLOAD_PATH}/bin/bin/clang-format" "$install_path/bin/"

    elif [ -d "$ASDF_DOWNLOAD_PATH"/src ]; then
      source_build_install "$ASDF_DOWNLOAD_PATH"/src "$ASDF_DOWNLOAD_PATH/build" "$install_path"
    fi

    # TODO: Asert <YOUR TOOL> executable exists.
    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    log "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
