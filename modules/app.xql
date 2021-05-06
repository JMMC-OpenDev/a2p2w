xquery version "3.1";

module namespace app="http://www.jmmc.fr/a2p2w/templates";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://www.jmmc.fr/a2p2w/config" at "config.xqm";
import module namespace jmmc-eso-p2="http://www.jmmc.fr/a2p2w/jmmc-eso-p2" at "jmmc-eso-p2.xqm";
import module namespace functx="http://www.functx.com" ;

declare function app:show($node as node(), $model as map(*), $instrument as xs:string?, $period as xs:string?, $template as xs:string?, $period2 as xs:string?) {
    (
        <ul class="breadcrumb"> <li><u>Instrument</u></li>
        {for $ins in jmmc-eso-p2:instruments() let $a := <a href="?instrument={$ins}">{$ins}</a> 
        let $li := if($ins = $instrument) then <b>{$a}</b> else $a
        return <li>{$li}</li>}
        </ul>
        ,
        if (exists($instrument)) then
            (
                app:period-breadcrumb($instrument, $period, $template)
                ,if (exists($period)) then app:show-period( $instrument, $period, $template, $period2 ) else ()
            )
        else
            ()
    )
};

declare function app:period-breadcrumb($instrument, $period, $template) {
	<ul class="breadcrumb"><li><u>Period</u></li>{
                    for $mp in jmmc-eso-p2:periods($instrument) 
                        order by number(substring-before($mp, ".")) descending 
                        group by $p-major := number(substring-before($mp, ".")) 
                        return (<li>{$p-major}</li>,
                        for $p in $mp
                            let $p-minor :=number(substring-after($p, "."))
                            let $href := "?instrument="||$instrument||"&amp;"||"period="||$p||"&amp;"||"template="||$template
                            order by $p-minor descending
                            return <li style="{if (string($p) = $period) then "font-weight:bold;" else ()}" ><a href="{$href}">.{$p-minor}</a></li>  )
                }</ul>
};

declare function app:show-period($instrument, $period, $template as xs:string?, $period2 as xs:string?) {
    <ul class="breadcrumb"><li><u>Template</u></li>
        {
            for $templates in jmmc-eso-p2:template-signatures($instrument, $period)//template
                group by $type := data($templates/type)
                order by $type
                return (<li>{$type}</li>,
                for $t in $templates
                    let $name := data($t/templateName)
                    let $dname := substring-after($name,"_")
                    return <li style="{if (string($template) = $name) then "font-weight:bold;" else ()}"><a href="?instrument={$instrument}&amp;period={$period}&amp;template={$name}">{$dname}</a></li>
                )
        }
    </ul>
    ,
    app:show-instrument-constraints($instrument, $period)
    ,
    if (exists($template)) then app:show-template($instrument, $period, $template) else (),
    if (exists($template) and exists($period2)) then app:show-template($instrument, $period2, $template) else ()
};

declare function app:show-template($instrument, $period, $template) {
    let $template-params := try {
        jmmc-eso-p2:template($instrument, $period, $template)("parameters")    
    } catch * {
        ()
    }
    return 
    if (not(exists($template)) or string-length($template)=0 ) then ()
    else if (not(exists($template-params))) then <h2><b>{$template}</b> not present in P{$period}</h2>
    else
    <div>
        <h2><b>{$template}</b> P{$period}</h2>
        <em>TBD : YAPATOUTESLESCARACDESPARAM....</em>
        <table class="table">
        {
            let $params := array:flatten($template-params)
            return for $param in $params
                let $name := $param("name")
                let $default := $param("default")
                let $allowedValues := $param("allowedValues")
                let $label := $param("label")
                let $minihelp := $param("minihelp")
                let $type := $param("type")
                return <tr><td>{$label}</td><td>{$name}</td><td>{$type}</td><td>{$default}</td><td>{$minihelp}</td></tr>
        }
        </table>
        <pre>    &quot;{ $template }&quot;&#10;    {{&#10;{
                let $params := array:flatten($template-params)
                let $lines := for $param in $params 
                    return app:param-line($param)
                return string-join($lines, ",&#10;")
            }&#10;    }},
            </pre>
    </div>
};

declare function app:param-line($param) {
	    let $name := functx:pad-string-to-length("&quot;"|| $param("name") || "&quot;:" , " ",30)
                    let $default := $param("default")
                    let $type := $param("type")
                    let $default := if(exists($default))
                        then 
(:                            let $str := try {:)
(:                                            if( functx:is-a-number($default))  then $default else "&quot;"||$default||"&quot;" :)
(:                                        } catch * {:)
(:                                            ( :)
(:                                                util:log("info", $name ||" 's default format unrecognized "|| $default),:)
(:                                                "&quot;"||$default||"&quot;" :)
(:                                            ) :)
(:                                        }:)
                            let $str := if( $type = "number")  then $default else "&quot;"||$default||"&quot;" 
                                        
                            return "&quot;default&quot;: "||$str
                        else 
                            ()
                    let $allowedValues := $param("allowedValues")
                    let $allowedValues := if (exists($allowedValues))
                        then 
                            let $values := $allowedValues("values")
                            let $ranges := $allowedValues("ranges")
                            return if (exists($values)) then 
                                    "&quot;list&quot;: [" || string-join(array:for-each($values, function($e) { "&quot;"||$e||"&quot;" }) ,", ") || "]"  
                                else if (exists($ranges)) then
                                    for $range in $ranges
                                        return array:for-each($range, 
                                            function($m) { 
                                                map:for-each($m, function($e){"&quot;" || $e || "&quot;: "||map:get($m,$e)})
                                            }
                                        )
                                else
                                    ()
                        else
                            ()
                    let $values := $param("values")
                    let $values := if (exists($values)) then 
                                    "&quot;list&quot;: [" || string-join(array:for-each($values, function($e) { "&quot;"||$e||"&quot;" }) ,", ") || "]"  
                                    else 
                                        ()
                    let $range := $param("range")
                    let $range := if (exists($range)) then 
                                        string-join(map:for-each($range, function($e) { "&quot;"||$e||"&quot;: "||map:get($range,$e) }) ,", ")
                                    else 
                                        ()
                    
                    let $label := $param("label")
                    let $minihelp := $param("minihelp")
                    let $type := $param("type")
                    return "        " || $name || "{" || string-join(($default,$values,$allowedValues, $range), ", ") || "}"
};

declare function app:show-instrument-constraints($instrument, $period) {
    <div>
        <h3>Instrument constraints</h3>
        <pre>{
            let $params:= for $param in jmmc-eso-p2:instrument-constraints($instrument, $period)
                return  app:param-line($param)
            return string-join($params, ",&#10;")
        }</pre>
    </div>
};
