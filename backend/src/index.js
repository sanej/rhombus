export const STATUSES = ["idea", "planned", "inProgress", "blocked", "done"];

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json" } });

const clean = (s) => (typeof s === "string" ? s.trim().slice(0, 200) : "");

function authorized(request, env) {
  const header = request.headers.get("authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!env.API_TOKEN || token.length !== env.API_TOKEN.length) return false;
  let diff = 0;
  for (let i = 0; i < token.length; i++) diff |= token.charCodeAt(i) ^ env.API_TOKEN.charCodeAt(i);
  return diff === 0;
}

export async function handle(request, env) {
  if (!authorized(request, env)) return json({ error: "unauthorized" }, 401);
  const url = new URL(request.url);
  const parts = url.pathname.split("/").filter(Boolean); // ["api", ...]
  if (parts[0] !== "api") return json({ error: "not found" }, 404);
  const db = env.DB;
  const now = new Date().toISOString();
  let body = {};
  if (request.method === "POST" || request.method === "PATCH") {
    try { body = await request.json(); } catch { return json({ error: "invalid json" }, 400); }
  }

  if (parts[1] === "state" && request.method === "GET") {
    const products = await db.prepare("SELECT id, name, created_at AS createdAt FROM products ORDER BY created_at").all();
    const features = await db.prepare(
      "SELECT id, product_id AS productId, title, status, updated_at AS updatedAt FROM features ORDER BY created_at").all();
    return json({ products: products.results, features: features.results });
  }

  if (parts[1] === "products") {
    if (parts.length === 2 && request.method === "POST") {
      const name = clean(body.name);
      if (!name) return json({ error: "name required" }, 400);
      const id = crypto.randomUUID();
      await db.prepare("INSERT INTO products (id, name, created_at) VALUES (?, ?, ?)").bind(id, name, now).run();
      return json({ id, name, createdAt: now }, 201);
    }
    if (parts.length === 3 && request.method === "DELETE") {
      await db.prepare("DELETE FROM features WHERE product_id = ?").bind(parts[2]).run();
      await db.prepare("DELETE FROM products WHERE id = ?").bind(parts[2]).run();
      return json({ ok: true });
    }
  }

  if (parts[1] === "features") {
    if (parts.length === 2 && request.method === "POST") {
      const title = clean(body.title);
      const status = body.status ?? "idea";
      if (!title || !clean(body.productId)) return json({ error: "title and productId required" }, 400);
      if (!STATUSES.includes(status)) return json({ error: "invalid status" }, 400);
      const product = await db.prepare("SELECT id FROM products WHERE id = ?").bind(body.productId).first();
      if (!product) return json({ error: "product not found" }, 404);
      const id = crypto.randomUUID();
      await db.prepare(
        "INSERT INTO features (id, product_id, title, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)")
        .bind(id, body.productId, title, status, now, now).run();
      return json({ id, productId: body.productId, title, status, updatedAt: now }, 201);
    }
    if (parts.length === 3 && request.method === "PATCH") {
      if (!STATUSES.includes(body.status)) return json({ error: "invalid status" }, 400);
      const res = await db.prepare("UPDATE features SET status = ?, updated_at = ? WHERE id = ?")
        .bind(body.status, now, parts[2]).run();
      if (res.meta && res.meta.changes === 0) return json({ error: "not found" }, 404);
      return json({ id: parts[2], status: body.status, updatedAt: now });
    }
    if (parts.length === 3 && request.method === "DELETE") {
      await db.prepare("DELETE FROM features WHERE id = ?").bind(parts[2]).run();
      return json({ ok: true });
    }
  }
  return json({ error: "not found" }, 404);
}

export default { fetch: (request, env) => handle(request, env) };
