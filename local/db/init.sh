#!/bin/bash

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
  CREATE DATABASE taskmanager;
  CREATE DATABASE taskmanager_template;
EOSQL
