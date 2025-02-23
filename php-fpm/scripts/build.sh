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

## Build Dir should be the search path + variant (e.g. php-fpm/magento2)
BUILD_DIR="${SEARCH_PATH}/${VARIANT}"

## Image name should only be the top-level directory (e.g. php-fpm)
IMAGE_NAME=$(echo "${BUILD_DIR}" | cut -d/ -f1)
[[ "${INDEV_FLAG:-1}" != "0" ]] && IMAGE_NAME="${IMAGE_NAME}-indev"

## Tag suffix should be the variant (e.g. magento2, magento2-xdebug3)
TAG_SUFFIX=$(echo ${VARIANT} | tr / - | sed 's/^-//')
## If the tag suffix is "_base", remove it
[[ "${TAG_SUFFIX}" == "_base" ]] && TAG_SUFFIX=""

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

echo "Build Context ...... : ${BUILD_CONTEXT}"

docker buildx use warden-builder >/dev/null 2>&1 || docker buildx create --name warden-builder --use

echo "::group::Environment Variables"
  echo "Platform ........... : ${PLATFORM}"
  echo "ENV Source Image ... : ${ENV_SOURCE_IMAGE}" 
  echo "PHP Source Image ... : ${PHP_SOURCE_IMAGE}" 
  echo "PHP Version ........ : ${PHP_VERSION}" 
  echo "PHP Variant ........ : ${VARIANT}" 
  echo "Image Name ......... : ${IMAGE_NAME}" 
echo "::endgroup::"

echo "::group::Building ${IMAGE_NAME}:${IMAGE_TAG} (${TAG_SUFFIX})"

  BUILDER_IMAGE_NAME=$IMAGE_NAME
  [[ "$VARIANT" != "_base" ]] && BUILDER_IMAGE_NAME="${IMAGE_NAME}-${VARIANT}"

  echo ""
  echo "Builder Image Name ... : ${BUILDER_IMAGE_NAME}"
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
    MAJOR_TAG="${MAJOR_TAG}-${TAG_SUFFIX}"
    MINOR_TAG="${MINOR_TAG}-${TAG_SUFFIX}"
  fi

  IMAGE_TAGS=(
    ${MAJOR_TAG}
    ${MINOR_TAG}
  )

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

  echo "::notice title=Container image digest for ${IMAGE_NAME} (${PLATFORM##*/})::${digest}"

echo "::endgroup::"