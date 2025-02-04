--
-- Test INSERT/UPDATE/DELETE RETURNING
--

-- Simple cases

--DDL_STATEMENT_BEGIN--
CREATE TEMP TABLE foo (f1 serial, f2 text, f3 int default 42);
--DDL_STATEMENT_END--

INSERT INTO foo (f2,f3)
  VALUES ('test', DEFAULT), ('More', 11), (upper('more'), 7+9)
  RETURNING *, f1+f3 AS sum;

SELECT * FROM foo;

SELECT * FROM foo;

DELETE FROM foo WHERE f1 > 2 RETURNING f3, f2, f1, least(f1,f3);

SELECT * FROM foo;

-- Subplans and initplans in the RETURNING list

INSERT INTO foo SELECT f1+10, f2, f3+99 FROM foo
  RETURNING *, f1+112 IN (SELECT q1 FROM int8_tbl) AS subplan,
    EXISTS(SELECT * FROM int4_tbl) AS initplan;

UPDATE foo SET f3 = f3 * 2
  WHERE f1 > 10
  RETURNING *, f1+112 IN (SELECT q1 FROM int8_tbl) AS subplan,
    EXISTS(SELECT * FROM int4_tbl) AS initplan;

DELETE FROM foo
  WHERE f1 > 10
  RETURNING *, f1+112 IN (SELECT q1 FROM int8_tbl) AS subplan,
    EXISTS(SELECT * FROM int4_tbl) AS initplan;

-- Joins
-- update involves two or more tables, not supported in kunlun currently.
--UPDATE foo SET f3 = f3*2
--  FROM int4_tbl i
--  WHERE foo.f1 + 123455 = i.f1
--  RETURNING foo.*, i.f1 as "i.f1";

SELECT * FROM foo;

-- delete involves two or more tables, not supported in kunlun currently.
--DELETE FROM foo
--  USING int4_tbl i
--  WHERE foo.f1 + 123455 = i.f1
--  RETURNING foo.*, i.f1 as "i.f1";
-- SELECT * FROM foo;

-- Check inheritance cases

--DDL_STATEMENT_BEGIN--
CREATE TEMP TABLE foochild (fc int) INHERITS (foo);
--DDL_STATEMENT_END--

INSERT INTO foochild VALUES(123,'child',999,-123);

--DDL_STATEMENT_BEGIN--
ALTER TABLE foo ADD COLUMN f4 int8 DEFAULT 99;
--DDL_STATEMENT_END--

SELECT * FROM foo;
SELECT * FROM foochild;

UPDATE foo SET f4 = f4 + f3 WHERE f4 = 99 RETURNING *;

SELECT * FROM foo;
SELECT * FROM foochild;

-- update involves two or more tables, not supported in kunlun currently.
--UPDATE foo SET f3 = f3*2
--FROM int8_tbl i
--  WHERE foo.f1 = i.q2
--  RETURNING *;
--
--SELECT * FROM foo;
--SELECT * FROM foochild;

-- delete involves two or more tables, not supported in kunlun currently.
--DELETE FROM foo
--  USING int8_tbl i
--  WHERE foo.f1 = i.q2
--  RETURNING *;
--
--SELECT * FROM foo;
--SELECT * FROM foochild;

--DDL_STATEMENT_BEGIN--
DROP TABLE foochild;
--DDL_STATEMENT_END--

-- Rules and views

--DDL_STATEMENT_BEGIN--
CREATE TEMP VIEW voo AS SELECT f1, f2 FROM foo;
--DDL_STATEMENT_END--

INSERT INTO voo VALUES(11,'zit');
-- fails:
INSERT INTO voo VALUES(12,'zoo') RETURNING *, f1*2;

-- should still work
INSERT INTO voo VALUES(13,'zit2');
-- works now
INSERT INTO voo VALUES(14,'zoo2') RETURNING *;

SELECT * FROM foo;
SELECT * FROM voo;

update voo set f1 = f1 + 1 where f2 = 'zoo2';
update voo set f1 = f1 + 1 where f2 = 'zoo2' RETURNING *, f1*2;

SELECT * FROM foo;
SELECT * FROM voo;

DELETE FROM foo WHERE f1 = 13;
DELETE FROM foo WHERE f2 = 'zit' RETURNING *;

SELECT * FROM foo;
SELECT * FROM voo;

-- Try a join case

--DDL_STATEMENT_BEGIN--
CREATE TEMP TABLE joinme (f2j text, other int);
--DDL_STATEMENT_END--
INSERT INTO joinme VALUES('more', 12345);
INSERT INTO joinme VALUES('zoo2', 54321);
INSERT INTO joinme VALUES('other', 0);

--DDL_STATEMENT_BEGIN--
CREATE TEMP VIEW joinview AS
  SELECT foo.*, other FROM foo JOIN joinme ON (f2 = f2j);
--DDL_STATEMENT_END--

SELECT * FROM joinview;

UPDATE joinview SET f1 = f1 + 1 WHERE f3 = 57 RETURNING *, other + 1;

SELECT * FROM joinview;
SELECT * FROM foo;
SELECT * FROM voo;

-- Check aliased target relation
INSERT INTO foo AS bar DEFAULT VALUES RETURNING *; -- ok
INSERT INTO foo AS bar DEFAULT VALUES RETURNING foo.*; -- fails, wrong name
INSERT INTO foo AS bar DEFAULT VALUES RETURNING bar.*; -- ok
INSERT INTO foo AS bar DEFAULT VALUES RETURNING bar.f3; -- ok
