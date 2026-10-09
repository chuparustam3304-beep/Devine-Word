#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
android_dir="$repo_root/android"
properties_file="$android_dir/key.properties"
bundle_file="$repo_root/build/app/outputs/bundle/release/app-release.aab"

if ! command -v flutter >/dev/null 2>&1; then
  printf 'Error: Flutter is not on PATH. Open a Flutter-enabled VS Code terminal and retry.\n' >&2
  exit 1
fi

if [[ ! -f "$properties_file" ]]; then
  printf 'Error: %s is missing. Follow ANDROID_AAB_BUILD.md to create it.\n' "$properties_file" >&2
  exit 1
fi

read_property() {
  local property_name="$1"
  awk -F= -v key="$property_name" '
    $1 == key {
      sub(/\r$/, "", $2)
      sub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      print $2
      exit
    }
  ' "$properties_file"
}

for property_name in storePassword keyPassword keyAlias storeFile; do
  value="$(read_property "$property_name")"
  if [[ -z "$value" || "$value" == replace-with-* ]]; then
    printf 'Error: set a real %s value in android/key.properties.\n' "$property_name" >&2
    exit 1
  fi
done

store_file="$(read_property storeFile)"
if [[ "$store_file" = /* ]]; then
  keystore_path="$store_file"
else
  keystore_path="$android_dir/$store_file"
fi

if [[ ! -f "$keystore_path" ]]; then
  printf 'Error: keystore not found at %s (the storeFile path in key.properties).\n' \
    "$keystore_path" >&2
  exit 1
fi

cd "$repo_root"
printf 'Building signed Android App Bundle...\n'
flutter build appbundle --release

if [[ ! -f "$bundle_file" ]]; then
  printf 'Error: Flutter reported success, but the AAB was not found at %s.\n' \
    "$bundle_file" >&2
  exit 1
fi

printf '\nBuild complete:\n%s\n' "$bundle_file"