PRAGMA foreign_keys = ON;
CREATE TABLE creators (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE
);
CREATE TABLE artworks (
    id TEXT PRIMARY KEY,
    owner TEXT NOT NULL REFERENCES creators(id),
    operation TEXT NOT NULL,
    digest TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    tags TEXT NOT NULL,
    asset TEXT NOT NULL,
    thumbnail TEXT NOT NULL,
    created INTEGER NOT NULL,
    visible INTEGER NOT NULL DEFAULT 1,
    UNIQUE (owner, operation)
);
CREATE INDEX gallery_order ON artworks(visible, created DESC, id);
CREATE TABLE reports (
    artwork TEXT NOT NULL REFERENCES artworks(id),
    reporter TEXT NOT NULL REFERENCES creators(id),
    reason TEXT NOT NULL,
    PRIMARY KEY (artwork, reporter)
);
