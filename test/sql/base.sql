\set ECHO 0
BEGIN;
\i sql/geoip.sql
\set ECHO all

-- Tests goes here.

ROLLBACK;
