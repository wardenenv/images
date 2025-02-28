#!/usr/bin/env bash
set -e
trap 'error "$(printf "Command \`%s\` at $BASH_SOURCE:$LINENO failed with exit code $?" "$BASH_COMMAND")"' ERR

function error {
  >&2 printf "\033[31mERROR\033[0m: %s\n" "$@"
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

## find directory above where this script is located following symlinks if neccessary
readonly BASE_DIR="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
pushd "${BASE_DIR}" >/dev/null

readonly ROOT_DIR="$(dirname "${BASE_DIR}")"

## if --push is passed as first argument to script, this will login to docker hub and push images
PUSH_FLAG=${PUSH_FLAG:=0}
if [[ "${1:-}" = "--push" ]]; then
  PUSH_FLAG=1
fi

## login to docker hub as needed
if [[ $PUSH_FLAG != 0 && ${PRE_AUTH:-0} != 1 ]]; then
  if [ -t 1 ]; then
    docker login
  else
    echo "${DOCKER_PASSWORD:-}" | docker login -u "${DOCKER_USERNAME:-}" --password-stdin
  fi
fi

IMAGE_NAME=${IMAGE_NAME:-php}
if [[ "${INDEV_FLAG:-1}" != "0" ]]; then
  IMAGE_NAME="${IMAGE_NAME}-indev"
fi
MAJOR_VERSION="$(echo "${BUILD_VERSION}" | sed -E 's/([0-9])([0-9])/\1.\2/')"
# Configure build args specific to this image build
export PHP_VERSION="${MAJOR_VERSION}"
BUILD_ARGS=(PHP_VERSION)
BUILD_ARGS+=(IMAGE_NAME="${WARDEN_IMAGE_REPOSITORY}/${IMAGE_NAME}")

echo "::group::Downloading Container Structure Test"
  curl -LO https://github.com/GoogleContainerTools/container-structure-test/releases/latest/download/container-structure-test-${PLATFORM//\//-}
  mv container-structure-test-${PLATFORM//\//-} ${ROOT_DIR}/container-structure-test
  chmod +x ${ROOT_DIR}/container-structure-test
echo "::endgroup::"

echo "::group::Building ${IMAGE_NAME}:${BUILD_VERSION} (${BUILD_VARIANT})"

  docker buildx use warden-builder >/dev/null 2>&1 || docker buildx create --name warden-builder --use

  # Build the image passing list of tags and build args
  printf "\e[01;31m==> building %s:%s (%s)\033[0m\n" \
    "${IMAGE_NAME}" "${BUILD_VERSION}" "${BUILD_VARIANT}"

  # Build the multi-arch image, but don't load it because GitHub can't load multi-arch images
  docker buildx build \
    --load \
    --platform=${PLATFORM} \
    -t "${IMAGE_NAME}:build" \
    "${BUILD_VARIANT}" \
    $(printf -- "--build-arg %s " "${BUILD_ARGS[@]}")

echo "::endgroup::"

echo "::group::Running container structure test"
  TESTS_DIR="${ROOT_DIR}/.github/container-structure-tests"
  CST_CONFIGS=("${TESTS_DIR}/${BUILD_VARIANT}.yml")

  if [[ -d "${TESTS_DIR}/${BUILD_VARIANT}" ]]; then
    for FILE in $(ls -r "${TESTS_DIR}/${BUILD_VARIANT}"); do
      APPLIES_TO_VERSION=$(basename "$FILE" | cut -d. -f-2)

      if versionCompare "${PHP_VERSION}" "${APPLIES_TO_VERSION}" ">="; then
        CST_CONFIGS+=("${TESTS_DIR}/${BUILD_VARIANT}/${FILE}")
        break
      fi
    done
  fi

  ${ROOT_DIR}/container-structure-test test --image "${IMAGE_NAME}:build" $(printf -- "--config %s " "${CST_CONFIGS[@]}")
  if [[ $? -ne 0 ]]; then
    echo "::error title=Container Structure Test::Container Structure Test failed"
    exit 2
  fi
echo "::endgroup::"

echo "::group::Generating tags for ${IMAGE_NAME}:${BUILD_VERSION} (${BUILD_VARIANT})"

  # Strip the term 'cli' from tag suffix as this is the default variant
  TAG_SUFFIX="$(echo "${BUILD_VARIANT}" | sed -E 's/^(cli$|cli-)//')"
  [[ ${TAG_SUFFIX} ]] && TAG_SUFFIX="-${TAG_SUFFIX}"

  echo "Evaluating full PHP version: ${FULL_PHP_VERSION}"
  if [[ -z "${FULL_PHP_VERSION}" ]]; then
    echo "::notice title=Full PHP Version Empty::Full PHP version is empty (${FULL_PHP_VERSION}), running container to get full version"
    # Fetch the precise php version from the built image and tag it
    FULL_PHP_VERSION="$(docker run --rm -t --entrypoint php "${IMAGE_NAME}:build" -r 'echo phpversion();')"

    echo "full_php_version=${FULL_PHP_VERSION}" >> $GITHUB_OUTPUT

    mkdir -p "${PHP_VERSIONS_DIR}"
    jq -n --arg major "$MAJOR_VERSION" --arg full "$FULL_PHP_VERSION" '{ ($major): $full }' > "${PHP_VERSIONS_DIR}/${MAJOR_VERSION}-${PLATFORM//\//-}.json"
  else
    echo "::notice title=Full PHP Version Provided::Full PHP Version - ${FULL_PHP_VERSION}"
  fi

  # Generate array of tags for the image being built
  IMAGE_TAGS=(
    "${MAJOR_VERSION}${TAG_SUFFIX}"
    "${FULL_PHP_VERSION}${TAG_SUFFIX}"
  )

echo "::endgroup::"

echo "::group::Pushing layers to registries for ${IMAGE_NAME}:${FULL_PHP_VERSION}${TAG_SUFFIX} (${PLATFORM})"

  # Iterate and push image tags to remote registry
  if [[ ${PUSH_FLAG} != 0 ]]; then
    docker buildx build \
      --push \
      --platform=${PLATFORM} \
      --metadata-file metadata.json \
      --output=type=image,\"name=${REPOSITORY}/${IMAGE_NAME}\",push-by-digest=true,name-canonical=true \
      "${BUILD_VARIANT}" \
      $(printf -- "--build-arg %s " "${BUILD_ARGS[@]}")

    printf "\e[01;31m==> metdata for %s:%s (%s)\033[0m\n" \
      "${IMAGE_NAME}" "${BUILD_VERSION}" "${BUILD_VARIANT}"
    cat metadata.json
    echo -e "\n\e[01;31m==> end metadata output\033[0m\n"

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
    echo "${JSON}" > "${METADATA_DIR}/${BUILD_VERSION}-${BUILD_VARIANT}-${PLATFORM//\//-}.json"

    echo "::notice title=Container image digest for ${IMAGE_NAME}:${FULL_PHP_VERSION}${TAG_SUFFIX} (${PLATFORM##*/})::${digest}"
  fi

echo "::endgroup::"