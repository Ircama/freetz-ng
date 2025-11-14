#! /usr/bin/env bash
# generates docs/stats/README.md
SCRIPT="$(readlink -f $0)"
PARENT="$(dirname $(dirname ${SCRIPT%/*}))"
OUTFILE="$PARENT/docs/stats/README.md"
TMPFILE="$PARENT/.stats"
rm -f "$TMPFILE".??.*


table_head() {
	echo "<table>"
	echo "<caption style='background-color:gray'>${3:-&nbsp;}</caption>"
	echo "<thead><tr><th style='width:450px'>$1</th><th style='width:300px'>$2</th></tr></thead>"
	echo "<tbody>"
}

table_foot() {
	echo "</tbody></table>"
}

spoiler_head() {
	count=$(cat "$1" | wc -l | tr -d '\n')
	echo "<details><summary>${count} $2</summary>"
	echo
}

spoiler_body() {
	cat "$1" | sed 's/|/\\|/g' | sed -r 's, *@ (.*) @ (.*) @,<tr><td>\2</td><td>\1</td></tr>,g'
	table_foot
	echo "</details>"
	echo
}

get_fw() {
	area='Firmware version'
	file="config/ui/firmware.in"
	(
		table_head "Version" "Symbol"
		cat "$file" | grep "prompt \"${area}\"" -m1 -A9999 | grep "^endchoice" -m1 -B9999 | sed 's/^[ \t]*//g' | grep -E "^(config|bool) " | while read -r line; do
			[ "${line#config}"  != "$line" ] && echo "$line" | tr -d '\n'  | sed 's/^[^\t ]*[ \t]*/@ /g;s/$/ @ /g'
			[ "${line#bool}"    != "$line" ] && echo "$line"               | sed 's/^[^\t ]*[ \t]*"//g;s/"/ @/g' && echo >> "$TMPFILE.fw.head"
		done | sed 's/ - [^ ]*//g' | grep -Evi "(inhaus|labor|plus)"
	) > "$TMPFILE.fw.body"
}

get_hw() {
	area='Hardware type'
	file="config/ui/firmware.in"
	(
		first='y'
		cat "$file" | grep "prompt \"${area}\"" -m1 -A9999 | grep "^endchoice" -m1 -B9999 | sed 's/^[ \t]*//g' | grep -E "^(comment|config|bool) " | while read -r line; do
			if [ "${line#comment}" != "$line" ]; then
				[ "$first" == "y" ] && first='n' || table_foot
#				echo "$line"  | sed 's/^[^\t ]*[ \t]*"/<h3>/;s/".*/<\/h3>/'
				table_head "Name" "Symbol"  "$(echo "$line"  | sed 's/^[^\t ]*[ \t]*"//;s/".*//')"
			fi
			[ "${line#config}"  != "$line" ] && echo "$line" | tr -d '\n'           | sed 's/^[^\t ]*[ \t]*/@ /g;s/$/ @ /g'
			[ "${line#bool}"    != "$line" ] && echo "$line"                        | sed 's/^[^\t ]*[ \t]*"//g;s/"/ @/g' && echo >> "$TMPFILE.hw.head"
		done | sed 's/ - [^ ]*//g'
	) > "$TMPFILE.hw.body"
}

get_dl() {
	area='Firmware source'
	file="config/mod/dl-firmware.in"
	(
		table_head "Datei(/AVM)" "Symbole"
		cat "$file" | grep "string \"${area}\"" -m1 -A9999 | grep "^config " -m1 -B9999 | sed 's/^[ \t]*//g' | grep -E "^(default) " | while read -r line; do
			echo "$line" | tr -s ' ' | sed -r 's/.*"(.*)".* if (.*)/@ \2 @ \1 @/g' && echo >> "$TMPFILE.dl.head"
		done | sed -r 's/_(inhaus|labor|plus)//gI' | grep -v "DETECT_IMAGE_NAME" | sed 's/&/\&amp;/g;s/|/\&vert;/g'
	) > "$TMPFILE.dl.body"
}

main() {

	echo "# Statistiken rund um Freetz-NG"
	echo

	echo "firmware" >&2
	get_fw
	spoiler_head "$TMPFILE.fw.head" "verschiedene FRITZ!OS"
	spoiler_body "$TMPFILE.fw.body"
	rm -f "$TMPFILE.fw."*

	echo "hardware" >&2
	get_hw
	spoiler_head "$TMPFILE.hw.head" "verschiedene Geräte"
	spoiler_body "$TMPFILE.hw.body"
	rm -f "$TMPFILE.hw."*

	echo "image" >&2
	get_dl
	spoiler_head "$TMPFILE.dl.head" "verschiedene Images"
	spoiler_body "$TMPFILE.dl.body"
	rm -f "$TMPFILE.dl."*

}

main > "$OUTFILE"
exit 0

