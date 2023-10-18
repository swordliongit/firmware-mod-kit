#!/bin/sh

#shell will run when wan interface create
local cmd="$1"
local vlan_id="$2"
local wan_mode="$3"
local service_mode="$4"
local tr069_protocol=`echo $service_mode | grep TR069`
local voip_protocol=`echo $service_mode | grep VOIP`

