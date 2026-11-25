#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: sh tools/publish_test_apk.sh path/to/PaperRally-VERSION-test.apk" >&2
    exit 2
fi

apk=$1
name=${apk##*/}
if ! printf '%s\n' "$name" | grep -Eq '^PaperRally-[0-9]+\.[0-9]+\.[0-9]+-test\.apk$'; then
    echo "Use a versioned APK name such as PaperRally-1.0.16-test.apk." >&2
    exit 2
fi
unzip -tq "$apk" >&2

remote=$(git remote get-url --push origin)
case "$remote" in
    https://github.com/* | git@github.com:*) repository=${remote#*github.com}; repository=${repository#?} ;;
    *) echo "Origin must be a GitHub repository." >&2; exit 2 ;;
esac
repository=${repository%.git}
version=${name#PaperRally-}
version=${version%-test.apk}
tag="android-apk-v$version"
ref="refs/tags/$tag"
url="https://raw.githubusercontent.com/$repository/$tag/$name"

# Keep the APK in a standalone tag so it adds no binary to the source history.
existing=$(git ls-remote --refs origin "$ref")
if [ -z "$existing" ]; then
    blob=$(git hash-object --no-filters -w -- "$apk")
    tree=$(printf '100644 blob %s\t%s\n' "$blob" "$name" | git mktree)
    revision=$(git rev-parse HEAD)
    artifact=$(printf 'Paper Rally %s Android test APK\n\nSource: %s\n' "$version" "$revision" | git commit-tree "$tree")
    git push origin "$artifact:$ref"
fi

download=$(mktemp)
trap 'rm -f "$download"' EXIT
curl --fail --silent --show-error --location --retry 5 --retry-delay 3 --retry-all-errors \
    --max-time 120 --output "$download" "$url"
if ! cmp -s "$apk" "$download"; then
    echo "The GitHub file differs from the local APK. Publish the new build with a new version." >&2
    exit 1
fi
printf '%s\n' "$url"
