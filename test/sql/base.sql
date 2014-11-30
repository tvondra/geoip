\set ECHO 0
BEGIN;

\i sql/geoip--0.2.1.sql

INSERT INTO geoip_country(begin_ip, end_ip, country, name) VALUES ('78.31.24.0',   '78.31.31.255', 'AA', 'Country A');
INSERT INTO geoip_country(begin_ip, end_ip, country, name) VALUES ('78.41.8.0',    '78.41.23.255', 'BB', 'Country B');
INSERT INTO geoip_country(begin_ip, end_ip, country, name) VALUES ('78.44.0.0',   '78.45.255.255', 'CC', 'Country C');
INSERT INTO geoip_country(begin_ip, end_ip, country, name) VALUES ('78.80.0.0',   '78.80.255.255', 'DD', 'Country D');
INSERT INTO geoip_country(begin_ip, end_ip, country, name) VALUES ('78.102.0.0', '78.103.255.255', 'EE', 'Country E');

-- country CC
SELECT geoip_country_code('78.45.133.255'::inet);

SELECT * FROM geoip_country('78.45.133.255'::inet);

-- no matching country record (before the first IP)
SELECT geoip_country_code('10.45.133.255'::inet);

SELECT * FROM geoip_country_code('10.45.133.255'::inet);

-- no matching country record (between records)
SELECT geoip_country_code('78.43.1.1'::inet);

SELECT * FROM geoip_country_code('78.43.1.1'::inet);

-- no matching country record (after the last IP)
SELECT geoip_country_code('79.43.1.1'::inet);

SELECT * FROM geoip_country_code('79.43.1.1'::inet);

INSERT INTO geoip_city_location(loc_id, country, region, city, postal_code, latitude, longitude, metro_code, area_code) VALUES (21235, 'CZ', 52, 'A', NULL, 50.0833, 14.4667, NULL, NULL);
INSERT INTO geoip_city_location(loc_id, country, region, city, postal_code, latitude, longitude, metro_code, area_code) VALUES (37990, 'CZ', 78, 'B', NULL, 49.2, 16.6333, NULL, NULL);

INSERT INTO geoip_city_block(begin_ip, end_ip, loc_id) VALUES ('31.7.243.0', '31.7.243.31', 21235);
INSERT INTO geoip_city_block(begin_ip, end_ip, loc_id) VALUES ('31.30.3.72', '31.30.3.79', 21235);
INSERT INTO geoip_city_block(begin_ip, end_ip, loc_id) VALUES ('46.13.32.0', '46.13.63.255', 21235);
INSERT INTO geoip_city_block(begin_ip, end_ip, loc_id) VALUES ('46.13.240.0', '46.13.255.255', 37990);

-- city A
SELECT geoip_city_location('31.7.243.10'::inet);

SELECT * FROM geoip_city('31.7.243.10'::inet);

-- no matching city record (before the first IP)
SELECT geoip_city_location('10.7.243.10'::inet);

SELECT * FROM geoip_city('10.7.243.10'::inet);

-- no matching city record (between the records)
SELECT geoip_city_location('40.1.1.1'::inet);

SELECT * FROM geoip_city('40.1.1.1'::inet);

-- no matching city record (after the last IP)
SELECT geoip_city_location('47.1.1.1'::inet);

SELECT * FROM geoip_city('47.1.1.1'::inet);

INSERT INTO geoip_asn(begin_ip, end_ip, name) VALUES ('1.11.64.0', '1.11.95.255', 'AS38091 CJ-CABLENET');
INSERT INTO geoip_asn(begin_ip, end_ip, name) VALUES ('1.11.96.0', '1.11.127.255', 'AS38669 ChungNam Broadcastin Co.');
INSERT INTO geoip_asn(begin_ip, end_ip, name) VALUES ('1.11.128.0', '1.11.255.255', 'AS17839 DreamcityMedia');

-- ASN CABLENET
SELECT * FROM geoip_asn('1.11.66.10'::inet);

-- missing ASN records
SELECT * FROM geoip_asn('10.11.66.10'::inet);

ROLLBACK;
