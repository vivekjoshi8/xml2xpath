#!/bin/bash

script_name=$(basename $0)
#---------------------------------------------------------------------------------------
# Help.
#---------------------------------------------------------------------------------------
function print_help(){
	cat<<EOF-MAN
NAME
$script_name - Print XPath present on xml or (if possible) xsd files.

SYNOPSIS
$script_name [-h] [-d file -t <tag name>] [-x file]

DESCRIPTION
     foo .

OPTIONS
     -d   xsd file path.

     -h   print this help message.

     -f   tag name to start searching for xpath strings.

     -t   print XML element tree as provided by xmllint 'du' shell command.

     -x   xml file, not to use with -d option.
EOF-MAN
}

function print_usage(){
	echo "Usage: $script_name [-h] [-d file -t <tag name>] [-x file]"
}

xsd=""
xml_file=""
tag1=""
print_tree=0

#---------------------------------------------------------------------------------------
# get white space indentation as multiple dots, count them and divide by 2
#---------------------------------------------------------------------------------------
function get_indent_level(){
    for c in $(echo "$@" $1 | sed -nre '/^ / s/^( +).*/\1/p' | tr ' ' '.' | sort | uniq); do
        echo $((${#c}/2)) 
    done
}

#---------------------------------------------------------------------------------------
# generate XML from XSD. Requires xmlbeans package.
#---------------------------------------------------------------------------------------
function create_xml_instance(){
	if [ -x /usr/bin/xsd2inst ]; then
		if [ -z "$xsd" ]; then
			echo -e "FATAL: XSD file path can not be empty if -d option is used." > /dev/stderr
			exit 1
		fi
		xml_file=$(mktemp)
		echo -e "Creating XML instance from $xsd as $xml_file starting at element $tag1\n"
	    XMLBEANS_LIB='/usr/share/java/xmlbeans/' xsd2inst "$xsd" -name "$tag1" > "$xml_file"
	else
		echo "FATAL: package xmlbeans is not installed but is required for -d option. Aborting." > /dev/stderr
		exit 1
	fi
}

#---------------------------------------------------------------------------------------
# Get elements tree as provided by xmllint 'du' command 
#---------------------------------------------------------------------------------------
function get_xml_tree(){
	if [ -n "$xml_file" ]; then
		echo "du /" | xmllint --shell "$xml_file" | grep -v '\/'
	else
	echo "ERROR: No XML file. Either provide an XSD to create an instance from (-d option) or pass the path to an XML valid file"
		exit 1
	fi
}

while getopts d:f:htx: arg
do
  case $arg in
    h) print_help; exit;;
	d) xsd=$OPTARG;;
	f) tag1=$OPTARG;;
	t) print_tree=1;;
	x) xml_file=$OPTARG;;
    *) 
        echo "Invalid option $arg"
        print_help
        exit 1;;
  esac
done

if [ -z "$xsd" ] && [ -z "$xml_file" ]; then
	echo -e "FATAL: At least on of -d or -x must be provided.\n" > /dev/stderr
	print_usage
	exit 1
fi
if [ -n "$xsd" ]; then
	create_xml_instance
fi
# get elements tree with xmllint
xml_tree=$(get_xml_tree)

if [ "$print_tree" -eq 1 ]; then
	echo -e "$xml_tree\n"
fi

indent_levels=$(get_indent_level "$xml_tree")
max_level=$(echo "$indent_levels" | tail -n1)
declare -a xpath_arr

# generate xpaths
echo "$xml_tree" | while IFS='' read line; do
    indent=$(echo "$line" | sed -nre 's/^( +).*/\1/p' | tr ' ' '.')
    ilvl=$((${#indent}/2))
    prev_lvl=$(($ilvl - 1))

    if [ "$ilvl" -eq 0 ]; then
        xpath_arr[0]="/$line"
        xpath="${xpath_arr[0]}"
    elif [ "$ilvl" -le "$max_level" ]; then
        xpath="${xpath_arr[$prev_lvl]}/$(echo "$line" | tr -d ' ')"
        xpath_arr[$ilvl]="$xpath"
    fi
    echo "$xpath"
done

if [ -n "$xsd" ]; then
	rm "$xml_file"
fi