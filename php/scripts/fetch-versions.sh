#!/usr/bin/env bash

MIN_VERS=$(echo $MINIMUM_VERSION | sed -E 's/([0-9]+\.[0-9]+)(\..*)?/\1/')
STATES=$(curl -o- "https://www.php.net/releases/states?json" 2>/dev/null)
ALL_VERSIONS=$(echo "$STATES" | jq --arg minVers "$MIN_VERS" '[ .[] | to_entries[] | .key as $version | select(.key >= $minVers) | { "version": $version, "state": .value.state } ]')

ACTIVE_VERSIONS='{"major": [], "minor": []}'
LEGACY_VERSIONS='{"major": [], "minor": []}'

for RELEASE in $(echo "$ALL_VERSIONS" | jq -c '.[]'); do
  STATE=$(echo "$RELEASE" | jq -r '.state')
  MAJOR_VERSION=$(echo "$RELEASE" | jq -r '.version')
  MINOR_VERSION=$(curl -o- "https://www.php.net/releases/?json&version=${MAJOR_VERSION}" 2>/dev/null | jq -r '.version')

  if [[ "$STATE" = "eol" ]]; then
    LEGACY_VERSIONS=$(echo "$LEGACY_VERSIONS" | jq -c --arg newVers $MAJOR_VERSION '.major[ .major | length ] |= .major + $newVers | .major |= sort')
    LEGACY_VERSIONS=$(echo "$LEGACY_VERSIONS" | jq -c --arg newVers $MINOR_VERSION '.minor[ .minor | length ] |= .minor + $newVers | .minor |= sort')
  else
    ACTIVE_VERSIONS=$(echo "$ACTIVE_VERSIONS" | jq -c --arg newVers $MAJOR_VERSION '.major[ .major | length ] |= .major + $newVers | .major |= sort')
    ACTIVE_VERSIONS=$(echo "$ACTIVE_VERSIONS" | jq -c --arg newVers $MINOR_VERSION '.minor[ .minor | length ] |= .minor + $newVers | .minor |= sort')
  fi
done

echo "active_versions=$(echo $ACTIVE_VERSIONS | jq -c '.major + .minor | sort')" >> $GITHUB_OUTPUT
echo "active_major_versions=$(echo $ACTIVE_VERSIONS | jq -c '.major')" >> $GITHUB_OUTPUT
echo "active_minor_versions=$(echo $ACTIVE_VERSIONS | jq -c '.minor')" >> $GITHUB_OUTPUT

echo "legacy_versions=$(echo $LEGACY_VERSIONS | jq -c '.major + .minor | sort')" >> $GITHUB_OUTPUT
echo "legacy_major_versions=$(echo $LEGACY_VERSIONS | jq -c '.major')" >> $GITHUB_OUTPUT
echo "legacy_minor_versions=$(echo $LEGACY_VERSIONS | jq -c '.minor')" >> $GITHUB_OUTPUT

echo "::notice title=Active PHP Versions Identified::$(echo $ACTIVE_VERSIONS | jq -c '.major + .minor | sort')"
echo "::notice title=Legacy PHP Versions Identified::$(echo $LEGACY_VERSIONS | jq -c '.major + .minor | sort')"
