#!/bin/bash
#
# Script to build all OPERA PGE Docker images
#

echo '
=======================================

Building all OPERA PGE docker images...

=======================================
'

TAG=$1

# defaults
[ -z "${WORKSPACE}" ] && WORKSPACE=$(realpath $(dirname $(realpath $0))/../..)
[ -z "${TAG}" ] && TAG="${USER}-dev"

echo "WORKSPACE: $WORKSPACE"
echo "TAG: $TAG"

# check .ci scripts directory exists
if [ ! -d "${WORKSPACE}/.ci" ]; then
  echo "Error: the .ci directory doesn't exist at ${WORKSPACE}/.ci"
  exit 1
fi

# Build all of the Docker images
BUILD_SCRIPTS_DIR=${WORKSPACE}/.ci/scripts
${BUILD_SCRIPTS_DIR}/build_dswx_hls.sh --tag ${TAG} --workspace ${WORKSPACE}
${BUILD_SCRIPTS_DIR}/build_cslc_s1.sh --tag ${TAG} --workspace ${WORKSPACE}
${BUILD_SCRIPTS_DIR}/build_rtc_s1.sh --tag ${TAG} --workspace ${WORKSPACE}

echo 'Build Complete'

exit 0
