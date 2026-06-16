---
title: "Adjustable Logging - R&D"
source: "https://gongio.atlassian.net/wiki/spaces/EN/pages/3103196742/Adjustable+Logging"
author:
published:
created: 2026-06-16
description:
tags:
  - "clippings"
  - "learning"
  - "engineering"
---
## Adjustable Logging

## Motivation

In order to reduce our logging costs (see [logs cost dashboard](https://app.datadoghq.com/dashboard/awf-kce-64a/logging-costs-dashboard?view=spans "https://app.datadoghq.com/dashboard/awf-kce-64a/logging-costs-dashboard?view=spans")) and following some feedbacks we got around adjusting the modules log levels we introduce a new functionality to help the teams adjusting their log levels.

---

## Log Levels in Gong - Standards Review

Currently the default verbosity level for modules is DEBUG unless defined otherwise.

As a refresher the logging levels and how they are/should be used in Gong, in growing level of verbosity:

- **==ERROR==** ==\- indicates something== **==is a bug==**==, usually unexpected. Triggers sentry and various flows. Kept in the logs for longer than the other logs.== **==If this is a transient error, it shouldn't be an error.==**  
	Error logs generate Sentry events. So another way to look at is basically you'd want to log as an error anything that should trigger a Sentry event (or the other way around - ask if this is something you'd want a Sentry for, otherwise it may not need to be an error). If a single occurrence of this state should be handled by on-call, then it should be logged using `ERROR`. Otherwise use `WARN` and look for other ways to monitor this (usually metrics and alerts). In general, transient errors should be logged as `WARN` and they should be monitored with relevant alerts for increased rates and duration of failures.  
	Examples for transient errors:
	- Client errors (client sent bad data to my API) **should not** be logged as errors (also this is usually expected and part of the working order of things → warning at most). But client errors should be monitored for anomalies that may be caused by Gong issues.
		- Failure to process a single data event **should not** be an error log. Example for data event - CRM change event. Example for an event that might trigger sentry - company purge event. Even if you decide to log event processing as error, make sure you do this after exhausting all retries. Again, event processing failures **should** be monitored for anomalies.
		- A transient failure in feign client request **should not** be logged by the client as an error. Transient errors are 5xx. Feign clients can fail due to transient issues such network down, service down, etc. Transient errors should be monitored.
- **WARN** - indicates something may be wrong or an expected error. Tracked by the teams and not via sentry
- **====INFO====** ==\- information we need when the system is in GA, to know the module is working as expected without further debugging details (enough to know things are working, not necessarily enough to debug a deep coding problem). Should be summaries of things if possible==
	- General rule of thumb: use info for high-level events, significant state changes, and successful business transactions
		- We have many default info logs already, don't add additional logs if you don't need to. For example service start/stop, API requests, ==Kafka event consumption==
		- Avoid putting info logs in tight loops. It is probably ok to put info in (for company in …) loops but not a good idea when, e.g. iterating over emails or todos
	If you need to log additional technical details, use DEBUG level.
- **DEBUG** - information we need to debug the module. This is our lowest logging level in production at the moment.
- **TRACE** - when we write a new feature/module, and want to make sure the code works, we'll usually add a lot of log messages in DEBUG to check our logic and make sure things are working as tested/expected in Prod. Once the module is GA'ed we'll usually reduce the verbosity of these logs to TRACE since we don't need them anymore (not even necessarily for debugging), but don't want to remove logs which were useful once (I took the time to write them, so they might be useful in the future again…). That's where trace comes in - logs we needed once, don't need anymore, but don't want to remove. **Trace can also be used to debug locally.**

As explained in TRACE, logs will *sometimes* migrate between the categories as the code/module/feature migrate from in-development to LA to GA. The same can be said for the module's entire logging in logback.

Regarding DEBUG and TRACE - know that Lightrun may be a better option to debugging in Prod than using these logs

---

## Procedure

Following the above explanation of our various logging levels, the expected flow is:

1. Module owners and teams who opt in will change their module's logging levels in the module's logback xmls (see "Adjusting your logs for the long term" below) to reflect the logs they absolutely need to monitor their system on the regular
	1. If you have infra logs that need adjusting (not log messages you wrote) that are overriden by us, then you need to discuss that with our infra team to see what we want to do about that
2. When the module owner and team need to debug a problem → increase the verbosity of a log that was reduced → follow "Adjust your logs temporarily" below

Logs that are needed for startup/shutdown should not be played with here and should be 'as is' in the logback xml files. There may be a short delay on startup until the adjusted levels are reflected.

---

## Solution Design

The solution is composed of two basic components:

1. **LogsManager** - a module that has access to a dedicated Redis cluster to save all the loggers and their levels for each context.
2. **AdjustableLogging** - a jar that is found on each of our deployable modules. The jar implements a schedule task that polls **LogsManager** via Feign for all the temporary adjustable loggers.
	1. When a new logger (and its level) is within the response, the task will automatically set the level for this logger in the pod logback configuration (no restart is needed).
		2. When a specific logger (and its level) is removed from the response, the task will automatically set the original level (from our logback.xml) for this logger in the pod logback configuration.

**Note that even if something fails within this process, there won't be any errors (only warns) as this should not interfere with the module errors and alerts.**

Reference design document: [Adjustable logging levels - design](https://gongio.atlassian.net/wiki/spaces/EN/pages/2811922975)

---

## Adjusting your logs for the long term

We added three options to override the default logback.xml configuration:

1. `logback-app-defaults.xml` should be found under your application resources folder (see example under `WebAppSample` resources folder). **This will affect the log configuration for your application across all cells.**  
	If the file doesn't exist, create it. [For example](https://github.com/Honeyfy/gong-email-digestion/blob/556c3c57eb1db14592ad8030dc4aefb970f7ece3/EmailsIndexer/src/main/resources/logback-app-defaults.xml#L2 "https://github.com/Honeyfy/gong-email-digestion/blob/556c3c57eb1db14592ad8030dc4aefb970f7ece3/EmailsIndexer/src/main/resources/logback-app-defaults.xml#L2"):
	```xml
	<included>
	    <logger name="com.honeyfy" level="INFO"/>
	</included>
	```
2. `==logback-cell-defaults.xml==` ==should be found under== `==gong-app-properties==` ==repository (see example here:== [==https://github.com/search?q=repo%3AHoneyfy%2Fgong-app-properties "logback-cell-defaults.xml"&type=code==](https://github.com/search?q=repo%3AHoneyfy%2Fgong-app-properties%20%22logback-cell-defaults.xml%22&type=code "https://github.com/search?q=repo%3AHoneyfy%2Fgong-app-properties%20%22logback-cell-defaults.xml%22&type=code")
3. `==logback-app-cell-overrides.xml==` ==should be found under== `==gong-app-properties==` ==repository (see example here:== [==https://github.com/search?q=repo%3AHoneyfy%2Fgong-app-properties+"logback-app-cell-overrides.xml"&type=code&p=1==](https://github.com/search?q=repo%3AHoneyfy%2Fgong-app-properties+%22logback-app-cell-overrides.xml%22&type=code&p=1 "https://github.com/search?q=repo%3AHoneyfy%2Fgong-app-properties+%22logback-app-cell-overrides.xml%22&type=code&p=1")

Infra logs will not be affected by your changes. We have a different logback.xml that is maintained but the infra team that controls log levels for infra logs.

---

## Adjusting your logs temporarily

If you want to increase / decrease your log levels you should follow these steps:

1. Goto [dev gateway](https://dev-data-gateway-vip.prod.gongio.net/troubleshooter-audit-request "https://dev-data-gateway-vip.prod.gongio.net/troubleshooter-audit-request")
2. Request access to LogsManager troubleshooter
3. Use the set method [https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/set](https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/set "https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/set")
	1. **Context** - your module
		2. **Logger** - can be a package or the logger full qualified name (`com.example` or `com.example.Someservice`. Note that changing the package logger level will change the log levels of all of its descendent loggers).
		3. **Level** - the required level.
		4. **Duration** - the amount of time you want to set this log level for this logger. Should be in a duration format `PT30m` for 30 minutes, `PT2h` for 2 hours.

You have additional troubleshooters to help you verify what is the current status:

1. [https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/get](https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/get "https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/get") - to get the logger level of specific logger and context
2. [https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/listLoggingLevels](https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/listLoggingLevels "https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/listLoggingLevels") - to list all loggers and their levels for a specific context
3. [https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/clear](https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/clear "https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/clear") - to clear all temporary adjusted loggers.

---

## Debugging log levels

We added a built in troubleshooter in each of our deployable modules to help you debug the current status of your module loggers and levels.

To access it, follow these steps:

1. Goto [dev gateway](https://dev-data-gateway-vip.prod.gongio.net/troubleshooter-audit-request "https://dev-data-gateway-vip.prod.gongio.net/troubleshooter-audit-request")
2. Request access to your module troubleshooter
	1. `/list-logback-loggers` - list the current module loggers and their levels. Please note that the response here includes all the defaults and temporary loggers.
		2. `/list-updated-loggers` - list the current temporary loggers and their levels.

---

## Related Notes

- [[Metrics in Gong - the complete guide - R&D]] — metrics infrastructure, Datadog/OpenSearch
