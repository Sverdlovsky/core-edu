CREATE DB coredu;
CREATE USER coredu WITH PASSWORD 'coredu_pass';
ALTER DATABASE coredu OWNER TO coredu;


CREATE TYPE unit_type AS ENUM ('movie', 'season', 'tv', 'ova', 'ona', 'special', 'documentary');
CREATE TYPE relation_type AS ENUM ('prequel', 'sequel', 'spinoff', 'side_story');

CREATE TABLE Users (
    id SERIAL PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    cat TIMESTAMP DEFAULT now()
);
CREATE INDEX idx_users_email ON users(email);

CREATE TABLE Words (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    word TEXT UNIQUE,
    read TEXT,
    extra JSONB,
    lang TEXT,
    cat TIMESTAMP DEFAULT now()
);

CREATE TABLE Senses (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sense TEXT UNIQUE,
    cat TIMESTAMP DEFAULT now()
);

CREATE TABLE Word_Sense_Links (
    wid INT REFERENCES Words(id) ON DELETE CASCADE,
    sid INT REFERENCES Senses(id) ON DELETE CASCADE,
    PRIMARY KEY (wid, sid)
);

CREATE TABLE Franchises (
    id INT PRIMARY KEY,
    title TEXT,
    read TEXT,
    extra JSONB,
    lang TEXT,
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
    read TEXT,
    extra JSONB,
    lang TEXT,
    dsc TEXT,
    eps SMALLINT,
    score REAL,
    air DATE,
    cat TIMESTAMP DEFAULT NOW(),
    UNIQUE (fid, chnum),
    UNIQUE (fid, type, num)
);

CREATE TABLE Episodes (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fid INT REFERENCES Franchises(id) ON DELETE CASCADE,
    uid INT REFERENCES Units(id) ON DELETE CASCADE,
    chnum SMALLINT NOT NULL,
    num SMALLINT NOT NULL,
    br BOOLEAN DEFAULT False,
    title TEXT,
    read TEXT,
    extra JSONB,
    lang TEXT,
    dsc TEXT,
    score REAL,
    air DATE,
    cat TIMESTAMP DEFAULT NOW(),
    UNIQUE (fid, chnum),
    UNIQUE (uid, num)
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
    uid SMALLINT REFERENCES Users(id) ON DELETE CASCADE,
    eid INT REFERENCES Episodes(id) ON DELETE CASCADE,
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
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    eid INT REFERENCES Episodes(id),
    example TEXT NOT NULL,
    read TEXT,
    extra JSONB,
    lang TEXT,
    cat TIMESTAMP DEFAULT now()
);

CREATE TABLE Example_Word_Links (
    eid INT REFERENCES Examples(id) ON DELETE CASCADE,
    wid INT REFERENCES Words(id) ON DELETE CASCADE,
    PRIMARY KEY (wid, eid)
);
CREATE INDEX idx_ewl_wid ON example_word_links(wid);

CREATE TABLE Answers (
    uid INT REFERENCES Users(id) ON DELETE CASCADE,
    wid BIGINT REFERENCES Words(id) ON DELETE CASCADE,
    score REAL NOT NULL,
    cat TIMESTAMP PRIMARY KEY DEFAULT now()
);
CREATE INDEX idx_answers_uid ON answers(uid);
CREATE INDEX idx_answers_uid_wid ON answers(uid, wid);

CREATE TABLE Word_Progress (
    user_id INT REFERENCES Users(id) ON DELETE CASCADE,
    word_id BIGINT REFERENCES Words(id) ON DELETE CASCADE,
    mastery REAL DEFAULT 0,
    confidence REAL DEFAULT 0,
    attempts INT DEFAULT 0,
    attempts_since_last INT DEFAULT 0,
    PRIMARY KEY (user_id, word_id)
);
CREATE INDEX idx_wp_user ON word_progress(user_id);
CREATE INDEX idx_wp_user_word ON word_progress(user_id, word_id);

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

CREATE OR REPLACE FUNCTION init_user_progress(v_user_id BIGINT)
RETURNS VOID AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM word_progress WHERE user_id = v_user_id
  ) THEN
    RETURN;
  END IF;

  INSERT INTO word_progress (user_id, word_id)
  SELECT v_user_id, wf.wid
  FROM word_frequency wf
  ORDER BY wf.freq DESC
  LIMIT 10;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION next_word(
  p_email TEXT,
  p_limit INT DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_user_id BIGINT;
  result JSONB;
BEGIN
  SELECT id INTO v_user_id FROM users WHERE email = p_email;

  PERFORM init_user_progress(v_user_id);

  WITH
  stats AS (
    SELECT
      wp.word_id,
      --w.difficulty,
      wp.mastery,
      wp.confidence,
      wp.attempts,
      wp.attempts_since_last,

      1.0 / sqrt(wp.attempts + 1) as uncertainty,

      ln(wp.attempts_since_last + 1) as neglect,

      CASE 
        WHEN wp.mastery <= 0 OR wp.mastery >= 1 THEN 0
        ELSE -wp.mastery * ln(wp.mastery) - (1 - wp.mastery) * ln(1 - wp.mastery)
      END AS entropy
    FROM word_progress wp
    --JOIN words w ON w.id = wp.word_id
    WHERE wp.user_id = v_user_id
  ),

  selected AS (
    SELECT word_id
    FROM stats
    ORDER BY
      --difficulty
      (1 - mastery)
      * entropy
      * uncertainty
      * neglect DESC
    LIMIT p_limit
  ),

  random_example AS (
    SELECT DISTINCT ON (ewl.wid)
      ewl.wid,
      e.id,
      e.example,
      e.extra
    FROM example_word_links ewl
    JOIN examples e ON e.id = ewl.eid
    ORDER BY ewl.wid, random()
  ),

  senses_agg AS (
    SELECT
      wsl.wid,
      JSONB_AGG(s.sense) AS senses
    FROM word_sense_links wsl
    JOIN senses s ON s.id = wsl.sid
    GROUP BY wsl.wid
  )

  SELECT jsonb_build_object(
    'lang', w.lang,

    'word', jsonb_build_object(
      'id', w.id,
      'text', w.word,
      'extra', w.extra
    ),

    'example', jsonb_build_object(
      'id', re.id,
      'text', re.example,
      'extra', re.extra
    ),

    'senses', COALESCE(sa.senses, '[]'::jsonb)
  )
  INTO result
  FROM selected s1
  JOIN words w ON w.id = s1.word_id
  LEFT JOIN random_example re ON re.wid = w.id
  LEFT JOIN senses_agg sa ON sa.wid = w.id;

  RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION submit_answer(
  p_email TEXT,
  p_word_id BIGINT,
  p_response_time REAL
)
RETURNS VOID AS $$
DECLARE
  v_user_id BIGINT;
  v_score REAL;
BEGIN
  SELECT id INTO v_user_id FROM users WHERE email = p_email;

  v_score := 1.1*(1/(1+EXP(p_response_time)/EXP(2.5))); -- Sigmoid + Abjustment

  INSERT INTO Answers(uid, wid, score) VALUES (v_user_id, p_word_id, v_score);

  UPDATE word_progress
  SET
    attempts = attempts + 1,
    attempts_since_last = -1,

    confidence = confidence + 0.1 * (1 - confidence),

    mastery = mastery * (1 - (0.05 + 0.1 * confidence)) + v_score * (0.05 + 0.1 * confidence)
  WHERE user_id = v_user_id
    AND word_id = p_word_id;

  UPDATE word_progress
  SET attempts_since_last = attempts_since_last + 1
  WHERE user_id = v_user_id AND word_id <> p_word_id;

  PERFORM add_next_word(v_user_id);
END;
$$ LANGUAGE plpgsql STABLE;

CREATE MATERIALIZED VIEW word_frequency AS
SELECT wid, COUNT(*) as freq
FROM example_word_links
GROUP BY wid;
CREATE INDEX idx_word_freq ON word_frequency(freq DESC);

CREATE OR REPLACE FUNCTION add_next_word(v_user_id BIGINT)
RETURNS VOID AS $$
DECLARE
  v_avg_mastery REAL;
  v_new_word_id BIGINT;
BEGIN
  SELECT AVG(mastery)
  INTO v_avg_mastery
  FROM word_progress
  WHERE user_id = v_user_id;

  IF v_avg_mastery IS NULL OR v_avg_mastery <= 0.8 THEN
    RETURN;
  END IF;

  SELECT wf.wid
  INTO v_new_word_id
  FROM word_frequency wf
  LEFT JOIN word_progress wp
    ON wp.word_id = wf.wid
   AND wp.user_id = v_user_id
  WHERE wp.word_id IS NULL
  ORDER BY wf.freq DESC
  LIMIT 1;

  IF v_new_word_id IS NOT NULL THEN
    INSERT INTO word_progress (user_id, word_id)
    VALUES (v_user_id, v_new_word_id)
    ON CONFLICT DO NOTHING;
  END IF;

END;
$$ LANGUAGE plpgsql;

