/*
 * Author: Tomas Vondra, Pavlo Golub
 *
 * Created at: Tue Apr 29 10:55:03 +0200 2025
 */

/* country locations */
CREATE TABLE geoip_country_locations (
    geoname_id             INT     PRIMARY KEY,
    locale_code            CHAR(2) NOT NULL,
    continent_code         CHAR(2),
    continent_name         TEXT,
    country_iso_code       CHAR(2),
    country_name           TEXT,
    is_in_european_union   BOOL,
    is_anycast             BOOL
);

/* IPv4/IPv6 blocks for countries */
CREATE TABLE geoip_country_blocks (
    network                iprange NOT NULL,
    geoname_id             INT,
    registered_country_id  INT,
    represented_country_id INT,
    is_anonymous_proxy     BOOL NOT NULL,
    is_satellite_provider  BOOL NOT NULL,
    is_anycast             BOOL
);

/* city locations */
CREATE TABLE geoip_city_locations (
    geoname_id             INT     PRIMARY KEY,
    locale_code            CHAR(2) NOT NULL,
    continent_code         CHAR(2),
    continent_name         TEXT,
    country_iso_code       CHAR(2),
    country_name           TEXT,
    subdivision_1_iso_code TEXT,
    subdivision_1_name     TEXT,
    subdivision_2_iso_code TEXT,
    subdivision_2_name     TEXT,
    city_name              TEXT,
    metro_code             TEXT,
    time_zone              TEXT,
    is_in_european_union   BOOL
);

/* IPv4/IPv6 blocks for cities */
CREATE TABLE geoip_city_blocks (
    network                iprange NOT NULL,
    geoname_id             INT  REFERENCES geoip_city_locations(geoname_id),
    registered_country_id  INT,
    represented_country_id INT,
    is_anonymous_proxy     BOOL NOT NULL,
    is_satellite_provider  BOOL NOT NULL,
    postal_code            TEXT,
    latitude               DOUBLE PRECISION,
    longitude              DOUBLE PRECISION,
    accuracy_radius        DOUBLE PRECISION,
    is_anycast             BOOL
);

/* IPv4/IPv6 blocks for autonomous systems */
CREATE TABLE geoip_asn_blocks (
    network                   iprange NOT NULL,
    autonomous_system_number  INT,
    autonomous_system_organization TEXT
);

CREATE INDEX geoip_country_blocks_idx ON geoip_country_blocks USING gist (network);
CREATE INDEX geoip_city_blocks_idx ON geoip_city_blocks USING gist (network);
CREATE INDEX geoip_asn_blocks_idx ON geoip_asn_blocks USING gist (network);

-- search country, returns just the country code (2 characters)
CREATE OR REPLACE FUNCTION geoip_country_code(p_ip ipaddress) RETURNS CHAR(2) AS $$

    SELECT country_iso_code
      FROM (SELECT geoname_id FROM @extschema@.geoip_country_blocks WHERE $1 <<= network LIMIT 1) foo
      JOIN @extschema@.geoip_country_locations USING (geoname_id);

$$ LANGUAGE sql;

-- search city, returns just the location ID (PK of the geoip_city_location)
CREATE OR REPLACE FUNCTION geoip_city_location(p_ip ipaddress) RETURNS INT AS $$

    SELECT geoname_id
      FROM @extschema@.geoip_city_blocks
     WHERE $1 <<= network LIMIT 1;

$$ LANGUAGE sql;

-- search city, returns all the city details (zipcode, GPS etc.)
CREATE OR REPLACE FUNCTION geoip_city(p_ip ipaddress, OUT geoname_id INT, OUT country_iso_code CHAR(2), OUT city_name VARCHAR(100),
                                                OUT postal_code VARCHAR(10), OUT metro_code TEXT,
                                                OUT latitude DOUBLE PRECISION, OUT longitude DOUBLE PRECISION) AS $$

    SELECT l.geoname_id, country_iso_code, city_name, postal_code, metro_code, latitude, longitude
      FROM (SELECT geoname_id, postal_code, latitude, longitude FROM @extschema@.geoip_city_blocks WHERE $1 <<= network LIMIT 1) foo
      JOIN @extschema@.geoip_city_locations l USING (geoname_id);

$$ LANGUAGE sql;

-- search country, returns all the details
CREATE OR REPLACE FUNCTION geoip_country(p_ip ipaddress, OUT network iprange, OUT country_iso_code CHAR(2), OUT country_name VARCHAR(100)) AS $$

    SELECT network, country_iso_code, country_name
      FROM (SELECT network, geoname_id FROM @extschema@.geoip_country_blocks WHERE $1 <<= network LIMIT 1) foo
      JOIN @extschema@.geoip_country_locations USING (geoname_id);

$$ LANGUAGE sql;

-- search ASN, returns the IP range and ASN name
CREATE OR REPLACE FUNCTION geoip_asn(p_ip ipaddress, OUT network iprange, OUT asn_number INT, OUT asn_name TEXT) AS $$

    SELECT network, autonomous_system_number, autonomous_system_organization
      FROM @extschema@.geoip_asn_blocks WHERE $1 <<= network LIMIT 1;

$$ LANGUAGE sql;

/** functions used to search data by IP **/

-- check consistency of the country table
CREATE OR REPLACE FUNCTION geoip_country_check() RETURNS BOOLEAN AS $$
DECLARE
    v_previous RECORD;
    v_block    RECORD;
    v_first    BOOLEAN := TRUE;
    v_valid    BOOLEAN := TRUE;
BEGIN

    FOR v_block IN SELECT network, lower(network) AS begin_ip, upper(network) AS end_ip FROM @extschema@.geoip_country_blocks ORDER BY family(network), begin_ip ASC LOOP

        IF (NOT v_first) THEN

            IF (family(v_block.network) != family(v_previous.network)) AND (v_previous.end_ip >= v_block.begin_ip) THEN
                RAISE WARNING 'ranges % and % overlap, end % start %', v_previous.network, v_block.network, v_previous.end_ip, v_block.begin_ip;
                v_valid := FALSE;
            END IF;

        END IF;

        v_first := FALSE;
        v_previous := v_block;

    END LOOP;

    RETURN v_valid;

END;
$$ LANGUAGE plpgsql;

-- check consistency of the city table
CREATE OR REPLACE FUNCTION geoip_city_check() RETURNS BOOLEAN AS $$
DECLARE
    v_previous RECORD;
    v_block    RECORD;
    v_first    BOOLEAN := TRUE;
    v_valid    BOOLEAN := TRUE;
BEGIN

    FOR v_block IN SELECT network, lower(network) AS begin_ip, upper(network) AS end_ip FROM @extschema@.geoip_city_blocks ORDER BY family(network), begin_ip ASC LOOP

        IF (NOT v_first) THEN
            IF (family(v_block.network) != family(v_previous.network)) AND (v_previous.end_ip >= v_block.begin_ip) THEN
                RAISE WARNING 'ranges % and % overlap, end % start %', v_previous.network, v_block.network, v_previous.end_ip, v_block.begin_ip;
                v_valid := FALSE;
            END IF;
        END IF;

        v_first := FALSE;
        v_previous := v_block;

    END LOOP;

    RETURN v_valid;

END;
$$ LANGUAGE plpgsql;

-- check consistency of the ASN table
CREATE OR REPLACE FUNCTION geoip_asn_check() RETURNS BOOLEAN AS $$
DECLARE
    v_previous RECORD;
    v_block    RECORD;
    v_first    BOOLEAN := TRUE;
    v_valid    BOOLEAN := TRUE;
BEGIN

    FOR v_block IN SELECT network, lower(network) AS begin_ip, upper(network) AS end_ip FROM @extschema@.geoip_asn_blocks ORDER BY family(network), begin_ip ASC LOOP

        IF (NOT v_first) THEN
            IF (family(v_block.network) != family(v_previous.network)) AND (v_previous.end_ip >= v_block.begin_ip) THEN
                RAISE WARNING 'ranges % and % overlap, end % start %', v_previous.network, v_block.network, v_previous.end_ip, v_block.begin_ip;
                v_valid := FALSE;
            END IF;
        END IF;

        v_first := FALSE;
        v_previous := v_block;

    END LOOP;

    RETURN v_valid;

END;
$$ LANGUAGE plpgsql;
