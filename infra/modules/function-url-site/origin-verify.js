import cf from 'cloudfront';

const store = cf.kvs();

// biome-ignore lint/correctness/noUnusedVariables: CloudFront invokes handler by name
async function handler(event) {
  const request = event.request;

  delete request.headers['x-origin-verify'];
  request.headers['x-viewer-ip'] = { value: event.viewer.ip };

  try {
    request.headers['x-origin-verify'] = { value: await store.get(request.headers.host.value) };
  } catch (_error) {
    // A host without a secret sends none, so the origin refuses the request instead of the edge failing it.
  }

  return request;
}
