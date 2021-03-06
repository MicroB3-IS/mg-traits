##########################
### 1 - functions 
#########################


function email_comm() {
  mail -s "mg_traits:${JOB_ID} failed" "${mt_admin_mail}" <<EOF
"${1}"
EOF
}


function cleanup {
rsync -a --remove-source-files "${THIS_JOB_TMP_DIR}" "${FAILED_JOBS_DIR}"
rmdir "${THIS_JOB_TMP_DIR}"
}


function error_exit() {
  local msg=${1}
  local exit_code=${2}
  echo ${msg} 1>&2

  if [[ -n "${mt_admin_mail}" ]]; then
    email_comm ${1}
  fi

  cleanup
  exit ${exit_code}
}

function db_error_comm() {
  echo "UPDATE ${schema}.mg_traits_jobs SET time_finished = now(), \
  return_code = 1, error_message = '${1}' WHERE sample_label = \
  '${SAMPLE_LABEL}' AND id = '${ID}';" | psql -U "${target_db_user}" -h \
  "${target_db_host}" -p "${target_db_port}" -d "${target_db_name}"
}

##########################
### 2 - functions
#########################


function check_required_programs() {

    req_progs=("$@"); 
    ERROR_UTILITIES=""

    for p in ${req_progs[@]}; do
      hash "${p}" 2>&- || \
      if  [[ -z "${ERROR_UTILITIES}" ]]; then
        ERROR_UTILITIES="${p}"
      else
        ERROR_UTILITIES="${ERROR_UTILITIES} ${p}"
      fi
    done
  echo "${ERROR_UTILITIES}"
}

function check_required_files() {

    req_files=("$@");
    ERROR_UTILITIES=""

    for f in "${req_files[@]}"; do
        if [[ ! -r "${f}" ]]; then
          if [[ -z "${ERROR_FILES}" ]]; then
            ERROR_FILES="${f}"
          else
            ERROR_FILES="${ERROR_FILES} ${f}"
          fi
        fi
    done
    echo "${ERROR_FILES}"
}



function check_required_writable_directories() {

    req_dirs=("$@"); 
    ERROR_WDIRECTORIES=""
   
    for d in "${req_dirs[@]}"; do
        if [[ ! -d "${d}" && ! -w "${d}" ]]; then 
          if [[ -z "${ERROR_WDIRECTORIES}" ]]; then 
            ERROR_WDIRECTORIES="${d}"
          else
            ERROR_WDIRECTORIES="${ERROR_WDIRECTORIES} ${d}"
          fi
        fi
    done
    echo "${ERROR_WDIRECTORIES}"
}


function check_required_readable_directories() {

  req_dirs=("$@");
  ERROR_RDIRECTORIES=""

  for d in "${req_dirs[@]}"; do
    if [[ ! -d "${d}" && ! -r "${d}" ]]; then
      if [[ -z "${ERROR_RDIRECTORIES}" ]]; then
        ERROR_RDIRECTORIES="${d}"
      else
        ERROR_RDIRECTORIES="${ERROR_RDIRECTORIES} ${d}"
      fi
    fi 
  done
  echo "${ERROR_RDIRECTORIES}"
}


### CHANGE SCHEMA TO mg_traits!!!!
function db_table_load1() {
  tail -n1 "${1}" | awk -vI="${ID}" -vO="${SAMPLE_LABEL}" \
  '{print I"\t"O"\t"$0}' | psql -U "${target_db_user}" \
  -h "${target_db_host}" -p "${target_db_port}" -d "${target_db_name}" \
  -c "\COPY ${schema}.${2} FROM STDIN CSV delimiter E'\t'"
}

### CHANGE SCHEMA TO mg_traits!!!!
function db_table_load2() {
  tail -n1 "${1}" | awk -vI="${ID}" -vO="${SAMPLE_LABEL}" \
  '{print O"\t"$0"\t"I}' | psql -U "${target_db_user}" \
  -h "${target_db_host}" -p "${target_db_port}" -d "${target_db_name}" \
  -c "\COPY ${schema}.${2} FROM STDIN CSV delimiter E'\t'"
}


data_retriever1() {
  echo "\COPY (SELECT A.* from mg_traits.${1} A INNER JOIN \
  mg_traits.mg_traits_jobs_public P ON A.id = P.id) TO ${2} CSV HEADER \
  delimiter E'\t'" | psql \
 -U "${target_db_user}" -h "${target_db_host}" \
 -p "${target_db_port}" -d "${target_db_name}"
}


data_retriever2() {
  echo "\COPY (SELECT F.id,(each(${1})).key as key, (each(${1})).value FROM \
  mg_traits.${2} F inner join mg_traits.mg_traits_jobs_public P on F.id = P.id \
  order by id, key) TO ${3} CSV HEADER delimiter E'\t'" | psql \
  -U "${target_db_user}" -h "${target_db_host}" \
  -p "${target_db_port}" -d "${target_db_name}"
}


### CHANGE SCHEMA TO mg_traits!!!!
function db_pca_load() {
 cat "${1}" | psql -U "${target_db_user}" -h "${target_db_host}" \
 -p "${target_db_port}" -d "${target_db_name}" \
 -c "\COPY ${schema}.mg_traits_pca FROM STDIN CSV delimiter E'\t'"
}

trap cleanup SIGINT SIGKILL SIGTERM

