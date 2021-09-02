#!/bin/bash
set -o errexit

# Default configuration
# URI to access Big Bang Git API Releases
BBURI="https://repo1.dso.mil/api/v4/projects/platform-one%2Fbig-bang%2Fbigbang/releases"
# Output directory for artifacts produced
OUTDIR="."
# Port to run Docker registry on
REGPORT=5000

# Functions
function help {
  cat << EOF
This script will identify images that have changed between Big Bang versions and create a new manifest and images tarball.
usage: $(basename "$0") <arguments>
  -c|--current <version> - [Required] Current version of Big Bang
    |--debug             - Turn on script tracing and debug messaging
  -h|--help              - Print help and exit
  -o|--output <dirpath>  - Folder to output the images.txt and images.tar.gz.  Defaults to current directory.
  -p|--port <number>     - Port to run the Docker registry on for trimming images.tar.gz.  Defaults to 5000.
  -s|--skipzip           - Skip the creation of the tar.gz file.
  -t|--target <version>  - Target version of Big Bang.  Defaults to latest release.
  -v|--verbose           - Verbose mode
  -w|--workdir <dirpath> - Working directory.  Defaults to random directory under /tmp.
  -z|--zip <filepath>    - Location of already downloaded images.tar.gz
EOF
  exit 1
}

function verifyApiResponse {
  local response=$1

  # Error: Didn't match anything
  if [ "[]" = "${response}" ]; then
    echo -e "\033[0;31mERROR: API returned an empty array\033[0m" >&2; exit 1;
  fi

  # Error: Returned a problem
  if [ "object" = "$(echo ${response} | jq -r '. | type')" ]; then
    echo -e "\033[0;31mERROR: API returned $(echo ${response} | jq)\033[0m" >&2; exit 1;
  fi
}

# Options
ARGS=$(getopt -o 'c:ho:p:st:vw:z:' -l 'current:,debug,help,output:,port:,skipzip,target:,verbose,workdir:,zip:' -- "$@") || exit
eval "set -- $ARGS"
while true; do
  case $1 in
    (-c|--current)
      CURRVER=$2; shift 2;;
    (--debug)
      set -o xtrace; set -o verbose; shift;;
    (-h|--help)
      help;;
    (-o|--output)
      OUTDIR=$2; shift 2;;
    (-p|--port)
      REGPORT=$2; shift 2;;
    (-s|--skipzip)
      SKIPZIP=1; shift;;
    (-t|--target)
      TARGVER=$2; shift 2;;
    (-v|--verbose)
      VERBOSE=1; shift;;
    (-w|--workdir)
      TMPDIR=$2; shift 2;;
    (-z|--zip)
      TARGZIPFILE=$2; shift 2;;
    (--)
      shift; break;;
    (*)
      exit 1;;
  esac
done

# Required options
if [ -z "${CURRVER}" ]; then
  echo -e "\033[0;31mERROR: Missing required option -c|--current <version>.\033[0m" >&2; help; exit 1
fi

# Check for prerequisities
TOOLS=(curl jq)
for TOOL in ${TOOLS[*]}; do
  hash $TOOL 2>/dev/null || { echo -e "\033[0;31mERROR: This script requires ${TOOL}, but it is not installed.\033[0m" >&2; exit 1; }
done
if [ ! ${SKIPZIP} ]; then
  # Tools if dealing with tar.gz creation
  TOOLS=(tar docker awk cut grep timeout bash)
  for TOOL in ${TOOLS[*]}; do
    hash $TOOL 2>/dev/null || { echo "\033[0;31mERROR: This script requires ${TOOL}, but it is not installed.\033[0m" >&2; exit 1; }
  done
fi

# Retrieve details
echo -n "Retrieving details for Big Bang releases ... "
if [ ${VERBOSE} ]; then echo; echo "Request: ${BBURI}"; fi
RELS=$(curl -sL "${BBURI}")
verifyApiResponse "${RELS}"

# If target version is not specified, get the latest release
if [ -z ${TARGVER} ]; then
  TARGVER=$(echo "${RELS}" | jq -r 'sort_by(.released_at) | .[-1].tag_name')
  if [ ${VERBOSE} ]; then echo "Target version set to ${TARGVER}"; fi
fi

# Print out releases we are interested in
if [ ${VERBOSE} ]; then
  echo "Release for ${CURRVER}:"
  echo ${RELS} | jq ".[] | select(.tag_name == \"${CURRVER}\")"
  echo "Release for ${TARGVER}:"
  echo ${RELS} | jq ".[] | select(.tag_name == \"${TARGVER}\")"
fi

# Get links to artifacts
CURRTXT=$(echo "${RELS}" | jq -r ".[] | select(.tag_name == \"${CURRVER}\") | .assets.links[] | select(.name == \"images.txt\") | .direct_asset_url")
if [ ${VERBOSE} ]; then echo "images.txt Link: $CURRTXT"; fi
if [ -z "${CURRTXT}" ]; then
  echo; echo -e "\033[0;31mERROR: Could not find link to images.txt in Big Bang release ${CURRVER}.\033[0m" >&2; exit 1
fi

TARGTXT=$(echo "${RELS}" | jq -r ".[] | select(.tag_name == \"${TARGVER}\") | .assets.links[] | select(.name == \"images.txt\") | .direct_asset_url")
if [ ${VERBOSE} ]; then echo "images.txt Link: $TARGTXT"; fi
if [ -z "${TARGTXT}" ]; then
  echo; echo -e "\033[0;31mERROR: Could not find link to images.txt in Big Bang release ${TARGVER}.\033[0m" >&2; exit 1
fi

TARGZIP=$(echo "${RELS}" | jq -r ".[] | select(.tag_name == \"${TARGVER}\") | .assets.links[] | select(.name == \"images.tar.gz\") | .direct_asset_url")
if [ ${VERBOSE} ]; then echo "images.tar.gz Link: $TARGZIP"; fi
if [ -z "${TARGZIP}" ]; then
  echo; echo -e "\033[0;31mERROR: Could not find link to images.tar.gz in Big Bang release ${TARGVER}.\033[0m" >&2; exit 1
fi
echo -e "\033[0;32mdone\033[0m."

echo -n "Downloading image manifests ... "
if [ ${VERBOSE} ]; then echo; echo "Request: ${CURRTXT}"; fi
CURRIMGS=$(curl -sL "${CURRTXT}")
if [ ${VERBOSE} ]; then echo "Response:"; echo "${CURRIMGS}"; fi
if [ -z "${CURRIMGS}" ]; then
  echo; echo -e "\033[0;31mERROR: No images returned from ${CURRTXT}.\033[0m" >&2; exit 1
fi

if [ ${VERBOSE} ]; then echo; echo "Request: ${TARGTXT}"; fi
TARGIMGS=$(curl -sL "${TARGTXT}")
if [ ${VERBOSE} ]; then echo "Response:"; echo "${TARGIMGS}"; fi
if [ -z "${CURRIMGS}" ]; then
  echo; echo -e "\033[0;31mERROR: No images returned from ${TARGTXT}.\033[0m" >&2; exit 1
fi

echo -e "\033[0;32mdone\033[0m."

# Find images in both versions
echo -n "Comparing Big Bang image from ${CURRVER} to ${TARGVER} ... "
if [ ${VERBOSE} ]; then echo; fi
for TARGIMG in ${TARGIMGS[@]}; do
  FOUND=0
  for CURRIMG in ${CURRIMGS[@]}; do
    # Compare images in both arrays.  If found, add to duplicate image array and break the loop.
    if [ "${CURRIMG}" == "${TARGIMG}" ]; then
      if [ ${VERBOSE} ]; then echo "SAME: ${CURRIMG}"; fi
      DUPEIMGS+=("${CURRIMG}")
      FOUND=1
      break
    fi
  done
  if [ "${FOUND}" == 0 ]; then
    if [ ${VERBOSE} ]; then echo "NEW: ${TARGIMG}"; fi
    UNIQIMGS+=("${TARGIMG}")
  fi
done
echo -e "\033[0;32mdone\033[0m."

# Output new manifest
OUTTXT="images.${CURRVER}_to_${TARGVER}.txt"
if [ ! -d "${OUTDIR}" ]; then
  echo "Output directory ${OUTDIR} created."
  mkdir "${OUTDIR}"
fi
echo -n "Creating new manifest at ${OUTDIR}/${OUTTXT} ... "
printf '%s\n' "${UNIQIMGS[@]}" > "${OUTDIR}/${OUTTXT}"
echo -e "\033[0;32mdone\033[0m."

# Skip over zip file creation if specified
if [ ! ${SKIPZIP} ]; then
  if [ ! "${TMPDIR}" ]; then
    TMPDIR=$(mktemp -d)
    if [ ! -d "${TMPDIR}" ]; then
      echo -e "\033[0;31mERROR: Could not create a temporary directory for image.tar.gz using 'mktemp -d'\033[0m" >&2; exit 1;
    fi
  else
    if [ ! -d "${TMPDIR}" ]; then
      mkdir "${TMPDIR}"
    else
      # User provided directory that already exists.  Do not clean it up.
      KEEPTMPDIR=1
    fi
  fi

  # Put images.tar.gz into temp directory
  if [ ! -f "${TARGZIPFILE}" ]; then
    echo "Downloading Big Bang ${TARGVER} images.tar.gz to ${TMPDIR} ... "
    if [ ${VERBOSE} ]; then echo "Request: ${TARGZIP}"; fi
    curl -L "${TARGZIP}" -o "${TMPDIR}/images.${TARGVER}.tar.gz"
    TARGZIPFILE="${TMPDIR}/images.${TARGVER}.tar.gz"
  fi

  echo -n "Extracting ${TARGZIPFILE} to ${TMPDIR} "
  # Cleanup old extractions if needed
  if [ -d "${TMPDIR}/var" ]; then
    rm -rf "${TMPDIR}/var"
  fi
  # Extract tar.gz
  tar --checkpoint=.25000 -xf ${TARGZIPFILE} -C "${TMPDIR}"
  echo -e " \033[0;32mdone\033[0m."

  # Remove any conflicting running containers silently
  docker rm -f registry > /dev/null 2> /dev/null
  # Start registry
  echo -n "Starting Docker registry on port ${REGPORT} ... "
  REGCONT=$(docker run -d -e REGISTRY_STORAGE_DELETE_ENABLED=true -p ${REGPORT}:5000 --name registry -v ${TMPDIR}/var/lib/registry:/var/lib/registry registry:2)
  if [ -z "${REGCONT}" ]; then
    echo -e "\033[0;31mERROR: Could not start Docker registry\033[0m" >&2; exit 1;
  fi
  # Wait for registry to be ready
  timeout 5 bash -c "until curl -s localhost:${REGPORT}/v2; do sleep 0.5; done" 2>&1 > /dev/null
  echo -e "\033[0;32mdone\033[0m."

  # Delete dupe images
  echo -n "Removing duplicate images ... "
  if [ ${VERBOSE} ]; then echo; fi
  for DUPEIMG in ${DUPEIMGS[@]}; do
    # Images consist of a registry/repository:tag.  Split on ':' and cut off registry
    DUPEREPO=$(echo "${DUPEIMG}" | awk '{split($0,SPLIT,":"); print SPLIT[1];}' | cut -d/ -f2-)
    DUPETAG=$(echo "${DUPEIMG}" | awk '{split($0,SPLIT,":"); print SPLIT[2];}')

    # Skip special "registry" image
    if [ "registry" == "${DUPEREPO}" ]; then continue; fi

    # Get digest for image using repo and tag
    if [ ${VERBOSE} ]; then echo "Attempting to get manifest from http://localhost:${REGPORT}/v2/${DUPEREPO}/manifests/${DUPETAG}"; fi
    DUPEDIG=$(curl -vsLH "Accept: application/vnd.docker.distribution.manifest.v2+json" "http://localhost:${REGPORT}/v2/${DUPEREPO}/manifests/${DUPETAG}" 2>&1 | grep -o -P "(?<=Docker-Content-Digest: )[a-z0-9:]*" || true)
    if [ -z "${DUPEDIG}" ]; then
      echo -e "\033[1;33mWARNING: Did not find ${DUPEIMG} in images.tar.gz.\033[0m"
    else
      if [ ${VERBOSE} ]; then echo "Digest for ${DUPEREPO}:${DUPETAG} is ${DUPEDIG}"; fi
      # Delete image using digest
      if [ ${VERBOSE} ]; then echo "Deleting image http://localhost:${REGPORT}/v2/${DUPEREPO}/manifests/${DUPEDIG}"; fi
      REGCODE=$(curl -sL -w %{response_code} -o /dev/null -X DELETE "http://localhost:${REGPORT}/v2/${DUPEREPO}/manifests/${DUPEDIG}")
      if [ ${VERBOSE} ]; then echo "Response code: ${REGCODE}"; fi
      if [ "${REGCODE}" == "202" ]; then
        if [ ${VERBOSE} ]; then echo "Successfully deleted ${DUPEIMG}"; fi
      else
        echo -e "\033[1;33mWARNING: Deletion of ${DUPEIMG} failed!\033[0m"
      fi
    fi
  done

  # Run garbage collection.  This only removes the images, not the repositories
  GC=$(docker exec registry /bin/registry garbage-collect /etc/docker/registry/config.yml 2>&1)
  if [ ${VERBOSE} ]; then echo "Garbage Collection:"; echo ${GC}; fi

  # Remove registry container
  docker rm -f ${REGCONT} > /dev/null
  echo -e "\033[0;32mdone\033[0m."

  echo -n "Removing duplicate repositories ... "
  if [ ${VERBOSE} ]; then echo; fi

  # Remove repository manually
  # Registry container unsets this permission.  Need to set it back to have access
  chmod u+x "${TMPDIR}/var/lib/registry"
  for DUPEIMG in ${DUPEIMGS[@]}; do
    # Images consist of a registry/repository:tag.  Split on ':' and cut off registry
    DUPEREPO=$(echo "${DUPEIMG}" | awk '{split($0,SPLIT,":"); print SPLIT[1];}' | cut -d/ -f2-)
    if [ ${VERBOSE} ]; then echo -n "Deleting repository ${DUPEREPO} ... "; fi
    rm -rf "${TMPDIR}/var/lib/registry/docker/registry/v2/repositories/${DUPEREPO}" > /dev/null
    if [ ${VERBOSE} ]; then echo -e "\033[0;32mdone\033[0m."; fi
  done
  echo -e "\033[0;32mdone\033[0m."

  # Compress images
  OUTZIP="images.${CURRVER}_to_${TARGVER}.tar.gz"
  echo -n "Compressing images into ${OUTDIR}/${OUTZIP} "
  tar --checkpoint=.10000 -C "${TMPDIR}" -caf "${OUTDIR}/${OUTZIP}" var
  echo -e " \033[0;32mdone\033[0m."

  # Cleanup
  echo -n "Cleaning up ${TMPDIR} ... "
  if [ ${KEEPTMPDIR} ]; then
    # Only delete what we created
    rm -rf "${TMPDIR}/var"
    rm -f "${TMPDIR}/${TARGZIPFILE}"
  else
    rm -rf ${TMPDIR}
  fi
  echo -e "\033[0;32mdone\033[0m."

  echo; echo "Successfully created ${OUTTXT} and ${OUTZIP} in ${OUTDIR}"
else
  echo; echo "Successfully created ${OUTTXT} in ${OUTDIR}"
fi
