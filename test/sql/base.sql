\set ECHO none
BEGIN;

SET client_min_messages = 'WARNING';
CREATE EXTENSION ip4r;
CREATE EXTENSION geoip VERSION '0.4.0';

INSERT INTO geoip.geoip_country_locations (geoname_id, locale_code, country_iso_code, country_name) VALUES (1, 'aa', 'AA', 'Country A');
INSERT INTO geoip.geoip_country_locations (geoname_id, locale_code, country_iso_code, country_name) VALUES (2, 'bb', 'BB', 'Country B');
INSERT INTO geoip.geoip_country_locations (geoname_id, locale_code, country_iso_code, country_name) VALUES (3, 'cc', 'CC', 'Country C');

INSERT INTO geoip.geoip_country_blocks(network, geoname_id, is_anonymous_proxy, is_satellite_provider) VALUES ('78.31.24.0/24',  1, false, false);
INSERT INTO geoip.geoip_country_blocks(network, geoname_id, is_anonymous_proxy, is_satellite_provider) VALUES ('78.41.8.0/24',   2, false, false);
INSERT INTO geoip.geoip_country_blocks(network, geoname_id, is_anonymous_proxy, is_satellite_provider) VALUES ('78.44.0.0/15',   3, false, false);
INSERT INTO geoip.geoip_country_blocks(network, geoname_id, is_anonymous_proxy, is_satellite_provider) VALUES ('78.80.1.0/24',   1, false, false);
INSERT INTO geoip.geoip_country_blocks(network, geoname_id, is_anonymous_proxy, is_satellite_provider) VALUES ('78.102.0.0/16',  2, false, false);

-- country CC
SELECT geoip.geoip_country_code('78.45.133.255'::ipaddress);

SELECT lower(network) AS begin_ip, upper(network) AS end_ip, country_iso_code AS country, country_name as name FROM geoip.geoip_country('78.45.133.255'::ipaddress);

-- no matching country record (before the first IP)
SELECT geoip.geoip_country_code('10.45.133.255'::ipaddress);

SELECT * FROM geoip.geoip_country_code('10.45.133.255'::ipaddress);

-- no matching country record (between records)
SELECT geoip.geoip_country_code('78.43.1.1'::ipaddress);

SELECT * FROM geoip.geoip_country_code('78.43.1.1'::ipaddress);

-- no matching country record (after the last IP)
SELECT geoip.geoip_country_code('79.43.1.1'::ipaddress);

SELECT * FROM geoip.geoip_country_code('79.43.1.1'::ipaddress);

INSERT INTO geoip.geoip_city_locations(geoname_id, locale_code, country_iso_code, metro_code, city_name) VALUES (21235, 'cs', 'CZ', 'metro A', 'City A');
INSERT INTO geoip.geoip_city_locations(geoname_id, locale_code, country_iso_code, metro_code, city_name) VALUES (37990, 'en', 'EN', 'metro B', 'City B');

INSERT INTO geoip.geoip_city_blocks(network, geoname_id, postal_code, latitude, longitude, is_anonymous_proxy, is_satellite_provider) VALUES ('31.7.243.31-31.7.243.0',    21235, 'postal A', 50.0833, 14.4667, true, true);
INSERT INTO geoip.geoip_city_blocks(network, geoname_id, postal_code, latitude, longitude, is_anonymous_proxy, is_satellite_provider) VALUES ('31.30.3.79-31.30.3.72',     21235, 'postal B', 50.0833, 14.4667, false, false);
INSERT INTO geoip.geoip_city_blocks(network, geoname_id, postal_code, latitude, longitude, is_anonymous_proxy, is_satellite_provider) VALUES ('46.13.63.255-46.13.32.0',   21235, 'postal C', 49.2, 16.6333, true, false);
INSERT INTO geoip.geoip_city_blocks(network, geoname_id, postal_code, latitude, longitude, is_anonymous_proxy, is_satellite_provider) VALUES ('46.13.255.255-46.13.240.0', 37990, 'postal D', 49.2, 16.6333, false, true);

-- city A
SELECT geoip.geoip_city_location('31.7.243.10'::ipaddress);

SELECT * FROM geoip.geoip_city('31.7.243.10'::ipaddress);

-- no matching city record (before the first IP)
SELECT geoip.geoip_city_location('10.7.243.10'::ipaddress);

SELECT * FROM geoip.geoip_city('10.7.243.10'::ipaddress);

-- no matching city record (between the records)
SELECT geoip.geoip_city_location('40.1.1.1'::ipaddress);

SELECT * FROM geoip.geoip_city('40.1.1.1'::ipaddress);

-- no matching city record (after the last IP)
SELECT geoip.geoip_city_location('47.1.1.1'::ipaddress);

SELECT * FROM geoip.geoip_city('47.1.1.1'::ipaddress);

INSERT INTO geoip.geoip_asn_blocks(network, autonomous_system_number, autonomous_system_organization) VALUES ('1.11.95.255-1.11.64.0', 38091, 'CJ-CABLENET');
INSERT INTO geoip.geoip_asn_blocks(network, autonomous_system_number, autonomous_system_organization) VALUES ('1.11.127.255-1.11.96.0', 38669, 'ChungNam Broadcastin Co.');
INSERT INTO geoip.geoip_asn_blocks(network, autonomous_system_number, autonomous_system_organization) VALUES ('1.11.255.255-1.11.128.0', 17839, 'DreamcityMedia');

-- ASN CABLENET
SELECT lower(network) AS begin_ip, upper(network) AS end_ip, asn_number, asn_name FROM geoip.geoip_asn('1.11.66.10'::ipaddress);

-- missing ASN records
SELECT lower(network) AS begin_ip, upper(network) AS end_ip, asn_number, asn_name FROM geoip.geoip_asn('10.11.66.10'::ipaddress);

ROLLBACK;
