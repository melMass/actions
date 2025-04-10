const core = require("@actions/core");
const github = require("@actions/github");

async function run() {
  try {
    const token = core.getInput("repo-token", { required: true });
    const upstreamBranch = core.getInput("upstream-branch", { required: true });
    const targetBranch = core.getInput("feature-branch", { required: true });
    const upstreamRepo = core.getInput("upstream-repo");
    let baseBranch = core.getInput("base-branch");

    const octokit = github.getOctokit(token);
    const { owner, repo } = github.context.repo;
    
    const isBranchPR = upstreamRepo || baseBranch;
    
    if (!baseBranch) {
      if (isBranchPR) {
        try {
          const { data: repoData } = await octokit.rest.repos.get({
            owner,
            repo
          });
          baseBranch = repoData.default_branch;
          console.log(`Using default branch: ${baseBranch}`);
        } catch (error) {
          baseBranch = "main"; 
          console.log(`Could not determine default branch, using: ${baseBranch}`);
        }
      } else {
        baseBranch = targetBranch;
      }
    }
    
    // Check for existing PRs
    const { data: pullRequests } = await octokit.rest.pulls.list({
      owner,
      repo,
      state: "open",
      head: isBranchPR ? `${owner}:${targetBranch}` : `${owner}:${targetBranch}`,
      base: baseBranch
    });

    let existingPR = pullRequests.find(pr => 
      pr.head.ref === targetBranch && pr.base.ref === baseBranch
    );

    // Handle different sync modes
    if (upstreamRepo) {
      // Sync with specified upstream repo
      const [upstreamOwner, upstreamRepoName] = upstreamRepo.split('/');
      
      console.log(`Syncing with specified upstream repo: ${upstreamRepo}`);
      
      // Fetch from upstream
      await octokit.rest.git.updateRef({
        owner,
        repo,
        ref: `heads/${targetBranch}`,
        sha: upstreamBranch,
        force: true
      }).catch(async error => {
        console.log(`Direct update failed: ${error.message}. Trying alternative approach...`);
        
        // Alternative approach: create a temporary reference
        const tempRef = `refs/heads/temp-sync-${Date.now()}`;
        await octokit.rest.git.createRef({
          owner,
          repo,
          ref: tempRef,
          sha: upstreamBranch
        });
        
        // Update target branch to point to the temporary reference
        await octokit.rest.git.updateRef({
          owner,
          repo,
          ref: `heads/${targetBranch}`,
          sha: tempRef.replace('refs/', ''),
          force: true
        });
        
        // Delete temporary reference
        await octokit.rest.git.deleteRef({
          owner,
          repo,
          ref: tempRef
        });
      });
      
      console.log(`Synced ${targetBranch} with ${upstreamRepo}:${upstreamBranch}`);
    } else {
      // Standard fork sync using GitHub's mergeUpstream API
      const { data: mergeResult } = await octokit.rest.repos.mergeUpstream({
        owner,
        repo,
        branch: targetBranch,
      });
      console.log(
        `Merged upstream changes into ${targetBranch}: ${mergeResult.message}`,
      );
    }
    
    // Handle PR creation or updates
    if (existingPR) {
      console.log(`Found existing PR: ${existingPR.number}`);

      await octokit.rest.issues.createComment({
        owner,
        repo,
        issue_number: existingPR.number,
        body: upstreamRepo 
          ? `Updated with the latest changes from ${upstreamRepo}:${upstreamBranch}.`
          : `Updated with the latest changes from the upstream branch ${upstreamBranch}.`,
      });
    } else if (isBranchPR || targetBranch !== baseBranch) {
      // Only create a PR if it's a branch PR or the target and base are different
      const { data: newPR } = await octokit.rest.pulls.create({
        owner,
        repo,
        title: upstreamRepo
          ? `Sync ${targetBranch} with ${upstreamRepo}:${upstreamBranch}`
          : `Sync ${targetBranch} with ${upstreamBranch}`,
        head: targetBranch,
        base: baseBranch,
        body: upstreamRepo
          ? `Automated pull request to keep ${targetBranch} up to date with ${upstreamRepo}:${upstreamBranch}.`
          : `Automated pull request to keep ${targetBranch} up to date with ${upstreamBranch}.`,
        maintainer_can_modify: true,
      });
      console.log(`Created new PR: ${newPR.number}`);
    }
  } catch (error) {
    core.setFailed(`Failed to execute action: ${error.message}`);
  }
}

run();
