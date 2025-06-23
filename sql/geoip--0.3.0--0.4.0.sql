    ALTER TABLE geoip.geoip_country_locations ADD COLUMN is_anycast boolean;
    ALTER TABLE geoip.geoip_country_blocks ADD COLUMN is_anycast boolean;
    ALTER TABLE geoip.geoip_city_blocks ADD COLUMN is_anycast boolean;
    ALTER TABLE geoip.geoip_country_blocks DROP CONSTRAINT geoip_country_blocks_geoname_id_fkey;