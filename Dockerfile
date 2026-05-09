FROM node:22-bookworm-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
  git curl ca-certificates jq \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://install.iii.dev/iii/main/install.sh | sh
RUN cp ~/.local/bin/iii /usr/local/bin/iii || cp /root/.local/bin/iii /usr/local/bin/iii

RUN git clone https://github.com/rohitg00/agentmemory.git .
RUN node - <<'NODE'
const fs = require('fs');

let text = fs.readFileSync('/app/src/config.ts', 'utf8');
text = text.replace(
`  if (hasRealValue(env["OPENROUTER_API_KEY"])) {
    return {
      provider: "openrouter",
      model: env["OPENROUTER_MODEL"] || "anthropic/claude-sonnet-4-20250514",
      maxTokens,
    };
  }
`,
`  if (hasRealValue(env["OPENROUTER_API_KEY"]) || hasRealValue(env["OPENAI_API_KEY"])) {
    return {
      provider: "openrouter",
      model:
        env["OPENROUTER_MODEL"] ||
        env["COMPRESSION_MODEL"] ||
        env["OPENAI_MODEL"] ||
        "anthropic/claude-sonnet-4-20250514",
      maxTokens,
      baseURL:
        env["OPENROUTER_BASE_URL"] ||
        env["OPENAI_BASE_URL"] ||
        "https://openrouter.ai/api/v1/chat/completions",
    };
  }
`
);
text = text.replace(
`    hasRealValue(env["OPENROUTER_API_KEY"]) ||
`,
`    hasRealValue(env["OPENROUTER_API_KEY"]) ||
    hasRealValue(env["OPENAI_API_KEY"]) ||
`
);
fs.writeFileSync('/app/src/config.ts', text);

text = fs.readFileSync('/app/src/providers/index.ts', 'utf8');
text = text.replace(
`    case "openrouter":
      return new OpenRouterProvider(
        requireEnvVar("OPENROUTER_API_KEY"),
        config.model,
        config.maxTokens,
        "https://openrouter.ai/api/v1/chat/completions",
      );
`,
`    case "openrouter":
      return new OpenRouterProvider(
        getEnvVar("OPENROUTER_API_KEY") || requireEnvVar("OPENAI_API_KEY"),
        config.model,
        config.maxTokens,
        config.baseURL ||
          getEnvVar("OPENROUTER_BASE_URL") ||
          getEnvVar("OPENAI_BASE_URL") ||
          "https://openrouter.ai/api/v1/chat/completions",
      );
`
);
fs.writeFileSync('/app/src/providers/index.ts', text);

text = fs.readFileSync('/app/src/providers/openrouter.ts', 'utf8');
text = text.replace(
`      body: JSON.stringify({
        model: this.model,
        max_tokens: this.maxTokens,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      }),
`,
`      body: JSON.stringify({
        model: this.model,
        max_tokens: this.maxTokens,
        stream: false,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      }),
`
);
fs.writeFileSync('/app/src/providers/openrouter.ts', text);

text = fs.readFileSync('/app/src/viewer/server.ts', 'utf8');
text = text.replace(
'  server.listen(port, "127.0.0.1", () => {\n    console.log(`[agentmemory] Viewer: http://localhost:${port}`);\n  });\n',
'  server.listen(port, "0.0.0.0", () => {\n    console.log(`[agentmemory] Viewer: http://0.0.0.0:${port}`);\n  });\n'
);
text = text.replace(
`    try {
      await proxyToRestApi(resolvedRestPort, pathname, qs, method, req, res, secret);
    } catch (err) {
`,
`    try {
      if (pathname === '/viewer/ws') {
        json(res, 426, { error: 'upgrade required' }, req);
        return;
      }
      const proxiedPath = pathname.startsWith('/viewer/api/')
        ? '/agentmemory/' + pathname.slice('/viewer/api/'.length)
        : pathname;
      await proxyToRestApi(resolvedRestPort, proxiedPath, qs, method, req, res, secret);
    } catch (err) {
`
);
text = text.replace(
`  server.on("error", (err: NodeJS.ErrnoException) => {
`,
`  server.on('upgrade', async (req, socket) => {
    const raw = req.url || '/';
    const qIdx = raw.indexOf('?');
    const pathname = qIdx >= 0 ? raw.slice(0, qIdx) : raw;
    const qs = qIdx >= 0 ? raw.slice(qIdx + 1) : '';
    const targetPath = pathname === '/viewer/ws' ? '/' : null;
    if (!targetPath) {
      socket.destroy();
      return;
    }
    try {
      const net = await import('node:net');
      const upstreamPort = resolvedRestPort + 1;
      const upstream = net.connect(upstreamPort, '127.0.0.1', () => {
        const lines = [
          'GET ' + targetPath + (qs ? '?' + qs : '') + ' HTTP/1.1',
          'Host: 127.0.0.1:' + upstreamPort,
          'Connection: Upgrade',
          'Upgrade: websocket',
        ];
        const pass = [
          'sec-websocket-key',
          'sec-websocket-version',
          'sec-websocket-protocol',
          'sec-websocket-extensions',
          'origin',
          'pragma',
          'cache-control',
          'user-agent'
        ];
        for (const key of pass) {
          const val = req.headers[key];
          if (typeof val === 'string') lines.push(key + ': ' + val);
        }
        lines.push('', '');
        upstream.write(lines.join('\\r\\n'));
      });
      upstream.on('error', () => socket.destroy());
      socket.on('error', () => upstream.destroy());
      upstream.pipe(socket);
      socket.pipe(upstream);
    } catch {
      socket.destroy();
    }
  });

  server.on("error", (err: NodeJS.ErrnoException) => {
`
);
fs.writeFileSync('/app/src/viewer/server.ts', text);

text = fs.readFileSync('/app/src/viewer/index.html', 'utf8');
text = text.replace(
`    var params = new URLSearchParams(window.location.search);
    var viewerPort = params.get('port') || window.location.port || '3113';
    var iiiPort = parseInt(viewerPort);
    if (iiiPort === 3111) viewerPort = '3113';
    var REST = window.location.protocol + '//' + window.location.hostname + ':' + viewerPort;
    var wsProto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    var wsPort = params.get('wsPort') || String(parseInt(viewerPort) - 1);
    var WS_URL = wsProto + '//' + window.location.hostname + ':' + wsPort;
    var WS_DIRECT_URL = wsProto + '//' + window.location.hostname + ':' + wsPort + '/stream/mem-live/viewer';
`,
`    var params = new URLSearchParams(window.location.search);
    var VIEWER_BASE = (function() {
      var path = window.location.pathname || '/viewer';
      if (path === '/' || path === '') return '/viewer';
      return path.replace(/\/+$/, '');
    })();
    var REST = window.location.origin + VIEWER_BASE;
    var wsProto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    var WS_URL = wsProto + '//' + window.location.host + VIEWER_BASE + '/ws';
    var WS_DIRECT_URL = WS_URL;
`
);
text = text.replace(
`        var url = REST + '/agentmemory/' + path;
`,
`        var url = REST + '/api/' + path;
`
);
text = text.replace(
`          if (!ws.__direct) {
            ws.send(JSON.stringify({
              type: 'join',
              data: {
                subscriptionId: 'viewer-' + Date.now(),
                streamName: 'mem-live',
                groupId: 'viewer'
              }
            }));
          }
`,
`          ws.send(JSON.stringify({
            type: 'join',
            data: {
              subscriptionId: 'viewer-' + Date.now(),
              streamName: 'mem-live',
              groupId: 'viewer'
            }
          }));
`
);
text = text.replace(
`    function connectWs() {
      startPolling();
      return;
`,
`    function connectWs() {
`
);
fs.writeFileSync('/app/src/viewer/index.html', text);

text = fs.readFileSync('/app/iii-config.yaml', 'utf8');
text = text.replace(/host: 127\.0\.0\.1/g, 'host: 0.0.0.0');
text = text.replace(
`  - name: iii-exec
    config:
      watch:
        - src/**/*.ts
      exec:
        - node dist/index.mjs
`,
''
);
fs.writeFileSync('/app/iii-config.yaml', text);
NODE
RUN npm install
RUN npm run build

EXPOSE 3111 3113

CMD ["node", "dist/cli.mjs"]
