# Gong Java Developer Cheat Sheet

Quick reference for common utility classes and patterns across the Gong (Honeyfy) codebase.

---

## 1. User / Auth Context

### `CurrentUser` — primary entry point for WebAPI services
**Package**: `com.honeyfy.usersminiapp.util`
**Module**: `honeyfy/UsersMiniApp`

All methods are static. Use `currentUserDetails()` as the preferred approach.

```java
CurrentUser.currentUserDetails()         // → LoggedInAppUser (preferred)
CurrentUser.isLoggedIn()                 // → boolean
CurrentUser.isGlobalAdministrator()      // → boolean
CurrentUser.isTechAdminAndNotAvatar()    // → boolean
CurrentUser.isTeamLeader()              // → boolean
CurrentUser.userTeamAndSelf()           // → Set<Long> (self + direct reports)
CurrentUser.getMyTeamLeaderId()         // → Optional<Long>
CurrentUser.getCurrentUserBasic()       // → IGongUserBasic

// Legacy — prefer currentUserDetails()
CurrentUser.getAppUser()                // → AppUser (deprecated)
CurrentUser.loggedInAppUserIfExists()   // → LoggedInAppUser (nullable, deprecated)
```

---

### `GongUserAuthUtils` — low-level principal access (backend/non-WebAPI services)
**Package**: `com.honeyfy.websecurity.servletauthutils`
**Module**: `gong-infra-core/WebSecurity`

Sits directly on Spring's `SecurityContextHolder`. Use in services that don't depend on `UsersMiniApp`.

```java
GongUserAuthUtils.getAuthenticatedGongUserId()               // → long (throws if unauthenticated)
GongUserAuthUtils.getAuthenticatedGongUserFullName()         // → String
GongUserAuthUtils.getUserEmail()                             // → String
GongUserAuthUtils.getAuthenticatedGongAppUserPrincipal()     // → AuthenticatedGongUserPrincipal (nullable)
GongUserAuthUtils.getUserWhoLoggedInOnBehalfOfAuthenticatedUser()
    // → Optional<AuthenticatedGongUserPrincipal>  (impersonation/avatar)
GongUserAuthUtils.userWhoLoggedInOnBehalfOfAuthenticatedUserIncludingSelf()
    // → AuthenticatedGongUserPrincipal (nullable)
```

---

### `AuthenticatedGongUserPrincipal` — full principal interface
**Package**: `com.honeyfy.websecurity.servletauthutils`
**Module**: `gong-infra-core/WebSecurity`

Returned by `GongUserAuthUtils.getAuthenticatedGongAppUserPrincipal()`. Extends Spring's `UserDetails`.

```java
principal.getUserId()        // → long
principal.getCompanyId()     // → long
principal.getCompanyName()   // → String
principal.getUserEmail()     // → String
principal.getUserFirstName() // → String
principal.getUserLastName()  // → String
principal.getUserTitle()     // → String
principal.isAvatar()         // → boolean (impersonating another user)
principal.isImpersonated()   // → boolean
```

---

### `AppUser` — core user DTO
**Package**: `com.honeyfy.users.dto`
**Module**: `honeyfy/Users`
**Implements**: `IGongUserBasic`, `Serializable`

```java
appUser.getId()                   // → long (user ID)
appUser.getEmailAddress()         // → String
appUser.getFirstName()            // → String
appUser.getLastName()             // → String
appUser.getCompanyId()            // → long
appUser.getHomeWorkspaceId()      // → Long (nullable)
appUser.isAvatar()                // → boolean
appUser.shouldRecord()            // → boolean
appUser.hasGongConnect()          // → boolean
appUser.shouldSyncEmail()         // → boolean

// Test factory:
AppUser.forTest(id, email, firstName, lastName, companyId, homeWorkspaceId)
```

---

### `IGongUserBasic` — minimal user interface
**Package**: `com.honeyfy.websecurity.servletauthutils`
**Module**: `gong-infra-core/WebSecurity`

Implemented by both `AppUser` and `LoggedInAppUser`. Use when you only need identity basics.

```java
user.getId()                   // → long
user.getCompanyId()            // → long
user.getFirstName()            // → String
user.getLastName()             // → String
user.getFullName()             // → String (default: first + last)
user.getPrimaryEmailAddress()  // → String
user.getRoles()                // → List<String>
user.isAvatar()                // → boolean
```

---

## 2. Tenant / Company Context

### `SpecialCompanyIds` — internal company ID checks
**Package**: `com.honeyfy.appcommon.company`
**Module**: `gong-infra-core/SharedEntities`

Static utility for checking whether a company is internal to Gong. Use for dev-only code paths.

```java
SpecialCompanyIds.isGongDevCompany(companyId)
SpecialCompanyIds.isGongCompany(companyId)              // prod Gong company
SpecialCompanyIds.isAGongCompany(companyId)             // dev OR prod
SpecialCompanyIds.isGongDevOrOurTestingCompany(companyId)
SpecialCompanyIds.isGongOrOurTestingCompany(companyId)
SpecialCompanyIds.isSyntheticDemoCompany(companyId)
SpecialCompanyIds.isObjectEditingAllowedInDevOrTest(companyId)
SpecialCompanyIds.isSisense(companyId)
```

Named constants:
```java
SpecialCompanyIds.GONG_DEV_COMPANY_ID
SpecialCompanyIds.GONG_COMPANY_ID
SpecialCompanyIds.GONG_DEMO_COMPANY_ID
SpecialCompanyIds.GONG_GTM_WORKSPACE_ID
SpecialCompanyIds.GONG_RECRUITING_WORKSPACE_ID
SpecialCompanyIds.GONG_DEVELOPMENT_WORKSPACE_ID
```

> **Note**: Workspace ID is carried on `AppUser.getHomeWorkspaceId()` or passed as an explicit method parameter — there is no shared `WorkspaceContext` bean.

---

## 3. Feature Flags

### `FeatureFlagsClient` — preferred approach
**Package**: `com.honeyfy.clients.featureflag`
**Module**: `honeyfy/BackEndClients/FeatureFlagsApiCommon/FeatureFlagsClient`

Inject via `@Autowired`. Each service typically wraps this in its own `FeatureFlagsConfig` bean.

```java
featureFlagsClient.isEnabled(flagName, companyId)
featureFlagsClient.isEnabled(flagName, companyId, userId)
featureFlagsClient.isEnabled(flagName, companyId, Optional<Long> userId)
featureFlagsClient.isGA(flagName)      // globally available (all companies)
featureFlagsClient.isOff(flagName)     // explicitly disabled
featureFlagsClient.exists(flagName)    // flag is defined at all
featureFlagsClient.getFrontFacingEnabledFlags(currentUserCompanyId, selectedCompanyId, userId)
    // → Set<String>
```

**Recommended pattern** — define a per-service config wrapper:

```java
@Service
@RequiredArgsConstructor
public class FeatureFlagsConfig {

    private static final String MY_FLAG = "my-feature-flag-name";  // plain String constant

    private final FeatureFlagsClient featureFlagsClient;

    public boolean isMyFeatureEnabled(long companyId) {
        return featureFlagsClient.isEnabled(MY_FLAG, companyId);
    }
}
```

> **Deprecated**: `FeatureFlagService` + `FeatureFlagName` enum (`com.honeyfy.appcommon.featureflags`) — still present in older services; avoid in new code.

---

## 4. Feign / HTTP Clients

### `FeignConfigurer` — internal Feign client factory
**Package**: `com.honeyfy.base.client.config.configurer`
**Module**: `gong-infra-core/BaseClient`

Inject as `@Autowired FeignConfigurer feignConfigurer` (registered as `feignConfigurerV2` bean).

```java
// Standard internal client — URL resolved from GongAppRole:
MyServiceApi client = feignConfigurer.defaultClient(
    MyServiceApi.class,
    baseClientSettings,
    GongAppRole.MY_SERVICE_ROLE
);

// A/B gradual rollout between remote Feign and local implementation:
MyServiceApi client = feignConfigurer.gradualRolloutClient(
    rolloutSettings, MyServiceApi.class, remoteImpl, localImpl
);
```

**Standard wiring pattern**:

```java
@Configuration
@Import(FeignConfiguration.class)   // registers FeignConfigurer bean
public class MyServiceClientConfig {

    @Bean
    @ConfigurationProperties("my-service-client")
    public BaseClientSettings myServiceClientSettings() {
        return BaseClientSettings.builder().build();
    }

    @Bean
    public MyServiceApi myServiceApi(FeignConfigurer feignConfigurer,
                                     BaseClientSettings myServiceClientSettings) {
        return feignConfigurer.defaultClient(
            MyServiceApi.class, myServiceClientSettings, GongAppRole.MY_SERVICE
        );
    }
}
```

### `GongAppRole` — service registry enum
**Package**: `com.honeyfy.softwaredefinedtopology.config`
**Module**: `gong-infra-core/SharedEntities`

Central enum of all Gong services. Passed to `FeignConfigurer.defaultClient()` for environment-aware URL resolution (`BasicProperties.getCellName()` is used internally).

---

## 5. Permissions / Roles

### `GlobalRole` enum — company-level roles
**Package**: `com.honeyfy.permissions.domain`
**Module**: `honeyfy/Permissions`

```java
// Via CurrentUser (WebAPI services):
CurrentUser.isGlobalAdministrator()     // checks GlobalRole.GLOBAL_ADMIN
CurrentUser.isTechAdminAndNotAvatar()   // checks GlobalRole.TECH_ADMIN

// Via SecurityContext (any service):
GongUserAuthUtils.getAuthenticatedGongAppUserPrincipal()
    .getAuthorities().stream()
    .anyMatch(a -> a.getAuthority().equals("ROLE_TECH_ADMIN"));
```

Available authorities appear on `LoggedInAppUser.getAuthorities()` as `GrantedAuthority` (wrapped by `Authority` class, `com.honeyfy.websecurity.Authority`).

---

## 6. Environment / Cell Configuration

### `BasicProperties` — cell/environment config
**Package**: `com.honeyfy.util.config`
**Module**: `gong-infra-core/Util`

Inject via `@Autowired BasicProperties basicProperties`.

```java
basicProperties.getCellName()                  // → "us02", "eu01", etc.
basicProperties.getCellResidency()             // → "US", "EU"
basicProperties.getAwsAccount()                // → AWS account ID string
basicProperties.getAwsRegion()                 // → "us-east-1"
basicProperties.getAwsRegionDrp()              // → DR region
basicProperties.getAwsSharedServicesAccount()  // → shared-services account
basicProperties.getGongRootDomain()            // → "gong.io"
basicProperties.getSQSEndpoint()
basicProperties.getS3Suffix()
basicProperties.getS3SecondaryRegionSuffix()
```

---

## 7. Kafka / Event Publishing

### `GdmKafkaProducerHelper<K, V>` — generic Kafka producer utility
**Package**: `com.honeyfy.gdm.utils`
**Module**: `gong-data-lake/GdmCommon`

Wraps `KafkaTemplate`. Supports synchronous sends with optional timer metrics.

```java
// Single message:
gdmKafkaProducerHelper.syncSend(topic, value)
gdmKafkaProducerHelper.syncSend(topic, key, value)

// With timing metrics:
gdmKafkaProducerHelper.timedSyncSend(topic, value, timer)

// Batch:
gdmKafkaProducerHelper.syncSendList(topic, values)
gdmKafkaProducerHelper.timedSyncSendList(producerRecords, timer)
```

**Spring bean wiring**:

```java
@Bean
public GdmKafkaProducerHelper<String, MyEvent> myProducerHelper(
        KafkaTemplate<String, MyEvent> kafkaTemplate) {
    return new GdmKafkaProducerHelper<>(kafkaTemplate, MAX_BATCH_SIZE);
}
```

**Idiomatic pattern**: Each domain creates a dedicated `@Service` producer (e.g. `MyDomainEventPublisher`) that wraps `GdmKafkaProducerHelper` and exposes typed publish methods. Use `Robust.tryAndLog()` for safe fire-and-forget publishes.

---

## 8. Error Handling Utilities

### `Robust` — exception suppression with logging
**Package**: `com.honeyfy.util.flow`
**Module**: `gong-infra-core/Util`

Heavily used throughout the codebase for fire-and-forget operations where failures should not propagate.

```java
// Execute, log & swallow — returns null on failure:
R result = Robust.result(() -> riskyOperation(), "log message", logger, param);

// Execute void, log & swallow:
Robust.execute(() -> riskyVoidOperation());

// Wrap as exception-safe Runnable:
Runnable safe = Robust.wrap(() -> riskyOperation());

// Ensure exceptions are always logged (even if rethrown):
R result = Robust.ensureExceptionLogging(() -> riskyOperation(), logger);
```

**Common usage** — safe event publish:
```java
Robust.tryAndLog(() -> producer.send(event), "Failed to publish event", logger);
```

---

## 9. Common Types & Models

| Class | Package | Module | Purpose |
|---|---|---|---|
| `AppUser` | `com.honeyfy.users.dto` | `honeyfy/Users` | Core user DTO |
| `IGongUserBasic` | `com.honeyfy.websecurity.servletauthutils` | `gong-infra-core` | Minimal user interface |
| `AuthenticatedGongUserPrincipal` | `com.honeyfy.websecurity.servletauthutils` | `gong-infra-core` | Full Spring principal |
| `LoggedInAppUser` | `com.honeyfy.usersminiapp.springsecurity` | `honeyfy/UsersMiniApp` | Concrete principal wrapping `AppUser` |
| `CompanyType` | `com.honeyfy.appcommon.company` | `honeyfy/AppCommon` | Enum: company tier/kind |
| `GlobalRole` | `com.honeyfy.permissions.domain` | `honeyfy/Permissions` | Enum: global roles |
| `GongAppRole` | `com.honeyfy.softwaredefinedtopology.config` | `gong-infra-core` | Enum: all Gong services |
| `SpecialCompanyIds` | `com.honeyfy.appcommon.company` | `gong-infra-core` | Internal company ID constants/checks |
| `BasicProperties` | `com.honeyfy.util.config` | `gong-infra-core` | Cell/environment config bean |

---

## 10. Quick Lookup: Source Locations

| What you need | File path (relative to repo root) |
|---|---|
| Get current user | `UsersMiniApp/src/main/java/com/honeyfy/usersminiapp/util/CurrentUser.java` |
| Low-level principal | `gong-infra-core: WebSecurity/src/main/java/com/honeyfy/websecurity/servletauthutils/GongUserAuthUtils.java` |
| Feature flags client | `BackEndClients/FeatureFlagsApiCommon/FeatureFlagsClient/src/main/java/com/honeyfy/clients/featureflag/FeatureFlagsClient.java` |
| Feign client factory | `gong-infra-core: BaseClient/src/main/java/com/honeyfy/base/client/config/configurer/FeignConfigurer.java` |
| Service URL registry | `gong-infra-core: SharedEntities/src/main/java/com/honeyfy/softwaredefinedtopology/config/GongAppRole.java` |
| Cell/env config | `gong-infra-core: Util/src/main/java/com/honeyfy/util/config/BasicProperties.java` |
| Kafka send helper | `gong-data-lake: GdmCommon/src/main/java/com/honeyfy/gdm/utils/GdmKafkaProducerHelper.java` |
| Exception suppression | `gong-infra-core: Util/src/main/java/com/honeyfy/util/flow/Robust.java` |
| Internal company IDs | `gong-infra-core: SharedEntities/src/main/java/com/honeyfy/appcommon/company/SpecialCompanyIds.java` |
| Reference examples | `gong-app-samples` repo — `TroubleshootingFeignExample`, `TroubleshootingFeatureFlags` |
