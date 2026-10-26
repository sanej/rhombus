CREATE TABLE products (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE features (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'idea',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX features_product ON features(product_id);
