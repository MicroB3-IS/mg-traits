#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script creates the codon and aa frequency table
# DEPENDENCIES: R
# CONFIGURATION VARIABLES: ${r_interpreter}, 
# EXIT CODES:
# 0    no errors
# 1    input/output error
# 5    config file not found or readable
# 6    config file format error
################################################################################
################################################################################
show_usage(){
  cat <<EOF
  Usage: ${0##*/} [-h] [-a|--aa_table FILE] [-b|--codon_table FILE] \
[-c|--config FILE] [-i|input FILE] [-r|--ab_ratio FILE ]

  -a|--aa_table      amino acids table output
  -b|--codon_table   codon table output
  -c|--config        configuration file
  -i|--input         cusp input file
  -h|--help          display this help and exit
  -r|--ab_ratio      acid to basic ratio

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


function create_codon_aa_table() {

  local CODONCUSP="${1}"
  local AA_TABLE="${2}"
  local CODON_TABLE="${3}"
  local ABRATIO_FILE="${4}"

  "${r_interpreter}" --vanilla --slave <<RSCRIPT
  codon<-read.table(file = "${CODONCUSP}", header = F, stringsAsFactors = F,\
  sep = ' ')
  codon<-cbind(codon, codon\$V3/ sum( as.numeric(codon\$V3) ) )
  colnames(codon)<-c("codon", "aa", "raw", "prop")
  codon2<-as.data.frame(t(codon\$prop), stringsAsFactors = F)
  colnames(codon2)<-codon\$codon
  aa<-aggregate(raw ~ aa, data = codon, sum)
  aa<-cbind(aa, (aa\$raw / sum( as.numeric(aa\$raw) ) ))
  colnames(aa)<-c("aa", "raw", "prop")
  aa2<-as.data.frame(t(aa\$prop))
  colnames(aa2)<-aa\$aa
  ab<-(aa2\$D + aa2\$E)/(aa2\$H + aa2\$R + aa2\$K)
  write.table(aa2, file = "${AA_TABLE}", sep = "\t", row.names = F, quote = F,\
  col.names  = T)
  write.table(codon2, file = "${CODON_TABLE}", sep = "\t", row.names = F, \
  quote=F, col.names  = T)
  write(ab, file = "${ABRATIO_FILE}")

RSCRIPT


  EXIT_CODE="$?"
}

main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi

  create_codon_aa_table "${INPUT}" "${AA_TABLE}" "${CODON_TABLE}" \
  "${ABRATIO_FILE}"


  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "codon and aa table successful"
  else
    echo "codon and aa table failed"
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
##########
    -a|--aa_table) # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      AA_TABLE="${2}"
      shift
    else
      printf 'ERROR: "--aa_table" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --aa_table=?*)
    AA_TABLE=${1#*=} # Delete everything up to "=" and assign the
                            # remainder.
    ;;
    --aa_table=)     # Handle the case of an empty --file=
    printf 'ERROR: "--aa_table" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
###########
-b|--codon_table) # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      CODON_TABLE="${2}"
      shift
    else
      printf 'ERROR: "--codon_table" requires a non-empty option argument.\n'>&2
      exit 1
    fi
    ;;
    --codon_table=?*)
    CODON_TABLE=${1#*=} # Delete everything up to "=" and assign the
                            # remainder.
    ;;
    --codon_table=)     # Handle the case of an empty --file=
    printf 'ERROR: "--codon_table" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
################
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
###########
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
###########
    -r|--ab_ratio)  # Takes an option argument, ensuring it has been
                  # specified.
    if [[ -n "${2}" ]]; then
      ABRATIO_FILE="${2}"
      shift
    else
      printf 'ERROR: "--ab_ratio" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;

    --ab_ratio=?*)
    ABRATIO_FILE=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;

    --ab_ratio=)         # Handle the case of an empty --file=
    printf 'ERROR: "--ab_ratio" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
################
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








