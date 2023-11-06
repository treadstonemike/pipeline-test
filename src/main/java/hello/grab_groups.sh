#!/bin/bash

if [[ -z $1 ]]; then
  echo "Please supply a group name";
  exit 1;
fi

DEBUG=false

GROUP="$1"
VERSION="";

TIMESTAMP=`date +%s`
WORKING_DIR="maven-artifacts-query-${TIMESTAMP}"
mkdir ${WORKING_DIR}

RETRIEVED_ENTRY_COUNT=0
PAGE=0
#supports 1-200
PAGE_SIZE=200

RESULT_FILENAME="${GROUP}-entries-${TIMESTAMP}.txt"
touch ${RESULT_FILENAME}  

if ${DEBUG}; then
  echo "Result Filename: ${RESULT_FILENAME}"
  echo "Working Directory: ${WORKING_DIR}"
fi

#grab the first page, as it has the paging information for the rest of the queries:

HOSTNAME=search.maven.org
https://nexus-trunk.udev.six3/#browse/search=keyword%3Dcloudward
BASE_URL1="https://search.maven.org/solrsearch/select?q=g:${GROUP}&rows=200";
if [[ -n $2 ]]; then
  BASE_URL1="https://search.maven.org/solrsearch/select?q=g:${GROUP}+AND+v:${2}&rows=200" 
fi
if ${DEBUG}; then
  echo "Querying ${BASE_URL1}&start=${PAGE}, and writing the results to '${WORKING_DIR}/${GROUP}-response-${PAGE}.json'"
fi
curl -s "${BASE_URL1}&start=${PAGE}" > ${WORKING_DIR}/${GROUP}-response-${PAGE}.json

if ${DEBUG}; then
  echo
  echo "Result file contents:"
  cat ${WORKING_DIR}/${GROUP}-response-${PAGE}.json
  echo 
  echo
fi

if [ $? -eq 0 ]; then
  ((RETRIEVED_ENTRY_COUNT+=PAGE_SIZE))
  ((PAGE++))

  RESPONSE_COUNT=`jq '.response.numFound' ${WORKING_DIR}/${GROUP}-response-0.json`
  PAGE_COUNT=$(($RESPONSE_COUNT / $PAGE_SIZE))
  REMAINDER=$(($RESPONSE_COUNT / $PAGE_SIZE))

  if [[ "$REMAINDER" -gt 0 ]]; then
    ((PAGE_COUNT++))
  fi

  if ${DEBUG}; then
    echo "Response Count from last query: ${RESPONSE_COUNT}"
    echo "Page Count: ${PAGE_COUNT}"
    echo "Remainder: ${REMAINDER}"
  fi

  until [ $RETRIEVED_ENTRY_COUNT -gt $RESPONSE_COUNT ]
  do
    if ${DEBUG}; then
      echo "Querying ${BASE_URL1}&start=${PAGE}, and writing the results to '${WORKING_DIR}/${GROUP}-response-${PAGE}.json'"
    fi
    curl -s "${BASE_URL1}&start=${PAGE}" > ${WORKING_DIR}/${GROUP}-response-${PAGE}.json
    ((RETRIEVED_ENTRY_COUNT+=PAGE_SIZE))
    ((PAGE++))
  done

  for RESULT in ${WORKING_DIR}/${GROUP}-response-*.json
  do
    if [[ -n $2 ]]; then
      jq '.response.docs[]' ${RESULT} | jq '"\(.g):\(.a):\(.v)"' | sed 's/"//g'>>${RESULT_FILENAME}
    else 
      jq '.response.docs[]' ${RESULT} | jq '"\(.g):\(.a):\(.latestVersion)"' | sed 's/"//g'>>${RESULT_FILENAME}
    fi
  done
fi 

#grab the first page, as it has the paging information for the rest of the queries:
BASE_URL2="https://search.maven.org/solrsearch/select?q=g:${GROUP}*&rows=200";
if [[ -n $2 ]]; then
  BASE_URL2="https://search.maven.org/solrsearch/select?q=g:${GROUP}*+AND+v:${2}&rows=200" 
fi

if ${DEBUG}; then
  echo "Querying ${BASE_URL2}&start=${PAGE}, and writing the results to '${WORKING_DIR}/${GROUP}-response-${PAGE}.json'"
fi

curl -s "${BASE_URL2}&start=${PAGE}" > ${WORKING_DIR}/${GROUP}-response-${PAGE}.json
if [ $? -eq 0 ]; then
  ((RETRIEVED_ENTRY_COUNT+=PAGE_SIZE))
  ((PAGE++))

  RESPONSE_COUNT=`jq '.response.numFound' ${WORKING_DIR}/${GROUP}-response-1.json`
  echo "attepting to get page count: $RESPONSE_COUNT / $PAGE_SIZE"
  PAGE_COUNT=$(($RESPONSE_COUNT / $PAGE_SIZE))
  REMAINDER=$(($RESPONSE_COUNT / $PAGE_SIZE))
  if [[ "$REMAINDER" -gt 0 ]]; then
    ((PAGE_COUNT++))
  fi

  until [ $RETRIEVED_ENTRY_COUNT -gt $RESPONSE_COUNT ]
  do
    if ${DEBUG}; then
      echo "Querying ${BASE_URL2}&start=${PAGE}, and writing the results to '${WORKING_DIR}/${GROUP}-response-${PAGE}.json'"
    fi

    curl -s "${BASE_URL2}&start=${PAGE}" > ${WORKING_DIR}/${GROUP}-response-${PAGE}.json
    ((RETRIEVED_ENTRY_COUNT+=PAGE_SIZE))
    ((PAGE++))
  done

  for RESULT in ${WORKING_DIR}/${GROUP}-response-*.json
  do
    if [[ -n $2 ]]; then
      jq '.response.docs[]' ${RESULT} | jq '"\(.g):\(.a):\(.v)"' | sed 's/"//g'>>${RESULT_FILENAME}
    else 
      jq '.response.docs[]' ${RESULT} | jq '"\(.g):\(.a):\(.latestVersion)"' | sed 's/"//g'>>${RESULT_FILENAME}
    fi
  done

  cat ${RESULT_FILENAME} | sort | uniq | awk -vORS=, '{ print $1 }' | sed 's/,$/\n/'

  if ! ${DEBUG}; then
    rm -rf ${WORKING_DIR}
    rm ${RESULT_FILENAME}
  fi
fi 