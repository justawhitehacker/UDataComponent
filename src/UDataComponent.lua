-- UDataComponent
-- A data component that can be used to store data in a way that is easy to use and manage

--[[
	== Informations ==
	
	Creator: @RaihanMan18 (Raihan Naufal Azmi)
	Version: UDataComponent v1.0
	Module-goal: DataStore wrapper
	Created-since: 5 August 2026
	License: MIT
	
	Written in Luau for Roblox
	
	== END ==
	
	SIMPLE DOCUMENTATION:
	
	Before that, I will tell you what's the differende between Safe, Force, and Normal (un-prefixed).
	
	- Safe
	--- This is method where your data will be handled with locks and queue-based ---
		
	- Force
	--- This is method where the data is immediately commited into data store of roblox, whether affected by cooldown or not, based of the configuration ---
	
	- Normal
	--- This is method where the data handled normally by UDataComponent. Enququed, then commited, without locks. and affected by the cooldown ---
	
	== Constructor ==
	
	UDataComponent.InDataInfo(DataStoreName: string, scope : string?) : UDataComponentInfo
	---- Creates a new UDataComponent info object, where all handler tables constructed ----
	
	== END ==
	
	== UDataComponentInfo ==
	
	UDataComponentInfo:GetPlayerData(Key: number | string, Callbacks: {UDataComponentCallbackFunctions?}) : UDataComponentRecord
	---- Gets the data of a player, allows you to access player's data level
	
	UDataComponentInfo:GetDataStoreName() : string
	---- Gets the current data store name ----
	
	UDataComponentInfo:GetLocalData(Callbacks: {UDataComponentCallbackFunctions?}) : UDataComponentRecord
	---- You can say Local Data is a "global data of this data store", where you can use this to store data where is not related to a player, but current data store ----
	
	UDataComponentInfo.Enabled : boolean --> Allows to UDataComponent process this data store to be loaded and saved
	UDataComponentInfo.ValidationEnabled : boolean --> Allows to UDataComponent validate this data store before saving
	UDataComponentInfo.CallbackEnabled : boolean --> Allows to UDataComponent listen the callbacks
	UDataComponentInfo.RequestTimestampCooldown : number --> Minimum time between each request to the data store
	UDataComponentInfo.DefaultDataLoadingAttempts : number --> Minimum attempts to load the data
	UDataComponentInfo.DefaultDataLoadingYieldDuration : number --> Minimum duration to yield when loading data
	UDataComponentInfo.WALEnabled : boolean --> Allows to UDataComponent to use Write Ahead Logging
	UDataComponentInfo.DefaultSaveAttempts : number --> Minimum attempts to save the data
	UDataComponentInfo.DefaultYieldAttempts : number --> Minimum duration to yield when saving data
	UDataComponentInfo.MaxKeyLength : number --> Maximum key length
	UDataComponentInfo.BackupEnabled : boolean --> Allows to UDataComponent to use backup data
	UDataComponentInfo.BackupYieldDuration : number --> Minimum duration to yield when saving backup data
	UDataComponentInfo.StrictlyUnallowDetaching : boolean --> Unallows UDataComponent to detach/delete data
	UDataComponentInfo.BackupRemovedWhenDetached : boolean --> Removes the backup data when the data is detached
	UDataComponentInfo.AutoSaveEnabled : boolean --> Enables the data to be saved automatically
	UDataComponentInfo.AutoSaveInterval : number --> Interval to save the data
	UDataComponentInfo.WALDataSuffix : string --> Suffix to the data key for Write Ahead Logging
	UDataComponentInfo.WALMaxEntries : number --> Maximum entries in the Write Ahead Logging
	UDataComponentInfo.BackupDataSuffix : string --> Suffix to the data key for backup data
	UDataComponentInfo.ExclusiveAccessEnabled : boolean --> Allows to UDataComponent to use exclusive access
	UDataComponentInfo.ExclusiveAccessExpiration : number --> Duration of exclusive data for each players since bound
	UDataComponentInfo.SwappingEnabled : boolean --> Allows to UDataComponent to swap/transaction data between players
	UDataComponentInfo.SwappingCooldown : number --> Minimum time between each swap/transaction request
	UDataComponentInfo.CacheCleaningEnabled : boolean --> Enables the cache to be cleaned automatically
	UDataComponentInfo.CacheCleaningInterval : number --> Interval to clean the cache
	UDataComponentInfo.DataExpiredDuration : number --> Duration of data to be considered as expired
	UDataComponentInfo.DataBlueprint : {any} --> Default data structure for template/blueprint
	UDataComponentInfo.ErrorReasonNamespace : string --> Namespace of error of UDataComponent
	UDataComponentInfo.LocalDataNamespace : string --> Namespace of local data of UDataComponent
	UDataComponentInfo.MessagingEnabled : boolean --> Allows to UDataComponent to replicate the data to other servers
	UDataComponentInfo.MessagingNamespace : string --> Namespace of broadcasting data to other servers
	UDataComponentInfo.MessagingSendingCooldown : number --> Cooldown of each sending to other servers
	UDataComponentInfo.MessagingReceivingCooldown : number --> Cooldown of each receiving from other servers
	UDataComponentInfo.MessagingLocalListeningCooldown : number --> Cooldown of each local listening to other servers
	UDataComponentInfo.ServerClaimerSuffix : string --> Suffix of server that currently claiming data of a player/key
	UDataComponentInfo.ArchivationEnabled : boolean --> Allows to UDataComponent to use archivation when detached
	UDataComponentInfo.ArchivationSuffix : string --> Suffix of archived data
	UDataComponentInfo.MessagingDebugEnabled : boolean --> Enables the debug messages of broadcasting
	UDataComponentInfo.MaxDataSavingPerTick : number --> Maximum data saving per tick
	
	== END ==
	
	== UDataComponentRecord ==
	
	UDataComponentRecord:Get(LoadRecovery? = false, ExclusivePlayer? = nil), returns (Status: boolean, Data: any)
	-- Get the data record of current info --
	-- When you used this function twice or more, this will return cache of data's record, to prevent boom request --
	
	-- !param LoadRecovery: boolean? = Invokes TryToRecover function to check if there was a record that haven't been commited, which is from WAL
	-- !param ExclusivePlayer: Player? = Checking data with player, if this data was belong and exclusived to the player
	
	-> Example:
	local currentData = info:GetPlayerData(plr.UserId)
	local status, data = currentData:Get(true, plr) -- Get the data of player with recovery, recommended to be called on first-join or data load
	
	
	
	UDataComponentRecord:Save(Data: any, SegmentIndex: number? = nil), returns (Status: boolean)
	-- Save the data record of current info --
	-- Data will be cached first before commited to data store --
	
	-- !param Data: any = Current data to commit
	-- !param SegmentIndex: number? = Index of table segment for data, as if used index to contain the data value
	
	-> Example:
	local currentData = info:GetPlayerData(plr.UserId)
	local isSuccess = currentData:Save({
		Money = (Money or 0) + 100,
		Items = (Items or 0) + 1,
	})
	
	-> Example (if use SegmentIndex):
	local currentData = info:GetPlayerData(plr.UserId)
	local isMoneySuccess = currentData:Save(100, 1) -- Save the "Money" data of player with index of 1
	local isItemsSuccess = currentData:Save(1, 2) -- Save the "Items" data of player with index of 2
	
	-- This will be { 100, 1 }, where you can access first index as "Money" and second index as "Items"
	
	
	
	UDataComponentRecord:Write(WritingFunction: (CurrentData: any) -> any), returns (Status: boolean)
	-- Modify the partial data of current data record, before saved to data store --
	-- Same as Save, data will be cached first before commited to data store --
	
	-- !param WritingFunction: (CurrentData: any) -> any = Function to modify the data
		-- @param CurrentData: any = Current data to modify
	-- !important: You should return the CurrentData in modifier function after modify the data
	
	-> Example:
	local currentData = info:GetPlayerData(plr.UserId)
	local isSuccess = currentData:Write(function(data)
		data.Money += 100
		data.Items += 1
		
		return data
	end)
	
	
	
	UDataComponentRecord:Flush()

	== END ==
	
--]]

local UDataComponent = {}
UDataComponent.__index = UDataComponent

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

local placeId = game.PlaceId

local __sc = script.ScopedMutex

local SDictionary = require(script.SDictionary)
local Mutex = require(__sc.Mutex)
local ScopedMutex = require(__sc)

export type UDataComponentValidationDummy = {
	-- Inserting a predication of data whereas the data can be written when the predicate fulfilled
	InsertPredicate: (self: UDataComponentValidationDummy, ThisData: any, Predicate: (ThisValue: any) -> any) -> any,
	RemovePredicate: (self: UDataComponentValidationDummy, ThisData: any) -> any,

	InsertClamp: (self: UDataComponentValidationDummy, ThisData: any, Min: number?, Max: number?) -> any,
	RemoveClamp: (self: UDataComponentValidationDummy, ThisData: any) -> any,

	InsertSchema: (self: UDataComponentValidationDummy, ThisData: any, Type: string) -> any,
	RemoveSchema: (self: UDataComponentValidationDummy, ThisData: any) -> any
} 

export type UDataComponentRecord = {
	Get: (self: UDataComponentRecord, LoadRecovery: boolean?, ExclusivePlayer: Player?) -> any,
	Save: (self: UDataComponentRecord, Data: any, SegmentIndex: number?) -> boolean,
	Write: (self: UDataComponentRecord, WritingFunction: (CurrentData: any) -> any) -> boolean,
	Flush: (self: UDataComponentRecord) -> (),
	Recover: (self: UDataComponentRecord) -> boolean,
	Detach : (self: UDataComponentRecord) -> (),
	ForceSave: (self: UDataComponentRecord, AlongCooldown: number, Data: any, SegmentIndex: number?) -> boolean,
	ForceWrite: (self: UDataComponentRecord, AlongCooldown: number, WritingFunction: (CurrentData: any) -> any) -> boolean,
	SafeGet: (self: UDataComponentRecord, LoadRecovery: boolean?, ExclusivePlayer: Player?, LoadAttempts: number?, YieldTime: number?) -> boolean,
	SafeSave: (self: UDataComponentRecord, Data: any, SegmentIndex: number?) -> (),
	SafeWrite: (self: UDataComponentRecord, WritingFunction: (CurrentData: any) -> any) -> boolean,
	AcquireLockSession: (self: UDataComponentRecord, OwnerIdentity: string?, Timeout: number?) -> (boolean, any), 
	ReleaseLockSession: (self: UDataComponentRecord, OwnerIdentity: string) -> (),
	IsSessionLocked: (self: UDataComponentRecord, OwnerIdentity: string) -> boolean,
	BindExclusiveAccess: (self: UDataComponentRecord, ExclusivePlayer: Player) -> boolean,
	UnbindExclusiveAccess: (self: UDataComponentRecord) -> boolean,
	RefreshExclusiveAccess: (self: UDataComponentRecord) -> boolean,
	IsExclusiveAccessBound: (self: UDataComponentRecord) -> boolean,
	IsPlayerInExclusiveAccess: (self: UDataComponentRecord, PlayerThatAssumedExclusive: Player) -> boolean,
	CreateValidation: (self: UDataComponentRecord, ValidationFunction: (ValidationDummy: UDataComponentValidationDummy) -> any) -> (),
	Unarchive: (self: UDataComponentRecord, Attempts: number?, YieldTime: number?) -> boolean,
	OnConnect: (self: UDataComponentRecord) -> UDataComponentCallbackFunctions,
	SwapTransaction: (self: UDataComponentRecord, OtherPlayerData: UDataComponentRecord, Transaction: (ThisCurrentData : UDataComponentEditor, OtherCurrentData : UDataComponentEditor) -> ()) -> boolean,
	SmartCleanCache: (self: UDataComponentRecord, Interval: number?) -> (),
	EndCacheCleaning: (self: UDataComponentRecord) -> (),
	GetVersion: (self: UDataComponentRecord) -> number,
	BroadcastCurrentData: (self: UDataComponentRecord, BroadcastName: string, DetailedThings: any?) -> boolean,
	WaitForBroadcastPacket: (self: UDataComponentRecord, BroadcastName: string) -> UDataComponentBroadcast,	
	SendLocalBroadcast: (self: UDataComponentRecord, LocalBroadcastName: string, Password: string, DetailedThings: any?) -> boolean,
	ListenToLocalBroadcast: (self: UDataComponentRecord, LocalBroadcastName: string, Password: string, Callback: (Key: string, BroadcastData: UDataComponentBroadcast) -> ()) -> (),
	CloseLocalBroadcastListener: (self: UDataComponentRecord, LocalBroadcastName: string, Password: string) -> (),
	
	Key : string | number,
	Owner : Player?,
	IsArchived : boolean
}

export type UDataComponentCallbackConnection = {
	Disconnect: (self: UDataComponentCallbackConnection) -> (),
	DisconnectAfterCalled: (self: UDataComponentCallbackConnection) -> (),
	Wait: (self: UDataComponentCallbackConnection) -> (string, any),
	IsConnected: (self: UDataComponentCallbackConnection) -> boolean,
}

export type UDataComponentCallbackFunctions = {
	OnDataLoading: (self: UDataComponentCallbackFunctions, Callback: (Key: string) -> ()) -> UDataComponentCallbackConnection,
	OnDataLoaded: (self: UDataComponentCallbackFunctions, Callback: (Key: string, CurrentData: any) -> ()) -> UDataComponentCallbackConnection,
	OnDataSaving: (self: UDataComponentCallbackFunctions, Callback: (Key: string) -> ()) -> UDataComponentCallbackConnection,
	OnDataSaved: (self: UDataComponentCallbackFunctions, Callback: (Key: string, CurrentData: any) -> ()) -> UDataComponentCallbackConnection,
	OnDataArchived: (self: UDataComponentCallbackFunctions, Callback: (Key: string, ArchivedData: any) -> ()) -> UDataComponentCallbackConnection,
	OnDataUnarchived: (self: UDataComponentCallbackFunctions, Callback: (Key: string, UnarchivedData: any) -> ()) -> UDataComponentCallbackConnection,
	OnDataRecovery: (self: UDataComponentCallbackFunctions, Callback: (Key: string, CurrentData: any) -> ()) -> UDataComponentCallbackConnection,
	OnDataCached: (self: UDataComponentCallbackFunctions, Callback: (Key: string, CurrentData: any) -> ()) -> UDataComponentCallbackConnection,
	OnDataRemoved: (self: UDataComponentCallbackFunctions, Callback: (Key: string, RemovedData: any) -> ()) -> UDataComponentCallbackConnection,
	OnDataBinding: (self: UDataComponentCallbackFunctions, Callback: (Key: string, Data: any) -> ()) -> UDataComponentCallbackConnection,
	OnDataUnbinding: (self: UDataComponentCallbackFunctions, Callback: (Key: string, Data: any) -> ()) -> UDataComponentCallbackConnection,
	OnDataBindExpired: (self: UDataComponentCallbackFunctions, Callback: (Key: string) -> ()) -> UDataComponentCallbackConnection,
	OnDataBindRefreshed: (self: UDataComponentCallbackFunctions, Callback: (Key: string) -> ()) -> UDataComponentCallbackConnection,
	OnCacheCleaned: (self: UDataComponentCallbackFunctions, Callback: (Key: string) -> ()) -> UDataComponentCallbackConnection,
	OnTransactionBegin: (self: UDataComponentCallbackFunctions, Callback: (Key: string, WithKey: string) -> ()) -> UDataComponentCallbackConnection,
	OnTransactionFiltered: (self: UDataComponentCallbackFunctions, Callback: (WhoKey: string, FilteredObject: any) -> ()) -> UDataComponentCallbackConnection,
	OnTransactionEnded: (self: UDataComponentCallbackFunctions, Callback: (Key: string, WithKey: string, Results: any) -> ()) -> UDataComponentCallbackConnection,
	OnReleased: (self: UDataComponentCallbackFunctions, Callback: (Key: string) -> ()) -> UDataComponentCallbackConnection,
	OnDataError: (self: UDataComponentCallbackFunctions, Callback: (Key: string, Reason: string) -> ()) -> UDataComponentCallbackConnection,
	OnSendingBroadcast: (self: UDataComponentCallbackFunctions, Callback: (Key: string, BroadcastName: string, BroadcastData: UDataComponentBroadcast) -> ()) -> UDataComponentCallbackConnection,
	OnReceivingBroadcast: (self: UDataComponentCallbackFunctions, Callback: (Key: string, BroadcastName: string, BroadcastData: UDataComponentBroadcast) -> ()) -> UDataComponentCallbackConnection,
	OnLocalBroadcastListenerReady: (self: UDataComponentCallbackFunctions, Callback: (Key: string, LocalBroadcastName: string) -> ()) -> UDataComponentCallbackConnection,
	OnLocalBroadcastListenerCalled: (self: UDataComponentCallbackFunctions, Callback: (Key: string, LocalBroadcastName: string) -> ()) -> UDataComponentCallbackConnection,
	OnLocalBroadcastListenerClosed: (self: UDataComponentCallbackFunctions, Callback: (Key: string, LocalBroadcastName: string) -> ()) -> UDataComponentCallbackConnection
}

export type UDataComponentInfo = {
	GetPlayerData: (self: UDataComponentInfo, Key: string | number, Callbacks: {UDataComponentCallbackFunctions?}) -> UDataComponentRecord,
	GetLocalData: (self: UDataComponentInfo, Callbacks: {UDataComponentCallbackFunctions?}) -> UDataComponentRecord,
	GetDataStoreName: (self: UDataComponentInfo) -> string | number,

	Enabled : boolean,
	ValidationEnabled : boolean,
	CallbackEnabled : boolean,
	RequestTimestampCooldown : number,
	WALEnabled : boolean,
	DefaultDataLoadingAttempts : number,
	DefaultDataLoadingYieldDuration : number,
	DefaultSaveAttempts : number,
	DefaultYieldAttempts : number,
	MaxKeyLength : number,
	BackupEnabled : boolean,
	BackupYieldDuration : number,
	StrictlyUnallowDetaching : boolean,
	BackupRemovedWhenDetached : boolean,
	AutoSaveEnabled : boolean,
	AutoSaveInterval : number,
	WALDataSuffix : string,
	WALMaxEntries : number,
	BackupDataSuffix : string,
	ExclusiveAccessEnabled : boolean,
	ExclusiveAccessExpiration : number,
	SwappingEnabled : boolean,
	SwappingCooldown : number,
	CacheCleaningEnabled : boolean,
	CacheCleaningInterval : number,
	DataBlueprint : {any?},
	ErrorReasonNamespace : string,
	LocalDataNamespace : string,
	MessagingEnabled : boolean,
	MessagingNamespace : string,
	MessagingCooldown : number,
	MessagingSendingCooldown : number,
	MessagingReceivingCooldown : number,
	MessagingLocalListeningCooldown : number,
	ServerClaimerSuffix : string,
	ArchivationEnabled : boolean,
	ArchivationSuffix : string,
	MessagingDebugEnabled : boolean,
	MaxDataSavingPerTick : number,
}

export type UDataComponentEditor = {
	Give: (self: UDataComponentEditor, ThisData: any, Value: any) -> (),
}

export type UDataComponentBroadcast = {
	Key : string | number,
	Data : any,
	BroadcasterJobId : number,
	BroadcasterUserId : number,
	BroadcastTime : number,
	Other : any
}

export type UDataComponent = {
	InDataInfo: (DataStoreName: string, Scope: string?, Configurations: {any?}) -> UDataComponentInfo,
	QuickSetup: (DataStoreName: string, Scope: string?, Configurations: {any?}) -> UDataComponentInfo,
}

local function InPlayerData(meta, Key)
	assert(typeof(meta) == "table", "InPlayerData must be called from a UDataComponentInfo object")
	assert(typeof(Key) == "string" or typeof(Key) == "number", "Key must be a string or id")

	local record = {}
	record.Key = Key
	record.Owner = nil
	record.IsArchived = false

	local function dispatch(key, eventName, ...)
		if not meta.CallbackEnabled then return end
		
		local args = table.pack(...)
		local callbacks = meta._UDataComponentDynamicCallbacks:Get(eventName)

		local suc, err = pcall(function()
			local callbacks = meta._UDataComponentCallbacks:Get(eventName)

			if callbacks then
				local callback = callbacks[key]
				if not callback then return end

				callback(key, table.unpack(args))
			end
		end)

		if not suc then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent's callback error happened, reason: " .. tostring(err))
		end

		if callbacks then
			local callback = callbacks[key]
			if not callback then return end

			local potentials = {}
			for id, cb in pairs(callback) do
				table.insert(potentials, cb)
			end

			for _, cb in ipairs(potentials) do
				local dysuc, dyerr = pcall(cb, key, table.unpack(args))
				if not dysuc then 
					warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent's callback error happened, reason: " .. tostring(dyerr))
				end
			end
		end
	end
	
	local function encrypt(text, key)
		if text == "" or key == "" then
			return ""
		end
		
		local encrypted = {}
		local length = #key
		for i = 1, #text do
			local t = string.byte(text, i)
			local k = string.byte(key, (i - 1) % length + 1)
			encrypted[i] = string.char(bit32.bxor(t, k))
		end
		
		return table.concat(encrypted)
	end

	local function deepclone(tab)
		if typeof(tab) ~= "table" then
			return tab
		end		
		local newTab = {}

		for k, v in pairs(tab) do
			newTab[k] = deepclone(v)
		end

		return newTab
	end

	local function get_blueprint()
		return deepclone(meta.DataBlueprint)
	end

	local function is_still_exclusive(key, strid)
		assert(typeof(strid) == "string")

		local days = meta.ExclusiveAccessExpiration
		local now = workspace:GetServerTimeNow()
		local dayInSec = 60 * 60 * 24

		local timeout = dayInSec * days

		local id = tonumber(strid)
		if id == nil then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to get the ID of player while trying to check the exlusive binding.")
			return false
		end

		local bound = meta._BoundRegistry[key]
		if not bound then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed because the data isn't bound with this player.")
			return false
		end

		local boundId, since = bound.UserId, bound.Since
		if not id or not since then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to get ID or time since bound from this player.")
			return false
		end

		return id == boundId and now - since < timeout
	end

	local function match_key(oriKey, strid : string)
		local key = tostring(oriKey)
		strid = tostring(strid)

		if key == "" or strid == "" then
			dispatch(oriKey, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Empty key or id is not allowed.")
			return false
		end

		local startpos, endpos = string.find(strid, key, 1, true)
		if startpos == nil or endpos == nil then 
			dispatch(oriKey, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to match key with id.")
			return false 
		end

		local obtainedId = string.sub(strid, startpos, endpos)
		if obtainedId == strid and is_still_exclusive(oriKey, strid) then
			return true
		end

		dispatch(oriKey, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: The data of this key isn't bound with this player.")
		return false
	end

	local function ensure_exc_player(key, player)
		assert(typeof(player) == "Instance" and player:IsA("Player"))

		if not meta.ExclusiveAccessEnabled then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Exclusive access is disabled.")
			return false
		end

		if RunService:IsClient() then
			warn("[" .. meta.ErrorReasonNamespace .. "]: Currently trying to set player as exclusive, named " .. player.Name ..  ", but called from clientt.")
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Currently trying to set player as exclusive, named " .. player.Name ..  ", but called from client.")
			return false
		end

		local strid = tostring(player.UserId)

		return match_key(key, strid)
	end

	local function call_backup(backup)
		local obtainedData = nil

		if not meta.BackupEnabled then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Backup is disabled.")
			return false, get_blueprint()
		end

		local _attempts = 0
		repeat
			local suc, err = pcall(function()
				obtainedData = backup:GetAsync(Key)
			end)

			if not suc then
				warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent's Get error happened, reason: " .. tostring(err))
				dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to obtain data from backup, trying to get data again...")
			end

			_attempts += 1
			task.wait(meta.BackupYieldDuration or 3)
		until _attempts >= meta.DefaultDataLoadingAttempts or obtainedData ~= nil

		if obtainedData == nil then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot check the record of the data from this key from backup")
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to obtain data from backup, switching data to template/blueprint")

			return false, get_blueprint()
		end

		return true, obtainedData
	end

	local function write_data(data : DataStore, key, currentData)
		local dataSuccess, err = pcall(function()
			return data:UpdateAsync(key, function(old)
				return currentData				
			end)
		end)

		if not dataSuccess then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent unable to write Data, reason: " .. tostring(err))
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to write Data.")

			return false, nil, "write_data_failed"
		end

		local clone = deepclone(currentData)
		dispatch(key, "OnDataSaved", clone)
		
		return true, dataSuccess, "write_data_success"
	end

	local function write_backup(backup : DataStore, key, currentData)
		if not meta.BackupEnabled then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Backup is disabled.")
			return false, nil, "backup_disabled"
		end

		local backupSuccess, err = pcall(function()
			return backup:UpdateAsync(key, function(old)
				return currentData				
			end)
		end)

		if not backupSuccess then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent unable to write Data to backup, reason: " .. tostring(err))
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to write Data to backup.")

			return false, nil, "write_backup_failed"
		end

		return true, backupSuccess, "write_backup_success"
	end

	local function write_wal_optionally(wal : DataStore, data : DataStore, backup : DataStore, key, currentData)
		if not meta.WALEnabled then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: WAL is disabled.")
			return false, nil, "wal_disabled"
		end

		local walSuccess, err = pcall(function()
			wal:UpdateAsync(key, function(old)
				return currentData				
			end)
		end)

		if not walSuccess then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent unable to write WAL before actual Data, reason: " .. tostring(err))
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to write WAL before actual Data.")

			return false, nil, "write_wal_failed"
		end

		local dataSuccess, _, _ = write_data(data, key, currentData)
		local backupSuccess, _, _ = write_backup(backup, key, currentData)
		
		if dataSuccess and backupSuccess and walSuccess then
			pcall(function()
				wal:RemoveAsync(key)
			end)
		else
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent unable to write Data or/and Backup, WAL remained for backup, reason: " .. tostring(err))
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to write Data or/and Backup, WAL remained for backup soon.")

			return false, nil, "write_data_orand_backup_failed"
		end

		return true, walSuccess, "write_wal_success"
	end
	
	local function is_key_owner_online(key)
		local data = meta._DataCache[key]
		if typeof(data) ~= "table" then return false end
		
		if data.__bounds and data.__bounds.id then
			return Players:GetPlayerByUserId(data.__bounds.id) ~= nil
		end
		
		local isId = tonumber(key)
		if isId then
			return Players:GetPlayerByUserId(isId) ~= nil
		end
		
		return true
	end
	
	local function is_key_pending(key)
		for i, pending in ipairs(meta._SavePendingQueue) do
			if pending.Key == key then
				return true
			end
		end
		
		return false
	end

	local function call_flush(key, data : DataStore, wal : DataStore, backup : DataStore)
		local currentData = meta._DataCache[key]
		if not currentData then 
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Data is not loaded and cannot able to find the data record from cache.")
			return false 
		end

		local status, _, codeStatus = write_wal_optionally(wal, data, backup, key, currentData)
		if codeStatus == "wal_disabled" then
			write_data(data, key, currentData)
			write_backup(backup, key, currentData)
		end
		
		for i, pending in ipairs(meta._SavePendingQueue) do
			if pending.Key == key then
				table.remove(meta._SavePendingQueue, i)
				break
			end
		end

		return true
	end
	
	local function call_cache_cleanup(key, interval, data : DataStore, wal : DataStore, backup : DataStore)
		if is_key_owner_online(key) then return false end
		if is_key_pending(key) then return false end
		if meta._LockSessions:IsLocked(key) then return false end

		local now = workspace:GetServerTimeNow()
		local lastTouch = math.max(meta._GetTimestamp[key] or 0, meta._SaveTimestamp[key] or 0)
		if now - lastTouch < interval then return false end

		call_flush(key, data, wal, backup)
				
		meta._DataCache[key] = nil
		meta._AutosaveTimestamp[key] = nil
		meta._GetTimestamp[key] = nil
		meta._SaveTimestamp[key] = nil
		
		dispatch(key, "OnCacheCleaned", key)
		
		return true
	end

	local function call_autosave(key, data : DataStore, wal : DataStore, backup : DataStore)
		local calledSince = workspace:GetServerTimeNow()

		while meta.Enabled and meta._DataCache[key] and meta._AutosaveTimestamp[key] and not meta._ShutdownCalled do
			local now = workspace:GetServerTimeNow()
			local currentData = meta._DataCache[key]

			if now - calledSince >= meta.AutoSaveInterval then
				local status, _, codeStatus = write_wal_optionally(wal, data, backup, key, currentData)

				if codeStatus == "wal_disabled" then
					local _, _, _ = write_data(data, key, currentData)
					local _, _, _ = write_backup(backup, key, currentData)
				end
								
				calledSince = now
			end

			task.wait(1)
		end
	end

	local function create_lock_timer(ownerId, timeout)
		if not meta._LockTimers[ownerId] then
			meta._LockTimers[ownerId] = coroutine.create(function()
				local startedSince = workspace:GetServerTimeNow()

				while meta.Enabled and meta._LockTimers[ownerId] and not meta._ShutdownCalled do
					local tickedNow = workspace:GetServerTimeNow()
					if tickedNow - startedSince >= timeout then
						record:ReleaseLockSession(ownerId)						
						break
					end
					
					task.wait(1)
				end

				meta._LockTimers[ownerId] = nil
			end)

			coroutine.resume(meta._LockTimers[ownerId])
		end
	end
	
	local function listen_local_broadcast(broadcastName, realName, key, callbackFunc)
		if meta._LocalBroadcastListeners[broadcastName] then return end
		
		local entry = { Key = key, Schedule = nil }
		
		local success, result = pcall(function()
			return MessagingService:SubscribeAsync(broadcastName, function(message)
				dispatch(key, "OnLocalBroadcastListenerCalled", realName)
				callbackFunc(message.Data.Key, message.Data)
			end)
		end)
		
		if not success then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to listen local broadcast, reason: " .. tostring(result))	
			return
		end
		
		entry.Schedule = result
		meta._LocalBroadcastListeners[broadcastName] = entry
		dispatch(key, "OnLocalBroadcastListenerReady", realName)
	end

	local function run_save_queue()
		if meta._IsRunning or meta._ShutdownCalled then return end
		meta._IsRunning = true

		task.spawn(function()
			while meta.Enabled and not meta._ShutdownCalled do
				local count = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
				local processed = 0
				local max = meta.MaxDataSavingPerTick

				while #meta._SavePendingQueue > 0 and processed < max and count > 0 and not meta._ShutdownCalled do
					local obj = table.remove(meta._SavePendingQueue, 1) -- First in first out

					local currentData = meta._DataCache[obj.Key]
					if currentData then
						local function commit()
							local latestData = meta._DataCache[obj.Key]
							if not latestData then return end
							
							latestData.__version = (latestData.__version or 0) + 1
							local status, _, message = write_wal_optionally(obj.WAL, obj.Data, obj.Backup, obj.Key, latestData)
							
							if message == "wal_disabled" then
								local _, _, _ = write_data(obj.Data, obj.Key, latestData)
								local _, _, _ = write_backup(obj.Backup, obj.Key, latestData)
							end
						end

						if obj.IsSafe then
							meta._LockSessions:Do(obj.Key, commit)
						else
							commit()
						end
					end

					processed += 1
					count -= 1
				end

				task.wait(1)
			end
		end)
	end

	local function enqueue_save(key, data, wal, backup, isSafe)
		for _, pending in ipairs(meta._SavePendingQueue) do
			if pending.Key == key then
				return false
			end
		end

		table.insert(meta._SavePendingQueue, {
			Key = key,
			Data = data,
			WAL = wal,
			Backup = backup,
			IsSafe = isSafe
		})

		run_save_queue()
		return true
	end

	local function is_data_valid(thisData, thisValue)
		if not meta.ValidationEnabled then 
			return true 
		end
		
		local trackedValidations = meta._TrackedValidations and meta._TrackedValidations[record.Key]
		if not trackedValidations then return true end
		
		local predicate = trackedValidations[thisData]
		if not predicate then
			return true
		end
		
		return predicate(thisValue)
	end

	local function is_schema_valid(thisData, thisValue)
		if not meta.ValidationEnabled then return true end

		local trackedSchemas = meta._TrackedSchemas and meta._TrackedSchemas[record.Key]
		if not trackedSchemas then return true end

		local schema = trackedSchemas[thisData]
		if not schema then return true end

		return typeof(thisValue) == schema
	end

	local function clamp_value(thisData, thisValue)
		if not meta.ValidationEnabled then return thisValue end

		local trackedClamps = meta._TrackedClamps and meta._TrackedClamps[record.Key]
		if not trackedClamps then return thisValue end

		local clampMin = trackedClamps[thisData] and trackedClamps[thisData].Min
		local clampMax = trackedClamps[thisData] and trackedClamps[thisData].Max
		
		if typeof(thisValue) ~= "number" then return thisValue end
		
		if clampMin ~= nil and clampMax == nil then return math.max(thisValue, clampMin) 
		elseif clampMax ~= nil and clampMin == nil then return math.min(thisValue, clampMax) 
		elseif clampMin ~= nil and clampMax ~= nil then return math.clamp(thisValue, clampMin, clampMax) end
		
		return thisValue
	end
	
	local function check_validation(key, thisData, thisValue)
		if not is_schema_valid(thisData, thisValue) then
			return false, nil
		end
				
		local value = clamp_value(thisData, thisValue)
		
		if not is_data_valid(thisData, value) then
			return false, nil
		end
		
		return true, value
	end
	
	local function write_wal_immediately(key, wal, data)
		local currentData = meta._DataCache[key]
		if not currentData then return end
		
		if meta.WALEnabled then
			local success, err = pcall(function()
				wal:UpdateAsync(key, function(old)
					return currentData
				end)
			end)
			
			if not success then
				dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to save WAL immediately, meaning the last data record haven't happened.")
			end
					else
			local success, err = pcall(function()
				data:UpdateAsync(key, function(old)
					return currentData
				end)
			end)
			
			if not success then
				dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to save last data, meaning the last data record haven't happened.")
			end
		end
	end
	
	local function broadcast_owner_claimer(key, plrId, now)
		if not meta.MessagingEnabled then return end
		
		local topic = meta.MessagingNamespace .. meta.ServerClaimerSuffix
		local message = {
			PossessedKey = key,
			PossessedUserId = plrId,
			PossessedSince = now,
			PossessiveServerId = game.JobId
		}
		
		local success, err = pcall(function()
			MessagingService:PublishAsync(topic, message)
		end)
		
		if not success then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to claim ownership of key.")
		end
	end

	local function create_exclusive_safety(key)
		Players.PlayerRemoving:Connect(function(player)
			local now = workspace:GetServerTimeNow()
			for key, bound in pairs(meta._BoundRegistry) do
				if bound.UserId == player.UserId then
					if not meta._DataCache[key] or not meta._DataCache[key].__bounds then continue end
					meta._DataCache[key].__bounds.since = now
					
					write_wal_immediately(key, meta._CurrentWALDataStore, meta._CurrentDataStore)
					meta._BoundRegistry[key] = nil
				end
			end

			for key, data in pairs(meta._DataCache) do
				if typeof(data) == "table" and data.__bounds and data.__bounds.id == player.UserId then
					meta._DataCache[key] = nil
					
					for i, pending in ipairs(meta._SavePendingQueue) do
						if pending.Key == key then
							table.remove(meta._SavePendingQueue, i)
							break
						end
					end
					
					meta._GetTimestamp[key] = nil
					meta._SaveTimestamp[key] = nil
					meta._AutosaveTimestamp[key] = nil
				end
			end
		end)

		game:BindToClose(function()
			meta._ShutdownCalled = true

			local schedule = { pending = 0 }
			for key, bound in pairs(meta._BoundRegistry) do				
				schedule.pending += 1
				task.spawn(bound.Coroutine, schedule)
			end

			local remainingTime = 0
			while schedule.pending > 0 and remainingTime < 25 do
				task.wait(1)
				remainingTime += 1
			end
		end)
	end
	
	local function unbind_exclusive_access(key)
		if not meta.ExclusiveAccessEnabled then return end
		if not meta._BoundRegistry[key] then return end

		meta._BoundRegistry[key] = nil
		dispatch(key, "OnDataUnbinding", meta._DataCache[key])
	end
	
	local function claim_ownership()
		if meta._ClaimerSyncCalled then return end
		meta._ClaimerSyncCalled = true

		if not meta.MessagingEnabled then return end

		local topic = meta.MessagingNamespace .. meta.ServerClaimerSuffix
		local success, err = pcall(function()
			MessagingService:SubscribeAsync(topic, function(message)
				local payload = message.Data
				if payload.PossessiveServerId == game.JobId then return end

				local key = payload.PossessedKey
				local currentBound = meta._BoundRegistry[key]
				if not currentBound then return end

				if payload.PossessedSince >= currentBound.Since then
					if meta._DataCache[key] then
						call_flush(key, meta._CurrentDataStore, meta._CurrentWALDataStore, meta._CurrentBackupDataStore)
					end

					unbind_exclusive_access(key)
					dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: A server has been claimed this key, but it's still bounding in this server. So that, UDataComponent decided to remove the died exclusive access.")
				end
			end)
		end)
		
		if not success then
			warn("[" .. meta.ErrorReasonNamespace .. "]: Unable to create a claimer broadcast, reason: " .. tostring(err))
		end
	end
	
	local function run_exclusive_timer(data, wal, backup)
		if meta._ExclusiveTimerCalled or meta._ShutdownCalled then return end
		meta._ExclusiveTimerCalled = true

		task.spawn(function()
			while meta.Enabled and meta.ExclusiveAccessEnabled and not meta._ShutdownCalled do
				local now = workspace:GetServerTimeNow()

				for key, bound in pairs(meta._BoundRegistry) do
					local since = bound.Since

					local dayInSec = 24 * 60 * 60
					local timeout = dayInSec * meta.ExclusiveAccessExpiration

					if now - since > timeout then
						if not meta._DataCache[key] then continue end
						
						meta._DataCache[key].__bounds = nil
						call_flush(key, data, wal, backup)

						unbind_exclusive_access(key)
						dispatch(key, "OnDataBindExpired")
					end
				end

				task.wait(1)
			end
		end)
	end

	local function bind_exclusive_access(key, ar, timeSinceBound, player : Player)
		if not meta.ExclusiveAccessEnabled then 
			return 
		end
		if not player then return end

		if meta._BoundRegistry[key] then
			return
		end
		
		meta._BoundRegistry[key] = {
			UserId = player.UserId,
			Since = timeSinceBound,
			Coroutine = function(schedule)		
				local now = workspace:GetServerTimeNow()
				if meta._DataCache[key] and meta._DataCache[key].__bounds then
					meta._DataCache[key].__bounds.since = now -- update the timestamp of subscription
				end
				
				write_wal_immediately(key, meta._CurrentWALDataStore, meta._CurrentDataStore)
				
				if schedule and schedule.pending ~= nil then
					schedule.pending -= 1
				end
			end
		}

		if not meta._ExclusiveSafetyCalled then
			meta._ExclusiveSafetyCalled = true
			create_exclusive_safety(key)
		end
		
		ar.Owner = player
		dispatch(key, "OnDataBinding", meta._DataCache[key])
		run_exclusive_timer(meta._CurrentDataStore, meta._CurrentWALDataStore, meta._CurrentBackupDataStore)
		
		claim_ownership()
		broadcast_owner_claimer(key, player.UserId, timeSinceBound)
	end

	function record:Get(LoadRecovery : boolean?, ExclusivePlayer: Player?)
		dispatch(record.Key, "OnDataLoading")

		local currentData = meta._CurrentDataStore
		local currentBackupData = meta._CurrentBackupDataStore
		local currentWALData = meta._CurrentWALDataStore

		local _attempts = 0
		local obtainedData = nil

		if meta._DataCache[record.Key] then
			obtainedData = meta._DataCache[record.Key]
			
			if obtainedData.__bounds then
				local id = obtainedData.__bounds.id
				local since = obtainedData.__bounds.since

				local dayInSec = 60 * 60 * 24
				local days = meta.ExclusiveAccessExpiration or 1

				local timeout = dayInSec * days

				if workspace:GetServerTimeNow() - since < timeout then
					local plr = Players:GetPlayerByUserId(id)
					bind_exclusive_access(record.Key, record, since, plr)
				else
					dispatch(record.Key, "OnDataBindExpired")
				end
			end
			
			local status, result = false, deepclone(obtainedData)
			if ExclusivePlayer then
				if ensure_exc_player(record.Key, ExclusivePlayer) then
					status = true
				else
					dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Get() returns blueprint/template of data, because the data is bound to another player.")
					status, result = false, get_blueprint()
				end
			end

			local clone = deepclone(result)
			dispatch(record.Key, "OnDataLoaded", clone)
			return true, result
		end

		local now = workspace:GetServerTimeNow()
		if meta._GetTimestamp[record.Key] and now - meta._GetTimestamp[record.Key] < meta.RequestTimestampCooldown then 
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Get() halted, waiting for cooldown.")
			return false, nil 
		end
		meta._GetTimestamp[record.Key] = now

		if LoadRecovery then
			local recoverStatus, message = record:TryToRecover()

			if recoverStatus then
				dispatch(record.Key, "OnDataRecovery")
			end
		end

		repeat
			local suc, err = pcall(function()
				obtainedData = currentData:GetAsync(Key)
			end)

			if not suc then
				warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent's Get error happened, reason: " .. tostring(err))
				dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: happened in Get's function, caused by failed to obtain data, trying to get data again...")		
			end

			_attempts += 1
			task.wait(meta.DefaultDataLoadingYieldDuration or 3)
		until _attempts >= meta.DefaultDataLoadingAttempts or obtainedData ~= nil

		if obtainedData == nil then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot obtain the record of the data from this key, trying to get data from backup")
			dispatch(record.Key, "OnDataError", "Error happened while trying to obtain data, trying to obtain data from backup...")

			local status, backupData = call_backup(currentBackupData)
			local dataResult = if status then backupData else get_blueprint()
			
			if not meta._DataCache[record.Key] then
				meta._DataCache[record.Key] = dataResult
			end

			if dataResult.__bounds then
				local id = dataResult.__bounds.id
				local since = dataResult.__bounds.since

				local dayInSec = 60 * 60 * 24
				local days = meta.ExclusiveAccessExpiration or 1

				local timeout = dayInSec * days

				if workspace:GetServerTimeNow() - since < timeout then
					local plr = Players:GetPlayerByUserId(id)
					bind_exclusive_access(record.Key, record, since, plr)
				else
					dispatch(record.Key, "OnDataBindExpired")
				end
			end
			local _, _, _ = write_data(currentData, record.Key, dataResult) -- this will rewrite the main datastore when backup un/obtained the data
			
			local result = dataResult
			if ExclusivePlayer then
				if ensure_exc_player(record.Key, ExclusivePlayer) then
					status = true
				else
					dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Get() returns blueprint/template of data, because the data is bound to another player.")
					status, result = false, get_blueprint()
				end
			end
			
			local clone = deepclone(result)
			dispatch(record.Key, "OnDataLoaded", clone)
			return status, result
		end
		
		if not meta._DataCache[record.Key] then
			meta._DataCache[record.Key] = obtainedData
		end		
		
		if obtainedData.__bounds then
			local id = obtainedData.__bounds.id
			local since = obtainedData.__bounds.since

			local dayInSec = 60 * 60 * 24
			local days = meta.ExclusiveAccessExpiration or 1

			local timeout = dayInSec * days

			if workspace:GetServerTimeNow() - since < timeout then
				local plr = Players:GetPlayerByUserId(id)
				bind_exclusive_access(record.Key, record, since, plr)
			else
				dispatch(record.Key, "OnDataBindExpired")
			end
		end
		
		local clone = deepclone(obtainedData)
		dispatch(record.Key, "OnDataLoaded", clone)

		if not meta._AutosaveTimestamp[record.Key] then
			meta._AutosaveTimestamp[record.Key] = coroutine.create(call_autosave)

			coroutine.resume(meta._AutosaveTimestamp[record.Key], record.Key, currentData, currentWALData, currentBackupData)
		end

		if ExclusivePlayer and obtainedData then
			if ensure_exc_player(record.Key, ExclusivePlayer) then
				return true, obtainedData
			else
				dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Get() returns blueprint/template of data, because the data is bound to another player.")
				return false, get_blueprint()
			end
		end

		return true, obtainedData
	end

	function record:Save(Data: any, SegmentIndex: number?)
		local now = workspace:GetServerTimeNow()
		if meta._SaveTimestamp[record.Key] and now - meta._SaveTimestamp[record.Key] < meta.RequestTimestampCooldown then 
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Save() halted, waiting for cooldown.")
			return false 
		end
		meta._SaveTimestamp[record.Key] = now

		dispatch(record.Key, "OnDataSaving")

		if not meta._DataCache[record.Key] then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save data, because data is not loaded yet.")
			return false
		end

		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		local rejected = {}

		if SegmentIndex then
			local success, value = check_validation(record.Key, SegmentIndex, Data)
			
			if success then
				meta._DataCache[record.Key][SegmentIndex] = value
			else
				table.insert(rejected, SegmentIndex)
			end
		else
			local accepted = deepclone(meta._DataCache[record.Key])
			
			for thisData, thisValue in pairs(Data) do
				local success, value = check_validation(record.Key, thisData, thisValue)
				
				if success then
					accepted[thisData] = value
				else
					table.insert(rejected, thisData)
				end
			end
			
			meta._DataCache[record.Key] = accepted
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save some of datas, because those are not valid.")
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end

		enqueue_save(record.Key, data, wal, backup, false)

		return true
	end

	function record:Write(WritingFunction: (CurrentData: any) -> any)
		local now = workspace:GetServerTimeNow()
		if meta._SaveTimestamp[record.Key] and now - meta._SaveTimestamp[record.Key] < meta.RequestTimestampCooldown then return false end
		meta._SaveTimestamp[record.Key] = now

		dispatch(record.Key, "OnDataSaving")

		if not meta._DataCache[record.Key] then
			return false
		end

		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		local clone = deepclone(meta._DataCache[record.Key])
		local resultFunction = WritingFunction(clone)

		if type(resultFunction) ~= "table" then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent's Write function must returns the/a table of param.")
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Write function isn't returning the table of param.")

			return false
		end

		local rejected = {}
		local filteredObjs = {}

		for thisData, thisValue in pairs(resultFunction) do
			filteredObjs[thisData] = thisValue
		end
		
		for thisData, thisValue in pairs(filteredObjs) do
			local accepted, value = check_validation(record.Key, thisData, thisValue)
			
			if not accepted then table.insert(rejected, thisData) continue end
			meta._DataCache[record.Key][thisData] = value
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save some of datas, because those are not valid.")
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
		
		enqueue_save(record.Key, data, wal, backup, false)
		return true
	end

	function record:Flush()
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		local wal = meta._CurrentWALDataStore

		return call_flush(record.Key, data, wal, backup)
	end

	function record:TryToRecover()
		if not meta.WALEnabled then
			return false, "wal_disabled"
		end

		local wal = meta._CurrentWALDataStore

		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		local recoveredData = nil
		local _walAttempts = 0
		repeat
			local status, err = pcall(function()
				recoveredData = wal:GetAsync(record.Key)
			end)

			if not status then
				warn("[" .. meta.ErrorReasonNamespace .. "]: Unexpected error happened when trying to recover data from WAL, with reason: " .. tostring(err))
				dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unexpected error happened, when trying to recover data that was dead from WAL.")
			end

			_walAttempts += 1
			task.wait(meta.DefaultDataLoadingYieldDuration or 3)
		until _walAttempts >= meta.DefaultDataLoadingAttempts or recoveredData ~= nil

		if not recoveredData then
			warn("[" .. meta.ErrorReasonNamespace .. "]: There is no WAL history to recover the data.")
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: There is no WAL history to recover the data, meaning the data has been successfully written or no record tracked.")

			return false, "failed_recover"
		end

		local status, _, message = write_wal_optionally(wal, data, backup, record.Key, recoveredData)

		if not status then
			warn("[" .. meta.ErrorReasonNamespace .. "]: Failed to recover data from WAL, with reason: " .. tostring(message))
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed to recover data from WAL.")

			return false, "failed_recover"
		end

		return true, "success"
	end

	function record:Detach()
		if meta.StrictlyUnallowDetaching then
			return false, "unallowed_detach"
		end

		local currentData = meta._DataCache[record.Key]
		if not currentData then
			return false, "not_cached"
		end
		local clone = deepclone(currentData)

		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		if meta.ArchivationEnabled then
			local archive = meta._CurrentArchivedDataStore
			pcall(function()
				archive:UpdateAsync(record.Key .. "_" .. workspace:GetServerTimeNow(), function()
					return currentData
				end)
			end)

			dispatch(record.Key, "OnDataArchived", clone)
			record.IsArchived = true
		end

		pcall(function()
			data:RemoveAsync(record.Key)
		end)

		if meta.BackupRemovedWhenDetached then
			pcall(function()
				backup:RemoveAsync(record.Key)
			end)
		end

		meta._BoundRegistry[record.Key] = nil
		meta._SaveTimestamp[record.Key] = nil
		meta._GetTimestamp[record.Key] = nil
		meta._DataCache[record.Key] = nil
		meta._AutosaveTimestamp[record.Key] = nil
		meta._TrackedClamps[record.Key] = nil
		meta._TrackedSchemas[record.Key] = nil
		meta._TrackedValidations[record.Key] = nil

		for i, pending in ipairs(meta._SavePendingQueue) do
			if pending.Key == record.Key then
				table.remove(meta._SavePendingQueue, i)
				break
			end
		end

		dispatch(record.Key, "OnDataRemoved", clone)
		return true, "success"
	end

	function record:ForceSave(AlongCooldown : boolean, Data: any, SegmentIndex: number?)
		local now = workspace:GetServerTimeNow()
		if AlongCooldown and meta._SaveTimestamp[record.Key] and now - meta._SaveTimestamp[record.Key] < meta.RequestTimestampCooldown then return false end
		meta._SaveTimestamp[record.Key] = now

		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		local wal = meta._CurrentWALDataStore

		dispatch(record.Key, "OnDataSaving")		

		if not meta._DataCache[record.Key] then
			return false
		end

		local rejected = {}

		if SegmentIndex then
			local success, value = check_validation(record.Key, SegmentIndex, Data)

			if success then
				meta._DataCache[record.Key][SegmentIndex] = value
			else
				table.insert(rejected, SegmentIndex)
			end
		else
			local accepted = deepclone(meta._DataCache[record.Key])

			for thisData, thisValue in pairs(Data) do
				local success, value = check_validation(record.Key, thisData, thisValue)

				if success then
					accepted[thisData] = value
				else
					table.insert(rejected, thisData)
				end
			end

			meta._DataCache[record.Key] = accepted
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save some of datas, because those are not valid.")
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end

		local clone = deepclone(meta._DataCache[record.Key])
		local status, _, message = write_wal_optionally(wal, data, backup, record.Key, meta._DataCache[record.Key])

		if not status then
			if message == "wal_disabled" then
				write_data(data, record.Key, meta._DataCache[record.Key])
				write_backup(backup, record.Key, meta._DataCache[record.Key])

				return true
			end

			warn("[" .. meta.ErrorReasonNamespace .. "]: Failed to save data, with reason: " .. tostring(message))
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed to save data.")

			return false
		end

		dispatch(record.Key, "OnDataSaved", clone)
		return true
	end

	function record:ForceWrite(AlongCooldown : boolean, WritingFunction: (CurrentData: any) -> any)
		local now = workspace:GetServerTimeNow()
		if AlongCooldown and meta._SaveTimestamp[record.Key] and now - meta._SaveTimestamp[record.Key] < meta.RequestTimestampCooldown then return false end
		meta._SaveTimestamp[record.Key] = now

		dispatch(record.Key, "OnDataSaving")

		if not meta._DataCache[record.Key] then
			return false
		end

		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		local clone = deepclone(meta._DataCache[record.Key])
		local resultFunction = WritingFunction(clone)

		if type(resultFunction) ~= "table" then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent's Write function must returns the/a table of param.")
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Write function isn't returning the table of param.")

			return false
		end

		local rejected = {}
		local filteredObjs = {}
		
		for thisData, thisValue in pairs(resultFunction) do
			filteredObjs[thisData] = thisValue
		end
		
		for thisData, thisValue in pairs(filteredObjs) do
			local accepted, value = check_validation(thisData, thisValue)
			
			if not accepted then table.insert(rejected, thisData) continue end
			meta._DataCache[record.Key][thisData] = value
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save some of datas, because those are not valid.")
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
		
		local filteredData = meta._DataCache[record.Key]
		local status, _, message = write_wal_optionally(wal, data, backup, record.Key, filteredData)

		if not status then
			if message == "wal_disabled" then
				write_data(data, record.Key, filteredData)
				write_backup(backup, record.Key, filteredData)

				dispatch(record.Key, "OnDataSaved", clone)

				return true
			end

			warn("[" .. meta.ErrorReasonNamespace .. "]: Failed to save data, with reason: " .. tostring(message))
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed to save data.")

			return false
		end

		dispatch(record.Key, "OnDataSaved", clone)
		return true
	end

	function record:SafeGet(LoadRecovery: boolean?, ExclusivePlayer: Player?, LoadAttempts: number?, YieldTime: number?)
		dispatch(record.Key, "OnDataLoading")

		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		local wal = meta._CurrentWALDataStore

		local attempts = LoadAttempts or meta.DefaultDataLoadingAttempts or 5
		local yieldTime = YieldTime or meta.DefaultDataLoadingYieldDuration or 3

		local status = false
		local obtainedData = nil

		if meta._DataCache[record.Key] then
			obtainedData = meta._DataCache[record.Key]
			local clone = deepclone(meta._DataCache[record.Key])
			
			if obtainedData.__bounds then
				local id = obtainedData.__bounds.id
				local since = obtainedData.__bounds.since

				local dayInSec = 60 * 60 * 24
				local days = meta.ExclusiveAccessExpiration or 1

				local timeout = dayInSec * days

				if workspace:GetServerTimeNow() - since < timeout then
					local plr = Players:GetPlayerByUserId(id)
					bind_exclusive_access(record.Key, record, since, plr)
				else
					dispatch(record.Key, "OnDataBindExpired")
				end
			end

			if ExclusivePlayer then
				if ensure_exc_player(record.Key, ExclusivePlayer) then
					status = true
				else
					status, obtainedData = false, get_blueprint()
				end
			else
				status = true
			end

			dispatch(record.Key, "OnDataLoaded", clone)
			return status, obtainedData
		end

		local now = workspace:GetServerTimeNow()
		if meta._GetTimestamp[record.Key] and now - meta._GetTimestamp[record.Key] < meta.RequestTimestampCooldown then return false, nil end
		meta._GetTimestamp[record.Key] = now

		meta._LockSessions:Do(record.Key, function()
			local _attempts = 0

			if LoadRecovery then
				local recoverStatus, message = record:TryToRecover()

				if recoverStatus then
					dispatch(record.Key, "OnDataRecovery")
				end
			end

			repeat
				local success, result = pcall(function()
					obtainedData = data:GetAsync(record.Key)
				end)

				if not success then
					warn("[" .. meta.ErrorReasonNamespace .. "]: Failed to load data, with reason: " .. tostring(result))
					dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed to load data.")
				end

				_attempts += 1
				task.wait(yieldTime)
			until _attempts >= attempts or obtainedData ~= nil

			if obtainedData == nil then
				warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot obtain the record of the data from this key, trying to get data from backup")
				dispatch(record.Key, "OnDataError", "Error happened while trying to obtain data, trying to obtain data from backup...")

				local preStatus, backupData = call_backup(backup)
				local dataResult = if preStatus then backupData else get_blueprint()
				
				if not meta._DataCache[record.Key] then
					meta._DataCache[record.Key] = dataResult
				end

				if dataResult.__bounds then
					local id = dataResult.__bounds.id
					local since = dataResult.__bounds.since

					local dayInSec = 60 * 60 * 24
					local days = meta.ExclusiveAccessExpiration or 1

					local timeout = dayInSec * days

					if workspace:GetServerTimeNow() - since < timeout then
						local plr = Players:GetPlayerByUserId(id)
						bind_exclusive_access(record.Key, record, since, plr)
					else
						dispatch(record.Key, "OnDataBindExpired")
					end
				end
				local _, _, _ = write_data(data, record.Key, dataResult) -- this will rewrite the main datastore when backup un/obtained the data

				status, obtainedData = preStatus, dataResult
			else
				status = true
			end
			
			if not meta._DataCache[record.Key] then
				meta._DataCache[record.Key] = obtainedData
			end	

			if obtainedData.__bounds then
				local id = obtainedData.__bounds.id
				local since = obtainedData.__bounds.since

				local dayInSec = 60 * 60 * 24
				local days = meta.ExclusiveAccessExpiration or 1

				local timeout = dayInSec * days

				if workspace:GetServerTimeNow() - since < timeout then
					local plr = Players:GetPlayerByUserId(id)
					bind_exclusive_access(record.Key, record, since, plr)
				else
					dispatch(record.Key, "OnDataBindExpired")
				end
			end

			if ExclusivePlayer and obtainedData then
				if ensure_exc_player(record.Key, ExclusivePlayer) then
					status = true
				else
					status, obtainedData = false, get_blueprint()
				end
			end
		end)	
		
		if not meta._AutosaveTimestamp[record.Key] then
			meta._AutosaveTimestamp[record.Key] = coroutine.create(call_autosave)

			coroutine.resume(meta._AutosaveTimestamp[record.Key], record.Key, data, wal, backup)
		end

		local clone = deepclone(obtainedData)
		dispatch(record.Key, "OnDataLoaded", clone)

		return status, obtainedData
	end

	function record:SafeSave(Data: any, SegmentIndex: number?)
		local now = workspace:GetServerTimeNow()
		if meta._SaveTimestamp[record.Key] and now - meta._SaveTimestamp[record.Key] < meta.RequestTimestampCooldown then return false end
		meta._SaveTimestamp[record.Key] = now

		dispatch(record.Key, "OnDataSaving")

		if not meta._DataCache[record.Key] then
			return false
		end

		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		local rejected = {}

		if SegmentIndex then
			local success, value = check_validation(record.Key, SegmentIndex, Data)

			if success then
				meta._DataCache[record.Key][SegmentIndex] = value
			else
				table.insert(rejected, SegmentIndex)
			end
		else
			local accepted = deepclone(meta._DataCache[record.Key])

			for thisData, thisValue in pairs(Data) do
				local success, value = check_validation(record.Key, thisData, thisValue)

				if success then
					accepted[thisData] = value
				else
					table.insert(rejected, thisData)
				end
			end

			meta._DataCache[record.Key] = accepted
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save some of datas, because those are not valid.")
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end

		enqueue_save(record.Key, data, wal, backup, true)

		return true
	end

	function record:SafeWrite(WritingFunction: (CurrentData: any) -> any)
		local now = workspace:GetServerTimeNow()
		if meta._SaveTimestamp[record.Key] and now - meta._SaveTimestamp[record.Key] < meta.RequestTimestampCooldown then return false end
		meta._SaveTimestamp[record.Key] = now

		dispatch(record.Key, "OnDataSaving")

		if not meta._DataCache[record.Key] then
			return false
		end

		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		local clone = deepclone(meta._DataCache[record.Key])
		local resultFunction = WritingFunction(clone)

		if type(resultFunction) ~= "table" then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent's Write function must returns the/a table of param.")
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Write function isn't returning the table of param.")

			return false
		end

		local filteredObjs = {}
		local rejected = {}

		for thisData, thisValue in pairs(resultFunction) do
			filteredObjs[thisData] = thisValue
		end
		
		for thisData, thisValue in pairs(filteredObjs) do
			local success, value = check_validation(record.Key, thisData, thisValue)
			
			if not success then table.insert(rejected, thisData) continue end
			meta._DataCache[record.Key][thisData] = value
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save some of datas, because those are not valid.")
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
		
		enqueue_save(record.Key, data, wal, backup, true)

		return true
	end

	function record:AcquireLockSession(OwnerIdentity: string?, Timeout: number?)
		local now = workspace:GetServerTimeNow()
		OwnerIdentity = tostring(OwnerIdentity or (HttpService:GenerateGUID(false) .. "-" .. tostring(now)))
		Timeout = Timeout or 10

		local isSuccess = meta._LockSessions:Acquire(OwnerIdentity)
		if not isSuccess then
			meta._LockSessions:Release(OwnerIdentity)
			return false, nil
		end

		create_lock_timer(OwnerIdentity, Timeout)
		return isSuccess, OwnerIdentity
	end

	function record:ReleaseLockSession(OwnerIdentity: string)
		local timer = meta._LockTimers[OwnerIdentity]
		if timer then
			coroutine.close(timer)
			meta._LockTimers[OwnerIdentity] = nil
		end

		meta._LockSessions:Release(OwnerIdentity)
		return true
	end

	function record:IsSessionLocked(OwnerIdentity: string)
		return meta._LockSessions:IsLocked(OwnerIdentity)
	end

	function record:BindExclusiveAccess(ExclusivePlayer: Player)
		if not meta.ExclusiveAccessEnabled then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end
		
		if not meta._DataCache or not meta._DataCache[record.Key] then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Unable to get data, it seems you called the binding before the data is loaded. Make sure the BindExclusivePlayer called after data loading of player.")
			return false
		end

		local id = ExclusivePlayer.UserId
		local data = deepclone(meta._DataCache[record.Key])
		local now = workspace:GetServerTimeNow()

		if data.__bounds == nil then
			record:SafeWrite(function(CurrentData)
				CurrentData.__bounds = {}

				CurrentData.__bounds.id = id
				CurrentData.__bounds.since = now

				return CurrentData
			end)

			if meta._BoundRegistry[record.Key] == nil then
				bind_exclusive_access(record.Key, record, now, ExclusivePlayer)
			end			

			return true
		end

		dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Data is already bound to " .. data.__bounds.id .. "")
		run_exclusive_timer(meta._CurrentDataStore, meta._CurrentWALDataStore, meta._CurrentBackupDataStore)
		return false
	end

	function record:UnbindExclusiveAccess()
		if not meta.ExclusiveAccessEnabled then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end

		local data = deepclone(meta._DataCache[record.Key])

		if data.__bounds == nil or meta._BoundRegistry[record.Key] == nil then 
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Data is not bound to any player.")
			return false
		end

		record:SafeWrite(function(CurrentData)
			CurrentData.__bounds = nil

			return CurrentData
		end)		

		unbind_exclusive_access(record.Key)

		return true
	end
	
	function record:RefreshExclusiveAccess()
		if not meta.ExclusiveAccessEnabled then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end
				
		local currentData = meta._DataCache[record.Key]
		local now = workspace:GetServerTimeNow()
		if not currentData then 
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Unable to renew the exclusive access subscription, it seems you called the renew function before the data loaded.")
			return false 
		end
				
		local data = deepclone(currentData)
		if data.__bounds == nil or data.__bounds.id == nil then 
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Data is not bound to any player.")
			return false 
		end
				
		local plr = Players:GetPlayerByUserId(data.__bounds.id)
		if not plr then 
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Unable to find player who belongs current data.")
			return false 
		end
				
		record:SafeWrite(function(CurrentData)
			CurrentData.__bounds.since = now
			
			return CurrentData
		end)
		
		bind_exclusive_access(record.Key, record, now, plr)
		dispatch(record.Key, "OnDataBindRefreshed")
		return true
	end

	function record:IsExclusiveAccessBound()
		if not meta.ExclusiveAccessEnabled then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end

		local data = deepclone(meta._DataCache[record.Key])

		return data.__bounds ~= nil and meta._BoundRegistry[record.Key] ~= nil
	end

	function record:IsPlayerInExclusiveAccess(PlayerThatAssumedExclusive: Player)
		if not meta.ExclusiveAccessEnabled then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end

		local data = deepclone(meta._DataCache[record.Key])
		local id = PlayerThatAssumedExclusive.UserId

		return data.__bounds ~= nil and data.__bounds.id == id and meta._BoundRegistry[record.Key] ~= nil and meta._BoundRegistry[record.Key].UserId == id
	end

	function record:CreateValidation(ValidationFunction: (PredicateDummy: UDataComponentValidationDummy) -> any)
		local dummyMethods = {}
		local trackedValidations = meta._TrackedValidations[record.Key] or {}
		local trackedSchemas = meta._TrackedSchemas[record.Key] or {}
		local trackedClamps = meta._TrackedClamps[record.Key] or {}

		meta._TrackedValidations[record.Key] = trackedValidations
		meta._TrackedSchemas[record.Key] = trackedSchemas
		meta._TrackedClamps[record.Key] = trackedClamps

		-- Inserting a predication of data whereas the data can be written when the predicate fulfilled
		function dummyMethods:InsertPredicate(ThisData : any, Predicate: (ThisValue: any) -> any)
			trackedValidations[ThisData] = Predicate
		end

		function dummyMethods:RemovePredicate(ThisData : any)
			trackedValidations[ThisData] = nil
		end

		function dummyMethods:InsertSchema(ThisData : any, Type: string)
			trackedSchemas[ThisData] = Type
		end

		function dummyMethods:RemoveSchema(ThisData : any)
			trackedSchemas[ThisData] = nil
		end

		function dummyMethods:InsertClamp(ThisData : any, Min: number?, Max: number?)
			trackedClamps[ThisData] = {Min = Min, Max = Max}
		end

		function dummyMethods:RemoveClamp(ThisData : any)
			trackedClamps[ThisData] = nil
		end

		ValidationFunction(dummyMethods)
	end
	
	function record:Unarchive(Attempts: number?, YieldTime: number?)
		if not meta.ArchivationEnabled then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Archiving is disabled.")
			return false
		end
		
		local att = Attempts or 10
		local yield = YieldTime or 1
		
		local obtained = nil
		local _attempts = 0
		repeat
			local success, err = pcall(function()
				obtained = meta._CurrentArchivedDataStore:GetAsync(record.Key)
			end)
			
			if not success then
				dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to unarchive back the destroyed data, reason: " .. tostring(err))
			end
			
			_attempts += 1
			task.wait(yield or 3)
		until _attempts >= att or obtained ~= nil
		
		if obtained ~= nil then
			write_data(meta._CurrentDataStore, record.Key, obtained)
			meta._DataCache[record.Key] = obtained
			
			dispatch(record.Key, "OnDataUnarchived", deepclone(obtained))
			record.IsArchived = false
			
			return true
		end
		
		return false
	end
	
	function record:OnConnect() : UDataComponentCallbackFunctions
		local callbackMethods = {}
		local components = meta._UDataComponentDynamicCallbacks
		
		local connectorMethods = {}
		
		local function registerCallback(CallbackType: string, Callback: any)
			local listener = components:Get(CallbackType) or {}
			
			listener[record.Key] = listener[record.Key] or {}
			
			local id = HttpService:GenerateGUID(false)
			listener[record.Key][id] = Callback
			
			local connector = {}
			local disconnected = false
			
			function connector:Disconnect()
				if disconnected then return end
				disconnected = true
				
				listener[record.Key][id] = nil
			end
			
			function connector:DisconnectAfterCalled()
				if disconnected then return end
				
				local original = Callback
				listener[record.Key][id] = function(...)
					local ok, err = pcall(original, ...)
					connector:Disconnect()
					
					if not ok then
						error("[" .. meta.ErrorReasonNamespace .. "]: " .. err, 0)
					end
				end
			end
			
			function connector:IsConnected()
				return listener[record.Key] and listener[record.Key][id]
			end
			
			function connector:Wait()
				local currentThread = coroutine.running()
				
				listener[record.Key][id] = function(...)
					local args = table.pack(...)
					
					local success, err = pcall(Callback, table.unpack(args, 1, args.n))
					task.spawn(currentThread, table.unpack(args, 1, args.n))

					if not success then
						error("[" .. meta.ErrorReasonNamespace .. "]: " .. err, 0)
					end					
				end
				
				return coroutine.yield()
			end
			
			return connector
		end
		
		-- Callback Methods

		function callbackMethods:OnDataLoading(Callback: (Key: string) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataLoading", Callback)
		end
		
		function callbackMethods:OnDataLoaded(Callback: (Key: string, CloneData: any) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataLoaded", Callback)
		end
	
		function callbackMethods:OnDataSaving(Callback: (Key: string) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataSaving", Callback)
		end
		
		function callbackMethods:OnDataSaved(Callback: (Key: string, CloneData: any) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataSaved", Callback)
		end
		
		function callbackMethods:OnDataArchived(Callback: (Key: string, ArchivedData: any) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataArchived", Callback)
		end
		
		function callbackMethods:OnDataUnarchived(Callback: (Key: string, UnarchivedData: any) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataUnarchived", Callback)
		end
		
		function callbackMethods:OnDataRecovery(Callback: (Key: string) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataRecovery", Callback)
		end
		
		function callbackMethods:OnDataCached(Callback: (Key: string, CloneData: any) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataCached", Callback)
		end
		
		function callbackMethods:OnDataRemoved(Callback: (Key: string, RemovedData: any) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataRemoved", Callback)
		end
		
		function callbackMethods:OnDataBinding(Callback: (Key: string, Data: any) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataBinding", Callback)
		end
		
		function callbackMethods:OnDataUnbinding(Callback: (Key: string, Data: any) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataUnbinding", Callback)
		end
		
		function callbackMethods:OnDataBindRefreshed(Callback: (Key: string) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataBindRefreshed", Callback)
		end
		
		function callbackMethods:OnDataBindExpired(Callback: (Key: string) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataBindExpired", Callback)
		end
		
		function callbackMethods:OnCacheCleaned(Callback: (Key: string) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnCacheCleaned", Callback)
		end
		
		function callbackMethods:OnTransactionBegin(Callback: (Key: string, WithKey: string) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnTransactionBegin", Callback)
		end
		
		function callbackMethods:OnTransactionFiltered(Callback: (Key: string, FilteredObject: any) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnTransactionFiltered", Callback)
		end
		
		function callbackMethods:OnTransactionEnded(Callback: (Key: string, WithKey: string, Results: any) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnTransactionEnded", Callback)
		end
		
		function callbackMethods:OnReleased(Callback: (Key: string) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnReleased", Callback)
		end
		
		function callbackMethods:OnDataError(Callback: (Key: string, Reason: string) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnDataError", Callback)
		end
		
		function callbackMethods:OnSendingBroadcast(Callback: (Key: string, BroadcastName: string, BroadcastData: UDataComponentBroadcast) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnSendingBroadcast", Callback)
		end
		
		function callbackMethods:OnReceivingBroadcast(Callback: (Key: string, BroadcastName: string, BroadcastData: UDataComponentBroadcast) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnReceivingBroadcast", Callback)
		end
		
		function callbackMethods:OnLocalBroadcastListenerReady(Callback: (Key: string, LocalBroadcastName: string) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnLocalBroadcastListenerReady", Callback)
		end
		
		function callbackMethods:OnLocalBroadcastListenerCalled(Callback: (Key: string, LocalBroadcastName: string) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnLocalBroadcastListenerCalled", Callback)
		end
		
		function callbackMethods:OnLocalBroadcastListenerClosed(Callback: (Key: string, LocalBroadcastName: string) -> ()) : UDataComponentCallbackConnection
			return registerCallback("OnLocalBroadcastListenerClosed", Callback)
		end
		
		return callbackMethods
	end
	
	function record:SwapTransaction(OtherPlayerData : UDataComponentRecord, Transaction: (ThisCurrentData: UDataComponentEditor, OtherCurrentData: UDataComponentEditor) -> (), Timeout : number?)
		Timeout = Timeout or 10
		if not meta.SwappingEnabled then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Swapping is disabled")
			return false
		end
		
		local now = workspace:GetServerTimeNow()
		if (meta._SwapTimestamp[record.Key] and now - meta._SwapTimestamp[record.Key] < meta.SwappingCooldown) or (meta._SwapTimestamp[OtherPlayerData.Key] and now - meta._SwapTimestamp[OtherPlayerData.Key] < meta.SwappingCooldown) then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Swapping is on cooldown")
			return false
		end
		
		meta._SwapTimestamp[record.Key] = now
		meta._SwapTimestamp[OtherPlayerData.Key] = now
		
		if OtherPlayerData.Key == record.Key then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Swapping with self is not allowed")
			return false
		end
		
		local myMethods = {}
		local otherMethods = {}
		local obtainedResults = { Other = {}, This = {} }
		
		local otherData = meta._DataCache[OtherPlayerData.Key]
		local myData = meta._DataCache[record.Key]
		
		if not otherData or not myData then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .."]: Unable to do transaction with other player, because failed to get data. It seems you're not loaded the data yet.")
			return false
		end
		
		local terminated = false
		function myMethods:Give(ThisData: any, Value: number)
			local _value = myData[ThisData] or 0
			if not _value or typeof(_value) ~= "number" then 
				dispatch(record.Key, "OnTransactionFiltered", ThisData)
				return 
			end
			
			Value = math.clamp(Value, 0, _value)
			obtainedResults["Other"][ThisData] = Value
		end
		
		function otherMethods:Give(ThisData: any, Value: number)
			local _value = otherData[ThisData] or 0
			if not _value or typeof(_value) ~= "number" then 
				dispatch(OtherPlayerData.Key, "OnTransactionFiltered", ThisData)
				return 
			end
			
			Value = math.clamp(Value, 0, _value)
			obtainedResults["This"][ThisData] = Value
		end
		
		local isSuccess1, lock1 = OtherPlayerData:AcquireLockSession(OtherPlayerData.Key, Timeout)
		local isSuccess2, lock2 = record:AcquireLockSession(record.Key, Timeout)
		
		if not isSuccess1 or not isSuccess2 then
			if isSuccess1 then OtherPlayerData:ReleaseLockSession(lock1) end
			if isSuccess2 then record:ReleaseLockSession(lock2) end
			
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .."]: Unable to do transaction with other player, because failed lock.")
			return false
		end
		
		otherData = meta._DataCache[OtherPlayerData.Key]
		myData = meta._DataCache[record.Key]
		
		if not otherData or not myData then
			OtherPlayerData:ReleaseLockSession(lock1)
			record:ReleaseLockSession(lock2)
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .."]: Unable to do transaction with other player, because failed to get data. It seems you're not loaded the data yet, or the snapshot gone.")
			return false
		end
		
		dispatch(record.Key, "OnTransactionBegin", OtherPlayerData.Key)
		dispatch(OtherPlayerData.Key, "OnTransactionBegin", record.Key)
		
		Transaction(myMethods, otherMethods)
		
		for key, value in pairs(obtainedResults.Other) do
			otherData[key] = (otherData[key] or 0) + value
			myData[key] = (myData[key] or 0) - value
		end
		
		for key, value in pairs(obtainedResults.This) do
			myData[key] = (myData[key] or 0) + value
			otherData[key] = (otherData[key] or 0) - value
		end
		
		OtherPlayerData:Flush()
		record:Flush()
		
		OtherPlayerData:ReleaseLockSession(lock1)
		record:ReleaseLockSession(lock2)
		
		dispatch(record.Key, "OnTransactionEnded", OtherPlayerData.Key, obtainedResults.This)
		dispatch(OtherPlayerData.Key, "OnTransactionEnded", record.Key, obtainedResults.Other)
		return true
	end

	function record:SmartCleanCache(Interval: number?)
		if not meta.CacheCleaningEnabled then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Cache cleaning is disabled")
			return
		end
		
		if meta._CacheCleaningCalled then return end
		meta._CacheCleaningCalled = true
		
		local data = meta._CurrentDataStore
		local wal = meta._CurrentWALDataStore
		local backup = meta._CurrentBackupDataStore
		
		local inv = Interval or meta.CacheCleaningInterval or 300
		
		meta._CacheCleaningThread = task.spawn(function()
			while meta.Enabled do
				local checkKeys = {}
				for key in pairs(meta._DataCache) do
					table.insert(checkKeys, key)
				end
				
				for _, key in ipairs(checkKeys) do
					if not meta._BoundRegistry[key] then
						call_cache_cleanup(key, inv, data, wal, backup)
					end
				end
				
				task.wait(inv)
			end
		end)
	end
	
	function record:EndCacheCleaning()
		if not meta.CacheCleaningEnabled then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Cache cleaning is disabled")
			return
		end
		
		if not meta._CacheCleaningCalled then return end
		meta._CacheCleaningCalled = false
		
		task.cancel(meta._CacheCleaningThread)
		meta._CacheCleaningThread = nil
	end

	function record:GetVersion()
		return meta._DataCache[record.Key] and meta._DataCache[record.Key].__version or 0
	end
	
	function record:BroadcastCurrentData(BroadcastName : string, DetailedThings : any?)
		if not meta.MessagingEnabled then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Messaging is disabled")
			return false
		end
		
		local data = meta._DataCache[record.Key]
		if not data then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Data is not loaded")
			return false
		end
		
		local bounds = data.__bounds
		if not bounds then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Data is not binded or it's expired")
			return false
		end
		
		data = deepclone(data)
		local name = (meta.MessagingNamespace .. BroadcastName) or "UDataComponent"
		
		local messages = {
			Key = record.Key,
			Data = data,
			BroadcasterPlaceId = game.JobId,
			BroadcasterUserId = bounds.UserId,
			BroadcastTime = workspace:GetServerTimeNow(),
			Other = {}
		}
		
		if DetailedThings then
			table.insert(messages.Other, DetailedThings)
		end
		
		local success, err = pcall(function()
			MessagingService:PublishAsync(name, messages)
		end)
		
		if not success then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to broadcast other servers for current data, reason: " .. tostring(err))
			return false
		end
		
		dispatch(record.Key, "OnSendingBroadcast", name, deepclone(messages))
		return success
	end
	
	function record:WaitForBroadcastPacket(BroadcastName : string, Timeout : number?) : UDataComponentBroadcast
		local name = (meta.MessagingNamespace .. BroadcastName) or "UDataComponent"
		local currentThread = coroutine.running()
		Timeout = Timeout or 50
		
		local connection
		local called = false
		
		local success, err = pcall(function()
			connection = MessagingService:SubscribeAsync(name, function(message)
				if called then return end
				called = true
				
				connection:Disconnect()
				task.spawn(currentThread, message.Data)
			end)
		end)
		
		if not success then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to subscribe for broadcast packets, reason: " .. tostring(err))
			return nil
		end
		
		local timeoutThread = task.delay(Timeout, function()
			if called then return end
			called = true
			
			if connection then connection:Disconnect() end
			task.spawn(currentThread, nil)
		end)
		
		local result = coroutine.yield()
		if timeoutThread then task.cancel(timeoutThread) end
		
		if result then
			dispatch(record.Key, "OnReceivingBroadcast", name, result)
			return result ::  UDataComponentBroadcast
		end
		
		return nil
	end
	
	function record:SendLocalBroadcast(BroadcastName : string, Password : string, DetailedThings : any?)
		if not meta.MessagingEnabled then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Messaging is disabled")
			return false
		end
		
		local data = meta._DataCache[record.Key]
		if not data then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Data is not loaded")
			return false
		end
		
		local bounds = data.__bounds
		if not bounds then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Data is not binded or it's expired")
			return false
		end
		
		data = deepclone(data)
		local name = (meta.MessagingNamespace .. BroadcastName) or "UDataComponent"
		local encryptedName = encrypt(name, Password)
		
		local messages = {
			Key = record.Key,
			Data = data,
			BroadcasterPlaceId = game.JobId,
			BroadcasterUserId = bounds.UserId,
			BroadcastTime = workspace:GetServerTimeNow(),
			Other = {}
		}
		
		if DetailedThings then
			table.insert(messages.Other, DetailedThings)
		end
		
		local success, err = pcall(function()
			MessagingService:PublishAsync(encryptedName, messages)
		end)
		
		if not success then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to broadcast to the targeted server, reason: " .. tostring(err))
			return false
		end
		
		dispatch(record.Key, "OnSendingBroadcast", name, deepclone(messages))
		return true
	end
	
	function record:ListenToLocalBroadcast(BroadcastName : string, Password : string, Callback: (Key: string, BroadcastData: UDataComponentBroadcast) -> ())
		local name = (meta.MessagingNamespace .. BroadcastName) or "UDataComponent"
		local encryptedName = encrypt(name, Password)
		
		listen_local_broadcast(encryptedName, BroadcastName, record.Key, Callback)
	end
	
	function record:CloseLocalBroadcastListener(LocalBroadcastName : string, Password : string)
		local name = (meta.MessagingNamespace .. LocalBroadcastName) or "UDataComponent"
		local encryptedName = encrypt(name, Password)
		
		local listener = meta._LocalBroadcastListeners[encryptedName]
		if not listener then
			dispatch(record.Key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Local Broadcast listener of " .. LocalBroadcastName .. " cannot be found.")
			return false
		end
		
		listener.Schedule:Disconnect()
		
		meta._LocalBroadcastListeners[encryptedName] = nil
		return true
	end

	return record
end

function UDataComponent.InDataInfo(DataStoreName : string, Scope : string?, Configurations : {any?}) : UDataComponentInfo
	local _scope = Scope or "global"

	local self = setmetatable({}, UDataComponent)

	self._DataPredicates = SDictionary.new("string", "table", {}) -- { [Key] = predicateFunction }

	self.Enabled = true
	self.ValidationEnabled = true
	self.CallbackEnabled = true
	self.RequestTimestampCooldown = 2
	self.DefaultDataLoadingAttempts = 5
	self.DefaultDataLoadingYieldDuration = 3
	self.WALEnabled = false
	self.WritingDataAgeEnabled = false
	self.DefaultSaveAttempts = 5
	self.DefaultYieldAttempts = 3
	self.MaxKeyLength = 50
	self.BackupEnabled = true
	self.BackupYieldDuration = 3
	self.StrictlyUnallowDetaching = true
	self.BackupRemovedWhenDetached = false
	self.AutoSaveEnabled = true
	self.AutoSaveInterval = 300
	self.WALDataSuffix = "_wal"
	self.WALMaxEntries = 50
	self.BackupDataSuffix = "_backup"
	self.ExclusiveAccessEnabled = true
	self.ExclusiveAccessExpiration = 1 -- 1 Day
	self.SwappingEnabled = true
	self.SwappingCooldown = 5
	self.CacheCleaningEnabled = true
	self.CacheCleaningInterval = 300
	self.CanDataExpired = false
	self.DataExpiredDuration = 300
	self.DataBlueprint = {}
	self.ErrorReasonNamespace = "UDataComponent"
	self.LocalDataNamespace = "LUDataComponent"
	self.MessagingEnabled = false
	self.MessagingNamespace = "UDataComponentReplication"
	self.MessagingSendingCooldown = 5
	self.MessagingReceivingCooldown = 5
	self.MessagingLocalListeningCooldown = 5
	self.ServerClaimerSuffix = "_possessive_claimer"
	self.ArchivationEnabled = true
	self.ArchivationSuffix = "_archive"
	self.MessagingDebugEnabled = false
	self.MaxDataSavingPerTick = 4

	self._CurrentDataStore = DataStoreService:GetDataStore(DataStoreName, _scope)
	self._CurrentWALDataStore = DataStoreService:GetDataStore(DataStoreName..self.WALDataSuffix, _scope)
	self._CurrentBackupDataStore = DataStoreService:GetDataStore(DataStoreName..self.BackupDataSuffix, _scope)
	self._CurrentArchivedDataStore = DataStoreService:GetDataStore(DataStoreName..self.ArchivationSuffix, _scope)
	self._DataStoreName = DataStoreName
	
	self._GetTimestamp = {} -- { [Key: string] = timestamp: number }
	self._SaveTimestamp = {} -- { [Key: string] = timestamp: number }
	self._SwapTimestamp = {} -- { [Key: string] = timestamp: number }
	self._AutosaveTimestamp = {} -- { [Key: string] = timestamp: number }
	self._SavePendingQueue = {} -- { [Key: string] = {Key, Data, WAL, Backup, IsSafe } }
	self._DataCache = {} -- { [Key: string] = Data: any }
	self._BoundRegistry = {} -- { [Key: string] = table }
	self._LockSessions = ScopedMutex.new(Mutex)
	self._LockTimers = {}
	self._LocalBroadcastListeners = {} -- { [Key: string] = { [ListenerId: string] = Listener: function } }

	self._ExclusiveTimerCalled = false
	self._ShutdownCalled = false
	self._ExclusiveSafetyCalled = false
	self._IsRunning = false
	self._CacheCleaningCalled = false
	self._ClaimedSyncCalled = false
	
	self._CacheCleaningThread = nil

	self._TrackedValidations = {} -- { [Key] = { Member = ValidationFunction, ... } }
	self._TrackedSchemas = {} -- { [Key] = { Member = ValidationFunction, ... } }
	self._TrackedClamps = {} -- { [Key] = { Member = ValidationFunction, ... } }
	
	self._UDataComponentCallbacks = SDictionary.new("string", "table", {
		OnDataLoading = {},
		OnDataLoaded = {},
		OnDataSaving = {},
		OnDataSaved = {},
		OnDataArchived = {},
		OnDataUnarchived = {},
		OnDataRecovery = {},
		OnDataCached = {},
		OnDataRemoved = {},
		OnDataBinding = {},
		OnDataUnbinding = {},
		OnDataBindRefreshed = {},
		OnDataBindExpired = {},
		OnCacheCleaned = {},
		OnTransactionBegin = {},
		OnTransactionFiltered = {},
		OnTransactionEnded = {},
		OnReleased = {},
		OnDataError = {},
		OnSendingBroadcast = {},
		OnReceivingBroadcast = {},
		OnLocalBroadcastListenerReady = {},
		OnLocalBroadcastListenerCalled = {},
		OnLocalBroadcastListenerClosed = {}
	})
	
	self._UDataComponentDynamicCallbacks = SDictionary.new("string", "table", {
		OnDataLoading = {},
		OnDataLoaded = {},
		OnDataSaving = {},
		OnDataSaved = {},
		OnDataArchived = {},
		OnDataUnarchived = {},
		OnDataRecovery = {},
		OnDataCached = {},
		OnDataRemoved = {},
		OnDataBinding = {},
		OnDataUnbinding = {},
		OnDataBindRefreshed = {},
		OnDataBindExpired = {},
		OnCacheCleaned = {},
		OnTransactionBegin = {},
		OnTransactionFiltered = {},
		OnTransactionEnded = {},
		OnReleased = {},
		OnDataError = {},
		OnSendingBroadcast = {},
		OnReceivingBroadcast = {},
		OnLocalBroadcastListenerReady = {},
		OnLocalBroadcastListenerCalled = {},
		OnLocalBroadcastListenerClosed = {}
	})

	if Configurations then
		for key, value in pairs(Configurations) do
			self[key] = value
		end
	end

	return self
end

--[[
	@param Key: string | number
	@param Callbacks: {UDataComponentCallbackFunctions?}
	@return UDataComponentRecord
]]
function UDataComponent:GetPlayerData(Key : string | number, Callbacks : {UDataComponentCallbackFunctions?}) : UDataComponentRecord
	if Callbacks then
		for key, value in pairs(Callbacks) do
			local currentFunc = self._UDataComponentCallbacks:Get(key)

			if currentFunc then
				currentFunc[Key] = value
			end
		end
	end
	
	if typeof(Key) == "string" and #Key > self.MaxKeyLength then
		warn("[ .. " .. self.ErrorReasonNamespace .. "] : Key is too long")
		
		Key = string.sub(Key, 1, tonumber(self.MaxKeyLength))
	end

	return InPlayerData(self, Key) :: UDataComponentRecord
end

function UDataComponent:GetLocalData(Callbacks : {UDataComponentCallbackFunctions?}) : UDataComponentRecord
	local locKey = self.LocalDataNamespace .. "@" .. self._DataStoreName
	if Callbacks then
		for key, value in pairs(Callbacks) do
			local currentFunc = self._UDataComponentCallbacks:Get(key)
			
			if currentFunc then
				currentFunc[key] = value
			end
		end
	end
	
	return InPlayerData(self, locKey) :: UDataComponentRecord
end

function UDataComponent:GetDataStoreName() : string
	return self._DataStoreName
end

return UDataComponent :: UDataComponent
