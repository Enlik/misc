# this is to create a friendly log for equo that
# records the most important actions

# usage: save this script as /root/SCRIPT_NAME (pick any name you like)
# and put ". ~/SCRIPT_NAME" into /root/.bashrc (assuming bash)

equo() {
	local log="/var/log/equo.log"
	local log_command=0
	local command_is_known=0
	local arg
	for arg in "$@"; do
		case $arg in
		-p|--pretend|-h|--help)
			log_command=0
			break
		;;
		-*)
			continue
		;;
		install|i | remove|rm | update|up | upgrade|u | conf | rescue | repo)
			# skip commands like: equo do-something-not-logged --funny conf
			if [ $command_is_known = 0 ]; then
				log_command=1
				command_is_known=1
			fi
		;;
		*)
			if [ $command_is_known = 0 ]; then
				log_command=0
				break
			fi
		;;
		# Traverse all arguments looking for -p/--pretend. Note: some subcommands
		# don't take them.
		esac
	done
	[ "$log_command" = 1 ] && echo "$(date): equo $*" >> "$log"
	/usr/bin/equo "$@"
}
