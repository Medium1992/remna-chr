:local Jc 4
:local Jmin 40
:local Jmax 70
:local TTL 64
:local UDPChecksumMode "calc"
:local DebugIparser false

:local i1 "<b 0xce000000010897a297ecc34cd6dd000044d0ec2e2e1ea2991f467ace4222129b5a098823784694b4897b9986ae0b7280135fa85e196d9ad980b150122129ce2a9379531b0fd3e871ca5fdb883c369832f730e272d7b8b74f393f9f0fa43f11e510ecb2219a52984410c204cf875585340c62238e14ad04dff382f2c200e0ee22fe743b9c6b8b043121c5710ec289f471c91ee414fca8b8be8419ae8ce7ffc53837f6ade262891895f3f4cecd31bc93ac5599e18e4f01b472362b8056c3172b513051f8322d1062997ef4a383b01706598d08d48c221d30e74c7ce000cdad36b706b1bf9b0607c32ec4b3203a4ee21ab64df336212b9758280803fcab14933b0e7ee1e04a7becce3e2633f4852585c567894a5f9efe9706a151b615856647e8b7dba69ab357b3982f554549bef9256111b2d67afde0b496f16962d4957ff654232aa9e845b61463908309cfd9de0a6abf5f425f577d7e5f6440652aa8da5f73588e82e9470f3b21b27b28c649506ae1a7f5f15b876f56abc4615f49911549b9bb39dd804fde182bd2dcec0c33bad9b138ca07d4a4a1650a2c2686acea05727e2a78962a840ae428f55627516e73c83dd8893b02358e81b524b4d99fda6df52b3a8d7a5291326e7ac9d773c5b43b8444554ef5aea104a738ed650aa979674bbed38da58ac29d87c29d387d80b526065baeb073ce65f075ccb56e47533aef357dceaa8293a523c5f6f790be90e4731123d3c6152a70576e90b4ab5bc5ead01576c68ab633ff7d36dcde2a0b2c68897e1acfc4d6483aaaeb635dd63c96b2b6a7a2bfe042f6aed82e5363aa850aace12ee3b1a93f30d8ab9537df483152a5527faca21efc9981b304f11fc95336f5b9637b174c5a0659e2b22e159a9fed4b8e93047371175b1d6d9cc8ab745f3b2281537d1c75fb9451871864efa5d184c38c185fd203de206751b92620f7c369e031d2041e152040920ac2c5ab5340bfc9d0561176abf10a147287ea90758575ac6a9f5ac9f390d0d5b23ee12af583383d994e22c0cf42383834bcd3ada1b3825a0664d8f3fb678261d57601ddf94a8a68a7c273a18c08aa99c7ad8c6c42eab67718843597ec9930457359dfdfbce024afc2dcf9348579a57d8d3490b2fa99f278f1c37d87dad9b221acd575192ffae1784f8e60ec7cee4068b6b988f0433d96d6a1b1865f4e155e9fe020279f434f3bf1bd117b717b92f6cd1cc9bea7d45978bcc3f24bda631a36910110a6ec06da35f8966c9279d130347594f13e9e07514fa370754d1424c0a1545c5070ef9fb2acd14233e8a50bfc5978b5bdf8bc1714731f798d21e2004117c61f2989dd44f0cf027b27d4019e81ed4b5c31db347c4a3a4d85048d7093cf16753d7b0d15e078f5c7a5205dc2f87e330a1f716738dce1c6180e9d02869b5546f1c4d2748f8c90d9693cba4e0079297d22fd61402dea32ff0eb69ebd65a5d0b687d87e3a8b2c42b648aa723c7c7daf37abcc4bb85caea2ee8f55bec20e913b3324ab8f5c3304f820d42ad1b9f2ffc1a3af9927136b4419e1e579ab4c2ae3c776d293d397d575df181e6cae0a4ada5d67ecea171cca3288d57c7bbdaee3befe745fb7d634f70386d873b90c4d6c6596bb65af68f9e5121e67ebf0d89d3c909ceedfb32ce9575a7758ff080724e1ab5d5f43074ecb53a479af21ed03d7b6899c36631c0166f9d47e5e1d4528a5d3d3f744029c4b1c190cbfbad06f5f83f7ad0429fa9a2719c56ffe3783460e166de2d8>"
:local i2 ""
:local i3 ""
:local i4 ""
:local i5 ""

:local IpacketCount 5

:local tohex do={
  :local n $1
  :local h ""
  :while ($n>0) do={
    :local r ($n % 16)
    :set h ([:pick "0123456789abcdef" $r ($r+1)] . $h)
    :set n ($n / 16)
  }
  :return $h
}

:local mac2hex do={
    :local m $1
    :set m ([:pick $m 0 2].[:pick $m 3 5].[:pick $m 6 8].[:pick $m 9 11].[:pick $m 12 14].[:pick $m 15 17])
    :return [:convert transform=lc $m]
}

:local hex16 do={
    :local n [:tonum $1]
    :local hi ($n >> 8)
    :local lo ($n & 255)

    :local digits "0123456789abcdef"

    :local h1 [:pick $digits ($hi >> 4) (($hi >> 4) + 1)]
    :local h2 [:pick $digits ($hi & 15) (($hi & 15) + 1)]
    :local h3 [:pick $digits ($lo >> 4) (($lo >> 4) + 1)]
    :local h4 [:pick $digits ($lo & 15) (($lo & 15) + 1)]

    :return ($h1 . $h2 . $h3 . $h4)
}

:local hex8 do={
    :local n [:tonum $1]
    :local digits "0123456789abcdef"

    :local h1 [:pick $digits ($n >> 4) (($n >> 4) + 1)]
    :local h2 [:pick $digits ($n & 15) (($n & 15) + 1)]

    :return ($h1 . $h2)
}

:local ip2hex do={
    :local ip [:tostr $1]
    :local digits "0123456789abcdef"
    :local out ""

    :local p1 [:find $ip "."]
    :local o1 [:tonum [:pick $ip 0 $p1]]
    :set out ([:pick $digits ($o1 >> 4) (($o1 >> 4)+1)] . [:pick $digits ($o1 & 15) (($o1 & 15)+1)])

    :local p2 [:find $ip "." ($p1 + 1)]
    :local o2 [:tonum [:pick $ip ($p1 + 1) $p2]]
    :set out ($out . [:pick $digits ($o2 >> 4) (($o2 >> 4)+1)] . [:pick $digits ($o2 & 15) (($o2 & 15)+1)])

    :local p3 [:find $ip "." ($p2 + 1)]
    :local o3 [:tonum [:pick $ip ($p2 + 1) $p3]]
    :set out ($out . [:pick $digits ($o3 >> 4) (($o3 >> 4)+1)] . [:pick $digits ($o3 & 15) (($o3 & 15)+1)])

    :local o4 [:tonum [:pick $ip ($p3 + 1) [:len $ip]]]
    :set out ($out . [:pick $digits ($o4 >> 4) (($o4 >> 4)+1)] . [:pick $digits ($o4 & 15) (($o4 & 15)+1)])

    :return $out
}

:local ipchecksum do={
    :local header $1
    :local sum 0

    :for j from=0 to=9 do={
        :local offset ($j * 4)
        :local word [:pick $header $offset ($offset + 4)]
        :local val [:tonum ("0x" . $word)]
        :set sum ($sum + $val)
    }

    :while ($sum > 65535) do={
        :set sum (($sum & 65535) + ($sum >> 16))
    }

    :local checksum (65535 - $sum)

    :local hi ($checksum >> 8)
    :local lo ($checksum & 255)

    :local digits "0123456789abcdef"

    :local h1 [:pick $digits ($hi >> 4) (($hi >> 4) + 1)]
    :local h2 [:pick $digits ($hi & 15) (($hi & 15) + 1)]
    :local h3 [:pick $digits ($lo >> 4) (($lo >> 4) + 1)]
    :local h4 [:pick $digits ($lo & 15) (($lo & 15) + 1)]

    :return ($h1 . $h2 . $h3 . $h4)
}

:local udpchecksum do={
    :local srcHex $1
    :local dstHex $2
    :local udpLenNum $3
    :local udpTmp $4
    :local pay $5

    :local pseudo ($srcHex . $dstHex . "00" . "11" . [$hex16 $udpLenNum])

    :local checkdata ($pseudo . $udpTmp . $pay)

    :if (([:len $checkdata] % 4) != 0) do={
        :set checkdata ($checkdata . "00")
    }

    :local sum 0
    :local wordCount ([:len $checkdata] / 4)
    :for j from=0 to=($wordCount - 1) do={
        :local offset ($j * 4)
        :local word [:pick $checkdata $offset ($offset + 4)]
        :local val [:tonum ("0x" . $word)]
        :set sum ($sum + $val)
    }

    :while ($sum > 65535) do={
        :set sum (($sum & 65535) + ($sum >> 16))
    }

    :local checksum (65535 - $sum)
    :if ($checksum = 0) do={ :set checksum 0 }

    :local hi ($checksum >> 8)
    :local lo ($checksum & 255)
    :local digits "0123456789abcdef"
    :local h1 [:pick $digits ($hi >> 4) (($hi >> 4) + 1)]
    :local h2 [:pick $digits ($hi & 15) (($hi & 15) + 1)]
    :local h3 [:pick $digits ($lo >> 4) (($lo >> 4) + 1)]
    :local h4 [:pick $digits ($lo & 15) (($lo & 15) + 1)]

    :return ($h1 . $h2 . $h3 . $h4)
}

:local randhex do={

    :local bytes $1
    :local out ""
    :local digits "0123456789abcdef"

    :for i from=1 to=$bytes do={

        :local r [:rndnum from=0 to=255]

        :local h1 [:pick $digits ($r >> 4) (($r >> 4) + 1)]
        :local h2 [:pick $digits ($r & 15) (($r & 15) + 1)]

        :set out ($out . $h1 . $h2)
    }

    :return $out
}

:local randdigitshex do={
    :local bytes $1
    :local out ""
    :local digits "0123456789abcdef"
    :for i from=1 to=$bytes do={
        :local n (48 + [:rndnum from=0 to=9])
        :set out ($out . [:pick $digits ($n >> 4) (($n >> 4) + 1)] . [:pick $digits ($n & 15) (($n & 15) + 1)])
    }
    :return $out
}

:local randcharshex do={
    :local bytes $1
    :local out ""
    :local digits "0123456789abcdef"
    :for i from=1 to=$bytes do={
        :local r [:rndnum from=0 to=51]
        :local n 0
        :if ($r < 26) do={
            :set n (97 + $r)
        } else={
            :set n (65 + ($r - 26))
        }
        :set out ($out . [:pick $digits ($n >> 4) (($n >> 4) + 1)] . [:pick $digits ($n & 15) (($n & 15) + 1)])
    }
    :return $out
}

:local timestamphex do={
    :local unix ([:tonsec [:timestamp]] / 1000000000)
    :local digits "0123456789abcdef"
    :local out ""
    :local n (($unix >> 16) & 65535)
    :local hi ($n >> 8)
    :local lo ($n & 255)
    :set out ($out . [:pick $digits ($hi >> 4) (($hi >> 4) + 1)] . [:pick $digits ($hi & 15) (($hi & 15) + 1)] . [:pick $digits ($lo >> 4) (($lo >> 4) + 1)] . [:pick $digits ($lo & 15) (($lo & 15) + 1)])
    :set n ($unix & 65535)
    :set hi ($n >> 8)
    :set lo ($n & 255)
    :set out ($out . [:pick $digits ($hi >> 4) (($hi >> 4) + 1)] . [:pick $digits ($hi & 15) (($hi & 15) + 1)] . [:pick $digits ($lo >> 4) (($lo >> 4) + 1)] . [:pick $digits ($lo & 15) (($lo & 15) + 1)])
    :return $out
}

:local normalizehex do={
    :local value [:tostr $1]
    :if ([:pick $value 0 2] = "0x") do={ :set value [:pick $value 2 [:len $value]] }
    :if ([:pick $value 0 2] = "0X") do={ :set value [:pick $value 2 [:len $value]] }
    :return $value
}

# Собирает IPv4/UDP-пакет из payload-hex и инжектит его.
# do={} не видит внешние :local, поэтому контекст и хелперы передаём аргументами.
:local buildinject do={
    :local partLen ([:len $pay] / 2)
    :local udpLen ($partLen + 8)
    :local ipLen ($udpLen + 20)
    :local ipidHex [$fnHex16 [:rndnum from=0 to=65535]]
    :local udpHeaderTmp ($sPortHex . $dPortHex . [$fnHex16 $udpLen] . "0000")
    :local udpCsum [$fnUdpCsum $sIpHex $dIpHex $udpLen $udpHeaderTmp $pay]
    :if ($csMode = "zero") do={ :set udpCsum "0000" }
    :local udpHeader ($sPortHex . $dPortHex . [$fnHex16 $udpLen] . $udpCsum)
    :local ipHeaderTmp ("4500" . [$fnHex16 $ipLen] . $ipidHex . "0000" . $tHex . "11" . "0000" . $sIpHex . $dIpHex)
    :local ipCsum [$fnIpCsum $ipHeaderTmp]
    :local ipHeader ("4500" . [$fnHex16 $ipLen] . $ipidHex . "0000" . $tHex . "11" . $ipCsum . $sIpHex . $dIpHex)
    :local fullpacket ($ethHdr . $ipHeader . $udpHeader . $pay)
    :log warning ("fullpacket: " . $fullpacket)
    /tool/traffic-generator/inject interface="$outIfName" data=$fullpacket
}

:global Tx
:global Rx
:if ([:typeof $Tx] != "array") do={ :set Tx ({}) }
:if ([:typeof $Rx] != "array") do={ :set Rx ({}) }
/interface wireguard peers
:foreach i in=[find where comment~"BYPASS"] do={
    :local LocalTx [get $i tx]
    :local LocalRx [get $i rx]
    :local LastHandshake [get $i last-handshake]
    :local isDisabled [get $i disabled]
    :if (([:tostr $LastHandshake] = "") or ($LastHandshake > [:totime "3m20s"]) or ($isDisabled = yes)) do={
        :local PeerName [get $i name]
        # Обёртка: сбой одного пира не должен прерывать обработку остальных.
        :do {
        :local Interface [get $i interface]
        :local EndpointAddress [get $i endpoint-address]
        :local EndpointIP ""
        :do {
            :set EndpointIP [:toip $EndpointAddress]
        } on-error={
            :set EndpointIP ""
        }
        :if ([:len [:tostr $EndpointIP]] = 0) do={
            :do {
                :set EndpointIP [:resolve $EndpointAddress]
            } on-error={
                :log error ("Could not resolve endpoint: " . $EndpointAddress)
                :error "resolve failed"
            }
        }

        :local DstPort [get $i current-endpoint-port]
        :if (([:tostr $DstPort] = "") or ($DstPort = 0)) do={
            :set DstPort [get $i endpoint-port]
        }
        :local rndport [:rndnum from=49000 to=59999]
        /interface wireguard set $Interface listen-port=$rndport
        :local SrcPort [/interface wireguard get $Interface listen-port]

        /tool ping address=$EndpointIP count=1 interval=200ms
        :delay 1s
        :local conn [/ip firewall connection find where dst-address="$EndpointIP" and protocol=icmp]
        :if ([:len $conn]=0) do={
            :log error "No WG conntrack entry for $EndpointIP:$DstPort"
            :error "no conntrack"
        }
        :local cid [:pick $conn 0]
        :local srcip [/ip firewall connection get $cid reply-dst-address]

        :local route [/ip route check dst-ip=$EndpointIP once as-value]
        :if ([:len $route]=0) do={
            :log error "Route check failed"
            :error "route check failed"
        }
        :local outIf ($route->"interface")
        :local ifType [/interface get $outIf type]

        :local eth ""
        :local gw ""
        :if ($ifType = "ether" or $ifType = "bridge") do={
            :set gw ($route->"nexthop")
            :local srcmacRaw [/interface get $outIf mac-address]
            :local srcmac [$mac2hex $srcmacRaw]
            :local arpId [/ip arp find where address=$gw and interface=$outIf]
            :if ([:len $arpId] = 0) do={
                /tool ping address=$gw count=1 interval=200ms
                :delay 500ms
                :set arpId [/ip arp find where address=$gw and interface=$outIf]
            }
            :if ([:len $arpId] = 0) do={
                :log error ("No ARP entry for gateway " . $gw . " on " . $outIf)
                :error "no arp"
            }
            :local dstmacRaw [/ip arp get $arpId mac-address]
            :local dstmac [$mac2hex $dstmacRaw]
            :set eth ($dstmac.$srcmac."0800")
        }

        :if ($ifType = "vlan") do={
            :set gw ($route->"nexthop")
            :local srcmacRaw [/interface get $outIf mac-address]
            :local srcmac [$mac2hex $srcmacRaw]
            :local arpId [/ip arp find where address=$gw and interface=$outIf]
            :if ([:len $arpId] = 0) do={
                /tool ping address=$gw count=1 interval=200ms
                :delay 500ms
                :set arpId [/ip arp find where address=$gw and interface=$outIf]
            }
            :if ([:len $arpId] = 0) do={
                :log error ("No ARP entry for gateway " . $gw . " on " . $outIf)
                :error "no arp"
            }
            :local dstmacRaw [/ip arp get $arpId mac-address]
            :local dstmac [$mac2hex $dstmacRaw]
            :local vlanId [/interface/vlan/get $outIf vlan-id]
            :local vlanIdHex [$hex16 $vlanId]
            :set outIf [/interface/vlan/get $outIf interface]
            :set eth ($dstmac.$srcmac."8100".$vlanIdHex."0800")
        }

        :local srcipHex [$ip2hex $srcip]
        :local dstipHex [$ip2hex $EndpointIP]
        :local ttlHex [$hex8 $TTL]

        :local srcPortHex [$hex16 $SrcPort]
        :local dstPortHex [$hex16 $DstPort]

        #Log peer info
        :log warning ("Peer: $PeerName, Interface: $Interface")
        :log warning ("Endpoint Address: $EndpointAddress, Endpoint IP: $EndpointIP")
        :log warning ("Src Port: $SrcPort, Dst Port: $DstPort, Last Handshake: $LastHandshake")
        :log warning ("Last Rx: " . $Rx->[:tostr $i] . ", Current Rx: $LocalRx")
        :log warning ("Last Tx: " . $Tx->[:tostr $i] . ", Current Tx: $LocalTx")

        #Disable peer
        :log warning ("Disable peer: $PeerName")
        set $i disabled=yes  responder=yes
        :delay 100ms

        #Generating spam
        :log warning ("Generating spam")
        :delay 1

        :log warning ("gateway: $gw")
        :log warning ("eth: $eth")
        :log warning ("srcip: $srcip")
        :log warning ("srcipHex: $srcipHex")
        :log warning ("dstip: $EndpointIP")
        :log warning ("dstipHex: $dstipHex")
        :log warning ("outInterface: $outIf")
        :log warning ("I-spec lengths: i1=" . [:len $i1] . ", i2=" . [:len $i2] . ", i3=" . [:len $i3] . ", i4=" . [:len $i4] . ", i5=" . [:len $i5])

        :for packetNo from=1 to=$IpacketCount do={
            :local part ""
            :if ($packetNo = 1) do={ :set part $i1 }
            :if ($packetNo = 2) do={ :set part $i2 }
            :if ($packetNo = 3) do={ :set part $i3 }
            :if ($packetNo = 4) do={ :set part $i4 }
            :if ($packetNo = 5) do={ :set part $i5 }

            :if ($DebugIparser = true) do={
                :log warning ("DBG I" . $packetNo . " raw len=" . [:len $part] . " raw=" . $part)
            }

            :if ([:pick $part 0 2] = "0x") do={ :set part [:pick $part 2 [:len $part]] }
            :if ([:pick $part 0 2] = "0X") do={ :set part [:pick $part 2 [:len $part]] }

            :local nextTag [:find $part "<" 1]
            :if ([:typeof $nextTag] = "nil") do={
                :if ([:pick $part 0 5] = "<b 0x") do={
                    :if ([:pick $part ([:len $part] - 1) [:len $part]] = ">") do={
                        :set part [:pick $part 5 ([:len $part] - 1)]
                    } else={
                        :log error ("I" . $packetNo . " static <b> tag is missing closing >, probably truncated")
                        :set part ""
                    }
                } else={
                    :if ([:pick $part 0 3] = "<b ") do={
                        :if ([:pick $part ([:len $part] - 1) [:len $part]] = ">") do={
                            :set part [:pick $part 3 ([:len $part] - 1)]
                        } else={
                            :log error ("I" . $packetNo . " static <b> tag is missing closing >, probably truncated")
                            :set part ""
                        }
                    }
                }
            }
            :if ([:pick $part 0 1] = "<") do={
                :local spec $part
                :local out ""
                :local pos 0
                :if ($DebugIparser = true) do={
                    :log warning ("DBG I" . $packetNo . " parse spec len=" . [:len $spec] . " spec=" . $spec)
                }

                :if (([:pick $spec 0 5] = "<b 0x") or ([:pick $spec 0 3] = "<b ")) do={
                    :local firstEnd [:find $spec ">"]
                    :if ($DebugIparser = true) do={
                        :log warning ("DBG I" . $packetNo . " firstEnd=" . $firstEnd . " firstPrefix5=" . [:pick $spec 0 5] . " firstPrefix3=" . [:pick $spec 0 3])
                    }
                    :if ([:typeof $firstEnd] = "nil") do={
                        :log error ("I" . $packetNo . " leading <b> tag is missing >: " . $spec)
                        :set spec ""
                    } else={
                        :local firstTag [:pick $spec 1 $firstEnd]
                        :local firstSp [:find $firstTag " "]
                        :if ($DebugIparser = true) do={
                            :log warning ("DBG I" . $packetNo . " firstTag=" . $firstTag . " firstSp=" . $firstSp)
                        }
                        :if ([:typeof $firstSp] != "nil") do={
                            :local firstVal [:pick $firstTag ($firstSp + 1) [:len $firstTag]]
                            :if ([:pick $firstVal 0 2] = "0x") do={ :set firstVal [:pick $firstVal 2 [:len $firstVal]] }
                            :if ([:pick $firstVal 0 2] = "0X") do={ :set firstVal [:pick $firstVal 2 [:len $firstVal]] }
                            :set out ($out . $firstVal)
                            :if ($DebugIparser = true) do={
                                :log warning ("DBG I" . $packetNo . " firstVal len=" . [:len $firstVal] . " outHexLen=" . [:len $out])
                            }
                        }
                        :set pos ($firstEnd + 1)
                        :if ($DebugIparser = true) do={
                            :log warning ("DBG I" . $packetNo . " pos after leading b=" . $pos)
                        }
                    }
                }

                :while ($pos < [:len $spec]) do={
                    :local start $pos
                    :if ([:pick $spec $pos ($pos + 1)] != "<") do={
                        :set start [:find $spec "<" $pos]
                    }
                    :if ($DebugIparser = true) do={
                        :log warning ("DBG I" . $packetNo . " loop pos=" . $pos . " start=" . $start . " specLen=" . [:len $spec])
                    }
                    :if ([:typeof $start] = "nil") do={
                        :set pos [:len $spec]
                    } else={
                        :local end [:find $spec ">" $start]
                        :if ($DebugIparser = true) do={
                            :log warning ("DBG I" . $packetNo . " end=" . $end . " at start=" . $start)
                        }
                        :if ([:typeof $end] = "nil") do={
                            :log error ("I" . $packetNo . " invalid tag, missing >: " . $spec)
                            :set out ""
                            :set pos [:len $spec]
                        } else={
                            :local tag [:pick $spec ($start + 1) $end]
                            :local handled false
                            :if ($DebugIparser = true) do={
                                :log warning ("DBG I" . $packetNo . " tag=[" . $tag . "] len=" . [:len $tag] . " p2=[" . [:pick $tag 0 2] . "] p3=[" . [:pick $tag 0 3] . "]")
                            }

                            :if ([:pick $tag 0 2] = "b ") do={
                                :local val [:pick $tag 2 [:len $tag]]
                                :if ([:pick $val 0 2] = "0x") do={ :set val [:pick $val 2 [:len $val]] }
                                :if ([:pick $val 0 2] = "0X") do={ :set val [:pick $val 2 [:len $val]] }
                                :set out ($out . $val)
                                :set handled true
                                :if ($DebugIparser = true) do={
                                    :log warning ("DBG I" . $packetNo . " handled b valHexLen=" . [:len $val] . " outHexLen=" . [:len $out])
                                }
                            }

                            :if ([:pick $tag 0 2] = "r ") do={
                                :local count [:tonum [:pick $tag 2 [:len $tag]]]
                                :local gen [$randhex $count]
                                :set out ($out . $gen)
                                :set handled true
                                :if ($DebugIparser = true) do={
                                    :log warning ("DBG I" . $packetNo . " handled r count=" . $count . " genHexLen=" . [:len $gen] . " outHexLen=" . [:len $out])
                                }
                            }

                            :if ([:pick $tag 0 3] = "rc ") do={
                                :local count [:tonum [:pick $tag 3 [:len $tag]]]
                                :local gen [$randcharshex $count]
                                :set out ($out . $gen)
                                :set handled true
                                :if ($DebugIparser = true) do={
                                    :log warning ("DBG I" . $packetNo . " handled rc count=" . $count . " genHexLen=" . [:len $gen] . " outHexLen=" . [:len $out])
                                }
                            }

                            :if ([:pick $tag 0 3] = "rd ") do={
                                :local count [:tonum [:pick $tag 3 [:len $tag]]]
                                :local gen [$randdigitshex $count]
                                :set out ($out . $gen)
                                :set handled true
                                :if ($DebugIparser = true) do={
                                    :log warning ("DBG I" . $packetNo . " handled rd count=" . $count . " genHexLen=" . [:len $gen] . " outHexLen=" . [:len $out])
                                }
                            }

                            :if ($tag = "t") do={
                                :local gen [$timestamphex]
                                :set out ($out . $gen)
                                :set handled true
                                :if ($DebugIparser = true) do={
                                    :log warning ("DBG I" . $packetNo . " handled t genHexLen=" . [:len $gen] . " outHexLen=" . [:len $out])
                                }
                            }

                            :if ($handled = false) do={
                                :log error ("I" . $packetNo . " unsupported tag: <" . $tag . ">")
                                :set out ""
                                :set pos [:len $spec]
                            }

                            :set pos ($end + 1)
                            :if ($DebugIparser = true) do={
                                :log warning ("DBG I" . $packetNo . " next pos=" . $pos . " handled=" . $handled . " outHexLen=" . [:len $out])
                            }
                        }
                    }
                }

                :set part $out
                :if ($DebugIparser = true) do={
                    :log warning ("DBG I" . $packetNo . " final partHexLen=" . [:len $part] . " payloadBytes=" . ([:len $part] / 2))
                }
            }

            :if ([:len $part] = 0) do={
                :log warning ("I-packet #" . $packetNo . " skipped: empty")
            }

            :if ([:len $part] > 0) do={
                :if (([:len $part] % 2) != 0) do={
                    :log error ("I" . $packetNo . " UDP payload HEX has odd length: " . [:len $part] . " hex chars")
                    :if ([:len $part] > 16) do={
                        :log error ("I" . $packetNo . " head/tail: " . [:pick $part 0 16] . "..." . [:pick $part ([:len $part] - 16) [:len $part]])
                    } else={
                        :log error ("I" . $packetNo . " value: " . $part)
                    }
                    :set part ""
                } else={
                    :log warning ("I-packet #" . $packetNo . " payload bytes: " . ([:len $part] / 2))
                    $buildinject pay=$part sPortHex=$srcPortHex dPortHex=$dstPortHex \
                        sIpHex=$srcipHex dIpHex=$dstipHex tHex=$ttlHex ethHdr=$eth \
                        csMode=$UDPChecksumMode outIfName=$outIf \
                        fnHex16=$hex16 fnUdpCsum=$udpchecksum fnIpCsum=$ipchecksum
                    :delay 5ms
                }
            }
        }

        :for j from=1 to=$Jc do={
            :local size [:rndnum from=$Jmin to=$Jmax]
            :local part [$randhex $size]
            :log warning ("Junk packet #" . $j . " payload bytes: " . ([:len $part] / 2))
            $buildinject pay=$part sPortHex=$srcPortHex dPortHex=$dstPortHex \
                sIpHex=$srcipHex dIpHex=$dstipHex tHex=$ttlHex ethHdr=$eth \
                csMode=$UDPChecksumMode outIfName=$outIf \
                fnHex16=$hex16 fnUdpCsum=$udpchecksum fnIpCsum=$ipchecksum
            :delay 5ms
        }

        #Enable peer
        :log warning ("Enable peer: $PeerName")
        set $i disabled=no responder=no
        } on-error={
            :log warning ("Skipping peer " . $PeerName . ", see errors above")
            # Страховка: не оставляем пир выключенным, если сбой пришёлся после disable.
            set $i disabled=no responder=no
        }
    }
    :set ($Tx->[:tostr $i]) $LocalTx
    :set ($Rx->[:tostr $i]) $LocalRx
}
