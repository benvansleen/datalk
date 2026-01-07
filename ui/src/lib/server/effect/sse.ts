import { Effect, Stream, Schedule } from 'effect';

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
  stream: Stream.Stream<T, E, R>
): Effect.Effect<Response, never, R> =>
  Effect.gen(function* () {
    // Transform stream values to SSE-formatted strings
    const sseStream = stream.pipe(
      Stream.map(formatSSEMessage),
      // On error, emit an error event and end the stream
      Stream.catchAll((error) =>
        Stream.make(`event: error\ndata: ${JSON.stringify({ error: String(error) })}\n\n`)
      )
    );

    // Convert to ReadableStream
    const readableStream = yield* Stream.toReadableStreamEffect(sseStream);

    // Create the Response with SSE headers
    // Use TextEncoderStream to handle string -> Uint8Array conversion
    const encodedStream = readableStream.pipeThrough(new TextEncoderStream());

    return new Response(encodedStream, {
      headers: SSE_HEADERS,
    });
  }).pipe(Effect.withSpan('sse.streamToSSE'));

/**
 * Create an SSE stream that emits a heartbeat to keep the connection alive.
 *
 * @param intervalMs - Heartbeat interval in milliseconds (default: 30000)
 * @returns A stream that emits SSE comment heartbeats
 */
export const heartbeat = (intervalMs = 30000) =>
  Stream.repeat(Stream.make(': heartbeat\n\n'), Schedule.spaced(intervalMs));

/**
 * Merge a data stream with a heartbeat stream.
 * Useful for keeping SSE connections alive during periods of inactivity.
 */
export const withHeartbeat = <T, E, R>(
  stream: Stream.Stream<T, E, R>,
  intervalMs = 30000
): Stream.Stream<T | string, E, R> =>
  Stream.merge(stream, heartbeat(intervalMs) as Stream.Stream<T | string, never, never>);
