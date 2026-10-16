#!/bin/bash
#~~~~~~~~~~
# Downloads the pinned ONNX Runtime GPU/CUDA release, packages it as the
# simply-cpp-onnxruntime .deb, and publishes it into the apt repo for every
# distribution. The binary itself isn't tied to a particular Ubuntu release,
# so one build covers jammy/noble/resolute alike - run this on any one build
# server (deploy.sh defaults to build-noble).
#
# Run this in the directory deploy.sh synced it to (/var/www/build/sc-onnxruntime).

set -euo pipefail

version=$(tr -d ' \t\n' < VERSION.txt)
variant="gpu_cuda13"
tarball="onnxruntime-linux-x64-${variant}-${version}.tgz"
url="https://github.com/microsoft/onnxruntime/releases/download/v${version}/${tarball}"
package="simply-cpp-onnxruntime"
# A packaging revision (REVISION.txt) when the same upstream version is packaged again, such as
# with a copyright file: 3.5.0-1~noble sorts after 3.5.0~noble.
revision=$( [ -f REVISION.txt ] && tr -d ' \t\n' < REVISION.txt || true)
package_version="${version}${revision:+-$revision}"
deb_file="${package}_${package_version}_amd64.deb"

mkdir -p work
if [ ! -f "work/$tarball" ]; then
    echo "Downloading $url"
    wget -q -O "work/$tarball" "$url"
fi

rm -rf pkg work/extracted
mkdir -p pkg/DEBIAN pkg/usr/include work/extracted
tar xzf "work/$tarball" -C work/extracted
extracted_dir=$(find work/extracted -mindepth 1 -maxdepth 1 -type d)

cp -a "$extracted_dir/include" "pkg/usr/include/onnxruntime"
mkdir -p pkg/usr/lib
cp -a "$extracted_dir"/lib/. pkg/usr/lib/

# Microsoft's own exported onnxruntimeTargets-release.cmake hardcodes
# ${_IMPORT_PREFIX}/lib64/... for IMPORTED_LOCATION even though the tarball's
# own directory is "lib" - a real upstream mismatch, not something specific
# to how we're installing it. /usr/lib64 already exists as a real directory
# on these systems (just the dynamic linker symlink), so add the one file
# consumers actually need there rather than replacing the directory.
mkdir -p pkg/usr/lib64
for so in pkg/usr/lib/libonnxruntime.so.*.*.*; do
    ln -sf "../lib/$(basename "$so")" "pkg/usr/lib64/$(basename "$so")"
done

cat > pkg/DEBIAN/control <<EOF
Package: $package
Version: $package_version
Architecture: amd64
Section: libs
Priority: optional
Maintainer: Roelof Rossouw
Description: Prebuilt ONNX Runtime (GPU/CUDA build), repackaged for apt
 Headers and shared libraries from Microsoft's official ONNX Runtime
 $variant release, so it can be installed like any other system
 dependency instead of downloaded and unpacked by hand.
EOF

cat > pkg/DEBIAN/postinst <<'EOF'
#!/bin/sh
set -e
ldconfig
EOF

cat > pkg/DEBIAN/postrm <<'EOF'
#!/bin/sh
set -e
ldconfig
EOF

chmod 755 pkg/DEBIAN/postinst pkg/DEBIAN/postrm

# copyright <package directory> <package name>: upstream's licence, which it asks to ship with the
# binaries, where Debian keeps one (/usr/share/doc/<package>/copyright).
copyright() {
    install -d "$1/usr/share/doc/$2"
    {
        echo "$2 packages ONNX Runtime $version (https://github.com/microsoft/onnxruntime), licensed under MIT (its third-party notices follow the licence)."
        echo "The packaging scripts (https://github.com/roelofrossouw/simply-cpp-onnxruntime) are Apache-2.0."
        echo
        echo "----- ONNX Runtime: LICENSE -----"
        cat "$extracted_dir/LICENSE"
        echo
        echo "----- ONNX Runtime: ThirdPartyNotices.txt -----"
        cat "$extracted_dir/ThirdPartyNotices.txt"
    } > "$1/usr/share/doc/$2/copyright"
}
copyright pkg "$package"

dpkg-deb --build --root-owner-group pkg "$deb_file"

pushd /var/www/build/repo >/dev/null
export GNUPGHOME=/var/www/build/signing
for dist in jammy noble resolute; do
    if reprepro list "$dist" | grep -q "$package .*$package_version"; then
        echo "$dist: $package $package_version already published"
    else
        echo "$dist: publishing $package $package_version"
        reprepro remove "$dist" "$package" || true
        reprepro includedeb "$dist" "/var/www/build/sc-onnxruntime/$deb_file"
    fi
done
popd >/dev/null

echo "Done."
