#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script creates the dinucleotide frequency table
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
  Usage: ${0##*/} [-h] [-c|--config FILE] [-d|--dinuc_frecs FILE] \
[-n|nuc_freqs FILE]  [-o|--odds_table FILE]

  -c|--config        configuration file
  -d|--dinuc_freqs   dinucleotide frequency file
  -h|--help          display this help and exit
  -n|--nuc_freqs     nucleotide frequency file
  -o|--odds_table    output odds table
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


function create_nuc_table() {

  local NUC_FREQS="${1}"
  local DINUC_FREQS="${2}"
  local ODDS_TABLE="${3}"

  "${r_interpreter}" --vanilla --slave <<RSCRIPT
  nuc<-read.table(file = "${NUC_FREQS}", header = F, stringsAsFactors = F, \
  sep = ' ')
  rownames(nuc)<-nuc\$V1
  nuc\$V1<-NULL
  nuc<-as.data.frame(t(nuc))
  dinuc<-read.table(file = "${DINUC_FREQS}", header = F, stringsAsFactors = F,\
  sep = ' ')
  rownames(dinuc)<-dinuc\$V1
  dinuc\$V1<-NULL
  dinuc<-as.data.frame(t(dinuc))
  #Forward strand f(X) when X={A,T,C,G} in S
  fa<-nuc\$A[[2]]
  ft<-nuc\$T[[2]]
  fc<-nuc\$C[[2]]
  fg<-nuc\$G[[2]]
  #Frequencies when S + SI = S*; f*(X) when X= {A,T,C,G}
  faR<-(fa+ft)/2
  fcR<-(fc+fg)/2
  fAA <- (dinuc\$AA[[2]] + dinuc\$TT[[2]])/2
  fAC <- (dinuc\$AC[[2]] + dinuc\$GT[[2]])/2
  fCC <- (dinuc\$CC[[2]] + dinuc\$GG[[2]])/2
  fCA <- (dinuc\$CA[[2]] + dinuc\$TG[[2]])/2
  fGA <- (dinuc\$GA[[2]] + dinuc\$TC[[2]])/2
  fAG <- (dinuc\$AG[[2]] + dinuc\$CT[[2]])/2
  pAA <- fAA/(faR * faR)
  pAC <- fAC/(faR * fcR)
  pCC <- fCC/(fcR * fcR)
  pCA <- fCA/(faR * fcR)
  pGA <- fGA/(faR * fcR)
  pAG <- fAG/(faR * fcR)
  pAT <- dinuc\$AT[[2]]/(faR * faR)
  pCG <- dinuc\$CG[[2]]/(fcR * fcR)
  pGC <- dinuc\$GC[[2]]/(fcR * fcR)
  pTA <- dinuc\$TA[[2]]/(faR * faR)
  odds<-cbind(pAA, pAC, pCC, pCA, pGA, pAG, pAT, pCG, pGC, pTA)
  colnames(odds)<-c("pAA/pTT", "pAC/pGT", "pCC/pGG", "pCA/pTG", "pGA/pTC",\
  "pAG/pCT", "pAT", "pCG", "pGC", "pTA")
  write.table(odds, file = "${ODDS_TABLE}", sep = "\t", row.names = F, \
  quote = F, col.names  = F)
RSCRIPT

  EXIT_CODE="$?"

}

main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi

  create_nuc_table "${NUC_FREQS}" "${DINUC_FREQS}" "${ODDS_TABLE}"

  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "nucleotide table successful"
  else
    echo "nucleotide table failed"
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
##########
    -d|--dinuc_freqs) # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      DINUC_FREQS="${2}"
      shift
    else
      printf 'ERROR: "--dinuc_freqs non-empty option argument.\n' >&2
      exit 1
    fi
    ;;

    --dinuc_freqs=?*)
    DINUC_FREQS=${1#*=} # Delete everything up to "=" and assign the
                            # remainder.
    ;;

    --dinuc_freqs=)     # Handle the case of an empty --file=
    printf 'ERROR: "--dinuc_freqs" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
###########
    -n|--nuc_freqs) # Takes an option argument, ensuring it has been
                # specified.
    if [[ -n "${2}" ]]; then
      NUC_FREQS="${2}"
      shift
    else
      printf 'ERROR: "--nuc_freqs" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;

    --nuc_freqs=?*)
    NUC_FREQS=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;

    --nuc_freqs=)     # Handle the case of an empty --file=
    printf 'ERROR: "--nuc_freqs" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
###########
-o|--odds_table) # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      ODDS_TABLE="${2}"
      shift
    else
      printf 'ERROR: "--odds_table" requires a non-empty option argument.\n'>&2
      exit 1
    fi
    ;;

    --odds_table=?*)
    ODDS_TABLE=${1#*=} # Delete everything up to "=" and assign the
                            # remainder.
    ;;

    --odds_table=)     # Handle the case of an empty --file=
    printf 'ERROR: "--odds_table" requires a non-empty option argument.\n' >&2
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








