# asdf-resvg


A `resvg` plugin for the [asdf version manager](https://asdf-vm.com).


This plugin installs the `resvg` tool from source.

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [License](#license)

# Dependencies

- `bash`, `curl`, `tar`: generic POSIX utilities.
- `cargo`: The Rust package manager.

# Install

Plugin:

```shell
asdf plugin add resvg https://github.com/FATMAP/asdf-resvg.git
```

resvg:

```shell
# Show all installable versions
asdf list-all resvg

# Install specific version
asdf install resvg latest

# Set a version globally (on your ~/.tool-versions file)
asdf global resvg latest

# Now resvg can be invoked from the shell
resvg --version
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Acknowledgements

The plugin is based on work in [asdf-community/asdf-cmake](https://github.com/asdf-community/asdf-cmake).
Many thanks to the original authors of that project.

# License

See [LICENSE](LICENSE)

© [Andy Mroczkowski](https://github.com/amrox/)<br>
© [Strava](https://strava.com/)
