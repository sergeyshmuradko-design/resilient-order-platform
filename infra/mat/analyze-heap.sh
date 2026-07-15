#!/usr/bin/env bash

set -Eeuo pipefail

# Передаём в Docker Compose UID/GID текущего пользователя.
# Тогда контейнер создаёт файлы с правильным владельцем,
# а не от имени root.
export LOCAL_UID="$(id -u)"
export LOCAL_GID="$(id -g)"

DUMP_NAME="${1:-order-service-oom.hprof}"
REPORT_TYPE="${2:-org.eclipse.mat.api:suspects}"

DUMP_DIR="infra/heap-dumps"
REPORT_ROOT="infra/heap-reports"

DUMP_PATH="${DUMP_DIR}/${DUMP_NAME}"
REPORT_NAME="${DUMP_NAME%.hprof}"
REPORT_DIR="${REPORT_ROOT}/${REPORT_NAME}"

if [[ ! -f "${DUMP_PATH}" ]]; then
  echo "Heap dump not found: ${DUMP_PATH}" >&2
  exit 1
fi

mkdir -p "${REPORT_ROOT}"

if [[ ! -w "${REPORT_ROOT}" ]]; then
    echo "Report directory is not writable: ${REPORT_ROOT}" >&2
    echo "Current owner and permissions:" >&2
    ls -ld "${REPORT_ROOT}" >&2
    echo >&2
    echo "Fix with:" >&2
    echo "sudo chown -R \$(id -u):\$(id -g) ${REPORT_ROOT}" >&2
    exit 1
fi

echo "Analyzing heap dump: ${DUMP_PATH}"
echo "MAT report type: ${REPORT_TYPE}"

docker compose \
    -f docker-compose.diagnostics.yml \
    run --rm \
    mat-headless \
    "/work/dumps/${DUMP_NAME}" \
    "${REPORT_TYPE}"

# MAT creates the report ZIP beside the heap dump.
# For a suspects report this is normally:
# order-service-oom_Leak_Suspects.zip
REPORT_ZIP="$(find "${DUMP_DIR}" \
    -maxdepth 1 \
    -type f \
    -name "${REPORT_NAME}*.zip" \
    -printf '%T@ %p\n' \
    | sort -n \
    | tail -n 1 \
    | cut -d' ' -f2-)"

if [[ -z "${REPORT_ZIP}" || ! -f "${REPORT_ZIP}" ]]; then
    echo "MAT completed, but no report ZIP was found in ${DUMP_DIR}." >&2
    exit 1
fi

rm -rf "${REPORT_DIR}"
mkdir -p "${REPORT_DIR}"

unzip -q "${REPORT_ZIP}" -d "${REPORT_DIR}"

# Move the ZIP away from the dump directory after successful extraction.
mv "${REPORT_ZIP}" "${REPORT_ROOT}/"

echo
echo "Heap analysis completed."
echo "HTML report: ${REPORT_DIR}/index.html"
echo
echo "Generated MAT indexes remain beside the heap dump."