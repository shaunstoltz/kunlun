-- Test basic TRUNCATE functionality.
--DDL_STATEMENT_BEGIN--
CREATE TABLE truncate_a (col1 integer primary key);
--DDL_STATEMENT_END--
INSERT INTO truncate_a VALUES (1);
INSERT INTO truncate_a VALUES (2);
SELECT * FROM truncate_a;
-- Roll truncate back
BEGIN;
TRUNCATE truncate_a;
ROLLBACK;
SELECT * FROM truncate_a;
-- Commit the truncate this time
BEGIN;
TRUNCATE truncate_a;
COMMIT;
SELECT * FROM truncate_a;

-- Test foreign-key checks
--DDL_STATEMENT_BEGIN--
CREATE TABLE trunc_b (a int REFERENCES truncate_a);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE trunc_c (a serial PRIMARY KEY);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE trunc_d (a int REFERENCES trunc_c);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE trunc_e (a int REFERENCES truncate_a, b int REFERENCES trunc_c);
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE truncate_a;		-- fail
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE truncate_a,trunc_b;		-- fail
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE truncate_a,trunc_b,trunc_e;	-- ok
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE truncate_a,trunc_e;		-- fail
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE trunc_c;		-- fail
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE trunc_c,trunc_d;		-- fail
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE trunc_c,trunc_d,trunc_e;	-- ok
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE trunc_c,trunc_d,trunc_e,truncate_a;	-- fail
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE trunc_c,trunc_d,trunc_e,truncate_a,trunc_b;	-- ok
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE truncate_a RESTRICT; -- fail
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE truncate_a CASCADE;  -- ok
--DDL_STATEMENT_END--

-- circular references
--DDL_STATEMENT_BEGIN--
ALTER TABLE truncate_a ADD FOREIGN KEY (col1) REFERENCES trunc_c;
--DDL_STATEMENT_END--

-- Add some data to verify that truncating actually works ...
INSERT INTO trunc_c VALUES (1);
INSERT INTO truncate_a VALUES (1);
INSERT INTO trunc_b VALUES (1);
INSERT INTO trunc_d VALUES (1);
INSERT INTO trunc_e VALUES (1,1);
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE trunc_c;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE trunc_c,truncate_a;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE trunc_c,truncate_a,trunc_d;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE trunc_c,truncate_a,trunc_d,trunc_e;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE trunc_c,truncate_a,trunc_d,trunc_e,trunc_b;
--DDL_STATEMENT_END--

-- Verify that truncating did actually work
SELECT * FROM truncate_a
   UNION ALL
 SELECT * FROM trunc_c
   UNION ALL
 SELECT * FROM trunc_b
   UNION ALL
 SELECT * FROM trunc_d;
SELECT * FROM trunc_e;

-- Add data again to test TRUNCATE ... CASCADE
INSERT INTO trunc_c VALUES (1);
INSERT INTO truncate_a VALUES (1);
INSERT INTO trunc_b VALUES (1);
INSERT INTO trunc_d VALUES (1);
INSERT INTO trunc_e VALUES (1,1);
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE trunc_c CASCADE;  -- ok
--DDL_STATEMENT_END--

SELECT * FROM truncate_a
   UNION ALL
 SELECT * FROM trunc_c
   UNION ALL
 SELECT * FROM trunc_b
   UNION ALL
 SELECT * FROM trunc_d;
SELECT * FROM trunc_e;

--DDL_STATEMENT_BEGIN--
DROP TABLE truncate_a,trunc_c,trunc_b,trunc_d,trunc_e CASCADE;
--DDL_STATEMENT_END--

-- Test TRUNCATE with inheritance

--DDL_STATEMENT_BEGIN--
CREATE TABLE trunc_f (col1 integer primary key);
--DDL_STATEMENT_END--
INSERT INTO trunc_f VALUES (1);
INSERT INTO trunc_f VALUES (2);

--DDL_STATEMENT_BEGIN--
CREATE TABLE trunc_fa (col2a text) INHERITS (trunc_f);
--DDL_STATEMENT_END--
INSERT INTO trunc_fa VALUES (3, 'three');

--DDL_STATEMENT_BEGIN--
CREATE TABLE trunc_fb (col2b int) INHERITS (trunc_f);
--DDL_STATEMENT_END--
INSERT INTO trunc_fb VALUES (4, 444);

--DDL_STATEMENT_BEGIN--
CREATE TABLE trunc_faa (col3 text) INHERITS (trunc_fa);
--DDL_STATEMENT_END--
INSERT INTO trunc_faa VALUES (5, 'five', 'FIVE');

BEGIN;
SELECT * FROM trunc_f;
TRUNCATE trunc_f;
SELECT * FROM trunc_f;
ROLLBACK;

BEGIN;
SELECT * FROM trunc_f;
TRUNCATE ONLY trunc_f;
SELECT * FROM trunc_f;
ROLLBACK;

BEGIN;
SELECT * FROM trunc_f;
SELECT * FROM trunc_fa;
SELECT * FROM trunc_faa;
TRUNCATE ONLY trunc_fb, ONLY trunc_fa;
SELECT * FROM trunc_f;
SELECT * FROM trunc_fa;
SELECT * FROM trunc_faa;
ROLLBACK;

BEGIN;
SELECT * FROM trunc_f;
SELECT * FROM trunc_fa;
SELECT * FROM trunc_faa;
TRUNCATE ONLY trunc_fb, trunc_fa;
SELECT * FROM trunc_f;
SELECT * FROM trunc_fa;
SELECT * FROM trunc_faa;
ROLLBACK;

--DDL_STATEMENT_BEGIN--
DROP TABLE trunc_f CASCADE;
--DDL_STATEMENT_END--

-- Test ON TRUNCATE triggers

--DDL_STATEMENT_BEGIN--
CREATE TABLE trunc_trigger_test (f1 int, f2 text, f3 text);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE trunc_trigger_log (tgop text, tglevel text, tgwhen text,
        tgargv text, tgtable name, rowcount bigint);
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
CREATE FUNCTION trunctrigger() RETURNS trigger as $$
declare c bigint;
begin
    execute 'select count(*) from ' || quote_ident(tg_table_name) into c;
    insert into trunc_trigger_log values
      (TG_OP, TG_LEVEL, TG_WHEN, TG_ARGV[0], tg_table_name, c);
    return null;
end;
$$ LANGUAGE plpgsql;
--DDL_STATEMENT_END--

-- basic before trigger
INSERT INTO trunc_trigger_test VALUES(1, 'foo', 'bar'), (2, 'baz', 'quux');

--DDL_STATEMENT_BEGIN--
CREATE TRIGGER t
BEFORE TRUNCATE ON trunc_trigger_test
FOR EACH STATEMENT
EXECUTE PROCEDURE trunctrigger('before trigger truncate');
--DDL_STATEMENT_END--

SELECT count(*) as "Row count in test table" FROM trunc_trigger_test;
SELECT * FROM trunc_trigger_log;
--DDL_STATEMENT_BEGIN--
TRUNCATE trunc_trigger_test;
--DDL_STATEMENT_END--
SELECT count(*) as "Row count in test table" FROM trunc_trigger_test;
SELECT * FROM trunc_trigger_log;

--DDL_STATEMENT_BEGIN--
DROP TRIGGER t ON trunc_trigger_test;
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
truncate trunc_trigger_log;
--DDL_STATEMENT_END--

-- same test with an after trigger
INSERT INTO trunc_trigger_test VALUES(1, 'foo', 'bar'), (2, 'baz', 'quux');

--DDL_STATEMENT_BEGIN--
CREATE TRIGGER tt
AFTER TRUNCATE ON trunc_trigger_test
FOR EACH STATEMENT
EXECUTE PROCEDURE trunctrigger('after trigger truncate');
--DDL_STATEMENT_END--

SELECT count(*) as "Row count in test table" FROM trunc_trigger_test;
SELECT * FROM trunc_trigger_log;
--DDL_STATEMENT_BEGIN--
TRUNCATE trunc_trigger_test;
--DDL_STATEMENT_END--
SELECT count(*) as "Row count in test table" FROM trunc_trigger_test;
SELECT * FROM trunc_trigger_log;

--DDL_STATEMENT_BEGIN--
DROP TABLE trunc_trigger_test;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP TABLE trunc_trigger_log;
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
DROP FUNCTION trunctrigger();
--DDL_STATEMENT_END--

-- test TRUNCATE ... RESTART IDENTITY
--DDL_STATEMENT_BEGIN--
CREATE SEQUENCE truncate_a_id1 START WITH 33;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE truncate_a (id serial,
                         id1 integer default nextval('truncate_a_id1'));
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--						 
ALTER SEQUENCE truncate_a_id1 OWNED BY truncate_a.id1;
--DDL_STATEMENT_END--

INSERT INTO truncate_a DEFAULT VALUES;
INSERT INTO truncate_a DEFAULT VALUES;
SELECT * FROM truncate_a;

--DDL_STATEMENT_BEGIN--
TRUNCATE truncate_a;
--DDL_STATEMENT_END--

INSERT INTO truncate_a DEFAULT VALUES;
INSERT INTO truncate_a DEFAULT VALUES;
SELECT * FROM truncate_a;

--DDL_STATEMENT_BEGIN--
TRUNCATE truncate_a RESTART IDENTITY;
--DDL_STATEMENT_END--

INSERT INTO truncate_a DEFAULT VALUES;
INSERT INTO truncate_a DEFAULT VALUES;
SELECT * FROM truncate_a;

--DDL_STATEMENT_BEGIN--
CREATE TABLE truncate_b (id int GENERATED ALWAYS AS IDENTITY (START WITH 44));
--DDL_STATEMENT_END--

INSERT INTO truncate_b DEFAULT VALUES;
INSERT INTO truncate_b DEFAULT VALUES;
SELECT * FROM truncate_b;

--DDL_STATEMENT_BEGIN--
TRUNCATE truncate_b;
--DDL_STATEMENT_END--

INSERT INTO truncate_b DEFAULT VALUES;
INSERT INTO truncate_b DEFAULT VALUES;
SELECT * FROM truncate_b;

--DDL_STATEMENT_BEGIN--
TRUNCATE truncate_b RESTART IDENTITY;
--DDL_STATEMENT_END--

INSERT INTO truncate_b DEFAULT VALUES;
INSERT INTO truncate_b DEFAULT VALUES;
SELECT * FROM truncate_b;

-- check rollback of a RESTART IDENTITY operation
BEGIN;
--DDL_STATEMENT_BEGIN--
TRUNCATE truncate_a RESTART IDENTITY;
--DDL_STATEMENT_END--
INSERT INTO truncate_a DEFAULT VALUES;
SELECT * FROM truncate_a;
ROLLBACK;
INSERT INTO truncate_a DEFAULT VALUES;
INSERT INTO truncate_a DEFAULT VALUES;
SELECT * FROM truncate_a;

--DDL_STATEMENT_BEGIN--
DROP TABLE truncate_a;
--DDL_STATEMENT_END--

SELECT nextval('truncate_a_id1'); -- fail, seq should have been dropped

-- partitioned table
--DDL_STATEMENT_BEGIN--
CREATE TABLE truncparted (a int, b char) PARTITION BY LIST (a);
--DDL_STATEMENT_END--
-- error, can't truncate a partitioned table
--DDL_STATEMENT_BEGIN--
TRUNCATE ONLY truncparted;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE truncparted1 PARTITION OF truncparted FOR VALUES IN (1);
--DDL_STATEMENT_END--
INSERT INTO truncparted VALUES (1, 'a');
-- error, must truncate partitions
--DDL_STATEMENT_BEGIN--
TRUNCATE ONLY truncparted;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
TRUNCATE truncparted;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP TABLE truncparted;
--DDL_STATEMENT_END--

-- foreign key on partitioned table: partition key is referencing column.
-- Make sure truncate did execute on all tables
--DDL_STATEMENT_BEGIN--
CREATE FUNCTION tp_ins_data() RETURNS void LANGUAGE plpgsql AS $$
  BEGIN
	INSERT INTO truncprim VALUES (1), (100), (150);
	INSERT INTO truncpart VALUES (1), (100), (150);
  END
$$;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE FUNCTION tp_chk_data(OUT pktb regclass, OUT pkval int, OUT fktb regclass, OUT fkval int)
  RETURNS SETOF record LANGUAGE plpgsql AS $$
  BEGIN
    RETURN QUERY SELECT
      pk.tableoid::regclass, pk.a, fk.tableoid::regclass, fk.a
    FROM truncprim pk FULL JOIN truncpart fk USING (a)
    ORDER BY 2, 4;
  END
$$;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE truncprim (a int PRIMARY KEY);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE truncpart (a int REFERENCES truncprim)
  PARTITION BY RANGE (a);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE truncpart_1 PARTITION OF truncpart FOR VALUES FROM (0) TO (100);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE truncpart_2 PARTITION OF truncpart FOR VALUES FROM (100) TO (200)
  PARTITION BY RANGE (a);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE truncpart_2_1 PARTITION OF truncpart_2 FOR VALUES FROM (100) TO (150);
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
CREATE TABLE truncpart_2_d PARTITION OF truncpart_2 DEFAULT;
--DDL_STATEMENT_END--

--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE truncprim;	-- should fail
--DDL_STATEMENT_END--

select tp_ins_data();
-- should truncate everything
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE truncprim, truncpart;
--DDL_STATEMENT_END--
select * from tp_chk_data();

select tp_ins_data();
-- should truncate everything
SET client_min_messages TO WARNING;	-- suppress cascading notices
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE truncprim CASCADE;
--DDL_STATEMENT_END--
RESET client_min_messages;
SELECT * FROM tp_chk_data();

SELECT tp_ins_data();
-- should truncate all partitions
--DDL_STATEMENT_BEGIN--
TRUNCATE TABLE truncpart;
--DDL_STATEMENT_END--
SELECT * FROM tp_chk_data();
--DDL_STATEMENT_BEGIN--
DROP TABLE truncprim, truncpart;
--DDL_STATEMENT_END--
--DDL_STATEMENT_BEGIN--
DROP FUNCTION tp_ins_data(), tp_chk_data();
--DDL_STATEMENT_END--