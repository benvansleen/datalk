import { Effect, Stream } from 'effect';

/**
 * SSE Response headers
 */
const SSE_HEADERS = {
  'Content-Type': 'text/event-stream',
  'Cache-Control': 'no-cache',
  Connection: 'keep-alive',
} as const;

/**
 * Format a value as an SSE data message.
 * Objects are JSON-serialized.
 */
const formatSSEMessage = <T>(data: T): string => {
  const payload = typeof data === 'string' ? data : JSON.stringify(data);
  return `data: ${payload}\n\n`;
};

/**
 * Convert an Effect Stream to an SSE Response.
 *
 * The stream values are automatically serialized to JSON and formatted
 * as SSE data messages.
 *
 * @param stream - The stream to convert to SSE
 * @returns An Effect that produces an SSE Response
 */
export const streamToSSE = <T, E, R>(
  stream: Stream.Stream<T, E, R>,
): Effect.Effect<Response, never, R> =>
  Effect.gen(function* () {
    // Transform stream values to SSE-formatted strings
    const sseStream = stream.pipe(
      Stream.map(formatSSEMessage),
      // On error, emit an error event and end the stream
      Stream.catchAll((error) =>
        Stream.make(`event: error\ndata: ${JSON.stringify({ error: String(error) })}\n\n`),
      ),
    );

    // Convert to ReadableStream
    const readableStream = yield* Stream.toReadableStreamEffect(sseStream);

    // Create the Response with SSE headers
    // Use TextEncoderStream to handle string -> Uint8Array conversion
    const encodedStream = readableStream.pipeThrough(new TextEncoderStream());

    return new Response(encodedStream, {
      headers: SSE_HEADERS,
    });
  }).pipe(Effect.withSpan('sse.stream'));
