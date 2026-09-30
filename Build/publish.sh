#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR"

die()
{
  echo "error: $1" >&2
  exit "${2:-1}"
}

FORCE=0
for arg in "$@"; do
  case "$arg" in
    -f|--force) FORCE=1 ;;
    *) die "unknown argument: $arg" 1 ;;
  esac
done

BUILT_KERNEL_IMAGE_PATH="../arch/arm64/boot/Image"
ORIGIN_BOOT_IMAGE_PATH="./orig/boot.img"
OUTPUT_DIR="built"
START_TIME=$(date +%s)

command -v magiskboot >/dev/null 2>&1 || die "magiskboot not found in PATH" 2
command -v sha256sum >/dev/null 2>&1 || die "sha256sum not found in PATH" 2
[ -f "$ORIGIN_BOOT_IMAGE_PATH" ] || die "$ORIGIN_BOOT_IMAGE_PATH not found" 1
[ -f "$BUILT_KERNEL_IMAGE_PATH" ] || die "built kernel not found: $BUILT_KERNEL_IMAGE_PATH" 1

mkdir -p -- "$OUTPUT_DIR"

KERNEL_HASH=$(cat -- "$BUILT_KERNEL_IMAGE_PATH" "$ORIGIN_BOOT_IMAGE_PATH" | sha256sum | cut -c1-12)
OUTPUT_BOOT_IMAGE_NAME="boot-${KERNEL_HASH}.img"
OUTPUT_TAR_NAME="boot-${KERNEL_HASH}.tar"

if [ -f "$OUTPUT_DIR/$OUTPUT_BOOT_IMAGE_NAME" ] && [ "$FORCE" -eq 0 ]; then
  echo "output already exists for this kernel, skipping (use -f/--force to rebuild): $OUTPUT_DIR/$OUTPUT_BOOT_IMAGE_NAME"
  exit 0
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/repack_boot.XXXXXX")"
trap 'rm -rf -- "$WORK_DIR"' EXIT INT TERM HUP

OLD_KERNEL_SIZE=$(wc -c <"$BUILT_KERNEL_IMAGE_PATH" 2>/dev/null || echo 0)
ORIGIN_SIZE=$(wc -c <"$ORIGIN_BOOT_IMAGE_PATH" 2>/dev/null || echo 0)

cp -- "$ORIGIN_BOOT_IMAGE_PATH" "$WORK_DIR/boot.img"
cp -- "$BUILT_KERNEL_IMAGE_PATH" "$WORK_DIR/kernel_new"

UNPACK_LOG="$WORK_DIR/unpack.log"
if ! (cd "$WORK_DIR" && magiskboot unpack boot.img) >"$UNPACK_LOG" 2>&1; then
  cat "$UNPACK_LOG" >&2
  die "magiskboot unpack failed" 3
fi
[ -f "$WORK_DIR/kernel" ] || die "'kernel' not found after unpack" 3

OLD_KERNEL_IN_BOOT_SIZE=$(wc -c <"$WORK_DIR/kernel")
mv -f -- "$WORK_DIR/kernel_new" "$WORK_DIR/kernel"

REPACK_LOG="$WORK_DIR/repack.log"
if ! (cd "$WORK_DIR" && magiskboot repack boot.img "$OUTPUT_BOOT_IMAGE_NAME") >"$REPACK_LOG" 2>&1; then
  cat "$REPACK_LOG" >&2
  die "magiskboot repack failed" 3
fi
[ -f "$WORK_DIR/$OUTPUT_BOOT_IMAGE_NAME" ] || die "repack succeeded but output file missing" 3

NEW_BOOT_SIZE=$(wc -c <"$WORK_DIR/$OUTPUT_BOOT_IMAGE_NAME")

(
  cd "$WORK_DIR"
  cp -- "$OUTPUT_BOOT_IMAGE_NAME" boot.img
  tar -cf "$OUTPUT_TAR_NAME" boot.img
) || die "failed to create boot.tar" 3

cp -- "$WORK_DIR/$OUTPUT_BOOT_IMAGE_NAME" "$OUTPUT_DIR/$OUTPUT_BOOT_IMAGE_NAME" || die "failed to copy boot.img to $OUTPUT_DIR" 3
cp -- "$WORK_DIR/$OUTPUT_TAR_NAME" "$OUTPUT_DIR/$OUTPUT_TAR_NAME" || die "failed to copy boot.tar to $OUTPUT_DIR" 3

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

human_size()
{
  awk -v b="$1" 'BEGIN{
    split("B K M G", u, " ")
    i=1
    while (b>=1024 && i<4) { b/=1024; i++ }
    printf "%.1f%s", b, u[i]
  }'
}

echo "kernel:  $(human_size "$OLD_KERNEL_IN_BOOT_SIZE") -> $(human_size "$OLD_KERNEL_SIZE")"
echo "boot:    $(human_size "$ORIGIN_SIZE") -> $(human_size "$NEW_BOOT_SIZE")"
echo "output:  $OUTPUT_DIR/$OUTPUT_BOOT_IMAGE_NAME"
echo "         $OUTPUT_DIR/$OUTPUT_TAR_NAME"
echo "elapsed: ${ELAPSED}s"
