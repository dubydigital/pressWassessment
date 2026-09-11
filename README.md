# Chat API (AI SDK + Web Search)

Fastify backend for a SwiftUI chat client. One endpoint, `POST /api/chat`, streams the model reply. The client chooses whether to enable Brave web search and whether to attach a photo or PDF.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Compose v2)
- An [OpenAI API key](https://platform.openai.com/api-keys)
- A [Brave Search API key](https://brave.com/search/api/) (only required when the request includes `"tools": ["webSearch"]`)

Node 22+ is enough if you run the server without Docker.

## Setup

```bash
cp .env.example .env
```

Fill in `.env`:

```
OPENAI_API_KEY=sk-...
BRAVE_SEARCH_API_KEY=BSA...
```

`.env` is gitignored. Compose injects it into the container at runtime; it is not baked into the image.

## Run with Docker

From the repo root:

```bash
docker compose up --build
```

The API is ready when you see:

```
API Server actively listening on: http://localhost:3000
```

Stop with `Ctrl+C`. Rebuild after code changes with `docker compose up --build`.

## Run locally (no Docker)

```bash
npm install
npm start
```

`npm start` serves on http://localhost:3000. Use `npm run dev` to restart on file changes.

## API

| | |
|---|---|
| Method / path | `POST /api/chat` |
| JSON body | No attachment |
| Multipart body | Photo or PDF attached |
| Success | Streamed `text/plain` (not a JSON blob) |
| Missing messages | `400` `{ "error": "Missing messages. ..." }` |

JSON fields:

```json
{
  "messages": [{ "role": "user", "content": "Hello" }],
  "tools": []
}
```

- `messages` — chat history. Roles: `user`, `assistant`, `system`.
- `tools` — `[]` for plain chat, or `["webSearch"]` to let the model call Brave.
- `prompt` — optional shortcut for a single user turn if you omit `messages`.

Multipart uses the same names. `messages` and `tools` are JSON strings. Any file part is attached to the last user message.

Use `curl -N` so the stream prints as tokens arrive instead of waiting for the full reply.

## Try it

Plain chat (no tools):

```bash
curl -N http://localhost:3000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{ "role": "user", "content": "Say hello in one sentence." }],
    "tools": []
  }'
```

Web search (needs `BRAVE_SEARCH_API_KEY`):

```bash
curl -N http://localhost:3000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{ "role": "user", "content": "Who won the last Super Bowl?" }],
    "tools": ["webSearch"]
  }'
```

Image or PDF:

```bash
curl -N http://localhost:3000/api/chat \
  -F 'messages=[{"role":"user","content":"What is in this file?"}]' \
  -F 'tools=[]' \
  -F 'file=@./photo.jpg;type=image/jpeg'
```

Point `-F file=@...` at a real file. Swap `image/jpeg` for `application/pdf` when you send a PDF.

Multi-turn (send prior assistant text back as history):

```bash
curl -N http://localhost:3000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      { "role": "user", "content": "Name a pasta dish." },
      { "role": "assistant", "content": "Cacio e pepe." },
      { "role": "user", "content": "What cheese does it use?" }
    ],
    "tools": []
  }'
```

Validation error:

```bash
curl -i http://localhost:3000/api/chat \
  -H "Content-Type: application/json" \
  -d '{}'
```

Expect `400` and `Missing messages`.

## Troubleshooting

- **Container exits immediately** — `.env` is missing or Compose cannot read it (`env_file: .env`).
- **500 on every request** — `OPENAI_API_KEY` is empty or invalid.
- **Web search replies fail** — `BRAVE_SEARCH_API_KEY` is missing. Plain chat with `"tools": []` does not need it.
- **Port already in use** — something else is bound to `3000`. Stop that process or change the left-hand port in `compose.yaml` (`"3001:3000"`).
