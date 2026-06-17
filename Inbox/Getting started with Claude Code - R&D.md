---
title: "Getting started with Claude Code - R&D"
source: "https://gongio.atlassian.net/wiki/spaces/EN/pages/4067852299/Getting+started+with+Claude+Code"
author:
published:
created: 2026-06-17
description:
tags:
  - "clippings"
---
## Getting started with Claude Code

## Claude Code: A Developer Guide for Gong Engineers

## Introduction

Claude Code is an AI-powered developer assistant that helps you understand, navigate, and modify codebases directly from your terminal. At Gong, we use a custom wrapper that configures Claude Code with our organization's settings and integrations.

With Claude Code, you can:

- Navigate and search through large codebases
- Understand complex code functionality
- Generate code for new features
- Fix bugs and refactor existing code
- Automate repetitive tasks
- Run Git operations
- Access Intellij files

## Additional Read Resources

***It’s highly recommended to read these before starting to use Claude Code***

- [Official Claude Code Course](https://anthropic.skilljar.com/claude-code-in-action "https://anthropic.skilljar.com/claude-code-in-action") - ***Highly recommended!! (1 hour long)***
	- You’ll need to create your own account with the [gong.io](http://gong.io/ "http://gong.io") email address
- [====Official Claude Code Documentation====](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview "https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview")
- [====Claude Prompt Engineering Guide====](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview "https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview")
- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices "https://www.anthropic.com/engineering/claude-code-best-practices")

## Installation and Setup (UPDATE: if you used Ansible to set up new env after 27.10.25 you should have the parts marked with \* configured)

### Prerequisites \*

- Leapp with **R&D AI Tools (AI4DevUserAccess)** and **Shared-Services** profiles activated
	- if you don’t see these profiles
		- press the “sync” button, on the right of the “Search Session” bar.
				- edit “R&D AI Tools (AI4DevUserAccess)” to have “rnd-ai-tools” profile name  
			Open image-20250512-061125.png ![image-20250512-061125.png](https://media-cdn.atlassian.com/file/d65fc12f-a34b-460a-8cc4-6fcee88a71df/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-4067852299&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC00MDY3ODUyMjk5IjpbInJlYWQiXX0sImV4cCI6MTc4MTY5MTkwNSwibmJmIjoxNzgxNjg5MDI1LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.Jnmwj9XQjzxmVNJMfCIJGQcjuL7-DXZY7Of_f4wUOjc&width=688#media-blob-url=true&id=d65fc12f-a34b-460a-8cc4-6fcee88a71df&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-4067852299&collection=contentId-4067852299)
				- ed ==it “Shared Ser== vices” to have “shared-services” profile name  
			Open image-20250512-061202.png ![image-20250512-061202.png](https://media-cdn.atlassian.com/file/05ad4f4b-c6db-4aca-b5f7-2731a3129cc7/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-4067852299&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC00MDY3ODUyMjk5IjpbInJlYWQiXX0sImV4cCI6MTc4MTY5MTkwNSwibmJmIjoxNzgxNjg5MDI1LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.Jnmwj9XQjzxmVNJMfCIJGQcjuL7-DXZY7Of_f4wUOjc&width=688#media-blob-url=true&id=05ad4f4b-c6db-4aca-b5f7-2731a3129cc7&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-4067852299&collection=contentId-4067852299)
- Git access to the `gong-build-commons` repository (IMPORTANT: make sure you are on `main` and then `git pull` to get latest)
- Github cli (`==gh==`) with authorized token (for using Github MCP) (`brew install gh` if ==not installed==)

### Installation Steps \*

Run `~/develop/code/gong-build-commons/dev/gong-claude-runner/gong-claude-runner.sh` in the terminal

**What it does:**

We package Claude Code in our custom Docker image (hosted in 'shared-services' account ECR). Our `gong-claude-runner.sh` wrapper:

- Installs approved MCPs (JetBrains, GitHub)
- Mounts AWS credentials and Maven repositories
- Creates persistent storage for history and configurations
- Optimizes the environment for Gong developers

The wrapper is located in the `gong-build-commons` repo under `dev/gong-claude-runner/gong-claude-runner.sh`

### Gong Claude Runner Through Terminal

In order to access Gong Claude Runner through terminal, please run:

```
gcr
```

For usage information please run,

```
gcr --help
```

### Intellij (Jetbrains) MCP configuration

In order to use the the intellij MCP client, we need to

1. Install MCP server plugin [MCP Server - IntelliJ IDEs Plugin | Marketplace](https://plugins.jetbrains.com/plugin/26071-mcp-server) **\***  
	Open image-20250422-092130.png ![image-20250422-092130.png](https://media-cdn.atlassian.com/file/3ebcbff5-da85-41da-b392-aead845540ab/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-4067852299&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC00MDY3ODUyMjk5IjpbInJlYWQiXX0sImV4cCI6MTc4MTY5MTkwNSwibmJmIjoxNzgxNjg5MDI1LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.Jnmwj9XQjzxmVNJMfCIJGQcjuL7-DXZY7Of_f4wUOjc&width=736#media-blob-url=true&id=3ebcbff5-da85-41da-b392-aead845540ab&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-4067852299&collection=contentId-4067852299)

If you do not see MCP server in the options please update your IntelliJ installation to the latest version.

2. Configure intellij debug port to listen globally.
- Go to ***Intel ==lij → Settings → Tools ->==*** **Web Browsers and Preview**  
	older versions ***Intel ==lij → Settings → Build, Execution, Deployment → Debugger==***
- ==Configure== ***==built-in server==*** ==to listen on port== **63340** and have both “ **Can accept external connetions” & “Allow unsigned request”** checked as in the screenshot below
- Open image-20250831-100746.png ![image-20250831-100746.png](https://media-cdn.atlassian.com/file/d8275bc7-b062-405d-9f8a-35f9fc063959/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-4067852299&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC00MDY3ODUyMjk5IjpbInJlYWQiXX0sImV4cCI6MTc4MTY5MTkwNSwibmJmIjoxNzgxNjg5MDI1LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.Jnmwj9XQjzxmVNJMfCIJGQcjuL7-DXZY7Of_f4wUOjc&width=760#media-blob-url=true&id=d8275bc7-b062-405d-9f8a-35f9fc063959&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-4067852299&collection=contentId-4067852299)
	in older versions  
	Open image-20250422-092428.png ![image-20250422-092428.png](https://media-cdn.atlassian.com/file/2ea688c0-cded-41bc-bab1-6787d3bc3069/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-4067852299&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC00MDY3ODUyMjk5IjpbInJlYWQiXX0sImV4cCI6MTc4MTY5MTkwNSwibmJmIjoxNzgxNjg5MDI1LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.Jnmwj9XQjzxmVNJMfCIJGQcjuL7-DXZY7Of_f4wUOjc&width=736#media-blob-url=true&id=2ea688c0-cded-41bc-bab1-6787d3bc3069&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-4067852299&collection=contentId-4067852299)

### Intellij (Jetbrains) Claude Code plugin (Still in beta)

[Use Claude Code in VS Code - Claude Code Docs](https://docs.anthropic.com/en/docs/claude-code/ide-integrations)

The [Claude Code jetbrains plugin](https://plugins.jetbrains.com/plugin/27310-claude-code-beta- "https://plugins.jetbrains.com/plugin/27310-claude-code-beta-") (still in beta) makes the integration a bit smoother. It allows to easily reference files, detected selected lines and present the **diff directly in the IDE “diff view”.**

Open image-20250619-082324.png

#### Installation & Configuration

Install the plugin from the Jetbrains market place \*

Open image-20250619-075646.png

**Set the plugin settings as follow:**

1. Go to ***Intel ==lij → Settings → Tools → Claude Code \[Beta\]==***
2. Check all the checkbox.
3. In General section, change “Claude command” to be: **gcr --ide-integration**

Open image-20250619-075612.png

### Usage

==When running GCR -== **==it won’t be automatiicaly connected to intellij==**

On each session, you’ll need to trigger the `/ide` slash command and choose your IDE instance.

If multiple IDEs are open you’ll see the PID next to it (have a feature request to Anthropic to have better description there)

Open image-20250619-080104.png

Once connected, you should see it detects the current open file or lines selected.  

Open image-20250619-081616.png

Open image-20250619-081639.png

You can also “send to Claude Code” with right click or a keyboard shortcut.  

Open image-20250619-081718.png

This will result in a reference in the Claude Code prompt such as  

Open image-20250619-081757.png

So you can reference multiple lines, from different files, etc.

### Atlassian MCP

Atlassian access through MCP server is available using a remote MCP and oauth authentication method. In order to support it - **make sure you’ve enabled “host networking” feature in Docker Desktop** - this is because the MCP server authentication callback expects the client to be in “localhost”.

From there - after starting `gcr` you can use the `/mcp` command in order to select the `atlassian` MCP server - and follow the on-screen instructions in order to authenticate.

### Figma MCP

To enable Figma’s local MCP server please follow the [Step 1: Enable the MCP Server](https://help.figma.com/hc/en-us/articles/32132100833559-Guide-to-the-Dev-Mode-MCP-Server#h_01JVAXW87T435SJDASMZB59AFG "https://help.figma.com/hc/en-us/articles/32132100833559-Guide-to-the-Dev-Mode-MCP-Server#h_01JVAXW87T435SJDASMZB59AFG") section in Figma’s official guide.

- **Make sure you’ve enabled “host networking” feature in Docker Desktop**

### GH Cli configuration

- Open terminal and make sure that `gh auth token` command returns your personal token.
- If it does not, please run `gh auth login` and follow the instructions on screen
- Run `gh auth setup-git`

### Basic Usage

First time setup:

```shell
cd ~/develop/code/<subsystem>

~/develop/code/gong-build-commons/dev/gong-claude-runner/gong-claude-runner.sh
```

After the first run, the script will create a symlink making it available from your PATH:

```shell
gong-claude-runner.sh
```

==In this stage, you should see the Claude Code prompt==  

Open image-20250527-102552.png

Please read the Claude Code how-to docs in order to get familiar with the common keyboard shortcuts and actions. [CLI reference - Claude Code Docs](https://docs.anthropic.com/en/docs/claude-code/cli-usage#special-shortcuts)

## Troubleshoot GCR issues

<table><colgroup><col> <col> <col></colgroup><tbody><tr><th rowspan="1" colspan="1"><div><p><strong>Symptom</strong></p><figure></figure></div></th><th rowspan="1" colspan="1"><div><p><strong>Notes</strong></p><figure></figure></div></th><th rowspan="1" colspan="1"><div><p><strong>Fix</strong></p><figure></figure></div></th></tr></tbody></table>

<table><colgroup><col> <col> <col></colgroup><tbody><tr><th rowspan="1" colspan="1"><div><p><strong>Symptom</strong></p><figure></figure></div></th><th rowspan="1" colspan="1"><div><p><strong>Notes</strong></p><figure></figure></div></th><th rowspan="1" colspan="1"><div><p><strong>Fix</strong></p><figure></figure></div></th></tr><tr><td rowspan="1" colspan="1"><p>Docker check is stuck / MCP setup is not working</p></td><td rowspan="1" colspan="1"><p>In most cases, this is Docker Daemon not responding</p></td><td rowspan="1" colspan="1"><p>Kill all GCR containers and restart Docker processes by running</p><p></p><pre><code>gcr --repair</code></pre><p></p></td></tr><tr><td rowspan="1" colspan="1"><p><span></span></p><pre><code>API Error (403 {"Message":"User: arn:aws:sts::619674557058:assumed-role/AWSReservedSSO_AI4DevUserAccess_8d0a03f0e739791c/elad.swisa@gong.io is not authorized to perform: bedrock:InvokeModel on resource: arn:aws:bedrock:us-east-1:619674557058:inference-profile/us.anthropic.claude-3-7-sonnet-20250219-v1:0 because no VPC endpoint policy allows the bedrock:InvokeModel action"})</code></pre><p></p></td><td rowspan="1" colspan="1"><p>This is due to skipping the VPN configuration section (removing <code>amazonaws.com</code> and adding <code>elb.amazonaws.com</code> & <code>eks.amazonaws.com</code> from domains list or not restarting the VPN connection)</p></td><td rowspan="1" colspan="1"><p>Make sure to follow instructions above and restart the VPN connection</p></td></tr><tr><td rowspan="1" colspan="1"><p>Intellij terminal does not recognize the <code>gcr</code> command</p></td><td rowspan="1" colspan="1"><p>Intellij sometimes set with default shell command of <code>/bin/zsh -i</code></p></td><td rowspan="1" colspan="1"><p>Change the default command to plain <code>/bin/zsh</code></p></td></tr><tr><td rowspan="1" colspan="1"><p>API Error (403 The security token included in the request is expired) · Retrying in 5 seconds… (attempt 4/10)</p></td><td rowspan="1" colspan="1"><p>If you are using a custom script to login into aws sso instead of Leapp. aws sso command uses ~/.aws/cache instead of ~/.aws/credentials</p></td><td rowspan="1" colspan="1"><p>Make sure the correct file has credentials to login as this file is the one bound to the container.</p></td></tr><tr><td rowspan="1" colspan="1"><p>During gcr execution, a popup message is shown requesting to enter the “login” keychain password.</p></td><td rowspan="1" colspan="1"><p>Open image-20251029-150101.png</p></td><td rowspan="1" colspan="1"><ol><li><p>exit gcr execution and run:<br>> <code>gh auth login</code></p></li><li><p>re-run gcr</p></li></ol></td></tr><tr><td rowspan="1" colspan="1"><p>During git commit (mainly at gong-research) cc tries to use credential-osxkeychain</p></td><td rowspan="1" colspan="1"><p>Open image-20251105-092111.png</p></td><td rowspan="1" colspan="1"><ol><li><p>exit gcr</p></li><li><p>run <code>gh auth setup-git</code></p><ol><li><p>re-run gcr</p></li></ol></li></ol></td></tr><tr><td rowspan="1" colspan="1"><p>Claude cannot access some local directories and suggests to clone repos you already cloned, for example <code>~develop/code/gong-email-digestion</code></p></td><td rowspan="1" colspan="1"><p>Claude's explanation and recommendation:</p><p><span></span></p><pre><code>Your Docker container (GCR - Gong Claude Runner) has specific volume mount configuration:

  volumes:

    - /Users/<your-username>/develop/code/gong-build-commons:/Users/<your-username>/develop/code/gong-build-commons

    - /Users/<your-username>/develop/code/gong-clients:/Users/<your-username>/develop/code/gong-clients

    - /Users/<your-username>/develop/code/honeyfy:/Users/<your-username>/develop/code/honeyfy

    - /develop/code/gong-ai4dev:/develop/code/gong-ai4dev

    # gong-email-digestion NOT mounted!

  Solution

  To access gong-email-digestion locally, you would need to:

  1. Update your GCR Docker configuration to mount that directory

  2. Restart the container

  That's why we used GitHub MCP tools instead - to work around the mounting limitation.</code></pre><p></p></td><td rowspan="1" colspan="1"><p>'s explanation and recommended fix:</p><p>For security reasons GCR has access to the mounted volumes only, to give it access to your directory run GCR from it, for example:</p><p></p><pre><code>cd ~/develop/code/gong-email-digestion

gcr</code></pre><p></p><p>GCR will ask to confirm access to this dir:</p><p><span></span></p><pre><code>Accessing workspace:

/Users/<your-username>/develop/code/gong-email-digestion

Quick safety check: Is this a project you created or one you trust? (Like your own code, a well-known open source project, or work from

your team). If not, take a moment to review what's in this folder first.

Claude Code'll be able to read, edit, and execute files here.</code></pre><p></p><p>Alternatively, add more volumes via GCR <code>--mount-dirs</code> start parameter:</p><p><span></span></p><pre><code>--mount-dirs=VALUE             List of directories to mount (comma/space sep)</code></pre><p></p></td></tr></tbody></table>

## 📚 Documentation & Guides

**All development guidance is maintained in our** [**gong-ai4dev**](https://github.com/Honeyfy/gong-ai4dev "https://github.com/Honeyfy/gong-ai4dev") **repository:**

### 🏗️ Architecture & Development Patterns

- **Technology-specific guides**: Java/Spring Boot, React/TypeScript, DevOps/Infrastructure
- **Implementation patterns**: Database, messaging, caching, security, testing
- **Repository structure**: Maven dependencies, package organization, placement decisions

### 🤖 AI Subagent System

Claude Code automatically routes questions to specialized experts:

- **pattern-guide** - Database, messaging, security implementations
- **java-architect** - Repository placement, Maven dependencies
- **react-architect** - Frontend components, TypeScript patterns
- **devops-architect** - Infrastructure, Kubernetes, monitoring
- **bash-expert** - CLI tools, script development
- **doc-maintainer** - Documentation consistency

*No need to remember which agent to use - the system detects context automatically.*

### ⚡ Slash Commands

Versioned shortcuts for common workflows:

- **Git operations**: `/git:clone-subsystem`, repository management
- **Memory management**: `/memory:read`, `/memory:write` for session context
- **Build processes**: Frontend, Java, and deployment workflows

### 🎯 Quick Start by Technology

- **Java Development**: Architecture guides, coding standards, pattern libraries
- **Frontend Development**: React/TypeScript patterns, design system integration
- **Claude Code Integration**: [CLAUDE.md](http://claude.md/ "http://claude.md/") orchestrator, Docker environment

## 💬 Support

- **Questions & Discussion**: [#ai4dev-tools-and-support](https://gongio.slack.com/archives/C08P3AVM8J1 "https://gongio.slack.com/archives/C08P3AVM8J1") Slack channel
- **Documentation Updates**: Submit PRs to [gong-ai4dev repository](https://github.com/Honeyfy/gong-ai4dev "https://github.com/Honeyfy/gong-ai4dev")

---