#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script downloads a file using the curl command, checks the
# format and uncompresses it if necessary. It can handle zip, gzip, 7zip and
# bzip2
# DEPENDENCIES: curl, zip, gzip, 7zip and bzip2
# CONFIGURATION VARIABLES:
# EXIT CODES:
# 0    no errors
# 1    no valid url, input/output error
# 2    no recognized downlaod file format
# 5    config not file found or readable
# 6    config file format error
# 37   curl failed
################################################################################
################################################################################

show_usage(){
  cat <<EOF
  Usage: ${0##*/} [-h] [-c|--config FILE] [-d|--dout FILE] [-f|--fout FILE] \
[-u|--url URL] ...

  -c|--config        configuration file
  -h|--help          display this help and exit
  -d|--dout          downlaod file
  -f|--fout          output file
  -u|--url           url
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



function download() {

  local URL="${1}"
  local RAW_DOWNLOAD="${2}"

#   set +H
#   local REGEX="(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*\
# [-A-Za-z0-9\+&@#/%=~_|]"
#   set -H
# 
#   if [[ ! "${URL}" =~ ${REGEX} ]]; then
#     echo "not valid url: ${URL}"
#     echo "${REGEX}"
#     exit 1
#   fi

  # download MG_URL
   if [[ "${URL}" =~ ^file ]] || \
      [[ "${URL}" =~ ^http ]] || \
      [[ "${URL}" =~ ^ftp ]]; then

    curl -sf "${URL}" > "${RAW_DOWNLOAD}"
    EXIT_CODE="$?"

  else 
   rsync -a "${URL}" "${RAW_DOWNLOAD}"
   EXIT_CODE="$?"
  fi

#    ln -s "${URL/file:\/\//}" "${RAW_DOWNLOAD}"
#    EXIT_CODE="$?"


  FILE_TYPE=$(file -b --mime-type "${RAW_DOWNLOAD}")

  if [[ "${FILE_TYPE}" == "text/plain" ]]; then
    mv "${RAW_DOWNLOAD}" "${RAW_FASTA}";

  elif [[ "${FILE_TYPE}" == "application/zip" ]]; then
    unzip -p "${RAW_DOWNLOAD}" > "${RAW_FASTA}";

  elif [[ "${FILE_TYPE}" == "application/x-gzip" ]]; then
    gunzip -c "${RAW_DOWNLOAD}" > "${RAW_FASTA}";

  elif [[ "${FILE_TYPE}" == "application/x-bzip2" ]]; then
    bzip2 -c -d "${RAW_DOWNLOAD}" > "${RAW_FASTA}";

  elif [[ "${FILE_TYPE}" == "application/x-7z-compressed" ]]; then
    7z e -so "${RAW_DOWNLOAD}" > "${RAW_FASTA}";

  else
    echo "no recognized format for download file"
    exit 2
  fi

}


main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi

  download "${MG_URL}" "${RAW_DOWNLOAD}"

  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "Download successful"
  else
    echo "Download failed"
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
##############
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
##############
   -d|--dout) # Takes an option argument, ensuring it has been
              # specified.
    if [[ -n "${2}" ]]; then
      RAW_DOWNLOAD="${2}"
      shift
    else
      printf 'ERROR: "--dout" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --dout=?*)
    RAW_DOWNLOAD=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --dout=)         # Handle the case of an empty --file=
    printf 'ERROR: "--dout" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
###############
    -f|--fout) # Takes an option argument, ensuring it has been
               # specified.
    if [[ -n "${2}" ]]; then
      RAW_FASTA="${2}"
      shift
    else
      printf 'ERROR: "--fout" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --fout=?*)
    RAW_FASTA=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --fout=)         # Handle the case of an empty --file=
    printf 'ERROR: "--fout" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
###############
    -u|--url)  # Takes an option argument, ensuring it has been specified.
    if [[ -n "${2}" ]]; then
      MG_URL="${2}"
      shift
    else
      printf 'ERROR: "--url" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --url=?*)
    MG_URL=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --url=)         # Handle the case of an empty --file=
    printf 'ERROR: "--url" requires a non-empty option argument.\n' >&2
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

