const core = require('@actions/core');
const github = require('@actions/github');

try {
  // `token-id` input defined in action metadata file
  // const token_id = core.getInput('token-id');
  // console.log(`Hello ${token_id}!`);
  const cid = (new Date()).toTimeString();
  core.setOutput("cid", cid);

} catch (error) {
  core.setFailed(error.message);
}
