function get_items {

    # returns the list of items in catalog
    # args:
    #  STAC catalog

    catalog=$1

    for item in $( jq -r '.links[] | select(.. | .rel? == "item") | .href' ${catalog} )
    do 
        echo $( dirname ${catalog})/${item}
    done

}

export -f get_items

function get_asset {

    # returns the asset href
    # args:
    #  STAC item 
    #  asset key

    item=$1
    asset=$2

    echo $( dirname $item)/$( jq --arg asset $asset -r ".assets.$asset.href" $item )

}

export -f get_asset 

function get_item_property {

    # return an item property value
    # args:
    #  STAC item
    #  property key
    item=$1
    property=$2

    echo $( jq --arg property $property ".properties.$property" $item )

}

export -f get_item_property

function init_catalog {

    # returns a STAC catalog without items

    echo '{}' |
    jq '.["id"]="catalog"' |
    jq '.["stac_version"]="1.0.0"' | 
    jq '.["type"]="catalog"' |
    jq '.["description"]="Result catalog"' |
    jq '.["links"]=[]'         

}

export -f init_catalog

function add_item {

    # adds an item to a STAC catalog
    # args:
    #  STAC catalog
    #  STAC item href 
    catalog=$1
    item=$2
    jq -e \
        --arg item ${item} \
        '.links += [{ "type":"application/geo+json", "rel":"item", "href":$item}]' ${catalog} > ${catalog}.tmp && mv ${catalog}.tmp ${catalog}

}

export -f add_item

function init_item {

    local item=$1
    local datetime=$2
    local bbox=$3
    local gsd=$4

    echo '{}' |
    jq --arg item_id ${item} '.["id"]=$item_id' | # set the item id
    jq '.["stac_version"]="1.0.0"' | 
    jq '.["type"]="Feature"' | # set the item type
    jq --arg c "$( echo $bbox | cut -d ',' -f 1)" '.bbox[0]=$c' | # set the bbox elements 
    jq --arg c "$( echo $bbox | cut -d ',' -f 2)" '.bbox[1]=$c' |
    jq --arg c "$( echo $bbox | cut -d ',' -f 3)" '.bbox[2]=$c' |
    jq --arg c "$( echo $bbox | cut -d ',' -f 4)" '.bbox[3]=$c' |
    jq '.bbox[] |= tonumber' | # convert the bbox to number
    jq '.["geometry"].type="Polygon"' | # set the geometry type
    jq '.["geometry"].coordinates=[]' |
    jq '.["geometry"].coordinates[0]=[]' |
    jq --arg min_lon "$( echo $bbox | cut -d ',' -f 1)" \
    --arg min_lat "$( echo $bbox | cut -d ',' -f 2)" \
    --arg max_lon "$( echo $bbox | cut -d ',' -f 3)" \
    --arg max_lat "$( echo $bbox | cut -d ',' -f 4)" \
    '.["geometry"].coordinates[0][0]=[$min_lon | tonumber, $min_lat | tonumber] | .["geometry"].coordinates[0][1]=[$max_lon | tonumber, $min_lat | tonumber] | .["geometry"].coordinates[0][2]=[$max_lon | tonumber, $max_lat | tonumber] | .["geometry"].coordinates[0][3]=[$min_lon | tonumber, $max_lat | tonumber] | .["geometry"].coordinates[0][4]=[$min_lon | tonumber, $min_lat | tonumber]' | # set the geojson Polygon coordinates
    jq --arg dt ${datetime} '.properties.datetime=$dt' | # set the datetime
    jq --arg gsd "${gsd}" '.properties.gsd=$gsd' | # set the gsd
    jq '.properties.gsd |= tonumber' | # convert the gsd to number
    jq -r '.["assets"]={}'  

}

export -f init_item

function add_asset {

    # adds an asset to a STAC item
    # args:
    #  STAC item
    #  asset key
    #  asset href
    #  asset mime-type
    #  asset title 
    #  asset role
    local item=$1
    local asset_key=$2
    local href="$3"
    local type="$4"
    local title="$5"
    local role="$6"

    jq -e -r \
        --arg asset_key $asset_key \
        --arg href ${href} \
        --arg type "${type}" \
        --arg title "${title}" \
        --arg role "${role}" \
        '.assets += { ($asset_key) : { "roles":[$role], "href":$href, "type":$type, "title":$title}}' ${item} > ${item}.tmp && mv ${item}.tmp ${item}



}

export -f add_asset