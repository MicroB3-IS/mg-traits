##########################
### 1 - functions 
#########################

function email_comm() {
mail -s "mg_traits:${JOB_ID} failed" "${mt_admin_mail}" <<EOF
"${1}"
EOF
}


function db_error_comm() {
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 1, error_message = '${1}' \
  WHERE sample_label = '${SAMPLE_LABEL}' AND id = '${MG_ID}';" | psql -U "${target_db_user}" -h "${target_db_host}" -p "${target_db_port}" -d "${target_db_name}"
}


##########################
### 2 - functions
#########################

function cleanup {
if [[ -f ${TMP_VOL_FILE} ]];then
mv "${TMP_VOL_FILE}" "${THIS_JOB_TMP_DIR}"
fi
mv -f "${THIS_JOB_TMP_DIR}" "${FAILED_JOBS_DIR}"
}


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

function db_pca_load() {
 cat "${1}" | psql -U "${target_db_user}" -h "${target_db_host}" -p "${target_db_port}" -d "${target_db_name}" -c "\COPY mg_traits.mg_traits_pca FROM STDIN CSV delimiter E'\t'"
}


trap cleanup SIGINT SIGKILL SIGTERM

