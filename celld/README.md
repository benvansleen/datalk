# Datalk celld application

This package is the live, stateful application layer. SvelteKit remains responsible for Better Auth and PostgreSQL-backed SSR; this Worker owns live chat state, generation coordination, WebSockets, and calls to `lis-python-server`.

## Durable-object layout

- `UserCell`, addressed by Better Auth user ID, stores the sidebar summary list and serves `/live/socket`.
- `ChatCell`, addressed by chat UUID, stores a chat's messages, generation state, and bounded event log. It serves replayable events and `/live/chats/:chatId/socket`.
- Durable-object serialization replaces the former PostgreSQL conditional update and Redis generation lock. A second message during generation receives `409`.

The event log is bounded to 1,000 records and is intended for reconnect replay, not analytics. PostgreSQL projection and cold-cell hydration are deliberately a later migration step.

## Required secrets and variables

- `INTERNAL_CELL_SECRET`: shared secret carried only on Worker-to-cell requests. It prevents celld's public direct-DO routes from being used to bypass the live router.
- `INTERNAL_PROJECTION_SECRET`: shared secret used to sign internal requests to SvelteKit, including forwarding the caller's session cookie to `/api/internal/auth/verify-session`.
- `OPENAI_API_KEY`: OpenAI API key for generation.
- `OPENAI_MODEL`: optional, defaults to `gpt-5-nano`.
- `LIVE_ORIGIN`: public SvelteKit origin permitted to make cookie-authenticated live HTTP and WebSocket requests. Same-origin GETs/HEADs (which send no `Origin` header, e.g. `<img>` loads) are also accepted; non-GET requests and mismatched origins are rejected with 403.
- `PYTHON_SERVER_URL`: the existing `lis-python-server` service URL.

Use celld's secret environment support for the first three values. Do not put them in `wrangler.jsonc`.

## Public API

- `GET /live/health`
- `GET|POST /live/chats`
- `DELETE /live/chats/:chatId`
- `POST /live/chats/:chatId/messages`
- `GET /live/chats/:chatId/socket` with WebSocket upgrade
- `GET /live/socket` with WebSocket upgrade

All live routes except health require a valid Better Auth session cookie, verified by forwarding the caller's `cookie` header to SvelteKit's signed `/api/internal/auth/verify-session` endpoint (cached per cookie in the isolate). The chat socket first sends a snapshot, then streams generation events; subsequent state changes are sent as snapshots. Reconnects restart from the current snapshot, since the bounded event log lives inside the cell.

## Validation

Run `npm run check` and `npm test` from this directory. The SeaweedFS celld object-store contract remains in `../celld-contract-tests/` and is intentionally independent from this Worker package.

## Operations and telemetry

Celld exposes the Worker on its public listener and its peer and operator APIs on a separate private listener. Kubernetes advertises each pod's private listener directly; never route that listener through the public ingress or advertise the shared application Service.

Use `GET /__celld/health` for node readiness. `GET /live/health` only checks the deployed application route.

Celld 0.2 provides the Worker runtime telemetry. When the local observability module is enabled, the daemon exports native request, cell, outbound fetch, and lifecycle spans over OTLP and propagates W3C trace context to SvelteKit and `lis-python-server`. It also exports trace-correlated Worker console logs.

Celld 0.2.1 does not expose an API for creating child spans or adding attributes and events to its active span. The Worker therefore emits bounded structured application records with `console.log`; celld attaches each record to the active native trace and span across `await` boundaries. `Observability` and `AiTelemetry` are Effect services covering live commands, chat and title generation, model calls, tools, and aggregate stream timings.

Prompts, message content, tool arguments, code, query text, outputs, identifiers, and error values are excluded. In the local observability stack, the collector's logs pipeline writes these correlated records to its Kubernetes logs. Jaeger continues to display only celld's native spans because it is not a log backend.

The object-store conditional-write startup probe remains enabled. A node must not become ready when SeaweedFS cannot enforce celld's ownership preconditions.
