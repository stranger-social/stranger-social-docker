# Managing This Repo with GitHub MCP

This repository is compatible with the GitHub Model Context Protocol (MCP) so you can manage issues, PRs, files, and reviews from an MCP-enabled client.

## 1) Make the GitHub repo private

When creating the repo on GitHub, choose “Private”. You can change this later in Settings > General > Danger Zone.

## 2) Enable the Wiki

- Go to Settings > General > Features
- Check “Wikis”
- Our GitHub Action will sync `docs/` to the Wiki automatically

## 3) Generate a Personal Access Token (PAT)

Create a fine-grained PAT with the following scopes for your user (used by your MCP client):

- repo (all) for your private repos
- workflow (to let MCP trigger and read Actions if needed)

Store this token securely on your local machine (Keychain, 1Password, pass, etc.).

## 4) Configure your MCP client

Example configuration for the GitHub MCP server in clients like Claude Desktop (adjust to your environment):

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "<your_pat_here>",
        "GITHUB_REPOSITORY": "<owner>/<repo>",
        "GITHUB_BASE_URL": "https://api.github.com"
      }
    }
  }
}
```

Notes:
- `GITHUB_REPOSITORY` must be `owner/repo`
- For GitHub Enterprise, set `GITHUB_BASE_URL` to your enterprise API root

## 5) Common MCP tasks

- Create issues: “Create a bug issue titled …”
- Open PRs: “Open a PR with changes in branch …”
- Review PRs: “Review PR #123 and summarize requested changes”
- Run Actions: “Dispatch the sync wiki workflow”

## 6) Secrets and safety

- `.env` is ignored via `.gitignore` (never commit real secrets)
- Use `.env.example` as a template
- Keep PATs in your local MCP client, not in the repo
