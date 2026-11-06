#!/usr/bin/env bash
set -Eeuo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LC_ALL=C
unset BASH_ENV ENV
umask 022

if [[ ${EUID} -ne 0 || ( ! -f /.dockerenv && ! -f /run/.containerenv ) ]]; then
    printf '%s\n' 'error: run this test as root inside a disposable Rocky container' >&2
    exit 2
fi

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_DIR="$(mktemp -d -t pkg-python.XXXXXXXX)"
RELEASE="$(rpm -q --qf '%{VERSION}' rocky-release)"
readonly SOURCE_DIR EVIDENCE_DIR RELEASE
readonly MAJOR="${RELEASE%%.*}"
readonly TARGET=/usr/bin/python3
readonly LINK=/usr/local/bin/python
readonly GROUP=pkg-automation-python
declare -g ASSERTIONS=0
declare -g FAILED=0
declare -g COMPLETE=0
declare -g CURRENT_STAGE=initialization
declare -a providers=()

function finish {
    local rc=$?

    printf 'Evidence: %s\nAssertions: %d\n' "${EVIDENCE_DIR}" "${ASSERTIONS}"
    if [[ ${FAILED} -ne 0 ]]; then
        printf '%s\n' '[VERDICT] Failed'
    elif [[ ${rc} -ne 0 || ${COMPLETE} -ne 1 ]]; then
        printf '[VERDICT] Incomplete at %s (native status %d)\n' "${CURRENT_STAGE}" "${rc}"
        [[ ${rc} -ne 0 ]] || rc=2
    else
        printf '%s\n' '[VERDICT] Passed'
    fi
    exit "${rc}"
}

function expect_equal {
    local label="$1"
    local expected="$2"
    local actual="$3"

    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ "${actual}" != "${expected}" ]]; then
        FAILED=1
        printf '[FAIL] %s\nExpected: %s\nActual: %s\n' "${label}" "${expected}" "${actual}" >&2
        exit 1
    fi
    printf '[PASS] %s\n' "${label}"
}

function run_installer {
    local label="$1"
    local expected="${2:-0}"
    local rc=0

    CURRENT_STAGE="${label}"
    bash "${SOURCE_DIR}/pkg_automation.bash" -y > "${EVIDENCE_DIR}/${label}.log" 2>&1 || rc=$?
    printf '%d\n' "${rc}" > "${EVIDENCE_DIR}/${label}.status"
    expect_equal "${label}: installer status" "${expected}" "${rc}"
}

function expect_python {
    local label="$1"
    local expected=""
    local actual=""
    local rc=0

    expected="$("${TARGET}" -c 'import os, sys; print(os.path.realpath(sys.executable)); print(sys.version_info[:3]); sys.exit(sys.version_info[0] != 3)')"
    actual="$(python -c 'import os, sys; print(os.path.realpath(sys.executable)); print(sys.version_info[:3]); sys.exit(sys.version_info[0] != 3)' 2> "${EVIDENCE_DIR}/${label}.stderr")" || rc=$?
    expect_equal "${label}: python execution" 0 "${rc}"
    expect_equal "${label}: selected interpreter and version" "${expected}" "${actual}"
    actual="$(PATH=/usr/sbin:/usr/bin:/sbin:/bin python -c 'import os, sys; print(os.path.realpath(sys.executable)); print(sys.version_info[:3]); sys.exit(sys.version_info[0] != 3)' 2> "${EVIDENCE_DIR}/${label}-system-path.stderr")" || rc=$?
    expect_equal "${label}: system PATH execution" 0 "${rc}"
    expect_equal "${label}: system PATH interpreter and version" "${expected}" "${actual}"
}

function expect_selection {
    local label="$1"
    local mode=""

    expect_equal "${label}: managed command" "/etc/alternatives/${GROUP}" "$(readlink "${LINK}")"
    expect_equal "${label}: selected target" "${TARGET}" "$(readlink "/etc/alternatives/${GROUP}")"
    alternatives --display "${GROUP}" > "${EVIDENCE_DIR}/${label}.alternatives"
    IFS= read -r mode < "/var/lib/alternatives/${GROUP}"
    expect_equal "${label}: manual selection" manual "${mode}"
}

trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

case "${MAJOR}" in
    8|9|10) ;;
    *) printf 'error: unsupported Rocky release %s\n' "${RELEASE}" >&2; exit 2 ;;
esac

sha256sum "${SOURCE_DIR}/pkg_automation.bash" "${BASH_SOURCE[0]}" "${SOURCE_DIR}"/pkg-*/* > "${EVIDENCE_DIR}/sources.sha256"
printf 'Rocky %s\n' "${RELEASE}"
sha256sum "${SOURCE_DIR}/pkg_automation.bash" "${BASH_SOURCE[0]}"
run_installer fresh
expect_python fresh

CURRENT_STAGE=provider-query
provider_names="$(rpm -qf --qf '%{NAME}\n' "${TARGET}")"
mapfile -t providers <<< "${provider_names}"
printf 'RPM providers: %s\n' "${providers[*]}"
if [[ "${MAJOR}" == 8 ]]; then
    CURRENT_STAGE=install-python39
    dnf -y install python39 > "${EVIDENCE_DIR}/install-python39.log" 2>&1
    expect_python after-python39
    CURRENT_STAGE=reinstall-providers
    dnf -y reinstall "${providers[@]}" python39 > "${EVIDENCE_DIR}/reinstall-providers.log" 2>&1
else
    CURRENT_STAGE=reinstall-providers
    dnf -y reinstall "${providers[@]}" python-unversioned-command > "${EVIDENCE_DIR}/reinstall-providers.log" 2>&1
fi
expect_python after-rpm-reinstall
expect_selection after-rpm-reinstall

candidate=/usr/bin/false
if [[ "${MAJOR}" == 8 ]]; then
    candidate=/usr/bin/python3.9
fi
alternatives --install "${LINK}" "${GROUP}" "${candidate}" 9999 > "${EVIDENCE_DIR}/higher-priority.log" 2>&1
expect_python after-higher-priority
expect_selection after-higher-priority

alternatives --set "${GROUP}" "${candidate}" > "${EVIDENCE_DIR}/wrong-selection.log" 2>&1
expect_equal 'wrong selection reached the real command' "$(readlink -f "${candidate}")" "$(readlink -f "${LINK}")"
run_installer repair-selection
expect_python repaired-selection
expect_selection repaired-selection

case "${MAJOR}" in
    8) legacy=/usr/bin/unversioned-python ;;
    9) legacy=/usr/bin/python ;;
    10) legacy=/usr/bin/python3 ;;
esac
ln -sfn "${legacy}" "${LINK}"
run_installer repair-legacy
expect_python repaired-legacy
expect_selection repaired-legacy

printf '%s\n' '#!/usr/bin/env bash' 'exit 42' > "${EVIDENCE_DIR}/unmanaged-python"
chmod 755 "${EVIDENCE_DIR}/unmanaged-python"
cp -p "${EVIDENCE_DIR}/unmanaged-python" "${EVIDENCE_DIR}/unmanaged-reference"
mv -T "${EVIDENCE_DIR}/unmanaged-python" "${LINK}"
run_installer reject-unmanaged-file 1
cmp "${EVIDENCE_DIR}/unmanaged-reference" "${LINK}"
expect_equal 'unmanaged file content and mode preserved' 755 "$(stat -c '%a' "${LINK}")"
grep -Fxq "error: refusing to replace unmanaged ${LINK}" "${EVIDENCE_DIR}/reject-unmanaged-file.log"

ln -sfn /usr/bin/false "${LINK}"
run_installer reject-unmanaged-link 1
expect_equal 'unmanaged link preserved' /usr/bin/false "$(readlink "${LINK}")"
grep -Fxq "error: refusing to replace unmanaged ${LINK} -> /usr/bin/false" "${EVIDENCE_DIR}/reject-unmanaged-link.log"

ln -sfn "${TARGET}" "${LINK}"
run_installer final-repair
expect_python final
expect_selection final
CURRENT_STAGE=provider-scriptlets
rpm -q --scripts "${providers[@]}" > "${EVIDENCE_DIR}/provider-scripts.txt"
CURRENT_STAGE=source-manifest
sha256sum -c "${EVIDENCE_DIR}/sources.sha256" > "${EVIDENCE_DIR}/sources-check.log"
COMPLETE=1
