CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name text NOT NULL,
    email text NOT NULL UNIQUE,
    password text NOT NULL
);

CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    title text NOT NULL,
    content text NOT NULL,
    published BOOLEAN NOT NULL DEFAULT FALSE,
    author_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE comments (
    user_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    post_id INTEGER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    content text NOT NULL,
    PRIMARY KEY (user_id, post_id)
);
