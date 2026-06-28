#!/usr/bin/env sh
# Wrapper around moon run cmd/json2schema providing --file support.
# MoonBit core lacks file I/O, so the shell handles file reading.
#
# Usage:
#   sh cli.sh <ops> --file <path>
#   sh cli.sh <ops> '<json-string>'

case "$1" in
  --file)
    if [ -z "$2" ]; then
      echo "Error: --file requires a file path argument" >&2
      echo "Usage: sh cli.sh --file <path>" >&2
      exit 1
    fi
    if [ ! -f "$2" ]; then
      echo "Error: file not found: $2" >&2
      exit 1
    fi
    content=$(cat "$2")
    exec moon run cmd/json2schema -- "$content"
    ;;
  --from-json-schema)
    case "$2" in
      --file)
        if [ -z "$3" ]; then
          echo "Error: --file requires a file path argument" >&2
          echo "Usage: sh cli.sh --from-json-schema --file <path>" >&2
          exit 1
        fi
        if [ ! -f "$3" ]; then
          echo "Error: file not found: $3" >&2
          exit 1
        fi
        content=$(cat "$3")
        exec moon run cmd/json2schema -- --from-json-schema "$content"
        ;;
      *)
        exec moon run cmd/json2schema -- --from-json-schema "$@"
        ;;
    esac
    ;;
  *)
    exec moon run cmd/json2schema -- "$@"
    ;;
esac
