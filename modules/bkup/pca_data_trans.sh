#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this computes a PCA for codon, aa, and dinuc frequencies
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
  Usage: ${0##*/} [-h] [-c|--config FILE] [-i|--id NUMBER] \
[-o|--output FILE] [-t|--table FILE]

  -c|--config        configuration file
  -h|--help          display this help and exit
  -i|--id            metagenomes id (\$ID)
  -o|--output        output pca scores
  -t|--table         input table for PCA
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


function pca() {

  local TABLE="${1}"
  local OUTPUT="${2}"
  local ID="${3}"

  if [[ ! -r "${TABLE}" ]]; then
    echo "${TABLE} doesn't exist or is not readable"
  fi

  "${r_interpreter}" --vanilla --slave <<RSCRIPT
  library(vegan)
  t<-read.table(file="${TABLE}", sep = "\t", header = T,
  stringsAsFactors = F)
  t\$sample_label <- NULL
  t.ids<-as.vector(unique(t\$id))
  createTableAbun <- function(X){
  t1<-subset(t, id == X)
  s <- cbind(X,t(t1\$value))
  colnames(s) <- c("id",as.vector(t(t1\$key)))
  return(s) 
  }
  ab.list <- lapply(t.ids, createTableAbun)
  ab.table<-data.frame(do.call("rbind", ab.list), stringsAsFactors = F)
  row.names(ab.table)<- ab.table\$id
  ab.table\$id <- NULL
  ab.table <- decostand(ab.table, method = "hellinger")
  pca<-rda(ab.table)
  pca.scores<-as.data.frame(scores(pca)\$sites)
  pca.scores<-cbind(rownames(pca.scores), "functional-table", pca.scores,
  "${ID}")
  write.table(pca.scores, file = "${OUTPUT}", col.names = F,
  row.names = F, sep = "\t", quote = F)
RSCRIPT


  EXIT_CODE="$?"
}

main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi

  pca ${TABLE} ${OUTPUT} ${ID}

  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "PCA ${TABLE} successful"
  else
    echo "PCA ${TABLE} failed"
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
################
    -i|--id)  # Takes an option argument, ensuring it has been specified.
    if [[ -n "${2}" ]]; then
      ID="${2}"
      shift
    else
      printf 'ERROR: "--id" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;

    --id=?*)
    ID=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;

    --id=)         # Handle the case of an empty --file=
    printf 'ERROR: "--id" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
#################
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
    OUTPUT=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;

    --output=)     # Handle the case of an empty --file=
    printf 'ERROR: "--output" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
#################
    -t|--table) # Takes an option argument, ensuring it has been
                # specified.
    if [[ -n "${2}" ]]; then
      TABLE="${2}"
      shift
    else
      printf 'ERROR: "--table" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;

    --table=?*)
    TABLE=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;

    --table=)     # Handle the case of an empty --file=
    printf 'ERROR: "--table" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
###############
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

