$namespaces:
  s: https://schema.org/
s:softwareVersion: 0.1.1
schemas:
- http://schema.org/version/9.0/schemaorg-current-http.rdf


$graph:
- class: Workflow
  label: Stage-in/out (source to local filesystem or source to sink object storages)
  doc: Stage-in/out (source to local filesystem or source to sink object storages)
  id: main
  inputs:
    source_access_key_id:
      doc: Source access-key-id if staging from object storage (optional)
      type: string?
    source_secret_access_key:
      doc: Source secret access key if staging from object storage (optional)
      type: string?
    source_service_url:
      doc: Source region if staging from object storage (optional)
      type: string?
    source_region:
      doc: Source region if staging from object storage (optional)
      type: string?
    sink_access_key_id:
      doc: Sink access key id if staging to object storage (optional)
      type: string?
    sink_secret_access_key:
      doc: Sink secret access key if staging to object storage (optional)
      type: string?
    sink_service_url:
      doc: Sink service URL if staging to object storage (optional)
      type: string?
    sink_region:
      doc: Sink region if staging to object storage (optional)
      type: string?      
    sink_path:
      doc: Sink path if staging to object storage (optional)
      type: string?  
    asf_username: 
      type: string
    asf_password:
      type: string
    search_terms:
      type: string[]?
      doc: key:value pair for the discovery step
    endpoint:
      type: string
      doc: opensearch endpoint
    harvest:
      type: string?
      doc: Do the harvesting (true/false)
      default: "true"
    verbose:
      type: string
      doc: Higher verbosity level (true/false)
      default: "false"
    si: 
      type: string
      doc: Sets the supplier
      default: "ASF"

  outputs:
  - id: wf_outputs_m
    outputSource:
    - node_calibration/calibration_outputs
    type: Directory[]
         # type: array
         # items:
         #   type: array
         #   items: Directory
  requirements:
    - class: ScatterFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement
    - class: SubworkflowFeatureRequirement


  steps:
    node_opensearch:
      in: 
        search_terms: search_terms
        endpoint: endpoint
      out:
      - discovered
      run: "#opensearch"
       
    node_calibration:

      in: 
        product_reference:
          source: node_opensearch/discovered
        harvest: harvest
        verbose: verbose
        source_access_key_id: source_access_key_id
        source_secret_access_key: source_secret_access_key
        source_service_url: source_service_url
        source_region: source_region
        si: si
        asf_password: asf_password
        asf_username: asf_username
      out: 
      - calibration_outputs

      run: "#wf-sar-calibration"

      scatter: product_reference
      scatterMethod: dotproduct

- class: Workflow

  id: wf-sar-calibration

  inputs:
    source_access_key_id:
      doc: Source access-key-id if staging from object storage (optional)
      type: string?
    source_secret_access_key:
      doc: Source secret access key if staging from object storage (optional)
      type: string?
    source_service_url:
      doc: Source region if staging from object storage (optional)
      type: string?
    source_region:
      doc: Source region if staging from object storage (optional)
      type: string?
    sink_access_key_id:
      doc: Sink access key id if staging to object storage (optional)
      type: string?
    sink_secret_access_key:
      doc: Sink secret access key if staging to object storage (optional)
      type: string?
    sink_service_url:
      doc: Sink service URL if staging to object storage (optional)
      type: string?
    sink_region:
      doc: Sink region if staging to object storage (optional)
      type: string?      
    sink_path:
      doc: Sink path if staging to object storage (optional)
      type: string?  
    asf_username: 
      type: string
    asf_password:
      type: string
    search_terms:
      type: string[]?
      doc: key:value pair for the discovery step
    product_reference: 
      type: string
    harvest:
      type: string?
      doc: Do the harvesting (true/false)
      default: "true"
    verbose:
      type: string
      doc: Higher verbosity level (true/false)
      default: "false"
    si: 
      type: string
      doc: Sets the supplier
      default: "ASF"

  outputs:
  - id: calibration_outputs
    outputSource:
    - node_stage_out/wf_outputs_out
    type: Directory

  steps:

    node_stage_in:
      in:
        product_reference: product_reference
        harvest: harvest
        verbose: verbose
        source_access_key_id: source_access_key_id
        source_secret_access_key: source_secret_access_key
        source_service_url: source_service_url
        source_region: source_region
        si: si
        asf_password: asf_password
        asf_username: asf_username
      out:
      - staged
      run: "#stage-in"
        
    node_resolve_manifest:
      run: '#cat2asset'
      in:
        stac: 
          source: [node_stage_in/staged]
        asset:
          default: "manifest"
      out:
      - asset_href

    node_sar_calibration: 
      in:
        product: 
          source: node_stage_in/staged
        asset_href:
          source: node_resolve_manifest/asset_href
      out: 
      - calibrated
      run: "#sar-calibration"
        
    node_stac:

      in:
        staged: 
          source: node_stage_in/staged
        calibrated:
          source: node_sar_calibration/calibrated
        overview:
          source: node_sar_calibration/calibrated

      out: 
      - stac

      run: "#stac-ify"


    node_stage_out:
      in:
        sink_access_key_id: sink_access_key_id
        sink_secret_access_key: sink_secret_access_key
        sink_service_url: sink_service_url
        sink_path: sink_path
        sink_region: sink_region
        wf_outputs: 
            source: node_stac/stac
      out:
      - wf_outputs_out
      run: "#stage-out"
      



- class: CommandLineTool 
  id: opensearch
  baseCommand: opensearch-client
  arguments:
  stdout: message        
  requirements:
    DockerRequirement:
      dockerPull: docker.io/terradue/opensearch-client:latest
  inputs:
    search_terms: 
      type:
        - "null"
        - type: array
          items: string
          inputBinding:
            prefix: '-p'
    endpoint:
      inputBinding:
        position: 8
      type: string
  outputs:
    discovered: 
      type: string[]
      outputBinding:
        glob: message
        loadContents: true
        outputEval: $(self[0].contents.split('\n').slice(0,-1))

- class: CommandLineTool
  id: stage-in

  baseCommand: Stars
  
  arguments:
  - copy
  - valueFrom: |
      ${ 
          return "-conf=" + runtime.outdir + "/usersettings.json";
      }
  - -rel
  - -si 
  - valueFrom: |
      ${
        return inputs.si.toString(); 
      }
  - valueFrom: |
      ${ 
        if (inputs.verbose == 'true')
          {return "-v";} 
        else 
          {return "--empty"}
        }
  - -r
  - '4'
  - valueFrom: |
      ${ 
        if (inputs.harvest == 'true')
          {return "--harvest";} 
        else 
          {return "--empty"}
        }
  - valueFrom: |
      ${ 
        if (inputs.product_reference.split("#").length == 2) 
          { return ["-af", inputs.product_reference.split("#")[1]]; }
        else 
          {return "--empty"}
        }
  - -o
  - ./
  - valueFrom: ${ return inputs.product_reference.split("#")[0]; } 
    
  inputs:
    product_reference:
      inputBinding:
      type: string
    harvest:
      type: string
    verbose:
      type: string
    source_access_key_id:
      type: string?
    source_secret_access_key:
      type: string?
    source_service_url:
      type: string?
    source_region:
      type: string?
    asf_username:
      type: string
    asf_password: 
      type: string
    si: 
      type: string
  outputs:
    staged:
      outputBinding:
        glob: .
      type: Directory
  requirements:
    EnvVarRequirement:
        envDef:
          AWS_ACCESS_KEY_ID: $(inputs.source_access_key_id)
          AWS_SECRET_ACCESS_KEY: $(inputs.source_secret_access_key)
          AWS__ServiceURL: $(inputs.source_service_url)
          AWS__Region: $(inputs.source_region)
          AWS__AuthenticationRegion: $(inputs.source_region)
          AWS__SignatureVersion: "2"
          PATH: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    ResourceRequirement: {}    
    InlineJavascriptRequirement: {}
    DockerRequirement:
      dockerPull: docker.io/terradue/stars-t2:0.9.44
    InitialWorkDirRequirement: 
      listing: 
        - entryname: usersettings.json
          entry: |- 
            {
                "Plugins": {
                    "Terradue": {
                        "Assembly": "/usr/share/Stars-Terradue/Stars-Terradue.dll",
                        "Suppliers": {
                            "ASF": {
                                "Type": "Terradue.Data.Stars.Suppliers.DataHubSourceSupplier",
                                "ServiceUrl": "https://api.daac.asf.alaska.edu",
                                "Priority": 3
                            }
                        }
                    }
                },
                "Credentials": {
                    "ASF": {
                        "AuthType": "basic",
                        "UriPrefix": "https://urs.earthdata.nasa.gov",
                        "Username": "$(inputs.asf_username)",
                        "Password": "$(inputs.asf_password)"
                    }
                }
            }


- class: CommandLineTool
  id: cat2asset
  requirements:
    InlineJavascriptRequirement: {}
    DockerRequirement:
      dockerPull: docker.io/terradue/jq
    ShellCommandRequirement: {}
    InitialWorkDirRequirement:
      listing:
        - entryname: resolve.sh
          entry: |-
            item="` jq -r '.links | select(.. | .rel? == "item")[0].href' $(inputs.stac.path)/catalog.json`"
            echo `dirname $item`/`cat $(inputs.stac.path)/$item | jq -r ".assets.$(inputs.asset).href"`
  baseCommand: ["/bin/bash", "resolve.sh"]
  inputs:
    stac: Directory
    asset: string
  outputs:
    asset_href:
      type: string
      outputBinding:
        glob: message
        loadContents: true
        outputEval: $( self[0].contents.split("\n").join("") )
  stdout: message

- class: CommandLineTool
  id: sar-calibration

  requirements:
    DockerRequirement:
      dockerPull: snap-gpt
    EnvVarRequirement:
      envDef:
        PATH: /srv/conda/envs/env_snap/snap/bin:/usr/share/java/maven/bin:/usr/share/java/maven/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin
    ResourceRequirement: {}
    InitialWorkDirRequirement:
      listing:
        - entryname: calibration.xml
          entry: |-
            <graph id="Graph">
              <version>1.0</version>
              <node id="Read">
                <operator>Read</operator>
                  <sources/>
                  <parameters class="com.bc.ceres.binding.dom.XppDomElement">
                    <file>$inFile</file>
                    <formatName>SENTINEL-1</formatName>
                  </parameters>
              </node>
              <node id="Apply-Orbit-File">
                <operator>Apply-Orbit-File</operator>
                <sources>
                  <sourceProduct refid="Read"/>
                </sources>
                <parameters class="com.bc.ceres.binding.dom.XppDomElement">
                  <orbitType>Sentinel Precise (Auto Download)</orbitType>
                  <polyDegree>3</polyDegree>
                  <continueOnFail>true</continueOnFail>
                </parameters>
              </node>
              <node id="Calibration">
                <operator>Calibration</operator>
                <sources>
                  <sourceProduct refid="Apply-Orbit-File"/>
                </sources>
                <parameters class="com.bc.ceres.binding.dom.XppDomElement">
                  <sourceBands/>
                  <auxFile>Latest Auxiliary File</auxFile>
                  <externalAuxFile/>
                  <outputImageInComplex>false</outputImageInComplex>
                  <outputImageScaleInDb>false</outputImageScaleInDb>
                  <createGammaBand>false</createGammaBand>
                  <createBetaBand>false</createBetaBand>
                  <selectedPolarisations/>
                  <outputSigmaBand>true</outputSigmaBand>
                  <outputGammaBand>false</outputGammaBand>
                  <outputBetaBand>false</outputBetaBand>
                </parameters>
              </node>
              <node id="LinearToFromdB">
                <operator>LinearToFromdB</operator>
                <sources>
                  <sourceProduct refid="Calibration"/>
                </sources>
                <parameters class="com.bc.ceres.binding.dom.XppDomElement">
                  <sourceBands/>
                </parameters>
              </node>
              <node id="Terrain-Correction">
                <operator>Terrain-Correction</operator>
                <sources>
                  <sourceProduct refid="LinearToFromdB"/>
                </sources>
                <parameters class="com.bc.ceres.binding.dom.XppDomElement">
                  <sourceBands/>
                  <demName>SRTM 1Sec HGT</demName>
                  <externalDEMFile/>
                  <externalDEMNoDataValue>0.0</externalDEMNoDataValue>
                  <externalDEMApplyEGM>true</externalDEMApplyEGM>
                  <demResamplingMethod>BILINEAR_INTERPOLATION</demResamplingMethod>
                  <imgResamplingMethod>BILINEAR_INTERPOLATION</imgResamplingMethod>
                  <pixelSpacingInMeter>20.0</pixelSpacingInMeter>
                  <pixelSpacingInDegree>0.0</pixelSpacingInDegree>
                  <mapProjection>AUTO:42001</mapProjection>
                  <alignToStandardGrid>false</alignToStandardGrid>
                  <standardGridOriginX>0.0</standardGridOriginX>
                  <standardGridOriginY>0.0</standardGridOriginY>
                  <nodataValueAtSea>true</nodataValueAtSea>
                  <saveDEM>false</saveDEM>
                  <saveLatLon>false</saveLatLon>
                  <saveIncidenceAngleFromEllipsoid>false</saveIncidenceAngleFromEllipsoid>
                  <saveLocalIncidenceAngle>false</saveLocalIncidenceAngle>
                  <saveProjectedLocalIncidenceAngle>false</saveProjectedLocalIncidenceAngle>
                  <saveSelectedSourceBand>true</saveSelectedSourceBand>
                  <saveLayoverShadowMask>false</saveLayoverShadowMask>
                  <outputComplex>false</outputComplex>
                  <applyRadiometricNormalization>false</applyRadiometricNormalization>
                  <saveSigmaNought>false</saveSigmaNought>
                  <saveGammaNought>false</saveGammaNought>
                  <saveBetaNought>false</saveBetaNought>
                  <incidenceAngleForSigma0>Use projected local incidence angle from DEM</incidenceAngleForSigma0>
                  <incidenceAngleForGamma0>Use projected local incidence angle from DEM</incidenceAngleForGamma0>
                  <auxFile>Latest Auxiliary File</auxFile>
                  <externalAuxFile/>
                </parameters>
              </node>
              <node id="Write">
                <operator>Write</operator>
                <sources>
                  <sourceProduct refid="Terrain-Correction"/>
                </sources>
                <parameters class="com.bc.ceres.binding.dom.XppDomElement">
                  <file>./cal.tif</file>
                  <formatName>GeoTIFF-BigTIFF</formatName>
                </parameters>
              </node>
            </graph>

  baseCommand: [gpt, calibration.xml]

  arguments:
  - -PinFile=$(inputs.product.path + "/" + inputs.asset_href )

  inputs:

    product:
      type: Directory

    asset_href: 
      type: string

  outputs:
    calibrated:
      outputBinding:
        glob: "*.tif"
      type: File

- class: CommandLineTool 

  id: stac-ify

  requirements:
    EnvVarRequirement:
      envDef:
        PATH: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    ResourceRequirement: {}    
    InlineJavascriptRequirement: {}
    DockerRequirement:
      dockerPull: stac-ify

  baseCommand: stac-ify
  
  arguments: []

  inputs:
    staged: 
      inputBinding:
        position: 1
      type: Directory
    calibrated:
      inputBinding:
        position: 2
      type: File
    overview:
      inputBinding:
        position: 3
      type: File

  outputs:
  
    stac:
      outputBinding:
        glob: .
      type: Directory

- class: CommandLineTool
  id: stage-out
 
  baseCommand: Stars
  
  arguments:
  - copy
  - -rel
  - valueFrom: |
      ${ 
        if (inputs.verbose == 'true')
          {return "-v";} 
        else 
          {return "--empty"}
        }
  - valueFrom: |
      ${ 
        if (inputs.harvest == 'true')
          {return "--harvest";} 
        else 
          {return "--empty"}
        }
  - -r
  - '4'
 
  inputs:
    sink_access_key_id:
      type: string?
    sink_secret_access_key:
      type: string?
    sink_service_url:
      type: string?
    sink_region:
      type: string?
    sink_path:
      inputBinding:
        position: 5
        prefix: -o
      type: string?
    wf_outputs:
      inputBinding:
        position: 6
      type: Directory

  outputs:
    wf_outputs_out:
      outputBinding:
        glob: .
      type: Directory

  requirements:
    EnvVarRequirement:
      envDef:
        AWS_ACCESS_KEY_ID: $(inputs.sink_access_key_id)
        AWS_SECRET_ACCESS_KEY: $(inputs.sink_secret_access_key)
        AWS__ServiceURL: $(inputs.sink_service_url)
        AWS__Region: $(inputs.sink_region)
        AWS__AuthenticationRegion: $(inputs.sink_region)
        AWS__SignatureVersion: "2"
        PATH: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    ResourceRequirement: {}
    DockerRequirement:
      dockerPull: terradue/stars-t2:latest

cwlVersion: v1.0
