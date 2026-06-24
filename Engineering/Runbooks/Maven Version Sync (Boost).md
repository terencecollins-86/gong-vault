---
tags:
- gong
- maven
- boost
- build
- runbook
created: 2026-06-24
---

# Maven Version Sync at Gong (Boost)

How Gong pins shared library versions at build time, how the `.mvn`
helper files fit together, and a FAQ of the sync issues that keep biting —
with the exact fix for each.

> **TL;DR** — Versions of shared Gong libs (`gong-clients`, `gong-infra-core`,
> `honeyfy`, …) are **not** hard-coded in poms. They live in version
> *properties* that the **boost-maven-plugin** resolves from DNS on every build
> and writes into `.mvn/maven.config`. That file is generated and gitignored —
> editing it by hand rarely sticks. Most "sync" errors are a property pointing
> at the wrong (or default `1.0-SNAPSHOT`) version, or a **stale local JAR**
> that no longer matches your source.

---

## The moving parts

Everything lives in the repo's `.mvn/` directory.

| File | Tracked? | Role |
|---|---|---|
| `extensions.xml` | ✅ git | Registers the **boost-maven-plugin** as a core Maven extension. This is what makes the sync happen. |
| `boost.properties` | ✅ git | Boost config: enable flag, DNS domain, the channel→property map, and exclusions. |
| `maven.config` | ❌ gitignored | **Generated.** Standard Maven file — its contents are prepended to every `mvn` command. Holds the resolved `-Dversion.*=…` pins. |
| `gong-shared-versions.properties` | ✅ git | Optional manual pins/overrides (usually commented out). |
| `wrapper/` | partial | Maven wrapper (`mvnw`) binaries/config. |

### `extensions.xml` — the engine

```xml
<extensions>
  <extension>
    <groupId>com.honeyfy.maven.plugins</groupId>
    <artifactId>boost-maven-plugin</artifactId>
    <version>17.main.40</version>
  </extension>
</extensions>
```

A **core extension** loads *before* the build starts — that's why Boost can
rewrite `maven.config` before Maven reads dependency versions.

### `boost.properties` — the config

```properties
boost.enabled = true
domain.lookup = builds.dev.gongio.net
lookup.property.names =\
  honeyfy.master:version.honeyfy,\
  gong-mongo-migration.main:version.gong.mongodb.migration,\
  gong-clients.main:version.gong.clients,\
  gong-checkstyle.main:version.gong.checkstyle,\
  gong-maven-plugins.main:version.gong.maven.plugins,\
  gong-infra-core.main:version.gong.infra.core
property.exclusion = version.gong.bom:…,version.honeyfy:…
```

- **`boost.enabled`** — master switch. `false` = Boost stops touching `maven.config`.
- **`domain.lookup`** — the DNS zone Boost queries for current versions.
- **`lookup.property.names`** — the heart of it: each entry maps a
  **build channel** (`gong-clients.main`) to a **Maven property**
  (`version.gong.clients`). Boost resolves the channel's latest version and
  writes `-Dversion.gong.clients=<resolved>` into `maven.config`.
- **`property.exclusion`** — properties Boost must **not** manage (you pin them yourself).

### `maven.config` — the output

```
-Dversion.gong.infra.core=STABLE
-Dversion.honeyfy=17.master.1.11706
-Dversion.gong.clients=17.main.1.10373
-Dversion.gong.mongodb.migration=STABLE
-T2C
```

Each `-Dversion.*` overrides the matching `${version.*}` placeholder used in
poms, e.g.:

```xml
<artifactId>IngesterTelephonySystemsSupervisorApi</artifactId>
<version>${version.gong.clients}</version>
```

`-T2C` = build with 2 threads per CPU core (unrelated to versions, just lives here).

---

## How a build resolves a version

```
mvn <goal>
   │
   ▼
boost-maven-plugin (core extension) loads
   │  reads boost.properties → for each channel:
   │  DNS lookup against builds.dev.gongio.net
   ▼
writes resolved -Dversion.*=… into .mvn/maven.config   ← OVERWRITES your edits
   │
   ▼
Maven reads maven.config as if typed on the CLI
   │
   ▼
${version.gong.clients} in poms → 17.main.1.10373
   │
   ▼
dependency pulled from .m2 (if present) else Artifactory
```

**Two independent things can go wrong**, and they look similar:

1. **Wrong version pinned** → property resolves to a value with no matching
   artifact (often the pom default `1.0-SNAPSHOT`). → *resolution* failure.
2. **Right version, stale artifact** → the JAR in `~/.m2` is older than your
   source / the published version. → *compile* or *NoClassDefFound* failure.

---

## Setting / overriding a version — the right way

Pick the row that matches your intent. **Do not just hand-edit `maven.config`** —
the next `mvn` run regenerates it.

| Goal | Do this |
|---|---|
| **Refresh to current** (let Boost re-resolve from DNS) | `mvn -N validate` — cheapest trigger; rewrites `maven.config`. |
| **Pin one lib permanently** | Add the property to `property.exclusion` in `boost.properties` (so Boost stops managing it), then set the value in `gong-shared-versions.properties` or `maven.config`. `boost.properties` is git-tracked → durable + shared. |
| **One-off override** | Pass `-Dversion.x=…` on the command line. CLI args beat `maven.config`; no file fight. |
| **Build against your local lib changes** | Build+install the lib first (`mvn -pl <Lib> -am install`), keep the dependent on the matching version, and rebuild it. See FAQ Q4. |
| **Stop all auto-rewriting** | `boost.enabled = false` in `boost.properties`. `maven.config` becomes yours alone (you now own keeping it correct). |

---

## FAQ — common sync issues & fixes

### Q1. I edited `.mvn/maven.config` and my changes got reset. What did that?

The **boost-maven-plugin**, not git. `maven.config` is gitignored
(`.gitignore: .mvn/maven.config`), so git never touches it. Boost regenerates
it from DNS on *every* `mvn` run — and an IntelliJ reimport/build runs Maven
too. Check the file's mtime: it bumps each build.

**Fix:** don't fight the file. Use the right channel above — exclusion +
tracked file for a durable pin, or `boost.enabled=false` to take full control.

---

### Q2. `Could not find artifact …:jar:1.0-SNAPSHOT in libs-release`

A `${version.*}` property resolved to **`1.0-SNAPSHOT`** — the pom *default*,
used when nothing overrides it. The artifact (e.g.
`IngesterTelephonySystemsSupervisorApi`) is a **published** lib that only
exists in Artifactory under a real version, so `1.0-SNAPSHOT` is never found.

Root cause is almost always `maven.config` holding
`-Dversion.gong.clients=1.0-SNAPSHOT` (hand-edited, or Boost couldn't reach DNS).

**Fix:** regenerate from DNS:

```bash
mvn -N validate -f <repo>/pom.xml
```

Then confirm `maven.config` shows a real version
(`-Dversion.gong.clients=17.main.1.xxxxx`) and rebuild.

> **Tell `1.0-SNAPSHOT` apart from a real version:** a published lib should
> never resolve to `1.0-SNAPSHOT`. Only *local reactor modules* legitimately
> carry `1.0-SNAPSHOT`. If a `…Api`/`…Client`/shared lib asks for
> `1.0-SNAPSHOT`, the property is wrong.

---

### Q3. `method X in class Y cannot be applied to given types` (or `NoSuchMethodError` / `NoClassDefFoundError` at startup)

A **stale JAR**. The version is fine, but the compiled artifact in `~/.m2`
predates your source. The compiler/runtime binds against the old class, whose
method signature (or class) differs from what the caller now expects.

This happens even for **local sibling modules** (`1.0-SNAPSHOT`): the dependent
reads the module from `~/.m2`, not the reactor, so an un-reinstalled edit is invisible.

**Diagnose** — compare source vs the installed jar:

```bash
# signature your source declares
grep -n "buildCreateEventForTs" <Module>/src/.../CallEventFactory.java

# signature actually compiled into the jar Maven will use
javap -classpath ~/.m2/repository/com/honeyfy/.../<Module>-1.0-SNAPSHOT.jar \
  com.honeyfy.telephony.callevent.common.CallEventFactory | grep buildCreateEventForTs

# mtimes: if the .java is newer than the .jar, the jar is stale
ls -la <Module>/src/.../CallEventFactory.java
ls -la ~/.m2/.../<Module>-1.0-SNAPSHOT.jar
```

**Fix** — rebuild + reinstall the module (and dependents):

```bash
mvn -pl <Module>,<Dependent> -am -DskipTests clean install -f <repo>/pom.xml
```

In IntelliJ, also do **Build → Rebuild Project** — otherwise the IDE compiles
against the same stale jar and you get the identical error.

---

### Q4. IntelliJ build fails but the terminal `mvn` build is fine (or vice-versa)

IntelliJ's Maven importer can resolve transitive deps via **parent-pom default
versions** instead of the Boost overrides, and it caches its own view of `.m2`.
CLI `mvn` reads `maven.config` (Boost-resolved) correctly. Result: IDE-only
compile errors on stale/old classes.

**Fix sequence:**
1. Make sure CLI is green first: `mvn -pl <Module> -am -DskipTests install`.
2. IntelliJ → **Maven panel → Reload All Maven Projects**.
3. **Build → Rebuild Project**.
4. If still wrong, remove the orphaned `.m2` entry for the lib and let it
   re-resolve; verify with `javap` before retrying.
5. As a clean-room alternative, launch from the CLI with a Maven-generated
   classpath instead of IntelliJ's (see [[#Appendix — CLI launch that bypasses IntelliJ]]).

---

### Q5. Boost can't reach DNS (offline / VPN off)

`builds.dev.gongio.net` lookups fail → Boost may write defaults
(`1.0-SNAPSHOT`) or leave a partial `maven.config`, cascading into Q2/Q3.

**Fix:** reconnect to VPN, then `mvn -N validate` to re-resolve. If you must
work offline, set `boost.enabled=false` and pin known-good versions manually in
`maven.config`.

---

### Q6. `dependency:tree` doesn't show anything useful

The Gong Maven extension suppresses some plugin execution output, which can
blank out `dependency:tree`. Diagnose via the resolved properties and the raw
`.m2` cache state instead:

```bash
cat .mvn/maven.config                    # what versions are actually pinned
ls ~/.m2/repository/com/honeyfy/.../      # which versions are present locally
javap -classpath <jar> <FQCN>             # what a specific jar actually contains
```

---

## Quick decision tree

```
Build/run fails on a Gong lib
│
├─ "Could not find artifact …:1.0-SNAPSHOT"  → Q2  (wrong version pinned → mvn -N validate)
│
├─ "cannot be applied to given types" /
│  NoSuchMethodError / NoClassDefFoundError   → Q3  (stale jar → clean install -pl … -am)
│
├─ Works in terminal, fails in IntelliJ
│  (or reverse)                               → Q4  (reload + rebuild project)
│
├─ maven.config keeps reverting               → Q1  (Boost regenerates it; use exclusion / disable)
│
└─ Everything fails after going offline       → Q5  (VPN, then mvn -N validate)
```

---

## Appendix — CLI launch that bypasses IntelliJ

When IntelliJ's resolver is the problem, run the app from a Maven-generated
classpath so you get the correctly-pinned jars:

```bash
cd <repo>
mvn -pl <Module> -am -DskipTests install \
  dependency:build-classpath -Dmdep.outputFile=<Module>/target/classpath.txt -q

java -Dspring.profiles.active=<profiles> \
  -cp "<Module>/target/classes:$(cat <Module>/target/classpath.txt)" \
  <main.class>
```

---

## See also

- [[Comms Capture Maven Modules]]
- `gong-module-runner/CLAUDE.md` — local build → container → restart loop
