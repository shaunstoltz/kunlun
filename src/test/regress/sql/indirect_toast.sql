--DDL_STATEMENT_BEGIN--
CREATE TABLE indtoasttest(descr text, cnt int DEFAULT 0, f1 text, f2 text);
--DDL_STATEMENT_END--

INSERT INTO indtoasttest(descr, f1, f2) VALUES('two-compressed', repeat('1234567890',1000), repeat('1234567890',1000));
INSERT INTO indtoasttest(descr, f1, f2) VALUES('two-toasted', repeat('1234567890',30000), repeat('1234567890',50000));
INSERT INTO indtoasttest(descr, f1, f2) VALUES('one-compressed,one-null', NULL, repeat('1234567890',1000));
INSERT INTO indtoasttest(descr, f1, f2) VALUES('one-toasted,one-null', NULL, repeat('1234567890',50000));

-- check whether indirect tuples works on the most basic level
SELECT descr, substring(make_tuple_indirect(indtoasttest)::text, 1, 200) FROM indtoasttest;

-- modification without changing varlenas
UPDATE indtoasttest SET cnt = cnt +1 RETURNING substring(indtoasttest::text, 1, 200);

-- modification without modifying assigned value
UPDATE indtoasttest SET cnt = cnt +1, f1 = f1 RETURNING substring(indtoasttest::text, 1, 200);

-- modification modifying, but effectively not changing
UPDATE indtoasttest SET cnt = cnt +1, f1 = f1||'' RETURNING substring(indtoasttest::text, 1, 200);

UPDATE indtoasttest SET cnt = cnt +1, f1 = '-'||f1||'-' RETURNING substring(indtoasttest::text, 1, 200);

SELECT substring(indtoasttest::text, 1, 200) FROM indtoasttest;
-- check we didn't screw with main/toast tuple visibility
SELECT substring(indtoasttest::text, 1, 200) FROM indtoasttest;


-- modification without changing varlenas
UPDATE indtoasttest SET cnt = cnt +1 RETURNING substring(indtoasttest::text, 1, 200);

-- modification without modifying assigned value
UPDATE indtoasttest SET cnt = cnt +1, f1 = f1 RETURNING substring(indtoasttest::text, 1, 200);

-- modification modifying, but effectively not changing
UPDATE indtoasttest SET cnt = cnt +1, f1 = f1||'' RETURNING substring(indtoasttest::text, 1, 200);

UPDATE indtoasttest SET cnt = cnt +1, f1 = '-'||f1||'-' RETURNING substring(indtoasttest::text, 1, 200);

INSERT INTO indtoasttest(descr, f1, f2) VALUES('one-toasted,one-null, via indirect', repeat('1234567890',30000), NULL);

SELECT substring(indtoasttest::text, 1, 200) FROM indtoasttest;
-- check we didn't screw with main/toast tuple visibility
SELECT substring(indtoasttest::text, 1, 200) FROM indtoasttest;

--DDL_STATEMENT_BEGIN--
DROP TABLE indtoasttest;
--DDL_STATEMENT_END--