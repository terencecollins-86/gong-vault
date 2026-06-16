---
title: "Metrics in Gong - the complete guide - R&D"
source: "https://gongio.atlassian.net/wiki/spaces/EN/pages/2218033248/Metrics+in+Gong+-+the+complete+guide"
author:
published:
created: 2026-06-16
description:
tags:
  - "clippings"
---
## Metrics in Gong - the complete guide

## Training video

This article summarizes the [presentation in Google Drive](https://docs.google.com/presentation/d/1JLNVYiVKplg7YuggYYFSDI37ENjEYkJ3njJQbrClweQ/edit?usp=sharing "https://docs.google.com/presentation/d/1JLNVYiVKplg7YuggYYFSDI37ENjEYkJ3njJQbrClweQ/edit?usp=sharing"). It is here mostly for search and copy/paste reasons. It is recommended to listen to the training video [**here**](https://gong.app.gong.io/call?id=6892404315825484745&xtid=5mv6d9r8jo46qqz84r "https://gong.app.gong.io/call?id=6892404315825484745&xtid=5mv6d9r8jo46qqz84r") (older Hebrew version in [here](https://app.gong.io/call?id=4351459744092035666 "https://app.gong.io/call?id=4351459744092035666")) to get a better explanation of the matter.

For your convenience, many of the headers below are direct links to the time in the training where we discuss the subject.

## Intro

## Definition of metrics

- **Metric definition**: A numeric measure in time (count, rate, time, meter) that represents a certain behavioral flow of your system. A metric can represent anything, which is numerically measurable - memory consumption, network bandwidth, emails sent, jobs executed etc.
- Metrics allow us to:
	- Monitor the behavior, performance and health of our production system
		- Measure the behavior of critical components in our production environment
		- Track the behavior of our system in the long run and identify anomalies / misbehavior - this can be done by graphing a metric value over time and checking the graph’s behavior
		- Set up alerts when a metric value crosses a predefined threshold

## Metric Dimensions

### Metric Dimensions - Motivation

- Sometimes you want to analyze the same metric according to several criteria, e.g numberOfDroppedEvents in WebFrontEnd vs. Orchestrator.
- In this example the metric is the same metric but you want to separate the count by Context.
- For this, metrics could have dimensions - in our example the dimension is called Context and its value may be any of our deployable modules’ names

### Metric Dimensions - How It Works

- When you define a metric you can define a set of dimensions for it, each with various options
- When you report such metric you report a different metric value for each dimension, e.g. the numberOfDroppedEvents for WebFrontEnd is 25 and for Orchestrator it’s 723
- If you think about it a metric with one dimension that can have 7 options is actually 7 different metrics that have the same name
- Even more - if the same metric has two dimensions one with 5 options and one with 3 options, there are 5 \* 3 combinations of dimensions which may result in 15 different actual metrics being reported

### Another example

<table><colgroup><col> <col> <col> <col> <col> <col> <col></colgroup><tbody><tr><td rowspan="1" colspan="7"><p><strong>com.honeyfy.publicapicommon.services.ApiMetricsService.api_access</strong></p></td></tr><tr><td rowspan="1" colspan="1"><p><strong>API /</strong></p><p><strong>Method</strong></p></td><td rowspan="1" colspan="1"><p><strong>calls</strong></p></td><td rowspan="1" colspan="1"><p><strong>media</strong></p></td><td rowspan="1" colspan="1"><p><strong>library/folders</strong></p></td><td rowspan="1" colspan="1"><p><strong>scorecards</strong></p></td><td rowspan="1" colspan="1"><p><strong>users</strong></p></td><td rowspan="1" colspan="1"><p><strong>workspaces</strong></p></td></tr><tr><td rowspan="1" colspan="1"><p><strong>post</strong></p></td><td rowspan="1" colspan="1"><p><strong>187</strong></p></td><td rowspan="1" colspan="1"></td><td rowspan="1" colspan="1"></td><td rowspan="1" colspan="1"><p><strong>5</strong></p></td><td rowspan="1" colspan="1"></td><td rowspan="1" colspan="1"></td></tr><tr><td rowspan="1" colspan="1"><p><strong>get</strong></p></td><td rowspan="1" colspan="1"></td><td rowspan="1" colspan="1"><p><strong>15</strong></p></td><td rowspan="1" colspan="1"><p><strong>51</strong></p></td><td rowspan="1" colspan="1"></td><td rowspan="1" colspan="1"><p><strong>394</strong></p></td><td rowspan="1" colspan="1"><p><strong>70</strong></p></td></tr><tr><td rowspan="1" colspan="1"><p><strong>put</strong></p></td><td rowspan="1" colspan="1"></td><td rowspan="1" colspan="1"><p><strong>126</strong></p></td><td rowspan="1" colspan="1"></td><td rowspan="1" colspan="1"></td><td rowspan="1" colspan="1"><p><strong>7</strong></p></td><td rowspan="1" colspan="1"></td></tr></tbody></table>

In this example although the overall number of possible dimensions is 6\*3=18 only 8 of them are actually populated, which means that Datadog will charge us for only 8 metrics and not 18

- By default the Gong metrics infrastructure, when reporting a metric to DD assigns every metrics additional three dimensions:
	- context - e.g. Orchestrator, RecordingSupervisor, etc.
		- ec2id - the id of the ec2 instance reporting the metric, e.g. i-0b1ad76e98ee2a45e
		- build - the build number of the component reporting the metric, e.g. a062319
- When reporting the same metric to ES additional dimension are added (e.g. host, type)

## Monitored vs. Explorative Metrics

- The metrics we collect can be categorized into two categories:
	- Monitored metrics are metrics you plan to set up alerts for as the expected behavior is within a certain range and it is important for us to know when the value is outside the expected range
		- Explorative metrics are metrics for which there is no need to setup an alert but might be useful to track patterns and helpful to troubleshoot incidents specifically trying to correlate historical trends to an issue
- When you create a metric you define if you want it to be monitored by setting *isMonitored* to *true* otherwise it’s explorative
- In our environment monitored metrics are collected in both DD and ES while explorative metrics are collected only in ES
- Since DD has better graphing and dashboarding capabilities people sometimes choose to define their metric as monitored although there is no alert set for it
- Similarly, when people want to graph an explorative metric along with a monitored metric in the same dashboard they tend to make it monitored too

## Naming a Metric

- A metric name should be a dot separated string
- Since all metrics are collected in the same container we need a convention that will keep our metrics’ names unique
- To assure that, use the dotted notation of the class owning the metric for the name prefix.
- Then continue with dot separated hierarchical name
- For example the count of total events in the `libbeat` output stats defined in class `FileBeatMetrics` will be called: `com.honeyfy.datadog.filebeat.FileBeatMetrics.stats.libbeat.output.events.total`

**Important Note**: Our current naming method relying on the class name is somewhat error-prone: renaming the class will affect the metric name, which means that if you set an alert over it that metric it will never be triggered any more.  
To solve this, prefer hard-coding the metric name as a string (full class name in most cases) instead of using an api to retrieve it.

## Pricing: Datadog vs. OpenSearch

- The average cost of a metric in DD is about $0.1 while in ES it’s about $0.0000015 (1:67,000 ratio)
- Datadog pricing is also based on the number of **used combinations of dimensions** - each combination is considered another metric
- Try to avoid defining a metric as monitored if its only use is explorative
- For monitored metrics try to avoid the usage of high cardinality dimensions, with explorative metrics feel free to use as many dimensions and dimension values as you need
- Please note that due to the higher price some built-in metric dimensions are reported only to ES and are not reported to DD
- You can use Kibana to explore and graph the explorative metrics - just choose the **metrics.production.\*** index pattern in the Kibana of [Metrics & Logs](https://search-gong-logs-gpjfnlubodjfs5flnx5n6e2gcy.us-east-1.es.amazonaws.com/_plugin/kibana/goto/7436f18d2cef97e999ab4e5808eaf064 "https://search-gong-logs-gpjfnlubodjfs5flnx5n6e2gcy.us-east-1.es.amazonaws.com/_plugin/kibana/goto/7436f18d2cef97e999ab4e5808eaf064")
- For deeper analysis of metrics considerations see: [Metrics: Reporting Exploring and Alerting](https://gongio.atlassian.net/wiki/spaces/EN/pages/142671941 "https://gongio.atlassian.net/wiki/spaces/EN/pages/142671941") in Confluence

## Aggregated Metrics

### The DropWizard Library

- The preferred way for collecting and reporting Metrics’ values is to use the DropWizard metrics library with the Gong wrappers
- The DropWizard library supports 5 types of metrics: **Counter**, **Meter**, **Gauge**, **Timer** and **Histogram**.
- DropWizard hosts your metrics values in memory (in what they call the Metrics Registry) the Gong wrapper is running a scheduled task once a minute that collects the values of all the metrics and reports them via Kafka to ES and DD
- `HoneyfyMetricsRegistry` - is the Gong wrapper to the DropWizard registry and provides methods for registering and unregistering metrics
- More about the various types of metrics in a few slides

### Creating a Metric

- `HoneyfyMetricsRegistry` contains numerous methods for metric creation, the preferred ones are the ones prefixed with *autoCloseable*, e.g. `HoneyfyMetricsRegistry.autoCloseableGauge(isMonitoringEnabled, threadPoolExecutor::getPoolSize, PeriodicMetricsCollectionService.class, "executor", "threads", "count")`
- These methods register the metric you request in the Metrics Registry and return a closable metric.
- The methods also allow to add dimensions to the registered metric
- Some of the methods also allow you to determine if the metric is monitored (reported to DD and ES) or explorative (reported only to ES)

### Updating a Metric

- Each type of metric has its own method(s) for updating its value, e.g. Counter metric has `inc()` and `dec()` methods to increment/decrement its value
- Calling these methods when the appropriate event occurs allows you to collect the data you need
- All the updates are done in memory and the result is sampled every minute and sent to DD and ES (that’s why they’re called aggregated)
- You can update the metric as long as it’s opened once you close it the metric should not be updated any more

### Closing a Metric

- The `close()` method of the metric **marks it for removal** from the registry and the metric will be removed as soon as its last value is reported
- Once the metric is removed from the registry its value is not reported any more
- If a metric is not updated but remains registered its latest value will be reported in each reporting interval
- **Please refrain from** frequently opening and closing your metrics. There used to be a practice of opening a counter incrementing it and immediately closing it in order to measure the rate of events, this practice is generating a lots of noise in the metrics backend and is bound to fail once the open-close rate crosses some arbitrary threshold
- Normally a metric should be opened before its first use and closed after its last use
	- Many metrics are opened at init time and closed when the process closes

## Types of metrics in Gong

### Choose the Right Metric For Your Needs

- Although Dropwizard supports 5 types of metrics we’ll discuss only four of them here.
- For discussion about Histogram as well as more elaborated info about other metrics please refer to the [Dropwizard documentation](https://metrics.dropwizard.io/4.2.0/manual/core.html "https://metrics.dropwizard.io/4.2.0/manual/core.html")

### The Gong Periodic Counter

- A periodic counter is a Gong implementation of the DropWizard counter, which is more useful
- Use this petric to count the number of occurrences of an event **per reporting interval** (1 minute)
- This counter resets back to zero when its value is reported making it an events-per-minute counter (or rate meter)
- Use the `inc()` and `dec()` methods to increment / decrement its value
- Use its *count* field to get its value
- Use `HoneyfyMetricsRegistry.autoCloseablePeriodicCounter()` to create such counter
- Periodic counters are shown with type COUNTER in OpenSearch

### Dropwizard Counter

- Use this metric to count the number of occurrences of events in your system (e.g. number of emails processed, number of calls recorded, etc.)
- The Dropwizard counter is **continuous** and keeps counting from its creation until its close
- Use the `inc()` and `dec()` methods to increment / decrement its value
- Use its *count* field to get its value
- To create a native Dropwizard counter use: `HoneyfyMetricsRegistry.autoCloseableContinuousCounter()`
- Continuous counters are shown with type COUNTER in OpenSearch
- Please mind that its ever growing nature makes it less useful for graphs hence you may usually prefer the Gong periodic counter
- In the past people used to open->increment->close a Dropwizard counter to achieve rate counting but this method is failing when used in high frequencies and reports incorrect data - if you see such implementations replace them with Gong periodic counter

### Dropwizard Meter

- A meter is mainly used to measure the **rate** of events per time unit - in our setup it’s events per second.
- A meter has only one method: *mark()*, which marks the occurrence of the event that its occurrence rate is measured
- For meter, Dropwizard calculates 4 fields:
	- *count* - the overall number of calls to mark() since the meter’s creation
		- *1MinuteRate* - the rate per second of calling mark() over the last minute
		- *5MinuteRate* - the rate per second of calling mark() over the last 5 minutes
		- *15MinuteRate* - the rate per second of calling mark() over the last 15 minutes
- All 4 fields are available in ES, however only *count* and *1MinuteRAte* are available in DD
- Use `HoneyfyMetricsRegistry.autoCloseableMeter()` to create your meters
- Meters are shown with type METER in OpenSearch

### Dropwizard Timer

- A timer is used to calculate both the rate and the time histogram of an operation
- Please refer to the Dropwizard documentation for farther explanation
- All the fields of timer are reported to ES but only *max*, *min*, *mean*, *count* and *1MinuteRate* are reported to DD
- Use `HoneyfyMetricsRegistry.autoCloseableTimer()` to create your timers
- Timers are shown with type TIMER in OpenSearch

### Dropwizard Gauge

- A gauge is actually a callback method implemented by you that returns a number
- The callback is called by `Dropwizard` and its Gong wrapper every minutes and its return value is reported to both ES and DD
- The gauge’s *value* is the only field and could be found in both ES and DD
- Use `HoneyfyMetricsRegistry.autoCloseableGauge()` to create your gauges
- Gauges are shown with type GAUGE in OpenSearch

## Handling Dynamic Dimensions

- As you can see, in the metric creation api, when creating a metric you also need to provide its dimensions and the selected option for each dimension
- Sometimes the dimensions assigned to a metric are not pre defined and may be dynamically created and destroyed in runtime
- In such cases you may want to use:
	- `DimensionalCountersCache`*,* `DimensionalMetersCache` or `DimensionalTimersCache` for dynamic dimensions with limited lifetime
- For each one of them you can select (by choosing the appropriate constructor) if you want to limit the cache and what policy to use for cache eviction
- Upon eviction from the cache the metric’s *close()* method is automatically called

#### Code sample (size limited counters cache)

```
class SomeBeanClass implements AutoCloseable {

  private final DimensionalCountersCache counters = new DimensionalCountersCache(

      true, 

      "counts", 

      "com.honeyfy.SomeBeanClass", 

      Optional.of(10), 

      Optional.empty()

  );

  public usage() {

    Map<String, String> dimensions = 

      ImmutableMap.of("dim1", "val1", "dim2", "val2", ...);

    counters.get(dimensions).inc();

  }

  public void close() {

    Robust.tryAndLog(counters::close, "Failed...", logger::warn);

  }

}
```

#### Code sample (counters are deleted after 10 minutes of no-usage)

```
class SomeBeanClass implements AutoCloseable {

  private final DimensionalCountersCache counters = new DimensionalCountersCache(

      true, 

      "counts", 

      "com.honeyfy.SomeBeanClass", 

      Optional.empty(),

      Optional.of(Duration.ofMinutes(10))

  );

  public usage() {

    counters.get(ImmutableMap.of("dimension1", "value1", "dimension2", "value2"))

    .inc();

  }

  public void close() {

    Robust.tryAndLog(counters::close, "Failed...", logger::warn);

  }

}
```

## Scattered Metrics Reporting in Gong

### com.honeyfy.monitoring.metrics.MetricsConsumer

- `MetricsConsumer` is an interface with one method: `sendBlocking()` - the method receives a list of measurements and reports them forward depending on implementation.
- Currently you should use one of the following implementations
	- `KafkaNonMonitoredMetricsConsumer` - reports your metrics only to OpenSearch
		- `KafkaMonitoredMetricsConsumer` - reports your metrics to both OpenSearch and Datadog
		- `KafkaMetricsConsumer` - metric is treated as either monitored or non-monitored according to some complicated legacy logic
- There are additional `MetricsConsumer` implementations, please refrain from using them unless you understand exactly what you’re doing
- To report your metrics through `MetricsConsumer` you should collect them in a list of structure called Measurement and pass the list to `sendBlocking()`
- The whole list of measurements you provide is sent, **immediately**, to Kafka and from there it’s transmitted by `MetricsStreamer` to OpenSearch and Datadog
- The metric value you provide is reported as is to ES and DD
- Metrics reported by `MetricsConsumer` are shown with type MEASUREMENT in OpenSearch

### The Measurement structure

- `com.honeyfy.monitoring.metrics.PeriodicallySampledMetric.Measurement` contains the following fields
	- `name` - the name of the metric according to the metric naming conventions
		- `value` - *Number* representing the value of the metric
		- `dimensions` - name value pairs of the dimensions associated with the metric and their value in a `Map<String, String>` format (key = name, value = value)
		- `timestamp` - an *Instant* representing the time when the metric had the value

### Replacing Scattered Metric With Aggregated Metric

- Scattered metrics (reported by `MetricsConsumer`) may be a less efficient way to monitor your application
- For instance sending a measurement every time an event happens just to later count in Datadog the amount of events per minute may generate lots of traffic to Datadog
- Instead you can simply use a Counter (preferably `PeriodicCounter`) which sends only one event per minute and provides the same level of monitoring
- A reason to use scattered metrics is when you need to report individual values in a frequent manner and cannot wait for them to aggregate and deliver periodically
- Another reason may be that you want to perform the aggregation yourself and send the metric in a specific point in time w/o waiting for the reporting interval to expire
- [Metrics: Reporting Exploring and Alerting](https://gongio.atlassian.net/wiki/spaces/EN/pages/142671941 "https://gongio.atlassian.net/wiki/spaces/EN/pages/142671941") in Confluence can also help to decide if scattered or aggregated metrics are a better solution for your case

## Testing Metrics in Development Environment

==Currently not supported.==

## Datadog Tips

Click on the link to listen to the training

## Metrics in Coralogix

Metrics are also making their way into Coralogix (instead of OpenSearch previously).