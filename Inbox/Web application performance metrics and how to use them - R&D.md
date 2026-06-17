---
title: "Web application performance metrics and how to use them - R&D"
source: "https://gongio.atlassian.net/wiki/spaces/EN/pages/4410605709/Web+application+performance+metrics+and+how+to+use+them"
author:
published:
created: 2026-06-17
description:
tags:
  - "clippings"
---
## Web application performance metrics and how to use them

## Intro

Web applications can be measured in different ways, starting from network connectivity to inner application transactions and rendering cycles. To allow a common language and utilities around it, there is a wide standard around [Core Web Vitals](https://web.dev/explore/learn-core-web-vitals "https://web.dev/explore/learn-core-web-vitals") that defines the relevant metrics, how to measure them, and thresholds to define desired values across the industry.

## APM in Gong

In Gong, we’ve chosen Dynatrace as our APM (Application Performance Monitoring) tool, and are leveraging their RUM (Real User Monitoring) application to measure our web application.

The RUM agent is set as a JS snippet as part of our HTML template and is applied to all Gong web pages, for all environments. The data is managed across different Dynatrace tenants (Dev, US, Prod) and defined on the snippet level.

### How to measure a page’s load time

Page load can be measured using [LCP](https://web.dev/articles/lcp "https://web.dev/articles/lcp") to define the time it took a user to get the majority of the application to render in a case or a page load.

In DT, use the [“Web” application](https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.frontend/#uemapplications/uemappmetrics;uemapplicationId=APPLICATION-E13E4678422D588C;gtf=-2h;gf=all "https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.frontend/#uemapplications/uemappmetrics;uemapplicationId=APPLICATION-E13E4678422D588C;gtf=-2h;gf=all") as an entry point for getting information about Gong  

Open ![image-20250916-103923.png](https://media-cdn.atlassian.com/file/a8955964-bb92-4aff-b9ca-15472ef763ca/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-4410605709&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC00NDEwNjA1NzA5IjpbInJlYWQiXX0sImV4cCI6MTc4MTY5MDgzNywibmJmIjoxNzgxNjg3OTU3LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.SsZvZKgafICRD18FCMmfvnZT6iElnnL6snoa0qtHJHk&width=760#media-blob-url=true&id=a8955964-bb92-4aff-b9ca-15472ef763ca&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-4410605709&collection=contentId-4410605709)

[https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.web/#uemapplications/uemappmetrics;gtf=-2h;gf=all;uemapplicationId=APPLICATION-E13E4678422D588C](https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.web/#uemapplications/uemappmetrics;gtf=-2h;gf=all;uemapplicationId=APPLICATION-E13E4678422D588C "https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.web/#uemapplications/uemappmetrics;gtf=-2h;gf=all;uemapplicationId=APPLICATION-E13E4678422D588C")

Since the Gong web application is implemented as a multi-SPA, the high-level metrics are less relevant for us, on the other hand, the metrics per page can show us the desired information

[![image-20250916-104156.png](https://media-cdn.atlassian.com/file/282068e2-ffe8-4b79-a6e2-7fe25c412373/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-4410605709&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC00NDEwNjA1NzA5IjpbInJlYWQiXX0sImV4cCI6MTc4MTY5MDgzNywibmJmIjoxNzgxNjg3OTU3LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.SsZvZKgafICRD18FCMmfvnZT6iElnnL6snoa0qtHJHk&width=760#media-blob-url=true&id=282068e2-ffe8-4b79-a6e2-7fe25c412373&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-4410605709&collection=contentId-4410605709)](https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.web/ui/applications/APPLICATION-E13E4678422D588C/pages/details?filtr3filterTargetViewGroup=s%2Fcall&gtf=-2h&gf=all)

[https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.web/ui/applications/APPLICATION-E13E4678422D588C/pages/details?filtr3filterTargetViewGroup=s%2Fcall&gtf=-2h&gf=all](https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.web/ui/applications/APPLICATION-E13E4678422D588C/pages/details?filtr3filterTargetViewGroup=s%2Fcall&gtf=-2h&gf=all "https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.web/ui/applications/APPLICATION-E13E4678422D588C/pages/details?filtr3filterTargetViewGroup=s%2Fcall&gtf=-2h&gf=all")

The waterfall analysis will allow us to have an aggregate view of the page load and the potential API calls or resources that affect the page load time

Open ![image-20250916-104353.png](https://media-cdn.atlassian.com/file/e3d40216-28b7-43c6-b527-59f14ded4ea0/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-4410605709&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC00NDEwNjA1NzA5IjpbInJlYWQiXX0sImV4cCI6MTc4MTY5MDgzNywibmJmIjoxNzgxNjg3OTU3LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.SsZvZKgafICRD18FCMmfvnZT6iElnnL6snoa0qtHJHk&width=760#media-blob-url=true&id=e3d40216-28b7-43c6-b527-59f14ded4ea0&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-4410605709&collection=contentId-4410605709)

[https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.frontend/#uemapplications/uempagewaterfall;gtf=-2h;gf=all;filtr3filterTargetViewGroup=s\\0call;uemapplicationId=APPLICATION-E13E4678422D588C;uatype=Load;filtr3facttyp=Load;uemSelDaSe=All](https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.frontend/#uemapplications/uempagewaterfall;gtf=-2h;gf=all;filtr3filterTargetViewGroup=s%5C0call;uemapplicationId=APPLICATION-E13E4678422D588C;uatype=Load;filtr3facttyp=Load;uemSelDaSe=All "https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.frontend/#uemapplications/uempagewaterfall;gtf=-2h;gf=all;filtr3filterTargetViewGroup=s%5C0call;uemapplicationId=APPLICATION-E13E4678422D588C;uatype=Load;filtr3facttyp=Load;uemSelDaSe=All")

### Drilling down into an API performance issue

From the waterfall view, you can pinpoint your performance bottlenecks and drill down to the relevant transactions. The drill-down can allow us to navigate through the API request flow along different services and DB queries to map the time spent on each level

Open ![image-20250916-105601.png](https://media-cdn.atlassian.com/file/54ebc328-fcce-426b-abca-f29330031e3f/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-4410605709&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC00NDEwNjA1NzA5IjpbInJlYWQiXX0sImV4cCI6MTc4MTY5MDgzNywibmJmIjoxNzgxNjg3OTU3LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.SsZvZKgafICRD18FCMmfvnZT6iElnnL6snoa0qtHJHk&width=760#media-blob-url=true&id=54ebc328-fcce-426b-abca-f29330031e3f&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-4410605709&collection=contentId-4410605709)

[https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.services/#responsetimeanalysis;sci=SERVICE-D6B779E99D0D37A1;timeframe=custom1758012665184to1758019865184;servicefilter=07APPLICATION-E13E4678422D588C00SERVICE-D6B779E99D0D37A11010SERVICE\_METHOD\_GROUP-219263613AF487FB9SERVICE\_METHOD-DBB9CCB6E36CB9D7;gf=all;gtf=c\_1758012665184\_1758019865184](https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.services/#responsetimeanalysis;sci=SERVICE-D6B779E99D0D37A1;timeframe=custom1758012665184to1758019865184;servicefilter=0%1E7%11APPLICATION-E13E4678422D588C%150%150%1F%15SERVICE-D6B779E99D0D37A1%151%150%1F10%13SERVICE_METHOD_GROUP-219263613AF487FB%129%13SERVICE_METHOD-DBB9CCB6E36CB9D7%15;gf=all;gtf=c_1758012665184_1758019865184 "https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.classic.services/#responsetimeanalysis;sci=SERVICE-D6B779E99D0D37A1;timeframe=custom1758012665184to1758019865184;servicefilter=0%1E7%11APPLICATION-E13E4678422D588C%150%150%1F%15SERVICE-D6B779E99D0D37A1%151%150%1F10%13SERVICE_METHOD_GROUP-219263613AF487FB%129%13SERVICE_METHOD-DBB9CCB6E36CB9D7%15;gf=all;gtf=c_1758012665184_1758019865184")

### Custom dashboards

In some cases, the custom dashboards rely on JS code that visualizes the metrics. To enable them, please allow running JS on the dashboard level when you first access them.

Open ![image-20250918-112813.png](https://media-cdn.atlassian.com/file/77cf64d8-323f-4f73-8465-46cdc599f83b/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-4410605709&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC00NDEwNjA1NzA5IjpbInJlYWQiXX0sImV4cCI6MTc4MTY5MDgzNywibmJmIjoxNzgxNjg3OTU3LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.SsZvZKgafICRD18FCMmfvnZT6iElnnL6snoa0qtHJHk&width=700#media-blob-url=true&id=77cf64d8-323f-4f73-8465-46cdc599f83b&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-4410605709&collection=contentId-4410605709)

#### Core Web vitals

This dashboard will allow you to monitor pages on a high level, as well as provide insights on a company level, to understand if we have a performance issue for a specific page on a specific company level

[https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.dashboards/dashboard/9d523050-9fd4-4e03-b549-b5d13c666281#vfilter\_CompanyName=Gong&vfilter\_ActionType=Entry&from=now()-7d&to=now()](https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.dashboards/dashboard/9d523050-9fd4-4e03-b549-b5d13c666281#vfilter_CompanyName=Gong&vfilter_ActionType=Entry&from=now%28%29-7d&to=now%28%29 "https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.dashboards/dashboard/9d523050-9fd4-4e03-b549-b5d13c666281#vfilter_CompanyName=Gong&vfilter_ActionType=Entry&from=now%28%29-7d&to=now%28%29")

#### Page Load Overview

This dashboard will allow you to monitor the CWV of pages over time

[https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.dashboards/dashboard/d0b2cbc4-867a-4cb5-9064-28c9cfdc396f](https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.dashboards/dashboard/d0b2cbc4-867a-4cb5-9064-28c9cfdc396f "https://pte42846.apps.dynatrace.com/ui/apps/dynatrace.dashboards/dashboard/d0b2cbc4-867a-4cb5-9064-28c9cfdc396f")

#### Creating your own dashboard

- [Self-monitoring metrics](https://docs.dynatrace.com/docs/analyze-explore-automate/metrics-classic/self-monitoring-metrics)
- [Metric events](https://docs.dynatrace.com/docs/discover-dynatrace/platform/davis-ai/anomaly-detection/set-up-a-customized-anomaly-detector/how-to-set-up/metric-events)
- [Create and edit Dynatrace dashboards](https://docs.dynatrace.com/docs/analyze-explore-automate/dashboards-classic/dashboards/create-dashboards)

### Measuring application flows

In some cases, we will want to measure an application flow and not a specific transaction. To enable us to create an internal utility that augments application flows and measures the time from start to finish.

For more details, please follow -

[UI Performance monitoring](https://gongio.atlassian.net/wiki/spaces/EN/pages/2767257646/UI+Performance+monitoring?atl_f=PAGETREE)