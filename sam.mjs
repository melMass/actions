import fs from "fs"
import path from "path"
import axios from "axios"
import { dirname } from 'path';
import { nanoid } from 'nanoid';
import { fileURLToPath } from 'url';
import FormData from "form-data";
const __dirname = dirname(fileURLToPath(import.meta.url));
import readJsonLines from 'read-json-lines-sync';
import mime from 'mime-types';
import Blob from 'node-blob';

const ignore =  [".DS_Store", "thumbs.db"]
const infuraURL = 'https://ipfs.infura.io:5001'
const getAllFiles = function(dirPath,{relative=false}={}, arrayOfFiles) {
  let files = fs.readdirSync(dirPath)

  arrayOfFiles = arrayOfFiles || []

  files.forEach(function(file) {
    if (fs.statSync(dirPath + "/" + file).isDirectory()) {
      arrayOfFiles = getAllFiles(dirPath + "/" + file, {relative},arrayOfFiles)
    } else {
      if (ignore.indexOf(file) === -1) {
        if (relative) {
          arrayOfFiles.push(path.join(dirPath, "/", file))
        }
        else{
        arrayOfFiles.push(path.join(__dirname, dirPath, "/", file))
        }
      }
    }
  })

  return arrayOfFiles
}


const files = getAllFiles("./test/sample")
console.log("Creating form")
const form = new FormData()
console.log("Appending files")
  files.forEach(async (file) => {
    const fm = mime.lookup(file) || 'application/octet-stream'
    console.log(`${file} is of type ${fm}`)
    // const blob = .toBlob(fm)
    const blob = fs.createReadStream(file)
    // const blob = new Blob([fs.createReadStream(file)],fm)
    form.append('file', blob, {
      filename: encodeURIComponent(file),
      contentType: fm,
    })
  })

  const endpoint = `${infuraURL}/api/v0/add?pin=true&recursive=true&wrap-with-directory=true`
  const boundary = `-----------------------------${nanoid()}`
  const res = await axios.post(endpoint, form, {
    headers: { 'Content-Type': `multipart/form-data; boundary=${boundary}` },
  })
  const data = readJsonLines(res.data)
  const rootDir = data.find((e) => e.Name === '')

  const directory = rootDir.Hash
console.log(directory)
