#!/bin/sh
# FastaValidator exit codes
# 0    valid input
# 1    unknown error
# 2    input/output error
# 3    invalid character in sequence
# 4    invalid FASTA format

show_usage(){
    cat <<EOF
    Usage: ${0##*/} [-h] [-c|--config FILE] [-f|--fastafile FILE] [-t|-seqtype TYPE] ...

    -h|--help          display this help and exit
    -c|--config        configuration file
    -f|--fastafile     fasta file to validate
    -t|--seqtype       alphabet to be used (allowed values: all|dna|rna|protein)
EOF
}


validate_fasta(){
    SFILE=${1}
    STYPE=${2}

    if [ ! -r "${SFILE}" ]; then
	echo "${SFILE} doesn't exist or is not readable"
    fi

    java -jar "${FASTA_VALIDATOR}" -nogui -f "${SFILE}" -t "${STYPE}"
    EXIT_CODE=$?
}

read_config(){
    CONFIG_FILE=$1

    if [ ! -r ${CONFIG_FILE} ]; then
	echo "${CONFIG_FILE} doesn't exist or is not readable"
	exit 1
    fi
    
    # commented lines, empty lines und lines of the from choose_ANYNAME='any.:Value' are valid
    CONFIG_SYNTAX='^\s*#|^\s*$|^[a-zA-Z_]+="[^"]*"$'

    # check if the file contains something we don't want
    if egrep -q -v "${CONFIG_SYNTAX}" "${CONFIG_FILE}"; then
	echo "Error parsing config file ${CONFIG_FILE}." >&2
	echo "The following lines in the configfile do not fit the syntax:" >&2
	egrep -vn "${CONFIG_SYNTAX}" "$CONFIG_FILE"
	exit 5
    fi
    source "${CONFIG_FILE}"
}

main(){
    if [ -n "${CONFIG_FILE}" ]; then
	read_config "${CONFIG_FILE}"
    fi

    validate_fasta "${SFILE}" "${STYPE}"

    if [ "${EXIT_CODE}" -eq 0 ]; then
	echo "Valid FASTA file."
    else
	echo "Invalid FASTA file."
    fi
    
    exit "${EXIT_CODE}"
}


if [ "$#" -eq 0 ]; then
    show_usage
fi
while :; do
    case $1 in
	-h|-\?|--help)   # Call a "show_help" function to display a synopsis, then exit.
	    show_usage
	    exit
	    ;;
	-f|--fastafile)       # Takes an option argument, ensuring it has been specified.
	    if [ -n "$2" ]; then
		SFILE=$2
		shift
	    else
		printf 'ERROR: "--fastafile" requires a non-empty option argument.\n' >&2
		exit 1
	    fi
	    ;;
	--fastafile=?*)
	    SFILE=${1#*=} # Delete everything up to "=" and assign the remainder.
	    ;;
	--fastafile=)         # Handle the case of an empty --file=
	printf 'ERROR: "--fastafile" requires a non-empty option argument.\n' >&2
	exit 1
	;;
	-c|--config)       # Takes an option argument, ensuring it has been specified.
	    if [ -n "$2" ]; then
		CONFIG_FILE=$2
		shift
	    else
		printf 'ERROR: "--config" requires a non-empty option argument.\n' >&2
		exit 1
	    fi
	    ;;
	--config=?*)
	    CONFIG_FILE=${1#*=} # Delete everything up to "=" and assign the remainder.
	    ;;
	--config=)         # Handle the case of an empty --file=
	printf 'WARN: Using default environment.\n' >&2
	;;
	-t|--seqtype)       # Takes an option argument, ensuring it has been specified.
	    if [ -n "$2" ]; then
		STYPE=$2
		shift
	    else
		printf 'ERROR: "--seqtype" requires a non-empty option argument.\n' >&2
		exit 1
	    fi
	    ;;
	--seqtype=?*)
	    STYPE=${1#*=} # Delete everything up to "=" and assign the remainder.
	    ;;
	--seqtype=)         # Handle the case of an empty --file=
	printf 'ERROR: "--seqtype" requires a non-empty option argument.\n' >&2
	exit 1
	;;

	--)              # End of all options.
	    shift
	    break
	    ;;
	-?*)
	    printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
	    ;;
	*)               # Default case: If no more options then break out of the loop.
	    break
    esac

    shift
done

main "$@"
