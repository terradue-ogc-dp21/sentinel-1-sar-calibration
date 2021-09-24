$graph:
- class: Workflow
  label: Stage-in/out (source to local filesystem or source to sink object storages)
  doc: Stage-in/out (source to local filesystem or source to sink object storages)
  id: main
  inputs:
    source-access-key-id:
      doc: Source access-key-id if staging from object storage (optional)
      type: string?
    source-secret-access-key:
      doc: Source secret access key if staging from object storage (optional)
      type: string?
    source-service-url:
      doc: Source region if staging from object storage (optional)
      type: string?
    source-region:
      doc: Source region if staging from object storage (optional)
      type: string?
    sink-access-key-id:
      doc: Sink access key id if staging to object storage (optional)
      type: string?
    sink-secret-access-key:
      doc: Sink secret access key if staging to object storage (optional)
      type: string?
    sink-service-url:
      doc: Sink service URL if staging to object storage (optional)
      type: string?
    sink-region:
      doc: Sink region if staging to object storage (optional)
      type: string?      
    sink-path:
      doc: Sink path if staging to object storage (optional)
      type: string?  
    #input-reference:
    #  doc: A reference to an opensearch catalog
    #  label: A reference to an opensearch catalog
    #  type: string[]
    search-terms:
      type: string[]?
      doc: key:value pair for the discovery step
    endpoint:
      type: string
      doc: opensearch endpoint
    harvest:
      type: string
      doc: Do the harvesting (true/false)
    verbose:
      type: string
      doc: Higher verbosity level (true/false)
#    do:
#     type: string[]
    config:
      type: File
      doc: Stars Configuration file for the stage-in step
    si: 
      type: string[]
      doc: Sets the supplier(s) 
  outputs:
  - id: wf_outputs_m
    outputSource:
    - node_stage_out/wf_outputs_out
    type:
          type: array
          items:
            type: array
            items: Directory
  requirements:
    - class: ScatterFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement


  steps:
    node_opensearch:
      in: 
        inp1: search-terms
        inp2: endpoint
      out:
      - results
      run: "#opensearch"
       
    node_stage_in:
      in:
        inp1: 
          source: node_opensearch/results
        harvest: harvest
        verbose: verbose
        source_access_key_id: source-access-key-id
        source_secret_access_key: source-secret-access-key
        source_service_url: source-service-url
        source_region: source-region
        config: config
        si: si
      out:
      - results
      run: "#stage-in"
        
      scatter: inp1
      scatterMethod: dotproduct  

    node_stage_out:
      in:
        sink_access_key_id: sink-access-key-id
        sink_secret_access_key: sink-secret-access-key
        sink_service_url: sink-service-url
        sink_path: sink-path
        sink_region: sink-region
        wf_outputs: 
            source: [node_stage_in/results]
      out:
      - wf_outputs_out
      run: "#stage-out"
        
      scatter: wf_outputs
      scatterMethod: dotproduct


- class: CommandLineTool 
  id: opensearch
  baseCommand: opensearch-client
  arguments:
  stdout: message        
  requirements:
    DockerRequirement:
      dockerPull: docker.io/terradue/opensearch-client:latest
  inputs:
    inp1: 
      type:
        - "null"
        - type: array
          items: string
          inputBinding:
            prefix: '-p'
    inp2:
      inputBinding:
        position: 8
      type: string
  outputs:
    results: 
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
  #- -xa
  #- "false"
  - valueFrom: |
      ${ return '-conf=' + inputs.config.path }
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
        if (inputs.inp1.split("#").length == 2) 
          { return ["-af", inputs.inp1.split("#")[1]]; }
        else 
          {return "--empty"}
        }
  - -o
  - ./
  - valueFrom: ${ return inputs.inp1.split("#")[0]; } # + '&do=[' + inputs.do.toString() + ']'; }
    
  inputs:
    inp1:
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
    config:
      type: File
    si: 
      type: string[]
  outputs:
    results:
      outputBinding:
        glob: .
      type: Any
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
      dockerPull: terradue/stars-t2:0.9.36

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
  - -af 
  - download
 
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
      type: Directory[]

  outputs:
    wf_outputs_out:
      outputBinding:
        glob: .
      type: Directory[]

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
