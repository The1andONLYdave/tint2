#!/bin/bash

set -x

if [ ! -z "$1" ]
then
    MINOR="$1"
else
    MINOR="1"
fi

# Get version (and check that the repository is clean)
VERSION=$(../get_version.sh --strict | sed 's/-git/./')
if [ ! $? -eq 0 ]
then
    echo >&2 "Error: get_version.sh failed!"
    exit 1
fi
rm -f version.h
VERSION="$(git show -s --pretty=format:%cI.%ct.%h | tr -d ':' | tr -d '-' | tr '.' '-' | sed 's/T[0-9\+]*//g').$MINOR"

# Export repository contents to source directory
DIR=tint2-$VERSION
echo "Making release $DIR"

pushd .
cd ..
git checkout-index --prefix=packaging/$DIR/ -a
popd

# Update version file in source directory
rm -f $DIR/make_release.sh
echo "echo \"#define VERSION_STRING \\\"$VERSION\\\"\" > version.h" > $DIR/get_version.sh

# Copy the debian files into the source directory
cp -r ubuntu $DIR/debian

for DISTRO in precise trusty wily xenial
do
    # Cleanup from previous builds
    rm -rf tint2_$VERSION-*

    # Update debian package changelog if necessary
    echo -e "tint2 ($VERSION-$DISTRO-1) $DISTRO; urgency=medium\n\n$(git log --pretty=format:'  * %h %an (%ci) %s %d')\n -- o9000 <mrovi9000@gmail.com>  $(date -R)\n" > $DIR/debian/changelog

    # Create source tarball
    ARCHIVE=tint2_$VERSION-$DISTRO.orig.tar.gz
    rm -rf $ARCHIVE
    tar -czf $ARCHIVE $DIR

    # Build package
    KEY=$(gpg --list-secret-keys | awk '/^sec/ { print $2 }' | cut -d / -f 2)

    pushd .
    cd $DIR
    debuild -S -k$KEY
    popd

    # Upload package
    dput ppa:o9000/tint2 tint2_$VERSION-$DISTRO-1_source.changes
done

# Cleanup
rm -rf $DIR $ARCHIVE
rm -rf tint2_$VERSION-*