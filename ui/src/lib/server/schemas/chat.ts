import { Schema } from 'effect';

export class NewChatRequest extends Schema.Class<NewChatRequest>('NewChatRequest')({
  dataset: Schema.String.pipe(
    Schema.filter((value) => value !== 'Select a dataset', {
      message: () => 'Please select a valid dataset',
    }),
  ),
}) {}
