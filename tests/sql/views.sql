BEGIN;

CREATE EXTENSION anon;

CREATE TABLE employee (
  id  SERIAL,
  ssn TEXT
);

CREATE VIEW v_early_employee AS
  SELECT *
  FROM employee
  WHERE id < 1000;


-- This is ok
SECURITY LABEL FOR anon ON COLUMN employee.ssn
IS 'MASKED WITH VALUE NULL';

-- This should fail
SAVEPOINT mask_on_view;
SECURITY LABEL FOR anon ON COLUMN v_early_employee.ssn
  IS 'MASKED WITH VALUE NULL';
ROLLBACK TO mask_on_view;

ROLLBACK;
