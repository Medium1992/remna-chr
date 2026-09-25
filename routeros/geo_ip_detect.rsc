# Load all exact domains and suffix roots from MetaCubeX's IP/geolocation
# detection category. A suffix root is intentionally added once as FQDN rather
# than expanding it into potentially thousands of subdomains.

:local list "GEO_IP_DETECT"
:local tag "geo-ip-detect"
:local sourceUrl "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/category-ip-geo-detect.json"
:local fetched [/tool/fetch url=$sourceUrl mode=https output=user as-value]
:if (($fetched->"status") != "finished") do={ :error ("GEO_IP_DETECT fetch failed: " . ($fetched->"status")) }

:local document
:onerror errorMessage in={
    :set document [:deserialize ($fetched->"data") from=json]
} do={
    :error ("GEO_IP_DETECT JSON parse failed: " . $errorMessage)
}

:local src "|"
:local added 0
:local removed 0
:foreach rule in=($document->"rules") do={
    :foreach host in=($rule->"domain") do={
        :if ([:find $src ("|" . $host . "|")] = [:nothing]) do={
            :set src ($src . $host . "|")
            :do {
                /ip/firewall/address-list/add list=$list address=$host comment=$tag
                :set added ($added + 1)
            } on-error={}
        }
    }
    :foreach host in=($rule->"domain_suffix") do={
        :if ([:find $src ("|" . $host . "|")] = [:nothing]) do={
            :set src ($src . $host . "|")
            :do {
                /ip/firewall/address-list/add list=$list address=$host comment=$tag
                :set added ($added + 1)
            } on-error={}
        }
    }
}

# Not contained in the upstream category but used as a public-address redirector.
:if ([:find $src "|redirector.googlevideo.com|"] = [:nothing]) do={
    :set src ($src . "redirector.googlevideo.com|")
    :do {
        /ip/firewall/address-list/add list=$list address=redirector.googlevideo.com comment=$tag
        :set added ($added + 1)
    } on-error={}
}

:foreach id in=[/ip/firewall/address-list/find where list=$list and comment=$tag] do={
    :local host [/ip/firewall/address-list/get $id address]
    :if ([:find $src ("|" . $host . "|")] = [:nothing]) do={
        /ip/firewall/address-list/remove $id
        :set removed ($removed + 1)
    }
}
:log info ("GEO_IP_DETECT sync done: added=" . $added . " removed=" . $removed)
