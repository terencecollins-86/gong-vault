---
title: "Lightrun - R&D"
source: "https://gongio.atlassian.net/wiki/spaces/EN/pages/2750578895/Lightrun"
author:
published:
created: 2026-06-16
description:
tags:
  - "clippings"
---
## Lightrun

In this article, you will find information about Lightrun and instructions for installing it.

Lightrun is a production debugger that allows setting virtual breakpoints in production code and investigating issues in real-time. In addition, Lightrun can inject logs on-demand, so you don't have to plan them in advance, which also reduces our logging costs.

## Installation

- Make sure you are on the VPN.

VPN is required for Lightrun since we use an on-premise system deployment within our AWS ==environment==.

- Sign-up to Lightrun to initialize your user. Follow this link: [https://lightrun.c1-devops.use1.prod.gongio.net/api/oauth/register?company=9933717a-2245-4d93-9ce1-75a59be0c2fe&key=12cf112e-03f5-42da-a2f3-3c46d331872b](https://lightrun.c1-devops.use1.prod.gongio.net/api/oauth/register?company=9933717a-2245-4d93-9ce1-75a59be0c2fe&key=12cf112e-03f5-42da-a2f3-3c46d331872b "https://lightrun.c1-devops.use1.prod.gongio.net/api/oauth/register?company=9933717a-2245-4d93-9ce1-75a59be0c2fe&key=12cf112e-03f5-42da-a2f3-3c46d331872b")
- Use **Okta** SSO to log in to Lightrun, so you should *not* use a user/password for the application.
- Fill in your first and last names.
- ==Lightrun is operated from IntelliJ. Install the IntelliJ Lightrun plugin according to the instructions provided on the== [*Install the plugin in your IDE*](https://lightrun.c1-devops.use1.prod.gongio.net/company/9933717a-2245-4d93-9ce1-75a59be0c2fe/learn-and-explore/install-the-plugin-in-your-ide "https://lightrun.c1-devops.use1.prod.gongio.net/company/9933717a-2245-4d93-9ce1-75a59be0c2fe/learn-and-explore/install-the-plugin-in-your-ide") page of our local server (see below). *==Do not==* ==download the plugin from any public repositories or IntelliJ market==.
- After installation and IntelliJ restart, configure the plugin according to the screen below. Notice the Lightrun server URL (*https://lightrun.c1-devops.use1.prod.gongio.net*) and the Send Source Full Path is checked (see below).
- Now you can log in to Lightrun from IntelliJ by selecting the Lightrun sidebar and clicking Login. This should bring up your default browser and allow you to log in using Okta. Once logged in, the Lightrun sidebar in IntelliJ will populate with the list of agents and tags it is connected to.

*Agents* represent individual Gong servers. *Tags* label each service cluster, for example, CRMEnricher.

- Upon successful configuration, Lightrun installs its buttons in the editor gutter and the editor context menu. You can customize the position of the Lightrun buttons on these menus using this IntalliJ settings screen (drag-and-drop the Lightrun icon to adjust the position).

## Usage

**Setting a virtual breakpoint**

- Ensure the version of the class you want to debug in your IDE matches the version currently deployed in production. Lightrun works at the level of line numbers within Java files, meaning that it is adequate to ensure the alignment of lines being debugged without requiring an exact match of the build or other files.
- Scroll to the method's code in your editor and use the gutter menu to set a Snapshot at the required location.
- Fill out the snapshot parameters.

IMPORTANT: Select the proper Tag in the **Source** field to designate the snapshot's target cluster.

- Proceed to the Lightrunn Snapshots bottom bar to view the snapshots and the corresponding stack frames.
- Delete the Virtual Breakpoint after use.

## Additional information

- Join the Lightrun users channel for questions and tips: [#lightrun-users](https://gongio.slack.com/archives/C04FYT4J5LJ "https://gongio.slack.com/archives/C04FYT4J5LJ")
- The introduction calls recordings:  
	\- in Hebrew: [https://gong.app.gong.io/call?id=3149460884133359833](https://gong.app.gong.io/call?id=3149460884133359833 "https://gong.app.gong.io/call?id=3149460884133359833")  
	\- in English: [https://gong.app.gong.io/call?id=4341553839909466484](https://gong.app.gong.io/call?id=4341553839909466484 "https://gong.app.gong.io/call?id=4341553839909466484")
- Peruse Lightrun documentation for additional Lightrun capabilities:

[https://docs.lightrun.com/actions/](https://docs.lightrun.com/actions/)

## Tips

- If you want to snapshot on an MDC value, use a condition like this:  
	==Objects.==*==equals==* ==(org.slf4j.MDC.==*==get==* ==("cid"), "3591171234567554980")==  
	Note, if you have an *and* (&&) condition, in many cases it is better to put such code as the first argument of an && to limit the number of evaluations of the second condition.