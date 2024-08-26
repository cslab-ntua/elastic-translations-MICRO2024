export WGET="wget -q -O-"
export FILE_HOST="83.212.99.29"

export BASE="${BASE:-/root/elastic-translations-MICRO2024}"
source "${BASE}/env/base.env"
pushd "${BASE}"

ok() {
        echo -e "[\033[0;32mOK\033[0m] ${@}"
}

fail() {
        echo -e "[\033[0;31mFAILED\033[0m] ${@}"
        exit 1
}

check() {
        [ $# -eq 2 -o $# -eq 3 ] || fail "internal: invalid check args"
        cmd="${1}"
        msg="${2}"
        [ -z ${3} ] && fmsg="${msg}"

        eval ${cmd} && ok "${msg}" || fail "${fmsg}"
}

cleanup() {
	FAILED=0
	[ $? -ne 0 ] && FAILED=1

	while popd &>/dev/null; do true; done

	[ ${FAILED} -eq 1 ] && fail "${0} failed, exiting..."
	ok "${0} finished, exiting..."
}
trap cleanup EXIT
