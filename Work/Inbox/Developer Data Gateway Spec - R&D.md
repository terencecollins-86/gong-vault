---
title: "Developer Data Gateway Spec - R&D"
source: "https://gongio.atlassian.net/wiki/spaces/EN/pages/2621997059/Developer+Data+Gateway+Spec"
author:
published:
created: 2026-06-16
description:
tags:
  - "clippings"
---
## Developer Data Gateway Spec

### Background

Our ongoing Argus project requires that we have the ability to audit when developers access raw customer data from our non-Satori-audited data sources, namely Redis and Kafka. For that, we are going to create a portal that is connected to OKTA where developers can enter their data source and cluster, as well as a justification for accessing them. A Jira ticket will be opened with the details, and all access to the troubleshooter will be audited in the access log with a reference to that Jira ticket.

### Product Flow

#### Request

1. In OKTA the developer will choose the **Developer Data Gateway** app
2. The portal will open and the dev will need to fill:
	1. Related Jira Id (if such exists): the id of the related Ticket/case - choose from the list of your assigned cases (not mandatory)
		2. Description: The purpose of needing access
		3. ==Data== Store: Currently Kafka, Redis, SQS and in Global Cell (GGE) Credentials Manager (to create/update secrets)
		4. ==Available Cluster: Based on (c) we will present the relevant clusters==
3. Press the “Request Access” button.

#### Result

1. We are going to use the current troubleshooter mechanism so a TSA Jira will be created containing the details filled (it will be linked to an existing JIRA item if supplied).
2. A Tab will be open with swaggers of the relevant requested data source and the same cookie used by troubleshooter authorization named troubleshootersAuthJWT will be set in the session. (take out the JWT from the URL to the body)
3. Now troubleshooters can be run for the next 12 hours.
4. Since we will use the same mechanism of the troubleshooter mechanism and have the troubleshooter cookie each troubleshooter call will have the matching Jira id and user in the matching access log entry

### Troubleshooters Spec

#### Kafka

Currently, the troubleshooter that will be used is the standard **kafka-admin-troubleshooter** with a few tweaks so that no cluster can be chosen since we will use the one that was authorized.

#### Redis

In the beginning, a troubleshooter will be created with basic operations, and with demand, more methods will be added

` keys()`

`keysByPattern(@RequestParam(name = "pattern") String pattern) `

`namedQueueInfo(@ApiParam(required = true, value = "Queue name")@RequestParam(name = "name") String name)`

### Open Questions

1. Are we going to allow write/delete operations for Redis? Today most of the Redis troubleshooters have this ability
2. Can we add more functionality to the Kafka troubleshooter that currently are restricted like listing a group’s ACLs. Yes
3. Are we going to allow multiple cluster permissions like the troubleshooter authorization? Yes
4. How long is the JWT expiration session? 8 hours
5. What can be done to prevent other troubleshooters from accessing Redis? Currently, it is a wild west situation. In each troubleshooter, there are different methods
6. Should the developer enter the required topics as well? Not so straightforward. Because for example, we have the list topics operation, how will it work?
7. What do we do to prevent developers from using Redis, and why should they? Because of the way Redis is built it is much more convenient to build your own troubleshooter with your collection logic.
8. How do we enter new clusters automatically into the portal? Need DevOps development here as well.
9. What should we do about UI dependencies? Should we use our design systems or do we want to keep this module as isolated as possible?
10. Is there a point in doing a Redis portal now that DataGrip supports Redis (using JDBC driver)? Can Satori do the logical DB management? [DataGrip 2022.3 EAP 2: Redis Support | The DataGrip Blog](https://blog.jetbrains.com/datagrip/2022/11/02/datagrip-2022-3-eap-2-redis-support/)