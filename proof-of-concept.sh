#!/bin/sh
# @file - clang-toolbox-proof-of-concept.sh
# @brief - A shell script that tests if the Clang+LLVM binary builds are
#   similar enough in structure for scraping files out of independant
#   of OS and arch.
# @copyright (C) 2021  Ruby Allison Rose
# SPDX-License-Identifier: GPL-3.0-only


SELF=$(readlink -nf "$0");
PROCDIR="$(dirname "$SELF")";
URL="https://api.github.com/repos/llvm/llvm-project/releases";
TMP="${XDG_RUNTIME_DIR:-/tmp}";
TEMPDIR="$(mktemp -p "$TMP" -d clang-toolbox-heuristics.XXXXXXXXX)";
JSON1="$TEMPDIR/json1";
JSON2="$TEMPDIR/json2";
TARFILEPREFIX="$TEMPDIR/build.tar";


# @describe - Tokenizes a string into semver segments, or throws an error.
tokenize_semver_string(){
	s="$1"; l=0; major='0'; minor='0'; patch='0'; prerelease=''; buildmetadata='';

	# Check for build metadata or prerelease
	f="${s%%[\-+]*}"; b="${s#*[\-+]}";
	if test -z "$f"; then
		echo "\"$1\" is not a Semantic Version." >&2; return 2;
	fi;
	OIFS="$IFS"; IFS=".";
	for ns in $f; do
		# Can't have empty fields, zero prefixes or contain non-numbers.
		if test -z "$ns" -o "$ns" != "${ns#0[0-9]}" -o "$ns" != "${ns#*[!0-9]}"; then
			echo "\"$1\" is not a Semantic Version." >&2; return 2;
		fi;

		case "$l" in
			'0') major="$ns";; '1') minor="$ns";; '2') patch="$ns";;
			*) echo "\"$1\" is not a Semantic Version." >&2; return 2;;
		esac;
		l=$(( l + 1 ));
	done;
	IFS="$OIFS";

	# Determine what character was used, metadata or prerelease.
	if test "$f-$b" = "$s"; then
		# if it was for the prerelease, check for the final build metadata.
		s="$b"; f="${s%%+*}"; b="${s#*+}";

		prerelease="$f";
		if test "$f" != "$b"; then buildmetadata="$b"; fi;

	elif test "$f+$b" = "$s"; then
		# If metadata, we're done processing.
		buildmetadata="$b";
	fi;

	OIFS="$IFS"; IFS=".";
	# prereleases and build metadata can have any number of letter fields,
	# alphanum, and numeric fields separated by dots.
	# Also protect buildmetadata and prerelease from special chars.
	for s in $prerelease; do
		case "$s" in
			# Leading zeros is bad juju
			''|0*[!1-9a-zA-Z-]*|*[!0-9a-zA-Z-]*)
				echo "\"$1\" is not a Semantic Version." >&2;
			IFS="$OIFS"; return 2;;
		esac;
	done;
	for s in $buildmetadata; do
		case "$s" in
			''|*[!0-9a-zA-Z-]*)
				echo "\"$1\" is not a Semantic Version." >&2;
			IFS="$OIFS"; return 2;;
		esac;
	done;
	IFS="$OIFS";
}

# @describe - Ensures any character in the provided string will be used as raw characters in a Regular Expression
# @usage escreg STRING('s)...
# @param STRING('s) - The string or strings you wish to sanitize.
escreg()
(
	DONE=''; f=''; b=''; c=''; # TODO='';

	TODO="$*";

	OIFS="$IFS"; # Use IFS to split by filter chars.
	IFS='"\$[]*+.^?!{}()|'; for f in $TODO; do
		# Since $f cannot contain unsafe chars, we can test against it.
		c=;
		if test "${TODO#${DONE}${f}\\}" != "$TODO"; then c='\\'; fi;
		if test "${TODO#${DONE}${f}\*}" != "$TODO"; then c='\*'; fi;
		if test "${TODO#${DONE}${f}\$}" != "$TODO"; then c='\$'; fi;
		# test "${TODO#${DONE}${f}\)}" = "$TODO" || c='\)';
		# test "${TODO#${DONE}${f}\(}" = "$TODO" || c='\(';
		if test "${TODO#${DONE}${f}\[}" != "$TODO"; then c='\['; fi;
		if test "${TODO#${DONE}${f}\]}" != "$TODO"; then c='\]'; fi;
		if test "${TODO#${DONE}${f}(}" != "$TODO"; then c='\)'; fi;
		if test "${TODO#${DONE}${f})}" != "$TODO"; then c='\('; fi;
		if test "${TODO#${DONE}${f}+}" != "$TODO"; then c='\+'; fi;
		if test "${TODO#${DONE}${f}.}" != "$TODO"; then c='\.'; fi;
		if test "${TODO#${DONE}${f}^}" != "$TODO"; then c='\^'; fi;
		if test "${TODO#${DONE}${f}\?}" != "$TODO"; then c='\?'; fi;
		if test "${TODO#${DONE}${f}\!}" != "$TODO"; then c='\!'; fi;
		if test "${TODO#${DONE}${f}\{}" != "$TODO"; then c='\}'; fi;
		if test "${TODO#${DONE}${f}\}}" != "$TODO"; then c='\{'; fi;
		if test "${TODO#${DONE}${f}|}" != "$TODO"; then c='\|'; fi;

		DONE="$DONE$f$c";
	done;
	IFS="$OIFS";

	printf '%s' "$DONE";
)

filter_clangtools_locations(){
	echo "["
	echo ".[$VI].assets[] |";
	echo "if (";
	echo '((.name | startswith("clang+llvm-")) and (.name | endswith(".tar.xz")))';
	echo "or"
	echo '((.name | startswith("LLVM-")) and (.name | endswith("-woa64.zip")))';
	echo ")"
	echo "then [.name, .browser_download_url] else empty end";
	echo "]"
}

heuristic_name() {
	hn="${1#clang+llvm-}";
	hn="${hn#*-}";
	printf "%s" "${hn%.tar*}";
}

already_downloaded_binary_heuristic() {
	hn="$(heuristic_name "$1")";
	for file in $(basename -a "$PROCDIR/filelists/"*); do
		if test "$hn" = "$(heuristic_name "$file")"; then
			return 0;
		fi;
	done;
	return 1;
}

has_universals() {
	cat "$1" | sort -u | {
		while read line; do
			case "$line" in
				'/bin/clang-format'|'/bin/clang-tidy'|'/bin/git-clang-format') printf ".";;
			esac;
		done;
	}
	printf "\n";
}


trap "sleep 1; rm -rf $TEMPDIR; exit 0;" 0 2 3 9 15;

# NOTE: only need to check the breaking changes versions, since those are the
#       only versions that SHOULD have filesystem differences between them, if
#       any exist at all.
curl -L "$URL" > "$JSON1";

cd "$PROCDIR";
mkdir "filelists" "binaries";

VERSION_COUNT="$(jq -r ". | length" "$JSON1")"; VI=0;
while test "$VI" -lt "$VERSION_COUNT"; do
	TAG="$(jq -r ".[$VI].tag_name" "$JSON1")";
	tokenize_semver_string "${TAG#llvmorg\-}";

	# Skip all versions that aren't explicitly breaking changes.
	if test -z "$prerelease"; then
		jq "$(filter_clangtools_locations)" "$JSON1" > "$JSON2";
		TARGET_COUNT="$(jq -r ". | length" "$JSON2")"; TI=0;

		while test "$TI" -lt "$TARGET_COUNT"; do
			filename="$(jq -r ".[$TI][0]" "$JSON2")";
			prefix="$(escreg "$filename")";
			url="$(jq -r ".[$TI][1]" "$JSON2")";

			if test "$filename" != "${filename%.tar*}"; then
				echo "Info: Discovering contents of $filename";

				TARFILE="$TARFILEPREFIX.${filename##*.}";
				curl -L "$url" > "$TARFILE";

				if ! already_downloaded_binary_heuristic "$filename"; then
					cd "$TEMPDIR";
					BINFILE="${filename%.tar*}/bin/clang-format";
					tar -Jxvf "$TARFILE" "$BINFILE";
					mv "$BINFILE" "$PROCDIR/binaries/clang-format_$(heuristic_name "$filename")";
					cd "$PROCDIR";
				fi;

				tar -Jtf "$TARFILE" | sed -Ee "s/^${prefix%\\.tar*}//" \
					> "$PROCDIR/filelists/$filename.list";

			elif test "$filename" != "${filename%.zip*}"; then
				echo "Warning: Zip files unsupported, skipping $filename";
				TI="$(($TI+1))";
				continue;

			else
				echo "Warning: File type unrecognized, skipping $filename";
				TI="$(($TI+1))";
				continue;
			fi;
			TI="$(($TI+1))";
		done;
	fi;

	VI="$(($VI+1))";
done;

echo "Discovering Universals:";
for file in "$PROCDIR/filelists/"*; do
	fn="${file%.list}";
	fn="${fn#clang+llvm-}";
	printf "%s -> %.50s" "$(has_universals "$file")" "$(basename "$fn")";
done;

echo "Discovering Bincompat:";
for file in "$PROCDIR/binaries/"*; do
	echo "$file";
	readelf -hA "$file" | grep -E "Machine:|Flags:|Tag_CPU_arch:|OS/ABI:";
done;
