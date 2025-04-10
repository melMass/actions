const core = require("@actions/core");
const fs = require("fs");
const path = require("path");

// Templates directory
const TEMPLATES_DIR = path.join(__dirname, "templates");

/**
 * Process conditional sections in the content
 * Format: #if(condition) ... #endif
 */
function processConditionalSections(content, variables) {
	// Regex to match conditional sections: #if(condition) ... #endif
	const conditionalRegex = /#if\((.*?)\)([\s\S]*?)#endif/g;

	return content.replace(
		conditionalRegex,
		(match, condition, sectionContent) => {
			try {
				// Replace variables in the condition
				const processedCondition = replaceVariables(condition, variables);

				// Evaluate the condition
				// eslint-disable-next-line no-eval
				const result = eval(processedCondition);

				return result ? sectionContent : "";
			} catch (error) {
				core.warning(
					`Error evaluating condition "${condition}": ${error.message}`,
				);
				return "";
			}
		},
	);
}

/**
 * Replace variables in the content with their values
 * Format: ${variableName}
 */
function replaceVariables(content, variables) {
	if (!variables) return content;

	// Regex to match variables: ${variableName}
	const variableRegex = /\${(.*?)}/g;

	return content.replace(variableRegex, (match, variableName) => {
		const value = variables[variableName.trim()];
		return value !== undefined ? value : match;
	});
}

/**
 * Load a template from the templates directory
 */
function loadTemplate(templateName) {
	const templatePath = path.join(TEMPLATES_DIR, `${templateName}.md`);

	try {
		if (fs.existsSync(templatePath)) {
			return fs.readFileSync(templatePath, "utf8");
		}

		core.warning(`Template "${templateName}" not found.`);
		return null;
	} catch (error) {
		core.warning(`Error loading template "${templateName}": ${error.message}`);
		return null;
	}
}

/**
 * Load a template from a file
 */
function loadTemplateFromFile(filePath) {
	try {
		if (fs.existsSync(filePath)) {
			return fs.readFileSync(filePath, "utf8");
		}

		core.warning(`Template file "${filePath}" not found.`);
		return null;
	} catch (error) {
		core.warning(`Error loading template file "${filePath}": ${error.message}`);
		return null;
	}
}

/**
 * Apply styling to the content based on the style preset
 */
function applyStyle(content, style) {
	// For now, we just return the content as is
	// In the future, we can add styling options
	return content;
}

/**
 * Write content to the GitHub step summary
 */
function writeToSummary(content, append) {
	const summaryPath = process.env.GITHUB_STEP_SUMMARY;

	if (!summaryPath) {
		core.warning(
			"GITHUB_STEP_SUMMARY environment variable not set. Are you running in a GitHub Actions workflow?",
		);
		return;
	}

	try {
		if (append === "true") {
			fs.appendFileSync(summaryPath, content);
		} else {
			fs.writeFileSync(summaryPath, content);
		}

		core.info("Summary created successfully!");
	} catch (error) {
		core.setFailed(`Error writing to summary: ${error.message}`);
	}
}

/**
 * Main function
 */
async function run() {
	try {
		// Get inputs
		const content = core.getInput("content");
		const templateName = core.getInput("template");
		const templateFile = core.getInput("template-file");
		const variablesInput = core.getInput("variables");
		const append = core.getInput("append");
		const style = core.getInput("style") || "default";

		// Parse variables
		let variables = {};
		if (variablesInput) {
			try {
				variables = JSON.parse(variablesInput);
			} catch (error) {
				core.warning(`Error parsing variables: ${error.message}`);
			}
		}

		// Determine the content to use
		let summaryContent = "";

		if (content) {
			// Use the provided content
			summaryContent = content;
		} else if (templateName) {
			// Load a pre-defined template
			const template = loadTemplate(templateName);
			if (template) {
				summaryContent = template;
			} else {
				core.setFailed(`Template "${templateName}" not found.`);
				return;
			}
		} else if (templateFile) {
			// Load a template from a file
			const template = loadTemplateFromFile(templateFile);
			if (template) {
				summaryContent = template;
			} else {
				core.setFailed(`Template file "${templateFile}" not found.`);
				return;
			}
		} else {
			core.setFailed("No content, template, or template file provided.");
			return;
		}

		// Process the content
		let processedContent = summaryContent;

		// Replace variables
		processedContent = replaceVariables(processedContent, variables);

		// Process conditional sections
		processedContent = processConditionalSections(processedContent, variables);

		// Apply styling
		processedContent = applyStyle(processedContent, style);

		// Write to the summary
		writeToSummary(processedContent, append);
	} catch (error) {
		core.setFailed(`Action failed: ${error.message}`);
	}
}

run();
