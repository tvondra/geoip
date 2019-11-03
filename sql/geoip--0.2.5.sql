/*
 * Author: Tomas Vondra
 * Created at: Sat Mar 31 22:51:21 +0200 2012
 *
 */ 

CREATE TABLE geoip_country (
    begin_ip    INET            NOT NULL,
    end_ip      INET            NOT NULL,
    country     CHAR(2)         NOT NULL,
    name        VARCHAR(100)    NOT NULL,
    CONSTRAINT valid_range CHECK (begin_ip <= end_ip)
);

CREATE TABLE geoip_city_location (
    loc_id      INTEGER         PRIMARY KEY,
    country     CHAR(2)         NOT NULL,
    region      CHAR(2),
    city        VARCHAR(100),
    postal_code VARCHAR(10),
    latitude    DOUBLE PRECISION,
    longitude   DOUBLE PRECISION,
    metro_code  INT,
    area_code   INT
);

CREATE TABLE geoip_city_block (
    begin_ip    INET            NOT NULL,
    end_ip      INET            NOT NULL,
    loc_id      INTEGER         NOT NULL    REFERENCES geoip_city_location(loc_id)
);

CREATE TABLE geoip_asn (
    begin_ip    INET        NOT NULL,
    end_ip      INET        NOT NULL,
    name        TEXT        NOT NULL
);

-- indexes (might be improved to handle index-only scans)
CREATE INDEX geoip_country_ip_idx ON geoip_country (begin_ip DESC);
CREATE INDEX geoip_city_block_ip_idx ON geoip_city_block (begin_ip DESC);
CREATE INDEX geoip_asn_ip_idx ON geoip_asn (begin_ip DESC);

/** functions used to search data by IP **/

-- search country, returns just the country code (2 characters)
CREATE OR REPLACE FUNCTION geoip_country_code(p_ip INET) RETURNS CHAR(2) AS $$

    SELECT country
      FROM @extschema@.geoip_country
     WHERE $1 >= begin_ip AND $1 <= end_ip ORDER BY begin_ip DESC LIMIT 1;

$$ LANGUAGE sql;

-- search city, returns just the location ID (PK of the geoip_city_location)
CREATE OR REPLACE FUNCTION geoip_city_location(p_ip INET) RETURNS INT AS $$

    SELECT loc_id
      FROM @extschema@.geoip_city_block
     WHERE $1 >= begin_ip AND $1 <= end_ip ORDER BY begin_ip DESC LIMIT 1;

$$ LANGUAGE sql;

-- search city, returns all the city details (zipcode, GPS etc.)
CREATE OR REPLACE FUNCTION geoip_city(p_ip INET, OUT loc_id INT, OUT country CHAR(2), OUT region CHAR(2),
                                                 OUT city VARCHAR(100), OUT postal_code VARCHAR(10),
                                                 OUT latitude DOUBLE PRECISION, OUT longitude DOUBLE PRECISION,
                                                 OUT metro_code INT, OUT area_code INT) AS $$

    SELECT l.loc_id, country, region, city, postal_code, latitude, longitude, metro_code, area_code
      FROM @extschema@.geoip_city_block b JOIN @extschema@.geoip_city_location l ON (b.loc_id = l.loc_id)
     WHERE $1 >= begin_ip AND $1 <= end_ip ORDER BY begin_ip DESC LIMIT 1;

$$ LANGUAGE sql;

-- search country, returns all the details
CREATE OR REPLACE FUNCTION geoip_country(p_ip INET, OUT begin_ip INET, OUT end_ip INET,
                                                         OUT country CHAR(2), OUT name VARCHAR(100)) AS $$

    SELECT begin_ip, end_ip, country, name
      FROM @extschema@.geoip_country WHERE $1 >= begin_ip AND $1 <= end_ip ORDER BY begin_ip DESC LIMIT 1;

$$ LANGUAGE sql;

-- search ASN, returns the IP range and ASN name
CREATE OR REPLACE FUNCTION geoip_asn(p_ip INET, OUT begin_ip INET, OUT end_ip INET,
                                                OUT name VARCHAR(100)) AS $$

    SELECT begin_ip, end_ip, name
      FROM @extschema@.geoip_asn WHERE $1 >= begin_ip AND $1 <= end_ip ORDER BY begin_ip DESC LIMIT 1;

$$ LANGUAGE sql;

/** functions used to search data by IP **/

-- check consistency of the country table
CREATE OR REPLACE FUNCTION geoip_country_check() RETURNS BOOLEAN AS $$
DECLARE
    v_previous RECORD;
    v_country  RECORD;
    v_first    BOOLEAN := TRUE;
    v_valid    BOOLEAN := TRUE;
BEGIN

    FOR v_country IN SELECT * FROM @extschema@.geoip_country ORDER BY begin_ip ASC LOOP

        IF (NOT v_first) THEN
            v_first := FALSE;
            IF (v_previous.end_ip + 1 != v_country.begin_ip) THEN
                RAISE WARNING 'there''s a hole between %-% and %-%',v_previous.begin_ip,
                    v_previous.end_ip,v_country.begin_ip,v_country.end_ip;
                v_valid := FALSE;
            END IF;
        END IF;

        v_previous := v_country;
    
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

    FOR v_block IN SELECT begin_ip, end_ip FROM @extschema@.geoip_city_block ORDER BY begin_ip ASC LOOP

        IF (NOT v_first) THEN
            v_first := FALSE;
            IF (v_previous.end_ip + 1 != v_block.begin_ip) THEN
                RAISE WARNING 'there''s a hole between %-% and %-%',v_previous.begin_ip,
                    v_previous.end_ip,v_block.begin_ip,v_block.end_ip;
                v_valid := FALSE;
            END IF;
        END IF;

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

    FOR v_block IN SELECT begin_ip, end_ip FROM @extschema@.geoip_asn ORDER BY begin_ip ASC LOOP

        IF (NOT v_first) THEN
            v_first := FALSE;
            IF (v_previous.end_ip + 1 != v_block.begin_ip) THEN
                RAISE WARNING 'there''s a hole between %-% and %-%',v_previous.begin_ip,
                    v_previous.end_ip,v_block.begin_ip,v_block.end_ip;
                v_valid := FALSE;
            END IF;
        END IF;

        v_previous := v_block;
    
    END LOOP;

    RETURN v_valid;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION @extschema@.geoip_bigint_to_inet(p_ip BIGINT) RETURNS inet AS $$
    SELECT (($1 >> 24 & 255) || '.' || ($1 >> 16 & 255) || '.' || ($1 >> 8 & 255) || '.' || ($1 & 255))::inet
$$ LANGUAGE sql strict immutable;
