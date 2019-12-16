xquery version "3.1";

module namespace jmmc-eso-p2="http://www.jmmc.fr/a2p2w/jmmc-eso-p2";

declare variable $jmmc-eso-p2:cache-name := "jmmc-eso-p2-cache-name";
declare variable $jmmc-eso-p2:ip-url := "https://www.eso.org/copdemo/api/v1/instrumentPackages/";

declare function jmmc-eso-p2:instruments() as xs:string*
{
    ("GRAVITY", "MATISSE",  "PIONIER")
};

declare function jmmc-eso-p2:q($paths){
    let $url := string-join(($jmmc-eso-p2:ip-url, $paths), "/")
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
    array:flatten(jmmc-eso-p2:q(($instrument,'')))
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

(: 
    INSCONFILE=$PDIR/${instrument}.instrumentConstraints
    test -e $INSCONFILE || curl https://www.eso.org/copdemo/api/v1/instrumentPackages/${instrument}/${period}/instrumentConstraints | jq --sort-keys ".observingConstraints |= sort_by(.name)" > $INSCONFILE
:)
