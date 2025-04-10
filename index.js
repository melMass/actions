const core = require("@actions/core");
const github = require("@actions/github");

async function run() {
  try {
    const token = core.getInput("repo-token", { required: true });
    const upstreamBranch = core.getInput("upstream-branch", { required: true });
    const targetBranch = core.getInput("feature-branch", { required: true });

    const octokit = github.getOctokit(token);
    const { owner, repo } = github.context.repo;

    const { data: pullRequests } = await octokit.rest.pulls.list({
      owner,
      repo,
      state: "open",
      head: `${owner}:${targetBranch}`,
    });

    let existingPR = pullRequests.find((pr) => pr.head.ref === targetBranch);

    const { data: mergeResult } = await octokit.rest.repos.mergeUpstream({
      owner,
      repo,
      branch: targetBranch,
    });
    console.log(
      `Merged upstream changes into ${targetBranch}: ${mergeResult.message}`,
    );
    if (existingPR) {
      console.log(`Found existing PR: ${existingPR.number}`);

      await octokit.rest.issues.createComment({
        owner,
        repo,
        issue_number: existingPR.number,
        body: `Updated with the latest changes from the upstream branch ${upstreamBranch}.`,
      });
    } else {
      const { data: newPR } = await octokit.rest.pulls.create({
        owner,
        repo,
        title: `Sync ${targetBranch} with ${upstreamBranch}`,
        head: targetBranch,
        base: targetBranch,
        body: `Automated pull request to keep ${targetBranch} up to date with ${upstreamBranch}.`,
        maintainer_can_modify: true,
      });
      console.log(`Created new PR: ${newPR.number}`);
    }
  } catch (error) {
    core.setFailed(`Failed to execute action: ${error.message}`);
  }
}

run();
