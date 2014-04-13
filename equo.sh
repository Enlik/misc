# this is to create a friendly log for equo that
# records the most important actions

# usage: save this script as /root/SCRIPT_NAME (pick any name you like)
# and put ". ~/SCRIPT_NAME" into /root/.bashrc (assuming bash)

equo() {
	local log="/var/log/equo.log"
	local log_command=0
	local arg
	for arg in "$@"; do
		case $arg in
		install|i | remove|rm | update|up | upgrade|u | conf | rescue | repo)
			log_command=1
		;;
		-p|--pretend)
			log_command=0
			break
		;;
		-*)
			continue
		;;
		*)
			# this will cause that -p/--pretend that is
			# too far from the beginning (equo install pkg -p)
			# would still be logged, but who knows a -p that far
			# would always mean pretend for any subcommand
			break
		;;
		esac
	done
	[ "$log_command" = 1 ] && echo "$(date): equo $*" >> "$log"
	/usr/bin/equo "$@"
}
