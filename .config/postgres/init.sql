CREATE DB coredu;
CREATE USER coredu WITH PASSWORD 'coredu_pass';
ALTER DATABASE coredu OWNER TO coredu;


CREATE TYPE unit_type AS ENUM ('movie', 'season', 'tv', 'ova', 'ona', 'special', 'documentary');
CREATE TYPE relation_type AS ENUM ('prequel', 'sequel', 'spinoff', 'side_story');

CREATE TABLE Users (
    id SERIAL PRIMARY KEY,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    cat TIMESTAMP DEFAULT now()
);

CREATE TABLE Words (
    word TEXT PRIMARY KEY,
    cat TIMESTAMP DEFAULT now()
);

CREATE TABLE Senses (
    sense TEXT PRIMARY KEY,
    cat TIMESTAMP DEFAULT now()
);

CREATE TABLE Sensepins (
    wid INT REFERENCES Words(id) ON DELETE CASCADE,
    sid INT REFERENCES Senses(id) ON DELETE CASCADE,
    PRIMARY KEY (wid, sid)
);

CREATE TABLE Franchises (
    id INT PRIMARY KEY,
    title TEXT,
    dsc TEXT,
    score REAL,
    air DATE NOT NULL,
    cat TIMESTAMP DEFAULT NOW()
);

CREATE TABLE Units (
    id INT PRIMARY KEY,
    fid INT REFERENCES Franchises(id) ON DELETE CASCADE,
    type unit_type NOT NULL,
    chnum SMALLINT NOT NULL,
    num SMALLINT NOT NULL,
    title TEXT NOT NULL,
    dsc TEXT,
    eps SMALLINT,
    score REAL,
    air DATE,
    cat TIMESTAMP DEFAULT NOW(),
    UNIQUE (fid, chnum),
    UNIQUE (fid, type, num)
);

CREATE TABLE Episodes (
    fid INT REFERENCES Franchises(id) ON DELETE CASCADE,
    uid INT REFERENCES Units(id) ON DELETE CASCADE,
    chnum SMALLINT NOT NULL,
    num SMALLINT NOT NULL,
    title TEXT,
    dsc TEXT,
    score REAL,
    air DATE,
    cat TIMESTAMP DEFAULT NOW(),
    UNIQUE (fid, chnum),
    PRIMARY KEY (uid, num)
);

CREATE TABLE Progresses (
    uid INT REFERENCES Users(id) ON DELETE CASCADE,
    fid INT REFERENCES Franchises(id) ON DELETE CASCADE,
    chnum SMALLINT DEFAULT 1,
    fins SMALLINT DEFAULT 0,
    PRIMARY KEY (uid, fid)
);

CREATE TABLE Relations (
    source SMALLINT REFERENCES Units(id) ON DELETE CASCADE,
    target SMALLINT REFERENCES Units(id) ON DELETE CASCADE,
    relation relation_type NOT NULL,
    PRIMARY KEY (source, target)
);

CREATE TABLE Views (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usid SMALLINT REFERENCES Users(id) ON DELETE CASCADE,
    unid INT REFERENCES Episodes(fid) ON DELETE CASCADE,
    num INT REFERENCES Episodes(num) ON DELETE CASCADE,
    cat TIMESTAMP DEFAULT NOW()
);

CREATE TABLE Ratings (
    uid SMALLINT REFERENCES Users(id) ON DELETE CASCADE,
    fid INT REFERENCES Franchises(id) ON DELETE CASCADE,
    score REAL NOT NULL CHECK (score BETWEEN 0 and 10),
    cat TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (uid, fid)
);

CREATE TABLE Examples (
    id INT PRIMARY KEY,
    fid INT REFERENCES Franchises(id) ON DELETE CASCADE,
    uid INT,
    num SMALLINT,
    exampe TEXT NOT NULL,
    cat TIMESTAMP DEFAULT now(),
    FOREIGN KEY (uid, num) REFERENCES Episodes(uid, num) ON DELETE CASCADE
);

CREATE TABLE Examplepins (
    wid INT REFERENCES Words(id) ON DELETE CASCADE,
    eid INT REFERENCES Examples(id) ON DELETE CASCADE,
    PRIMARY KEY (wid, eid)
);

CREATE TABLE Answers (
    uid INT REFERENCES Users(id) ON DELETE CASCADE,
    wid BIGINT REFERENCES Words(id) ON DELETE CASCADE,
    score REAL NOT NULL,
    cat TIMESTAMP PRIMARY KEY DEFAULT now()
);

CREATE OR REPLACE FUNCTION get_units (
    in_offset INT DEFAULT 0,
    in_limit  INT DEFAULT 30,
    in_email TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    usr_id INT;
    result JSON;
BEGIN
    IF in_email IS NOT NULL THEN
        SELECT id INTO usr_id
        FROM Users
        WHERE email = in_email;
    END IF;

    IF usr_id IS NOT NULL THEN
        SELECT json_agg(
            json_build_object(
                'id', f.id,
                'title', f.title,
                'dsc', f.dsc,
                'score', f.score,

                'next', COALESCE(
                    (
                        SELECT json_build_object(
                            'num', e.num,
                            'title', e.title,
                            'unit', e.uid
                        )
                        FROM Progresses pr
                        JOIN Episodes e
                          ON e.fid = pr.fid
                         AND e.chnum = pr.chnum
                        WHERE pr.fid = f.id
                          AND pr.uid = usr_id
                        LIMIT 1
                    ),
                    (
                        SELECT json_build_object(
                            'num', e.num,
                            'title', e.title,
                            'unit', e.uid
                        )
                        FROM Episodes e
                        WHERE e.fid = f.id
                        ORDER BY e.chnum
                        LIMIT 1
                    )
                ),

                'fins', COALESCE(
                    (
                        SELECT pr.fins
                        FROM Progresses pr
                        WHERE pr.fid = f.id
                          AND pr.uid = usr_id
                    ),
                    0
                )
            )
        )
        INTO result
        FROM (
            SELECT *
            FROM Franchises
            ORDER BY score DESC NULLS LAST, id ASC
            OFFSET in_offset
            LIMIT in_limit
        ) f;

    ELSE
        SELECT json_agg(
            json_build_object(
                'id', f.id,
                'title', f.title,
                'dsc', f.dsc,
                'score', f.score,
                'next',
                    (
                        SELECT json_build_object(
                            'num', e.num,
                            'title', e.title,
                            'unit', e.uid
                        )
                        FROM Episodes e
                        WHERE e.fid = f.id
                        ORDER BY e.chnum
                        LIMIT 1
                    ),
                'fins', 0
            )
        )
        INTO result
        FROM (
            SELECT *
            FROM Franchises
            ORDER BY score DESC NULLS LAST, id ASC
            OFFSET in_offset
            LIMIT in_limit
        ) f;
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION next_word(
  p_user_id BIGINT,
  p_limit INT DEFAULT 1
)
RETURNS TABLE(word_id BIGINT) AS $$
BEGIN
  RETURN query
  WITH stats AS (
    SELECT
      wp.word_id,
      w.difficulty,
      wp.mastery,
      wp.confidence,
      wp.attempts,
      wp.attempts_since_last,

      -- uncertainty
      1.0 / sqrt(wp.attempts + 1) as uncertainty,

      -- neglect по попыткам
      ln(wp.attempts_since_last + 1) as neglect,

      -- entropy
      CASE
	WHEN wp.mastery <= 0 OR wp.mastery >= 1 THEN 0
	ELSE -wp.mastery * ln(wp.mastery)
             - (1 - wp.mastery) * ln(1 - wp.mastery)
      END AS entropy
    FROM word_progress wp
    JOIN words w ON w.id = wp.word_id
    WHERE wp.user_id = p_user_id
  )
  SELECT word_id
  FROM stats
  ORDER BY
    difficulty
    * (1 - mastery)
    * entropy
    * uncertainty
    * neglect DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION submit_answer(
  p_user_id BIGINT,
  p_word_id BIGINT,
  p_correct BOOLEAN,
  p_response_time REAL
)
RETURNS VOID AS $$
DECLARE
  v_score REAL;
  v_alpha REAL;
BEGIN
  -- считаем score
  IF NOT p_correct THEN
    v_score := 0;
  ELSE
    IF p_response_time <= 2 THEN
      v_score := 1 - (p_response_time / 4); -- 1.0 .. 0.5
    ELSIF p_response_time < 4 THEN
      v_score := (4 - p_response_time) / 4; -- 0.5 .. 0.0
    ELSE
      v_score := 0;
    END IF;
  END IF;

  UPDATE word_progress
  SET
    attempts = attempts + 1,
    attempts_since_last = 0,

    -- confidence растёт всегда
    confidence = confidence + 0.1 * (1 - confidence),

    -- adaptive alpha
    mastery = mastery * (1 - (0.05 + 0.1 * confidence))
              + v_score * (0.05 + 0.1 * confidence)
  WHERE user_id = p_user_id
    AND word_id = p_word_id;

  -- все остальные слова считаем "пропущенными"
  UPDATE word_progress
  SET attempts_since_last = attempts_since_last + 1
  WHERE user_id = p_user_id
    AND word_id <> p_word_id;
END;
$$ LANGUAGE plpgsql STABLE;

