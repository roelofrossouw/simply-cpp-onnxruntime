# simply-cpp-onnxruntime

Prebuilt ONNX Runtime (GPU/CUDA build), repackaged as an apt package.

This exists so `simply-cpp-ai` (and anything else that needs ONNX Runtime) can
depend on a normal system package on Linux instead of downloading and unpacking
a release tarball by hand at configure time. There's no C++ source here - it's
just Microsoft's own ONNX Runtime release, repackaged as a `.deb`.

On macOS, use Homebrew's own `onnxruntime` formula instead - this package is
Linux/apt only.

## Install

```bash
sudo curl -fsSL https://apt.roelof.co.za/setup.sh | bash
sudo apt -y install simply-cpp-onnxruntime
```

This installs headers to `/usr/include/onnxruntime` and the shared libraries to
`/usr/lib`, so `find_package(onnxruntime CONFIG REQUIRED)` (or plain
`-lonnxruntime`) works the same way it would with any other apt-installed
library.

## Requirements

The packaged build is ONNX Runtime's GPU/CUDA variant - a matching NVIDIA
driver and CUDA installation must already be present on the machine for it to
load. There's currently no separate CPU-only package; if you need one, ask
rather than assuming it doesn't exist yet.

## Publishing a new version

Bump `VERSION.txt` to the ONNX Runtime release to package (must have a
`onnxruntime-linux-x64-gpu_cuda13-<version>.tgz` asset on
[the upstream releases page](https://github.com/microsoft/onnxruntime/releases)),
commit, then:

```bash
scripts/deploy.sh          # publishes to jammy/noble/resolute in one shot
```
