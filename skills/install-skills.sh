#!/bin/bash
# Install all curated skills for the Kimi Squad
set -e

echo "🚀 Installing Kimi Squad Skills..."

SKILLS=(
  "addyosmani/web-quality-skills@best-practices"
  "skillcreatorai/ai-agent-skills@backend-development"
  "manutej/luxor-claude-marketplace@nodejs-development"
  "pluginagentmarketplace/custom-plugin-nodejs@express-rest-api"
  "b-open-io/prompts@frontend-performance"
  "daffy0208/ai-dev-standards@accessibility-engineer"
  "vercel-labs/json-render@react"
  "cowork-os/cowork-os@code-review"
  "openhands/skills@security"
  "travisjneuman/.claude@database-expert"
  "1mangesh1/dev-skills-collection@docker-helper"
  "thebushidocollective/han@playwright-page-object-model"
  "softaworks/agent-toolkit@openapi-to-typescript"
)

for skill in "${SKILLS[@]}"; do
  echo "Installing: $skill"
  npx skills add "$skill" -g -y || echo "⚠️  Failed to install: $skill"
done

echo ""
echo "✅ Skill installation complete!"
echo "Installed skills:"
ls ~/.agents/skills/ | wc -l
echo "total skills"
