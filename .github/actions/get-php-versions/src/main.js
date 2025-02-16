import * as core from '@actions/core';
import * as semver from 'semver';

export async function run() {
    const data = {
        "eol": {
            "major": [],
            "minor": []
        },
        "security": {
            "major": [],
            "minor": []
        },
        "stable": {
            "major": [],
            "minor": []
        }
    };

    const phpStates = await getPHPStates();
    const absoluteMinimumVersion = '7.4';
    const versionConstraint = core.getInput('version-constraint');

    for (const [majorVer, majorReleases] of Object.entries(phpStates)) {
        for (const [minorVer, state] of Object.entries(majorReleases)) {
            if (!semver.gte(semver.coerce(minorVer), semver.coerce(absoluteMinimumVersion))) {
                console.error(`Skipping ${minorVer} as it is below the minimum version ${absoluteMinimumVersion}`);
                continue;
            }

            if (
                !versionConstraint
                || semver.satisfies(semver.coerce(minorVer), versionConstraint)
            ) {
                data[state.state].major.push(minorVer);

                const release = await getPHPRelease(minorVer);
                data[state.state].minor.push(release.version);
            }
        }
    }

    for (const [state, details] of Object.entries(data)) {
        core.setOutput(`php_${state}_versions`, JSON.stringify(details));
    }
}

async function getPHPStates() {
    const response = await fetch('https://www.php.net/releases/states?json');
    const phpStates = await response.json();

    // await core.group('Found PHP States', () => {
    //     core.info(JSON.stringify(phpStates, null, 2));
    // });

    return phpStates;
}

async function getPHPRelease(version) {
    const response = await fetch(`https://www.php.net/releases/?json&version=${version}`);
    const phpVersions = await response.json();

    // await core.group('Found PHP Versions', () => {
    //     core.info(JSON.stringify(phpVersions, null, 2));
    // });

    return phpVersions;
}
