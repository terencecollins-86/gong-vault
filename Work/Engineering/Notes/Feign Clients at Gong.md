---
title: Feign Clients at Gong
tags:
  - feign
  - java
  - http
  - service-to-service
  - rest
  - cheatsheet
created: 2026-07-20
aliases:
  - feign
  - feign client
  - service client
---

# Feign Clients at Gong

> [!note] TL;DR
> Feign is Gong's standard pattern for synchronous service-to-service HTTP calls. You define a shared Java interface (the contract), annotate it with Spring MVC annotations, and both the server controller and the client implement/extend it. Boilerplate is gone; type safety is compile-time. Source of truth: `gong-ai4dev/docs/java/patterns/feign-clients.md`.

---

## Feign vs Kafka — when to use which

| Situation | Use |
|---|---|
| Async, fire-and-forget ("this happened") | **Kafka** |
| Need a response in the same call flow | **Feign** |
| High-throughput / bulk processing | **Kafka** |
| Need replay or audit trail | **Kafka** |
| Cross-service read (get user, get account) | **Feign** |
| One service notifying many others | **Kafka** |
| Sub-millisecond low-latency internal call | **Direct method / Feign** |

---

## Three-module architecture

Every Feign integration has three pieces:

```
gong-clients (or honeyfy/BackendClients)
└── <Domain>Common/
    ├── <Domain>Api/       ← contract: interface + DTOs
    └── <Domain>Client/    ← @FeignClient declaration + config

gong-{service}/
└── rest/
    └── {Service}Controller.java   ← @RestController implements <Domain>Api
```

**Repository selection:**

| Where do consumers live? | Use |
|---|---|
| All in `gong-*` subsystem repos | `gong-clients` (preferred) |
| Any consumer is in `honeyfy` monorepo | `honeyfy/BackendClients` (avoids circular dep) |

**One parent module per business domain** — don't create a new `<Domain>Common/` if the domain already has one. Check first with `ls gong-clients/`.

**Maven groupId** (pom.xml only — Java packages are the same regardless):
- `gong-clients` → `com.honeyfy.backend.clients`
- `BackendClients` → `com.honeyfy.clients`
- Java packages in `.java` files → always `com.honeyfy.backend.clients.<domain>`

---

## API interface

```java
// <Domain>Api/src/main/java/com/honeyfy/backend/clients/<domain>/<Service>Api.java
public interface TranslationApi {
    String BASE_PATH = "/translation";
    String TRANSLATE = BASE_PATH + "/translate";

    @PostMapping(TRANSLATE)
    TranslationResultDto translate(
        @RequestBody TranslationRequestDto request,
        @RequestParam(name = "company-id") long companyId
    );

    @GetMapping(BASE_PATH + "/status")
    Optional<TranslationStatusDto> getStatus(
        @RequestParam(name = "request-id") String requestId
    );
}
```

Rules:
- Use Spring MVC annotations (`@GetMapping`, `@PostMapping`, etc.) — not Feign-specific ones.
- Parameter names in `@RequestParam(name = "...")` use **kebab-case**.
- Use `Optional<T>` for "may not exist" responses — never `ResponseEntity<T>`.
- Key by `companyId` as `@RequestParam(name = "company-id") long companyId`.

---

## Client declaration

```java
// <Domain>Client/src/main/java/com/honeyfy/backend/clients/<domain>/TranslationClient.java
@IntrospectableFeignClient(remoteServerRole = GongAppRole.TranslationService)
@FeignClient(
    value = "translation-client",
    fallbackFactory = TranslationClient.TranslationClientFallbackFactory.class
)
public interface TranslationClient extends TranslationApi {

    @Component
    class TranslationClientFallbackFactory implements FallbackFactory<TranslationClient> {
        @Override
        public TranslationClient create(Throwable cause) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                cause.getMessage(), cause);
        }
    }
}
```

---

## Client configuration

```java
@Configuration
@Import({FeignConfigurer.Beans.class})
public class TranslationClientConfig {

    public static final String TRANSLATION_CLIENT_BEAN = "translationClient";
    public static final String TRANSLATION_CLIENT_CONFIG = "translationClientConfig";

    @Bean(name = TRANSLATION_CLIENT_CONFIG)
    public BaseClientSettings translationClientSettings() {
        return BaseClientSettings.builder()
            .properties(BaseClientSettings.Properties.builder()
                .useNewErrorDecoder(true)   // required for custom ContractException propagation
                .build())
            .build();
    }

    @Bean(name = TRANSLATION_CLIENT_BEAN)
    public TranslationApi translationClient(
            FeignConfigurer feignConfigurer,
            @Qualifier(TRANSLATION_CLIENT_CONFIG) BaseClientSettings settings) {
        return feignConfigurer.defaultClient(
            TranslationClient.class, settings, GongAppRole.TranslationService);
    }
}
```

Inject the **API interface** (not the client class) in consumers:
```java
@Autowired
@Qualifier(TranslationClientConfig.TRANSLATION_CLIENT_BEAN)
private TranslationApi translationApi;
```

---

## Server controller

```java
@RestController
public class TranslationController implements TranslationApi {

    private final TranslationService service;

    @Override
    public TranslationResultDto translate(TranslationRequestDto request, long companyId) {
        return service.translate(request, companyId);
    }

    @Override
    public Optional<TranslationStatusDto> getStatus(String requestId) {
        return service.findStatus(requestId);
    }
}
```

Keep controllers thin — delegate all logic to the service layer.

---

## DTO decoupling (critical rule)

**API DTOs must be separate from internal entities.** Never reuse `@Entity` or internal model classes as Feign API return types — accidental field leakage has caused P0 incidents.

```java
// GOOD — dedicated API DTO in the Api module
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class TranslationResultDto {
    private String translatedText;
    private String sourceLanguage;
    // only fields that are part of the contract
}

// GOOD — manual field-by-field mapping in controller
@Override
public TranslationResultDto translate(TranslationRequestDto req, long companyId) {
    TranslationResult result = service.translate(req.getText(), companyId);
    return TranslationResultDto.builder()
        .translatedText(result.getText())
        .sourceLanguage(result.getDetectedLanguage())
        .build();
}
```

**NEVER use automated mappers** (MapStruct, ModelMapper, `BeanUtils.copyProperties()`). They copy all fields including new internal ones you didn't mean to expose.

---

## Error handling

### "Not found" → `Optional<T>`

```java
// interface
Optional<UserDto> findUser(@RequestParam(name = "id") long id);

// consumer
Optional<UserDto> user = userApi.findUser(id);
user.ifPresentOrElse(this::processUser, this::handleNotFound);
```

### Standard HTTP errors → `ResponseStatusException` + catch `FeignException`

```java
// server throws
throw new ResponseStatusException(HttpStatus.NOT_MODIFIED);

// consumer catches
try {
    ResourceDto r = api.getResource(id, etag);
} catch (FeignException e) {
    if (e.status() == 304) { return cachedValue; }
    throw e;
}
```

### Business logic exceptions → `ContractException` (HTTP 517 round-trip)

Use this when you need a typed exception to cross the service boundary (e.g. validation failure).

**6-piece pattern:**

1. Exception extends `ContractException`:
```java
@Getter
public class TranslationFailedException extends ContractException {
    private final String reason;
    public TranslationFailedException(String reason) { this.reason = reason; }
}
```

2. API interface declares `throws`:
```java
TranslationResultDto translate(...) throws TranslationFailedException;
```

3. Client config sets `useNewErrorDecoder(true)` (shown above).

4. Server `@ControllerAdvice` returns HTTP **517**:
```java
@ControllerAdvice(assignableTypes = {TranslationController.class})
public class TranslationExceptionHandler extends ResponseEntityExceptionHandler {
    @ExceptionHandler(TranslationFailedException.class)
    protected ResponseEntity<Object> handle(TranslationFailedException e) {
        return ResponseEntity
            .status(BaseClientErrorDecoder.GONG_INTERNAL_ERROR)  // 517
            .body(new FeignContractExceptionWrapper(e));
    }
}
```

5. Controller converts internal → API exception:
```java
@Override
public TranslationResultDto translate(...) throws TranslationFailedException {
    try {
        return service.translate(request, companyId);
    } catch (InternalTranslationException e) {
        throw new TranslationFailedException(e.getMessage());
    }
}
```

6. Consumer catches the typed exception directly:
```java
try {
    TranslationResultDto result = translationApi.translate(req, companyId);
} catch (TranslationFailedException e) {
    throw new BadRequestException(e.getReason());
}
```

Flow: consumer → Feign → HTTP → server → HTTP 517 + `FeignContractExceptionWrapper` → `BaseClientErrorDecoder` deserialises → consumer gets typed `TranslationFailedException`.

---

## Adding methods to an existing deployed interface (A→B→C order)

**Never add `@Override` before the interface is published.** The three-step order prevents compile errors and runtime failures:

| Step | PR target | What changes | `@Override`? |
|---|---|---|---|
| **A** | Server repo | Add method implementation to controller | ❌ No |
| **B** | `gong-clients` | Add method to the Api interface; publish artifact | — |
| **C** | Server + consumers | Add `@Override`; update consumers | ✅ Yes |

Deploy A, wait for it to be live. Then merge B. Then deploy C.

---

## Testing with WireMock

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@ActiveProfiles(HoneyfySpringProfiles.TEST)
@ContextConfiguration(classes = TranslationClientTest.Ctx.class)
@AutoConfigureWireMock
@DirtiesContext
public class TranslationClientTest extends AbstractTestNGSpringContextTests {

    private static final ObjectMapper MAPPER = new ObjectMapper()
        .registerModule(new Jdk8Module())
        .registerModule(new JavaTimeModule());

    private static final long COMPANY_ID = 123L;

    @Autowired @Qualifier(TranslationClientConfig.TRANSLATION_CLIENT_BEAN)
    private TranslationApi api;

    @Autowired
    private WireMockServer wireMockServer;

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry r) {
        r.add(FeignUrlSupplier.resolveUrlProperty(GongAppRole.TranslationService),
              () -> "http://localhost:${wiremock.server.port}");
    }

    @BeforeMethod(groups = "basic")
    public void setUp() { wireMockServer.resetAll(); }

    @Test(groups = "basic")
    public void testTranslate() throws Exception {
        TranslationResultDto mock = TranslationResultDto.builder()
            .translatedText("Bonjour").sourceLanguage("en").build();

        wireMockServer.stubFor(post(urlPathEqualTo("/translation/translate"))
            .withQueryParam("company-id", equalTo(String.valueOf(COMPANY_ID)))
            .willReturn(aResponse()
                .withHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .withStatus(200)
                .withBody(MAPPER.writeValueAsString(mock))));

        // Lambda capture pattern — local vars can't be reassigned in lambdas
        final TranslationResultDto[] result = new TranslationResultDto[1];
        Tenant.executeForCompany(COMPANY_ID, () ->
            result[0] = api.translate(new TranslationRequestDto("Hello", "fr"), COMPANY_ID));

        assertThat(result[0].getTranslatedText()).isEqualTo("Bonjour");
    }

    @Import({TranslationClientConfig.class})
    public static class Ctx {}
}
```

**Critical WireMock rules:**
- Always `wireMockServer.resetAll()` in `@BeforeMethod`.
- `@DirtiesContext` is mandatory — no context sharing between test classes.
- Wrap client calls in `Tenant.executeForCompany(companyId, ...)`.
- Use `final T[] result = new T[1]` to capture lambda results (local vars can't be reassigned).
- Register `Jdk8Module` + `JavaTimeModule` on ObjectMapper.

---

## Pros and cons

### Pros

**Type safety across service boundaries.** The Api interface is a shared compile-time contract — if the server removes a method or changes a signature, the build breaks before you ship.

**Zero HTTP boilerplate.** No `RestTemplate.exchange(...)`, no URL string building, no response body extraction. Call the interface method like a local function.

**Contract-first design.** The Api module forces you to think about what you're exposing before you write implementation code. DTOs are explicit, not accidental.

**Familiar Spring MVC annotations.** `@GetMapping`, `@PostMapping`, `@RequestParam` — the same annotations you use writing controllers. No new annotation vocabulary.

**Clean testability.** In unit tests, mock the Api interface with Mockito. In integration tests, stub with WireMock. No need to spin up a real server.

**Resilience built in.** `FallbackFactory` + Hystrix/Resilience4j circuit breaker wires naturally to the client. Fallback logic is co-located with the client.

**DTO isolation prevents leakage.** Explicit mapping from internal entities to API DTOs means internal model changes don't accidentally appear in downstream services.

### Cons

**Synchronous only.** Feign blocks the calling thread waiting for a response. For fire-and-forget, high-throughput, or fanout scenarios Kafka is the right tool.

**Three-step deployment for interface changes.** Adding a method to an existing deployed interface requires A→B→C across multiple PRs and deployments. Easy to get wrong under time pressure.

**Distributed failure surface.** A network timeout or 5xx from the downstream service becomes your problem. Must handle `FeignException` and circuit-breaker open states explicitly.

**HTTP overhead.** Each call is an HTTP round-trip — serialise, network, deserialise. For tight inner-loop calls (e.g. called thousands of times per request) this is measurable latency.

**ContractException plumbing is verbose.** The six-piece custom exception pattern (exception class, API throws declaration, config flag, `@ControllerAdvice`, controller catch+rethrow, consumer catch) is a lot of boilerplate for typed errors across boundaries.

**Client repo placement decision adds friction.** Having to decide `gong-clients` vs `honeyfy/BackendClients` and check for existing domain parents before every new client is a cognitive step that trips up people new to the codebase.

**`@IntrospectableFeignClient` + service discovery must match.** The `remoteServerRole` in `@IntrospectableFeignClient` drives URL resolution. Wrong role → wrong URL → silent routing failure in staging.

---

## Gotchas

**Never put `@Override` before the Api interface declares the method.** Step A (server) adds the method without `@Override`. Step B publishes the interface. Step C adds `@Override`. Swap the order and you get a compile error.

**Inject the Api interface, not the Client class.** `@Qualifier` + the Api type keeps your code decoupled from Feign. If the transport ever changes, the consumer doesn't care.

**`useNewErrorDecoder(true)` must be set for ContractException propagation.** Without it, HTTP 517 responses come back as generic `FeignException` and you lose the typed exception.

**`@ControllerAdvice` must be scoped to the specific controller.** Using `assignableTypes = {MyController.class}` prevents the advice from accidentally catching exceptions from other controllers in the same JVM.

**DTOs in the Api module only.** Never import an `@Entity` or internal model into the Api module — it pulls in the whole persistence stack as a transitive dependency.

**Don't share a database across service boundaries.** If Service A needs data owned by Service B, call Service B's Feign client. Never add a DAO that reaches into Service B's database directly.

---

## See also

- [[Kafka at Gong]] — async alternative; the "Kafka vs Feign" decision table
- `gong-ai4dev/docs/java/patterns/feign-clients.md` — full canonical patterns doc (DTO decoupling, error handling, deployment order)
- `gong-ai4dev/docs/java/patterns/feign-client-testing.md` — WireMock test patterns
- `gong-clients/TranslationCommon/` — canonical real-world example (Api + Client + Config)
- [[gong-java-cheat-sheet]] — general Java patterns
