--
-- SELECT_HAVING
--

-- load test data
--DDL_STATEMENT_BEGIN--
CREATE TABLE test_having (a int, b int, c char(8), d char);
--DDL_STATEMENT_END--
INSERT INTO test_having VALUES (0, 1, 'XXXX', 'A');
INSERT INTO test_having VALUES (1, 2, 'AAAA', 'b');
INSERT INTO test_having VALUES (2, 2, 'AAAA', 'c');
INSERT INTO test_having VALUES (3, 3, 'BBBB', 'D');
INSERT INTO test_having VALUES (4, 3, 'BBBB', 'e');
INSERT INTO test_having VALUES (5, 3, 'bbbb', 'F');
INSERT INTO test_having VALUES (6, 4, 'cccc', 'g');
INSERT INTO test_having VALUES (7, 4, 'cccc', 'h');
INSERT INTO test_having VALUES (8, 4, 'CCCC', 'I');
INSERT INTO test_having VALUES (9, 4, 'CCCC', 'j');

SELECT b, c FROM test_having
	GROUP BY b, c HAVING count(*) = 1 ORDER BY b, c;

-- HAVING is effectively equivalent to WHERE in this case
SELECT b, c FROM test_having
	GROUP BY b, c HAVING b = 3 ORDER BY b, c;

SELECT lower(c), count(c) FROM test_having
	GROUP BY lower(c) HAVING count(*) > 2 OR min(a) = max(a)
	ORDER BY lower(c);

SELECT c, max(a) FROM test_having
	GROUP BY c HAVING count(*) > 2 OR min(a) = max(a)
	ORDER BY c;

-- test degenerate cases involving HAVING without GROUP BY
-- Per SQL spec, these should generate 0 or 1 row, even without aggregates

SELECT min(a), max(a) FROM test_having HAVING min(a) = max(a);
SELECT min(a), max(a) FROM test_having HAVING min(a) < max(a);

-- errors: ungrouped column references
SELECT a FROM test_having HAVING min(a) < max(a);
SELECT 1 AS one FROM test_having HAVING a > 1;

-- the really degenerate case: need not scan table at all
SELECT 1 AS one FROM test_having HAVING 1 > 2;
SELECT 1 AS one FROM test_having HAVING 1 < 2;

-- and just to prove that we aren't scanning the table:
SELECT 1 AS one FROM test_having WHERE 1/a = 1 HAVING 1 < 2;

--DDL_STATEMENT_BEGIN--
DROP TABLE test_having;
--DDL_STATEMENT_END--