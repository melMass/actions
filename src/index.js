const core = require('@actions/core');
const github = require('@actions/github');
// const { create } = require('ipfs-http-client');
const fs = require("fs")
const path = require("path")

const infuraURL = 'https://ipfs.infura.io:5001'

const ignore = [".DS_Store", "thumbs.db"]

const getAllFiles = function(dirPath, arrayOfFiles) {
  files = fs.readdirSync(dirPath)

  arrayOfFiles = arrayOfFiles || []

  files.forEach(function(file) {
    if (fs.statSync(dirPath + "/" + file).isDirectory()) {
      arrayOfFiles = getAllFiles(dirPath + "/" + file, arrayOfFiles)
    } else {
      if (ignore.indexOf(file) === -1) {
        arrayOfFiles.push(path.join(__dirname, dirPath, "/", file))
      }
    }
  })

  return arrayOfFiles
}

const uploadDirectory = async (directory, ipfs) => {
  const files = getAllFiles(directory)
  const form = new FormData()

  files.forEach((file) => {
    form.append('file', file.blob, encodeURIComponent(file.path))
  })

  const endpoint = `${infuraUrl}/api/v0/add?pin=true&recursive=true&wrap-with-directory=true`
  const res = await axios.post(endpoint, form, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  const data = readJsonLines(res.data)
  const rootDir = data.find((e) => e.Name === '')

  const directory = rootDir.Hash
  return directory
}

try {
  // `token-id` input defined in action metadata file
  // const token_id = core.getInput('token-id');
  // console.log(`Hello ${token_id}!`);
  const input_folder = core.getInput('path');

  if (fs.existsSync(input_folder)) {
    // const ipfs = create('https://ipfs.infura.io:5001')
    const cid = await uploadDirectory(input_folder)
    core.setOutput("cid", cid);
  }

  else{
    core.setFailed(`${input_folder} does not exist`);
  }

} catch (error) {
  core.setFailed(error.message);
}
