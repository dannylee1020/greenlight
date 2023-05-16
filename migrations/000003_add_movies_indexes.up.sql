CREATE INDEX IF NOT EXISTS movies_title_idx ON movies USING GIN (to_tsvector('simple', title));

CREATE INDEX IF NOT EXISTS movie_genres_idx on movies USING GIN (genres)