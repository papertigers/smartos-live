#
# Copyright 2019 Joyent, Inc.
#

# XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX
# This would probably better as somethign that just reads the cache created with
# the mechanism described in the comment at the top of
# src/node_modules/features.js.
# XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX
#
# This library file is intended for use with ksh93 or bash scripts that need to
# access system features.  System features are typically defined in
# /etc/features.d/* in a key-value format.  Each value is a boolean.  The format
# of keys is:
#
# :reverse_dns_domain.:category.:subcat.:feature[.:subfeature]
#
# Concrete examples from various categories follow:
#
# Example 1: Is `zlogin -N` supported?
#
# org.illumos.cmd.zlogin.flags.N=true
#
# Example 2: Does the ipf drive support uuid tags on in and out rules?
#
# com.joyent.driver.ipf.rules.in-out-uuid=true

ILLUMOS_FEATURE_DIR=${ILLUMOS_FEATURE_DIR:-/etc/features.d}

# bash uses `declare -A`, ksh uses `set -A`
builtin declare -A _ILLUMOS_FEATURES 2>/dev/null || set -A _ILLUMOS_FEATURES
_ILLUMOS_FEATURES_LOADED=false

# Populate _ILLUMOS_FEATURES from ILLUMOS_FEATURES_DIR/*.  This is done in a
# function so that local variables are used.  Libraries should not clobber or
# initialize other scripts variables.
function illumos_features_load {
	[[ $_ILLUMOS_FEATURES_LOADED == true ]] && return
	typeset file path line lno junk key value
	typeset dir=$ILLUMOS_FEATURE_DIR
	typeset me=illumos_features_load

	# Sort entries by name.  Presumably they start with a couple digits
	# so that ordering is intentional.
	#
	# In this loop do not use `cat $file | while read ...` or similar
	# because bash and ksh differ which side of the pipe is the subshell.
	for file in $(ls -1 "$dir"); do
		path="$dir/$file"
		if [[ ! -f "$path" || ! -r "$path" ]]; then
			echo "$me: $path: not a readable file" 1>&2
			continue
		fi
		lno=0
		typeset lineno
		while read line junk; do
			let lno=lno+1

			# skip comments and blank lines
			[[ $line == \#* ]] && continue
			[[ -z $line ]] && continue

			if [[ -n "$junk" ]]; then
				echo "$me: $path:$lno: illegal white space" 1>&2
				continue
			fi

			key=${line%=*}
			val=${line#*=}
			if [[ -z "$key" || -z "$val" ]]; then
				echo "$me: $path:$lno: not key=value" 1>&2
				continue
			fi
			if [[ "$val" != true && "$val" != false ]]; then
				echo "$me: $path:$lno: value not boolean" 1>&2
				continue
			fi

			_ILLUMOS_FEATURES["$key"]="$val"
		done <$path
	done
	_ILLUMOS_FEATURES_LOADED=true
}

# Prints the value of the feature to stdout.  May be `true`, `false`, or an
# empty string.
function illumos_feature_get {
	illumos_features_load
	if [[ -z "$1" ]]; then
		echo "illumos_feature_get: missing argument" 1>&2
		return 1
	fi

	echo "${_ILLUMOS_FEATURES[$1]}"
}


# Returns 0 if feature is enabled, else 1
function illumos_feature_enabled {
	illumos_features_load
	if [[ -z "$1" ]]; then
		echo "illumos_feature_enabled: missing argument" 1>&2
		return 1
	fi

	if [[ "${_ILLUMOS_FEATURES[$1]}" == true ]]; then
		return 0
	else
		return 1
	fi
}

function illumos_features_as_json {
	illumos_features_load
	typeset key val comma
	echo "{"
	for key in "${!_ILLUMOS_FEATURES[@]}"; do
		val=${_ILLUMOS_FEATURES["$key"]}
		echo "  $comma \"$key\": \"$val\""
		comma=,
	done
	echo "}"
}

# This file is generally expected to be sourced by another script.  However, it
# can be run on its own with `bash .../features.sh <function> [args]`
if [[ $(basename $0) == features.sh ]] &&
    [[ $1 == illumos_feature_get || $1 == illumos_feature_enabled ||
    $1 == illumos_features_as_json ]]; then
	"$@"
fi
