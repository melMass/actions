# 🧪 Test Results Summary

## 📊 Test Statistics

| Metric | Value |
| --- | --- |
| ✅ Passed | ${passed} |
| ❌ Failed | ${failed} |
| ⏭️ Skipped | ${skipped} |
| ⏱️ Duration | ${duration} |
| 📊 Coverage | ${coverage} |

#if(${failed} > 0)
## ❌ Failed Tests
${failureDetails}
#endif

#if(${hasSkipped})
## ⏭️ Skipped Tests
${skippedDetails}
#endif

#if(${failed} == 0)
## ✅ All tests passed successfully!
#endif
