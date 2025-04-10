# @melmass/summary

A GitHub Action to create beautiful workflow summaries with ease. This action simplifies the process of creating rich, formatted summaries for your GitHub workflows.

## Features

- **Multiline String Support**: Write your summary as a single multiline string instead of multiple echo commands
- **Variable Substitution**: Easily include GitHub context variables and custom inputs in your summaries
- **Conditional Sections**: Include or exclude parts of the summary based on conditions
- **Pre-defined Templates**: Use built-in templates for common summary types (deployment, build, test)
- **Custom Styling**: Choose from different style presets or customize your own

## Usage

```yml
- name: Create workflow summary
  uses: melMass/actions@summary
  with:
    content: |
      # 🚀 Deployment Summary
      
      ## 📦 Build Information
      
      | Property | Value |
      | --- | --- |
      | 🔄 Repository | ${{ github.repository }} |
      | 🌿 Branch | ${{ github.ref_name }} |
      | 🔖 Commit | `${{ github.sha }}` |
      
      ## 🌐 Deployment
      
      | Property | Value |
      | --- | --- |
      | 🔗 URL | ${url} |
      | 🕒 Deployed at | ${timestamp} |
      
      ✅ Deployment completed successfully!
    variables: '{"url": "${{ steps.deployment.outputs.page_url }}", "timestamp": "${{ steps.deployment.outputs.timestamp }}"}'
```

## Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `content` | Markdown content for the summary | No | - |
| `template` | Pre-defined template to use (deployment, build, test) | No | - |
| `template-file` | Path to a custom template file | No | - |
| `variables` | JSON string of variables to substitute in the template | No | - |
| `append` | Append to existing summary instead of creating a new one | No | `false` |
| `conditional-sections` | JSON string of conditions for conditional sections | No | - |
| `style` | Style preset to use (default, minimal, detailed) | No | `default` |

## Examples

### Using a Pre-defined Template

```yml
- name: Create deployment summary
  uses: melMass/actions@summary
  with:
    template: deployment
    variables: '{"url": "${{ steps.deployment.outputs.page_url }}", "commit": "${{ github.sha }}"}'
```

### Using Conditional Sections

```yml
- name: Create test summary
  uses: melMass/actions@summary
  with:
    content: |
      # Test Results
      
      ## Summary
      Tests: ${passed} passed, ${failed} failed
      
      #if(${failed} > 0)
      ## Failed Tests
      ${failureDetails}
      #endif
    variables: '{"passed": "${{ steps.test.outputs.passed }}", "failed": "${{ steps.test.outputs.failed }}", "failureDetails": "${{ steps.test.outputs.details }}"}'
```
