#! /bin/sh

CMD="$1"
INITD="$2"
SLEEP=""

start() {
	if [ -d "$INITD" ]; then
		echo "Launching initialization scripts"
		for f in $INITD/S*; do
			# echo "file: $f"
			[ -x "$f" ] && "$f" start
		done
	else
		echo "error: %s directory not found" 1>&2
		exit 1
	fi
}

stop() {
	if [ -d "$INITD" ]; then
		echo "Launching termination scripts"
		for f in $INITD/K*; do
			[ -x "$f" ] && "$f" stop
		done
	else
		echo "error: %s directory not found" 1>&2
		exit 1
	fi
}

restart() {
	stop "$1"
	start "$1"
}

_term() {
	trap "" TERM INT
	stop
	[ -n "$SLEEP" ] && kill $SLEEP
	SLEEP=""
	exit 0
}

service() {
	start
	trap _term TERM INT
	while : 
	do
		sleep infinity &
		SLEEP=$!
		wait $!
	done
}

INITD=/home/skywind/tmp/init.d

service


