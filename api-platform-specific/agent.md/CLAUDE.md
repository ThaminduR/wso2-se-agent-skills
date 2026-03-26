# Repo Map

Workspace: `api-platform/` (Go workspace), `gateway-controllers/` (policies/docs).

## Gateway (api-platform/gateway/)

- Build all: `make build`
- Build one: `make build-controller`, `make build-gateway-builder`, `make build-gateway-runtime`
- Run: `docker compose up` (or `up -d`)
- Debug run: `docker compose -f docker-compose.debug.yaml up`
- Unit tests: `make test`
- Integration tests: `cd it && make test` (images must be built first)
- Integration build+test: `cd it && make test-all`
- Clean: `make clean`

Components: gateway-controller (Go, xDS control plane), gateway-runtime (Envoy + policy-engine), gateway-builder (policy compiler).

## Platform API (api-platform/platform-api/)

- Build: `make build` (see Makefile)
- Spec: `spec/`, codegen: `oapi-codegen.yaml`

## CLI (api-platform/cli/)

- Source: `src/`, integration tests: `it/`

## Go Workspace

Root: `api-platform/go.work` — lists all modules.

## Key Paths

- Gateway configs: `api-platform/gateway/configs/`
- Gateway docker-compose: `api-platform/gateway/docker-compose.yaml`
- Gateway IT compose: `api-platform/gateway/it/docker-compose.test.yaml`
- System policies: `api-platform/gateway/system-policies/`
- SDK: `api-platform/sdk/` (core, ai)
- Samples: `api-platform/samples/`
