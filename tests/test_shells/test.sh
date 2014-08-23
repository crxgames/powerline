#!/bin/bash
: ${PYTHON:=python}
FAILED=0
ONLY_SHELL="$1"
ONLY_TEST_TYPE="$2"
COMMAND_PATTERN="$3"

export PYTHON

if test "x$ONLY_SHELL" = "x--help" ; then
cat << EOF
Usage:
	$0 [[[ONLY_SHELL | ""] (ONLY_TEST_TYPE | "")] (COMMAND_PATTERN | "")]

ONLY_SHELL: execute only tests for given shell
ONLY_TEST_TYPE: execute only "daemon" or "nodaemon" tests
COMMAND_PATTERN: use only commands that match given pattern for testing
EOF
fi

check_screen_log() {
	TEST_TYPE="$1"
	TEST_CLIENT="$2"
	SH="$3"
	if test -e tests/test_shells/${SH}.${TEST_TYPE}.ok ; then
		diff -a -u tests/test_shells/${SH}.${TEST_TYPE}.ok tests/shell/${SH}.${TEST_TYPE}.${TEST_CLIENT}.log
		return $?
	elif test -e tests/test_shells/${SH}.ok ; then
		diff -a -u tests/test_shells/${SH}.ok tests/shell/${SH}.${TEST_TYPE}.${TEST_CLIENT}.log
		return $?
	else
		cat tests/shell/${SH}.${TEST_TYPE}.${TEST_CLIENT}.log
		return 1
	fi
}

run() {
	TEST_TYPE="$1"
	shift
	TEST_CLIENT="$1"
	shift
	SH="$1"
	shift
	local local_path="$PWD/tests/shell/path:$PWD/scripts"
	if test "x$SH" = "xfish" ; then
		local_path="${local_path}:/usr/bin:/bin"
	fi
	if test $TEST_TYPE = daemon ; then
		local additional_prompts=1
	else
		local additional_prompts=
	fi
	env -i \
		PATH="$local_path" \
		TERM="${TERM}" \
		COLUMNS="${COLUMNS}" \
		LINES="${LINES}" \
		TEST_TYPE="${TEST_TYPE}" \
		TEST_CLIENT="${TEST_CLIENT}" \
		SH="${SH}" \
		DIR1="${DIR1}" \
		DIR2="${DIR2}" \
		XDG_CONFIG_HOME="$PWD/tests/shell/fish_home" \
		IPYTHONDIR="$PWD/tests/shell/ipython_home" \
		POWERLINE_SHELL_CONTINUATION=$additional_prompts \
		POWERLINE_SHELL_SELECT=$additional_prompts \
		POWERLINE_COMMAND="${POWERLINE_COMMAND}" \
		"$@"
}

run_test() {
	TEST_TYPE="$1"
	shift
	TEST_CLIENT="$1"
	shift
	SH="$1"
	SESNAME="powerline-shell-test-${SH}-$$"
	ARGS=( "$@" )

	run "${TEST_TYPE}" "${TEST_CLIENT}" "${SH}" \
		screen -L -c tests/test_shells/screenrc -d -m -S "$SESNAME" \
			env LANG=en_US.UTF-8 BINDFILE="$BINDFILE" "${ARGS[@]}"
	while ! screen -S "$SESNAME" -X readreg a tests/test_shells/input.$SH ; do
		sleep 0.1s
	done
	# Wait for screen to initialize
	sleep 1
	while ! screen -S "$SESNAME" -p 0 -X width 300 1 ; do
		sleep 0.1s
	done
	if test "x${SH}" = "xdash" ; then
		# If I do not use this hack for dash then output will look like
		#
		#     command1
		#     command2
		#     …
		#     prompt1> prompt2> …
		while read -r line ; do
			screen -S "$SESNAME" -p 0 -X stuff "$line"$'\n'
			sleep 1
		done < tests/test_shells/input.$SH
	else
		screen -S "$SESNAME" -p 0 -X paste a
	fi
	# Wait for screen to exit (sending command to non-existing screen session 
	# fails; when launched instance exits corresponding session is deleted)
	while screen -S "$SESNAME" -X blankerprg "" > /dev/null ; do
		sleep 0.1s
	done
	./tests/test_shells/postproc.py ${TEST_TYPE} ${TEST_CLIENT} ${SH}
	rm -f tests/shell/3rd/pid
	if ! check_screen_log ${TEST_TYPE} ${TEST_CLIENT} ${SH} ; then
		echo '____________________________________________________________'
		if test "x$POWERLINE_TEST_NO_CAT_V" != "x1" ; then
			# Repeat the diff to make it better viewable in travis output
			echo "Diff (cat -v):"
			echo '============================================================'
			check_screen_log  ${TEST_TYPE} ${TEST_CLIENT} ${SH} | cat -v
			echo '____________________________________________________________'
		fi
		echo "Failed ${SH}. Full output:"
		echo '============================================================'
		cat tests/shell/${SH}.${TEST_TYPE}.${TEST_CLIENT}.full.log
		echo '____________________________________________________________'
		if test "x$POWERLINE_TEST_NO_CAT_V" != "x1" ; then
			echo "Full output (cat -v):"
			echo '============================================================'
			cat -v tests/shell/${SH}.${TEST_TYPE}.${TEST_CLIENT}.full.log
			echo '____________________________________________________________'
		fi
		case ${SH} in
			*ksh)
				${SH} -c 'echo ${KSH_VERSION}'
				;;
			dash)
				# ?
				;;
			busybox)
				busybox --help
				;;
			*)
				${SH} --version
				;;
		esac
		if which dpkg >/dev/null ; then
			dpkg -s ${SH}
		fi
		return 1
	fi
	return 0
}

test -d tests/shell && rm -r tests/shell
mkdir tests/shell
git init tests/shell/3rd
git --git-dir=tests/shell/3rd/.git checkout -b BRANCH
export DIR1="[32m"
export DIR2=""
mkdir tests/shell/3rd/"$DIR1"
mkdir tests/shell/3rd/"$DIR2"
mkdir tests/shell/3rd/'\[\]'
mkdir tests/shell/3rd/'%%'
mkdir tests/shell/3rd/'#[bold]'
mkdir tests/shell/3rd/'(echo)'
mkdir tests/shell/3rd/'$(echo)'
mkdir tests/shell/3rd/'`echo`'

mkdir tests/shell/fish_home
cp -r tests/test_shells/ipython_home tests/shell

mkdir tests/shell/path
ln -s "$(which "${PYTHON}")" tests/shell/path/python
ln -s "$(which screen)" tests/shell/path
ln -s "$(which env)" tests/shell/path
ln -s "$(which sleep)" tests/shell/path
ln -s "$(which cat)" tests/shell/path
ln -s "$(which false)" tests/shell/path
ln -s "$(which true)" tests/shell/path
ln -s "$(which kill)" tests/shell/path
ln -s "$(which echo)" tests/shell/path
ln -s "$(which which)" tests/shell/path
ln -s "$(which dirname)" tests/shell/path
ln -s "$(which wc)" tests/shell/path
ln -s "$(which stty)" tests/shell/path
ln -s "$(which cut)" tests/shell/path
ln -s "$(which bc)" tests/shell/path
ln -s "$(which expr)" tests/shell/path
ln -s "$(which mktemp)" tests/shell/path
ln -s "$(which grep)" tests/shell/path
ln -s "$(which sed)" tests/shell/path
ln -s "$(which rm)" tests/shell/path
ln -s ../../test_shells/bgscript.sh tests/shell/path
ln -s ../../test_shells/waitpid.sh tests/shell/path
if which socat ; then
	ln -s "$(which socat)" tests/shell/path
fi
for pexe in powerline powerline-config ; do
	if test -e scripts/$pexe ; then
		ln -s "$PWD/scripts/$pexe" tests/shell/path
	elif which $pexe ; then
		ln -s "$(which $pexe)" tests/shell/path
	else
		echo "Executable $pexe was not found"
		exit 1
	fi
done

for exe in bash zsh busybox fish tcsh mksh dash ipython ; do
	if which $exe >/dev/null ; then
		ln -s "$(which $exe)" tests/shell/path
	fi
done

unset ENV

if test -z "${ONLY_SHELL}" || test "x${ONLY_SHELL%sh}" != "x${ONLY_SHELL}" || test "x${ONLY_SHELL}" = xbusybox ; then
	powerline-daemon -k || true
	sleep 1s

	scripts/powerline-config shell command

	for TEST_TYPE in "daemon" "nodaemon" ; do
		if test $TEST_TYPE = daemon ; then
			sh -c 'echo $$ > tests/shell/daemon_pid; $PYTHON ./scripts/powerline-daemon -f &>tests/shell/daemon_log' &
		fi
		if test "x$ONLY_TEST_TYPE" != "x" && test "x$ONLY_TEST_TYPE" != "x$TEST_TYPE" ; then
			continue
		fi
		echo "> Testing $TEST_TYPE"
		for POWERLINE_COMMAND in "" \
			$PWD/scripts/powerline \
			$PWD/scripts/powerline-render \
			"$PYTHON $PWD/client/powerline.py" \
			$PWD/client/powerline.sh
		do
			case "$POWERLINE_COMMAND" in
				*powerline)        TEST_CLIENT=C ;;
				*powerline-render) TEST_CLIENT=render ;;
				*powerline.py)     TEST_CLIENT=python ;;
				*powerline.sh)     TEST_CLIENT=shell ;;
				"")                TEST_CLIENT=auto ;;
			esac
			if test "$TEST_CLIENT" = "C" && ! test -x scripts/powerline ; then
				if which powerline >/dev/null ; then
					POWERLINE_COMMAND=powerline
				else
					continue
				fi
			fi
			if test "$TEST_CLIENT" = "shell" && ! which socat >/dev/null ; then
				continue
			fi
			if test "$TEST_CLIENT" = render && test "$TEST_TYPE" = daemon ; then
				continue
			fi
			if test "x$COMMAND_PATTERN" != "x" && ! (
				echo "$POWERLINE_COMMAND" | grep -e"$COMMAND_PATTERN" &>/dev/null)
			then
				continue
			fi
			export POWERLINE_COMMAND
			echo ">> powerline command is ${POWERLINE_COMMAND:-empty}"
			for TEST_COMMAND in \
				"bash --norc --noprofile -i" \
				"zsh -f -i" \
				"fish -i" \
				"tcsh -f -i" \
				"busybox ash -i" \
				"mksh -i" \
				"dash -i"
			do
				SH="${TEST_COMMAND%% *}"
				if test "x$ONLY_SHELL" != "x" && test "x$ONLY_SHELL" != "x$SH" ; then
					continue
				fi
				if ! which $SH >/dev/null ; then
					continue
				fi
				echo ">>> $(which $SH)"
				if ! run_test $TEST_TYPE $TEST_CLIENT $TEST_COMMAND ; then
					# dash tests are not stable, see #931
					if test "x$SH" != "xdash" ; then
						FAILED=1
					fi
				fi
			done
		done
		if test $TEST_TYPE = daemon ; then
			$PYTHON ./scripts/powerline-daemon -k
			wait $(cat tests/shell/daemon_pid)
			if ! test -z "$(cat tests/shell/daemon_log)" ; then
				echo '____________________________________________________________'
				echo "Daemon log:"
				echo '============================================================'
				cat tests/shell/daemon_log
				FAILED=1
			fi
		fi
	done
fi

if ! $PYTHON scripts/powerline-daemon &> tests/shell/daemon_log_2 ; then
	echo "Daemon exited with status $?"
	FAILED=1
else
	sleep 1
	$PYTHON scripts/powerline-daemon -k
fi

if ! test -z "$(cat tests/shell/daemon_log_2)" ; then
	FAILED=1
	echo '____________________________________________________________'
	echo "Daemon log (2nd):"
	echo '============================================================'
	cat tests/shell/daemon_log_2
	FAILED=1
fi

if test "x${ONLY_SHELL}" = "x" || test "x${ONLY_SHELL}" = "xipython" ; then
	echo "> $(which ipython)"
	if ! run_test ipython ipython ipython ; then
		FAILED=1
	fi
fi

test $FAILED -eq 0 && rm -r tests/shell
exit $FAILED
