# 🏗️ Build Summary

## 📊 Build Statistics

| Metric | Value |
| --- | --- |
| 🕒 Build Duration | ${duration} |
| 📦 Artifacts Size | ${artifactSize} |
| 🔢 Build Number | ${buildNumber} |

## 🔍 Build Details

| Property | Value |
| --- | --- |
| 🔄 Repository | ${repository} |
| 🌿 Branch | ${branch} |
| 🔖 Commit | `${commit}` |
| 📅 Date | ${date} |
| 👤 Author | ${author} |

#if(${hasWarnings})
## ⚠️ Warnings
${warnings}
#endif

#if(${hasErrors})
## ❌ Errors
${errors}
#endif

${buildStatus}
