--!strict

--> Freon Type
type Freon = {
	State: {},
	Changed: boolean,
	Permanent: boolean,
	Key: string,
	Recipients: {},
	Replicate: boolean,
	CreationTime: number,
}

local Freon: Freon = {}

--[[
    ! Due to the system being top-down (Server -> Client) only, data cannot be modified by the client. (In theory)
    ! Freon's state objects are strictly primitive. Only primitive types should be included in state.

    > Freon - A Replicated Primitave State Manager
        | Dynamically Manages and Replicates State to Each Client on Change

        > Communication is strictly downstream (Server -> Client)
        > Packets from Server to Client will expire if not refreshed by the Server
        > Packets have an update method, which fires when updated.
        > When the client is ready, freon's client will automatically pull the current state from the server.
]]--

--> Services
local RunService = game:GetService("RunService")

--> Dependancies
local Debug = require(script.Util.Debug)
local TableUtil = require(script.Util.Table)

--> Ghetto Enum
Freon.AllPlayers = "ALL_PLRS"

--> Constants
local IsServer = RunService:IsServer()

--> On Initial Require, Create our Remote
local PushRemote
local PullRequest
local Binds

do
	if IsServer then
		PushRemote = Instance.new("RemoteEvent")
		PushRemote.Name = "Freon_Push"
		PushRemote.Parent = game.ReplicatedStorage.Events

        PullRequest = Instance.new("RemoteFunction")
		PullRequest.Name = "Freon_Request"
		PullRequest.Parent = game.ReplicatedStorage.Events

		Binds = Instance.new("Folder")
		Binds.Name = "Binds"
		Binds.Parent = PushRemote
	else
		PushRemote = game.ReplicatedStorage.Events:WaitForChild("Freon_Push", 5)
        PullRequest = game.ReplicatedStorage.Events:WaitForChild("Freon_Request", 5)
		Binds = PushRemote:WaitForChild("Binds", 5)
		--! error out if we can't find it
	end
end

--> Configuration
local Updater = RunService.Heartbeat
local MaxAwait = 30
local DevMode = true

--> Unique State
local States = {} --| Holds 'Local' Keys

--> Client
local ExpiredKeys = {} --| Table of Expired Keys
local DataExpireTime = 5 --| 600 (Seconds)
local DataCheckRate = 5 --| 5   (Seconds)

--> Internal <-----------------------------------------------------------

--> Custom Print
local _print = print
local print = function(...)
    if DevMode then
        _print(...)
    end
end

--> Check to see if a Key Exists in any Current Registry
function DoesKeyExist(Key: string)
	if States[Key] then
		return true
	end

	return false
end

function GetByKey(Key: string)
	if States[Key] then
		return States[Key]
	end

	return nil
end

function FireGroup(Players: { Player }, ...)
	for _, Player: Player in ipairs(Players) do
		PushRemote:FireClient(Player, ...)
	end
end

function NewBind()
	local OnUpdate = Instance.new("BindableEvent")
	OnUpdate.Parent = Binds

	return OnUpdate
end

--> When Client Is Loaded, Initiate Server Pull Request to Get Current State
function ClientReadyPull(Player: Player)    
    for _, Obj: Freon in pairs(States) do
        task.wait(0.01)
        Obj:push(false, Player)
    end
end


--> Create a new Instance of Freon
function Freon.new(
	Key: string,
	InitialState: { any? },
	Recipients: { Player? } | Player? | boolean?,
	IsPermanent: boolean?
)

	InitialState = InitialState or { math.huge }

	--> If we are passed a empty table, error.
	if not TableUtil:IsEmpty(InitialState) then
		Debug.Error(Debug.Errors.EmptyInitialTable)
	end

	if DoesKeyExist(Key) then
		Debug.Error(Debug.Errors.DuplicateKey, Key)
	end

	IsPermanent = IsPermanent or false

	local _Freon = setmetatable({}, {
        __index = Freon,
    })

	--> Set (Read Only) State
	_Freon.Permanent = IsPermanent
	_Freon.Key = Key
	_Freon.Recipients = Recipients or nil
	_Freon.Changed = true
	_Freon.State = { "" }
	_Freon.Replicate = (Recipients ~= nil) and true or false
	_Freon.CreationTime = os.time()
	_Freon.Connections = {}

	--> For Update Listeners
	_Freon._OnUpdate = NewBind()

	_Freon:set(InitialState)
	States[Key] = _Freon

    --> Throw error if State is Directly Modified
    _Freon.__newindex = function(_, _, Value)
        if Value then
            Debug.Error(Debug.Errors.AttemptDirectChange)
        end
    end

	return _Freon
end

--> API <----------------------------------------------------------------

function Freon:set(State: { any })
	local Identical = TableUtil:Compare(self.State, State)

	if not Identical then
		self._OnUpdate:Fire()
		print("Non Identical, Updating")
		rawset(self, "State", State)
        rawset(self, "Changed", true)
	else
		print("Identical, Skipping")
	end
end

--> Get Current State, or Another by Key
function Freon:get()
    local Key = self.Key

    local Get = GetByKey(Key)
    if Get then
        return Get
    end

    if ExpiredKeys[Key] then
        Debug.Warn(Debug.Errors.AttemptGetOnExpiredKey, Key, os.time() - ExpiredKeys[Key].ExpireTime)
    end

end

--> Wait for a Key with a given timeout (Default is MaxAwait)
function Freon:await(Key: string?, Timeout)
	Timeout = Timeout or MaxAwait

	for _ = 1, Timeout, 0.1 do
		task.wait(0.1)
		local Get = GetByKey(Key)

		if Get then
			print(Get)
			return Get
		end
	end

	Debug.Warn(Debug.Errors.MaxAwaitTimeoutReached, Key)
	return nil
end

--> On Connection Update
function Freon:onUpdate(Callback)
	table.insert(
		self.Connections,
		self._OnUpdate.Event:Connect(function()
			Callback()
		end)
	)
end

--> Attempt to push changes to client
function Freon:push(Force: boolean?, Target: Player?)
    --> Target is for updating a single clients state internally
    if Target then
        PushRemote:FireClient(Target, self.Key, self.Packet, self.Permanent)
        return
    end
	
    --> If we are pushing from client, error out.
	if not IsServer then
		Debug:Error(Debug.Errors.AttemptedPushFromClient, self.Key)
	end

	--> If our state is non replicable, warn developer.
	if not self.Replicate then
		Debug.Warn(Debug.Errors.AttemptToPushNonReplicableState, self.Key)
	end

	--> If our state has updated, push to client.
	if self.Changed or Force then
		rawset(self, "Changed", false)

		--> Pack State
		local Key = self.Key
		local Packet = self.State
		local IsPermanent = self.Permanent

		--> Fire depending on the
		if self.Recipients == self.AllPlayers then
			PushRemote:FireAllClients(Key, Packet, IsPermanent)
		elseif typeof(self.Recipients) == "table" then
			FireGroup(self.Recipients, Key, Packet, IsPermanent)
		elseif self.Recipients:IsA("Player") then
			PushRemote:FireClient(self.Recipients, Key, Packet, IsPermanent)
		end
	end
end

function Freon:destroy()
	--> Keep track of Expired Keys for error handling
	ExpiredKeys[self.Key] = {}
	ExpiredKeys[self.Key].ExpireTime = os.time()

	for _, Event in ipairs(self.Connections) do
		Event:Disconnect()
	end

    print 'key purged'
	--! Purge Key
	States[self.Key] = nil
end

--> Runtime <----------------------------------------------------------------
if IsServer then
    PullRequest.OnServerInvoke = ClientReadyPull

	--> Call push each frame
	Updater:Connect(function()
		--> Loop through each State object and Push if Replicable
		for _, Instance: Freon in pairs(States) do
			if Instance.Replicate then
				Instance:push()
			end
		end
	end)
else
	--> On Client Event, Add to ClientCache
	PushRemote.OnClientEvent:Connect(function(Key: string, Packet, IsPermanent)
		local Object: Freon = States[Key]

		if Object then
			--> Refresh Object
			rawset(Object, "CreationTime", os.time())
			Object:set(Packet)
		else
			Freon.new(Key, Packet, nil, IsPermanent)
		end
	end)

    --> On Client Ready, We Pull the Server's Current State
    PullRequest:InvokeServer()

	local TimeElapsed = 0

	--> Update Client Side
	Updater:Connect(function(DeltaTime)
		TimeElapsed += DeltaTime

		if TimeElapsed > DataCheckRate then
			TimeElapsed = 0

			for _, Packet: Freon in pairs(States) do
				--! Do not pass this to gc if the packet is permanent.
				if Packet.Permanent then
					continue
				end

				--> If our keys have expired, pass them (hopefully) to gc
				if (os.time() - Packet.CreationTime) > DataExpireTime then
					Packet:destroy()
				end
			end
		end
	end)
end

return Freon
