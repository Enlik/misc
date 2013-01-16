# this is to create a friendly log for equo that
# records the most important actions

# usage: save this script as /root/SCRIPT_NAME (pick any name you like)
# and put ". ~/SCRIPT_NAME" into /root/.bashrc (assuming bash)

equo() {
	local log="/var/log/equo.log"
	local executed=0
	local arg
	for arg in "$@"; do
		case $arg in
		install|remove|update|upgrade|conf|rescue|repo)
			executed=1
			echo "$(date): equo $*" >> "$log"
			/usr/bin/equo "$@"
		;;
		-*)
			executed=0
			continue
		;;
		*)
			executed=1
			/usr/bin/equo "$@"
		;;
		esac
		break
	done
	[ "$executed" = 0 ] && /usr/bin/equo "$@"
}
