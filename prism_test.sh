#!/usr/bin/env bash
set -euo pipefail

DATA_TYPE="f32"
SIZE_X=500
SIZE_Y=500
SIZE_Z=100

OUTPUT_DIR="output"
TMP_DIR="${OUTPUT_DIR}/tmp_prism_runs"

BINARY=/home/moonlightplague/projects/PRISM/build/prism
PRISM=true
PRISMTEST=true
PRISMTESTAT=false
PRISMTESTFAT=false
EBSTR=("1e-3" "1e-5")

mkdir -p "${OUTPUT_DIR}" "${TMP_DIR}"

OUTPUT_FILE="${OUTPUT_DIR}/prism_test.log"
: > "${OUTPUT_FILE}"

sanitize_log_output() {
    LC_ALL=C sed -E $'s/\x1B\\[[0-?]*[ -/]*[@-~]//g; s/[^[:print:]\t]//g'
}

append_log() {
    "$@" 2>&1 | sanitize_log_output >> "${OUTPUT_FILE}"
}

cleanup_tmp() {
    rm -f -- "${TMP_DIR}"/*
}

trap cleanup_tmp EXIT

echo "Test start with Hurricane dataset" > "${OUTPUT_FILE}"

shopt -s nullglob

for FILENAME in *.f32; do
    STEM="$(basename "${FILENAME}" .f32)"

    for EB in "${EBSTR[@]}"; do
        EB_TAG="${EB//[^a-zA-Z0-9]/_}"

        echo "**********Running ${FILENAME} with relative error bound ${EB}**********" >> "${OUTPUT_FILE}"

        if $PRISM; then
            echo "==============" >> "${OUTPUT_FILE}"
            echo "Running prism" >> "${OUTPUT_FILE}"
            echo "==============" >> "${OUTPUT_FILE}"

            X_FILE="${TMP_DIR}/${STEM}_eb_${EB_TAG}.prism"
            Z_FILE="${TMP_DIR}/${STEM}_eb_${EB_TAG}.compressed.prism"

            rm -f -- "${X_FILE}" "${Z_FILE}"

            append_log $BINARY \
                -i "${FILENAME}" \
                -f -3 "${SIZE_X}" "${SIZE_Y}" "${SIZE_Z}" \
                -R "${EB}" \
                -x "${X_FILE}" \
                -z "${Z_FILE}" \
                --report time,cr

            rm -f -- "${X_FILE}" "${Z_FILE}"
        fi

        if $PRISMTEST; then
            echo "===========================================" >> "${OUTPUT_FILE}"
            echo "Running prism test mode 1" >> "${OUTPUT_FILE}"
            echo "===========================================" >> "${OUTPUT_FILE}"

            X_FILE="${TMP_DIR}/${STEM}_eb_${EB_TAG}.prismtest"
            Z_FILE="${TMP_DIR}/${STEM}_eb_${EB_TAG}.compressed.prismtest"

            rm -f -- "${X_FILE}" "${Z_FILE}"

            append_log $BINARY \
                -i "${FILENAME}" \
                -f -3 "${SIZE_X}" "${SIZE_Y}" "${SIZE_Z}" \
                -R "${EB}" \
                -x "${X_FILE}" \
                -z "${Z_FILE}" \
                --report time,cr \
                --test

            rm -f -- "${X_FILE}" "${Z_FILE}"
        fi

        if $PRISMTESTAT; then
            echo "========================================" >> "${OUTPUT_FILE}"
            echo "Running prism test mode 2" >> "${OUTPUT_FILE}"
            echo "========================================" >> "${OUTPUT_FILE}"

            X_FILE="${TMP_DIR}/${STEM}_eb_${EB_TAG}.prismtest"
            Z_FILE="${TMP_DIR}/${STEM}_eb_${EB_TAG}.compressed.prismtest"

            rm -f -- "${X_FILE}" "${Z_FILE}"

            append_log $BINARY \
                -i "${FILENAME}" \
                -f -3 "${SIZE_X}" "${SIZE_Y}" "${SIZE_Z}" \
                -R "${EB}" \
                -x "${X_FILE}" \
                -z "${Z_FILE}" \
                --report time,cr \
                --test --test-autotune-direction

            rm -f -- "${X_FILE}" "${Z_FILE}"
        fi

        if $PRISMTESTFAT; then
            echo "===================================================" >> "${OUTPUT_FILE}"
            echo "Running prism test mode 3" >> "${OUTPUT_FILE}"
            echo "===================================================" >> "${OUTPUT_FILE}"

            X_FILE="${TMP_DIR}/${STEM}_eb_${EB_TAG}.prismtest"
            Z_FILE="${TMP_DIR}/${STEM}_eb_${EB_TAG}.compressed.prismtest"

            rm -f -- "${X_FILE}" "${Z_FILE}"

            append_log $BINARY \
                -i "${FILENAME}" \
                -f -3 "${SIZE_X}" "${SIZE_Y}" "${SIZE_Z}" \
                -R "${EB}" \
                -x "${X_FILE}" \
                -z "${Z_FILE}" \
                --report time,cr \
                --test --test-fixed-autotune-direction

            rm -f -- "${X_FILE}" "${Z_FILE}"
        fi
    done
done

cleanup_tmp