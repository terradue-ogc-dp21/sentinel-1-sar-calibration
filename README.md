# Sentinel-1 SAR calibration

This repo contains a CWL Workflow to discover and calibrate Copernicus Sentinel-1 GRD acquisitions

## Requirements to run a CWL Workflow

You'll need: 

- a CWL runner, see https://cwl-for-eo.github.io/guide/requirements/#cwl-runner
- a container runner, see https://cwl-for-eo.github.io/guide/requirements/#docker

## Get the CWL Workflow

The Sentinel-1 SAR calibration workflow releases are available at: https://github.com/terradue-ogc-dp21/sentinel-1-sar-calibration/releases

## Running the CWL Workflow

Prepare a YAML parameters file with the skeleton:

```yaml
# OpenSearch endpoint for Sentinel-1
endpoint: "https://catalog.terradue.com/sentinel1/search"

# set the OpenSearch search terms (key=value)
search_terms:
- "uid=S1B_IW_GRDH_1SDV_20210929T233417_20210929T233442_028919_037386_1E60"

# another set of search terms provided as an example:
#- "count=2"
#- "start=2021-01-01T00:00:00Z"
#- "stop=2021-01-02T00:00:00Z"
#- "eop:productType=GRD"
#- "geom=POLYGON((8.086 38.548%2C8.086 40.313%2C11.25 40.313%2C11.25 38.548%2C8.086 38.548))"

# ASF credentials
asf_username: ""
asf_password: ""

# Optional upload to an Object Storage
# uncomment and add the values to publish the calibrated data to an S3 object storage
# sink-access-key-id: 
# sink-secret-access-key: 
# sink-service-url: 
# sink-region: 
# sink-path: s3://
```

Run with: 

```console
cwltool s1-sar-calibration.0.1.0.cwl params.yml
```
