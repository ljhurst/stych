const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const policies = { fife: "default-src 'self'" };
const sandbox = {
  cf: {
    kvs: () => ({
      get: async (key) => {
        if (!(key in policies)) {
          throw new Error('key not found');
        }
        return policies[key];
      },
    }),
  },
};
const source = fs.readFileSync(path.join(__dirname, 'router.js'), 'utf8').replace(/^import .*\n/m, '');
vm.runInNewContext(source, sandbox);

const host = (label) => `${label}.preview.bylukehurst.com`;

test('maps a preview host to the project and pull request prefix', () => {
  assert.equal(sandbox.route(host('bracket-clash-pr-12'), '/assets/app.js'), '/bracket-clash/pr-12/assets/app.js');
});

test('keeps hyphens in the project name', () => {
  assert.equal(sandbox.route(host('train-spotting-pr-3'), '/style.css'), '/train-spotting/pr-3/style.css');
});

test('serves index.html for the root and for directories', () => {
  assert.equal(sandbox.route(host('fife-pr-7'), '/'), '/fife/pr-7/index.html');
  assert.equal(sandbox.route(host('fife-pr-7'), '/about'), '/fife/pr-7/about/index.html');
  assert.equal(sandbox.route(host('fife-pr-7'), '/about/'), '/fife/pr-7/about/index.html');
});

test('rejects hosts that are not a project and pull request', () => {
  assert.equal(sandbox.route(host('fife'), '/'), null);
  assert.equal(sandbox.route(host('fife-pr-x'), '/'), null);
  assert.equal(sandbox.route(host('-pr-4'), '/'), null);
});

test('rejects paths that climb out of the prefix', () => {
  assert.equal(sandbox.route(host('fife-pr-7'), '/../other-pr-1/index.html'), null);
});

const requestEvent = (label, uri = '/') => ({
  context: { eventType: 'viewer-request' },
  request: { uri, headers: { host: { value: host(label) } } },
});

const responseEvent = (label) => ({
  context: { eventType: 'viewer-response' },
  request: { uri: '/fife/pr-7/index.html', headers: { host: { value: host(label) } } },
  response: { statusCode: 200, headers: {} },
});

test('answers 404 for a host it cannot route', async () => {
  const response = await sandbox.handler(requestEvent('nope'));
  assert.equal(response.statusCode, 404);
});

test('rewrites the request uri for a routable host', async () => {
  const request = await sandbox.handler(requestEvent('fife-pr-7'));
  assert.equal(request.uri, '/fife/pr-7/index.html');
});

test("adds the project's stored content security policy to the response", async () => {
  const response = await sandbox.handler(responseEvent('fife-pr-7'));
  assert.equal(response.headers['content-security-policy'].value, "default-src 'self'");
});

test('serves the response unchanged when the project has no stored policy', async () => {
  const response = await sandbox.handler(responseEvent('train-spotting-pr-3'));
  assert.deepEqual(response.headers, {});
});
