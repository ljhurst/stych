import cf from 'cloudfront';

const store = cf.kvs();

function parse(host) {
  const match = /^(.+)-pr-(\d+)$/.exec(host.split('.')[0]);
  return match ? { project: match[1], pr: match[2] } : null;
}

function route(host, uri) {
  const preview = parse(host);
  if (preview === null || uri.includes('..')) {
    return null;
  }

  let path = uri;
  if (path.endsWith('/')) {
    path = `${path}index.html`;
  } else if (!path.split('/').pop().includes('.')) {
    path = `${path}/index.html`;
  }

  return `/${preview.project}/pr-${preview.pr}${path}`;
}

async function addPolicy(event) {
  const response = event.response;
  const preview = parse(event.request.headers.host.value);

  if (preview !== null) {
    try {
      response.headers['content-security-policy'] = { value: await store.get(preview.project) };
    } catch (_error) {
      // A project without a stored policy is served without one rather than failing the page.
    }
  }

  return response;
}

function routeRequest(event) {
  const request = event.request;
  const key = route(request.headers.host.value, request.uri);

  if (key === null) {
    return { statusCode: 404, statusDescription: 'Not Found' };
  }

  request.uri = key;
  return request;
}

// biome-ignore lint/correctness/noUnusedVariables: CloudFront invokes handler by name
async function handler(event) {
  return event.context.eventType === 'viewer-response' ? addPolicy(event) : routeRequest(event);
}
