geoip
=====

This extension provides IP-based geolocation, i.e. you provide an IPv4
address and the extension looks for info about country, city, GPS etc.

To operate, the extension needs data mapping IP addresses to the other
info, but these data are not part of the extension. A good free dataset
is GeoLite from MaxMind (available at www.maxmind.com).

Installation
------------

To install the extension, basically all you need to do is this

    make install

and then (if you're on PostgreSQL 9.1 or above)

    CREATE EXTENSION geoip;

For versions of PostgreSQL less than 9.1.0, you'll need to run the
installation script manually:

    psql -d mydb -f /path/to/pgsql/share/contrib/geoip.sql

Now you're ready to use the extension. More details about the installation
options and issues are available in the INSTALL file.


Using the extension
-------------------

The extension allows you to search for country, city and ASN. All of that
is encapsulated into these functions:

 * geoip_country_code(inet) - returns country code (2 chars)
 * geoip_country(inet) - returns all country info (code, name, ...)
 * geoip_city_location(inet) - returns just location ID (INT)
 * geoip_city(inet) - returns all the city info (GPS, ZIP code, ...)
 * geoip_asn(inet) - retusn ASN name and IP range

Using the functions is quite straightforward, especially for functions that
return a single value

    db=# SELECT geoip_country_code('78.45.133.255'::inet);

     geoip_country_code 
    --------------------
     CZ
    (1 row)

    db=# SELECT geoip_city_location('78.45.133.255'::inet);

     geoip_city_location 
    ---------------------
                   21235
    (1 row)

The functions that return a tuple are a bit more complicated. Probably the
best way to call them is like a SRF:

    db=# SELECT * FROM geoip_city('78.45.133.255'::inet);

     loc_id | country | region |  city  | latitude | longitude | ...
    --------+---------+--------+--------+----------+-----------+-----
      21235 | CZ      | 52     | Prague |  50.0833 |   14.4667 | ...

    db=# SELECT * FROM geoip_country('78.45.133.255'::inet);

     begin_ip  |    end_ip     | country |      name      
    -----------+---------------+---------+----------------
     78.44.0.0 | 78.45.255.255 | CZ      | Czech Republic
    (1 row)

    db=# SELECT * FROM geoip_asn('78.45.133.255'::inet);

     begin_ip  |    end_ip     |               name                
    -----------+---------------+-----------------------------------
     78.44.0.0 | 78.45.255.255 | AS6830 UPC Broadband Holding B.V.
    (1 row)

Sure, you can access the data directly through the tables.

Loading the data
----------------
This extension requires manual downloading and loading the data. Once
you have the extension installed (so that the tables exist), go to
http://www.maxmind.com and download the CSV files

 * http://www.maxmind.com/app/geolitecountry - GeoIPCountryCSV.zip
 * http://www.maxmind.com/app/geolitecity - GeoLiteCity_20120207.zip
 * http://www.maxmind.com/app/asnum - GeoIPASNum2.zip

Now we need to preprocess the CSV files so that it's possible to load
them into the tables with a COPY. First, unzip the GeoIPCountryCSV.zip
and remove the two columns with IP addresses encoded as INT values.

    $ unzip GeoIPCountryCSV.zip
    $ sed 's/^\("[^"]*","[^"]*",\)"[^"]*","[^"]*",\("[^"]*","[^"]*"\)/\1\2/' \
          GeoIPCountryWhois.csv > countries.csv

Now unzip the GeoLite city data and remove the first two rows (header)

    $ tail -$((`wc -l GeoLiteCity-Blocks.csv | awk '{print $1}'`-2)) \
      GeoLiteCity-Blocks.csv > blocks.csv

    $ tail -$((`wc -l GeoLiteCity-Location.csv | awk '{print $1}'`-2)) \
      GeoLiteCity-Location.csv > locations.csv

It's time to load the data into the database. There's still a bit of
transforming that needs to be done (and doing it in shell would be
awkward), so we'll create a few temporary tables. So log in to the
database and do this (the PATH needs to be replaced with an actual
absolute path to the files).

    COPY geoip_country FROM 'PATH/countries.csv'
    WITH csv DELIMITER ',' NULL '' QUOTE '"' ENCODING 'ISO-8859-2';

    CREATE TEMPORARY TABLE geoip_city_block_tmp (
        begin_ip    BIGINT      NOT NULL,
        end_ip      BIGINT      NOT NULL,
        loc_id      INTEGER     NOT NULL
    );

    CREATE TEMPORARY TABLE geoip_asn_tmp (
        begin_ip    BIGINT      NOT NULL,
        end_ip      BIGINT      NOT NULL,
        name        TEXT        NOT NULL
    );

    COPY geoip_city_block_tmp FROM 'PATH/blocks.csv'
    WITH csv DELIMITER ',' NULL '' QUOTE '"' ENCODING 'ISO-8859-2';

    COPY geoip_city_location FROM 'PATH/locations.csv'
    WITH csv DELIMITER ',' NULL '' QUOTE '"' ENCODING 'ISO-8859-2';

    COPY geoip_asn_tmp FROM 'PATH/GeoIPASNum2.csv'
    WITH csv DELIMITER ',' NULL '' QUOTE '"' ENCODING 'ISO-8859-2';

    INSERT INTO geoip_city_block
         SELECT geoip_bigint_to_inet(begin_ip),
                geoip_bigint_to_inet(end_ip), loc_id
           FROM geoip_city_block_tmp;

    INSERT INTO geoip_asn
         SELECT geoip_bigint_to_inet(begin_ip),
                geoip_bigint_to_inet(end_ip), name
           FROM geoip_asn_tmp;

    ANALYZE;

Now the data is loaded.


Copyright and License
---------------------
Copyright (c) 2012 Tomas Vondra
The extension is distributed under BSD license (see the LICENSE file)