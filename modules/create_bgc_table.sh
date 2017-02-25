#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script creates the functional annotation table
# DEPENDENCIES: R
# CONFIGURATION VARIABLES: ${r_interpreter}, ${BGC_DOMAINS}
# EXIT CODES:
# 0    no errors
# 1    input/output error
# 5    config file not found or readable
# 6    config file format error
################################################################################
################################################################################

show_usage(){
  cat <<EOF
  Usage: ${0##*/} [-h] [-c|--config FILE] [-i|--input FILE] \
[-f|--fun_table FILE] [-n|--num_genes NUMBER]  [-t|--tfperc FILE ] \
[-r|--cfperc FILE]

  -c|--config        configuration file
  -h|--help          display this help and exit
  -f|--fun_table     output functional table
  -n|--num_genes     number of found genes
  -r|--clperc        classified reads percentage
  -t|--tfperc        transcriptional factors percentage
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


function create_fun_table() {

  local NUM_GENES="${1}"
  local BGCFILE="${2}"
  local FUNCTIONALTABLE="${3}"

  "${r_interpreter}" --vanilla --slave <<RSCRIPT
  n.genes<-as.numeric("${NUM_GENES}")
  t<-read.table(file = '${BGCFILE}', header = F, stringsAsFactors=F, sep=",")
  colnames(t)<-c("seq_id", "bgc_dom")
  perc.cl<-(length(unique(t[,1]))/n.genes)*100
  t<-subset(t, select = "bgc_dom")
  p<-read.table(file = '${BGC_DOMAINS}', header = F, stringsAsFactors=F)
  colnames(p)<-'bgc_dom'
  t.t<-as.data.frame(table(t\$bgc_dom))
  colnames(t.t)<-c("bgc_dom", "counts")
  t.m<-merge(p, t.t, all = T, by= "bgc_dom")
  t.m[is.na(t.m)]<-0
  colnames(t.m)<-c("bgc_dom", "counts")
  write.table(t.m, file = '${FUNCTIONALTABLE}', sep = "\t", row.names = F, \
  quote = F, col.names = F)
  write.table(perc.cl, file = '${CLPERC}', sep = "\t", row.names = F, \
  quote = F, col.names = F)
RSCRIPT


  EXIT_CODE="$?"
}

main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi


  create_fun_table "${NUM_GENES}" "${INPUT}" "${FUNCTIONALTABLE}" "${TFPERC}" \
  "${CLPERC}"


  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "functional table successful"
  else
    echo "functional table failed"
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
##########
    -f|--fun_table) # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      FUNCTIONALTABLE="${2}"
      shift
    else
      printf 'ERROR: "--fun_table" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --fun_table=?*)
    FUNCTIONALTABLE=${1#*=} # Delete everything up to "=" and assign the
                            # remainder.
    ;;
    --fun_table=)     # Handle the case of an empty --file=
    printf 'ERROR: "--fun_table" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
###########
    -n|--num_genes)  # Takes an option argument, ensuring it has been specified.
    if [[ -n "${2}" ]]; then
      NUM_GENES="${2}"
      shift
    else
      printf 'ERROR: "--num_genes" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --num_genes=?*)
    NUM_GENES=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --num_genes=)         # Handle the case of an empty --file=
    printf 'ERROR: "--num_genes" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
#############
    -r|--clperc)  # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      CLPERC="${2}"
      shift
    else
      printf 'ERROR: "--clperc" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --clperc=?*)
    CLPERC=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --clperc=)         # Handle the case of an empty --file=
    printf 'ERROR: "--clperc" requires a non-empty option argument.\n' >&2
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








