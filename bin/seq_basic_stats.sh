#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script computes the number of bp, and the gc mean and
# variance 
# DEPENDENCIES: R
# CONFIGURATION VARIABLES: ${r_interpreter}
# EXIT CODES:
# 0    no errors
# 1    input/output error
# 5    config file not found or readable
# 6    config file format error
################################################################################
################################################################################

show_usage(){
  cat <<EOF
  Usage: ${0##*/} [-h] [-c|--config FILE] [-i|input FILE] [-o|--output FILE]

  -c|--config        configuration file
  -h|--help          display this help and exit
  -i|--input         input sequence info file
  -o|--output        output stats
EOF
}

read_config(){
  CONFIG_FILE="${1}"

  if [[ ! -r "${CONFIG_FILE}" ]]; then
    echo "${CONFIG_FILE} doesn't exist or is not readable"
    exit 5
  fi

  CONFIG_SYNTAX="^\s*#|^\s*$|^[0-9a-zA-Z_]+=\"[^\"]*$|^[0-9a-zA-Z_]+\=\"[^\"]\
*\"$|[^\"]*\"$"

  if egrep -q -v "${CONFIG_SYNTAX}" "${CONFIG_FILE}"; then
    echo "Error parsing config file ${CONFIG_FILE}." >&2
    echo "The following lines in the configfile do not fit the syntax:" >&2
    egrep -vn "${CONFIG_SYNTAX}" "$CONFIG_FILE"
    exit 6
  fi

  source "${CONFIG_FILE}"
}


function seq_basic_stats() {

  local INFOSEQ_TMPFILE="${1}"
  local INFOSEQ_MGSTATS="${2}"

  "${r_interpreter}" --vanilla --slave <<RSCRIPT
  t<-read.table(file = "${INFOSEQ_TMPFILE}", header = F)
  bp<-sum(as.numeric(t[,1]))
  meanGC<-mean(as.numeric(t[,2]))
  varGC<-var(as.numeric(t[,2]))
  res<-paste(bp, meanGC, varGC, sep = ' ')
  write(x=res,file="${INFOSEQ_MGSTATS}")
RSCRIPT
  EXIT_CODE="$?"
}

main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi

  seq_basic_stats "${INPUT}" "${OUTPUT}"


  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "Seq stats successful"
  else
    echo "Seq stats table failed"
  fi
  exit "${EXIT_CODE}"
}


if  [[ "$#" -eq 0 ]]; then
    show_usage
fi

#######################################
# parse positional parameters
#######################################

while :; do
  case "${1}" in

    -h|-\?|--help) # Call a "show_help" function to display a synopsis, then
                   # exit.
    show_usage
    exit
    ;;
###########
   -c|--config) # Takes an option argument, ensuring it has been specified.
    if [ -n "${2}" ]; then
      CONFIG_FILE="${2}"
      shift
    else
      printf 'ERROR: "--config" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --config=?*)
    CONFIG_FILE=${1#*=} # Delete everything up to "=" and assign the
                        # remainder.
    ;;
    --config=) # Handle the case of an empty --file=
    printf 'WARN: Using default environment.\n' >&2
    ;;
#############
    -i|--input) # Takes an option argument, ensuring it has been
                # specified.
    if [[ -n "${2}" ]]; then
      INPUT="${2}"
      shift
    else
      printf 'ERROR: "--input" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --input=?*)
    INPUT=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --input=)     # Handle the case of an empty --file=
    printf 'ERROR: "--input" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
##########
    -o|--output) # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      OUTPUT="${2}"
      shift
    else
      printf 'ERROR: "--output" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --output=?*)
    OUTPUT=${1#*=} # Delete everything up to "=" and assign the
                   # remainder.
    ;;
    --output=)     # Handle the case of an empty --file=
    printf 'ERROR: "--output" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
###########
    --)              # End of all options.
    shift
    break
    ;;

    -?*)
    printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
    ;;

    *) # Default case: If no more options then break out of the loop.
    break
    esac

    shift
done

main "$@"








