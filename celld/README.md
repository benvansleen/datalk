# Datalk celld application

This package is the live, stateful application layer. SvelteKit remains responsible for Better Auth and PostgreSQL-backed SSR; this Worker owns live chat state, generation coordination, WebSockets, and calls to `lis-python-server`.

## Durable-object layout

- `UserCell`, addressed by Better Auth user ID, stores the sidebar summary list and serves `/live/socket`.
- `ChatCell`, addressed by chat UUID, stores a chat's messages, generation state, and bounded event log. It serves replayable events and `/live/chats/:chatId/socket`.
- Durable-object serialization replaces the former PostgreSQL conditional update and Redis generation lock. A second message during generation receives `409`.

The event log is bounded to 1,000 records and is intended for reconnect replay, not analytics. PostgreSQL projection and cold-cell hydration are deliberately a later migration step.

## Required secrets and variables

- `AUTH_SECRET`: HMAC key used to validate short-lived `datalk_live` JWTs minted by the SvelteKit auth service. Claims must be `{ sub, exp, aud: "datalk-live", iss: "datalk" }`.
- `INTERNAL_CELL_SECRET`: shared secret carried only on Worker-to-cell requests. It prevents celld's public direct-DO routes from being used to bypass the live router.
- `OPENAI_API_KEY`: OpenAI API key for generation.
- `OPENAI_MODEL`: optional, defaults to `gpt-5-nano`.
- `LIVE_ORIGIN`: public SvelteKit origin permitted to make cookie-authenticated live HTTP and WebSocket requests.
- `PYTHON_SERVER_URL`: the existing `lis-python-server` service URL.

Use celld's secret environment support for the first four values. Do not put them in `wrangler.jsonc`.

## Public API

- `GET /live/health`
- `GET|POST /live/chats`
- `DELETE /live/chats/:chatId`
- `POST /live/chats/:chatId/messages`
- `GET /live/chats/:chatId/events?after=<sequence>`
- `GET /live/chats/:chatId/socket?after=<sequence>` with WebSocket upgrade
- `GET /live/socket` with WebSocket upgrade

All live routes except health require the short-lived session credential. The chat socket first sends a snapshot, then replays events newer than `after`; subsequent state changes are sent as snapshots. This keeps reconnection semantics explicit while the browser migration is still pending.

## Validation

Run `npm run check` and `npm test` from this directory. The SeaweedFS celld object-store contract remains in `../celld-contract-tests/` and is intentionally independent from this Worker package.
