# agents.md — WSO2 API Platform

## Product Overview

WSO2 API Platform is an AI-ready, GitOps-driven API management platform that provides full lifecycle management — from API ideation and design through deployment, governance, and monetization. It supports cloud, hybrid, and on-premises deployments. The platform is built around an Envoy-based API Gateway with a policy-first architecture, a management control plane (Platform API), developer and management portals, a CLI tool, and AI/MCP integration capabilities.

Primary users are API developers, platform engineers, and DevOps teams managing API infrastructure at scale.

## Architecture

### System Architecture

The platform follows a **microservices + modular monorepo** architecture with clear separation between control plane and data plane. All components are independently deployable as Docker containers and coordinated via a Go workspace (`go.work`).

```
┌─────────────────────────────────────────────────────────────┐
│         Management Portal / Developer Portal (React)         │
└──────────────────────────┬──────────────────────────────────┘
                           │ REST/HTTPS
┌──────────────────────────▼──────────────────────────────────┐
│              Platform API (Go, Gin, Port 9243)               │
│         REST API + WebSocket for portals & automation         │
└────────┬──────────────────────────────┬─────────────────────┘
         │ REST                         │ WebSocket
┌────────▼───────────────┐   ┌─────────▼─────────────────────┐
│ Gateway Controller     │   │ STS (OAuth2/OIDC Server)       │
│ (xDS Control Plane)    │   │ Asgardeo Thunder               │
│ Port 9090 REST         │   │ Port 8090 HTTPS, 9091 UI       │
│ Port 18000 xDS/gRPC    │   └────────────────────────────────┘
└────────┬───────────────┘
         │ xDS/gRPC (Envoy SotW protocol)
┌────────▼───────────────────────────────┐
│          Gateway Runtime                │
│  ┌──────────────────────────────────┐  │
│  │ Router (Envoy Proxy 1.35.3)     │  │
│  │ Port 8080 HTTP, 8443 HTTPS      │  │
│  └──────────┬───────────────────────┘  │
│             │ gRPC ext_proc            │
│  ┌──────────▼───────────────────────┐  │
│  │ Policy Engine (Go, CEL rules)   │  │
│  │ Port 9002 admin                 │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
         │
    Upstream Services
```

### Module/Component Map

| Module | Path | Responsibility |
|--------|------|----------------|
| Platform API | `platform-api/` | Backend REST + WebSocket service for portals, gateways, and automation. Handles organization, project, API, gateway, subscription, and API key lifecycle. |
| Gateway Controller | `gateway/gateway-controller/` | xDS control plane that serves Envoy configuration snapshots to routers. REST API for API configuration management. |
| Gateway Runtime (Router) | `gateway/gateway-runtime/router/` | Envoy Proxy data plane that handles API traffic routing, TLS termination. |
| Gateway Runtime (Policy Engine) | `gateway/gateway-runtime/policy-engine/` | gRPC ext_proc service that evaluates policies (auth, rate limiting, transformations) using CEL expressions. |
| Gateway Builder | `gateway/gateway-builder/` | Policy compilation tooling — compiles policy definitions into executable form. |
| Gateway Policies | `gateway/policies/` | Built-in policy definitions (JWT auth, API key, rate limiting, CORS, etc.). |
| CLI | `cli/src/` | Command-line tool for gateway registration and API lifecycle automation. |
| CLI Integration Tests | `cli/it/` | BDD integration tests for the CLI. |
| Gateway Integration Tests | `gateway/it/` | BDD integration tests for the full gateway stack. |
| Common | `common/` | Shared Go libraries: logger, config, errors, models, utils, constants. |
| SDK Core | `sdk/core/` | Core SDK utilities for extensions. |
| SDK AI | `sdk/ai/` | AI/ML integrations: Milvus vector DB, Redis caching, embedding providers. |
| Management Portal | `portals/management-portal/` | React + TypeScript + Vite admin UI for gateway and API management. |
| Developer Portal | `portals/developer-portal/` | React UI for API discovery, subscriptions, API key management. |
| API Designer | `api-designer/` | VSCode extension for REST, GraphQL, and AsyncAPI spec design with AI assistance. |
| STS | `sts/` | OAuth 2.0 / OIDC Security Token Service (Asgardeo Thunder). |
| Kubernetes Operator | `kubernetes/gateway-operator/` | Kubernetes operator for gateway orchestration. |
| Distribution | `distribution/all-in-one/` | Docker Compose all-in-one deployment for local development. |
| Mock Servers | `tests/mock-servers/` | Mock services for testing: mock-platform-api, mock-jwks, mock-azure-content-safety, mock-embedding-provider, mock-analytics-collector, mock-aws-bedrock-guardrail. |
| Sample Service | `samples/sample-service/` | Sample backend service for testing and demos. |

### Key Abstractions & Patterns

- **Layered architecture** in Platform API: Handler (HTTP binding) → Service (business logic, validation) → Repository (data access) → Database (SQLite/PostgreSQL).
- **Policy-first gateway**: Everything except basic routing is a policy. Policies are compiled by Gateway Builder and evaluated at runtime by the Policy Engine using CEL expressions.
- **xDS protocol**: Gateway Controller serves configuration to Router via Envoy's State-of-the-World (SotW) gRPC protocol, enabling zero-downtime configuration updates.
- **Specification-first development**: PRDs drive implementation, OpenAPI specs drive code generation (via `oapi-codegen`).
- **Go conventions**: Short lowercase package names, interfaces defined at usage point, accept interfaces return structs, structured logging with context.
- **Table-driven tests**: Go tests use `[]struct{}` test tables with subtests.
- **Mock implementations**: Embed the interface for unimplemented methods, override only what the test needs.

### Inter-Component Communication

| From | To | Protocol | Details |
|------|----|----------|---------|
| Portals | Platform API | REST/HTTPS | CRUD operations on organizations, projects, APIs, gateways |
| CLI | Platform API | REST/HTTPS | Automation for gateway registration and API lifecycle |
| Platform API | Gateway Controller | REST | Deploy API configurations to the control plane |
| Gateway (runtime) | Platform API | WebSocket | Bidirectional real-time events: deployment notifications, config sync. Auth via `api-key` header. Heartbeat ping/pong every 20s. |
| Gateway Controller | Router (Envoy) | xDS/gRPC | Port 18000. Full xDS snapshots for route, cluster, and listener configuration. |
| Router (Envoy) | Policy Engine | gRPC ext_proc | Request/response policy evaluation during traffic processing |
| Portals/Platform API | STS | OAuth2/OIDC | JWT token issuance and validation |

## Feature Inventory

| Feature | Documentation | Related Components |
|---------|---------------|--------------------|
| API Lifecycle Management | `platform-api/spec/impls/api-lifecycle-management.md`, `platform-api/spec/prds/api-lifecycle-management.md` | Platform API, Gateway Controller |
| Gateway Management | `platform-api/spec/impls/gateway-management.md`, `platform-api/spec/prds/gateway-management.md` | Platform API, Gateway Controller, Gateway Runtime |
| Gateway WebSocket Events | `platform-api/spec/impls/gateway-websocket-events.md` | Platform API (WebSocket handler) |
| Organization Management | `platform-api/spec/impls/organization-management.md` | Platform API |
| Project Management | `platform-api/spec/impls/project-management.md` | Platform API |
| Platform Bootstrap | `platform-api/spec/impls/platform-bootstrap.md` | Platform API |
| API Portal Publishing | `platform-api/spec/impls/apiportal-api-publishing.md` | Platform API, Developer Portal |
| JWT Authentication Policy | `gateway/policies/`, `gateway/gateway-controller/authentication.md` | Gateway Controller, Policy Engine |
| Policy Engine & CEL Rules | `gateway/gateway-runtime/policy-engine/Spec.md`, `gateway/gateway-runtime/policy-engine/BUILDER_DESIGN.md` | Policy Engine, Gateway Builder |
| AI Gateway | `docs/ai-gateway/` | SDK AI, Policy Engine, Gateway Controller |
| API Subscriptions | `docs/api-subscriptions/` | Platform API, Developer Portal |
| CLI Operations | `docs/cli/`, `cli/README.md` | CLI |
| Kubernetes Operator | `kubernetes/gateway-operator/README.md` | Gateway Operator |
| Platform API Architecture | `platform-api/spec/architecture.md` | Platform API |
| Platform API PRD | `platform-api/spec/prd.md` | Platform API |
| Development Standards | `platform-api/spec/constitution.md` | All components |

## Deployment

### Prerequisites

- **Docker & Docker Compose** (required for local development)
- **Go 1.25.5+** (for building gateway, platform-api, CLI, SDK, operator from source)
- **Node.js v22.0.0+** (for building portals)
- **Make** (build orchestration)
- **PostgreSQL 15+** (used in production; SQLite is default for local dev)

### Build & Run

**Quickest way — Docker Compose (all-in-one):**

```bash
cd distribution/all-in-one
docker compose up          # Start the full stack
docker compose up --build  # Rebuild images after code changes
docker compose down        # Shutdown (keeps data)
docker compose down -v     # Shutdown and clear all data
```

**Building individual components from source:**

```bash
# Gateway (all components: controller, builder, runtime)
cd gateway && make build

# Platform API
cd platform-api && make build

# CLI (all OS binaries)
cd cli/src && make build-all
```

### Configuration

**Key ports:**

| Port | Service |
|------|---------|
| 9243 | Platform API (HTTPS, self-signed cert) |
| 5173 | Management Portal |
| 3001 | Developer Portal |
| 9090 | Gateway Controller REST API |
| 18000 | Gateway Controller xDS/gRPC |
| 8080 | Gateway Router HTTP |
| 8443 | Gateway Router HTTPS |
| 9901 | Envoy Admin |
| 8090 | STS (HTTPS) |
| 9091 | STS Gate App UI |

**Key environment variables:**

| Variable | Component | Purpose |
|----------|-----------|---------|
| `DATABASE_DRIVER` | Platform API | `postgres` or `sqlite` |
| `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD` | Platform API | PostgreSQL connection |
| `DATABASE_SSL_MODE` | Platform API | PostgreSQL SSL mode |
| `APIP_GW_CONTROLLER_STORAGE_TYPE` | Gateway Controller | `sqlite` or `memory` |
| `APIP_GW_CONTROLLER_LOGGING_LEVEL` | Gateway Controller | `debug`, `info`, `warn`, `error` |
| `ROUTER_XDS_SERVER_HOST` | Gateway Runtime | xDS server hostname |

**Key config files:**
- `distribution/all-in-one/docker-compose.yaml` — full stack composition
- `portals/developer-portal/config.json` — developer portal settings
- `gateway/local.env` — local gateway development env vars

### Health Check

| Component | Endpoint | Expected |
|-----------|----------|----------|
| Platform API | `https://localhost:9243/health` | HTTP 200 |
| Gateway Controller | `http://localhost:9090/health` | HTTP 200 |
| Router (Envoy) | `http://localhost:9901/ready` | HTTP 200 |
| Policy Engine | `http://localhost:9002/health` | HTTP 200 |
| PostgreSQL | `pg_isready -U postgres -d devportal` | Exit 0 |

The gateway runtime uses `gateway/gateway-runtime/health-check.sh` which checks both Router and Policy Engine.

## Testing

### Test Framework & Conventions

- **Framework:** Go standard `testing` package + `stretchr/testify` (assert, require) for unit tests. `cucumber/godog` (BDD/Gherkin) for integration tests.
- **Naming convention:** `TestFunctionName_Scenario` or `TestFunctionName` (e.g., `TestAPIRepo_CreateAndRead`, `TestValidateUpdateAPIRequest`, `TestGenerateDockerfile_Success`). Table-driven tests use `tests := []struct{ name string; ... }{}` with `t.Run(tt.name, ...)`.
- **Unit test location:** Co-located with source code following standard Go layout (`*_test.go` alongside `.go` files).
- **Integration test location:** Separate `it/` directories — `gateway/it/` for gateway BDD tests, `cli/it/` for CLI BDD tests. Feature files in `it/features/*.feature`.

### Running Tests

```bash
# --- Unit Tests ---

# All gateway unit tests (controller + builder + policy engine)
make test-gateway
# Or: cd gateway && make test

# Gateway controller only
cd gateway && make test-controller

# Gateway builder only
cd gateway && make test-gateway-builder

# Policy engine only
cd gateway && make test-policy-engine

# Platform API unit tests
make test-platform-api
# Or: cd platform-api && make test

# CLI unit tests
make test-cli
# Or: cd cli/src && make test

# Run tests for a specific Go module
cd <module-dir> && go test -v ./...

# Run a single test
cd <module-dir> && go test -v -run TestFunctionName ./path/to/package/

# Run with coverage
cd <module-dir> && go test -v -cover -coverprofile=coverage.txt ./...

# --- Integration Tests ---

# Gateway integration tests (requires Docker; builds coverage images first)
cd gateway && make test-integration-all

# Gateway integration tests only (images must already be built)
cd gateway && make test-integration
# Or: cd gateway/it && make test

# Run specific feature file
cd gateway/it && IT_FEATURE_PATHS=features/health.feature make test

# Gateway integration tests with PostgreSQL backend
cd gateway/it && make test-postgres

# CLI integration tests
cd cli/it && make test
```

### Testing Dev Policies Locally (from gateway-controllers repo)

Policies are developed in the separate `wso2/gateway-controllers` repository. To test a policy change against the full gateway stack locally, use the `gateway/dev-policies/` workflow (see `gateway/dev-policies/README.md` for full details):

1. **Copy your policy** into `gateway/dev-policies/<policy-name>/` — it must contain `go.mod`, a `.go` file implementing `policy.Policy`, and `policy-definition.yaml`.

2. **Copy the policy definition** to the controller's default policies:
   ```bash
   cp gateway/dev-policies/<policy-name>/policy-definition.yaml \
      gateway/gateway-controller/default-policies/<policy-name>.yaml
   ```

3. **Register it** in `gateway/build.yaml` using a `filePath` entry:
   ```yaml
   policies:
     - name: <policy-name>
       filePath: ./dev-policies/<policy-name>
   ```

4. **Build and test locally:**
   ```bash
   cd gateway/gateway-runtime && make build
   # Then run the gateway stack (docker compose or make test-integration)
   ```

5. **Before committing:** Remove the `filePath` entry from `build.yaml` and the copied definition from `default-policies/` — dev-policies are not included in production builds.

An example dev policy (`count-letters/`) is provided in `gateway/dev-policies/` as a reference.

### Test Infrastructure

- **testcontainers-go** with Docker Compose module: Used by gateway and CLI integration tests to spin up the full stack in containers.
- **Mock servers** (`tests/mock-servers/`): Pre-built mock services for testing without external dependencies:
  - `mock-platform-api` — mock Platform API responses
  - `mock-jwks` — mock JWT JWKS endpoint
  - `mock-azure-content-safety` — mock Azure Content Safety API
  - `mock-embedding-provider` — mock embedding/vector API
  - `mock-analytics-collector` — mock analytics ingestion
  - `mock-aws-bedrock-guardrail` — mock AWS Bedrock guardrail API
- **Docker Compose test files** (`gateway/it/docker-compose.test.*.yaml`): Various configurations for different integration test scenarios (default SQLite, PostgreSQL, virtual hosts).
- **Test config files:**
  - `gateway/it/test-config.toml` — gateway integration test configuration (controller, router, policy engine settings, policy paths)
  - `cli/it/test-config.yaml` — CLI integration test configuration (infrastructure dependencies, test definitions)
- **Coverage-instrumented builds:** `cd gateway && make build-coverage` builds gateway images with coverage instrumentation for integration test code coverage collection.
- **Mock patterns in unit tests:** Embed the repository/service interface, override only needed methods:
  ```go
  type mockAPIRepository struct {
      repository.APIRepository
      handleExistsResult bool
      // ...
  }
  ```
- **Test helpers:** Functions like `createTestOrganizationAndProject(t *testing.T, db *database.DB, ...)` for common setup. `t.TempDir()` for ephemeral SQLite databases in unit tests.

## Coding Conventions

### Style & Formatting

- **Go:** `gofmt` formatting, `goimports` for import ordering. Linter config at `kubernetes/gateway-operator/.golangci.yml` (dupl, errcheck, goconst, gocyclo, gofmt, goimports, gosimple, govet, ineffassign, lll, misspell, staticcheck, unconvert, unparam, unused).
- **TypeScript/React (Portals):** ESLint v9 flat config with `typescript-eslint`, `eslint-plugin-react-hooks`, `eslint-plugin-react-refresh`. Config at `portals/management-portal/eslint.config.js`.
- **API naming:** camelCase properties (e.g., `organizationId`, `createdAt`). Resource IDs use `id` for primary, `<resource>Id` for foreign keys. Path params use `{resourceId}` format.
- **Go package naming:** Short, lowercase, single-word names. Interfaces defined at usage point. Accept interfaces, return structs.
- **Structured logging** with context throughout all Go components.

### Commit Message Format

Conventional-style commits observed in the repository:

```
<type>(<scope>): <subject>
```

Common types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Imperative mood for subjects (e.g., `Add SDK release workflows`, `Fix issues in MCP analytics`). PR merge commits follow: `Merge pull request #<N> from <branch>`.

### Branch Naming

- **Feature branches:** `feature/<description>` (e.g., `feature/llm-improvements`)
- **Fix branches:** `fix/<description>` (e.g., `fix/operator-indexed-configmap-fanout`)
- **Copilot branches:** `copilot/<description>` (e.g., `copilot/add-jwt-policy-tests`)
- **Release branches:** `release`, `helm-<version>`, `operator-<version>`

## Contribution Guidelines

### PR Process

- PRs require review from code owners defined in `.github/CODEOWNERS` (Go dependency changes require approval from @pubudu538, @malinthaprasan, @Krishanx92).
- CI workflows must pass (component-specific: `gateway-integration-test.yml`, `platform-api-pr-check.yml`, etc.).
- Security scanning via Trivy and JFrog scans.
- Code coverage tracked via Codecov.
- Follow the development standards in `platform-api/spec/constitution.md`: specification-first, layered architecture, security by default, documentation traceability.

### PR Template Location

`.github/pull_request_template.md`

### Labels & Categories

**Type labels:**

| Label | When to use |
|-------|-------------|
| `Type/Bug` | Something does not work as expected |
| `Type/Feature` | New feature request |
| `Type/Improvement` | Enhancement to existing functionality |
| `Type/Task` | Development task |

**Area labels:**

| Label | When to use |
|-------|-------------|
| `Area/Management` | Management API or Management Portal UI |
| `Area/Gateway` | Routing, API deployment in gateway |
| `Area/Policies` | Policies, Policy Hub, Policy Engine |
| `Area/APIDesigner` | API Designer VSCode extension |
| `Area/DeveloperPortal` | Developer Portal API or UI |
| `Area/AIGateway` | AI Gateway runtime/control plane |
| `Area/AIPolicies` | AI Gateway Policies, Guardrails |
| `Area/Operator` | Kubernetes operator |
| `Area/Other` | Anything else |

**Aspect labels:**

| Label | When to use |
|-------|-------------|
| `Aspect/API` | API backends, definitions, contracts, OpenAPI |
| `Aspect/UI` | Frontend layouts, components, styling |
| `Aspect/Configuration` | Config files, settings, env vars |
| `Aspect/Logging` | Log formats, instrumentation |
| `Aspect/Monitoring` | Metrics, observability, health checks |
| `Aspect/Performance` | Latency, optimizations, load issues |
| `Aspect/Testing` | Test coverage, integration tests |
| `Aspect/AI` | AI/LLM integration, MCP, AI readiness |
| `Aspect/UX` | User experience, flows, usability |
| `Aspect/Other` | Anything else |

**Severity labels:**

| Label | When to use |
|-------|-------------|
| `Severity/Blocker` | Core functionality broken, consumer blocked, needs immediate attention |
| `Severity/Critical` | Core functionality broken but workaround exists, needs urgent attention |
| `Severity/Major` | Important functionality broken, should be prioritized |
| `Severity/Minor` | Non-critical, can be fixed in future releases |
| `Severity/Trivial` | Cosmetic issues |

## References

- **OpenAPI Specs:**
  - Platform API: `platform-api/src/resources/openapi.yaml`
  - Gateway Controller Management: `gateway/gateway-controller/api/management-openapi.yaml`
  - Gateway Controller Admin: `gateway/gateway-controller/api/admin-openapi.yaml`
- **Architecture docs:** `platform-api/spec/architecture.md`
- **Product requirements:** `platform-api/spec/prd.md`
- **Development standards:** `platform-api/spec/constitution.md`
- **Documentation guidelines:** `guidelines/DOCUMENTATION.md`
- **Copilot/AI agent instructions:** `.github/copilot-instructions.md`
- **Performance benchmarks:** `docs/performance/`
- **Docker registry:** `ghcr.io/wso2/api-platform`
- **License:** Apache 2.0