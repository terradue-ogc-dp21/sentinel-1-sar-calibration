
FROM osgeo/gdal

RUN apt update && \
    apt-get install -y jq

ADD functions.sh /functions.sh

ADD stac-ify /usr/bin/stac-ify 
  
RUN chmod +x /usr/bin/stac-ify 