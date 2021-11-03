#!/bin/bash
######################################
##  GET THE INPUT CONFIG FILE       ##
##    CONFIG FILE = $1              ##
######################################
# Absolutely not secure !!!
source $1  

######################################
## LABEL FROM $2 AND LOG TIMESTAMP  ##
## USED IN HEADER AND RESPONSE LOG  ##
######################################
label=${2:-''}
#echo $label
log_tmstmp=$(date +%Y%m%d%H%M%S)
#echo $log_tmstmp

######################################
##    GENERATE BASIC TOKEN FROM     ##
##        USER AND PASSWORD         ##
######################################
BAV=$(echo -n "${USER%$'\r'}:${PWD%$'\r'}" | base64) # -n in echo e' FONDAMENTALE


token=''
######################################
##  FUNCTION TO GET THE AUTH TOKEN  ##
###################################### 
get_token(){
	response_token=$(curl -k -s \
	--request GET "${HOST_VALIDATE%$'\r'}" \
	--header "Authorization: Basic $BAV")

	token=$(echo "$response_token" | awk -F'"' '{print $4}')
}

#Call the function
get_token
#echo "$token"

######################################
##    STRING COOKIE GENERATION      ##
###################################### 
## ex: 50afd3ee4e4907ee7f9f923a5edc8873=eab7b06ba120a2cb0d0be7617bd7aad7
COQUE=$(head -3 /dev/urandom |tr -cd 'a-z0-9' | cut -c -32)':'$(head -3 /dev/urandom |tr -cd 'a-z0-9' | cut -c -32)
#echo -n "$COQUE"

######################################
## GET THINK_TIME FROM CONFIG OR    ##
## SEI IT TO 0 IF NOT SET           ##
######################################
THINK_TIME="${THINK_TIME%$'\r'}"
think_time=${THINK_TIME:-0}

######################################
## GET FIRST TIMESTAMP              ##
######################################
TIMSTP_OLD=$(date +"%s")
#echo ${TIMSTP_OLD}

######################################
##       PRINT THE HEADER           ##
######################################
printf "%s;%s;%s;%s;%s;%s\n" "#" "Date Time" "URL" "Response Time (s)" "Response Size (bts)" "Test HTTP Code"


#################################
##  LOOP ON THE INPUT URL FILE ##
################################# 

# Cycle variable
i=0

# Cycle reading file
while read row; do

	    ######################################
		##  GET SECOND LABEL FROM URL NAME  ##
		######################################	
        labelurl=$(echo "$row" | awk -F"/" '{print $5}' | sed "s/\?/-/g" | sed "s/\&//g" )	
		#echo ${labelurl} 

		#####################################
		##   CHECK WHETHER SAVE OR NOT     ##
		##     REQUEST AND RESPONSE        ##
		#####################################		
		FILE_HEADER="./TEMP/${log_tmstmp}_header_tmp_${label}.txt"
		if [  "${PRINT_HEADER%$'\r'}" == "T" ]; then
			FILE_HEADER="headers/${log_tmstmp}_header_${label}_${labelurl}_${i}.txt";
		fi

		FILE_RESPONSE="./TEMP/${log_tmstmp}_respns_tmp_${label}.json"
		if [  "${PRINT_RESPONSE%$'\r'}" == "T" ]; then
			FILE_RESPONSE="responses/${log_tmstmp}_respns_${label}_${labelurl}_${i}.json";
		fi

		######################################
		##         WAITH THINK_TIME         ##
		######################################
		sleep ${think_time}
		
		######################################
		## CALCULATE DELTA TIMESTAMP        ##
		######################################
		TIMSTP_NEW=$(date +"%s")
		if [  $((TIMSTP_NEW - TIMSTP_OLD)) -ge ${DELTA_TIME_TOKEN%$'\r'} ]; then
			#echo "NEW-OLD= " $((TIMSTP_NEW - TIMSTP_OLD));
			get_token
			## Reset the time-stamp OLD
			TIMSTP_OLD=${TIMSTP_NEW}
		fi
		
		######################################
		##      CALL TO THE SERVICE         ##
		######################################
		response_time=$(curl -k -s --request GET "$row" \
		--write-out %{time_total} \
		--dump-header "${FILE_HEADER}" \
		--output "${FILE_RESPONSE}" \
		--header "Authorization: Bearer $token" \
		--header "Cookie: ${COQUE}" \
		--header "Host: ${HOST_API%$'\r'}" \
		--header 'User-Agent: PostmanRuntime/7.26.10' \
		--header 'Accept: */*' \
		--header 'Accept-Encoding: gzip, deflate, br' \
		--header 'Connection: keep-alive') 

		
		# Get the HTTP and content
		http_code=$(head -n1 ${FILE_HEADER}) 
		
		# Increment the counter
		((i=i+1))
		
		# Time-stamp to print in the log
		DATETIME=$(date +%Y-%m-%dH%T)
		
		# Get the file size of the response
		respsize=$(stat -c%s ${FILE_RESPONSE})
		#echo ${respsize}
		
		# Print out the result
	    printf "%s;%s;%s;%s;%s;%s;%s;%s;%s;%s\n" "${i}" "${DATETIME}" "${row}" "${response_time%$'\r'}" "${respsize}" "${http_code%$'\r'}"

done

exit 0;

