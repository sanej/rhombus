import { test } from "node:test";
import assert from "node:assert/strict";
import { handle } from "../src/index.js";

function fakeDB() {
  const products = [], features = [];
  return {
    prepare(sql) {
      let args = [];
      const stmt = {
        bind(...a) { args = a; return stmt; },
        async run() {
          if (sql.startsWith("INSERT INTO products")) products.push({ id: args[0], name: args[1] });
          else if (sql.startsWith("INSERT INTO features")) features.push({ id: args[0], status: args[3] });
          else if (sql.startsWith("UPDATE features")) {
            const f = features.find((x) => x.id === args[2]);
            if (f) f.status = args[0];
            return { meta: { changes: f ? 1 : 0 } };
          }
          return { meta: { changes: 1 } };
        },
        async first() { return products.find((p) => p.id === args[0]) ?? null; },
        async all() { return { results: sql.includes("FROM products") ? products : features }; },
      };
      return stmt;
    },
  };
}

const env = () => ({ API_TOKEN: "secret", DB: fakeDB() });
const req = (path, method = "GET", body, token = "secret") =>
  new Request("https://x" + path, {
    method, body: body ? JSON.stringify(body) : undefined,
    headers: { authorization: "Bearer " + token },
  });

test("rejects bad token", async () => {
  assert.equal((await handle(req("/api/state", "GET", undefined, "nope"), env())).status, 401);
});

test("product and feature lifecycle", async () => {
  const e = env();
  const p = await (await handle(req("/api/products", "POST", { name: " Orbit " }), e)).json();
  assert.equal(p.name, "Orbit");
  const fr = await handle(req("/api/features", "POST", { productId: p.id, title: "Voice login" }), e);
  assert.equal(fr.status, 201);
  const f = await fr.json();
  assert.equal(f.status, "idea");
  assert.equal((await handle(req(`/api/features/${f.id}`, "PATCH", { status: "done" }), e)).status, 200);
  assert.equal((await handle(req(`/api/features/${f.id}`, "PATCH", { status: "bogus" }), e)).status, 400);
  const state = await (await handle(req("/api/state"), e)).json();
  assert.equal(state.features[0].status, "done");
});

test("feature requires existing product", async () => {
  const r = await handle(req("/api/features", "POST", { productId: "zzz", title: "x" }), env());
  assert.equal(r.status, 404);
});
