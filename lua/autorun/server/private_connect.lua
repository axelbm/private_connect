local server_owner = CreateConVar( "private_connect_owner", "", bit.bor( FCVAR_ARCHIVE, FCVAR_GAMEDLL, FCVAR_PROTECTED) , "The SteamID64 of the owner." );
local api_key = CreateConVar( "private_connect_api_key", "", bit.bor( FCVAR_ARCHIVE, FCVAR_GAMEDLL, FCVAR_PROTECTED) , "The API key." );
 
local players_friend = {}

local function getfriend(steamid64)
	local url = string.format("http://api.steampowered.com/ISteamUser/GetFriendList/v0001/?key=%s&steamid=%s&relationship=friend", api_key:GetString(), steamid64)

	local request = {
		url   	= url,
		method	= "get",
		success = function(_, body)
			local data = util.JSONToTable(body)

			if data then
				local ndata = {}
				for i,v in pairs(data.friendslist.friends) do
					ndata[v.steamid] = true
				end
				
				players_friend[steamid64] = ndata
			end
		end,
		failed = function() return end
	}

	local succ = HTTP(request)

	if not succ then
		timer.Simple(0, function()
			getfriend(steamid64)
		end)
	end
end
 
local ulx_check_access
if ULib then
	ULib.ucl.registerAccess("private_connect", {"operator", "admin", "superadmin"}, _, "Other")

	function ulx_check_access(group, access)
		if not ULib then return end
		local ucl = ULib.ucl

		while group do 
			local groupInfo = ucl.groups[ group ]
			if not groupInfo then return end
			if table.HasValue(groupInfo.allow, access) then return true end
			if groupInfo.allow[ access ] then return true end

			group = ucl.groupInheritsFrom( group )
		end
	end
end

hook.Add("CheckPassword", "private_connect", function(steamID64, ipAddress, svPassword, clPassword, name)
	if api_key:GetString() == "" then return end

	local steamid = util.SteamIDFrom64(steamID64)

	if svPassword ~= "" and svPassword == clPassword then
		print(name, steamID64, ipAddress, "Valid Password")
		return true
	end

	if ULib then
		local ulx_info = ULib.ucl.getUserInfoFromID(steamid)

		if ulx_info then
			local group = ulx_info.group

			if ulx_check_access(group, "private_connect") then
				print(name, steamID64, ipAddress, "Has Access")
				return true
			end
		end
	end

	if steamID64 == server_owner:GetString() then
		print(name, steamID64, ipAddress, "Is Owner")
		return true
	end

	for k,v in pairs(players_friend) do
		if v[steamID64] then
			print(name, steamID64, ipAddress, "Is Friend With", k)
			return true
		end
	end

	print(name, steamID64, ipAddress, "Access denied")
	PrintMessage(HUD_PRINTTALK, name .. " try to connect.")
	return false, "Access denied."
end)

hook.Add("PlayerInitialSpawn", "private_connect", function(ply)
	if api_key:GetString() == "" then return end

	local steamid = ply:SteamID64()

	if steamid ~= server_owner:GetString() then
		getfriend(steamid)
	end
end)

hook.Add("PlayerDisconnected", "private_connect", function(ply)
	if api_key:GetString() == "" then return end

	local steamid = ply:SteamID64()

	if steamid ~= server_owner:GetString() then
		players_friend[steamid] = nil
	end
end)


cvars.AddChangeCallback("private_connect_owner", function(name, old, new)
	if api_key:GetString() ~= "" then
		if old == new then return end

		if old ~= "" then
			local ply = player.GetBySteamID64(old)

			if not IsValid(ply) then
				players_friend[old] = nil
			end
		end

		getfriend(new)
	end
end)

cvars.AddChangeCallback("private_connect_api_key", function(name, old, new)
	players_friend = {}

	if new ~= "" then
		if server_owner:GetString() ~= "" then
			getfriend(server_owner:GetString())
		end

		for _,ply in pairs(player.GetAll()) do
			if ply:SteamID64() ~= server_owner:GetString() then
				getfriend(ply:SteamID64())
			end
		end
	end
end)

PrivateConnect = {}
PrivateConnect.Friends = players_friend

if server_owner:GetString() and api_key:GetString() then
	getfriend(server_owner:GetString())
end