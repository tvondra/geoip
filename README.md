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

    psql -d mydb -f /path/to/pgsql/share/contrib/geoip--0.3.0.sql

Now you're ready to use the extension. More details about the installation
options and issues are available in the INSTALL file.


Using the extension
-------------------

The extension allows you to search for country, city and ASN. All of that
is encapsulated into these functions:

 * `geoip_country_code(ip4|ip6)` - returns country code (2 chars)
 * `geoip_country(ip4|ip6)` - returns all country info (code, name, ...)
 * `geoip_city_location(ip4|ip6)` - returns just location ID (INT)
 * `geoip_city(ip4|ip6)` - returns all the city info (GPS, ZIP code, ...)
 * `geoip_asn(ip4|ip6)` - retusn ASN name and IP range

Using the functions is quite straightforward, especially for functions that
return a single value

    db=# SELECT geoip_country_code('78.45.133.255'::ip4);

     geoip_country_code 
    --------------------
     CZ
    (1 row)

    db=# SELECT geoip_city_location('78.45.133.255'::ip4);

     geoip_city_location 
    ---------------------
                   21235
    (1 row)

The functions that return a tuple are a bit more complicated. Probably the
best way to call them is like a SRF:

    db=# SELECT * FROM geoip.geoip_city('78.45.133.255'::ip4);

     geoname_id | country_iso_code | city_name | postal_code |  ...
    ------------+------------------+-----------+-------------+- ...
        3066399 | CZ               | Sardice   | 696 13      |  ...

    db=# SELECT * FROM geoip.geoip_country('78.45.133.255'::ip4);

        network     | country_iso_code | country_name 
    ----------------+------------------+--------------
     78.45.128.0/17 | CZ               | Czechia
    (1 row)

    db=# SELECT * FROM geoip.geoip_asn('78.45.133.255'::ip4);

       network    | asn_number |      asn_name       
    --------------+------------+---------------------
     78.44.0.0/15 |       6830 | Liberty Global B.V.
    (1 row)

Sure, you can access the data directly through the tables.


Consistency of data
-------------------
Correctness of the answers depends on consistency of the GeoIP database.


Loading the data
----------------
This extension requires manual downloading and loading the data. Once
you have the extension installed (so that the tables exist), go to
http://www.maxmind.com and download the GeoLite2 CSV files

 * https://dev.maxmind.com/geoip/geoip2/geolite2/

Download all three data sets (City, Country, ASN) in CSV format, and
extract them. You'll need these CSV files:

 * GeoLite2-City-Locations-en.csv
 * GeoLite2-City-Blocks-IPv4.csv
 * GeoLite2-City-Blocks-IPv6.csv
 * GeoLite2-Country-Locations-en.csv
 * GeoLite2-Country-Blocks-IPv4.csv
 * GeoLite2-Country-Blocks-IPv6.csv
 * GeoLite2-ASN-Blocks-IPv4.csv
 * GeoLite2-ASN-Blocks-IPv6.csv

The "locations" files have multiple language variants, so pick the one
that works for you. Then simply load the data using COPY command:

    $ cat GeoLite2-Country-Locations-en.csv | \
      psql $DBNAME -c 'COPY geoip.geoip_country_locations FROM stdin WITH (FORMAT CSV, HEADER)'

    $ cat GeoLite2-Country-Blocks-IPv4.csv | \
      psql $DBNAME -c 'COPY geoip.geoip_country_blocks FROM stdin WITH (FORMAT CSV, HEADER)'

    $ cat GeoLite2-Country-Blocks-IPv6.csv | \
      psql $DBNAME -c 'COPY geoip.geoip_country_blocks FROM stdin WITH (FORMAT CSV, HEADER)'

    $ cat GeoLite2-City-Locations-en.csv | \
      psql $DBNAME -c 'COPY geoip.geoip_city_locations FROM stdin WITH (FORMAT CSV, HEADER)'

    $ cat GeoLite2-City-Blocks-IPv4.csv | \
      psql $DBNAME -c 'COPY geoip.geoip_city_blocks FROM stdin WITH (FORMAT CSV, HEADER)'

    $ cat GeoLite2-City-Blocks-IPv6.csv | \
      psql $DBNAME -c 'COPY geoip.geoip_city_blocks FROM stdin WITH (FORMAT CSV, HEADER)'

    $ cat GeoLite2-ASN-Blocks-IPv4.csv | \
      psql $DBNAME -c 'COPY geoip.geoip_city_blocks FROM stdin WITH (FORMAT CSV, HEADER)'

    $ cat GeoLite2-ASN-Blocks-IPv6.csv | \
      psql $DBNAME -c 'COPY geoip.geoip_city_blocks FROM stdin WITH (FORMAT CSV, HEADER)'

Now the data is loaded.


Copyright and License
---------------------
Copyright (c) 2012 Tomas Vondra
The extension is distributed under BSD license (see the LICENSE file)
