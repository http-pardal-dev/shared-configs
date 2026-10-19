-- database.sql
--
-- Shared schema of the API implemented by both projects (node-express and
-- ruby-sinatra). The three resources are users, products and payments, and
-- there are no relations between them.
--
-- Dialect: SQLite. Both projects store their data in SQLite; each one maps its
-- own ORM types onto these columns (see the per-project notes below).
--
-- Differences preserved between implementations:
--   node-express (Prisma):  TEXT / DATETIME ... DEFAULT CURRENT_TIMESTAMP,
--                           unique index created separately (users_email_key).
--   ruby-sinatra (ActiveRecord): VARCHAR / DATE / DECIMAL(10, 2),
--                           CONSTRAINT ... UNIQUE inline, no column defaults.

PRAGMA foreign_keys = OFF;

-- users
--
-- password_digest is the only form of the password that is stored (bcrypt).
-- `password` and `password_confirmation` are virtual attributes and have no
-- column. The unique index is the last line of defence for the email: the
-- application validates uniqueness, but only the database can refuse a
-- duplicate when two requests are validated at the same time.
CREATE TABLE users (
    id              INTEGER     PRIMARY KEY AUTOINCREMENT,
    name            TEXT        NOT NULL,
    email           TEXT        NOT NULL,
    password_digest TEXT        NOT NULL,
    role            TEXT        NOT NULL DEFAULT 'user',
    active          BOOLEAN     NOT NULL DEFAULT true,
    birthdate       DATETIME,
    created_at      DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME    NOT NULL
);

CREATE UNIQUE INDEX users_email_key ON users(email);

-- products
--
-- price is stored as a DECIMAL (SQLite NUMERIC affinity) and serialized to the
-- client as text, never as a JSON number.
CREATE TABLE products (
    id          INTEGER  PRIMARY KEY AUTOINCREMENT,
    name        TEXT     NOT NULL,
    description TEXT,
    category    TEXT     NOT NULL,
    price       DECIMAL  NOT NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME NOT NULL
);

-- payments
--
-- status is the state of the payment. It starts as 'pending' and only moves to
-- 'paid' (confirm) or 'cancelled' (cancel); there is no other transition.
CREATE TABLE payments (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    amount     DECIMAL NOT NULL,
    status     TEXT    NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL
);