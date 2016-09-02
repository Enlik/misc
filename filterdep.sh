#!/bin/bash

# Filter strings like REQUIRED_USE or DEPEND (ebuilds use those) taking into
# consideration flags.
# For example, if "a" is set, "a? ( b )" would result in "( b )".
# Maybe-todo: filter brackets noise if needed (should be trivial).

#    Copyright 2016, Sławomir Nizio

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.


set_shell_settings() {
	local ret
	set -f
	shopt -s extglob
	"$@"
	ret=$?
	shopt -u extglob
	set +f
	return ${ret}
}


_match() {
	local use match=0
	local mytok=${tok%?}

	local ret_idx=1

	if [[ ${mytok} = !* ]]; then
		ret_idx=0 # reverse meaning of match in return
		mytok=${mytok#!}
	fi

	for use in ${use_items}; do
		if [[ " ${mytok} " = *" ${use} "* ]]; then
			match=1
			break
		fi
	done
	return $(( ret_idx - match ))
}

filteruse() {
	local depstr=$1
	local use_items=$2
	local depstr_result

	local in_brackets_lvl=0
	local stepdown_to_lvl=
	local _this_tok_type=
	local last_tok_type=
	local so_far=

	local use_pattern='?(!)!(-)+([a-z0-9-])\?'
	local tok
	for tok in ${depstr}; do
		#echo "token -> ${tok}" >&2
		so_far+=" ${tok}"
		case ${tok} in
			${use_pattern})
				_this_tok_type=use
				if [[ ${last_tok_type} = use ]]; then
					echo "was 'use?' token already, tok='${tok}', until '${so_far# }'" >&2
					return 1
				fi

				if [[ -n ${stepdown_to_lvl} ]]; then
					if (( in_brackets_lvl >= stepdown_to_lvl )); then
						true # skip
					else
						echo "req. level to skip to '${stepdown_to_lvl}' < current '${in_brackets_lvl}'" >&2
						return 1
					fi
				else
					if ! _match; then
						stepdown_to_lvl=${in_brackets_lvl}
					fi
				fi
			;;

			'(')
				_this_tok_type=openbracket
				if [[ ${last_tok_type} != use ]] && [[ -n ${last_tok_type} ]]; then
					echo "was not 'use?' token, but ${last_tok_type}, tok='${tok}', until '${so_far# }'" >&2
					return 1
				fi
				(( in_brackets_lvl++ ))
				[[ -z ${stepdown_to_lvl} ]] && depstr_result+=" ${tok}"
			;;

			')')
				_this_tok_type=closebracket
				if (( in_brackets_lvl == 0 )); then
					echo "not in any 'use?', tok='${tok}', until '${so_far# }'" >&2
					return 1
				fi
				if [[ -z ${stepdown_to_lvl} ]]; then
					depstr_result+=" ${tok}"
				else
					if (( stepdown_to_lvl == in_brackets_lvl - 1 )); then
						stepdown_to_lvl=
					fi
				fi
				(( in_brackets_lvl-- ))
			;;

			*)
				_this_tok_type=atom
				[[ -z ${stepdown_to_lvl} ]] && depstr_result+=" ${tok}"
			;;
		esac
		#echo "token -> ${tok} of type ${_this_tok_type}" >&2
		last_tok_type=${_this_tok_type}
	done

	if (( in_brackets_lvl > 0 )); then
		echo "not closed ${in_brackets_lvl} bracket(s)" >&2
		return 1
	fi

	echo "${depstr_result# }"
}

assert_eq() {
	local exp=$1
	shift
	local res
	res=$(set_shell_settings filteruse "$@") || exit 1
	if [[ ${res} = "${exp}" ]]; then
		echo "ok: ${res}"
	else
		echo "!!! fail with '$*'"
		echo "    got: '${res}'"
		echo "    exp: '${exp}'"
		exit 1
	fi
}

# Currently there are tests for correct strings only.

# basic
assert_eq "bla" "bla"
assert_eq "bla" "bla" "use1 use2"
# not nested
assert_eq "" "x? ( a b c )"
assert_eq "( a b c )" "x? ( a b c )" "x"
assert_eq "( a b c )" "x? ( a b c )" "x y z"
assert_eq "( a b c )" "y? ( a b c )" "x y z"
assert_eq "( a b c )" "z? ( a b c )" "x y z"
assert_eq "" "!x? ( a b c )" "x"
assert_eq "( b )" "x? ( a ) !x? ( b )"
assert_eq "( b )" "x? ( a ) !x? ( b )" "z"
assert_eq "( a )" "x? ( a ) !x? ( b )" "x"
assert_eq "( a b c )" "!x? ( a b c )"
assert_eq "( a b c )" "!x? ( a b c )" "y"
assert_eq "( a b c )" "!x? ( a b c )" "y z"
# nested
assert_eq "( a ( b ) )" "x? ( a y? ( b ) )" "x y"
assert_eq "( a )" "x? ( a y? ( b ) )" "x"
assert_eq "" "x? ( a y? ( b ) )" "y"
assert_eq "" "x? ( a y? ( b ) )" "z"
# more complicated
dep="ua? ( a b ub? ( c !uc? ( d ) ) ) e ud? ( ) ue? ( f )"
assert_eq "e" "${dep}"
assert_eq "( a b ) e" "${dep}" "ua"
assert_eq "( a b ( c ( d ) ) ) e" "${dep}" "ua ub"
assert_eq "( a b ( c ) ) e" "${dep}" "ua ub uc"
assert_eq "( a b ( c ) ) e ( )" "${dep}" "ua ub uc ud"
assert_eq "( a b ( c ) ) e ( ) ( f )" "${dep}" "ua ub uc ud ue"
assert_eq "e ( ) ( f )" "${dep}" "ub uc ud ue"
assert_eq "e ( ) ( f )" "${dep}" "uc ud ue"
assert_eq "e ( ) ( f )" "${dep}" "ud ue"
assert_eq "e ( f )" "${dep}" "ue"
# deeply nested
dep=
for i in {1..100}; do
	dep+=" use${i}? ("
done
for i in {1..100}; do
	dep+=" )"
done
assert_eq "$(echo "${dep# }" | sed 's/use[0-9]*? //g')" "${dep}" "$(echo use{1..1000})"
# weird
assert_eq "( a )" "( a )"
assert_eq "( )" "( )"
