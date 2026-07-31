const http = require("http");
const fs = require("fs");
const path = require("path");

const port = 8765;
const dist = "C:\\Users\\justi\\AppData\\Local\\Programs\\Green Rack Runner\\resources\\app\\dist";
const store = "C:\\Users\\justi\\AppData\\Local\\RackRunner\\green-rack-runner-sync-state.json";

function sendJson(res, code, body) {
  res.writeHead(code, {
    "content-type": "application/json",
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "content-type"
  });
  res.end(JSON.stringify(body));
}

http.createServer((req, res) => {
  if (req.method === "OPTIONS") return sendJson(res, 200, { ok: true });
  if (req.url.startsWith("/api/sync") && req.method === "GET") {
    if (!fs.existsSync(store)) return sendJson(res, 200, { ok: true, hasState: false, updatedAt: 0 });
    try { return sendJson(res, 200, Object.assign({ ok: true, hasState: true }, JSON.parse(fs.readFileSync(store, "utf8")))); }
    catch (e) { return sendJson(res, 500, { ok: false, error: e.message }); }
  }
  if (req.url === "/api/sync" && req.method === "POST") {
    let body = "";
    req.on("data", chunk => { body += chunk; if (body.length > 5000000) req.destroy(); });
    req.on("end", () => {
      try {
        const parsed = JSON.parse(body || "{}");
        fs.writeFileSync(store, JSON.stringify(Object.assign({ updatedAt: Date.now() }, parsed), null, 2));
        sendJson(res, 200, { ok: true });
      } catch (e) {
        sendJson(res, 400, { ok: false, error: e.message });
      }
    });
    return;
  }
  const rel = req.url === "/" ? "index.html" : decodeURIComponent(req.url.split("?")[0]).replace(/^\/+/, "");
  const target = path.normalize(path.join(dist, rel));
  if (!target.startsWith(dist)) return sendJson(res, 403, { ok: false });
  fs.readFile(target, (err, data) => {
    if (err) return sendJson(res, 404, { ok: false });
    const type = target.endsWith(".html") ? "text/html" : target.endsWith(".js") ? "text/javascript" : target.endsWith(".css") ? "text/css" : "application/octet-stream";
    res.writeHead(200, { "content-type": type });
    res.end(data);
  });
}).listen(port, "0.0.0.0", () => console.log(`Green Rack Runner sync: http://100.125.245.10:${port}/`));
