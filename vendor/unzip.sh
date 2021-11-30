#!/bin/bash

set -eu
set -o pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

mkdir -p "${SCRIPT_DIR}/big_sur/"
mkdir -p "${SCRIPT_DIR}/arm64_big_sur/"

for zip in *.tar.gz; do
    echo "Unzipping $zip..."
    case $zip in
        *.big_sur.*)
            echo "This is an Intel binary."
            folder=big_sur/
            ;;
        *.arm64_big_sur.*)
            echo "This is an ARM64 binary."
            folder=arm64_big_sur/
            ;;
        *)
            echo "Unknown tar.gz file, error."
            exit 1
            ;;
    esac
    (cd "$folder" ; tar xzf ../"$zip")
done
