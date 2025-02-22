#!/usr/bin/env bash
set -e
trap 'error "$(printf "Command \`%s\` at $BASH_SOURCE:$LINENO failed with exit code $?" "$BASH_COMMAND")"' ERR

function error {
  >&2 printf "\033[31mERROR\033[0m: %s\n" "$@"
}

## find directory above where this script is located following symlinks if neccessary
readonly BASE_DIR="$(
  cd "$(
    dirname "$(
      (readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}") \
        | sed -e "s#^../#$(dirname "$(dirname "${BASH_SOURCE[0]}")")/#"
    )"
  )/.." >/dev/null \
  && pwd
)"
pushd "${BASE_DIR}" >/dev/null

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
  BUILD_ARGS=(IMAGE_NAME PHP_VERSION)

docker buildx use warden-builder >/dev/null 2>&1 || docker buildx create --name warden-builder --use

echo "::group::building ${IMAGE_NAME}:${BUILD_VERSION} (${BUILD_VARIANT})"
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

echo "::group::Generating tags for ${IMAGE_NAME}:${BUILD_VERSION} (${BUILD_VARIANT})"
  # Strip the term 'cli' from tag suffix as this is the default variant
  TAG_SUFFIX="$(echo "${BUILD_VARIANT}" | sed -E 's/^(cli$|cli-)//')"
  [[ ${TAG_SUFFIX} ]] && TAG_SUFFIX="-${TAG_SUFFIX}"

  # Fetch the precise php version from the built image and tag it
  MINOR_VERSION="$(docker run --rm -t --entrypoint php "${IMAGE_NAME}:build" -r 'echo phpversion();')"

  # Generate array of tags for the image being built
  IMAGE_TAGS=(
    "${IMAGE_NAME}:${MAJOR_VERSION}${TAG_SUFFIX}"
    "${IMAGE_NAME}:${MINOR_VERSION}${TAG_SUFFIX}"
  )

echo "::endgroup::"

echo "::group::Pushing layers to registries for ${IMAGE_NAME}:${MINOR_VERSION}${TAG_SUFFIX} (${PLATFORM})"

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

    echo "::notice title=Container image digest for ${IMAGE_NAME}:${MINOR_VERSION}${TAG_SUFFIX} (${PLATFORM##*/})::${digest}"
  fi

echo "::endgroup::"