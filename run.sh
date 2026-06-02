set -euo pipefail

EB="1e-1"
FILENAME="TCf48.bin.f32"
DATA_TYPE="f32"
SIZE_X=500
SIZE_Y=500
SIZE_Z=100
OUTPUT_DIR="output/"
VIS=false
#OUTPUT_DIR="${OUTPUT_FOLDER}${FILENAME}"

mkdir -p $OUTPUT_DIR

OUTPUT_FILE="${OUTPUT_DIR}${FILENAME}.log"
touch "${OUTPUT_FILE}"

sanitize_log_output() {
    LC_ALL=C sed -E $'s/\x1B\\[[0-?]*[ -/]*[@-~]//g; s/[^[:print:]\t]//g'
}

append_log() {
    "$@" 2>&1 | sanitize_log_output >> "${OUTPUT_FILE}"
}

echo "==============" > "${OUTPUT_FILE}"
echo "Running cuszhi" >> "${OUTPUT_FILE}"
echo "==============" >> "${OUTPUT_FILE}"

append_log cuszhi \
    -t "${DATA_TYPE}" \
    -m abs \
    -e "${EB}" \
    -i "${FILENAME}" \
    -l "${SIZE_X}x${SIZE_Y}x${SIZE_Z}" \
    -z --report time

append_log cuszhi \
    -i "${FILENAME}.cusza" \
    -x --report time \
    --compare "${FILENAME}"

echo "==============" >> "${OUTPUT_FILE}"
echo "Running cuszi" >> "${OUTPUT_FILE}"
echo "==============" >> "${OUTPUT_FILE}"

append_log cuszi \
    -t "${DATA_TYPE}" \
    -m abs \
    -e "${EB}" \
    -i "${FILENAME}" \
    -l "${SIZE_X}x${SIZE_Y}x${SIZE_Z}" \
    -z --report time

append_log cuszi \
    -i "${FILENAME}.cusza" \
    -x --report time \
    --compare "${FILENAME}"

echo "==============" >> "${OUTPUT_FILE}"
echo "Running cuszp" >> "${OUTPUT_FILE}"
echo "==============" >> "${OUTPUT_FILE}"

append_log cuszp \
    -i "${FILENAME}" \
    -t "${DATA_TYPE}" \
    -m "outlier" \
    -d 3 $SIZE_Z $SIZE_Y $SIZE_X \
    -eb abs "${EB}" \
    -o "${FILENAME}.cuszp"

append_log psnr \
    "${FILENAME}.cuszp" \
    "${FILENAME}" \
    "${DATA_TYPE}"

echo "==============" >> "${OUTPUT_FILE}"
echo "Running sz3" >> "${OUTPUT_FILE}"
echo "==============" >> "${OUTPUT_FILE}"

append_log sz3 \
    -f -i "${FILENAME}" \
    -o "${FILENAME}.sz3" \
    -3 "${SIZE_X}" "${SIZE_Y}" "${SIZE_Z}" \
    -M ABS "${EB}" \
    -a

echo "==============" >> "${OUTPUT_FILE}"
echo "Running prism" >> "${OUTPUT_FILE}"
echo "==============" >> "${OUTPUT_FILE}"

append_log prism \
    -i "${FILENAME}" \
    -f -3 "${SIZE_Z}" "${SIZE_Y}" "${SIZE_X}" \
    -A "${EB}" \
    -x "${FILENAME}.prism" \
    -z "${FILENAME}.compressed.prism" \
    --report time,cr

if $VIS; then
python tools/visualization.py \
    --output-dir "${OUTPUT_DIR}" \
    "${FILENAME}" "${FILENAME}.cuszx" "${FILENAME}.cuszp" "${FILENAME}.sz3"
fi

rm *.cusza *.cuszp *.cuszx *.sz3 *.prism