#!/usr/bin/env sh
# Wrapper around moon run cmd/validate providing file input support.
# MoonBit core lacks file I/O, so the shell handles file reading.
#
# Usage:
#   sh cmd/validate/cli.sh --schema-file <schema.json> --file <data.json>
#   sh cmd/validate/cli.sh --sample-file <sample.json> --file <data.json>
#   sh cmd/validate/cli.sh --schema '<json-schema>' '<json-data>'

case "$1" in
  -h|--help)
    exec moon run cmd/validate -- --help
    ;;
  --schema-file|--file)
    if [ -z "$2" ]; then
      echo "Error: $1 requires a file path argument" >&2
      echo "Usage: sh cmd/validate/cli.sh --schema-file <schema.json> --file <data.json>" >&2
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
        echo "Usage: sh cmd/validate/cli.sh --schema-file <schema.json> --file <data.json>" >&2
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
  --sample-file)
    if [ -z "$2" ]; then
      echo "Error: --sample-file requires a file path argument" >&2
      echo "Usage: sh cmd/validate/cli.sh --sample-file <sample.json> --file <data.json>" >&2
      exit 1
    fi
    if [ ! -f "$2" ]; then
      echo "Error: file not found: $2" >&2
      exit 1
    fi
    sample_content=$(cat "$2")
    shift 2
    if [ "$1" = "--file" ]; then
      if [ -z "$2" ]; then
        echo "Error: --file requires a file path argument" >&2
        echo "Usage: sh cmd/validate/cli.sh --sample-file <sample.json> --file <data.json>" >&2
        exit 1
      fi
      if [ ! -f "$2" ]; then
        echo "Error: file not found: $2" >&2
        exit 1
      fi
      data_content=$(cat "$2")
      exec moon run cmd/validate -- "$sample_content" "$data_content"
    else
      exec moon run cmd/validate -- "$sample_content" "$@"
    fi
    ;;
  *)
    exec moon run cmd/validate -- "$@"
    ;;
esac
