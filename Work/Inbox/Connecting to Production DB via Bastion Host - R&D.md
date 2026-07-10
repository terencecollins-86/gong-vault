---
title: "Connecting to Production DB via Bastion Host - R&D"
source: "https://gongio.atlassian.net/wiki/spaces/EN/pages/3932247/Connecting+to+Production+DB+via+Bastion+Host"
author:
published:
created: 2026-06-16
description:
tags:
  - "clippings"
---
## Connecting to Production DB via Bastion Host

In order to connect to production DBs (Operational / Recorder / Ingester / etc), we use a set of Windows machines located in AWS which have access to the read-only replica of each DB.

This is similar to the console machine that is currently in use (console.honeyfy.local) - but provides a full Windows operating system for easier usage.

If you prefer command line access - see how [here](https://gongio.atlassian.net/wiki/spaces/EN/pages/2444394720/Access+to+PostgreSQL+databases+with+Satori#Console "https://gongio.atlassian.net/wiki/spaces/EN/pages/2444394720/Access+to+PostgreSQL+databases+with+Satori#Console")

The machines are ephemeral - meaning, that for security reasons, they're being recreated once a week.

As such, they are not to be used to store data for long periods of time.

In order to make the usage of the Bastions easier, we have a “RECREATE\_BASTION” flag in the Jenkins job, that allow you to pull the previously defined connections (JetBrains and MongoDB Compass).

Be aware: The bastions are being constantly monitored by our security tooling to validate that no sensitive data is being stored/moved in/out

Do not save or transfer any sensitive data from/to the machine without consulting with ProdSec team

Please note that the only folders that will be recreated are:

• AppData\\Roaming\\MongoDB Compass\\\*

• AppData\\Roaming\\JetBrains\\\*

## Connecting to a bastion-host machine

### Connection details

1. ***Do you know your LDAP user + password on*** [***Honeyfy.net***](http://honeyfy.net/ "http://Honeyfy.net") ***(NOT Gong.io).*** Note these are not the same as Okta credentials.  
	If you don't have any or forgot them or ***you are new at Gong***, use this job: [https://jenkins-devops.dev.gongio.net/job/add-Reset-LDAP-Users/](https://jenkins-devops.dev.gongio.net/job/add-Reset-LDAP-Users/ "https://jenkins-devops.dev.gongio.net/job/add-Reset-LDAP-Users/") to get a link via Slack, that will assist you to reset password.  
	For troubleshooting open a [Jira](https://gongio.atlassian.net/wiki/spaces/EN/pages/2504032280 "https://gongio.atlassian.net/wiki/spaces/EN/pages/2504032280") only after doing the below:

**Common Issues:**

- **Networking error:** Please ensure you are connected to the VPN. EU VPN for EU bastion
- **Authentication Error:** Re-set your LDAP password by running the job (Make sure you get a link to 1password in the slack message). Ensure your connection details are correct with the new/updated credentials from 1password.
- **Authentication Error:** Recreate your bastion with the **"RECREATE\_BASTION"** parameter selected.
![image-20260319-110000.png](https://media-cdn.atlassian.com/file/58d7fe82-ee7d-409b-b226-bf4a8671ae88/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-3932247&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC0zOTMyMjQ3IjpbInJlYWQiXX0sImV4cCI6MTc4MTYxNzMzOCwibmJmIjoxNzgxNjE0NDU4LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.RDbEi6_hLU0EdS5X0tUvHgGEybAljp02vmhGO6Je7HE&width=300#media-blob-url=true&id=58d7fe82-ee7d-409b-b226-bf4a8671ae88&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-3932247&collection=contentId-3932247)
- Try a different RDP client
2. You'll need to create your own personal **Bastion machine**.
	1. For production US (legacy GPE):  
		Create one using [this job](https://jenkins-devops.dev.gongio.net/job/Build-My-Win-Bastion/ "https://jenkins-devops.dev.gongio.net/job/Build-My-Win-Bastion/")  
		Once the job is done (it could take up to 15 minutes..) look for "Your Bastion Machine hostname is:" in the job's console output to find the newly created machine's hostname. The hostname is **ALWAYS** in the following format: **<your-first-name>-<your-last-name>.bastion-host.dev.gongio.net**  
		Alternatively - when the job is done, Jenkins also sends a message to your **#jenkins-app** channel in slack with the hostname:  
		![](https://media-cdn.atlassian.com/file/37e94c15-c9ca-4d83-9846-068adccb5874/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-3932247&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC0zOTMyMjQ3IjpbInJlYWQiXX0sImV4cCI6MTc4MTYxNzMzOCwibmJmIjoxNzgxNjE0NDU4LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.RDbEi6_hLU0EdS5X0tUvHgGEybAljp02vmhGO6Je7HE&width=621#media-blob-url=true&id=37e94c15-c9ca-4d83-9846-068adccb5874&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-3932247&collection=contentId-3932247)
		2. For EU follow this instructions: [Connecting to Eu-02 Bastion Hosts](https://gongio.atlassian.net/wiki/spaces/EN/pages/3747710059)
		3. For global account (AKA GGE):  
		We currently do not have a fully implemented solution for ASA Bastion in GGE.  
		As a temporary measure, we use separate EC2 instances where users are created based on requests.  
		These users are not linked to any domain, and their management is currently handled manually.  
		We have multiple servers for GGE, with three users assigned to each.  
		Due to the limitations of the free license, the number of simultaneous RDP sessions is restricted to 2.  
		If you encounter any login issues, please let us know, and we will resolve them as soon as possible.
		Available Bastion Servers:  
		1\. **bastion-1.gge-use1.gongio.net**  
		\- doron.tohar@honeyfy.net  
		\- lior.ben.ami@honeyfy.net  
		\- nimrod.nahum@honeyfy.net  
		2\. **bastion-2.gge-use1.gongio.net**  
		\- haggai.meltzer@honeyfy.net  
		\- yonatan.pinko@honeyfy.net  
		\- ola.hamud@honeyfy.net
		4. [Connecting to Eu-02 Bastion Hosts](https://gongio.atlassian.net/wiki/spaces/EN/pages/3747710059 "https://gongio.atlassian.net/wiki/spaces/EN/pages/3747710059")
3. Enter you LDAP Credentials

Windows

- Download the following RDP connection [file](https://gongio.atlassian.net/wiki/download/attachments/3932247/BastionHost.rdp?version=3&modificationDate=1621767100872&cacheVersion=1&api=v2 "https://gongio.atlassian.net/wiki/download/attachments/3932247/BastionHost.rdp?version=3&modificationDate=1621767100872&cacheVersion=1&api=v2")
- Right click on the downloaded file and edit it
	- Replace "computer" with your bastion hostname
		- Replace "user name" with your own (i.e. [first-name.last-name@honeyfy.net](mailto:first.last@honeyfy.net "mailto:first.last@honeyfy.net"))
		- Save it.
![](https://media-cdn.atlassian.com/file/a8e188b4-1795-43d0-9f1f-49edfa6f4323/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-3932247&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC0zOTMyMjQ3IjpbInJlYWQiXX0sImV4cCI6MTc4MTYxNzMzOCwibmJmIjoxNzgxNjE0NDU4LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.RDbEi6_hLU0EdS5X0tUvHgGEybAljp02vmhGO6Je7HE&width=2543#media-blob-url=true&id=a8e188b4-1795-43d0-9f1f-49edfa6f4323&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-3932247&collection=contentId-3932247)
- After connecting to the VPN, double click and connect with your credentials

## Connecting to a production database (through Bastion)

We use

1. DataGrip for legacy GPE (AKA production US)
2. DBeaver for EU/GGE (DataGrip needs to access Intellij's license server which isn't accessible from the global account for now)

DataGrip:

- Double click on the "DataGrip" icon located on the Windows Windows desktop screen screen (through the Bastion connection).
- (If you don't have any databases) duplicate an example postgres connection ('Satori Postgres Example') and update the copied configuration with your specific database connection details ([Access to PostgreSQL databases with Satori](https://gongio.atlassian.net/wiki/spaces/EN/pages/2444394720 "https://gongio.atlassian.net/wiki/spaces/EN/pages/2444394720"))
![](https://media-cdn.atlassian.com/file/7f9c9b75-9b06-489e-98b8-30c163a96727/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-3932247&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC0zOTMyMjQ3IjpbInJlYWQiXX0sImV4cCI6MTc4MTYxNzMzOCwibmJmIjoxNzgxNjE0NDU4LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.RDbEi6_hLU0EdS5X0tUvHgGEybAljp02vmhGO6Je7HE&width=510#media-blob-url=true&id=7f9c9b75-9b06-489e-98b8-30c163a96727&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-3932247&collection=contentId-3932247)
- Synchronize your credentials by clicking on the "Synchronize" button and enter your DB credentials (i.e. "first\_last")
![](https://media-cdn.atlassian.com/file/11bb9b5f-326b-4489-8726-8cb796c4627e/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-3932247&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC0zOTMyMjQ3IjpbInJlYWQiXX0sImV4cCI6MTc4MTYxNzMzOCwibmJmIjoxNzgxNjE0NDU4LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.RDbEi6_hLU0EdS5X0tUvHgGEybAljp02vmhGO6Je7HE&width=544#media-blob-url=true&id=11bb9b5f-326b-4489-8726-8cb796c4627e&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-3932247&collection=contentId-3932247) ![](https://media-cdn.atlassian.com/file/7fe5252f-c989-43e6-9826-f44b3f2bc7f8/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-3932247&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC0zOTMyMjQ3IjpbInJlYWQiXX0sImV4cCI6MTc4MTYxNzMzOCwibmJmIjoxNzgxNjE0NDU4LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.RDbEi6_hLU0EdS5X0tUvHgGEybAljp02vmhGO6Je7HE&width=578#media-blob-url=true&id=7fe5252f-c989-43e6-9826-f44b3f2bc7f8&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-3932247&collection=contentId-3932247)

DBeaver:

1. Open DBeaver:  
	![](https://media-cdn.atlassian.com/file/96a98551-c162-4573-8de4-51c27ff57155/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-3932247&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC0zOTMyMjQ3IjpbInJlYWQiXX0sImV4cCI6MTc4MTYxNzMzOCwibmJmIjoxNzgxNjE0NDU4LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.RDbEi6_hLU0EdS5X0tUvHgGEybAljp02vmhGO6Je7HE&width=170#media-blob-url=true&id=96a98551-c162-4573-8de4-51c27ff57155&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-3932247&collection=contentId-3932247)
2. Disable channel binding check [How to Disable Channel Binding in DBeaver](https://gongio.atlassian.net/wiki/spaces/DEVOPS/pages/5555224596)
3. Create new connection:  
	![](blob:https://gongio.atlassian.net/2a9f6aa1-80bd-47f1-a014-337869b741cc#media-blob-url=true&id=69e08a96-76f2-423a-84c3-f277dd1dfba3&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-3932247&collection=contentId-3932247)
4. Add the connection details from Satori and you're good to go

Note:

If you have an issue while downloading drivers, please go (in DBeaver Top Menu): Window→Preferences->Connections, turn off "Windows trust store" setting, restart DBeaver and continue.  

![](blob:https://gongio.atlassian.net/276a5fda-82e7-45ad-aed4-74f533ea0384#media-blob-url=true&id=ab52bd6e-c393-47a6-9da0-41c65099351d&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-3932247&collection=contentId-3932247)

## Querying a specific production database

To query a specific db you'll need a password.

To obtain one and connect to the db follow instructions [here](https://gongio.atlassian.net/wiki/spaces/EN/pages/2444394720/Access+to+PostgreSQL+databases+with+Satori#Bastion "https://gongio.atlassian.net/wiki/spaces/EN/pages/2444394720/Access+to+PostgreSQL+databases+with+Satori#Bastion").

## Adding a new database in DataGrip

To add a new database, please follow [this guide](https://gongio.atlassian.net/wiki/spaces/EN/pages/2444394720/Access+to+PostgreSQL+databases+with+Satori#How-to-add-a-new-connection%3F "https://gongio.atlassian.net/wiki/spaces/EN/pages/2444394720/Access+to+PostgreSQL+databases+with+Satori#How-to-add-a-new-connection%3F").

==All DataGrip settings== (preferences / queries / consoles) are synced for each user and being re-synced upon login.  
  
\*\*\* Please note that the only folders synchronized with S3 from Bastion are (mentioned on top):

**• Documents\\\***

**• Desktop\\\***