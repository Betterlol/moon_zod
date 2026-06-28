#!/usr/bin/env sh
# Wrapper around moon run cmd/json2schema providing --file support.
# MoonBit core lacks file I/O, so the shell handles file reading.
#
# Usage:
#   sh cli.sh --file <path> --file <path>
#   sh cli.sh '<json-schema>' '<json-data>'

case "$1" in
  --file)
    if [ -z "$2" ]; then
      echo "Error: --file requires a file path argument" >&2
      echo "Usage: sh cli.sh --file <path> --file <path>" >&2
      exit 1
    fi
    if [ ! -f "$2" ]; then
      echo "Error: file not found: $2" >&2
      exit 1
    fi
    schema_content=$(cat "$2")
    shift 2
    if [ "$1" = "--file" ]; then
      if [ -z "$2" ]; then
        echo "Error: --file requires a file path argument" >&2
        echo "Usage: sh cli.sh --file <path> --file <path>" >&2
        exit 1
      fi
      if [ ! -f "$2" ]; then
        echo "Error: file not found: $2" >&2
        exit 1
      fi
      data_content=$(cat "$2")
      exec moon run cmd/validate -- --schema "$schema_content" "$data_content"
    else
      exec moon run cmd/validate -- --schema "$schema_content" "$@"
    fi
    ;;
  *)
    exec moon run cmd/validate -- "$@"
    ;;
esac