type StreamEvent = {
  id: string;
  event: object;
};

export const makeXReadScript = (batches: StreamEvent[][]) => {
  let index = 0;

  return async () => {
    if (index >= batches.length) {
      return null;
    }

    const batch = batches[index];
    index += 1;

    return [
      {
        messages: batch.map(({ id, event }) => ({
          id,
          message: { event: JSON.stringify(event) },
        })),
      },
    ];
  };
};
