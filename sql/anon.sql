
--------------------------------------------------------------------------------
-- Security First
--------------------------------------------------------------------------------

-- Untrusted users cannot do anything inside the anon schema
REVOKE ALL ON SCHEMA anon FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA anon FROM PUBLIC;
-- ...except calling the functions
GRANT USAGE ON SCHEMA anon TO PUBLIC;
-- other privileges will be granted below on a case-by-case basis


--
-- By default, masking filter functions must be trusted
-- and we only trust functions from the `anon` namespaces
--
SECURITY LABEL FOR anon ON SCHEMA anon IS 'TRUSTED';

--
-- In the same spirit, the functions below that are NOT masking functions,
-- (i.e. mostly internal functions of the masking engine) are labeled as
-- `UNSTRUSTED` to block users from using them in masking rules.
--

--
-- This extension will create views based on masking functions. These functions
-- will be run as with privileges of the owners of the views. This is prone
-- to search_path attacks: an untrusted user may be able to override some
-- functions and gain superuser privileges.
--
-- Therefore all functions should be defined with `SET search_path=''` even if
-- they are not SECURITY DEFINER.
--
-- More about this:
-- https://www.postgresql.org/docs/current/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY
-- https://www.cybertec-postgresql.com/en/abusing-security-definer-functions/
--

-------------------------------------------------------------------------------
-- TRUSTED pg_catalog functions
-------------------------------------------------------------------------------

-- Some pg_catalog functions, such as `pg_terminate_backend()`, should not be
-- used in masking rule. That's why the pg_catalog schema is not trusted by
-- by default. As we try to discourage users to mark it as TRUSTED, we provide
-- a simple way to trust some functions individually in order to allow usage of
-- some safe and useful functions.
--
-- Note: A function may have multiple definitions (e.g. `age(DATE,DATE)` and
-- `age(TIMESTAMP,TIMESTAMP)`). In such case, trusting one definition is
-- equivalent to trusting all of the definitions.
--
-- Obviously we're not trying to be exhaustive here. There's just too many
-- pg_catalog functions, but if you think a useful function is missing below,
-- please open a ticket.
--

SECURITY LABEL FOR anon ON FUNCTION pg_catalog.array_to_json(ANYARRAY) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.age(TIMESTAMP, TIMESTAMP) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.btrim(TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.concat(VARIADIC "any") IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.date_part(TEXT,TIMESTAMP) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.date_trunc(TEXT,TIMESTAMP) IS 'TRUSTED';
-- gen_random_uuid is not present in PG12, uncomment this in 2015
--SECURITY LABEL FOR anon ON FUNCTION pg_catalog.gen_random_uuid IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.json_build_array() IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.jsonb_build_array() IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.json_build_object() IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.jsonb_build_object() IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.json_object(TEXT[]) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.jsonb_object(TEXT[]) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.left(TEXT, INTEGER) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.length(TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.lower(TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.ltrim(TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.make_date(INT,INT,INT ) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.make_time(INT,INT,DOUBLE PRECISION) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.md5(TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.now() IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.random() IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.regexp_replace(TEXT,TEXT,TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.regexp_replace(TEXT,TEXT,TEXT,TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.repeat IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.replace(TEXT,TEXT,TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.right(TEXT,INTEGER) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.row_to_json(RECORD)  IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.rtrim(TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.substr(TEXT,INTEGER) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.to_char(TIMESTAMP,TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.to_date(TEXT,TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.to_json IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.to_jsonb IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.to_number(TEXT,TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.to_timestamp(TEXT,TEXT) IS 'TRUSTED';
SECURITY LABEL FOR anon ON FUNCTION pg_catalog.upper(TEXT) IS 'TRUSTED';

-- Display all the trusted functions
CREATE OR REPLACE VIEW anon.pg_trusted_functions
AS
  SELECT
    objnamespace::REGNAMESPACE AS schema,
    objname AS function
  FROM pg_seclabels
  WHERE upper(label) = 'TRUSTED'
  AND objtype='function'
  ORDER BY 1,2
;


-------------------------------------------------------------------------------
-- Bindings to useful functions in pg_catalog
-------------------------------------------------------------------------------

--
-- This section is undocumented and unsupported.
-- Kept for backward compatibility with rules written for version 1.3
--

CREATE OR REPLACE FUNCTION anon.age(TIMESTAMP, TIMESTAMP)
  RETURNS INTERVAL AS
  $$ SELECT pg_catalog.age($1,$2) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.age(TIMESTAMP)
  RETURNS INTERVAL AS
  $$ SELECT pg_catalog.age($1) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.concat(TEXT,TEXT)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.concat($1,$2) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.concat(TEXT,TEXT,TEXT)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.concat($1,$2,$3) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.date_add(TIMESTAMP WITH TIME ZONE,INTERVAL)
  RETURNS TIMESTAMP WITH TIME ZONE AS
  $$ SELECT $1 + $2; $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.date_part(TEXT,TIMESTAMP)
  RETURNS double precision AS
  $$ SELECT pg_catalog.date_part($1,$2); $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.date_part(TEXT,INTERVAL)
  RETURNS double precision AS
  $$ SELECT pg_catalog.date_part($1,$2); $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.date_subtract(TIMESTAMP WITH TIME ZONE, INTERVAL )
  RETURNS TIMESTAMP WITH TIME ZONE AS
  $$ SELECT $1 - $2; $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.date_trunc(TEXT,TIMESTAMP)
  RETURNS TIMESTAMP AS
  $$ SELECT pg_catalog.date_trunc($1,$2); $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.date_trunc(TEXT,TIMESTAMP WITH TIME ZONE)
  RETURNS TIMESTAMP WITH TIME ZONE AS
  $$ SELECT pg_catalog.date_trunc($1,$2); $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.date_trunc(TEXT,INTERVAL)
  RETURNS INTERVAL AS
  $$ SELECT pg_catalog.date_trunc($1,$2); $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.left(TEXT, INTEGER)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.left($1,$2) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.length(TEXT)
  RETURNS INTEGER AS
  $$ SELECT pg_catalog.length($1) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.lower(TEXT)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.lower($1) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.make_date(INT,INT,INT )
  RETURNS date AS
  $$ SELECT pg_catalog.make_date($1,$2,$3); $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.make_time(INT,INT,DOUBLE PRECISION)
  RETURNS time AS
  $$ SELECT pg_catalog.make_time($1,$2,$3); $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.md5(TEXT)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.md5($1) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.now()
  RETURNS TIMESTAMP WITH TIME ZONE AS
  $$ SELECT pg_catalog.now() $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.random()
  RETURNS DOUBLE PRECISION AS
  $$ SELECT pg_catalog.random() $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.replace(TEXT,TEXT,TEXT)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.md5($1,$2,$3) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.regexp_replace(TEXT,TEXT,TEXT)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.regexp_replace($1,$2,$3) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.regexp_replace(TEXT,TEXT,TEXT,TEXT)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.regexp_replace($1,$2,$3,$4) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.right(TEXT,INTEGER)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.right($1,$2) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.substr(TEXT,INTEGER)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.substr($1,$2) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.substr(TEXT,INTEGER,INTEGER)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.substr($1,$2,$3) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.to_char(TIMESTAMP,TEXT)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.to_char($1,$2) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.to_char(TIMESTAMP WITH TIME ZONE, TEXT)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.to_char($1,$2) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.to_char(INTERVAL,TEXT)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.to_char($1,$2) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.to_char(NUMERIC,TEXT)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.to_char($1,$2) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.to_date(TEXT,TEXT)
  RETURNS DATE AS
  $$ SELECT pg_catalog.to_date($1,$2) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.to_number(TEXT,TEXT)
  RETURNS NUMERIC AS
  $$ SELECT pg_catalog.to_number($1,$2) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.to_timestamp(TEXT,TEXT)
  RETURNS TIMESTAMP WITH TIME ZONE AS
  $$ SELECT pg_catalog.to_timestamp($1,$2) $$
  LANGUAGE SQL PARALLEL SAFE;

CREATE OR REPLACE FUNCTION anon.upper(TEXT)
  RETURNS TEXT AS
  $$ SELECT pg_catalog.upper($1) $$
  LANGUAGE SQL PARALLEL SAFE;


-------------------------------------------------------------------------------
-- Common functions
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION anon.version()
RETURNS TEXT AS
$func$
  SELECT extversion FROM pg_extension WHERE extname='anon';
$func$
  LANGUAGE SQL
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

-- Returns TRUE if the column exists in the table
CREATE OR REPLACE FUNCTION anon.column_exists(
  table_relid regclass,
  column_name NAME
)
RETURNS BOOLEAN
AS $func$
  SELECT count(attname)>0
  FROM pg_catalog.pg_attribute
  WHERE attrelid = table_relid
  AND attnum > 0 -- Ordinary columns are numbered from 1 up
  AND NOT attisdropped
  AND attname = column_name;
$func$
  LANGUAGE SQL
  STABLE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;


-- Returns a value or another value :)
--
-- This provides a shorter way to write conditional masking rules
--
-- See https://gitlab.com/dalibo/postgresql_anonymizer/-/issues/383#note_1676912245
--
CREATE OR REPLACE FUNCTION anon.ternary(
  condition BOOL,
  then_val ANYELEMENT,
  else_val ANYELEMENT)
RETURNS ANYELEMENT
AS $$
  SELECT CASE WHEN condition THEN then_val ELSE else_val END;
$$
LANGUAGE SQL
;


-- Return the default value of a given column
--
-- * relid : the relation id
-- * num   : the ordered number of the column
--
-- Introduced for version 2.0
--
CREATE OR REPLACE FUNCTION anon.get_attrdef(
    relid INT,
    num   INT
)
RETURNS TEXT
AS $$
    SELECT pg_catalog.pg_get_expr(adbin,adrelid)
    FROM pg_catalog.pg_attrdef
    WHERE adrelid=relid
    AND   adnum=num;
$$ LANGUAGE SQL STRICT;

-------------------------------------------------------------------------------
-- Noise
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION anon.add_noise_on_numeric_column(
  noise_table regclass,
  noise_column TEXT,
  ratio FLOAT
)
RETURNS BOOLEAN
AS $func$
BEGIN

  -- Stop if noise_column does not exist
  IF NOT anon.column_exists(noise_table,noise_column) THEN
    RAISE EXCEPTION 'Column "%" does not exist in table "%".',
                    noise_column,
                    noise_table;
    RETURN FALSE;
  END IF;

  IF ratio < 0 OR ratio > 1 THEN
    RAISE EXCEPTION 'ratio must be between 0 and 1';
    RETURN FALSE;
  END IF;

  EXECUTE format('
     UPDATE %I
     SET %I = %I *  (1+ (2 * random() - 1 ) * %L) ;
     ', noise_table, noise_column, noise_column, ratio
);
RETURN TRUE;
END;
$func$
  LANGUAGE plpgsql
  VOLATILE
  PARALLEL UNSAFE -- because of the EXCEPTION
  SECURITY INVOKER
; -- SET search_path='';

CREATE OR REPLACE FUNCTION anon.add_noise_on_datetime_column(
  noise_table regclass,
  noise_column TEXT,
  variation INTERVAL
)
RETURNS BOOLEAN
AS $func$
BEGIN
  -- Stop if noise_column does not exist
  IF NOT anon.column_exists(noise_table,noise_column) THEN
    RAISE EXCEPTION 'Column "%" does not exist in table "%".',
                  noise_column,
                  noise_table;
    RETURN FALSE;
  END IF;

  EXECUTE format('UPDATE %I SET %I = %I + (2 * random() - 1 ) * ''%s''::INTERVAL',
                  noise_table,
                  noise_column,
                  noise_column,
                  variation
  );
  RETURN TRUE;
END;
$func$
  LANGUAGE plpgsql
  VOLATILE
  PARALLEL UNSAFE -- because of the EXCEPTION
  SECURITY INVOKER
; --SET search_path='';

-------------------------------------------------------------------------------
-- "on the fly" noise
-------------------------------------------------------------------------------

-- for numerical values
CREATE OR REPLACE FUNCTION anon.noise(
  noise_value ANYELEMENT,
  ratio DOUBLE PRECISION
)
 RETURNS ANYELEMENT
AS $func$
DECLARE
  res ALIAS FOR $0;
  ran float;
BEGIN
  ran = (2.0 * random() - 1.0) * ratio;
  SELECT (noise_value * (1.0 - ran))::ANYELEMENT
    INTO res;
  RETURN res;
EXCEPTION
  WHEN numeric_value_out_of_range THEN
    SELECT (noise_value * (1.0 + ran))::ANYELEMENT
      INTO res;
    RETURN res;
END;
$func$
  LANGUAGE plpgsql
  VOLATILE
  PARALLEL UNSAFE -- because of the EXCEPTION
  SECURITY INVOKER
  SET search_path='';

-- for time and timestamp values
CREATE OR REPLACE FUNCTION anon.dnoise(
  noise_value ANYELEMENT,
  noise_range INTERVAL
)
 RETURNS ANYELEMENT
AS $func$
DECLARE
  res ALIAS FOR $0;
  ran INTERVAL;
BEGIN
  ran = (2.0 * random() - 1.0) * noise_range;
  SELECT (noise_value + ran)::ANYELEMENT
    INTO res;
  RETURN res;
EXCEPTION
  WHEN datetime_field_overflow THEN
    SELECT (noise_value - ran)::ANYELEMENT
      INTO res;
    RETURN res;
END;
$func$
  LANGUAGE plpgsql
  VOLATILE
  PARALLEL UNSAFE -- because of the EXCEPTION
  SECURITY INVOKER
  SET search_path=''
;


-------------------------------------------------------------------------------
-- Shuffle
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION anon.shuffle_column(
  shuffle_table regclass,
  shuffle_column NAME,
  primary_key NAME
)
RETURNS BOOLEAN
AS $func$
BEGIN
  IF NOT anon.column_exists(shuffle_table,shuffle_column) THEN
    RAISE EXCEPTION 'Column "%" does not exist in table "%".',
                  shuffle_column,
                  shuffle_table;
    RETURN FALSE;
  END IF;

  -- Stop if primary_key does not exist
  IF NOT anon.column_exists(shuffle_table,primary_key) THEN
    RAISE EXCEPTION 'Column "%" does not exist in table "%".',
                  primary_key,
                  shuffle_table;
    RETURN FALSE;
  END IF;

  -- shuffle
  EXECUTE format('
  WITH s1 AS (
    -- shuffle the primary key
    SELECT row_number() over (order by random()) n,
           %3$I AS pkey
    FROM %1$s
  ),
  s2 AS (
    -- shuffle the column
    SELECT row_number() over (order by random()) n,
           %2$I AS val
    FROM %1$s
  )
  UPDATE %1$s
  SET %2$I = s2.val
  FROM s1 JOIN s2 ON s1.n = s2.n
  WHERE %3$I = s1.pkey;
  ', shuffle_table, shuffle_column, primary_key);
  RETURN TRUE;
END;
$func$
  LANGUAGE plpgsql
  VOLATILE
  PARALLEL UNSAFE -- because of UPDATE
  SECURITY INVOKER
; --SET search_path='';

-------------------------------------------------------------------------------
-- Fake Data
-------------------------------------------------------------------------------

CREATE TYPE anon_fake_data_tables
AS ENUM (
  'address', 'city', 'company', 'country', 'email', 'first_name',
  'iban', 'last_name', 'lorem_ipsum', 'postcode', 'siret'
);

-- Address
DROP TABLE IF EXISTS anon.address;
CREATE TABLE anon.address (
  oid SERIAL PRIMARY KEY,
  val TEXT
);

ALTER TABLE anon.address CLUSTER ON address_pkey;
GRANT SELECT ON TABLE anon.address TO PUBLIC;
GRANT SELECT ON SEQUENCE anon.address_oid_seq TO PUBLIC;
--SELECT pg_catalog.pg_extension_config_dump('anon.address','');
--SELECT pg_catalog.pg_extension_config_dump('anon.address_oid_seq','');

COMMENT ON TABLE anon.address IS 'Fake Adresses';

-- Cities
DROP TABLE IF EXISTS anon.city;
CREATE TABLE anon.city (
  oid SERIAL PRIMARY KEY,
  val TEXT
);

ALTER TABLE anon.city CLUSTER ON city_pkey;
GRANT SELECT ON TABLE anon.city TO PUBLIC;
GRANT SELECT ON SEQUENCE anon.city_oid_seq TO PUBLIC;

--SELECT pg_catalog.pg_extension_config_dump('anon.city','');
--SELECT pg_catalog.pg_extension_config_dump('anon.city_oid_seq','');

COMMENT ON TABLE anon.city IS 'Fake Cities';

-- Companies
DROP TABLE IF EXISTS anon.company;
CREATE TABLE anon.company (
  oid SERIAL PRIMARY KEY,
  val TEXT
);

ALTER TABLE anon.company CLUSTER ON company_pkey;
GRANT SELECT ON TABLE anon.company TO PUBLIC;
GRANT SELECT ON SEQUENCE anon.company_oid_seq TO PUBLIC;

--SELECT pg_catalog.pg_extension_config_dump('anon.company','');
--SELECT pg_catalog.pg_extension_config_dump('anon.company_oid_seq','');

COMMENT ON TABLE anon.city IS 'Fake Companies';

-- Country
DROP TABLE IF EXISTS anon.country;
CREATE TABLE anon.country (
  oid SERIAL PRIMARY KEY,
  val TEXT
);

ALTER TABLE anon.country CLUSTER ON country_pkey;
GRANT SELECT ON TABLE anon.country TO PUBLIC;
GRANT SELECT ON SEQUENCE anon.country_oid_seq TO PUBLIC;

--SELECT pg_catalog.pg_extension_config_dump('anon.country','');
--SELECT pg_catalog.pg_extension_config_dump('anon.country_oid_seq','');

COMMENT ON TABLE anon.country IS 'Fake Countries';

-- Email
DROP TABLE IF EXISTS anon.email;
CREATE TABLE anon.email (
  oid SERIAL PRIMARY KEY,
  val TEXT
);

ALTER TABLE anon.email CLUSTER ON email_pkey;
GRANT SELECT ON TABLE anon.email TO PUBLIC;
GRANT SELECT ON SEQUENCE anon.email_oid_seq TO PUBLIC;

--SELECT pg_catalog.pg_extension_config_dump('anon.email','');
--SELECT pg_catalog.pg_extension_config_dump('anon.email_oid_seq','');

COMMENT ON TABLE anon.email IS 'Fake email adresses';

-- First names
DROP TABLE IF EXISTS anon.first_name;
CREATE TABLE anon.first_name (
  oid SERIAL PRIMARY KEY,
  val TEXT
);

ALTER TABLE anon.first_name CLUSTER ON first_name_pkey;
GRANT SELECT ON TABLE anon.first_name TO PUBLIC;
GRANT SELECT ON SEQUENCE anon.first_name_oid_seq TO PUBLIC;

--SELECT pg_catalog.pg_extension_config_dump('anon.first_name','');
--SELECT pg_catalog.pg_extension_config_dump('anon.first_name_oid_seq','');

COMMENT ON TABLE anon.first_name IS 'Fake first names';

-- IBAN
DROP TABLE IF EXISTS anon.iban;
CREATE TABLE anon.iban (
  oid SERIAL PRIMARY KEY,
  val TEXT
);

ALTER TABLE anon.iban CLUSTER ON iban_pkey;
GRANT SELECT ON TABLE anon.iban TO PUBLIC;
GRANT SELECT ON SEQUENCE anon.iban_oid_seq TO PUBLIC;

--SELECT pg_catalog.pg_extension_config_dump('anon.iban','');
--SELECT pg_catalog.pg_extension_config_dump('anon.iban_oid_seq','');

COMMENT ON TABLE anon.iban IS 'Fake IBAN codes';

-- Last names
DROP TABLE IF EXISTS anon.last_name;
CREATE TABLE anon.last_name (
  oid SERIAL PRIMARY KEY,
  val TEXT
);

ALTER TABLE anon.last_name CLUSTER ON last_name_pkey;
GRANT SELECT ON TABLE anon.last_name TO PUBLIC;
GRANT SELECT ON SEQUENCE anon.last_name_oid_seq TO PUBLIC;

--SELECT pg_catalog.pg_extension_config_dump('anon.last_name','');
--SELECT pg_catalog.pg_extension_config_dump('anon.last_name_oid_seq','');

COMMENT ON TABLE anon.last_name IS 'Fake last names';

-- Postcode
DROP TABLE IF EXISTS anon.postcode;
CREATE TABLE anon.postcode (
  oid SERIAL PRIMARY KEY,
  val TEXT
);

ALTER TABLE anon.postcode CLUSTER ON postcode_pkey;
GRANT SELECT ON TABLE anon.postcode TO PUBLIC;
GRANT SELECT ON SEQUENCE anon.postcode_oid_seq TO PUBLIC;

--SELECT pg_catalog.pg_extension_config_dump('anon.postcode','');
--SELECT pg_catalog.pg_extension_config_dump('anon.postcode_oid_seq','');

COMMENT ON TABLE anon.postcode IS 'Fake street post codes';

-- SIRET
DROP TABLE IF EXISTS anon.siret;
CREATE TABLE anon.siret (
  oid SERIAL PRIMARY KEY,
  val TEXT
);

ALTER TABLE anon.siret CLUSTER ON siret_pkey;
GRANT SELECT ON TABLE anon.siret TO PUBLIC;
GRANT SELECT ON SEQUENCE anon.siret_oid_seq TO PUBLIC;

--SELECT pg_catalog.pg_extension_config_dump('anon.siret','');
--SELECT pg_catalog.pg_extension_config_dump('anon.siret_oid_seq','');

COMMENT ON TABLE anon.siret IS 'Fake SIRET codes';

-- Lorem Ipsum
DROP TABLE IF EXISTS anon.lorem_ipsum;
CREATE TABLE anon.lorem_ipsum (
  oid SERIAL PRIMARY KEY,
  paragraph TEXT
);

ALTER TABLE anon.lorem_ipsum CLUSTER ON lorem_ipsum_pkey;
GRANT SELECT ON TABLE anon.lorem_ipsum TO PUBLIC;
GRANT SELECT ON SEQUENCE anon.lorem_ipsum_oid_seq TO PUBLIC;

--SELECT pg_catalog.pg_extension_config_dump('anon.lorem_ipsum','');
--SELECT pg_catalog.pg_extension_config_dump('anon.lorem_ipsum_oid_seq','');

COMMENT ON TABLE anon.lorem_ipsum IS 'Fake text';

-- ADD NEW TABLE HERE


-------------------------------------------------------------------------------
-- Discovery / Scanning
-------------------------------------------------------------------------------

-- https://labkey.med.ualberta.ca/labkey/_webdav/REDCap%20Support/@wiki/identifiers/identifiers.html?listing=html

CREATE TABLE anon.identifiers_category(
  name TEXT UNIQUE NOT NULL,
  direct_identifier BOOLEAN,
  anon_function TEXT
);

ALTER TABLE anon.identifiers_category
  CLUSTER ON identifiers_category_name_key;
GRANT SELECT ON TABLE anon.identifiers_category TO PUBLIC;
COMMENT ON TABLE anon.identifiers_category
IS 'Generic identifiers categories based the HIPAA classification';


CREATE TABLE anon.identifier(
  lang TEXT,
  attname TEXT,
  fk_identifiers_category TEXT,
  PRIMARY KEY(attname,lang),
  FOREIGN KEY (fk_identifiers_category)
    REFERENCES anon.identifiers_category(name)
);

ALTER TABLE anon.identifier
  CLUSTER ON identifier_pkey;
GRANT SELECT ON TABLE anon.identifier TO PUBLIC;
COMMENT ON TABLE anon.identifier
IS 'Dictionnary of common identifiers field names';

CREATE OR REPLACE FUNCTION anon.detect(
  dict_lang TEXT DEFAULT 'en_US'
)
RETURNS TABLE (
  table_name REGCLASS,
  column_name NAME,
  identifiers_category TEXT,
  direct BOOLEAN
)
AS $$
BEGIN
  IF not anon.is_initialized() THEN
    RAISE NOTICE 'The dictionary of identifiers is not present.'
      USING HINT = 'You probably need to run ''SELECT anon.init()'' ';
  END IF;

RETURN QUERY SELECT
  a.attrelid::regclass,
  a.attname,
  ic.name,
  ic.direct_identifier
FROM pg_catalog.pg_attribute a
JOIN anon.identifier fn
  ON lower(a.attname) = fn.attname
JOIN anon.identifiers_category ic
  ON fn.fk_identifiers_category = ic.name
JOIN pg_catalog.pg_class c
  ON c.oid = a.attrelid
WHERE fn.lang = dict_lang
  AND c.relnamespace IN ( -- exclude the extension tables and the catalog
        SELECT oid
        FROM pg_catalog.pg_namespace
        WHERE nspname NOT LIKE 'pg_%'
        AND nspname NOT IN  (
          'information_schema',
          'anon',
          pg_catalog.current_setting('anon.maskschema')::NAME
        )
      )
;
END;
$$
  LANGUAGE plpgsql
  PARALLEL SAFE
  STABLE
;


-------------------------------------------------------------------------------
-- Functions : INIT / RESET
-------------------------------------------------------------------------------

-- ADD unit tests in tests/sql/init.sql

CREATE OR REPLACE FUNCTION anon.load_csv(
  dest_table REGCLASS,
  csv_file TEXT
)
RETURNS BOOLEAN AS
$$
DECLARE
  csv_file_check TEXT;
  sequence TEXT;
BEGIN
-- This check does not work with PG 10 and below (absolute path not supported)
--
--  SELECT * INTO  csv_file_check
--  FROM pg_catalog.pg_stat_file(csv_file, missing_ok := TRUE );
--
--  IF csv_file_check IS NULL THEN
--    RAISE NOTICE 'Data file ''%'' is not present. Skipping.', csv_file;
--    RETURN FALSE;
--  END IF;

  -- load the csv file
  EXECUTE 'COPY ' || dest_table
      || ' FROM ' || quote_literal(csv_file);

  -- update the oid sequence (if any)
  SELECT pg_catalog.pg_get_serial_sequence(dest_table::TEXT,'oid')
  INTO sequence
  FROM pg_catalog.pg_attribute
  WHERE attname ='oid'
  AND attrelid = dest_table;

  IF sequence IS NOT NULL
  THEN
    EXECUTE format( 'SELECT pg_catalog.setval(%L, max(oid)) FROM %s',
                    sequence,
                    dest_table
    );
  END IF;

  -- clustering the table for better performance
  EXECUTE 'CLUSTER ' || dest_table;

  RETURN TRUE;

EXCEPTION

  WHEN undefined_file THEN
    RAISE NOTICE 'Data file ''%'' is not present. Skipping.', csv_file;
    RETURN FALSE;

  WHEN bad_copy_file_format THEN
    RAISE NOTICE 'Data file ''%'' has a bad CSV format. Skipping.', csv_file;
    RETURN FALSE;

  WHEN invalid_text_representation THEN
    RAISE NOTICE 'Data file ''%'' has a bad CSV format. Skipping.', csv_file;
    RETURN FALSE;

END;
$$
  LANGUAGE plpgsql
  VOLATILE
  RETURNS NULL ON NULL INPUT
  PARALLEL UNSAFE -- because of the EXCEPTION
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.load_csv IS 'UNTRUSTED';

-- load fake data from a given path
CREATE OR REPLACE FUNCTION anon.init(
  datapath TEXT
)
RETURNS BOOLEAN
AS $$
DECLARE
  datapath_check TEXT;
  success BOOLEAN;
BEGIN

  IF anon.is_initialized() THEN
    RAISE NOTICE 'The anon extension is already initialized.';
    RETURN TRUE;
  END IF;

  SELECT bool_or(results) INTO success
  FROM unnest(array[
    anon.load_csv('anon.identifiers_category',datapath||'/identifiers_category.csv'),
    anon.load_csv('anon.identifier',datapath ||'/identifier.csv'),
    anon.load_csv('anon.address',datapath ||'/address.csv'),
    anon.load_csv('anon.city',datapath ||'/city.csv'),
    anon.load_csv('anon.company',datapath ||'/company.csv'),
    anon.load_csv('anon.country',datapath ||'/country.csv'),
    anon.load_csv('anon.email', datapath ||'/email.csv'),
    anon.load_csv('anon.first_name',datapath ||'/first_name.csv'),
    anon.load_csv('anon.iban',datapath ||'/iban.csv'),
    anon.load_csv('anon.last_name',datapath ||'/last_name.csv'),
    anon.load_csv('anon.postcode',datapath ||'/postcode.csv'),
    anon.load_csv('anon.siret',datapath ||'/siret.csv'),
    anon.load_csv('anon.lorem_ipsum',datapath ||'/lorem_ipsum.csv')
  ]) results;
  RETURN success;

END;
$$
  LANGUAGE PLPGSQL
  VOLATILE
  RETURNS NULL ON NULL INPUT
  PARALLEL UNSAFE -- because load_csv is unsafe
  SECURITY INVOKER
  SET search_path=''
;
SECURITY LABEL FOR anon ON FUNCTION anon.init(TEXT) IS 'UNTRUSTED';

-- People tend to forget the anon.init() step
-- This is a friendly notice for them
CREATE OR REPLACE FUNCTION anon.notice_if_not_init()
RETURNS TEXT AS
$$
BEGIN
  IF NOT anon.is_initialized() THEN
    RAISE NOTICE 'The anon extension is not initialized.'
      USING HINT='Use ''SELECT anon.init()'' before running this function';
  END IF;
  RETURN NULL;
END;
$$
  LANGUAGE plpgsql
  STABLE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path='';
;
SECURITY LABEL FOR anon ON FUNCTION anon.notice_if_not_init IS 'UNTRUSTED';

-- load() is here for backward compatibility with version 0.6
CREATE OR REPLACE FUNCTION anon.load(TEXT)
RETURNS BOOLEAN AS
$$
  SELECT anon.init($1);
$$
  LANGUAGE SQL
  VOLATILE
  RETURNS NULL ON NULL INPUT
  PARALLEL UNSAFE -- because init() is unsafe
  SECURITY INVOKER
  SET search_path=''
;
SECURITY LABEL FOR anon ON FUNCTION anon.load(TEXT) IS 'UNTRUSTED';

-- If no path given, use the default data
CREATE OR REPLACE FUNCTION anon.init()
RETURNS BOOLEAN
AS $$
  WITH conf AS (
        -- find the local extension directory
        SELECT setting AS sharedir
        FROM pg_catalog.pg_config
        WHERE name = 'SHAREDIR'
    )
  SELECT anon.init(conf.sharedir || '/extension/anon/')
  FROM conf;
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL UNSAFE -- because init is unsafe
  SECURITY INVOKER
  SET search_path=''
;
SECURITY LABEL FOR anon ON FUNCTION anon.init() IS 'UNTRUSTED';

-- load() is here for backward compatibility with version 0.6 and below
CREATE OR REPLACE FUNCTION anon.load()
RETURNS BOOLEAN
AS $$
BEGIN
  RAISE NOTICE 'anon.load() will be deprecated in future versions.'
    USING HINT = 'you should use anon.init() instead.';
  RETURN anon.init();
END;
$$
  LANGUAGE plpgsql
  VOLATILE
  PARALLEL UNSAFE -- because init is unsafe
  SECURITY INVOKER
  SET search_path=''
;
SECURITY LABEL FOR anon ON FUNCTION anon.load() IS 'UNTRUSTED';

-- True if the fake data is already here
CREATE OR REPLACE FUNCTION anon.is_initialized()
RETURNS BOOLEAN
AS $$
  SELECT count(*)::INT::BOOLEAN
  FROM (   SELECT 1 FROM anon.address
     UNION SELECT 1 FROM anon.city
     UNION SELECT 1 FROM anon.company
     UNION SELECT 1 FROM anon.country
     UNION SELECT 1 FROM anon.email
     UNION SELECT 1 FROM anon.first_name
     UNION SELECT 1 FROM anon.iban
     UNION SELECT 1 FROM anon.last_name
     UNION SELECT 1 FROM anon.lorem_ipsum
     UNION SELECT 1 FROM anon.postcode
     UNION SELECT 1 FROM anon.siret
     -- ADD NEW TABLE HERE
     LIMIT 1
  ) t
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL SAFE
  SECURITY DEFINER
  SET search_path=''
;
SECURITY LABEL FOR anon ON FUNCTION anon.is_initialized IS 'UNTRUSTED';

-- remove all fake data
CREATE OR REPLACE FUNCTION anon.reset()
RETURNS BOOLEAN AS
$$
    TRUNCATE anon.address;
    TRUNCATE anon.city;
    TRUNCATE anon.company;
    TRUNCATE anon.country;
    TRUNCATE anon.email;
    TRUNCATE anon.first_name;
    TRUNCATE anon.iban;
    TRUNCATE anon.last_name;
    TRUNCATE anon.lorem_ipsum;
    TRUNCATE anon.postcode;
    TRUNCATE anon.siret;
    TRUNCATE anon.identifiers_category CASCADE;
    TRUNCATE anon.identifier;
    -- ADD NEW TABLE HERE
    SELECT TRUE;
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL UNSAFE -- because of TRUNCATE
  SECURITY INVOKER
  SET search_path=''
;
SECURITY LABEL FOR anon ON FUNCTION anon.reset IS 'UNTRUSTED';

-- backward compatibility with version 0.6 and below
CREATE OR REPLACE FUNCTION anon.unload()
RETURNS BOOLEAN AS
$$
  SELECT anon.reset()
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL UNSAFE -- because reset is unsafe
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.unload IS 'UNTRUSTED';

-------------------------------------------------------------------------------
--- Generic hashing
-------------------------------------------------------------------------------

-- Return the hash of a value for a given algorithm and a salt
-- Standard algorithms are md5, sha224, sha256, sha384 and sha512
--
-- * In version 1.x, this was a wrapper around pgcrypto's digest() function
-- * Since version 2.x, `sha1` is not longer supported
--
CREATE OR REPLACE FUNCTION anon.digest(
  val TEXT,
  salt TEXT,
  algorithm TEXT
)
RETURNS TEXT AS
$$
  SELECT CASE
    WHEN algorithm = 'md5'
      THEN pg_catalog.md5(concat(val,salt))
    WHEN algorithm = 'sha224'
      THEN pg_catalog.encode(pg_catalog.sha224(concat(val,salt)::BYTEA),'hex')
    WHEN algorithm = 'sha256'
      THEN pg_catalog.encode(pg_catalog.sha256(concat(val,salt)::BYTEA),'hex')
    WHEN algorithm = 'sha384'
      THEN pg_catalog.encode(pg_catalog.sha384(concat(val,salt)::BYTEA),'hex')
    WHEN algorithm = 'sha512'
      THEN pg_catalog.encode(pg_catalog.sha512(concat(val,salt)::BYTEA),'hex')
    ELSE NULL
    END
$$
  LANGUAGE SQL
  IMMUTABLE
  RETURNS NULL ON NULL INPUT
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

--
-- Return a hash value for a seed
--
-- The function is a SECURITY DEFINER because `anon.salt` and `anon.algorithm`
-- are visible only to superusers.
--
CREATE OR REPLACE FUNCTION anon.hash(
  seed TEXT
)
RETURNS TEXT AS $$
  SELECT anon.digest(
    seed,
    pg_catalog.current_setting('anon.salt'),
    pg_catalog.current_setting('anon.algorithm')
  );
$$
  LANGUAGE SQL
  STABLE
  RETURNS NULL ON NULL INPUT
  PARALLEL SAFE
  SECURITY DEFINER
  SET search_path = ''
;
-- https://www.postgresql.org/docs/current/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY

-------------------------------------------------------------------------------
-- Random Generic Data
-------------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION anon.random_date_between(
  date_start timestamp WITH TIME ZONE,
  date_end timestamp WITH TIME ZONE
)
RETURNS timestamp WITH TIME ZONE AS $$
    SELECT (random()*(date_end-date_start))::interval+date_start;
$$
  LANGUAGE SQL
  VOLATILE
  RETURNS NULL ON NULL INPUT
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;


-- The random functions are written in Rust (see `src/random.rs`)

-- Undocumented and kept for backward compatibility with v1
-- returns an empty string when l=0
CREATE OR REPLACE FUNCTION anon.random_string(
  l integer
)
RETURNS text
AS $$
  SELECT anon.random_string(pg_catalog.int4range(l,l+1));
$$
  LANGUAGE SQL
  VOLATILE
  RETURNS NULL ON NULL INPUT
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

-- Undocumented and kept for backward compatibility with v1
CREATE OR REPLACE FUNCTION anon.random_phone(
  prefix TEXT
)
RETURNS TEXT AS $$
  SELECT  anon.random_number_with_format(prefix||'#########');
$$
  LANGUAGE SQL
  VOLATILE
  RETURNS NULL ON NULL INPUT
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

-- Undocumented and kept for backward compatibility with v1
CREATE OR REPLACE FUNCTION anon.plop(
  prefix TEXT
)
RETURNS TEXT AS $$
  SELECT  anon.random_number_with_format(prefix||'#########');
$$
  LANGUAGE SQL
  VOLATILE
  RETURNS NULL ON NULL INPUT
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

--
-- hashing a seed with a random salt
--
CREATE OR REPLACE FUNCTION anon.random_hash(
  seed TEXT
)
RETURNS TEXT AS
$$
  SELECT anon.digest(
    seed,
    anon.random_string(6),
    pg_catalog.current_setting('anon.algorithm')
  );
$$
  LANGUAGE SQL
  VOLATILE
  SECURITY DEFINER
  PARALLEL RESTRICTED -- because random
  SET search_path = ''
  RETURNS NULL ON NULL INPUT
;

-- Array
CREATE OR REPLACE FUNCTION anon.random_in(
  a ANYARRAY
)
RETURNS ANYELEMENT AS
$$
  SELECT a[pg_catalog.floor(pg_catalog.random()*array_length(a,1)+1)]
$$
  LANGUAGE SQL
  VOLATILE
  RETURNS NULL ON NULL INPUT
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;


-- ENUM

CREATE OR REPLACE FUNCTION anon.random_in_enum(
  element ANYELEMENT
)
RETURNS ANYELEMENT AS
$$
  SELECT anon.random_in(enum_range(element));
$$
  LANGUAGE SQL
  VOLATILE
  -- We need to invoke the function like this anon.random_in_enum(NULL::CARD);
  --RETURNS NULL ON NULL INPUT
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.random_in_daterange(
  r DATERANGE
)
RETURNS DATE
AS $$
  SELECT CAST(
      (
        pg_catalog.random()
        *(pg_catalog.upper(r)::TIMESTAMP-pg_catalog.lower(r)::TIMESTAMP)
      )::INTERVAL
      +pg_catalog.lower(r)
      AS DATE
  );
$$
  LANGUAGE SQL
  VOLATILE
  RETURNS NULL ON NULL INPUT
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;


CREATE OR REPLACE FUNCTION anon.random_in_tsrange(
  r TSRANGE
)
RETURNS TIMESTAMP WITHOUT TIME ZONE
AS $$
  SELECT CAST(
    (
      pg_catalog.random()
      *(pg_catalog.upper(r)-pg_catalog.lower(r))
    )::INTERVAL
    +pg_catalog.lower(r)
    AS TIMESTAMP WITHOUT TIME ZONE);
$$
  LANGUAGE SQL
  VOLATILE
  RETURNS NULL ON NULL INPUT
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.random_in_tstzrange(
  r TSTZRANGE
)
RETURNS TIMESTAMP WITH TIME ZONE
AS $$
  SELECT CAST(
    (
      pg_catalog.random()
      *(pg_catalog.upper(r)-pg_catalog.lower(r))
    )::INTERVAL
    +pg_catalog.lower(r)
    AS TIMESTAMP WITH TIME ZONE);
$$
  LANGUAGE SQL
  VOLATILE
  RETURNS NULL ON NULL INPUT
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

-------------------------------------------------------------------------------
-- FAKE data
-------------------------------------------------------------------------------

-- We avoid using the floor() function in the function below because it is
-- way too slow. Instead we're using the mod operator like this:
--    (pg_catalog.random()*last_value)::INTEGER%last_value
-- See Issue #223 for more details
-- https://gitlab.com/dalibo/postgresql_anonymizer/-/merge_requests/223

CREATE OR REPLACE FUNCTION anon.fake_first_name()
RETURNS TEXT AS $$
  WITH random AS (
    SELECT (pg_catalog.random()*last_value)::INTEGER%last_value+1 AS oid
    FROM anon.first_name_oid_seq
  )
  SELECT COALESCE(f.val,anon.notice_if_not_init())
  FROM anon.first_name f
  JOIN random r ON f.oid=r.oid;
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.fake_last_name()
RETURNS TEXT AS $$
  WITH random AS (
    SELECT (pg_catalog.random()*last_value)::INTEGER%last_value+1 AS oid
    FROM anon.last_name_oid_seq
  )
  SELECT COALESCE(l.val,anon.notice_if_not_init())
  FROM anon.last_name l
  JOIN random r ON l.oid=r.oid;
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.fake_email()
RETURNS TEXT AS $$
  WITH random AS (
    SELECT (pg_catalog.random()*last_value)::INTEGER%last_value+1 AS oid
    FROM anon.email_oid_seq
  )
  SELECT COALESCE(e.val,anon.notice_if_not_init())
  FROM anon.email e
  JOIN random r ON e.oid=r.oid;
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.fake_address()
RETURNS TEXT AS $$
  WITH random AS (
    SELECT (pg_catalog.random()*last_value)::INTEGER%last_value+1 AS oid
    FROM anon.address_oid_seq
  )
  SELECT COALESCE(a.val,anon.notice_if_not_init())
  FROM anon.address a
  JOIN random r ON a.oid = r.oid
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.fake_city()
RETURNS TEXT AS $$
  WITH random AS (
    SELECT (pg_catalog.random()*last_value)::INTEGER%last_value+1 AS oid
    FROM anon.city_oid_seq
  )
  SELECT COALESCE(c.val,anon.notice_if_not_init())
  FROM anon.city c
  JOIN random r ON c.oid=r.oid;
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.fake_company()
RETURNS TEXT AS $$
  WITH random AS (
    SELECT (pg_catalog.random()*last_value)::INTEGER%last_value+1 AS oid
    FROM anon.company_oid_seq
  )
  SELECT COALESCE(c.val,anon.notice_if_not_init())
  FROM anon.company c
  JOIN random r ON c.oid = r.oid
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.fake_country()
RETURNS TEXT AS $$
  WITH random AS (
    SELECT (pg_catalog.random()*last_value)::INTEGER%last_value+1 AS oid
    FROM anon.country_oid_seq
  )
  SELECT COALESCE(c.val,anon.notice_if_not_init())
  FROM anon.country c
  JOIN random r ON c.oid = r.oid
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.fake_iban()
RETURNS TEXT AS $$
  WITH random AS (
    SELECT (pg_catalog.random()*last_value)::INTEGER%last_value+1 AS oid
    FROM anon.iban_oid_seq
  )
  SELECT COALESCE(i.val,anon.notice_if_not_init())
  FROM anon.iban i
  JOIN random r ON i.oid = r.oid;
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.fake_postcode()
RETURNS TEXT AS $$
  WITH random AS (
    SELECT (pg_catalog.random()*last_value)::INTEGER%last_value+1 AS oid
    FROM anon.postcode_oid_seq
  )
  SELECT COALESCE(p.val,anon.notice_if_not_init())
  FROM anon.postcode p
  JOIN random r ON p.oid = r.oid
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.fake_siret()
RETURNS TEXT AS $$
  WITH random AS (
    SELECT (pg_catalog.random()*last_value)::INTEGER%last_value+1 AS oid
    FROM anon.siret_oid_seq
  )
  SELECT COALESCE(s.val,anon.notice_if_not_init())
  FROM anon.siret s
  JOIN random r ON s.oid = r.oid;
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

-- Lorem Ipsum
-- Usage:
--   `SELECT anon.lorem_ipsum()` returns 5 paragraphs
--   `SELECT anon.lorem_ipsum(2)` returns 2 paragraphs
--   `SELECT anon.lorem_ipsum( paragraph := 4 )` returns 4 paragraphs
--   `SELECT anon.lorem_ipsum( words := 20 )` returns 20 words
--   `SELECT anon.lorem_ipsum( characters := 7 )` returns 7 characters
--
CREATE OR REPLACE FUNCTION anon.lorem_ipsum(
  paragraphs INTEGER DEFAULT 5,
  words INTEGER DEFAULT 0,
  characters INTEGER DEFAULT 0
)
RETURNS TEXT AS $$
WITH
-- First let's shuffle the lorem_ipsum table
randomized_lorem_ipsum AS (
  SELECT *
  FROM anon.lorem_ipsum
  ORDER BY RANDOM()
),
-- if `characters` is defined,
-- then the limit is the number of characters
-- else return NULL
cte_characters AS (
  SELECT
    CASE characters
      WHEN 0
      THEN NULL
      ELSE substring( c.agg_paragraphs for characters )
    END AS n_characters
  FROM (
    SELECT string_agg(paragraph,E'\n') AS agg_paragraphs
    FROM randomized_lorem_ipsum
  ) AS c
),
-- if `characters` is not defined and if `words` defined,
-- then the limit is the number of words
-- else return NULL
cte_words AS (
  SELECT
    CASE words
      WHEN 0
      THEN NULL
      ELSE string_agg(w.unnested_words,' ')
    END AS n_words
  FROM (
    SELECT unnest(string_to_array(p.agg_paragraphs,' ')) as unnested_words
    FROM (
      SELECT string_agg(paragraph,E' \n') AS agg_paragraphs
      FROM randomized_lorem_ipsum
      ) AS p
    LIMIT words
  ) as w
),
-- if `characters` is notdefined and `words` is not defined,
-- then the limit is the number of paragraphs
cte_paragraphs AS (
  SELECT string_agg(l.paragraph,E'\n') AS n_paragraphs
  FROM (
    SELECT *
    FROM randomized_lorem_ipsum
    LIMIT paragraphs
  ) AS l
)
SELECT COALESCE(
  cte_characters.n_characters,
  cte_words.n_words,
  cte_paragraphs.n_paragraphs,
  anon.notice_if_not_init()
)
FROM
  cte_characters,
  cte_words,
  cte_paragraphs
;
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL RESTRICTED -- because random
  SECURITY INVOKER
  SET search_path=''
;

-------------------------------------------------------------------------------
-- Pseudonymized data
-------------------------------------------------------------------------------

--
-- Convert an hexadecimal value to an integer
--
CREATE OR REPLACE FUNCTION anon.hex_to_int(
  hexval TEXT
)
RETURNS INT AS $$
DECLARE
    result  INT;
BEGIN
    EXECUTE 'SELECT x' || quote_literal(hexval) || '::INT' INTO result;
    RETURN result;
END;
$$
  LANGUAGE plpgsql
  IMMUTABLE
  STRICT
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

--
-- Return a deterministic value inside a range of OID for a given seed+salt
--
CREATE OR REPLACE FUNCTION anon.projection_to_oid(
  seed ANYELEMENT,
  salt TEXT,
  last_oid BIGINT
)
RETURNS INT AS $$
  --
  -- get a md5 hash of the seed and then project it on a 0-to-1 scale
  -- then multiply by the latest oid
  -- which give a deterministic oid inside the range
  --
  -- This works because MD5 signatures values have a uniform distribution
  -- see https://crypto.stackexchange.com/questions/14967/distribution-for-a-subset-of-md5
  --
  SELECT CAST(
    -- we use only the 6 first characters of the md5 signature
    -- and we divide by the max value : x'FFFFFF' = 16777215
    last_oid * anon.hex_to_int(md5(seed::TEXT||salt)::char(6)) / 16777215.0
  AS INT )
$$
  LANGUAGE SQL
  IMMUTABLE
  RETURNS NULL ON NULL INPUT
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;


--
-- the pseudo function are declared as SECURITY DEFINER because the access
-- the anon.salt which is only visible to superusers.
--
-- If a masked role can read the salt, he/she can run a brute force attack to
-- retrieve the original data based on the pseudonymized data
--

CREATE OR REPLACE FUNCTION anon.pseudo_first_name(
  seed ANYELEMENT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT COALESCE(val,anon.notice_if_not_init())
  FROM anon.first_name
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt, pg_catalog.current_setting('anon.salt')),
    (SELECT max(oid) FROM anon.first_name)
  );
$$
  LANGUAGE SQL
  STABLE
  PARALLEL SAFE
  SECURITY DEFINER
  SET search_path = pg_catalog,pg_temp
;

CREATE OR REPLACE FUNCTION anon.pseudo_last_name(
  seed ANYELEMENT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT COALESCE(val,anon.notice_if_not_init())
  FROM anon.last_name
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt, pg_catalog.current_setting('anon.salt')),
    (SELECT max(oid) FROM anon.last_name)
  );
$$
  LANGUAGE SQL
  STABLE
  PARALLEL SAFE
  SECURITY DEFINER
  SET search_path = pg_catalog,pg_temp
;


CREATE OR REPLACE FUNCTION anon.pseudo_email(
  seed ANYELEMENT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT COALESCE(val,anon.notice_if_not_init())
  FROM anon.email
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt, pg_catalog.current_setting('anon.salt')),
    (SELECT MAX(oid) FROM anon.email)
  );
$$
  LANGUAGE SQL
  STABLE
  PARALLEL SAFE
  SECURITY DEFINER
  SET search_path=''
;


CREATE OR REPLACE FUNCTION anon.pseudo_city(
  seed ANYELEMENT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT COALESCE(val,anon.notice_if_not_init())
  FROM anon.city
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt, pg_catalog.current_setting('anon.salt')),
    (SELECT MAX(oid) FROM anon.city)
  );
$$
  LANGUAGE SQL
  STABLE
  PARALLEL SAFE
  SECURITY DEFINER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.pseudo_country(
  seed ANYELEMENT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT COALESCE(val,anon.notice_if_not_init())
  FROM anon.country
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt, pg_catalog.current_setting('anon.salt')),
    (SELECT MAX(oid) FROM anon.country)
  );
$$
  LANGUAGE SQL
  STABLE
  PARALLEL SAFE
  SECURITY DEFINER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.pseudo_company(
  seed ANYELEMENT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT COALESCE(val,anon.notice_if_not_init())
  FROM anon.company
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt, pg_catalog.current_setting('anon.salt')),
    (SELECT MAX(oid) FROM anon.company)
  );
$$
  LANGUAGE SQL
  STABLE
  PARALLEL SAFE
  SECURITY DEFINER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.pseudo_iban(
  seed ANYELEMENT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT COALESCE(val,anon.notice_if_not_init())
  FROM anon.iban
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt, pg_catalog.current_setting('anon.salt')),
    (SELECT MAX(oid) FROM anon.iban)
  );
$$
  LANGUAGE SQL
  STABLE
  PARALLEL SAFE
  SECURITY DEFINER
  SET search_path=''
;

CREATE OR REPLACE FUNCTION anon.pseudo_siret(
  seed ANYELEMENT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT COALESCE(val,anon.notice_if_not_init())
  FROM anon.siret
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt, pg_catalog.current_setting('anon.salt')),
    (SELECT MAX(oid) FROM anon.siret)
  );
$$
  LANGUAGE SQL
  STABLE
  PARALLEL SAFE
  SECURITY DEFINER
  SET search_path=''
;




-------------------------------------------------------------------------------
-- Partial Scrambling
-------------------------------------------------------------------------------

-- partial('abcdefgh',1,'xxxx',3) will return 'axxxxfgh';
CREATE OR REPLACE FUNCTION anon.partial(
  ov TEXT,
  prefix INT,
  padding TEXT,
  suffix INT
)
RETURNS TEXT AS $$
  SELECT substring(ov FROM 1 FOR prefix)
      || padding
      || substring(ov FROM (length(ov)-suffix+1) FOR suffix);
$$
  LANGUAGE SQL
  IMMUTABLE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

--
-- partial_email('daamien@gmail.com') will become 'da******@gm******.com'
--
CREATE OR REPLACE FUNCTION anon.partial_email(
  ov TEXT
)
RETURNS TEXT AS $$
-- This is an oversimplistic way to scramble an email address
-- The main goal is to avoid any complex regexp
-- by splitting the job into simpler tasks
  SELECT substring(regexp_replace(ov, '@.*', '') FROM 1 FOR 2) -- da
      || '******'
      || '@'
      || substring(regexp_replace(ov, '.*@', '') FROM 1 FOR 2) -- gm
      || '******'
      || '.'
      || regexp_replace(ov, '.*\.', '') -- com
  ;
$$
  LANGUAGE SQL
  IMMUTABLE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;


-------------------------------------------------------------------------------
-- Masking Rules Management
-- This is the common metadata used by the 3 main features :
-- anonymize(), dump() and dynamic masking engine
-------------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION anon.get_schema(t TEXT)
RETURNS TEXT
AS $$
  SELECT pg_catalog.quote_ident(a[array_upper(a, 1)-1])
  FROM pg_catalog.parse_ident(t) AS a;
$$
  LANGUAGE SQL
  IMMUTABLE
  STRICT
  PARALLEL SAFE
;



CREATE OR REPLACE FUNCTION anon.get_relname(t TEXT)
RETURNS TEXT
AS $$
  SELECT pg_catalog.quote_ident(a[array_upper(a, 1)])
  FROM pg_catalog.parse_ident(t) AS a;
$$
  LANGUAGE SQL
  IMMUTABLE
  STRICT
  PARALLEL SAFE
;


-- List of all the masked columns
CREATE OR REPLACE VIEW anon.pg_masking_rules AS
WITH const AS (
  SELECT
    -- #" is the escape-double-quote separator
    '%MASKED +WITH +FUNCTION +#"%#(%#)#"%'::TEXT
      AS pattern_mask_column_function,
    'MASKED +WITH +VALUE +#"%#" ?'::TEXT
      AS pattern_mask_column_value
),
rules_from_default AS (
SELECT
  c.oid AS attrelid,
  a.attnum  AS attnum,
  c.relnamespace::REGNAMESPACE,
  c.relname,
  a.attname,
  pg_catalog.format_type(a.atttypid, a.atttypmod),
  NULL AS col_description,
  NULL AS masking_function,
  anon.masking_value_for_column(c.oid,a.attnum,'anon') AS masking_value,
  0 AS priority -- lowest priority for the default value
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid
LEFT JOIN pg_catalog.pg_attrdef d ON (a.attrelid, a.attnum) = (d.adrelid, d.adnum)
WHERE a.attnum > 0
AND n.nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast','anon')
AND NOT a.attisdropped
AND pg_catalog.current_setting('anon.privacy_by_default')::BOOLEAN
),
rules_from_seclabels AS (
SELECT
  sl.objoid AS attrelid,
  sl.objsubid  AS attnum,
  c.relnamespace::REGNAMESPACE,
  c.relname,
  a.attname,
  pg_catalog.format_type(a.atttypid, a.atttypmod),
  sl.label AS col_description,
  trim(substring( sl.label FROM k.pattern_mask_column_function FOR '#'))
    AS masking_function,
  trim(substring(sl.label FROM k.pattern_mask_column_value FOR '#'))
    AS masking_value,
  100 AS priority -- high priority for the security label syntax
FROM const k,
     pg_catalog.pg_seclabel sl
JOIN pg_catalog.pg_class c ON sl.classoid = c.tableoid AND sl.objoid = c.oid
JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid AND sl.objsubid = a.attnum
WHERE a.attnum > 0
--  TODO : Filter out the catalog tables
AND NOT a.attisdropped
AND (   sl.label SIMILAR TO k.pattern_mask_column_function ESCAPE '#'
    OR  sl.label SIMILAR TO k.pattern_mask_column_value ESCAPE '#'
    )
AND sl.provider = 'anon' -- this is hard-coded in anon.c
),
rules_from_all AS (
SELECT * FROM rules_from_default
UNION
SELECT * FROM rules_from_seclabels
)
-- DISTINCT will keep just the 1st rule for each column based on priority,
SELECT
  DISTINCT ON (attrelid, attnum) *,
  COALESCE(masking_function,masking_value) AS masking_filter,
  (
    -- Aggregate with count and bool_and to handle the cases
    -- when the schema is not declared
    SELECT COUNT(label)>0 and bool_and(label='TRUSTED')
    FROM pg_seclabel sl,
         anon.get_function_schema(masking_function) f("schema")
    WHERE f.schema != ''
    AND   sl.objoid=f.schema::REGNAMESPACE
  ) AS trusted_schema

FROM rules_from_all
ORDER BY attrelid, attnum, priority DESC
;

GRANT SELECT ON anon.pg_masking_rules TO PUBLIC;

-- get the TABLESAMPLE ratio declared for this table, if any
CREATE OR REPLACE FUNCTION anon.get_tablesample_ratio(relid OID)
RETURNS TEXT
AS $$
  SELECT COALESCE(
    (
    SELECT sl.label
    FROM pg_catalog.pg_seclabel sl
    WHERE sl.objoid = relid
    AND sl.objsubid = 0
    AND sl.provider = 'anon'
    ),
    (
    SELECT sl.label
    FROM pg_catalog.pg_seclabels sl
    WHERE sl.provider = 'anon'
    AND objtype='database'
    AND objoid = (SELECT oid FROM pg_database WHERE datname=current_database())
    )
  )
  ;
$$
  LANGUAGE SQL
  PARALLEL SAFE
  SECURITY DEFINER
  SET search_path=''
;

--
-- Unmask all the role at once
--
CREATE OR REPLACE FUNCTION anon.remove_masks_for_all_columns()
RETURNS BOOLEAN AS
$$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT relnamespace, relname, attname
           FROM anon.pg_masking_rules
  LOOP
    EXECUTE format('SECURITY LABEL FOR anon ON COLUMN %I.%I.%I IS NULL',
                    r.relnamespace,
                    r.relname,
                    r.attname
    );
  END LOOP;
  RETURN TRUE;
END
$$
  LANGUAGE plpgsql
  PARALLEL UNSAFE -- because of SECURITY LABEL
  SECURITY INVOKER
  SET search_path=''
;
SECURITY LABEL FOR anon ON FUNCTION anon.remove_masks_for_all_columns IS 'UNTRUSTED';

-- Compatibility with version 0.3 and earlier
CREATE OR REPLACE VIEW anon.pg_masks AS
SELECT * FROM anon.pg_masking_rules
;

-------------------------------------------------------------------------------
-- Generalization
-------------------------------------------------------------------------------

-- ADD TEST IN FILES:
--   * tests/sql/generalization.sql

-- Transform an integer into a range of integer
CREATE OR REPLACE FUNCTION anon.generalize_int4range(
  val INTEGER,
  step INTEGER default 10
)
RETURNS INT4RANGE
AS $$
SELECT int4range(
    val / step * step,
    ((val / step)+1) * step
  );
$$
  LANGUAGE SQL
  IMMUTABLE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

-- Transform a bigint into a range of bigint
CREATE OR REPLACE FUNCTION anon.generalize_int8range(
  val BIGINT,
  step BIGINT DEFAULT 10
)
RETURNS INT8RANGE
AS $$
SELECT int8range(
    val / step * step,
    ((val / step)+1) * step
  );
$$
  LANGUAGE SQL
  IMMUTABLE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

-- Transform a numeric into a range of numeric
CREATE OR REPLACE FUNCTION anon.generalize_numrange(
  val NUMERIC,
  step INTEGER DEFAULT 10
)
RETURNS NUMRANGE
AS $$
WITH i AS (
  SELECT anon.generalize_int4range(val::INTEGER,step) as r
)
SELECT numrange(
    lower(i.r)::NUMERIC,
    upper(i.r)::NUMERIC
  )
FROM i
;
$$
  LANGUAGE SQL
  IMMUTABLE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

-- Transform a timestamp with out timezone (ts) into a range of ts
-- the `step` option can have the following values
--        microseconds,milliseconds,second,minute,hour,day,week,
--        month,year,decade,century,millennium
CREATE OR REPLACE FUNCTION anon.generalize_tsrange(
  val TIMESTAMP WITHOUT TIME ZONE,
  step TEXT DEFAULT 'decade'
)
RETURNS TSRANGE
AS $$
SELECT tsrange(
    date_trunc(step, val)::TIMESTAMP WITHOUT TIME ZONE,
    date_trunc(step, val)::TIMESTAMP WITHOUT TIME ZONE + ('1 '|| step)::INTERVAL
  );
$$
  LANGUAGE SQL
  IMMUTABLE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

-- tstzrange
CREATE OR REPLACE FUNCTION anon.generalize_tstzrange(
  val TIMESTAMP WITH TIME ZONE,
  step TEXT DEFAULT 'decade'
)
RETURNS TSTZRANGE
AS $$
WITH lowerbound AS (
  SELECT date_trunc(step, val)::TIMESTAMP WITH TIME ZONE AS d
)
SELECT tstzrange( d, d + ('1 '|| step)::INTERVAL )
FROM lowerbound
;
$$
  LANGUAGE SQL
  IMMUTABLE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

-- daterange — Range of date
CREATE OR REPLACE FUNCTION anon.generalize_daterange(
  val DATE,
  step TEXT DEFAULT 'decade'
)
RETURNS DATERANGE
AS $$
SELECT daterange(
    date_trunc(step, val)::DATE,
    (date_trunc(step, val) + ('1 '|| step)::INTERVAL)::DATE
  );
$$
  LANGUAGE SQL
  PARALLEL SAFE
  IMMUTABLE
  SECURITY INVOKER
  SET search_path=''
;

-------------------------------------------------------------------------------
-- Risk Evaluation
-------------------------------------------------------------------------------

-- ADD TEST IN FILES:
--   * tests/sql/k_anonymity.sql

-- This is an attempt to implement various anonymity assessment methods.
-- These functions should be used with care.

CREATE OR REPLACE VIEW anon.pg_identifiers AS
WITH const AS (
  SELECT
    '%(quasi|indirect) identifier%'::TEXT AS pattern_indirect_identifier
)
SELECT
  sl.objoid AS attrelid,
  sl.objsubid  AS attnum,
  c.relname,
  a.attname,
  pg_catalog.format_type(a.atttypid, a.atttypmod),
  sl.label AS col_description,
  lower(sl.label) SIMILAR TO k.pattern_indirect_identifier ESCAPE '#'  AS indirect_identifier,
  100 AS priority -- high priority for the security label syntax
FROM const k,
     pg_catalog.pg_seclabel sl
JOIN pg_catalog.pg_class c ON sl.classoid = c.tableoid AND sl.objoid = c.oid
JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid AND sl.objsubid = a.attnum
WHERE a.attnum > 0
--  TODO : Filter out the catalog tables
AND NOT a.attisdropped
AND lower(sl.label) SIMILAR TO k.pattern_indirect_identifier ESCAPE '#'
AND sl.provider = pg_catalog.current_setting('anon.k_anonymity_provider')
;


-- see https://en.wikipedia.org/wiki/K-anonymity
CREATE OR REPLACE FUNCTION  anon.k_anonymity(
  relid REGCLASS
)
RETURNS INTEGER
AS $$
DECLARE
  identifiers TEXT;
  result INTEGER;
BEGIN
  SELECT string_agg(attname,',')
  INTO identifiers
  FROM anon.pg_identifiers
  WHERE relname::REGCLASS = relid;

  IF identifiers IS NULL THEN
    RAISE WARNING 'There is no identifier declared for relation ''%''.',
                  relid::REGCLASS
    USING HINT = 'Use `SECURITY LABEL FOR k_anonymity [...]` to declare '
              || 'which columns are indirect identifiers.';
    RETURN NULL;
  END IF;

  EXECUTE format(E'
    SELECT min(c) AS k_anonymity
    FROM (
      SELECT COUNT(*) as c
      FROM %s
      GROUP BY %s
    ) AS k;
  ',
  relid::REGCLASS,
  identifiers
  )
  INTO result;
  RETURN result;
END
$$
  LANGUAGE plpgsql
  IMMUTABLE
  PARALLEL SAFE
  SECURITY INVOKER
; --SET search_path='';

-- TODO : https://en.wikipedia.org/wiki/L-diversity

-- TODO : https://en.wikipedia.org/wiki/T-closeness
