#!/usr/bin/env bash
set -e
trap 'error "$(printf "Command \`%s\` at $BASH_SOURCE:$LINENO failed with exit code $?" "$BASH_COMMAND")"' ERR

## find directory where this script is located following symlinks if neccessary
## 
readonly BASE_DIR="$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")")"
pushd ${BASE_DIR} >/dev/null

function version {
  echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }';
}

function compareVersions() {
  [[ $1 == $2 ]] && return 0

  local IFS=.
  local i ver1=($1) ver2=($2)
  # fill empty fields in ver1 with zeros
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do ver1[i]=0; done

  for ((i=0; i<${#ver1[@]}; i++)); do
    if ((10#${ver1[i]:=0} > 10#${ver2[i]:=0})); then
      return 1
    fi
    if ((10#${ver1[i]:=0} < 10#${ver2[i]:=0})); then
      return 2
    fi
  done
  return 0
}

function versionCompare() {
  compareVersions $1 $2
  local result=$?

  case "${3:->}" in
    "<")
      [[ $result == 2 ]] && return 0
    ;;
    "<=")
      [[ $result == 0 || $result == 2 ]] && return 0
    ;;
    "=")
      [[ $result == 0 ]] && return 0
    ;;
    ">=")
      [[ $result == 0 || $result == 1 ]] && return 0
    ;;
    ">")
      [[ $result == 1 ]] && return 0
    ;;
  esac
  return 1
}


## if --push is passed as first argument to script, this will login to docker hub and push images
PUSH_FLAG=${PUSH_FLAG:-0}
if [[ "${1:-}" = "--push" ]]; then
  PUSH_FLAG=1
  SEARCH_PATH="${2:-}"
else
  SEARCH_PATH="${1:-}"
fi

## since fpm images no longer can be traversed, this script should require a search path vs defaulting to build all
if [[ -z ${SEARCH_PATH} ]]; then
  echo "::error title=Search Path Undefined" \
    "::Missing search path. Please try again passing an image type as an argument."
  exit 1
fi

## login to docker hub as needed
if [[ ${PUSH_FLAG} != 0 && ${PRE_AUTH:-0} != 1 ]]; then
  if [[ ${DOCKERHUB_USERNAME:-} ]]; then
    echo "Attempting non-interactive docker login (via provided credentials)"
    echo "${DOCKERHUB_TOKEN:-}" | docker login -u "${DOCKERHUB_USERNAME:-}" --password-stdin ${DOCKER_REGISTRY:-docker.io}
  elif [[ -t 1 ]]; then
    echo "Attempting interactive docker login (tty)"
    docker login ${DOCKER_REGISTRY:-docker.io}
  fi
fi

## define image repository to push
WARDEN_IMAGE_REPOSITORY="${WARDEN_IMAGE_REPOSITORY:-"ghcr.io/wardenenv"}"

PHP_SOURCE_IMAGE="${PHP_SOURCE_IMAGE:-"ghcr.io/wardenenv/centos-php"}"
if [[ "${INDEV_FLAG:-1}" != "0" ]]; then
  PHP_SOURCE_IMAGE="${PHP_SOURCE_IMAGE}-indev"
fi

ENV_SOURCE_IMAGE="${ENV_SOURCE_IMAGE:-"${WARDEN_IMAGE_REPOSITORY}/php-fpm"}"
if [[ "${INDEV_FLAG:-1}" != "0" ]]; then
  ENV_SOURCE_IMAGE="${ENV_SOURCE_IMAGE}-indev"
fi
# export PHP_SOURCE_IMAGE ENV_SOURCE_IMAGE

if [[ -z ${PHP_VERSION} ]]; then
  echo "::error title=PHP Version Undefined" \
    "::Building ${SEARCH_PATH} images requires PHP_VERSION env variable be set."
  exit 2
fi

## Build Dir should be the search path + variant (e.g. php-fpm/magento2, php-fpm/magento2/xdebug3)
BUILD_DIR="${SEARCH_PATH}/${VARIANT}"

## Image name should only be the top-level directory (e.g. php-fpm)
IMAGE_NAME=$(echo "${BUILD_DIR}" | cut -d/ -f1)
[[ "${INDEV_FLAG:-1}" != "0" ]] && IMAGE_NAME="${IMAGE_NAME}-indev"

## Tag suffix should be the variant prefixed by any trailing directory of build dir (e.g. magento2, magento2-xdebug3)

## Start with the last part(s) of the build directory
TAG_SUFFIX=$(echo "${BUILD_DIR}" | cut -d/ -f2-)
## If it ends with "/_base" or is just "_base" then remove it
[[ "${TAG_SUFFIX}" =~ /_base$ ]] && TAG_SUFFIX="${TAG_SUFFIX%%/_base}"
[[ "${TAG_SUFFIX}" =~ ^_base$ ]] && TAG_SUFFIX="${TAG_SUFFIX%%_base}"
## Replace dashes with hyphens
TAG_SUFFIX="${TAG_SUFFIX//\//-}"
## if the tag isn't empty, prefix it with a dash
[[ -n "${TAG_SUFFIX}" ]] && TAG_SUFFIX="-${TAG_SUFFIX}"

BUILD_ARGS=(PHP_SOURCE_IMAGE ENV_SOURCE_IMAGE PHP_VERSION)
if [[ ${PHP_VARIANT:-} ]]; then
  BUILD_ARGS+=(PHP_VARIANT)
fi

PUSH_FLAG=""
[[ $PUSH_FLAG != 0 ]] && PUSH_FLAG="--push"

# Skip build of xdebug3 fpm images on older versions of PHP (it requires PHP 7.2 or greater)
if [[ ${IMAGE_SUFFIX} =~ xdebug3 ]] && test $(version ${PHP_VERSION}) -lt $(version "7.2"); then
  echo "::notice file=php-fpm/scripts/build.sh,line=96,title=Xdebug Unavailable" \
    "::Skipping build for ${IMAGE_NAME}:${IMAGE_TAG} (xdebug3 is unavailable for PHP/${PHP_VERSION})"
  exit 0
fi

# Check if the current build directory has a context directory
if [[ -d "${BUILD_DIR}/context" ]]; then
  BUILD_CONTEXT="${BUILD_DIR}/context"
# Check if the root image type variant has a context directory
elif [[ -d "$(echo $BUILD_DIR | cut -d/ -f1)/${VARIANT}/context" ]]; then
  BUILD_CONTEXT="$(echo $BUILD_DIR | cut -d/ -f1)/${VARIANT}/context"
# Use the entire build directory as the context
else
  BUILD_CONTEXT="${BUILD_DIR}"
fi

echo "::group::Downloading Container Structure Test"
  curl -LO https://github.com/GoogleContainerTools/container-structure-test/releases/latest/download/container-structure-test-${PLATFORM//\//-}
  mv container-structure-test-${PLATFORM//\//-} ${BASE_DIR}/container-structure-test
  chmod +x ${BASE_DIR}/container-structure-test
echo "::endgroup::"

echo "::group::Environment Variables"
  echo "   Build Directory .... : ${BUILD_DIR}"
  echo "   Build Context ...... : ${BUILD_CONTEXT}"
  echo "   Platform ........... : ${PLATFORM}"
  echo "   ENV Source Image ... : ${ENV_SOURCE_IMAGE}" 
  echo "   PHP Source Image ... : ${PHP_SOURCE_IMAGE}" 
  echo "   PHP Version ........ : ${PHP_VERSION}" 
  echo "   PHP Variant ........ : ${VARIANT}" 
  echo "   Image Name ......... : ${IMAGE_NAME}" 
echo "::endgroup::"

echo "::group::Building ${IMAGE_NAME}:${IMAGE_TAG}${TAG_SUFFIX} (${PLATFORM})"
  docker buildx use warden-builder >/dev/null 2>&1 || docker buildx create --name warden-builder --use

  BUILDER_IMAGE_NAME=$IMAGE_NAME
  [[ "$VARIANT" != "_base" ]] && BUILDER_IMAGE_NAME="${IMAGE_NAME}-${PHP_VERSION}${TAG_SUFFIX}"

  echo ""
  echo "    Builder Image Name ... : ${BUILDER_IMAGE_NAME}"
  echo "    Build Context ........ : ${BUILD_CONTEXT}"
  echo "    Image Name ........... : ${IMAGE_NAME}"
  echo "    Compiled Image Tag ... : ${PHP_VERSION}${TAG_SUFFIX}"
  echo ""

  docker buildx build \
    --load \
    --platform=${PLATFORM} \
    -t "${BUILDER_IMAGE_NAME}:build" \
    -f ${BUILD_DIR}/Dockerfile \
    $(printf -- "--build-arg %s " "${BUILD_ARGS[@]}") \
    "${BUILD_CONTEXT}"

  MAJOR_TAG="${PHP_VERSION}"
  MINOR_TAG="${FULL_PHP_VERSION}"
  ## If the suffix is not empty, append it to the image tag
  if [[ -n "${TAG_SUFFIX}" ]]; then
    MAJOR_TAG="${MAJOR_TAG}${TAG_SUFFIX}"
    MINOR_TAG="${MINOR_TAG}${TAG_SUFFIX}"
  fi

  IMAGE_TAGS=(
    ${MAJOR_TAG}
    ${MINOR_TAG}
  )

echo "::endgroup::"

echo "::group::Running container structure test"
  TEST_NAME=$(echo "${BUILD_DIR}" | cut -d/ -f1)
  TEST_VARIANT=$(echo "${BUILD_DIR}" | cut -d/ -f2-)
  [[ "${TEST_VARIANT}" != "_base" ]] && TEST_NAME="${TEST_NAME}-${TEST_VARIANT//\//-}"

  TESTS_DIR="${BASE_DIR}/.github/container-structure-tests"
  if [[ -e "${TESTS_DIR}/${TEST_NAME}.yml" ]]; then
    CST_CONFIGS=("${TESTS_DIR}/${TEST_NAME}.yml")

    if [[ -d "${TESTS_DIR}/${TEST_NAME}" ]]; then
      for FILE in $(ls -r "${TESTS_DIR}/${TEST_NAME}"); do
        APPLIES_TO_VERSION=$(basename "$FILE" | cut -d. -f-2)

        if versionCompare "${PHP_VERSION}" "${APPLIES_TO_VERSION}" ">="; then
          CST_CONFIGS+=("${TESTS_DIR}/${TEST_NAME}/${FILE}")
          break
        fi
      done
    fi

    echo "Container Structure Test Config Files:"
    printf "    - %s\n" "${CST_CONFIGS[@]}"

    ${BASE_DIR}/container-structure-test test --image "${BUILDER_IMAGE_NAME}:build" $(printf -- "--config %s " "${CST_CONFIGS[@]}")
    if [[ $? -ne 0 ]]; then
      echo "::error title=Container Structure Test::Container Structure Test failed"
      exit 2
    fi
  else
    echo -e "\033[01;31m==> No container structure test config found for ${TEST_NAME}\033[0m"
  fi

echo "::endgroup::"

echo "::group::Pushing layers to registries for ${IMAGE_NAME}:${IMAGE_TAG}${TAG_SUFFIX} (${PLATFORM})"

  printf "\e[01;31m==> building ${IMAGE_TAG} from ${BUILD_DIR}/Dockerfile with context ${BUILD_CONTEXT}\033[0m\n"

  NAMES=()
  for registry in $(jq -r '.[]' <<< "${REGISTRIES}"); do
    NAMES+=("${registry}/${IMAGE_NAME}")
  done

  docker buildx build \
    $PUSH_FLAG \
    --platform=${PLATFORM} \
    --metadata-file metadata.json \
    --output=type=image,\"name=$(IFS=, ; echo "${NAMES[*]}")\",push-by-digest=true,name-canonical=true \
    -f ${BUILD_DIR}/Dockerfile \
    $(printf -- "--build-arg %s " "${BUILD_ARGS[@]}") \
    "${BUILD_CONTEXT}"

echo "::endgroup::"

echo "::group::Metadata for ${IMAGE_NAME}:${IMAGE_TAG}${TAG_SUFFIX}"

  echo "${IMAGE_NAME}: $(jq -cr '.[containerimage.digest]' metadata.json)"

  echo -e "\e[01;31m===> Metadata from build image <==\033[0m"
  jq '.' metadata.json
  echo -e "\e[01;31m===> <===\033[0m"

echo "::endgroup::"

echo "::group::Compiling and mapping metadata"

  digest=$(jq -r '."containerimage.digest"' metadata.json)
  tagsJSON=$(printf '%s\n' "${IMAGE_TAGS[@]}" | jq -R . | jq -cs .)
  JSON=$(
    jq -n \
      --arg image "${IMAGE_NAME}" \
      --arg digest "${digest}" \
      --argjson tags "${tagsJSON}" \
      '{ image: $image, digests: [$digest], tags: $tags }'
  )

  mkdir -p "${METADATA_DIR}"
  echo "${JSON}" > "${METADATA_DIR}/${IMAGE_NAME}-${IMAGE_TAG//\//-}${TAG_SUFFIX//\//-}-${PLATFORM//\//-}.json"

  echo "::notice title=Container image digest for ${IMAGE_NAME}${TAG_SUFFIX} (${PLATFORM##*/})::${digest}"

echo "::endgroup::"