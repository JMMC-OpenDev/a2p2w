xquery version "3.1";

module namespace jmmc-eso-p2="http://www.jmmc.fr/a2p2w/jmmc-eso-p2";

declare variable $jmmc-eso-p2:cache-name := "jmmc-eso-p2-cache-name";
declare variable $jmmc-eso-p2:expirable-cache-name := $jmmc-eso-p2:cache-name||"-expirable";
declare variable $jmmc-eso-p2:expirable-cache := cache:create($jmmc-eso-p2:expirable-cache-name||"-expirable",map { "expireAfterAccess": 1200000 });

declare variable $jmmc-eso-p2:ip-url := "https://www.eso.org/cop/api/v1/instrumentPackages/";

declare function jmmc-eso-p2:instruments() as xs:string*
{
    ("GRAVITY", "MATISSE",  "PIONIER")
};

declare function jmmc-eso-p2:query($paths,$use-permanent-cache as xs:boolean*){
    let $url := string-join(($jmmc-eso-p2:ip-url, $paths), "/")
    let $c := cache:get($jmmc-eso-p2:cache-name, $url)
    return
        if(exists($c) and $use-permanent-cache)
        then 
            $c
        else
            let $log := util:log("info", "trying to get data at "||$url)
            let $res := json-doc($url)
            let $store := cache:put($jmmc-eso-p2:cache-name, $url, $res)
            return 
                $res
};

declare function jmmc-eso-p2:q($paths){
   jmmc-eso-p2:query($paths, true())
};

declare function jmmc-eso-p2:q($paths){
    let $url := string-join(($jmmc-eso-p2:ip-url, $paths), "/")
    let $log := util:log("info", "q : "|| $url)
    let $c := cache:get($jmmc-eso-p2:cache-name, $url)
    return
        if(exists($c))
        then 
            $c
        else
            let $log := util:log("info", "trying to get data at "||$url)
            let $res := json-doc($url)
            let $store := cache:put($jmmc-eso-p2:cache-name, $url, $res)
            return 
                $res
};

declare function jmmc-eso-p2:periods($instrument) (: as xs:string ?:)
{
    (: add last '' to force trailing / :)
    (: Do not use permanent cache since it can evolve:)
    array:flatten(jmmc-eso-p2:query(($instrument,''), false()))
};

(: ~ Output list of templates as xml 
 : list of map { "templateName": "PIONIER_acq", "type": "acquisition" }
 :  is transformed onto xml
 : :)
declare function jmmc-eso-p2:template-signatures($instrument, $period)
{
    element {"templates"} {
        for $m in array:flatten(jmmc-eso-p2:q(($instrument,$period, "templateSignatures")))
        return 
            element {"template"} { map:for-each($m, function($e) { element {$e} {map:get($m, $e)} } ) }
    }
};

(: ~ Output list of templates as xml 
 : e.g. : map { "templateName": "PIONIER_acq", "type": "acquisition" }
 :  
 : :)
declare function jmmc-eso-p2:template($instrument, $period, $template)
{
    jmmc-eso-p2:q(($instrument,$period, "templateSignatures", $template))
};

(: ~ Output instrumentConstraints as xml 
 :)
declare function jmmc-eso-p2:instrument-constraints($instrument, $period)
{
    array:flatten(jmmc-eso-p2:q(($instrument,$period, "instrumentConstraints"))("observingConstraints"))
};

(: 
 map {
    "observingConstraints": [map {
        "default": 1.6e0,
        "name": "airmass",
        "inputValidationPattern": "\d{0,1}(\.\d{0,1})?",
        "label": "Airmass",
        "type": "float",
        "range": map {
            "max": 5.0e0,
            "min": 1.0e0
        }
    },map {
        "default": "Clear",
        "values": ["Photometric","Clear","Variable, thin cirrus","Variable, thick cirrus"],
        "name": "skyTransparency",
        "label": "Sky Transparency",
        "type": "string"
    },map {
        "default": 3.0e1,
        "name": "waterVapour",
        "inputValidationPattern": "\d{0,2}(\.\d{0,1})?",
        "label": "PWV (mm)",
        "type": "float",
        "range": map {
            "max": 3.0e1,
            "min": 1.0e-1
        }
    },map {
        "default": "50%  (Seeing < 1.0  arcsec, t0 > 3.2 ms)",
        "values": ["10%  (Seeing < 0.6  arcsec, t0 > 5.2 ms)","20%  (Seeing < 0.7  arcsec, t0 > 4.4 ms)","30%  (Seeing < 0.8  arcsec, t0 > 4.1 ms)","50%  (Seeing < 1.0  arcsec, t0 > 3.2 ms)","70%  (Seeing < 1.15 arcsec, t0 > 2.2 ms)","85%  (Seeing < 1.4  arcsec, t0 > 1.6 ms)"],
        "name": "atm",
        "label": "Turbulence Category",
        "type": "string"
    }]
}

 
 : 
 : 
    INSCONFILE=$PDIR/${instrument}.instrumentConstraints
    test -e $INSCONFILE || curl https://www.eso.org/copdemo/api/v1/instrumentPackages/${instrument}/${period}/instrumentConstraints | jq --sort-keys ".observingConstraints |= sort_by(.name)" > $INSCONFILE
:)
