# !/bin/bash

DB_USER="rj"
DB_NAME="cooking"
SQL_FILE="./cooking_query.sql"

psql -U $DB_USER -d $DB_NAME -f $SQL_FILE
psql -U $DB_USER -d $DB_NAME -c "\copy (SELECT * FROM results_table) TO './cooking.csv' WITH CSV HEADER"
