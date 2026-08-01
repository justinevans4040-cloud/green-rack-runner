const http = require("http");
const https = require("https");
const fs = require("fs");
const path = require("path");

const port = Number(process.env.RACK_RUNNER_PORT || 8765);
const dist = process.env.RACK_RUNNER_DIST || "C:\\Users\\justi\\AppData\\Local\\Programs\\Green Rack Runner\\resources\\app\\dist";
const store = process.env.RACK_RUNNER_STORE || "C:\\Users\\justi\\AppData\\Local\\RackRunner\\green-rack-runner-sync-state.json";
const brightDataEndpoint = "https://api.brightdata.com/request";
const maxBodyBytes = 5_000_000;

function sendJson(res, code, body) {
  res.writeHead(code, {
    "content-type": "application/json; charset=utf-8",
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "content-type,x-rack-runner-token"
  });
  res.end(JSON.stringify(body));
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", chunk => {
      body += chunk;
      if (Buffer.byteLength(body, "utf8") > maxBodyBytes) {
        reject(new Error("Request body is too large."));
        req.destroy();
      }
    });
    req.on("end", () => {
      try {
        resolve(JSON.parse(body || "{}"));
      } catch {
        reject(new Error("Request body must be valid JSON."));
      }
    });
    req.on("error", reject);
  });
}

function isAllowedWebUrl(value) {
  try {
    const target = new URL(value);
    return target.protocol === "http:" || target.protocol === "https:";
  } catch {
    return false;
  }
}

function isAuthorized(req) {
  const requiredToken = process.env.RACK_RUNNER_API_TOKEN;
  return !requiredToken || req.headers["x-rack-runner-token"] === requiredToken;
}

function callBrightData({ url, country, format = "raw" }) {
  const apiKey = process.env.BRIGHTDATA_API_KEY;
  const zone = process.env.BRIGHTDATA_ZONE || "rack_runner";

  if (!apiKey) throw new Error("BRIGHTDATA_API_KEY is not configured.");
  if (!zone) throw new Error("BRIGHTDATA_ZONE is not configured.");
  if (!isAllowedWebUrl(url)) throw new Error("A valid public HTTP or HTTPS URL is required.");
  if (!new Set(["raw", "json"]).has(format)) throw new Error("format must be raw or json.");

  const requestBody = JSON.stringify({
    zone,
    url,
    format,
    ...(country ? { flags: `country-${String(country).toLowerCase()}` } : {})
  });

  return new Promise((resolve, reject) => {
    const target = new URL(brightDataEndpoint);
    const upstream = https.request({
      hostname: target.hostname,
      path: target.pathname,
      method: "POST",
      headers: {
        "content-type": "application/json",
        "authorization": `Bearer ${apiKey}`,
        "content-length": Buffer.byteLength(requestBody)
      },
      timeout: 90_000
    }, upstreamResponse => {
      let body = "";
      upstreamResponse.setEncoding("utf8");
      upstreamResponse.on("data", chunk => { body += chunk; });
      upstreamResponse.on("end", () => {
        const contentType = String(upstreamResponse.headers["content-type"] || "text/plain");
        let data = body;
        if (contentType.includes("application/json")) {
          try { data = JSON.parse(body); } catch { data = body; }
        }
        resolve({
          ok: upstreamResponse.statusCode >= 200 && upstreamResponse.statusCode < 300,
          status: upstreamResponse.statusCode,
          responseId: upstreamResponse.headers["x-response-id"] || null,
          contentType,
          data
        });
      });
    });

    upstream.on("timeout", () => upstream.destroy(new Error("Bright Data request timed out.")));
    upstream.on("error", reject);
    upstream.write(requestBody);
    upstream.end();
  });
}

http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") return sendJson(res, 200, { ok: true });

  if (req.url.startsWith("/api/sync") && req.method === "GET") {
    if (!fs.existsSync(store)) return sendJson(res, 200, { ok: true, hasState: false, updatedAt: 0 });
    try {
      return sendJson(res, 200, Object.assign({ ok: true, hasState: true }, JSON.parse(fs.readFileSync(store, "utf8"))));
    } catch (error) {
      return sendJson(res, 500, { ok: false, error: error.message });
    }
  }

  if (req.url === "/api/sync" && req.method === "POST") {
    try {
      const parsed = await readJsonBody(req);
      fs.mkdirSync(path.dirname(store), { recursive: true });
      fs.writeFileSync(store, JSON.stringify(Object.assign({ updatedAt: Date.now() }, parsed), null, 2));
      return sendJson(res, 200, { ok: true });
    } catch (error) {
      return sendJson(res, 400, { ok: false, error: error.message });
    }
  }

  if (req.url === "/api/brightdata/unlock" && req.method === "POST") {
    if (!isAuthorized(req)) return sendJson(res, 401, { ok: false, error: "Unauthorized." });
    try {
      const payload = await readJsonBody(req);
      const result = await callBrightData(payload);
      return sendJson(res, result.ok ? 200 : 502, result);
    } catch (error) {
      return sendJson(res, 400, { ok: false, error: error.message });
    }
  }

  const rel = req.url === "/" ? "index.html" : decodeURIComponent(req.url.split("?")[0]).replace(/^\/+/, "");
  const target = path.normalize(path.join(dist, rel));
  if (!target.startsWith(path.normalize(dist))) return sendJson(res, 403, { ok: false });

  fs.readFile(target, (error, data) => {
    if (error) return sendJson(res, 404, { ok: false });
    const type = target.endsWith(".html") ? "text/html" : target.endsWith(".js") ? "text/javascript" : target.endsWith(".css") ? "text/css" : "application/octet-stream";
    res.writeHead(200, { "content-type": type });
    res.end(data);
  });
}).listen(port, "0.0.0.0", () => {
  console.log(`Green Rack Runner sync: http://0.0.0.0:${port}/`);
  console.log(`Bright Data endpoint: POST http://127.0.0.1:${port}/api/brightdata/unlock`);
});
