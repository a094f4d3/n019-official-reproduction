#!/usr/bin/env bash

set -euo pipefail

if [[ "$(id -u)" != "0" ]]; then
  echo "This distribution script must run as root inside an AI container." >&2
  exit 2
fi

SOURCE_ACCOUNT="${N019_SOURCE_ACCOUNT:-a094f4d4}"
TARGET_ACCOUNTS="${N019_TARGET_ACCOUNTS:-a094f4d6 a094f4d7}"
SOURCE_ROOT="/public/home/$SOURCE_ACCOUNT/voice_projects/tmp"

if [[ "$#" -eq 0 ]]; then
  echo "Usage: $0 FILE [FILE ...]" >&2
  exit 3
fi

for source in "$@"; do
  case "$source" in
    "$SOURCE_ROOT"/*) ;;
    *)
      echo "Refusing source outside $SOURCE_ROOT: $source" >&2
      exit 4
      ;;
  esac
  if [[ ! -f "$source" ]]; then
    echo "Missing source file: $source" >&2
    exit 5
  fi
done

for account in $TARGET_ACCOUNTS; do
  home="/public/home/$account"
  if [[ ! -d "$home" ]]; then
    echo "Missing target home: $home" >&2
    exit 6
  fi
  owner_group="$(stat -c '%u:%g' "$home")"
  uid="${owner_group%%:*}"
  gid="${owner_group##*:}"
  destination_dir="$home/voice_projects/tmp"
  install -d -o "$uid" -g "$gid" "$destination_dir"

  for source in "$@"; do
    name="$(basename "$source")"
    destination="$destination_dir/$name"
    source_hash="$(sha256sum "$source" | awk '{print $1}')"
    cp "$source" "$destination.distributing"
    chown "$uid:$gid" "$destination.distributing"
    mv "$destination.distributing" "$destination"
    destination_hash="$(sha256sum "$destination" | awk '{print $1}')"
    if [[ "$source_hash" != "$destination_hash" ]]; then
      echo "SHA256 mismatch: $account $name" >&2
      exit 7
    fi
    echo "copied account=$account file=$name bytes=$(stat -c %s "$destination") sha256=$destination_hash"
  done
done

echo "DISTRIBUTION_COMPLETE"
