#!/bin/bash
#    pg_dump_anon
#    A basic wrapper to export anonymized data with pg_dump and psql

echo "WARNING:" >&2
echo "This script is deprecated and replaced by a new version." >&2
echo "It will be removed in a future version" >&2
echo "Please read the doc below for more details" >&2
echo "https://postgresql-anonymizer.readthedocs.io/en/latest/anonymous_dumps/#pg_dump_anonsh" >&2

usage()
{
cat << END
Usage: $(basename "$0") [OPTION]... [DBNAME]

General options:
  -f, --file=FILENAME           output file
  --help                        display this message

Options controlling the output content:
  -a, --data-only               Dump only the data, not the schema
  -E, --encoding=ENCODING       dump the data in encoding ENCODING
  -n, --schema=PATTERN          dump the specified schema(s) only
  -N, --exclude-schema=PATTERN  do NOT dump the specified schema(s)
  -t, --table=PATTERN           dump the specified table(s) only
  -T, --exclude-table=PATTERN   do NOT dump the specified table(s)
  --exclude-table-data=PATTERN  do NOT dump data for the specified table(s)

Connection options:
  -d, --dbname=DBNAME           database to dump
  -h, --host=HOSTNAME           database server host or socket directory
  -p, --port=PORT               database server port number
  -U, --username=NAME           connect as specified database user
  -w, --no-password             never prompt for password
  -W, --password                force password prompt (should happen automatically)

If no database name is supplied, then the PGDATABASE environment
variable value is used.

END
}

## Return the masking schema
get_maskschema() {
psql "${psql_opts[@]}" << EOSQL
  SELECT pg_catalog.current_setting('anon.maskschema');
EOSQL
}

## Return the masking filters based on the table name
get_mask_filters() {
psql "${psql_opts[@]}" << EOSQL
  SELECT anon.mask_filters('$1'::REGCLASS);
EOSQL
}

## There's no clean way to exclude an extension from a dump
## This is a pragmatic approach
filter_out_extension(){
grep -v -E "^-- Name: $1;" |
grep -v -E "^CREATE EXTENSION IF NOT EXISTS $1" |
grep -v -E "^-- Name: EXTENSION $1" |
grep -v -E "^COMMENT ON EXTENSION $1"
}

################################################################################
## 0. Parsing the command line arguments
##
## pg_dump_anon supports a subset of pg_dump options
##
## some arguments will be pushed to `pg_dump` and/or `psql` while others need
## specific treatment ( especially the `--file` option)
################################################################################

output=/dev/stdout      # by default, use standard output

if [ ! -w "$output" ]
then
  output=/dev/tty       # when using sudo, /dev/stdout is not writable
fi

pg_dump_opts=()         # export options
psql_opts=(
  "--quiet"
  "--tuples-only"
  "--no-align"
  "--no-psqlrc"
)                       # connections options
exclude_table_data=()   # dump the DDL, ignore the data
data_only=              # dump the data, ignore the DDL

while [ $# -gt 0 ]; do
    case "$1" in
    # 2-parts options pushed to pg_dump and psql
    -d|--dbname|-h|--host|-p|--port|-U|--username)
        pg_dump_opts+=("$1" "$2")
        psql_opts+=("$1" "$2")
        shift
        ;;
    # 1-part options pushed to pg_dump and psql
    --dbname=*|--host=*|--port=*|--username=*|-w|--no-password|-W|--password)
        pg_dump_opts+=("$1")
        psql_opts+=("$1")
        ;;
    # output options
    # `pg_dump_anon -f foo.sql` becomes `pg_dump [...] > foo.sql`
    -f|--file)
        shift # skip the `-f` tag
        output="$1"
        ;;
    --file=*)
        output="${1#--file=}"
        ;;
    # 2-parts options pushed only to pg_dump
    -E|-n|--schema|-N|--exclude-schema|-t|--table|-T|--exclude-table)
        pg_dump_opts+=("$1" "$2")
        shift
        ;;
    # 1-part options pushed only to pg_dump
    --encoding=*|--schema=*|--exclude-schema=*|--table=*|--exclude-table=*)
        pg_dump_opts+=("$1")
        ;;
    # special case for `--exclude-table-data`
    --exclude-table-data=*)
        pg_dump_opts+=("$1")
        exclude_table_data+=("$1")
        ;;
    # special case for `--data-only`
    -a|--data-only)
        data_only="$1"
        ;;
    # general options and fallback
    --help)
        usage
        exit 0
        ;;
    -*)
        echo "$0: Invalid option -- $1"
        echo Try "$0 --help" for more information.
        exit 1
        ;;
    *)
        # this is DBNAME
        pg_dump_opts+=("$1")
        psql_opts+=("$1")
        ;;
    esac
    shift
done

# Stop if the extension is not installed in the database
version=$( psql "${psql_opts[@]}" -c 'SELECT anon.version();' )
if [ -z "$version" ]
then
  echo 'ERROR: Anon extension is not installed in this database.' >&2
  exit 1
fi

# Stop if the output is not writable
touch "$output" || {
  echo "ERROR: $output is not writable." >&2
  exit 2
}

# Header
cat > "$output" <<EOF
--
-- Dump generated by PostgreSQL Anonymizer $version
--
-- IMPORTANT: This dump MAY NOT be consistent !
-- see the link below for more details about backup consistency
--
-- https://postgresql-anonymizer.readthedocs.io/en/latest/anonymous_dumps/#consistent-backups
--
EOF

################################################################################
## 1. Dump the DDL (pre-data section)
################################################################################

# gather all options needed to dump the DDL
pre_data_dump_opt=(
  "${pg_dump_opts[@]}"    # options from the command line
  "--section=pre-data"    # data will be dumped later
  "--no-security-labels"  # masking rules are confidential
  "--exclude-schema=anon" # do not dump the extension schema
  "--exclude-schema=$(get_maskschema)" # idem
)

# This will be used in step 2
tables_dump_opt=("${pre_data_dump_opt[@]}")

# add the --data-only flag if defined
[ -z "$data_only" ] || pre_data_dump_opt+=("$data_only")

# we need to remove some `CREATE EXTENSION` commands
pg_dump "${pre_data_dump_opt[@]}" \
| filter_out_extension anon  \
| filter_out_extension pgcrypto  \
| filter_out_extension tsm_system_rows \
>> "$output"

################################################################################
## 2. Dump the tables data
##
## We need to know which table data must be dumped.
## So We're launching the pg_dump again to get the list of the tables that were
## dumped previously.
################################################################################

# Only this time, we exclude the tables listed in `--exclude-table-data`
# shellcheck disable=SC2206
data_dump_opt=(
  "${tables_dump_opt[@]}"  # same as previously
  ${exclude_table_data//--exclude-table-data=/--exclude-table=}
)

# List the tables whose data must be dumped
dumped_tables=$(
  pg_dump "${data_dump_opt[@]}" \
  | awk '/^CREATE TABLE /{ print $3 }'
)

# For each dumped table, we export the data by applying the masking rules
for t in $dumped_tables
do
  # get the masking filters of this table (if any)
  filters=$(get_mask_filters "$t")
  # generate the "COPY ... FROM STDIN" statement for a given table
  echo "COPY $t FROM STDIN WITH CSV;" >> "$output"
  # export the data
  psql "${psql_opts[@]}" \
    -c "\\copy (SELECT $filters FROM $t) TO STDOUT WITH CSV" \
    >> "$output" || echo "Error during export of $t" >&2
  # close the stdin stream
  echo \\.  >> "$output"
  echo >> "$output"
done

################################################################################
## 3. Dump the sequences data
################################################################################

IFS=" " read -r -a seq_table_opts <<< "$( \
  psql "${psql_opts[@]}" \
    -c "SELECT sequence_name \
        FROM information_schema.sequences \
        WHERE sequence_schema != 'anon';" \
  | sed 's/^/--table /' \
  | tr '\n' ' '
)"

if [ ${#seq_table_opts[@]} -gt 0 ] ; then
  seq_data_dump_opt=(
    "${seq_table_opts[@]}"   # options to select sequence tables only
    "${pg_dump_opts[@]}"     # options from the command line
    "--data-only"            # we only want the `setval` lines
  )

  pg_dump "${seq_data_dump_opt[@]}" >> "$output"
fi

################################################################################
## 4. Dump the DDL (post-data section)
################################################################################

# gather all options needed to dump the DDL
post_data_dump_opt=(
  "${pg_dump_opts[@]}"    # options from the command line
  "--section=post-data"
  "--no-security-labels"  # masking rules are confidential
  "--exclude-schema=anon" # do not dump the extension schema
  "--exclude-schema=$(get_maskschema)" # idem
)

# add the --data-only flag if defined
[ -z "$data_only" ] || post_data_dump_opt+=("$data_only")

pg_dump "${post_data_dump_opt[@]}" >> "$output"

exit 0
