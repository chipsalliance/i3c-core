#!/usr/bin/env bash

# Process all code-coverage metrics

[[ -z "${I3C_ROOT_DIR}" ]] && echo "I3C_ROOT_DIR must be set!" && exit 1
COVERAGE_DIR="${I3C_ROOT_DIR}/artifacts/coverage"
mkdir -p "${COVERAGE_DIR}"

process_cov_file () {
    dat_file=$1
    out_file="$(dirname "${dat_file}")/$(basename "${dat_file}" .dat)_verilator.info"

    # N.B. this requires features from antmicro/verilator?ref=cond_coverage
    verilator_coverage --skip-toggle --write-info        "${out_file}"                                            "${dat_file}"
    verilator_coverage --toggle-only --write-info        "${out_file%%_all_verilator.info}_toggle_verilator.info" "${dat_file}"
    info-process extract --coverage-type line --output   "${out_file%%_all_verilator.info}_line_verilator.info"   "${out_file}"
    info-process extract --coverage-type cond --output   "${out_file%%_all_verilator.info}_cond_verilator.info"   "${out_file}"
    info-process extract --coverage-type branch --output "${out_file%%_all_verilator.info}_branch_verilator.info" "${out_file}"

    rm "${dat_file}" "${out_file}"
}

# Copy all *.dat coverage databases to a special 'artifacts/coverage' directory for post-processing
pushd verification/cocotb
find -name \*.dat -not -name Vtop\*.dat | xargs cp -Lrv --parents -t "${COVERAGE_DIR}"
popd

# Process each coverage database file to extract the different coverage metrics into individual files
for cov in $(find "${COVERAGE_DIR}" -type f -name \*.dat); do
    process_cov_file "${cov}"
done

# Post-process all coverage files to clean up the outputs and only show relevant data
info_process_args=(
    transform
    --strip-file-prefix "^${I3C_ROOT_DIR}/" # Normalize all paths to the project root
    --filter '^src/'                        # Remove files not under the src/ directory (e.g. third-party)
)
find "${COVERAGE_DIR}" -name '*.info' -exec info-process "${info_process_args[@]}" '{}' \;
