#!/bin/bash

# Create packages on which nothing depends.
# Important fact that makes it work as intended is that 'equo query revdeps'
# seems to take care of PDEPENDs as well.


#    Copyright 2017, Sławomir Nizio

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

set -e

ps=$(equo query list installed -qv)

echo "got $(echo "$ps" | wc -l) inst. packages" >&2

vsedcmd='s/-[0-9.]+[a-z]?(((_p|_pre|_beta)[0-9]+)|_rc[0-9]*)*(-r[0-9]+)?$//'

LANG=en_US.UTF-8 equo query revdeps $ps \
	| egrep 'Matched:|Found:' \
	| awk '{ if(NR%2 == 0) { if($0 ~ /Found: * 0 entries/) print pkgline } else { pkgline=$0 } }' \
	| sed -r 's/.* ([^ ]+)$/\1/' \
	| sed -r "$vsedcmd"
