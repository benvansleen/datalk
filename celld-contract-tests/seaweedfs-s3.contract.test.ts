import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CreateBucketCommand,
  GetObjectCommand,
  HeadObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';

const endpoint = process.env.CELLD_S3_ENDPOINT;
const bucket = process.env.CELLD_S3_BUCKET;
const region = process.env.AWS_REGION ?? 'us-east-1';
const configured = endpoint !== undefined || bucket !== undefined;

const client =
  endpoint && bucket
    ? new S3Client({
        endpoint,
        region,
        forcePathStyle: true,
        credentials: {
          accessKeyId: process.env.AWS_ACCESS_KEY_ID ?? 'celld-contract-test',
          secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY ?? 'celld-contract-test',
        },
      })
    : undefined;

const testOptions = {
  skip: configured ? false : 'set CELLD_S3_ENDPOINT and CELLD_S3_BUCKET to run against SeaweedFS',
};

function statusCode(error: unknown): number | undefined {
  if (typeof error !== 'object' || error === null || !('$metadata' in error)) {
    return undefined;
  }

  const metadata = error.$metadata;
  if (typeof metadata !== 'object' || metadata === null || !('httpStatusCode' in metadata)) {
    return undefined;
  }

  return typeof metadata.httpStatusCode === 'number' ? metadata.httpStatusCode : undefined;
}

async function rejectsWithPreconditionFailure(operation: Promise<unknown>) {
  await assert.rejects(operation, (error) => statusCode(error) === 412);
}

test('SeaweedFS implements celld S3 conditional-write contract', testOptions, async () => {
  assert.ok(endpoint, 'CELLD_S3_ENDPOINT is required when running the storage contract suite');
  assert.ok(bucket, 'CELLD_S3_BUCKET is required when running the storage contract suite');
  assert.ok(client);

  await client.send(new CreateBucketCommand({ Bucket: bucket })).catch((error: unknown) => {
    const status = statusCode(error);
    if (status !== 409) {
      throw error;
    }
  });

  const prefix = `celld-contract/${crypto.randomUUID()}`;
  const key = `${prefix}/ownership.json`;
  const created = await client.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: 'owner-a',
      ContentType: 'application/json',
      Metadata: { contract: 'celld' },
      IfNoneMatch: '*',
    }),
  );

  assert.ok(created.ETag, 'conditional create must return an ETag');
  await rejectsWithPreconditionFailure(
    client.send(
      new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        Body: 'owner-b',
        IfNoneMatch: '*',
      }),
    ),
  );

  const head = await client.send(new HeadObjectCommand({ Bucket: bucket, Key: key }));
  assert.equal(head.ETag, created.ETag, 'HEAD must expose the stable ETag used for CAS');
  assert.equal(head.Metadata?.contract, 'celld', 'user metadata must round-trip');

  const read = await client.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
  assert.equal(await read.Body?.transformToString(), 'owner-a');
  assert.equal(read.ETag, created.ETag, 'GET must expose the stable ETag used for CAS');

  const updated = await client.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: 'owner-c',
      IfMatch: created.ETag,
    }),
  );
  assert.ok(updated.ETag, 'conditional update must return an ETag');
  await rejectsWithPreconditionFailure(
    client.send(
      new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        Body: 'owner-d',
        IfMatch: created.ETag,
      }),
    ),
  );

  const raceKey = `${prefix}/race.json`;
  const race = await Promise.allSettled(
    Array.from({ length: 8 }, (_, index) =>
      client.send(
        new PutObjectCommand({
          Bucket: bucket,
          Key: raceKey,
          Body: `candidate-${index}`,
          IfNoneMatch: '*',
        }),
      ),
    ),
  );
  assert.equal(race.filter((result) => result.status === 'fulfilled').length, 1);
  for (const result of race.filter((result) => result.status === 'rejected')) {
    assert.equal(statusCode(result.reason), 412, 'losing conditional creates must return 412');
  }

  const raceHead = await client.send(new HeadObjectCommand({ Bucket: bucket, Key: raceKey }));
  assert.ok(raceHead.ETag, 'concurrent update test requires the created object ETag');
  const updateRace = await Promise.allSettled(
    Array.from({ length: 8 }, (_, index) =>
      client.send(
        new PutObjectCommand({
          Bucket: bucket,
          Key: raceKey,
          Body: `updated-candidate-${index}`,
          IfMatch: raceHead.ETag,
        }),
      ),
    ),
  );
  assert.equal(updateRace.filter((result) => result.status === 'fulfilled').length, 1);
  for (const result of updateRace.filter((result) => result.status === 'rejected')) {
    assert.equal(statusCode(result.reason), 412, 'losing conditional updates must return 412');
  }

  const listed = await client.send(
    new ListObjectsV2Command({ Bucket: bucket, Prefix: `${prefix}/` }),
  );
  assert.deepEqual(
    listed.Contents?.map((object) => object.Key).sort(),
    [key, raceKey].sort(),
    'prefix listing must include newly written objects',
  );
});
