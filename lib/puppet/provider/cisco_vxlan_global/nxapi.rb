# The NXAPI provider for cisco vxlan global.
#
# November 2015
#
# Copyright (c) 2014-2015 Cisco and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'cisco_node_utils' if Puppet.features.cisco_node_utils?
begin
  require 'puppet_x/cisco/autogen'
rescue LoadError # seen on master, not on agent
  # See longstanding Puppet issues #4248, #7316, #14073, #14149, etc. Ugh.
  require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..',
                                     'puppet_x', 'cisco', 'autogen.rb'))
end

Puppet::Type.type(:cisco_vxlan_global).provide(:nxapi) do
  desc 'The nxapi provider.'

  confine feature: :cisco_node_utils
  defaultfor operatingsystem: :nexus

  mk_resource_methods

  VXLAN_GLOBAL_PROPS = [
    :dup_host_ip_addr_detection_host_moves,
    :dup_host_ip_addr_detection_timeout,
    :anycast_gateway_mac,
    :dup_host_mac_detection_host_moves,
    :dup_host_mac_detection_timeout
  ]

  PuppetX::Cisco::AutoGen.mk_puppet_methods(:non_bool, self, '@vxlan_global',
                                            VXLAN_GLOBAL_PROPS)

  def initialize(value={})
    super(value)
    @vxlan_global = Cisco::VxlanGlobal.new if Cisco::VxlanGlobal.enabled
    @property_flush = {}
  end

  def self.properties_get(vxlan_global)
    current_state = {
      name:   'default',
      ensure: :present,
    }

    # Call node_utils getter for each property
    VXLAN_GLOBAL_PROPS.each do |prop|
      current_state[prop] = vxlan_global.send(prop)
    end
    new(current_state)
  end # self.properties_get

  def self.instances
    vxlan_globals = []
    return vxlan_globals unless Cisco::VxlanGlobal.enabled

    vxlan_global = Cisco::VxlanGlobal.new

    vxlan_globals << properties_get(vxlan_global)
    vxlan_globals
  end # self.instances

  def self.prefetch(resources)
    resources.values.first.provider = instances.first unless instances.first.nil?
  end

  def exists?
    (@property_hash[:ensure] == :present)
  end

  def create
    @property_flush[:ensure] = :present
  end

  def destroy
    @property_flush[:ensure] = :absent
  end

  def instance_name
    vxlan_global
  end

  def properties_set(new_vxlan_global=false)
    VXLAN_GLOBAL_PROPS.each do |prop|
      next unless @resource[prop]
      send("#{prop}=", @resource[prop]) if new_vxlan_global
      unless @property_flush[prop].nil?
        @vxlan_global.send("#{prop}=", @property_flush[prop]) if
          @vxlan_global.respond_to?("#{prop}=")
      end
    end
  end

  def flush
    if @property_flush[:ensure] == :absent
      @vxlan_global.disable
      @vxlan_global = nil
    else
      # Create/Update
      if @vxlan_global.nil?
        new_vxlan_global = true
        @vxlan_global = Cisco::VxlanGlobal.new
      end
      properties_set(new_vxlan_global)
    end
    puts_config
  end

  def puts_config
    return if @vxlan_global.nil?

    # Dump all current properties for vxlan_global
    current = sprintf("\n%30s: %s", 'vxlan_global', instance_name)
    VXLAN_GLOBAL_PROPS.each do |prop|
      current.concat(sprintf("\n%30s: %s", prop, @vxlan_global.send(prop)))
    end
    debug current
  end # puts_config
end # Puppet::Type
