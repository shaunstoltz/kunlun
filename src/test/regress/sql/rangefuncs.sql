--DDL_STATEMENT_BEGIN--
DROP TABLE if exists rngfunc2 cascade;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE rngfunc2(rngfuncid int, f2 int);
--DDL_STATEMENT_END--
INSERT INTO rngfunc2 VALUES(1, 11);
INSERT INTO rngfunc2 VALUES(2, 22);
INSERT INTO rngfunc2 VALUES(1, 111);

--DDL_STATEMENT_BEGIN--
CREATE FUNCTION rngfunct(int) returns setof rngfunc2 as 'SELECT * FROM rngfunc2 WHERE rngfuncid = $1 ORDER BY f2;' LANGUAGE SQL;
--DDL_STATEMENT_END--

-- function with ORDINALITY
select * from rngfunct(1) with ordinality as z(a,b,ord);
select * from rngfunct(1) with ordinality as z(a,b,ord) where b > 100;   -- ordinal 2, not 1
-- ordinality vs. column names and types
select a,b,ord from rngfunct(1) with ordinality as z(a,b,ord);
select a,ord from unnest(array['a','b']) with ordinality as z(a,ord);
select * from unnest(array['a','b']) with ordinality as z(a,ord);
select a,ord from unnest(array[1.0::float8]) with ordinality as z(a,ord);
select * from unnest(array[1.0::float8]) with ordinality as z(a,ord);
select row_to_json(s.*) from generate_series(11,14) with ordinality s;
-- ordinality vs. views
--DDL_STATEMENT_BEGIN--
create temporary view vw_ord as select * from (values (1)) v(n) join rngfunct(1) with ordinality as z(a,b,ord) on (n=ord);
--DDL_STATEMENT_END--
select * from vw_ord;
select definition from pg_views where viewname='vw_ord';
--DDL_STATEMENT_BEGIN--
drop view vw_ord;
--DDL_STATEMENT_END--

-- multiple functions
select * from rows from(rngfunct(1),rngfunct(2)) with ordinality as z(a,b,c,d,ord);
--DDL_STATEMENT_BEGIN--
create temporary view vw_ord as select * from (values (1)) v(n) join rows from(rngfunct(1),rngfunct(2)) with ordinality as z(a,b,c,d,ord) on (n=ord);
--DDL_STATEMENT_END--
select * from vw_ord;
select definition from pg_views where viewname='vw_ord';
--DDL_STATEMENT_BEGIN--
drop view vw_ord;
--DDL_STATEMENT_END--

-- expansions of unnest()
select * from unnest(array[10,20],array['foo','bar'],array[1.0]);
select * from unnest(array[10,20],array['foo','bar'],array[1.0]) with ordinality as z(a,b,c,ord);
select * from rows from(unnest(array[10,20],array['foo','bar'],array[1.0])) with ordinality as z(a,b,c,ord);
select * from rows from(unnest(array[10,20],array['foo','bar']), generate_series(101,102)) with ordinality as z(a,b,c,ord);
--DDL_STATEMENT_BEGIN--
create temporary view vw_ord as select * from unnest(array[10,20],array['foo','bar'],array[1.0]) as z(a,b,c);
--DDL_STATEMENT_END--
select * from vw_ord;
select definition from pg_views where viewname='vw_ord';
--DDL_STATEMENT_BEGIN--
drop view vw_ord;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
create temporary view vw_ord as select * from rows from(unnest(array[10,20],array['foo','bar'],array[1.0])) as z(a,b,c);
--DDL_STATEMENT_END--
select * from vw_ord;
select definition from pg_views where viewname='vw_ord';
--DDL_STATEMENT_BEGIN--
drop view vw_ord;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
create temporary view vw_ord as select * from rows from(unnest(array[10,20],array['foo','bar']), generate_series(1,2)) as z(a,b,c);
--DDL_STATEMENT_END--
select * from vw_ord;
select definition from pg_views where viewname='vw_ord';
--DDL_STATEMENT_BEGIN--
drop view vw_ord;
--DDL_STATEMENT_END--

-- function with implicit LATERAL
--will crash:  select * from rngfunc2, rngfunct(rngfunc2.rngfuncid) z where rngfunc2.f2 = z.f2;

-- function with implicit LATERAL and explicit ORDINALITY
-- will crash: select * from rngfunc2, rngfunct(rngfunc2.rngfuncid) with ordinality as z(rngfuncid,f2,ord) where rngfunc2.f2 = z.f2;

-- function in subselect
-- will crash: select * from rngfunc2 where f2 in (select f2 from rngfunct(rngfunc2.rngfuncid) z where z.rngfuncid = rngfunc2.rngfuncid) ORDER BY 1,2;

-- function in subselect
-- will crash: select * from rngfunc2 where f2 in (select f2 from rngfunct(1) z where z.rngfuncid = rngfunc2.rngfuncid) ORDER BY 1,2;

-- function in subselect
-- will crash: select * from rngfunc2 where f2 in (select f2 from rngfunct(rngfunc2.rngfuncid) z where z.rngfuncid = 1) ORDER BY 1,2;

-- nested functions
select rngfunct.rngfuncid, rngfunct.f2 from rngfunct(sin(pi()/2)::int) ORDER BY 1,2;
--DDL_STATEMENT_BEGIN--

drop table if exists rngfunc cascade;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE rngfunc (rngfuncid int, rngfuncsubid int, rngfuncname text, primary key(rngfuncid,rngfuncsubid));
--DDL_STATEMENT_END--
INSERT INTO rngfunc VALUES(1,1,'Joe');
INSERT INTO rngfunc VALUES(1,2,'Ed');
INSERT INTO rngfunc VALUES(2,1,'Mary');

-- sql, proretset = f, prorettype = b
--DDL_STATEMENT_BEGIN--
CREATE FUNCTION getrngfunc1(int) RETURNS int AS 'SELECT $1;' LANGUAGE SQL;
--DDL_STATEMENT_END--
SELECT * FROM getrngfunc1(1) AS t1;
SELECT * FROM getrngfunc1(1) WITH ORDINALITY AS t1(v,o);
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc1(1);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc1(1) WITH ORDINALITY as t1(v,o);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--

-- sql, proretset = t, prorettype = b
--DDL_STATEMENT_BEGIN--
CREATE FUNCTION getrngfunc2(int) RETURNS setof int AS 'SELECT rngfuncid FROM rngfunc WHERE rngfuncid = $1;' LANGUAGE SQL;
--DDL_STATEMENT_END--
SELECT * FROM getrngfunc2(1) AS t1;
SELECT * FROM getrngfunc2(1) WITH ORDINALITY AS t1(v,o);
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc2(1);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc2(1) WITH ORDINALITY AS t1(v,o);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--

-- sql, proretset = t, prorettype = b
--DDL_STATEMENT_BEGIN--
CREATE FUNCTION getrngfunc3(int) RETURNS setof text AS 'SELECT rngfuncname FROM rngfunc WHERE rngfuncid = $1;' LANGUAGE SQL;
--DDL_STATEMENT_END--
SELECT * FROM getrngfunc3(1) AS t1;
SELECT * FROM getrngfunc3(1) WITH ORDINALITY AS t1(v,o);
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc3(1);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc3(1) WITH ORDINALITY AS t1(v,o);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--

-- sql, proretset = f, prorettype = c
--DDL_STATEMENT_BEGIN--
CREATE FUNCTION getrngfunc4(int) RETURNS rngfunc AS 'SELECT * FROM rngfunc WHERE rngfuncid = $1;' LANGUAGE SQL;
--DDL_STATEMENT_END--
SELECT * FROM getrngfunc4(1) AS t1;
SELECT * FROM getrngfunc4(1) WITH ORDINALITY AS t1(a,b,c,o);
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc4(1);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc4(1) WITH ORDINALITY AS t1(a,b,c,o);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--

-- sql, proretset = t, prorettype = c
--DDL_STATEMENT_BEGIN--
CREATE FUNCTION getrngfunc5(int) RETURNS setof rngfunc AS 'SELECT * FROM rngfunc WHERE rngfuncid = $1;' LANGUAGE SQL;
--DDL_STATEMENT_END--
SELECT * FROM getrngfunc5(1) AS t1;
SELECT * FROM getrngfunc5(1) WITH ORDINALITY AS t1(a,b,c,o);
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc5(1);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc5(1) WITH ORDINALITY AS t1(a,b,c,o);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--

-- sql, proretset = f, prorettype = record
--DDL_STATEMENT_BEGIN--
CREATE FUNCTION getrngfunc6(int) RETURNS RECORD AS 'SELECT * FROM rngfunc WHERE rngfuncid = $1;' LANGUAGE SQL;
--DDL_STATEMENT_END--
SELECT * FROM getrngfunc6(1) AS t1(rngfuncid int, rngfuncsubid int, rngfuncname text);
SELECT * FROM ROWS FROM( getrngfunc6(1) AS (rngfuncid int, rngfuncsubid int, rngfuncname text) ) WITH ORDINALITY;
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc6(1) AS
(rngfuncid int, rngfuncsubid int, rngfuncname text);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS
--DDL_STATEMENT_END--
  SELECT * FROM ROWS FROM( getrngfunc6(1) AS (rngfuncid int, rngfuncsubid int, rngfuncname text) )
                WITH ORDINALITY;
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--

-- sql, proretset = t, prorettype = record
--DDL_STATEMENT_BEGIN--
CREATE FUNCTION getrngfunc7(int) RETURNS setof record AS 'SELECT * FROM rngfunc WHERE rngfuncid = $1;' LANGUAGE SQL;
--DDL_STATEMENT_END--
SELECT * FROM getrngfunc7(1) AS t1(rngfuncid int, rngfuncsubid int, rngfuncname text);
SELECT * FROM ROWS FROM( getrngfunc7(1) AS (rngfuncid int, rngfuncsubid int, rngfuncname text) ) WITH ORDINALITY;
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc7(1) AS
(rngfuncid int, rngfuncsubid int, rngfuncname text);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS
  SELECT * FROM ROWS FROM( getrngfunc7(1) AS (rngfuncid int, rngfuncsubid int, rngfuncname text) )
                WITH ORDINALITY;
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--

-- plpgsql, proretset = f, prorettype = b
--DDL_STATEMENT_BEGIN--
CREATE FUNCTION getrngfunc8(int) RETURNS int AS 'DECLARE rngfuncint int; BEGIN SELECT rngfuncid into rngfuncint FROM rngfunc WHERE rngfuncid = $1; RETURN rngfuncint; END;' LANGUAGE plpgsql;
--DDL_STATEMENT_END--
SELECT * FROM getrngfunc8(1) AS t1;
SELECT * FROM getrngfunc8(1) WITH ORDINALITY AS t1(v,o);
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc8(1);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc8(1) WITH ORDINALITY AS t1(v,o);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--

-- plpgsql, proretset = f, prorettype = c
--DDL_STATEMENT_BEGIN--
CREATE FUNCTION getrngfunc9(int) RETURNS rngfunc AS 'DECLARE rngfunctup rngfunc%ROWTYPE; BEGIN SELECT * into rngfunctup FROM rngfunc WHERE rngfuncid = $1; RETURN rngfunctup; END;' LANGUAGE plpgsql;
--DDL_STATEMENT_END--
SELECT * FROM getrngfunc9(1) AS t1;
SELECT * FROM getrngfunc9(1) WITH ORDINALITY AS t1(a,b,c,o);
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc9(1);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE VIEW vw_getrngfunc AS SELECT * FROM getrngfunc9(1) WITH ORDINALITY AS t1(a,b,c,o);
--DDL_STATEMENT_END--
SELECT * FROM vw_getrngfunc;
--DDL_STATEMENT_BEGIN--
DROP VIEW vw_getrngfunc;
--DDL_STATEMENT_END--

-- mix 'n match kinds, to exercise expandRTE and related logic

select * from rows from(getrngfunc1(1),getrngfunc2(1),getrngfunc3(1),getrngfunc4(1),getrngfunc5(1),
                    getrngfunc6(1) AS (rngfuncid int, rngfuncsubid int, rngfuncname text),
                    getrngfunc7(1) AS (rngfuncid int, rngfuncsubid int, rngfuncname text),
                    getrngfunc8(1),getrngfunc9(1))
              with ordinality as t1(a,b,c,d,e,f,g,h,i,j,k,l,m,o,p,q,r,s,t,u);
select * from rows from(getrngfunc9(1),getrngfunc8(1),
                    getrngfunc7(1) AS (rngfuncid int, rngfuncsubid int, rngfuncname text),
                    getrngfunc6(1) AS (rngfuncid int, rngfuncsubid int, rngfuncname text),
                    getrngfunc5(1),getrngfunc4(1),getrngfunc3(1),getrngfunc2(1),getrngfunc1(1))
              with ordinality as t1(a,b,c,d,e,f,g,h,i,j,k,l,m,o,p,q,r,s,t,u);

--DDL_STATEMENT_BEGIN--
create temporary view vw_rngfunc as
  select * from rows from(getrngfunc9(1),
                      getrngfunc7(1) AS (rngfuncid int, rngfuncsubid int, rngfuncname text),
                      getrngfunc1(1))
                with ordinality as t1(a,b,c,d,e,f,g,n);
--DDL_STATEMENT_END--
select * from vw_rngfunc;
select pg_get_viewdef('vw_rngfunc');
--DDL_STATEMENT_BEGIN--
drop view vw_rngfunc;
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
DROP FUNCTION getrngfunc1(int);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP FUNCTION getrngfunc2(int);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP FUNCTION getrngfunc3(int);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP FUNCTION getrngfunc4(int);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP FUNCTION getrngfunc5(int);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP FUNCTION getrngfunc6(int);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP FUNCTION getrngfunc7(int);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP FUNCTION getrngfunc8(int);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP FUNCTION getrngfunc9(int);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP FUNCTION rngfunct(int);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP TABLE rngfunc2;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP TABLE rngfunc;
--DDL_STATEMENT_END--

-- Rescan tests --
--DDL_STATEMENT_BEGIN--
CREATE TEMPORARY SEQUENCE rngfunc_rescan_seq1;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TEMPORARY SEQUENCE rngfunc_rescan_seq2;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TYPE rngfunc_rescan_t AS (i integer, s bigint);
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
CREATE FUNCTION rngfunc_sql(int,int) RETURNS setof rngfunc_rescan_t AS 'SELECT i, nextval(''rngfunc_rescan_seq1'') FROM generate_series($1,$2) i;' LANGUAGE SQL;
--DDL_STATEMENT_END--
-- plpgsql functions use materialize mode
--CREATE FUNCTION rngfunc_mat(int,int) RETURNS setof rngfunc_rescan_t AS 'begin for i in $1..$2 loop return next (i, nextval(''rngfunc_rescan_seq2'')); end loop; end;' LANGUAGE plpgsql;

--invokes ExecReScanFunctionScan - all these cases should materialize the function only once
-- LEFT JOIN on a condition that the planner can't prove to be true is used to ensure the function
-- is on the inner path of a nestloop join

SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
SELECT * FROM (VALUES (1),(2),(3)) v(r) LEFT JOIN rngfunc_sql(11,13) ON (r+i)<100;
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
SELECT * FROM (VALUES (1),(2),(3)) v(r) LEFT JOIN rngfunc_sql(11,13) WITH ORDINALITY AS f(i,s,o) ON (r+i)<100;

SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM (VALUES (1),(2),(3)) v(r) LEFT JOIN rngfunc_mat(11,13) ON (r+i)<100;
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM (VALUES (1),(2),(3)) v(r) LEFT JOIN rngfunc_mat(11,13) WITH ORDINALITY AS f(i,s,o) ON (r+i)<100;
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM (VALUES (1),(2),(3)) v(r) LEFT JOIN ROWS FROM( rngfunc_sql(11,13), rngfunc_mat(11,13) ) WITH ORDINALITY AS f(i1,s1,i2,s2,o) ON (r+i1+i2)<100;

SELECT * FROM (VALUES (1),(2),(3)) v(r) LEFT JOIN generate_series(11,13) f(i) ON (r+i)<100;
SELECT * FROM (VALUES (1),(2),(3)) v(r) LEFT JOIN generate_series(11,13) WITH ORDINALITY AS f(i,o) ON (r+i)<100;

SELECT * FROM (VALUES (1),(2),(3)) v(r) LEFT JOIN unnest(array[10,20,30]) f(i) ON (r+i)<100;
SELECT * FROM (VALUES (1),(2),(3)) v(r) LEFT JOIN unnest(array[10,20,30]) WITH ORDINALITY AS f(i,o) ON (r+i)<100;

--invokes ExecReScanFunctionScan with chgParam != NULL (using implied LATERAL)

SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
SELECT * FROM (VALUES (1),(2),(3)) v(r), rngfunc_sql(10+r,13);
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
SELECT * FROM (VALUES (1),(2),(3)) v(r), rngfunc_sql(10+r,13) WITH ORDINALITY AS f(i,s,o);
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
SELECT * FROM (VALUES (1),(2),(3)) v(r), rngfunc_sql(11,10+r);
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
SELECT * FROM (VALUES (1),(2),(3)) v(r), rngfunc_sql(11,10+r) WITH ORDINALITY AS f(i,s,o);
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
SELECT * FROM (VALUES (11,12),(13,15),(16,20)) v(r1,r2), rngfunc_sql(r1,r2);
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
SELECT * FROM (VALUES (11,12),(13,15),(16,20)) v(r1,r2), rngfunc_sql(r1,r2) WITH ORDINALITY AS f(i,s,o);

SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM (VALUES (1),(2),(3)) v(r), rngfunc_mat(10+r,13);
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM (VALUES (1),(2),(3)) v(r), rngfunc_mat(10+r,13) WITH ORDINALITY AS f(i,s,o);
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM (VALUES (1),(2),(3)) v(r), rngfunc_mat(11,10+r);
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM (VALUES (1),(2),(3)) v(r), rngfunc_mat(11,10+r) WITH ORDINALITY AS f(i,s,o);
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM (VALUES (11,12),(13,15),(16,20)) v(r1,r2), rngfunc_mat(r1,r2);
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM (VALUES (11,12),(13,15),(16,20)) v(r1,r2), rngfunc_mat(r1,r2) WITH ORDINALITY AS f(i,s,o);

-- selective rescan of multiple functions:

SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM (VALUES (1),(2),(3)) v(r), ROWS FROM( rngfunc_sql(11,11), rngfunc_mat(10+r,13) );
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM (VALUES (1),(2),(3)) v(r), ROWS FROM( rngfunc_sql(10+r,13), rngfunc_mat(11,11) );
SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM (VALUES (1),(2),(3)) v(r), ROWS FROM( rngfunc_sql(10+r,13), rngfunc_mat(10+r,13) );

SELECT setval('rngfunc_rescan_seq1',1,false),setval('rngfunc_rescan_seq2',1,false);
--SELECT * FROM generate_series(1,2) r1, generate_series(r1,3) r2, ROWS FROM( rngfunc_sql(10+r1,13), rngfunc_mat(10+r2,13) );

SELECT * FROM (VALUES (1),(2),(3)) v(r), generate_series(10+r,20-r) f(i);
SELECT * FROM (VALUES (1),(2),(3)) v(r), generate_series(10+r,20-r) WITH ORDINALITY AS f(i,o);

SELECT * FROM (VALUES (1),(2),(3)) v(r), unnest(array[r*10,r*20,r*30]) f(i);
SELECT * FROM (VALUES (1),(2),(3)) v(r), unnest(array[r*10,r*20,r*30]) WITH ORDINALITY AS f(i,o);

-- deep nesting

SELECT * FROM (VALUES (1),(2),(3)) v1(r1),
              LATERAL (SELECT r1, * FROM (VALUES (10),(20),(30)) v2(r2)
                                         LEFT JOIN generate_series(21,23) f(i) ON ((r2+i)<100) OFFSET 0) s1;
SELECT * FROM (VALUES (1),(2),(3)) v1(r1),
              LATERAL (SELECT r1, * FROM (VALUES (10),(20),(30)) v2(r2)
                                         LEFT JOIN generate_series(20+r1,23) f(i) ON ((r2+i)<100) OFFSET 0) s1;
SELECT * FROM (VALUES (1),(2),(3)) v1(r1),
              LATERAL (SELECT r1, * FROM (VALUES (10),(20),(30)) v2(r2)
                                         LEFT JOIN generate_series(r2,r2+3) f(i) ON ((r2+i)<100) OFFSET 0) s1;
SELECT * FROM (VALUES (1),(2),(3)) v1(r1),
              LATERAL (SELECT r1, * FROM (VALUES (10),(20),(30)) v2(r2)
                                         LEFT JOIN generate_series(r1,2+r2/5) f(i) ON ((r2+i)<100) OFFSET 0) s1;

-- check handling of FULL JOIN with multiple lateral references (bug #15741)

SELECT *
FROM (VALUES (1),(2)) v1(r1)
    LEFT JOIN LATERAL (
        SELECT *
        FROM generate_series(1, v1.r1) AS gs1
        LEFT JOIN LATERAL (
            SELECT *
            FROM generate_series(1, gs1) AS gs2
            LEFT JOIN generate_series(1, gs2) AS gs3 ON TRUE
        ) AS ss1 ON TRUE
        FULL JOIN generate_series(1, v1.r1) AS gs4 ON FALSE
    ) AS ss0 ON TRUE;
	
--DDL_STATEMENT_BEGIN--
DROP FUNCTION rngfunc_sql(int,int);
--DDL_STATEMENT_END--
--DROP FUNCTION rngfunc_mat(int,int);
--DDL_STATEMENT_BEGIN--
DROP SEQUENCE rngfunc_rescan_seq1;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP SEQUENCE rngfunc_rescan_seq2;
--DDL_STATEMENT_END--

--
-- Test cases involving OUT parameters
--

--DDL_STATEMENT_BEGIN--
CREATE FUNCTION rngfunc(in f1 int, out f2 int)
AS 'select $1+1' LANGUAGE sql;
--DDL_STATEMENT_END--
SELECT rngfunc(42);
SELECT * FROM rngfunc(42);
SELECT * FROM rngfunc(42) AS p(x);

-- explicit spec of return type is OK
--DDL_STATEMENT_BEGIN--
CREATE OR REPLACE FUNCTION rngfunc(in f1 int, out f2 int) RETURNS int
AS 'select $1+1' LANGUAGE sql;
--DDL_STATEMENT_END--
-- error, wrong result type
--DDL_STATEMENT_BEGIN--
CREATE OR REPLACE FUNCTION rngfunc(in f1 int, out f2 int) RETURNS float
AS 'select $1+1' LANGUAGE sql;
--DDL_STATEMENT_END--
-- with multiple OUT params you must get a RECORD result
--DDL_STATEMENT_BEGIN--
CREATE OR REPLACE FUNCTION rngfunc(in f1 int, out f2 int, out f3 text) RETURNS int
AS 'select $1+1' LANGUAGE sql;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE OR REPLACE FUNCTION rngfunc(in f1 int, out f2 int, out f3 text)
RETURNS record
AS 'select $1+1' LANGUAGE sql;
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
CREATE OR REPLACE FUNCTION rngfuncr(in f1 int, out f2 int, out text)
AS $$select $1-1, $1::text || 'z'$$ LANGUAGE sql;
--DDL_STATEMENT_END--
SELECT f1, rngfuncr(f1) FROM int4_tbl;
SELECT * FROM rngfuncr(42);
SELECT * FROM rngfuncr(42) AS p(a,b);

--DDL_STATEMENT_BEGIN--
CREATE OR REPLACE FUNCTION rngfuncb(in f1 int, inout f2 int, out text)
AS $$select $2-1, $1::text || 'z'$$ LANGUAGE sql;
--DDL_STATEMENT_END--
SELECT f1, rngfuncb(f1, f1/2) FROM int4_tbl;
SELECT * FROM rngfuncb(42, 99);
SELECT * FROM rngfuncb(42, 99) AS p(a,b);

-- Can reference function with or without OUT params for DROP, etc
--DDL_STATEMENT_BEGIN--
DROP FUNCTION rngfunc(int);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP FUNCTION rngfuncr(in f2 int, out f1 int, out text);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP FUNCTION rngfuncb(in f1 int, inout f2 int);
--DDL_STATEMENT_END--

--
-- For my next trick, polymorphic OUT parameters
--

--DDL_STATEMENT_BEGIN--
CREATE FUNCTION dup (f1 anyelement, f2 out anyelement, f3 out anyarray)
AS 'select $1, array[$1,$1]' LANGUAGE sql;
--DDL_STATEMENT_END--
SELECT dup(22);
SELECT dup('xyz');	-- fails
SELECT dup('xyz'::text);
SELECT * FROM dup('xyz'::text);

-- fails, as we are attempting to rename first argument
--DDL_STATEMENT_BEGIN--
CREATE OR REPLACE FUNCTION dup (inout f2 anyelement, out f3 anyarray)
AS 'select $1, array[$1,$1]' LANGUAGE sql;
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
DROP FUNCTION dup(anyelement);
--DDL_STATEMENT_END--

-- equivalent behavior, though different name exposed for input arg
--DDL_STATEMENT_BEGIN--
CREATE OR REPLACE FUNCTION dup (inout f2 anyelement, out f3 anyarray)
AS 'select $1, array[$1,$1]' LANGUAGE sql;
SELECT dup(22);
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
DROP FUNCTION dup(anyelement);
--DDL_STATEMENT_END--

-- fails, no way to deduce outputs
--DDL_STATEMENT_BEGIN--
CREATE FUNCTION bad (f1 int, out f2 anyelement, out f3 anyarray)
AS 'select $1, array[$1,$1]' LANGUAGE sql;
--DDL_STATEMENT_END--

--
-- table functions
--

--DDL_STATEMENT_BEGIN--
CREATE OR REPLACE FUNCTION rngfunc()
RETURNS TABLE(a int)
AS $$ SELECT a FROM generate_series(1,5) a(a) $$ LANGUAGE sql;
--DDL_STATEMENT_END--
SELECT * FROM rngfunc();
--DDL_STATEMENT_BEGIN--
DROP FUNCTION rngfunc();
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
CREATE OR REPLACE FUNCTION rngfunc(int)
RETURNS TABLE(a int, b int)
AS $$ SELECT a, b
         FROM generate_series(1,$1) a(a),
              generate_series(1,$1) b(b) $$ LANGUAGE sql;
--DDL_STATEMENT_END--		
SELECT * FROM rngfunc(3);
--DDL_STATEMENT_BEGIN--
DROP FUNCTION rngfunc(int);
--DDL_STATEMENT_END--

-- case that causes change of typmod knowledge during inlining
--DDL_STATEMENT_BEGIN--
CREATE OR REPLACE FUNCTION rngfunc()
RETURNS TABLE(a varchar(5))
AS $$ SELECT 'hello'::varchar(5) $$ LANGUAGE sql STABLE;
--DDL_STATEMENT_END--
SELECT * FROM rngfunc() GROUP BY 1;
--DDL_STATEMENT_BEGIN--
DROP FUNCTION rngfunc();
--DDL_STATEMENT_END--

--
-- some tests on SQL functions with RETURNING
--

--DDL_STATEMENT_BEGIN--
create temp table tt(f1 serial, data text);
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
create function insert_tt(text) returns int as
$$ insert into tt(data) values($1) returning f1 $$
language sql;
--DDL_STATEMENT_END--

select insert_tt('foo');
select insert_tt('bar');
select * from tt;

-- insert will execute to completion even if function needs just 1 row
--DDL_STATEMENT_BEGIN--
create or replace function insert_tt(text) returns int as
$$ insert into tt(data) values($1),($1||$1) returning f1 $$
language sql;
--DDL_STATEMENT_END--

select insert_tt('fool');
select * from tt;

-- setof does what's expected
--DDL_STATEMENT_BEGIN--
create or replace function insert_tt2(text,text) returns setof int as
$$ insert into tt(data) values($1),($2) returning f1 $$
language sql;
--DDL_STATEMENT_END--

select insert_tt2('foolish','barrish');
select * from insert_tt2('baz','quux');
select * from tt;

-- limit doesn't prevent execution to completion
select insert_tt2('foolish','barrish') limit 1;
select * from tt;

select insert_tt2('foolme','barme') limit 1;
select * from tt;

-- and rules work
--DDL_STATEMENT_BEGIN--
create temp table tt_log(f1 int, data text);
--DDL_STATEMENT_END--

select insert_tt2('foollog','barlog') limit 1;
select * from tt;
-- note that nextval() gets executed a second time in the rule expansion,
-- which is expected.
select * from tt_log;

-- test case for a whole-row-variable bug
--DDL_STATEMENT_BEGIN--
create function rngfunc1(n integer, out a text, out b text)
  returns setof record
  language sql
  as $$ select 'foo ' || i, 'bar ' || i from generate_series(1,$1) i $$;
--DDL_STATEMENT_END--

set work_mem='64kB';
select t.a, t, t.a from rngfunc1(10000) t limit 1;
reset work_mem;
select t.a, t, t.a from rngfunc1(10000) t limit 1;

--DDL_STATEMENT_BEGIN--
drop function rngfunc1(n integer);
--DDL_STATEMENT_END--

-- test use of SQL functions returning record
-- this is supported in some cases where the query doesn't specify
-- the actual record type ...

--DDL_STATEMENT_BEGIN--
create function array_to_set(anyarray) returns setof record as $$
  select i AS "index", $1[i] AS "value" from generate_subscripts($1, 1) i
$$ language sql strict immutable;
--DDL_STATEMENT_END--

select array_to_set(array['one', 'two']);
select * from array_to_set(array['one', 'two']) as t(f1 int,f2 text);
select * from array_to_set(array['one', 'two']); -- fail

--DDL_STATEMENT_BEGIN--
create temp table rngfunc(f1 int8, f2 int8);
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
drop function if exists testrngfunc;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
create function testrngfunc() returns record as $$
  insert into rngfunc values (1,2) returning *;
$$ language sql;
--DDL_STATEMENT_END--

select testrngfunc();
select * from testrngfunc() as t(f1 int8,f2 int8);
select * from testrngfunc(); -- fail

--DDL_STATEMENT_BEGIN--
drop function testrngfunc();
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
create function testrngfunc() returns setof record as $$
  insert into rngfunc values (1,2), (3,4) returning *;
$$ language sql;
--DDL_STATEMENT_END--

select testrngfunc();
select * from testrngfunc() as t(f1 int8,f2 int8);
select * from testrngfunc(); -- fail

--DDL_STATEMENT_BEGIN--
drop function testrngfunc();
--DDL_STATEMENT_END--

--
-- Check some cases involving added/dropped columns in a rowtype result
--

--DDL_STATEMENT_BEGIN--
create temp table users (userid text, seq int, email text, todrop bool, moredrop int, enabled bool);
--DDL_STATEMENT_END--
insert into users values ('id',1,'email',true,11,true);
insert into users values ('id2',2,'email2',true,12,true);
--DDL_STATEMENT_BEGIN--
alter table users drop column todrop;
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
create or replace function get_first_user() returns users as
$$ SELECT * FROM users ORDER BY userid LIMIT 1; $$
language sql stable;
--DDL_STATEMENT_END--

SELECT get_first_user();
SELECT * FROM get_first_user();

--DDL_STATEMENT_BEGIN--
create or replace function get_users() returns setof users as
$$ SELECT * FROM users ORDER BY userid; $$
language sql stable;
--DDL_STATEMENT_END--

SELECT get_users();
SELECT * FROM get_users();
SELECT * FROM get_users() WITH ORDINALITY;   -- make sure ordinality copes

-- multiple functions vs. dropped columns
SELECT * FROM ROWS FROM(generate_series(10,11), get_users()) WITH ORDINALITY;
SELECT * FROM ROWS FROM(get_users(), generate_series(10,11)) WITH ORDINALITY;

-- check that we can cope with post-parsing changes in rowtypes
--DDL_STATEMENT_BEGIN--
create temp view usersview as
SELECT * FROM ROWS FROM(get_users(), generate_series(10,11)) WITH ORDINALITY;
--DDL_STATEMENT_END--

select * from usersview;
--DDL_STATEMENT_BEGIN--
alter table users add column junk text;
--DDL_STATEMENT_END--
select * from usersview;
begin;
--DDL_STATEMENT_BEGIN--
alter table users drop column moredrop;
--DDL_STATEMENT_END--
select * from usersview;  -- expect clean failure
rollback;
--DDL_STATEMENT_BEGIN--
alter table users alter column seq type numeric;
--DDL_STATEMENT_END--
select * from usersview;  -- expect clean failure

--DDL_STATEMENT_BEGIN--
drop view usersview;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
drop function get_first_user();
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
drop function get_users();
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
drop table users;
--DDL_STATEMENT_END--

-- this won't get inlined because of type coercion, but it shouldn't fail

--DDL_STATEMENT_BEGIN--
create or replace function rngfuncbar() returns setof text as
$$ select 'foo'::varchar union all select 'bar'::varchar ; $$
language sql stable;
--DDL_STATEMENT_END--

select rngfuncbar();
select * from rngfuncbar();

--DDL_STATEMENT_BEGIN--
drop function rngfuncbar();
--DDL_STATEMENT_END--

-- check handling of a SQL function with multiple OUT params (bug #5777)

--DDL_STATEMENT_BEGIN--
create or replace function rngfuncbar(out integer, out numeric) as
$$ select (1, 2.1) $$ language sql;
--DDL_STATEMENT_END--

select * from rngfuncbar();

--DDL_STATEMENT_BEGIN--
create or replace function rngfuncbar(out integer, out numeric) as
$$ select (1, 2) $$ language sql;
--DDL_STATEMENT_END--

select * from rngfuncbar();  -- fail

--DDL_STATEMENT_BEGIN--
create or replace function rngfuncbar(out integer, out numeric) as
$$ select (1, 2.1, 3) $$ language sql;
--DDL_STATEMENT_END--

select * from rngfuncbar();  -- fail

--DDL_STATEMENT_BEGIN--
drop function rngfuncbar();
--DDL_STATEMENT_END--

-- check whole-row-Var handling in nested lateral functions (bug #11703)

--DDL_STATEMENT_BEGIN--
create function extractq2(t int8_tbl) returns int8 as $$
  select t.q2
$$ language sql immutable;
--DDL_STATEMENT_END--

explain (verbose, costs off)
select x from int8_tbl, extractq2(int8_tbl) f(x);

select x from int8_tbl, extractq2(int8_tbl) f(x);

--DDL_STATEMENT_BEGIN--
create function extractq2_2(t int8_tbl) returns table(ret1 int8) as $$
  select extractq2(t) offset 0
$$ language sql immutable;
--DDL_STATEMENT_END--

explain (verbose, costs off)
select x from int8_tbl, extractq2_2(int8_tbl) f(x);

-- syntax error currently: select x from int8_tbl, extractq2_2(int8_tbl) f(x);

-- without the "offset 0", this function gets optimized quite differently

--DDL_STATEMENT_BEGIN--
create function extractq2_2_opt(t int8_tbl) returns table(ret1 int8) as $$
  select extractq2(t)
$$ language sql immutable;
--DDL_STATEMENT_END--

explain (verbose, costs off)
select x from int8_tbl, extractq2_2_opt(int8_tbl) f(x);

select x from int8_tbl, extractq2_2_opt(int8_tbl) f(x);

-- check handling of nulls in SRF results (bug #7808)

--DDL_STATEMENT_BEGIN--
create type rngfunc2 as (a integer, b text);
--DDL_STATEMENT_END--

select *, row_to_json(u) from unnest(array[(1,'foo')::rngfunc2, null::rngfunc2]) u;
select *, row_to_json(u) from unnest(array[null::rngfunc2, null::rngfunc2]) u;
select *, row_to_json(u) from unnest(array[null::rngfunc2, (1,'foo')::rngfunc2, null::rngfunc2]) u;
select *, row_to_json(u) from unnest(array[]::rngfunc2[]) u;

--DDL_STATEMENT_BEGIN--
drop type rngfunc2;
--DDL_STATEMENT_END--