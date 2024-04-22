# asdf-clang-format


A `clang-format` plugin for the [asdf version manager](https://asdf-vm.com).


This plugin will try to install a binary build of clang-format from the official LLVM repository.
Failing that, it will try to build it from source. Building from source can also be forced by
setting the `ASDF_CLANG_FORMAT_FORCE_SOURCE_INSTALL=1` environment variable.

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [License](#license)

# Dependencies

- `bash`, `curl`, `tar`: generic POSIX utilities.
- If building from source, a C++ compiler, `cmake`, `make`, etc are required.

# Install

Plugin:

```shell
asdf plugin add clang-format https://github.com/FATMAP/asdf-clang-format.git
```

clang-format:

```shell
# Show all installable versions
asdf list-all clang-format

# Install specific version
asdf install clang-format latest

# Set a version globally (on your ~/.tool-versions file)
asdf global clang-format latest

# Now clang-format can be invoked from the shell
clang-format --version
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Configuration

A following environment variables can affect this plugin:

- `ASDF_CLANG_FORMAT_FORCE_SOURCE_INSTALL`: Set to `1` to force a source-based installation instead of using a
  pre-compiled binary, even if a binary release is available.

# Acknowledgements

The plugin is based on work in [asdf-community/asdf-cmake](https://github.com/asdf-community/asdf-cmake).
Many thanks to the original authors of that project.

# License

See [LICENSE](LICENSE)

© [Andy Mroczkowski](https://github.com/amrox/)<br>
© [Strava](https://strava.com/)
