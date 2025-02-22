import * as core from '@actions/core';
import fs from 'node:fs/promises';
import {Exec} from '@docker/actions-toolkit/lib/exec';
import { Toolkit } from '@docker/actions-toolkit/lib/toolkit';
import { ImageTools } from '@docker/actions-toolkit/lib/buildx/imagetools';
import { Util } from '@docker/actions-toolkit/lib/util';

export async function run() {
    const toolkit = new Toolkit();
    if (!(await toolkit.buildx.isAvailable())) {
        core.setFailed(`Docker buildx is required. See https://github.com/docker/setup-buildx-action to set up buildx.`);
        return;
    }

    // await core.group(`Buildx version`, async () => {
    //     await toolkit.buildx.printVersion();
    // });

    // await core.group(`Builder info`, async () => {
    //     builder = await toolkit.builder.inspect();
    //     core.info(JSON.stringify(builder, null, 2));
    // });

    const inputs = await getInputs();
    const args = ['create'];
    let imageName;
    const digests = [];
    const tags = [];

    const files = await fs.readdir(inputs.metadataPath);
    for (const file of files) {
        if (file.endsWith('.json')) {
            const contents = await fs.readFile(`${inputs.metadataPath}/${file}`);
            const json = JSON.parse(contents);

            if (!imageName || imageName === "") {
                imageName = json.image;
            }

            if (json.tags && json.tags.length > 0) {
                tags.push(...json.tags);
            }

            if (json.digests && json.digests.length > 0) {
                digests.push(...json.digests);
            }
        }
    }

    // Add any additional tags passed via input
    if (inputs.tags.length > 0) {
        await Util.asyncForEach(inputs.tags, async (tag) => {
            tags.push(tag);
        });
    }

    await Util.asyncForEach(inputs.annotations, async (annotation) => {
        args.push('--annotation', annotation);
    });

    await Util.asyncForEach(tags, async (tag) => {
        args.push('--tag', tag);
    });

    await Util.asyncForEach(digests, async (digest) => {
        args.push(`${inputs.repository}/${imageName}@${digest}`);
    });

    const imagetools = new ImageTools();
    const toolCmd = await imagetools.getCommand(args);

    core.info(`toolCmd.command: ${toolCmd.command}`);
    core.info(`toolCmd.args: ${JSON.stringify(toolCmd.args)}`);

    let err;
    await Exec.getExecOutput(toolCmd.command, toolCmd.args, {
            ignoreReturnCode: true,
            env: Object.assign({}, process.env, {
                BUILDX_METADATA_WARNINGS: 'true'
              })
        }).then((res) => {
            if (res.exitCode != 0) {
                err = Error(`buildx failed with: ${res.stderr.match(/(.*)\s*$/)?.[0]?.trim() ?? 'unknown error'}`);
            }
        });

    if (err) {
        throw err;
    }

}

async function getInputs() {
    return {
        annotations: Util.getInputList('annotations'),
        imageName: core.getInput('image-name'),
        metadataPath: core.getInput('metadata-path'),
        repository: core.getInput('repository'),
        tags: Util.getInputList('tags'),
    };
}