#!/usr/bin/env bash
set -euo pipefail

DATA_TYPE="f32"
SIZE_X=500
SIZE_Y=500
SIZE_Z=100

OUTPUT_DIR="cusz-hi_test_result"
TMP_DIR="${OUTPUT_DIR}/tmp_runs"

BINARY_ORIGIN=/home/moonlightplague/chenwei/cuSZ-Hi-original/build/cuszhi
BINARY_TEST=/home/moonlightplague/chenwei/cuSZ-Hi/build/cuszhi
RUN=true
TEST=true
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

        if $RUN; then
            echo "==============" >> "${OUTPUT_FILE}"
            echo "Running cusz-hi" >> "${OUTPUT_FILE}"
            echo "==============" >> "${OUTPUT_FILE}"

            append_log $BINARY_ORIGIN \
                -t "${DATA_TYPE}" \
                -m r2r \
                -e "${EB}" \
                -i "${FILENAME}" \
                -l "${SIZE_X}x${SIZE_Y}x${SIZE_Z}" \
                -s tp \
                -z --report time

            append_log $BINARY_ORIGIN \
                -i "${FILENAME}.cusza" \
                -x --report time \
                --compare "${FILENAME}"

            rm -f -- "${FILENAME}.cusza"
            rm -f -- "${FILENAME}.cuszx"
        fi

        if $TEST; then
            echo "===========================================" >> "${OUTPUT_FILE}"
            echo "Running cusz-hi test mode" >> "${OUTPUT_FILE}"
            echo "===========================================" >> "${OUTPUT_FILE}"

            append_log $BINARY_TEST \
                -t "${DATA_TYPE}" \
                -m r2r \
                -e "${EB}" \
                -i "${FILENAME}" \
                -l "${SIZE_X}x${SIZE_Y}x${SIZE_Z}" \
                -s tp \
                -z --report time

            append_log $BINARY_TEST \
                -i "${FILENAME}.cusza" \
                -x --report time \
                --compare "${FILENAME}"

            rm -f -- "${FILENAME}.cusza"
            rm -f -- "${FILENAME}.cuszx"
        fi
    done
done

cleanup_tmp