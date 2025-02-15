--[[
LuCI - Configuration Bind Interface

Description:
Offers an interface for binding configuration values to certain
data types. Supports value and range validation and basic dependencies.

FileId:
$Id: cbi.lua 6821 2011-01-29 17:54:00Z jow $

License:
Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

]]--
module("luci.cbi", package.seeall)

require("luci.template")
local util = require("luci.util")
require("luci.http")


--local event      = require "luci.sys.event"
local fs         = require("nixio.fs")
local uci        = require("luci.model.uci")
local datatypes  = require("luci.cbi.datatypes")
local class      = util.class
local instanceof = util.instanceof

FORM_NODATA  =  0
FORM_PROCEED =  0
FORM_VALID   =  1
FORM_DONE	 =  1
FORM_INVALID = -1
FORM_CHANGED =  2
FORM_SKIP    =  4

AUTO = true

CREATE_PREFIX = "cbi.cts."
REMOVE_PREFIX = "cbi.rts."
RESORT_PREFIX = "cbi.sts."
FEXIST_PREFIX = "cbi.cbe."

--[[
	get the atrribute of parament 
	1. file : config file name
           section  : section name
	   option   : option name
	return :
		4: only read
		2: only write
		6: read/write 
--]]
function para_attribute_get(file,section,option)
	local parattr = 6
	local parastr = nil
	local cmd = nil
	
	if not file or not section or not option then
		return parattr
	end
	
	
	-- get attibute value by section
	cmd = string.format("uci_attribute get %s.%s rw",file,section)
	local parastr= util.exec(cmd)
	-- test igmp
	if parastr then
	   -- read only
	   if tonumber(parastr) == 0 then  
	   	parattr = 4
	   end	   
	end
	
	if parattr ~= 4 then
		-- get attibute value by option
		cmd = string.format("uci_attribute get %s.%s.%s rw",file,section,option)	
		local parastr= util.exec(cmd)
		if parastr then
		   -- read only
		   if tonumber(parastr) == 0 then  
		   	parattr = 4
		   end	   
		end	
	end

	return parattr
end
-- Loads a CBI map from given file, creating an environment and returns it
function load(cbimap, ...)
	local fs   = require "nixio.fs"
	local i18n = require "luci.i18n"
	require("luci.config")
	require("luci.util")

	local upldir = "/lib/uci/upload/"
	local cbidir = luci.util.libpath() .. "/model/cbi/"
	local func, err

	if fs.access(cbidir..cbimap..".lua") then
		func, err = loadfile(cbidir..cbimap..".lua")
	elseif fs.access(cbimap) then
		func, err = loadfile(cbimap)
	else
		func, err = nil, "Model '" .. cbimap .. "' not found!"
	end

	assert(func, err)

	luci.i18n.loadc("base")

	local env = {
		translate=i18n.translate,
		translatef=i18n.translatef,
	 	arg={...}
	}

	setfenv(func, setmetatable(env, {__index =
		function(tbl, key)
			return rawget(tbl, key) or _M[key] or _G[key]
		end}))

	local maps       = { func() }
	local uploads    = { }
	local has_upload = false

	for i, map in ipairs(maps) do
		if not instanceof(map, Node) then
			error("CBI map returns no valid map object!")
			return nil
		else
			map:prepare()
			if map.upload_fields then
				has_upload = true
				for _, field in ipairs(map.upload_fields) do
					uploads[
						field.config .. '.' ..
						field.section.sectiontype .. '.' ..
						field.option
					] = true
				end
			end
		end
	end

	if has_upload then
		local uci = luci.model.uci.cursor()
		local prm = luci.http.context.request.message.params
		local fd, cbid

		luci.http.setfilehandler(
			function( field, chunk, eof )
				if not field then return end
				if field.name and not cbid then
					local c, s, o = field.name:gmatch(
						"cbid%.([^%.]+)%.([^%.]+)%.([^%.]+)"
					)()

					if c and s and o then
						local t = uci:get( c, s )
						if t and uploads[c.."."..t.."."..o] then
					--		local path = upldir .. field.name
							local pathcfg = uci:get(c,s,o)
							local path = upldir .. field.name
							path= pathcfg or path
							fd = io.open(path, "w")
							if fd then
								cbid = field.name
								prm[cbid] = path
							end
						end
					end
				end

				if field.name == cbid and fd then
					fd:write(chunk)
				end

				if eof and fd then
					fd:close()
					fd   = nil
					cbid = nil
				end
			end
		)
	end

	return maps
end


-- Node pseudo abstract class
Node = class()

function Node.__init__(self, title, description)
	self.children = {}
	self.title = title or ""
	self.description = description or ""
	self.template = "cbi/node"
end

-- hook helper
function Node._run_hook(self, hook)
	if type(self[hook]) == "function" then
		return self[hook](self)
	end
end

function Node._run_hooks(self, ...)
	local f
	local r = false
	for _, f in ipairs(arg) do
		if type(self[f]) == "function" then
			self[f](self)
			r = true
		end
	end
	return r
end

-- Prepare nodes
function Node.prepare(self, ...)
	for k, child in ipairs(self.children) do
		child:prepare(...)
	end
end

-- Append child nodes
function Node.append(self, obj)
	table.insert(self.children, obj)
end

-- Parse this node and its children
function Node.parse(self, ...)
	for k, child in ipairs(self.children) do
		child:parse(...)
	end
end

-- Render this node
function Node.render(self, scope)
	scope = scope or {}
	scope.self = self

	luci.template.render(self.template, scope)
end

-- Render the children
function Node.render_children(self, ...)
	for k, node in ipairs(self.children) do
		node:render(...)
	end
end


--[[
A simple template element
]]--
Template = class(Node)

function Template.__init__(self, template)
	Node.__init__(self)
	self.template = template
end

function Template.render(self)
	luci.template.render(self.template, {self=self})
end

function Template.parse(self, readinput)
	self.readinput = (readinput ~= false)
	return Map.formvalue(self, "cbi.submit") and FORM_DONE or FORM_NODATA
end


--[[
Map - A map describing a configuration file
]]--
Map = class(Node)

function Map.__init__(self, config, ...)
	Node.__init__(self, ...)

	self.config = config
	self.parsechain = {self.config}
	self.template = "cbi/map"
	self.apply_on_parse = nil
	self.readinput = true
	self.proceed = false
	self.flow = {}
	--//added by chenfei
	self.pageqosaction = false
	self.pagewlanaction = false
	self.pageurlaction = false
	self.pageadminaction = false
	self.pagelanaction = false
	--//
	--//added by hj
	self.pagemacaction = false
	self.pageipportaction = false
	self.pagebuttonaction = false
	--//
	self.apply_before_commit = false --wxb

	self.uci = uci.cursor()
	self.save = true

	self.changed = false

	if not self.uci:load(self.config) then
		error("Unable to read UCI data: " .. self.config)
	end
end

function Map.formvalue(self, key)
	return self.readinput and luci.http.formvalue(key)
end

function Map.formvaluetable(self, key)
	return self.readinput and luci.http.formvaluetable(key) or {}
end

function Map.get_scheme(self, sectiontype, option)
	if not option then
		return self.scheme and self.scheme.sections[sectiontype]
	else
		return self.scheme and self.scheme.variables[sectiontype]
		 and self.scheme.variables[sectiontype][option]
	end
end

function Map.submitstate(self)
	return self:formvalue("cbi.submit")
end

-- Chain foreign config
function Map.chain(self, config)
	table.insert(self.parsechain, config)
end

function Map.state_handler(self, state)
	return state
end

-- Use optimized UCI writing
function Map.parse(self, readinput, ...)
	self.readinput = (readinput ~= false)
	self:_run_hooks("on_parse")

	if self:formvalue("cbi.skip") then
		self.state = FORM_SKIP
		return self:state_handler(self.state)
	end

	Node.parse(self, ...)

	if self.save then
		self:_run_hooks("on_save", "on_before_save")
		for i, config in ipairs(self.parsechain) do
			self.uci:save(config)
		end
		self:_run_hooks("on_after_save")
		if self:submitstate() and ((not self.proceed and self.flow.autoapply) or luci.http.formvalue("cbi.apply")) then
			if self.apply_before_commit then
				self:_run_hooks("on_before_apply")
				if self.apply_on_parse then
					self.uci:apply(self.parsechain)
					self:_run_hooks("on_apply", "on_after_apply")
				else
					-- This is evaluated by the dispatcher and delegated to the
					-- template which in turn fires XHR to perform the actual
					-- apply actions.
					self.apply_needed = true
				end
			--[[
				self:_run_hooks("on_before_commit")
				for i, config in ipairs(self.parsechain) do
					self.uci:commit(config)

					-- Refresh data because commit changes section names
					self.uci:load(config)
				end
				self:_run_hooks("on_commit", "on_after_commit")
			]]--
			else				
				self:_run_hooks("on_before_commit")
				for i, config in ipairs(self.parsechain) do
					self.uci:commit(config)

					-- Refresh data because commit changes section names
					self.uci:load(config)
				end
				self:_run_hooks("on_commit", "on_after_commit", "on_before_apply")
				if self.apply_on_parse then
					self.uci:apply(self.parsechain)
					self:_run_hooks("on_apply", "on_after_apply")
				else
					-- This is evaluated by the dispatcher and delegated to the
					-- template which in turn fires XHR to perform the actual
					-- apply actions.
					self.apply_needed = true
				end
			end
			-- Reparse sections
			Node.parse(self, true)

		end
		
		if not  self.apply_before_commit then
			for i, config in ipairs(self.parsechain) do
				self.uci:unload(config)
			end
		end
		if type(self.commit_handler) == "function" then
			self:commit_handler(self:submitstate())
		end
	end

	if self:submitstate() then
		if not self.save then
			self.state = FORM_INVALID
		elseif self.proceed then
			self.state = FORM_PROCEED
		else
			self.state = self.changed and FORM_CHANGED or FORM_VALID
		end
	else
		self.state = FORM_NODATA
	end

	return self:state_handler(self.state)
end

function Map.render(self, ...)
	self:_run_hooks("on_init")
	Node.render(self, ...)
end

-- Creates a child section
function Map.section(self, class, ...)
	if instanceof(class, AbstractSection) then
		local obj  = class(self, ...)
		self:append(obj)
		return obj
	else
		error("class must be a descendent of AbstractSection")
	end
end

-- UCI add
function Map.add(self, sectiontype)
	return self.uci:add(self.config, sectiontype)
end

-- UCI set
function Map.set(self, section, option, value)
	if type(value) ~= "table" or #value > 0 then
		if option then
			return self.uci:set(self.config, section, option, value)
		else
			return self.uci:set(self.config, section, value)
		end
	else
		return Map.del(self, section, option)
	end
end

-- UCI del
function Map.del(self, section, option)
	if option then
		return self.uci:delete(self.config, section, option)
	else
		return self.uci:delete(self.config, section)
	end
end

-- UCI get
function Map.get(self, section, option)
	if not section then
		return self.uci:get_all(self.config)
	elseif option then
		return self.uci:get(self.config, section, option)
	else
		return self.uci:get_all(self.config, section)
	end
end

--[[
Compound - Container
]]--
Compound = class(Node)

function Compound.__init__(self, ...)
	Node.__init__(self)
	self.template = "cbi/compound"
	self.children = {...}
end

function Compound.populate_delegator(self, delegator)
	for _, v in ipairs(self.children) do
		v.delegator = delegator
	end
end

function Compound.parse(self, ...)
	local cstate, state = 0

	for k, child in ipairs(self.children) do
		cstate = child:parse(...)
		state = (not state or cstate < state) and cstate or state
	end

	return state
end


--[[
Delegator - Node controller
]]--
Delegator = class(Node)
function Delegator.__init__(self, ...)
	Node.__init__(self, ...)
	self.nodes = {}
	self.defaultpath = {}
	self.pageaction = false
	self.readinput = true
	self.allow_reset = false
	self.allow_cancel = false
	self.allow_back = false
	self.allow_finish = false
	self.template = "cbi/delegator"
end

function Delegator.set(self, name, node)
	assert(not self.nodes[name], "Duplicate entry")

	self.nodes[name] = node
end

function Delegator.add(self, name, node)
	node = self:set(name, node)
	self.defaultpath[#self.defaultpath+1] = name
end

function Delegator.insert_after(self, name, after)
	local n = #self.chain + 1
	for k, v in ipairs(self.chain) do
		if v == after then
			n = k + 1
			break
		end
	end
	table.insert(self.chain, n, name)
end

function Delegator.set_route(self, ...)
	local n, chain, route = 0, self.chain, {...}
	for i = 1, #chain do
		if chain[i] == self.current then
			n = i
			break
		end
	end
	for i = 1, #route do
		n = n + 1
		chain[n] = route[i]
	end
	for i = n + 1, #chain do
		chain[i] = nil
	end
end

function Delegator.get(self, name)
	local node = self.nodes[name]

	if type(node) == "string" then
		node = load(node, name)
	end

	if type(node) == "table" and getmetatable(node) == nil then
		node = Compound(unpack(node))
	end

	return node
end

function Delegator.parse(self, ...)
	if self.allow_cancel and Map.formvalue(self, "cbi.cancel") then
		if self:_run_hooks("on_cancel") then
			return FORM_DONE
		end
	end

	if not Map.formvalue(self, "cbi.delg.current") then
		self:_run_hooks("on_init")
	end

	local newcurrent
	self.chain = self.chain or self:get_chain()
	self.current = self.current or self:get_active()
	self.active = self.active or self:get(self.current)
	assert(self.active, "Invalid state")

	local stat = FORM_DONE
	if type(self.active) ~= "function" then
		self.active:populate_delegator(self)
		stat = self.active:parse()
	else
		self:active()
	end

	if stat > FORM_PROCEED then
		if Map.formvalue(self, "cbi.delg.back") then
			newcurrent = self:get_prev(self.current)
		else
			newcurrent = self:get_next(self.current)
		end
	elseif stat < FORM_PROCEED then
		return stat
	end


	if not Map.formvalue(self, "cbi.submit") then
		return FORM_NODATA
	elseif stat > FORM_PROCEED
	and (not newcurrent or not self:get(newcurrent)) then
		return self:_run_hook("on_done") or FORM_DONE
	else
		self.current = newcurrent or self.current
		self.active = self:get(self.current)
		if type(self.active) ~= "function" then
			self.active:populate_delegator(self)
			local stat = self.active:parse(false)
			if stat == FORM_SKIP then
				return self:parse(...)
			else
				return FORM_PROCEED
			end
		else
			return self:parse(...)
		end
	end
end

function Delegator.get_next(self, state)
	for k, v in ipairs(self.chain) do
		if v == state then
			return self.chain[k+1]
		end
	end
end

function Delegator.get_prev(self, state)
	for k, v in ipairs(self.chain) do
		if v == state then
			return self.chain[k-1]
		end
	end
end

function Delegator.get_chain(self)
	local x = Map.formvalue(self, "cbi.delg.path") or self.defaultpath
	return type(x) == "table" and x or {x}
end

function Delegator.get_active(self)
	return Map.formvalue(self, "cbi.delg.current") or self.chain[1]
end

--[[
Page - A simple node
]]--

Page = class(Node)
Page.__init__ = Node.__init__
Page.parse    = function() end


--[[
SimpleForm - A Simple non-UCI form
]]--
SimpleForm = class(Node)

function SimpleForm.__init__(self, config, title, description, data)
	Node.__init__(self, title, description)
	self.config = config
	self.data = data or {}
	self.template = "cbi/simpleform"
	self.dorender = true
	self.pageaction = false
	self.readinput = true
end

SimpleForm.formvalue = Map.formvalue
SimpleForm.formvaluetable = Map.formvaluetable

function SimpleForm.parse(self, readinput, ...)
	self.readinput = (readinput ~= false)

	if self:formvalue("cbi.skip") then
		return FORM_SKIP
	end

	if self:formvalue("cbi.cancel") and self:_run_hooks("on_cancel") then
		return FORM_DONE
	end

	if self:submitstate() then
		Node.parse(self, 1, ...)
	end

	local valid = true
	for k, j in ipairs(self.children) do
		for i, v in ipairs(j.children) do
			valid = valid
			 and (not v.tag_missing or not v.tag_missing[1])
			 and (not v.tag_invalid or not v.tag_invalid[1])
			 and (not v.error)
		end
	end

	local state =
		not self:submitstate() and FORM_NODATA
		or valid and FORM_VALID
		or FORM_INVALID

	self.dorender = not self.handle
	if self.handle then
		local nrender, nstate = self:handle(state, self.data)
		self.dorender = self.dorender or (nrender ~= false)
		state = nstate or state
	end
	return state
end

function SimpleForm.render(self, ...)
	if self.dorender then
		Node.render(self, ...)
	end
end

function SimpleForm.submitstate(self)
	return self:formvalue("cbi.submit")
end

function SimpleForm.section(self, class, ...)
	if instanceof(class, AbstractSection) then
		local obj  = class(self, ...)
		self:append(obj)
		return obj
	else
		error("class must be a descendent of AbstractSection")
	end
end

-- Creates a child field
function SimpleForm.field(self, class, ...)
	local section
	for k, v in ipairs(self.children) do
		if instanceof(v, SimpleSection) then
			section = v
			break
		end
	end
	if not section then
		section = self:section(SimpleSection)
	end

	if instanceof(class, AbstractValue) then
		local obj  = class(self, section, ...)
		obj.track_missing = true
		section:append(obj)
		return obj
	else
		error("class must be a descendent of AbstractValue")
	end
end

function SimpleForm.set(self, section, option, value)
	self.data[option] = value
end


function SimpleForm.del(self, section, option)
	self.data[option] = nil
end


function SimpleForm.get(self, section, option)
	return self.data[option]
end


function SimpleForm.get_scheme()
	return nil
end


Form = class(SimpleForm)

function Form.__init__(self, ...)
	SimpleForm.__init__(self, ...)
	self.embedded = true
end


--[[
AbstractSection
]]--
AbstractSection = class(Node)

function AbstractSection.__init__(self, map, sectiontype, ...)
	Node.__init__(self, ...)
	self.sectiontype = sectiontype
	self.map = map
	self.config = map.config
	self.optionals = {}
	self.defaults = {}
	self.fields = {}
	self.tag_error = {}
	self.tag_invalid = {}
	self.tag_deperror = {}
	self.changed = false

	self.optional = true
	self.addremove = false
	self.dynamic = false
end

-- Define a tab for the section
function AbstractSection.tab(self, tab, title, desc)
	self.tabs      = self.tabs      or { }
	self.tab_names = self.tab_names or { }

	self.tab_names[#self.tab_names+1] = tab
	self.tabs[tab] = {
		title       = title,
		description = desc,
		childs      = { }
	}
end

-- Check whether the section has tabs
function AbstractSection.has_tabs(self)
	return (self.tabs ~= nil) and (next(self.tabs) ~= nil)
end

-- Appends a new option
function AbstractSection.option(self, class, option, ...)
	if instanceof(class, AbstractValue) then
		local obj  = class(self.map, self, option, ...)
		self:append(obj)
		self.fields[option] = obj
		return obj
	elseif class == true then
		error("No valid class was given and autodetection failed.")
	else
		error("class must be a descendant of AbstractValue")
	end
end

-- Appends a new tabbed option
function AbstractSection.taboption(self, tab, ...)

	assert(tab and self.tabs and self.tabs[tab],
		"Cannot assign option to not existing tab %q" % tostring(tab))

	local l = self.tabs[tab].childs
	local o = AbstractSection.option(self, ...)

	if o then l[#l+1] = o end

	return o
end

-- Render a single tab
function AbstractSection.render_tab(self, tab, ...)

	assert(tab and self.tabs and self.tabs[tab],
		"Cannot render not existing tab %q" % tostring(tab))

	for _, node in ipairs(self.tabs[tab].childs) do
		node:render(...)
	end
end

-- Parse optional options
function AbstractSection.parse_optionals(self, section)
	if not self.optional then
		return
	end

	self.optionals[section] = {}

	local field = self.map:formvalue("cbi.opt."..self.config.."."..section)
	for k,v in ipairs(self.children) do
		if v.optional and not v:cfgvalue(section) and not self:has_tabs() then
			if field == v.option then
				field = nil
				self.map.proceed = true
			else
				table.insert(self.optionals[section], v)
			end
		end
	end

	if field and #field > 0 and self.dynamic then
		self:add_dynamic(field)
	end
end

-- Add a dynamic option
function AbstractSection.add_dynamic(self, field, optional)
	local o = self:option(Value, field, field)
	o.optional = optional
end
-- wxb add
function AbstractSection.formvalue(self,section,option)
 	local formval = self.map:formvalue("cbid."..self.map.config.."."..section.."."..option)
 	return formval
end
function AbstractSection.formvaluetable(self,section)
	local form = self.map:formvaluetable( "cbid."..self.map.config.."."..section)
	local arr = {}
	
	for k,v in pairs(form) do
		arr[k] = v
	end
	return arr
end
-- Parse all dynamic options
function AbstractSection.parse_dynamic(self, section)
	if not self.dynamic then
		return
	end

	local arr  = luci.util.clone(self:cfgvalue(section))
	local form = self.map:formvaluetable("cbid."..self.config.."."..section)
	for k, v in pairs(form) do
		arr[k] = v
	end

	for key,val in pairs(arr) do
		local create = true

		for i,c in ipairs(self.children) do
			if c.option == key then
				create = false
			end
		end

		if create and key:sub(1, 1) ~= "." then
			self.map.proceed = true
			self:add_dynamic(key, true)
		end
	end
end

-- Returns the section's UCI table
function AbstractSection.cfgvalue(self, section)
	return self.map:get(section)
end

-- Push events
function AbstractSection.push_events(self)
	--luci.util.append(self.map.events, self.events)
	self.map.changed = true
end

-- Removes the section
function AbstractSection.remove(self, section)
	self.map.proceed = true
	return self.map:del(section)
end

-- Creates the section
function AbstractSection.create(self, section)
	local stat

	if section then
		stat = section:match("^[%w_]+$") and self.map:set(section, nil, self.sectiontype)
	else
		section = self.map:add(self.sectiontype)
		stat = section
	end

	if stat then
		for k,v in pairs(self.children) do
			if v.default then
				self.map:set(section, v.option, v.default)
			end
		end

		for k,v in pairs(self.defaults) do
			self.map:set(section, k, v)
		end
	end

	self.map.proceed = true

	return stat
end


SimpleSection = class(AbstractSection)

function SimpleSection.__init__(self, form, ...)
	AbstractSection.__init__(self, form, nil, ...)
	self.template = "cbi/nullsection"
end


Table = class(AbstractSection)

function Table.__init__(self, form, data, ...)
	local datasource = {}
	local tself = self
	datasource.config = "table"
	self.data = data or {}

	datasource.formvalue = Map.formvalue
	datasource.formvaluetable = Map.formvaluetable
	datasource.readinput = true

	function datasource.get(self, section, option)
		return tself.data[section] and tself.data[section][option]
	end

	function datasource.submitstate(self)
		return Map.formvalue(self, "cbi.submit")
	end

	function datasource.del(...)
		return true
	end

	function datasource.get_scheme()
		return nil
	end

	AbstractSection.__init__(self, datasource, "table", ...)
	self.template = "cbi/tblsection_tb"
	self.rowcolors = true
	self.anonymous = true
end

function Table.parse(self, readinput)
	self.map.readinput = (readinput ~= false)
	for i, k in ipairs(self:cfgsections()) do
		if self.map:submitstate() then
			Node.parse(self, k)
		end
	end
end

function Table.cfgsections(self)
	local sections = {}

	for i, v in luci.util.kspairs(self.data) do
		table.insert(sections, i)
	end

	return sections
end

function Table.update(self, data)
	self.data = data
end

--[[
NamedSection - A fixed configuration section defined by its name
]]--
NamedSection = class(AbstractSection)

function NamedSection.__init__(self, map, section, stype, ...)
	AbstractSection.__init__(self, map, stype, ...)

	-- Defaults
	self.addremove = false
	self.template = "cbi/nsection"
	self.section = section
end

function NamedSection.parse(self, novld)
	local s = self.section
	local active = self:cfgvalue(s)

	if self.addremove then
		local path = self.config.."."..s
		if active then -- Remove the section
			if self.map:formvalue("cbi.rns."..path) and self:remove(s) then
				self:push_events()
				return
			end
		else           -- Create and apply default values
			if self.map:formvalue("cbi.cns."..path) then
				self:create(s)
				return
			end
		end
	end

	if active then
		AbstractSection.parse_dynamic(self, s)
		if self.map:submitstate() then
			Node.parse(self, s)
		end
		AbstractSection.parse_optionals(self, s)

		if self.changed then
			self:push_events()
		end
	end
end


--[[
TypedSection - A (set of) configuration section(s) defined by the type
	addremove: 	Defines whether the user can add/remove sections of this type
	anonymous:  Allow creating anonymous sections
	validate: 	a validation function returning nil if the section is invalid
]]--
TypedSection = class(AbstractSection)

function TypedSection.__init__(self, map, type, ...)
	AbstractSection.__init__(self, map, type, ...)

	self.template = "cbi/tsection"
	self.deps = {}
	self.anonymous = false
end

-- Return all matching UCI sections for this TypedSection
function TypedSection.cfgsections(self)
	local sections = {}
	self.map.uci:foreach(self.map.config, self.sectiontype,
		function (section)
			if self:checkscope(section[".name"]) then
				table.insert(sections, section[".name"])
			end
		end)

	return sections
end

-- Limits scope to sections that have certain option => value pairs
function TypedSection.depends(self, option, value)
	table.insert(self.deps, {option=option, value=value})
end

function TypedSection.parse(self, novld)
	if self.addremove then
		-- Remove
		local crval = REMOVE_PREFIX .. self.config
		local name = self.map:formvaluetable(crval)
		for k,v in pairs(name) do
			if k:sub(-2) == ".x" then
				k = k:sub(1, #k - 2)
			end
			if self:cfgvalue(k) and self:checkscope(k) then
				self:remove(k)
			end
		end
	end

	local co
	for i, k in ipairs(self:cfgsections()) do
		AbstractSection.parse_dynamic(self, k)
		if self.map:submitstate() then
			Node.parse(self, k, novld)
		end
		AbstractSection.parse_optionals(self, k)
	end

	if self.addremove then
		-- Create
		local created
		local crval = CREATE_PREFIX .. self.config .. "." .. self.sectiontype
		local name  = self.map:formvalue(crval)
		if self.anonymous then
			if name then
				created = self:create()
			end
		else
			if name then
				-- Ignore if it already exists
				if self:cfgvalue(name) then
					name = nil;
				end

				name = self:checkscope(name)

				if not name then
					self.err_invalid = true
				end

				if name and #name > 0 then
					created = self:create(name) and name
					if not created then
						self.invalid_cts = true
					end
				end
			end
		end

		if created then
			AbstractSection.parse_optionals(self, created)
		end
	end

	if self.sortable then
		local stval = RESORT_PREFIX .. self.config .. "." .. self.sectiontype
		local order = self.map:formvalue(stval)
		if order and #order > 0 then
			local sid
			local num = 0
			for sid in util.imatch(order) do
				self.map.uci:reorder(self.config, sid, num)
				num = num + 1
			end
			self.changed = (num > 0)
		end
	end

	if created or self.changed then
		self:push_events()
	end
end

-- Verifies scope of sections
function TypedSection.checkscope(self, section)
	-- Check if we are not excluded
	if self.filter and not self:filter(section) then
		return nil
	end

	-- Check if at least one dependency is met
	if #self.deps > 0 and self:cfgvalue(section) then
		local stat = false

		for k, v in ipairs(self.deps) do
			if self:cfgvalue(section)[v.option] == v.value then
				stat = true
			end
		end

		if not stat then
			return nil
		end
	end

	return self:validate(section)
end


-- Dummy validate function
function TypedSection.validate(self, section)
	return section
end


--[[
AbstractValue - An abstract Value Type
	null:		Value can be empty
	valid:		A function returning the value if it is valid otherwise nil
	depends:	A table of option => value pairs of which one must be true
	default:	The default value
	size:		The size of the input fields
	rmempty:	Unset value if empty
	optional:	This value is optional (see AbstractSection.optionals)
]]--
AbstractValue = class(Node)

function AbstractValue.__init__(self, map, section, option, ...)
	Node.__init__(self, ...)
	self.section = section
	self.option  = option
	self.map     = map
	self.config  = map.config
	self.tag_invalid = {}
	self.tag_missing = {}
	self.tag_reqerror = {}
	self.tag_error = {}
	self.deps = {}
	self.subdeps = {}
	--self.cast = "string"

	self.track_missing = false
	self.rmempty   = true
	self.default   = nil
	self.size      = nil
	self.optional  = false
end

function AbstractValue.prepare(self)
	self.cast = self.cast or "string"
end

-- Add a dependencie to another section field
function AbstractValue.depends(self, field, value)
	local deps
	if type(field) == "string" then
		deps = {}
	 	deps[field] = value
	else
		deps = field
	end

	table.insert(self.deps, {deps=deps, add=""})
end

-- Generates the unique CBID
function AbstractValue.cbid(self, section)
	return "cbid."..self.map.config.."."..section.."."..self.option
end

-- Return whether this object should be created
function AbstractValue.formcreated(self, section)
	local key = "cbi.opt."..self.config.."."..section
	return (self.map:formvalue(key) == self.option)
end

-- Returns the formvalue for this object
function AbstractValue.formvalue(self, section)
	return self.map:formvalue(self:cbid(section))
end

function AbstractValue.additional(self, value)
	self.optional = value
end

function AbstractValue.mandatory(self, value)
	self.rmempty = not value
end

function AbstractValue.add_error(self, section, type, msg)
	self.error = self.error or { }
	self.error[section] = msg or type

	self.section.error = self.section.error or { }
	self.section.error[section] = self.section.error[section] or { }
	table.insert(self.section.error[section], msg or type)

	if type == "invalid" then
		self.tag_invalid[section] = true
	elseif type == "missing" then
		self.tag_missing[section] = true
	end

	self.tag_error[section] = true
	self.map.save = false
end

function AbstractValue.parse(self, section, novld)

	-- get the parament attribute and if only read, don't parse to uci section		
	local readwrite = para_attribute_get(self.map.config, section,self.option)
	if readwrite == 4 then
		return 
	end

	local fvalue = self:formvalue(section)
	local cvalue = self:cfgvalue(section)

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		local equal = #fvalue == #cvalue
		if equal then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					equal = false
				end
			end
		end
		if equal then
			fvalue = cvalue
		end
	end

	if fvalue and #fvalue > 0 then -- If we have a form value, write it to UCI
		local val_err
		fvalue, val_err = self:validate(fvalue, section)
		fvalue = self:transform(fvalue)

		if not fvalue and not novld then
			self:add_error(section, "invalid", val_err)
		end

		if fvalue and (self.forcewrite or not (fvalue == cvalue)) then
			if self:write(section, fvalue) then
				-- Push events
				self.section.changed = true
				--luci.util.append(self.map.events, self.events)
			end
		end
	else							-- Unset the UCI or error

		if fvalue and #fvalue == 0 then
		if self.rmempty or self.optional then
			if self:remove(section) then
				-- Push events
				self.section.changed = true
				--luci.util.append(self.map.events, self.events)
			end
		elseif cvalue ~= fvalue and not novld then
			-- trigger validator with nil value to get custom user error msg.
			local _, val_err = self:validate(nil, section)
			self:add_error(section, "missing", val_err)
		 end
		end
	end
end

-- Render if this value exists or if it is mandatory
function AbstractValue.render(self, s, scope)
	if not self.optional or self.section:has_tabs() or self:cfgvalue(s) or self:formcreated(s) then
		scope = scope or {}
		scope.section   = s
		scope.cbid      = self:cbid(s)
		scope.striptags = luci.util.striptags
		scope.pcdata	= luci.util.pcdata
		
		-- get the parament attribute and set it only read
		
		local readwrite = para_attribute_get(self.map.config, scope.section,self.option)
		if readwrite == 4 then
			self.template = "cbi/dvalue"
		end
		
		scope.ifattr = function(cond,key,val)
			if cond then
				return string.format(
					' %s="%s"', tostring(key),
					luci.util.pcdata(tostring( val
					 or scope[key]
					 or (type(self[key]) ~= "function" and self[key])
					 or "" ))
				)
			else
				return ''
			end
		end

		scope.attr = function(...)
			return scope.ifattr( true, ... )
		end

		Node.render(self, scope)
	end
end

-- Return the UCI value of this object
function AbstractValue.cfgvalue(self, section)
	local value
	if self.tag_error[section] then
		value = self:formvalue(section)
	else
		value = self.map:get(section, self.option)
	end

	if not value then
		return nil
	elseif not self.cast or self.cast == type(value) then
		return value
	elseif self.cast == "string" then
		if type(value) == "table" then
			return value[1]
		end
	elseif self.cast == "table" then
		return { value }
	end
end

-- Validate the form value
function AbstractValue.validate(self, value)
	if self.datatype and value then
		local args = { }
		local dt, ar = self.datatype:match("^(%w+)%(([^%(%)]+)%)")

		if dt and ar then
			local a
			for a in ar:gmatch("[^%s,]+") do
				args[#args+1] = a
			end
		else
			dt = self.datatype
		end

		if dt and datatypes[dt] then
			if type(value) == "table" then
				local v
				for _, v in ipairs(value) do
					if v and #v > 0 and not datatypes[dt](v, unpack(args)) then
						return nil
					end
				end
			else
				if not datatypes[dt](value, unpack(args)) then
					return nil
				end
			end
		end
	end

	return value
end

AbstractValue.transform = AbstractValue.validate


-- Write to UCI
function AbstractValue.write(self, section, value)
	return self.map:set(section, self.option, value)
end

-- Remove from UCI
function AbstractValue.remove(self, section)
	return self.map:del(section, self.option)
end




--[[
Value - A one-line value
	maxlength:	The maximum length
]]--
Value = class(AbstractValue)

function Value.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/value"
	self.keylist = {}
	self.vallist = {}
end

function Value.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function Value.value(self, key, val)
	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))
end

Value1 = class(AbstractValue)

function Value1.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/value1"
	self.keylist = {}
	self.vallist = {}
end

function Value1.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function Value1.value(self, key, val)
	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))
end


--[[
Value2 - A one-line value
	maxlength:	The maximum length
]]--
Value2 = class(AbstractValue)

function Value2.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/value2"
	self.keylist = {}
	self.vallist = {}
end

function Value2.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function Value2.value(self, key, val)
	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))
end

--[[
Value3 - A one-line value
	maxlength:	The maximum length
	addby chenfei for qos set Bandwith
]]--
Value3 = class(AbstractValue)

function Value3.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/value3"
	self.keylist = {}
	self.vallist = {}
end

function Value3.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function Value3.value(self, key, val)
	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))
end


-- DummyValue - This does nothing except being there
DummyValue = class(AbstractValue)

function DummyValue.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template = "cbi/dvalue"
	self.value = nil
end

function DummyValue.cfgvalue(self, section)
	local value
	if self.value then
		if type(self.value) == "function" then
			value = self:value(section)
		else
			value = self.value
		end
	else
		value = AbstractValue.cfgvalue(self, section)
	end
	return value
end

function DummyValue.parse(self)

end


--[[
Flag - A flag being enabled or disabled
]]--
Flag = class(AbstractValue)

function Flag.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/fvalue"

	self.enabled  = "1"
	self.disabled = "0"
	self.default  = self.disabled
end

-- A flag can only have two states: set or unset
function Flag.parse(self, section)

	-- get the parament attribute and if only read, don't parse to uci section		
	local readwrite = para_attribute_get(self.map.config, section,self.option)
	if readwrite == 4 then
		return 
	end

	local fexists = self.map:formvalue(
		FEXIST_PREFIX .. self.config .. "." .. section .. "." .. self.option)

	if fexists then
		local fvalue = self:formvalue(section) and self.enabled or self.disabled
		if fvalue ~= self.default or (not self.optional and not self.rmempty) then
			self:write(section, fvalue)
		else
			self:remove(section)
		end
	else
		self:remove(section)
	end
end

function Flag.cfgvalue(self, section)
	local cfgval= AbstractValue.cfgvalue(self, section) or self.default

	-- get the parament attribute and if only read, don't parse to uci section		
	local readwrite = para_attribute_get(self.map.config, section,self.option)
	if readwrite == 4 then
		self.flagdesc= tonumber(cfgval) == 1 and "Enable" or "Disable"
	end

	return cfgval
end


--[[
Flag1 - A flag1 being enabled or disabled for dhcp
]]--
Flag1 = class(AbstractValue)

function Flag1.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/fvalue1"

	self.enabled  = "1"
	self.disabled = "0"
	self.default  = self.disabled
end

-- A flag can only have two states: set or unset
function Flag1.parse(self, section)

	-- get the parament attribute and if only read, don't parse to uci section		
	local readwrite = para_attribute_get(self.map.config, section,self.option)
	if readwrite == 4 then
		return 
	end

	local fexists = self.map:formvalue(
		FEXIST_PREFIX .. self.config .. "." .. section .. "." .. self.option)

	if fexists then
		local fvalue = self:formvalue(section) and self.enabled or self.disabled
		if fvalue ~= self.default or (not self.optional and not self.rmempty) then
			self:write(section, fvalue)
		else
			self:remove(section)
		end
	else
		self:remove(section)
	end
end

function Flag1.cfgvalue(self, section)
	return Flag.cfgvalue(self,section)
--	return AbstractValue.cfgvalue(self, section) or self.default
end

--[[
Flag2 - A Flag2 being enabled or disabled for qos
]]--
Flag2 = class(AbstractValue)

function Flag2.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/fvalue2"

	self.enabled  = "1"
	self.disabled = "0"
	self.default  = self.disabled
end

-- A flag can only have two states: set or unset
function Flag2.parse(self, section)

	-- get the parament attribute and if only read, don't parse to uci section		
	local readwrite = para_attribute_get(self.map.config, section,self.option)
	if readwrite == 4 then
		return 
	end

	local fexists = self.map:formvalue(
		FEXIST_PREFIX .. self.config .. "." .. section .. "." .. self.option)

	if fexists then
		local fvalue = self:formvalue(section) and self.enabled or self.disabled
		if fvalue ~= self.default or (not self.optional and not self.rmempty) then
			self:write(section, fvalue)
		else
			self:remove(section)
		end
	else
		self:remove(section)
	end
end

function Flag2.cfgvalue(self, section)
	return Flag.cfgvalue(self,section)
--	return AbstractValue.cfgvalue(self, section) or self.default
end

--[[
Flag3 - A Flag3 being enabled or disabled for url filter
]]--
Flag3 = class(AbstractValue)

function Flag3.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/fvalue3"

	self.enabled  = "1"
	self.disabled = "0"
	self.default  = self.disabled
end

-- A flag can only have two states: set or unset
function Flag3.parse(self, section)

	-- get the parament attribute and if only read, don't parse to uci section		
	local readwrite = para_attribute_get(self.map.config, section,self.option)
	if readwrite == 4 then
		return 
	end

	local fexists = self.map:formvalue(
		FEXIST_PREFIX .. self.config .. "." .. section .. "." .. self.option)

	if fexists then
		local fvalue = self:formvalue(section) and self.enabled or self.disabled
		if fvalue ~= self.default or (not self.optional and not self.rmempty) then
			self:write(section, fvalue)
		else
			self:remove(section)
		end
	else
		self:remove(section)
	end
end

function Flag3.cfgvalue(self, section)
	return Flag.cfgvalue(self,section)
--	return AbstractValue.cfgvalue(self, section) or self.default
end

--[[
Flag4 - A Flag4 being enabled or disabled for mac filter
]]--
Flag4 = class(AbstractValue)

function Flag4.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/fvalue4"

	self.enabled  = "1"
	self.disabled = "0"
	self.default  = self.disabled
end

-- A flag can only have two states: set or unset
function Flag4.parse(self, section)

	-- get the parament attribute and if only read, don't parse to uci section		
	local readwrite = para_attribute_get(self.map.config, section,self.option)
	if readwrite == 4 then
		return 
	end

	local fexists = self.map:formvalue(
		FEXIST_PREFIX .. self.config .. "." .. section .. "." .. self.option)

	if fexists then
		local fvalue = self:formvalue(section) and self.enabled or self.disabled
		if fvalue ~= self.default or (not self.optional and not self.rmempty) then
			self:write(section, fvalue)
		else
			self:remove(section)
		end
	else
		self:remove(section)
	end
end

function Flag4.cfgvalue(self, section)
	return Flag.cfgvalue(self,section)
--	return AbstractValue.cfgvalue(self, section) or self.default
end

--[[
Flag5 - A Flag5 being enabled or disabled for ipport filter
]]--
Flag5 = class(AbstractValue)

function Flag5.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/fvalue5"

	self.enabled  = "1"
	self.disabled = "0"
	self.default  = self.disabled
end

-- A flag can only have two states: set or unset
function Flag5.parse(self, section)

	-- get the parament attribute and if only read, don't parse to uci section		
	local readwrite = para_attribute_get(self.map.config, section,self.option)
	if readwrite == 4 then
		return 
	end

	local fexists = self.map:formvalue(
		FEXIST_PREFIX .. self.config .. "." .. section .. "." .. self.option)

	if fexists then
		local fvalue = self:formvalue(section) and self.enabled or self.disabled
		if fvalue ~= self.default or (not self.optional and not self.rmempty) then
			self:write(section, fvalue)
		else
			self:remove(section)
		end
	else
		self:remove(section)
	end
end

function Flag5.cfgvalue(self, section)
	return Flag.cfgvalue(self,section)
--	return AbstractValue.cfgvalue(self, section) or self.default
end

--[[
Flag6 - A Flag6 being enabled or disabled for wlan
]]--
Flag6 = class(AbstractValue)

function Flag6.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/fvalue6"

	self.enabled  = "1"
	self.disabled = "0"
	self.default  = self.disabled
end

-- A flag can only have two states: set or unset
function Flag6.parse(self, section)

	-- get the parament attribute and if only read, don't parse to uci section		
	local readwrite = para_attribute_get(self.map.config, section,self.option)
	if readwrite == 4 then
		return 
	end

	local fexists = self.map:formvalue(
		FEXIST_PREFIX .. self.config .. "." .. section .. "." .. self.option)

	if fexists then
		local fvalue = self:formvalue(section) and self.enabled or self.disabled
		if fvalue ~= self.default or (not self.optional and not self.rmempty) then
			self:write(section, fvalue)
		else
			self:remove(section)
		end
	else
		self:remove(section)
	end
end

function Flag6.cfgvalue(self, section)
	return Flag.cfgvalue(self,section)
--	return AbstractValue.cfgvalue(self, section) or self.default
end

--[[
Flag7 - A Flag7 being enabled or disabled for qos plan select
]]--
Flag7 = class(AbstractValue)

function Flag7.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/fvalue7"

	self.enabled  = "1"
	self.disabled = "0"
	self.default  = self.disabled
end

-- A flag can only have two states: set or unset
function Flag7.parse(self, section)

	-- get the parament attribute and if only read, don't parse to uci section		
	local readwrite = para_attribute_get(self.map.config, section,self.option)
	if readwrite == 4 then
		return 
	end

	local fexists = self.map:formvalue(
		FEXIST_PREFIX .. self.config .. "." .. section .. "." .. self.option)

	if fexists then
		local fvalue = self:formvalue(section) and self.enabled or self.disabled
		if fvalue ~= self.default or (not self.optional and not self.rmempty) then
			self:write(section, fvalue)
		else
			self:remove(section)
		end
	else
		self:remove(section)
	end
end

function Flag7.cfgvalue(self, section)
	return Flag.cfgvalue(self,section)
--	return AbstractValue.cfgvalue(self, section) or self.default
end

--[[
Flag8 - A Flag8 being enabled or disabled for qos Enable DSCP Mark
]]--
Flag8 = class(AbstractValue)

function Flag8.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/fvalue8"

	self.enabled  = "1"
	self.disabled = "0"
	self.default  = self.disabled
end

-- A flag can only have two states: set or unset
function Flag8.parse(self, section)

	-- get the parament attribute and if only read, don't parse to uci section		
	local readwrite = para_attribute_get(self.map.config, section,self.option)
	if readwrite == 4 then
		return 
	end

	local fexists = self.map:formvalue(
		FEXIST_PREFIX .. self.config .. "." .. section .. "." .. self.option)

	if fexists then
		local fvalue = self:formvalue(section) and self.enabled or self.disabled
		if fvalue ~= self.default or (not self.optional and not self.rmempty) then
			self:write(section, fvalue)
		else
			self:remove(section)
		end
	else
		self:remove(section)
	end
end

function Flag8.cfgvalue(self, section)
	return Flag.cfgvalue(self,section)
--	return AbstractValue.cfgvalue(self, section) or self.default
end

--[[
ListValue - A one-line value predefined in a list
	widget: The widget that will be used (select, radio)
]]--
ListValue = class(AbstractValue)

function ListValue.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/lvalue"

	self.keylist = {}
	self.vallist = {}
	self.size   = 1
	self.widget = "select"
end

function ListValue.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function ListValue.value(self, key, val, ...)
	if luci.util.contains(self.keylist, key) then
		return
	end

	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))

	for i, deps in ipairs({...}) do
		self.subdeps[#self.subdeps + 1] = {add = "-"..key, deps=deps}
	end
end

function ListValue.validate(self, val)
	if luci.util.contains(self.keylist, val) then
		return val
	else
		return nil
	end
end

--added by chenfei 20110623
--[[
ListValue2 - A one-line value predefined in a list
	widget: The widget that will be used (select, radio)
]]--
ListValue2 = class(AbstractValue)

function ListValue2.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/lvalue2"

	self.keylist = {}
	self.vallist = {}
	self.size   = 1
	self.widget = "select"
end

function ListValue2.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function ListValue2.value(self, key, val, ...)
	if luci.util.contains(self.keylist, key) then
		return
	end

	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))

	for i, deps in ipairs({...}) do
		self.subdeps[#self.subdeps + 1] = {add = "-"..key, deps=deps}
	end
end

function ListValue2.validate(self, val)
	if luci.util.contains(self.keylist, val) then
		return val
	else
		return nil
	end
end


--added by chenfei 20110803
ListValue3 = class(AbstractValue)

function ListValue3.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/lvalue3"

	self.keylist = {}
	self.vallist = {}
	self.size   = 1
	self.widget = "select"
end

function ListValue3.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function ListValue3.value(self, key, val, ...)
	if luci.util.contains(self.keylist, key) then
		return
	end

	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))

	for i, deps in ipairs({...}) do
		self.subdeps[#self.subdeps + 1] = {add = "-"..key, deps=deps}
	end
end

function ListValue3.validate(self, val)
	if luci.util.contains(self.keylist, val) then
		return val
	else
		return nil
	end
end


--added by hj
ListValue4 = class(AbstractValue)

function ListValue4.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/lvalue4"

	self.keylist = {}
	self.vallist = {}
	self.size   = 1
	self.widget = "select"
end

function ListValue4.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function ListValue4.value(self, key, val, ...)
	if luci.util.contains(self.keylist, key) then
		return
	end

	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))

	for i, deps in ipairs({...}) do
		self.subdeps[#self.subdeps + 1] = {add = "-"..key, deps=deps}
	end
end

function ListValue4.validate(self, val)
	if luci.util.contains(self.keylist, val) then
		return val
	else
		return nil
	end
end


--added by hj
ListValue5 = class(AbstractValue)

function ListValue5.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/lvalue5"

	self.keylist = {}
	self.vallist = {}
	self.size   = 1
	self.widget = "select"
end

function ListValue5.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function ListValue5.value(self, key, val, ...)
	if luci.util.contains(self.keylist, key) then
		return
	end

	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))

	for i, deps in ipairs({...}) do
		self.subdeps[#self.subdeps + 1] = {add = "-"..key, deps=deps}
	end
end

function ListValue5.validate(self, val)
	if luci.util.contains(self.keylist, val) then
		return val
	else
		return nil
	end
end

--added by chenfei for qos plan select
ListValue6 = class(AbstractValue)

function ListValue6.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/lvalue6"

	self.keylist = {}
	self.vallist = {}
	self.size   = 1
	self.widget = "select"
end

function ListValue6.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function ListValue6.value(self, key, val, ...)
	if luci.util.contains(self.keylist, key) then
		return
	end

	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))

	for i, deps in ipairs({...}) do
		self.subdeps[#self.subdeps + 1] = {add = "-"..key, deps=deps}
	end
end

function ListValue6.validate(self, val)
	if luci.util.contains(self.keylist, val) then
		return val
	else
		return nil
	end
end

--added by chenfei for qos Enable 802.1P
ListValue7 = class(AbstractValue)

function ListValue7.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/lvalue7"

	self.keylist = {}
	self.vallist = {}
	self.size   = 1
	self.widget = "select"
end

function ListValue7.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function ListValue7.value(self, key, val, ...)
	if luci.util.contains(self.keylist, key) then
		return
	end

	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))

	for i, deps in ipairs({...}) do
		self.subdeps[#self.subdeps + 1] = {add = "-"..key, deps=deps}
	end
end

function ListValue7.validate(self, val)
	if luci.util.contains(self.keylist, val) then
		return val
	else
		return nil
	end
end
--added by huangjie for wlan

ListValue8 = class(AbstractValue)

function ListValue8.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/lvalue8"

	self.keylist = {}
	self.vallist = {}
	self.size   = 1
	self.widget = "select"
end

function ListValue8.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function ListValue8.value(self, key, val, ...)
	if luci.util.contains(self.keylist, key) then
		return
	end

	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))

	for i, deps in ipairs({...}) do
		self.subdeps[#self.subdeps + 1] = {add = "-"..key, deps=deps}
	end
end

function ListValue8.validate(self, val)
	if luci.util.contains(self.keylist, val) then
		return val
	else
		return nil
	end
end

--added by huangjie for wlan
ListValue9 = class(AbstractValue)

function ListValue9.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/lvalue9"

	self.keylist = {}
	self.vallist = {}
	self.size   = 1
	self.widget = "select"
end

function ListValue9.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function ListValue9.value(self, key, val, ...)
	if luci.util.contains(self.keylist, key) then
		return
	end

	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))

	for i, deps in ipairs({...}) do
		self.subdeps[#self.subdeps + 1] = {add = "-"..key, deps=deps}
	end
end

function ListValue9.validate(self, val)
	if luci.util.contains(self.keylist, val) then
		return val
	else
		return nil
	end
end



--[[
MultiValue - Multiple delimited values
	widget: The widget that will be used (select, checkbox)
	delimiter: The delimiter that will separate the values (default: " ")
]]--
MultiValue = class(AbstractValue)

function MultiValue.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template = "cbi/mvalue"

	self.keylist = {}
	self.vallist = {}

	self.widget = "checkbox"
	self.delimiter = " "
end

function MultiValue.render(self, ...)
	if self.widget == "select" and not self.size then
		self.size = #self.vallist
	end

	AbstractValue.render(self, ...)
end
function MultiValue.parse(self, section, novld)

	-- get the parament attribute and if only read, don't parse to uci section		
	local readwrite = para_attribute_get(self.map.config, section,self.option)
	if readwrite == 4 then
		return 
	end

	local fvalue = self:formvalue(section)
	local cvalue = self:cfgvalue(section)

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		local equal = #fvalue == #cvalue
		if equal then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					equal = false
				end
			end
		end
		if equal then
			fvalue = cvalue
		end
	end

	if fvalue and #fvalue > 0 then -- If we have a form value, write it to UCI
		local val_err
		fvalue, val_err = self:validate(fvalue, section)
		fvalue = self:transform(fvalue)

		if not fvalue and not novld then
			self:add_error(section, "invalid", val_err)
		end

		if fvalue and (self.forcewrite or not (fvalue == cvalue)) then
			if self:write(section, fvalue) then
				-- Push events
				self.section.changed = true
				--luci.util.append(self.map.events, self.events)
			end
		end
	else							-- Unset the UCI or error
--		if fvalue and #fvalue == 0 then
		if self.rmempty or self.optional then
			if self:remove(section) then
				-- Push events
				self.section.changed = true
				--luci.util.append(self.map.events, self.events)
			end
		elseif cvalue ~= fvalue and not novld then
			-- trigger validator with nil value to get custom user error msg.
			local _, val_err = self:validate(nil, section)
			self:add_error(section, "missing", val_err)
		 end
--		end
	end
end
function MultiValue.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function MultiValue.value(self, key, val)
	if luci.util.contains(self.keylist, key) then
		return
	end

	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))
end

function MultiValue.valuelist(self, section)
	local val = self:cfgvalue(section)

	if not(type(val) == "string") then
		return {}
	end

	return luci.util.split(val, self.delimiter)
end

function MultiValue.validate(self, val)
	val = (type(val) == "table") and val or {val}

	local result

	for i, value in ipairs(val) do
		if luci.util.contains(self.keylist, value) then
			result = result and (result .. self.delimiter .. value) or value
		end
	end

	return result
end


StaticList = class(MultiValue)

function StaticList.__init__(self, ...)
	MultiValue.__init__(self, ...)
	self.cast = "table"
	self.valuelist = self.cfgvalue

	if not self.override_scheme
	 and self.map:get_scheme(self.section.sectiontype, self.option) then
		local vs = self.map:get_scheme(self.section.sectiontype, self.option)
		if self.value and vs.values and not self.override_values then
			for k, v in pairs(vs.values) do
				self:value(k, v)
			end
		end
	end
end

function StaticList.validate(self, value)
	value = (type(value) == "table") and value or {value}

	local valid = {}
	for i, v in ipairs(value) do
		if luci.util.contains(self.keylist, v) then
			table.insert(valid, v)
		end
	end
	return valid
end


DynamicList = class(AbstractValue)

function DynamicList.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/dynlist"
	self.cast = "table"
	self.keylist = {}
	self.vallist = {}
end

function DynamicList.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function DynamicList.value(self, key, val)
	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))
end

function DynamicList.write(self, section, value)
	local t = { }

	if type(value) == "table" then
		local x
		for _, x in ipairs(value) do
			if x and #x > 0 then
				t[#t+1] = x
			end
		end
	else
		t = { value }
	end

	if self.cast == "string" then
		value = table.concat(t, " ")
	else
		value = t
	end

	return AbstractValue.write(self, section, value)
end

function DynamicList.cfgvalue(self, section)
	local value = AbstractValue.cfgvalue(self, section)

	if type(value) == "string" then
		local x
		local t = { }
		for x in value:gmatch("%S+") do
			if #x > 0 then
				t[#t+1] = x
			end
		end
		value = t
	end

	return value
end

function DynamicList.formvalue(self, section)
	local value = AbstractValue.formvalue(self, section)

	if type(value) == "string" then
		if self.cast == "string" then
			local x
			local t = { }
			for x in value:gmatch("%S+") do
				t[#t+1] = x
			end
			value = t
		else
			value = { value }
		end
	end

	return value
end

DynamicList2 = class(AbstractValue)

function DynamicList2.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/dynlist2"
	self.cast = "table"
	self.keylist = {}
	self.vallist = {}
end

function DynamicList2.reset_values(self)
	self.keylist = {}
	self.vallist = {}
end

function DynamicList2.value(self, key, val)
	val = val or key
	table.insert(self.keylist, tostring(key))
	table.insert(self.vallist, tostring(val))
end

function DynamicList2.write(self, section, value)
	local t = { }

	if type(value) == "table" then
		local x
		for _, x in ipairs(value) do
			if x and #x > 0 then
				t[#t+1] = x
			end
		end
	else
		t = { value }
	end

	if self.cast == "string" then
		value = table.concat(t, " ")
	else
		value = t
	end

	return AbstractValue.write(self, section, value)
end

function DynamicList2.cfgvalue(self, section)
	local value = AbstractValue.cfgvalue(self, section)

	if type(value) == "string" then
		local x
		local t = { }
		for x in value:gmatch("%S+") do
			if #x > 0 then
				t[#t+1] = x
			end
		end
		value = t
	end

	return value
end

function DynamicList2.formvalue(self, section)
	local value = AbstractValue.formvalue(self, section)

	if type(value) == "string" then
		if self.cast == "string" then
			local x
			local t = { }
			for x in value:gmatch("%S+") do
				t[#t+1] = x
			end
			value = t
		else
			value = { value }
		end
	end

	return value
end


--[[
TextValue - A multi-line value
	rows:	Rows
]]--
TextValue = class(AbstractValue)

function TextValue.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/tvalue"
end

TextValue1 = class(AbstractValue)

function TextValue1.__init__(self, ...)


	AbstractValue.__init__(self, ...)
	self.template  = "cbi/tvalue1"




end

--[[
Button
]]--
Button = class(AbstractValue)

function Button.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template  = "cbi/button"
	self.inputstyle = nil
	self.rmempty = true
end


FileUpload = class(AbstractValue)

function FileUpload.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template = "cbi/upload"
	if not self.map.upload_fields then
		self.map.upload_fields = { self }
	else
		self.map.upload_fields[#self.map.upload_fields+1] = self
	end
end

function FileUpload.formcreated(self, section)
	return AbstractValue.formcreated(self, section) or
		self.map:formvalue("cbi.rlf."..section.."."..self.option) or
		self.map:formvalue("cbi.rlf."..section.."."..self.option..".x")
end

function FileUpload.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	if val and fs.access(val) then
		return val
	end
	return nil
end

function FileUpload.formvalue(self, section)
	local val = AbstractValue.formvalue(self, section)
	if val then
		if not self.map:formvalue("cbi.rlf."..section.."."..self.option) and
		   not self.map:formvalue("cbi.rlf."..section.."."..self.option..".x")
		then
			return val
		end
		fs.unlink(val)
		self.value = nil
	end
	return nil
end

function FileUpload.remove(self, section)
	local val = AbstractValue.formvalue(self, section)
	if val and fs.access(val) then fs.unlink(val) end
	return AbstractValue.remove(self, section)
end


FileBrowser = class(AbstractValue)

function FileBrowser.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template = "cbi/browser"
end
