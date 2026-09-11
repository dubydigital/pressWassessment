import 'dotenv/config';
import { streamText, tool, isStepCount } from 'ai';
import { openai } from '@ai-sdk/openai';
import { z } from 'zod';
import Fastify from 'fastify';
import multipart from '@fastify/multipart';

// =============================================================================
//  Fastify app + multipart plugin (same as your current server.ts)
// =============================================================================
const fastify = Fastify({ logger: false });

fastify.register(multipart, {
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max per file
  },
});

const model = openai('gpt-4o-mini');

// =============================================================================
// Brave Search helper + webSearch tool
// This is still NOT an HTTP endpoint. The model calls webSearch; webSearch
// calls searchBrave; searchBrave hits Brave's API.
// =============================================================================
type BraveSearchResult = {
  title: string;
  url: string;
  snippet: string;
};

async function searchBrave(query: string): Promise<BraveSearchResult[]> {
  const apiKey = process.env.BRAVE_SEARCH_API_KEY;
  if (!apiKey) {
    throw new Error('Missing BRAVE_SEARCH_API_KEY in .env');
  }

  const url = new URL('https://api.search.brave.com/res/v1/web/search');
  url.searchParams.set('q', query);
  url.searchParams.set('count', '5');
  // Prefer recent pages. Without this, Brave can rank a 2024 recap of Super Bowl
  // LVII (2023) above the actual latest game — which is what /api/chat returned.
  url.searchParams.set('freshness', 'py'); // past year

  const response = await fetch(url, {
    headers: {
      Accept: 'application/json',
      'X-Subscription-Token': apiKey,
    },
  });

  if (!response.ok) {
    throw new Error(`Brave Search failed: ${response.status} ${response.statusText}`);
  }

  const data = await response.json() as {
    web?: {
      results?: Array<{ title?: string; url?: string; description?: string }>;
    };
  };

  return (data.web?.results ?? []).slice(0, 5).map((result) => ({
    title: result.title ?? '',
    url: result.url ?? '',
    snippet: result.description ?? '',
  }));
}

const webSearch = tool({
  description:
    'Search the live web. Use for current events, prices, scores, unknown names, or anything that may have changed recently. Put the current year in the query (e.g. "Super Bowl 2026 winner", not "last Super Bowl").',
  inputSchema: z.object({
    query: z.string().describe('Search query to send to Brave. Include the year for sports, news, and "latest/last" questions.'),
  }),
  execute: async ({ query }) => {
    console.log(`[webSearch] used — query: "${query}"`);
    const results = await searchBrave(query);
    console.log(`[webSearch] Brave returned ${results.length} result(s)`);
    return results;
  },
});

// Built like a list of rules (same concatenated-string style as a typical
// generateText `system:` prompt). Each sentence is one instruction you can
// tweak without rewriting the whole block.
//
// Why this exists: gpt-4o-mini's training data ends ~late 2023. "Who won the
// last Super Bowl?" sounded like something it already knew, so it answered
// Super Bowl LVII (Chiefs 38-35, 2023) instead of searching. The old prompt
// said "use your own knowledge when that is enough," which encouraged that.
// Inject today's date, forbid memory for "last/latest/who won," and make the
// search query include the year.
function searchSystem() {
  const today = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  return (
    `Today is ${today}. Your training data is out of date. ` +
    `If the user says last, latest, current, who won, or anything that can change, you MUST call webSearch. ` +
    `Never answer those from memory. ` +
    `Put the current year in the search query (e.g. "Super Bowl 2026 winner", not "last Super Bowl"). ` +
    `Cite source URLs from the search results.`
  );
}

// =============================================================================
// NEW: tool registry
// Replaces "always attach webSearch on /api/ask and /api/ask-stream".
// SwiftUI now sends which tools it wants. Adding RAG later = add another
// entry here. You do NOT add a new Fastify route.
//
// Example later:
//   const retrieveDocs = tool({ ... });
//   ALL_TOOLS.rag = retrieveDocs;
//   SwiftUI sends tools: ["rag"] or tools: ["webSearch", "rag"]
// =============================================================================
const ALL_TOOLS = {
  webSearch,
  // rag: retrieveDocs,  // <-- uncomment/add when you have a vector store
};

function pickTools(requested: string[] = []) {
  const selected: Partial<typeof ALL_TOOLS> = {};

  for (const name of requested) {
    if (name === 'webSearch') {
      selected.webSearch = ALL_TOOLS.webSearch;
    }
    // if (name === 'rag') selected.rag = ALL_TOOLS.rag;
  }

  return selected;
}

function systemFor(requested: string[] = []) {
  const parts = ['You are a helpful chat assistant.'];

  if (requested.includes('webSearch')) {
    parts.push(searchSystem()); // fresh date on every request, not once at boot
  }
  // if (requested.includes('rag')) {
  //   parts.push('Use retrieveDocs when the question is about the user\'s documents.');
  // }

  return parts.join(' ');
}

// =============================================================================
// NEW: one request shape for the SwiftUI chat app
//
// Replaces three different body parsers:
//   /api/ask          -> JSON { prompt }
//   /api/ask-stream   -> JSON { prompt }
//   /api/describe-file -> multipart { prompt, file }
//
// Now SwiftUI always hits POST /api/chat with:
//   messages: chat history  (replaces the single "prompt" string)
//   tools:    ["webSearch"] or []   (empty = plain chat, no Brave)
//   file:     optional photo/PDF    (same multipart idea as /api/describe-file)
//
// Two encodings, one handler:
//   application/json        when there is no attachment
//   multipart/form-data     when the user attached a file
// =============================================================================
type ChatMessage = {
  role: 'user' | 'assistant' | 'system';
  content: string;
};

type ChatRequest = {
  messages: ChatMessage[];
  tools: string[];
  files: { buffer: Buffer; mimeType: string }[];
};

async function parseChatRequest(request: any): Promise<ChatRequest> {
  // ----- JSON path (no file) -----
  // This is the /api/ask + /api/ask-stream body, upgraded to `messages`.
  if (!request.isMultipart()) {
    const body = (request.body ?? {}) as {
      messages?: ChatMessage[];
      tools?: string[];
      prompt?: string; // optional leftover from your old curl tests
    };

    const messages =
      body.messages && body.messages.length > 0
        ? body.messages
        : body.prompt
          ? [{ role: 'user' as const, content: body.prompt }]
          : [];

    return {
      messages,
      tools: body.tools ?? [],
      files: [],
    };
  }

  // ----- Multipart path (file + fields) -----
  // Same loop you already had in /api/describe-file, plus `messages` and `tools`.
  const messages: ChatMessage[] = [];
  let tools: string[] = [];
  const files: ChatRequest['files'] = [];
  let promptFallback = '';

  for await (const part of request.parts()) {
    if (part.type === 'file') {
      files.push({
        buffer: await part.toBuffer(),
        mimeType: part.mimetype, // e.g. image/jpeg, application/pdf
      });
      continue;
    }

    if (part.fieldname === 'messages') {
      messages.push(...JSON.parse(part.value as string));
    } else if (part.fieldname === 'tools') {
      tools = JSON.parse(part.value as string);
    } else if (part.fieldname === 'prompt') {
      // lets you keep testing with the old form field name
      promptFallback = part.value as string;
    }
  }

  if (messages.length === 0 && promptFallback) {
    messages.push({ role: 'user', content: promptFallback });
  }

  return { messages, tools, files };
}

// =============================================================================
// REPLACES:
//   POST /api/ask            (single-shot JSON + web search)
//   POST /api/ask-stream     (streaming JSON + web search)
//   POST /api/describe-file  (multipart file + prompt, no tools)
//
// One URL for the SwiftUI app. Streaming is always on (chat UX).
// Files, web search, and later RAG are flags on the request, not new routes.
// =============================================================================
fastify.post('/api/chat', async (request, reply) => {
  try {
    const { messages, tools: requestedTools, files } = await parseChatRequest(request);

    if (messages.length === 0) {
      return reply.status(400).send({
        error: 'Missing messages. Send { messages: [{ role, content }] }.',
      });
    }

    // Put attachments on the last user turn — same content array you used
    // in /api/describe-file, but now it sits inside a real chat history.
    const last = messages[messages.length - 1];
    const prior = messages.slice(0, -1);

    const lastContent =
      files.length === 0
        ? last.content
        : [
            { type: 'text' as const, text: last.content },
            ...files.map((file) => ({
              type: 'file' as const,
              mediaType: file.mimeType,
              data: file.buffer,
            })),
          ];

    const tools = pickTools(requestedTools);
    const hasTools = Object.keys(tools).length > 0;

    // streamText = what /api/ask-stream already did.
    // tools + stopWhen = what /api/ask already did, but only if SwiftUI asked.
    const { textStream } = streamText({
      model,
      system: systemFor(requestedTools),
      messages: [
        ...prior,
        { role: last.role, content: lastContent },
      ],
      ...(hasTools
        ? {
            tools,
            stopWhen: isStepCount(5), // lets the model search, then answer
          }
        : {}),
    });

    // UNCHANGED streaming headers from /api/ask-stream
    reply.raw.writeHead(200, {
      'Content-Type': 'text/plain; charset=utf-8',
      'Transfer-Encoding': 'chunked',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    });

    for await (const text of textStream) {
      reply.raw.write(text);
    }
    reply.raw.end();
  } catch (error) {
    fastify.log.error(error);
    if (!reply.raw.headersSent) {
      return reply.status(500).send({ error: 'Internal AI Chat Failure' });
    }
    reply.raw.end();
  }
});

// =============================================================================
// Docker-friendly listener
// =============================================================================
const start = async () => {
  try {
    await fastify.listen({
      port: 3000,
      host: '0.0.0.0',
    });
    console.log('🚀 API Server actively listening on: http://localhost:3000');
  } catch (err) {
    console.error('Fatal Server Boot Error:', err);
    process.exit(1);
  }
};

start();