:local list "SKIPA_CIDR"
:local tag "skipa"
:local url "https://raw.githubusercontent.com/tread-lightly/CyberOK_Skipa_ips/main/lists/skipa_cidr.txt"

:local r [/tool fetch url=$url mode=https output=user as-value]
:if (($r->"status") != "finished") do={ :error ("fetch failed: " . ($r->"status")) }

:local content ($r->"data")
:local line ""
:local char ""
:local len [:len $content]
:local i 0
:local src "|"
:local added 0
:local removed 0

:while ($i < $len) do={
    :set char [:pick $content $i ($i + 1)]
    :if ($char = "\r") do={} else={
        :if ($char = "\n") do={
            :if (([:len $line] > 0) && ([:pick $line 0 1] != "#") && ([:find $line ":"] = [:nothing])) do={
                :if ([:find $line "/"] = [:nothing]) do={ :set line ($line . "/32") }
                :if ([:find $src ("|" . $line . "|")] = [:nothing]) do={ :set src ($src . $line . "|") }
                :do {
                    /ip firewall address-list add address=$line list=$list comment=$tag
                    :set added ($added + 1)
                } on-error={}
            }
            :set line ""
        } else={
            :set line ($line . $char)
        }
    }
    :set i ($i + 1)
}

:if (([:len $line] > 0) && ([:pick $line 0 1] != "#") && ([:find $line ":"] = [:nothing])) do={
    :if ([:find $line "/"] = [:nothing]) do={ :set line ($line . "/32") }
    :if ([:find $src ("|" . $line . "|")] = [:nothing]) do={ :set src ($src . $line . "|") }
    :do {
        /ip firewall address-list add address=$line list=$list comment=$tag
        :set added ($added + 1)
    } on-error={}
}

:foreach id in=[/ip firewall address-list find where list=$list and comment=$tag] do={
    :local addr [/ip firewall address-list get $id address]
    :if ([:find $addr "/"] = [:nothing]) do={ :set addr ($addr . "/32") }
    :if ([:find $src ("|" . $addr . "|")] = [:nothing]) do={
        /ip firewall address-list remove $id
        :set removed ($removed + 1)
    }
}

:log warning ("SKIPA sync done: added=" . $added . " removed=" . $removed)
