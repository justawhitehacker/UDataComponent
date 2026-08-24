--[[
BATTLE TEST RESULTS:

A. Core Testing
1. Data is loaded correctly
2. Data is ready properly
3. Data record can be accessed everywhere after ready
4. Data can be changed from .Data, but you need to use Save() to save it
5. Write() executes properly, and returns failed when the data is already released or asleep
6. Save() with custom data successfully saved the data
7. Save() with custom data AND segment index successfully saved the data
8. When trying to access .Data before Ready() even called, it will return nil
9. When trying to call record for sleep twice, first operation will return true, and second operation will return false
10. When trying to call record then ready, then sleep, then awake again and ready, it's successfully awakening the .Data
11. When trying to use record members, or modify the data before Ready called. It will return nil or failed, without crashing
12. When trying to use record members, or modify the data after sleep. It will return nil or failed, without crashing

Result of Core Testing: SUCCESS

B. Reconciliation Testing
1. When there is a missing element, it will be reconciled
2. When trying to use Save() just only to save some datas without including other elements as blueprint, it will automatically reconciled missing elements
3. When there is/are new element(s) from blueprint, meanwhile loaded old data from a record haven't included those element(s) because recently added, it will automatically reconciled
4. Same as number 3, but nested data will also reconciled
5. When there is/are removed elements from blueprint, meanwhile you've been loaded it already, it remains without missing
6. Reconcile works gracefully, no elements overlapping when the data already loaded or existed

Result of Reconciliation Testing: SUCCESS

C. Exclusive Access (Single Server)
1. Awake() for the first time, when first player successfully awakened, other players will not be able to awake and kicked, meanwhile if they're rejoining it will be able to awake (FIXED)
2. When trying to Ready() with another owner of record who not belonged this data, it will failed successfully
3. When tries to Awake() twice or more before Sleep() called, it will return false
4. __bounds info in record successfully captured after Awake()

Result of Exclusive Access (Single Server) Testing: PARTIALLY SUCCESS, No.1 failed
New Result: FIXED, SUCCESS

D. Multi Server testing (CRUCIAL)
1. When a player Awake() his own record, the server and the player claimed the record. When another server and even another player tries to Awake() the same record, it will return false
2. When the owner of record released the session with Sleep(), another server that tries to claim record with Awake(), it will be able to claim the record
3.

--]]


-- UDataComponent.lua
-- UDataComponent-v2.0

-- I decided to refactor, but also created a new one
-- I probably still stealing some features from the previous version into here
-- That'd cut some many times instead imagining a new-massive module features
local UDataComponent : UDataComponent = {}
UDataComponent.__index = UDataComponent

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

local Compressor = require(script.Compressor)
local Mutex = require(script.Mutex)
local ScopedMutex = require(script.ScopedMutex)

local ServerId = game.JobId
local PlaceId = game.PlaceId

local ConnectionTest = DataStoreService:GetDataStore("ConnectionTest-" .. PlaceId)

local EMERGENCY_COMPRESSION_LEVEL = 0

local InfosStorage = {}

UDataComponent.Enabled = true

-- State Machines:
--[[
	"Asleep" -> where the record is not owned by any server or remaining untouched yet
	"WakingUp" -> where the record is claimed by a server, but not yet confirmed by the server
	"Ready" -> where the record is ready to be used
	"Sleeping" -> where the record is released by the server, but not yet confirmed by the server
	"Died" -> where the record is getting detached or removed, along the release
	"Reborn" -> where the record is getting unarchived, and start to awake
--]]

-- Data Structure:
--[[
PlayerRecord:
	__version : number -> Version of current data
	__bounds : {Bindings} -> Information about the bound of this data
		-- id : number -> ID of the player who owns this data
		-- since : number -> Time since this player bound or own this data
		-- lastheartbeat : number -> Time since the last heartbeat sent for this data, meaning the server is still alive
		-- serverid : string? -> ServerID (JobID) of this data, where this id contains the id of server who claimed this data
	__data : any -> Data of this player
	__flag : string (should be char) -> flag that indicates whether the data of this record was compressed ('C') or real ('R'), so that UDC will handle it
--]]

-- Standard UDataComponent level
export type UDataComponent = {
	InDataInfo: (DataStoreName: string, Scope: string?, Configurations: {[string]: any}?) -> UDCInfo,
	-- This is where you will use a data info to access into info and record
	-- @param: DataStoreName: string -> Name of the data store
	-- @param: Scope: string? -> Scope of the data store
	-- @param: Configurations: {[string]: any}? -> Configurations of the data store
	-- @return: UDCInfo -> Info of the data store
	
	IsAlive: () -> boolean,
	-- This is to check whether the UDataComponent and DataStore are alive or not
	-- @param: UDC: UDataComponent -> UDataComponent to check
	-- @return: boolean -> If the UDataComponent is alive or not
	
	-- Configurations
	Enabled : boolean, -- If this UDataComponent enabled to alive
}

-- Info level, where UDataComponent see the configurations
export type UDCInfo = {
	Name: string, -- Name of the data store from this info
	Scope: string, -- Scope of the data store from this info
	
	GetCurrentRecord: (UDCInfo: UDCInfo, Key: number | string, OwnerOfThisData: Player) -> UDCRecord,
	-- This is where the record of player's data is obtained:
	-- @param: Key: number | string -> Key of the record of this player
	-- @param: OwnerOfThisData: Player -> Player who owns this data, prevent other servers or other player to obtain or commit the data
	ViewCurrentRecord: (UDCInfo: UDCInfo, Key: number | string) -> UDCRecord,
	-- This is where you can view the record of player's data, also showing owner and version
	-- @param: Key: number | string -> Key of the record of this player
	GetLocalRecord: (UDCInfo: UDCInfo) -> UDCRecord,
	-- This is where the record of local data is obtained
	-- You can say, in UDC, local data is just "global data of this data store" or "global record"
	ViewLocalRecord: (UDCInfo: UDCInfo) -> UDCRecord,
	-- This is where you can view the record of local data
	
	-- Configurations
	Enabled : boolean, -- If this UDataComponent's info enabled to be used 
	ValidationEnabled : boolean, -- If this UDataComponent's info allowed to validate the data that came from commit
	CallbackEnabled : boolean, -- If this UDataComponent's info allowed to fire callback functions
	WALEnabled : boolean, -- If this UDataComponent's info allowed to use Write Ahead Logging, WAL called at fatal-points, like server shutdown or player leaving with save queue pended
	DataWritingCooldown : number, -- Cooldown between each data write
	MaxKeyLength : number, -- Maximum key-length for each keys
	BackupEnabled : boolean, -- If this UDataComponent's info allowed to call backup data when fatal error occurs
	DefaultBackupAttempts : number, --  Strictly gives some attempts to get the data-backup when normal load failed
	DefaultBackupYieldDuration : number, -- Yield duration between each attempt of get the data-backup
	StrictlyUnallowDetaching : boolean, -- If this UDataComponent's info unallowed to remove/archive current data
	AutoSaveEnabled : boolean, -- If this UDataComponent's info allowed to auto-save data in background
	AutoSaveInterval : number, -- Interval between each auto-save
	WALDataSuffix : string, -- Suffixed to the DataStore name for the WAL
	WALMaxEntries : number, -- Maximum entries in the WAL
	OwnershipExpiration : number, -- Duration for the data's ownership, where the player can holds the data and server claiming current data to other servers
	SwappingEnabled : boolean, -- If this UDataComponent's info allowed to swap data between players
	SwappingCooldown : number, -- Cooldown between each swap
	CacheCleaningEnabled : boolean, -- If this UDataComponent's info allowed to clean up the cache
	CacheCleaningInterval : number,-- Interval between each cache cleaning
	DataBlueprint : {any?}, -- Blueprint for the data, where when a new player joins, the data will be filled with the blueprint as template or first data
	ErrorReasonNamespace : string, -- Namespace for the error reasons
	CompressionLevel : number, -- Compression level for the data
	CompressionThreshold : number, -- Threshold for the data to be compressed, in bytes
	CompressionQueueCooldown : number, -- Cooldown between each compression
	MaxDecompressedSize : number, -- Maximum size for the data to be compressed, in bytes
	LocalDataNamespace : string, -- Namespace for the local record level
	MessagingEnabled : boolean, -- If this UDataComponent's info allowed to use messaging across servers, called Broadcasting
	MessagingNamespace : string, -- Namespace for the Broadcast channel for each server
	MessagingSendingCooldown : number, -- Cooldown for sending the broadcast informations
	MessagingReceivingCooldown : number, -- Cooldown for listening the broadcast messages
	MessagingLocalListeningCooldown : number, -- Cooldown for listening the local broadcast messages
	ArchivationEnabled : boolean, -- If this UDataComponent's info allowed to use archivation, where the data will be moved to the archived data store after detaching
	ArchivationSuffix : string, -- Suffixed to the DataStore name for the archived data,
	MaxDataSavingPerTick : number, -- Maximum data saving per tick in FIFO queue,
	MaxDataObtainingPerTick : number, -- Maximum data obtaining per tick in FIFO queue,
	MaxConcurrentLoadWorkers : number, -- Maximum concurrent load workers
	MaxConcurrentSaveWorkers : number, -- Maximum concurrent save workers
	StaleServerClaimingTime : number, -- Duration for the server to claim the data of other server
}

-- info level helper for internal...
export type __UDCInfo_Internal = {
	Name: string, -- Name of the data store from this info
	Scope: string, -- Scope of the data store from this info

	GetCurrentRecord: (UDCInfo: UDCInfo, Key: number | string, OwnerOfThisData: Player) -> UDCRecord,
	-- This is where the record of player's data is obtained:
	-- @param: Key: number | string -> Key of the record of this player
	-- @param: OwnerOfThisData: Player -> Player who owns this data, prevent other servers or other player to obtain or commit the data
	ViewCurrentRecord: (UDCInfo: UDCInfo, Key: number | string) -> UDCRecord,
	-- This is where you can view the record of player's data, also showing owner and version
	-- @param: Key: number | string -> Key of the record of this player
	GetLocalRecord: (UDCInfo: UDCInfo) -> UDCRecord,
	-- This is where the record of local data is obtained
	-- You can say, in UDC, local data is just "global data of this data store" or "global record"
	ViewLocalRecord: (UDCInfo: UDCInfo) -> UDCRecord,
	-- This is where you can view the record of local data
	
	_CurrentDataStore : DataStore,
	_CurrentWALDataStore : DataStore,
	_CurrentArchivedDataStore : DataStore,
	
	_CompressedBlueprint : { any },

	_WriteTimestamp : { any? },
	_SwapTimestamp : { any? },
	_AutosaveTimestamp : { any? },
	_SavePendingQueue : { any? },
	_ObtainPendingQueue : { any? },
	_UnreadyData : { any? },
	_DataCache : { any? },
	_CompressionStack : { any? },
	_StandbyRegistry : { any? },
	_LockSessions : any,
	_LocalBroadcastListeners : { any? },

	_ExclusiveTimerCalled : boolean,
	_ShutdownCalled : boolean,
	_ExclusiveSafetyCalled : boolean,
	_IsSaveRunning : boolean,
	_IsObtainingRunning : boolean,
	_IsCompressionTimerRunning : boolean,
	_CacheCleaningCalled : boolean,
	_StandbyReady : boolean,
	
	_CurrentLoadWorkers : number,
	_CurrentSaveWorkers : number,

	_TrackedValidations : { any? },
	_TrackedSchemas : { any? },
	_TrackedClamps : { any? },

	_UDataComponentCallbacks : { any? },
	_UDataComponentDynamicCallbacks : { any? },

	-- Configurations
	Enabled : boolean, -- If this UDataComponent's info enabled to be used 
	ValidationEnabled : boolean, -- If this UDataComponent's info allowed to validate the data that came from commit
	CallbackEnabled : boolean, -- If this UDataComponent's info allowed to fire callback functions
	WALEnabled : boolean, -- If this UDataComponent's info allowed to use Write Ahead Logging, WAL called at fatal-points, like server shutdown or player leaving with save queue pended
	DataWritingCooldown : number, -- Cooldown between each data write
	MaxKeyLength : number, -- Maximum key-length for each keys
	BackupEnabled : boolean, -- If this UDataComponent's info allowed to call backup data when fatal error occurs
	DefaultBackupAttempts : number, --  Strictly gives some attempts to get the data-backup when normal load failed
	DefaultBackupYieldDuration : number, -- Yield duration between each attempt of get the data-backup
	StrictlyUnallowDetaching : boolean, -- If this UDataComponent's info unallowed to remove/archive current data
	AutoSaveEnabled : boolean, -- If this UDataComponent's info allowed to auto-save data in background
	AutoSaveInterval : number, -- Interval between each auto-save
	WALDataSuffix : string, -- Suffixed to the DataStore name for the WAL
	WALMaxEntries : number, -- Maximum entries in the WAL
	OwnershipExpiration : number, -- Duration for the data's ownership, where the player can holds the data and server claiming current data to other servers
	SwappingEnabled : boolean, -- If this UDataComponent's info allowed to swap data between players
	SwappingCooldown : number, -- Cooldown between each swap
	CacheCleaningEnabled : boolean, -- If this UDataComponent's info allowed to clean up the cache
	CacheCleaningInterval : number,-- Interval between each cache cleaning
	DataBlueprint : {any?}, -- Blueprint for the data, where when a new player joins, the data will be filled with the blueprint as template or first data
	ErrorReasonNamespace : string, -- Namespace for the error reasons
	CompressionLevel : number, -- Compression level for the data, 1-22, default 10
	CompressionThreshold : number, -- Threshold for the data to be compressed, in bytes
	CompressionQueueCooldown : number, -- Cooldown for the compression queue
	MaxDecompressedSize  : number, -- Maximum size for the data to be compressed, in bytes
	LocalDataNamespace : string, -- Namespace for the local record level
	MessagingEnabled : boolean, -- If this UDataComponent's info allowed to use messaging across servers, called Broadcasting
	MessagingNamespace : string, -- Namespace for the Broadcast channel for each server
	MessagingSendingCooldown : number, -- Cooldown for sending the broadcast informations
	MessagingReceivingCooldown : number, -- Cooldown for listening the broadcast messages
	MessagingLocalListeningCooldown : number, -- Cooldown for listening the local broadcast messages
	ArchivationEnabled : boolean, -- If this UDataComponent's info allowed to use archivation, where the data will be moved to the archived data store after detaching
	ArchivationSuffix : string, -- Suffixed to the DataStore name for the archived data,
	MaxDataSavingPerTick : number, -- Maximum data saving per tick in FIFO queue,
	MaxDataObtainingPerTick : number, -- Maximum data obtaining per tick in FIFO queue,
	MaxConcurrentSaveWorkers : number, -- Maximum concurrent save workers
	MaxConcurrentLoadWorkers : number, -- Maximum concurrent load workers
	StaleServerClaimingTime : number, -- Duration for the server to claim the data if the owner is unknown
}

-- Record level, where the data record is accessed here
export type UDCRecord = {
	Key: number | string, -- Key of this data
	Owner: Player?, -- Player who owns this record
	IsArchived: boolean, -- If this record was detached and archived
	Event: UDCEvent, -- Utils for the events
	Validation: UDCValidation, -- Utils for the validation
	Swap: UDCSwap, -- Utils for the swap
	Messaging: UDCMessaging, -- Utils for the messaging
	Version: number, -- Version of this data
	Data: any?, -- Loaded Data that has been loaded, this is a clone from the actual data/cache, where this must be a read member
	
	-- These are two Write functions, with two types too: Normal and Force
	-- Normal is when you writing the data with cooldown and lock, especially when the data is pending into queue to be commited
	-- Force is when you don't care about the cooldown and lock, and will be commited immediately
	
	-- For safe writing data session, use Normal, and for immediate case, use Force
	-- For normal, before even the commiting, it will be cached first, in case the read data is changed for the next usage after the write session
	
	Awake: (UDCRecord: UDCRecord) -> boolean, -- (Suspending) IMPORTANT POINT, this load the record from the datastore, and must be called when player is joing the experience
	-- @return boolean -- Status of the loading the data, true if success
	
	Ready: (UDCRecord: UDCRecord, FindingPlayerTimeout: number?) -> boolean, -- (Suspending) IMPORANT POINT, this must be called before the data can be used, where UDC is evaluating everything fromn the data and ownership, before the data can be used
	-- @return boolean -- Status when the data of this player is ready after evaluating and hard-checking, if true the data is ready to be used
	
	Standby: (UDCRecord: UDCRecord) -> boolean, -- (Suspending) IMPORTANT POINT, this will be called automatically when player is leaving the experience, or server shutdown, where the data will be saved and released, must be called after the record is ready, which after "Ready()" returns true. 
	-- This will use WAL to save data, to prevent request "Boom", and will easily and automatically recovered by UDC from Awake()
	
	Sleep: (UDCRecord: UDCRecord) -> boolean, -- (Suspending) IMPORTANT POINT, this is where you can release the bounds of this server from data, then commited into datastore
	-- @info -- You can call this when you're needing a manual control over releasing session, meanwhile this was called automatically when Standby() triggered
	-- @return boolean -- Status of the releasing the data, true if success
	
	Save: (UDCRecord: UDCRecord, Data: any?, SegmentIndex: number?) -> boolean, -- (Suspending) this is saving data where the data must be an over-all data, which is the previous recored that haven't been edited also must be saved too, will pushed into save pending queue then changed the read data
	-- @param Data: any? -- Data to commit, if nil, current read data will be used as data to commit
	-- @param SegmentIndex: number? -- Where the current data is contained in an index to
	-- @return boolean -- Status of the saving data, true if success, but true in here isn't meaning the data is actually commited
	
	Write: (UDCRecord: UDCRecord, WritingFunction: (CurrentData: any) -> ()) -> boolean, -- (Suspending) this is how you can save the data with partial update, where you don't need to commit all data to write when you just need one or two or more datas to edit
	-- @param WritingFunction: (CurrentData: any) -> () -- Function that used as Write session over the data
	-- @return boolean -- Status of the writing data, true if success, but true in here isn't meaning the data is actually commited
	
	ForceSave: (UDCRecord: UDCRecord, Data: any, SegmentIndex: number?) -> boolean, -- (Suspending) same as record:Save(...), but this will commit into datastore immediately
	-- @param Data: any -- Data to commit
	-- @param SegmentIndex: number? -- Where the current data is contained in an index to
	-- @return boolean -- Status of the saving data, true if success

	ForceWrite: (UDCRecord: UDCRecord, WritingFunction: (CurrentData: any) -> ()) -> boolean, -- (Suspending) same as record:Write(...), but this will commit into datastore immediately
	-- @param WritingFunction: (CurrentData: any) -> () -- Function that used as Write session over the data
	-- @return boolean -- Status of the writing data, true if success
	
	Detach: (UDCRecord: UDCRecord) -> boolean, -- (Suspending) DANGEROUS, this will destroy/erase the record data from datastore and cache, but if archivation is true, the data will be archived
	-- @return boolean -- Status of the erasing the data, true if successfully detached/removed the data
	
	Unarchive: (UDCRecord: UDCRecord) -> boolean, -- (Suspending) Call the removed data from datastore, where the data will be immediately written into cache
	-- @return boolean -- Status of the unarchiving data, true if success
	
}

export type UDCEvent = {
	
}

export type UDCValidation = {
	
}

export type UDCSwap = {
	
}

export type UDCMessaging = {
	
}

export type UDCEventConnector = {
	
}

-- automatic compression, by checking if there is an overhead if compressed or not
local function compare_and_compress(meta : __UDCInfo_Internal, data : { any? })
	local buff, flag = Compressor.TryToCompress(data, meta.CompressionLevel, meta.CompressionThreshold)

	return buff, flag
end

-- for deepcloning table
local function deepclone(tab)
	if typeof(tab) ~= "table" then
		return tab
	end		
	local newTab = table.clone(tab)

	for k, v in pairs(tab) do
		if typeof(v) == "table" then
			newTab[k] = deepclone(v)
		end
	end

	return newTab
end

-- to call event
local function dispatch(record, eventName, ...)
	local args = table.pack(...)
	
end

-- to call specific, OnDataError event, with message
local function throw(record, message)
	
end

-- to reconcile data, where the data will be reconciled with the blueprint
local function reconcile(data : {any}, blueprint : {any})
	for key, value in pairs(blueprint) do
		if data[key] == nil then
			data[key] = value
		elseif typeof(value) == "table" and typeof(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
end

-- finding a heart (value of a key) within a girl (table)
local function find_element(girl : {any}, heart : any, tries : number?)
	tries = tries or 1 -- tries is an index where the element can be found inside and obtained
	-- As example:
	--[[
	You have a table like this:
	{
		Inventory = 
		{
			Inventory = 30,
			...
		}
	}
	
	If you use default tries index or 1. You will return the "Inventory" element that has the table as value.
	Regarding to the example above, if you want to get the "Inventory" element that has number value, you need to set the tries to 2.
	
	If there is no element that matches the needle, it will return nil
	--]]
	
	local count = 0
	for key, value in pairs(girl) do
		if key == heart then
			count += 1
			
			if count == tries then
				return value, count
			end
		end
		
		if typeof(value) == "table" then
			local element, subcount = find_element(value, heart, tries - count)
			count += subcount
			
			if element then
				return element, count
			end
		end
	end
	
	return nil, count
end

-- changing a heart (value of a key) with an intention (intended value) within a girl (table)
local function change_element(girl : {any}, heart : any, intention : any, tries : number?)
	tries = tries or 1 -- tries is an index where the element can be found inside and obtained
	-- As example:
	--[[
	You have a table like this:
	{
		Inventory = {
			Inventory = 30,
			...
		}
	}
	
	If you use default tries index or 1. You will change the "Inventory" element that has the table as value, into your intended value.
	Regarding to the example above, if you want to change the "Inventory" element that has number value, you need to set the tries to 2.
	
	It will return true if it's successfully changed, otherwise it will return false.
	If you ever tries to out of the tries, it will return false of change nothing.
	--]]
	
	local count = 0
	for key, value in pairs(girl) do
		if key == heart then
			count += 1
			
			if count == tries then
				girl[key] = intention
				return true, count
			end
		end
		
		if typeof(value) == "table" then
			local success, subcount = change_element(value, heart, intention, tries - count)
			count += subcount
			
			if success then
				return true, count
			end
		end
	end
	
	return false, count
end

-- to load the data, where it's running in a session
local function load_data(meta : __UDCInfo_Internal, record : UDCRecord)
	local entry -- empty entry
	
	-- Checking if WAL Entry is exist
	local ok, result = pcall(function() return meta._CurrentWALDataStore:GetAsync(record.Key) end)
	if meta.WALEnabled and ok and result then
		-- Change the entry to the WAL Entry
		entry = result
	end

	local thisOwnerId = record.Owner and record.Owner.UserId or 0
	local now = workspace:GetServerTimeNow()
	local attempts = 0
	
	-- Use UpdateAsync to load data, also handle the WAL
	local success, result
	meta._LockSessions:Do(record.Key, function()
		success, result = pcall(function()
			return meta._CurrentDataStore:UpdateAsync(record.Key, function(CurrentData)
				-- Checking if current data have these bound elements
				if CurrentData and CurrentData.__bounds and CurrentData.__bounds.id and CurrentData.__bounds.serverid then
					local bounds = CurrentData.__bounds
					local id = CurrentData.__bounds.id -- UserId of the player who owns this data
					local serverid = CurrentData.__bounds.serverid -- ServerID (JobID) of server whose this data to commit
					local lastHeartbeat = CurrentData.__bounds.lastheartbeat or 0 -- Time when the server claimed this data

					-- Checking if the server is still alive
					local isStale = now - lastHeartbeat > meta.StaleServerClaimingTime

					local isDifferentOwner = thisOwnerId ~= id -- Checking if the owner is different
					local isDifferentServer = serverid and serverid ~= ServerId and not isStale -- Checking if the server is different and not dead/stale

					-- If the data is owned by a different player or a different server, return nil to force an invalid result
					if isDifferentOwner or isDifferentServer then
						return nil
					end
				end

				-- If the data is not exist, or the data is exist but the server is dead/stale, use the WAL entry, or the compressed blueprint
				CurrentData = CurrentData or entry or deepclone(meta._CompressedBlueprint)

				-- Checking WAL entry if exist and has a newer version than the current data
				if entry and entry.__version and entry.__version > (CurrentData.__version or 0) then
					-- Use the WAL entry if it's newer
					CurrentData = entry
				end

				-- Rebinding the data with the new bounds, if some elements are already belongs to a player or something, it remains same
				CurrentData.__bounds = {
					id = CurrentData.__bounds and CurrentData.__bounds.id or thisOwnerId,
					serverid = ServerId,
					since = CurrentData.__bounds and CurrentData.__bounds.since or now,
					lastheartbeat = now,
				}
				return CurrentData
			end)
		end)
	end)
	
	-- Checking if the result is success and has a valid data, and WAL entry is existed
	if success and result and entry then
		-- Remove the WAL entry after successfully commiting the data
		pcall(function()  
			meta._CurrentWALDataStore:RemoveAsync(record.Key)
		end)
	end

	return result
end

local function save_data(meta : __UDCInfo_Internal, record : UDCRecord)
	local now = workspace:GetServerTimeNow()
	local thisOwnerId = record.Owner and record.Owner.UserId or 0
	
	local dataCache = meta._DataCache[record.Key]
	if not dataCache then return false end
	
	local tempData = dataCache.__data
	
	local compressed, flag
	local found = false
	
	local existed = meta._CompressionStack[record.Key]
	
	if existed then
		if not existed.Dirty and record._LastCompressedData and record._LastFlagData then
			compressed, flag = record._LastCompressedData, record._LastFlagData
		else
			local ok, newCompressed, newFlag = pcall(compare_and_compress, meta, tempData)

			if not ok then
				return false
			end

			compressed, flag = newCompressed, newFlag

			record._LastCompressedData = compressed
			record._LastFlagData = flag

			existed.Tick = now
			existed.Dirty = false
		end
	else
		local ok, newCompressed, newFlag = pcall(compare_and_compress, meta, tempData)
		if not ok then return false end

		compressed, flag = newCompressed, newFlag

		record._LastCompressedData = compressed
		record._LastFlagData = flag
	end
	
	dataCache.__version = (dataCache.__version or 0) + 1
	dataCache.__flag = flag
	
	local commitedData = deepclone(dataCache)
	commitedData.__data = compressed
	
	local success, result
	meta._LockSessions:Do(record.Key, function()
		success, result = pcall(function()
			return meta._CurrentDataStore:UpdateAsync(record.Key, function(CurrentData)
				if CurrentData and CurrentData.__bounds and CurrentData.__bounds.id and CurrentData.__bounds.serverid then
					local id = CurrentData.__bounds.id
					local serverid = CurrentData.__bounds.serverid
					local lastHeartbeat = CurrentData.__bounds.lastheartbeat or 0

					local isStale = now - lastHeartbeat > meta.StaleServerClaimingTime

					local isDifferentOwner = thisOwnerId ~= id			
					local isDifferentServer = serverid and serverid ~= ServerId and not isStale

					local isCacheStale = now - (dataCache.__bounds and dataCache.__bounds.since or 0) > meta.StaleServerClaimingTime

					local isServerNotSameAsCache = dataCache.__bounds and dataCache.__bounds.serverid and dataCache.__bounds.serverid ~= serverid and not isCacheStale
					local isOwnerNotSameAsCache = dataCache.__bounds and dataCache.__bounds.id and dataCache.__bounds.id ~= id
					
					-- If the data from cache is owned by a different player or a different server, return nil to force an invalid result
					if isServerNotSameAsCache or isOwnerNotSameAsCache then
						return nil
					end

					-- If the data is owned by a different player or a different server, return nil to force an invalid result
					if isDifferentOwner or isDifferentServer then
						return nil
					end
				end
								
				CurrentData = CurrentData or commitedData or deepclone(meta._CompressedBlueprint)

				if commitedData.__version and commitedData.__version > (CurrentData and CurrentData.__version or 0) then
					CurrentData = commitedData
				end

				CurrentData.__bounds.lastheartbeat = now			
				return CurrentData
			end)
		end)
	end)
	
	local status = success and result
	if status then
		local standbyRegistry = meta._StandbyRegistry[record.Key]
		if standbyRegistry then
			standbyRegistry.Dirty = false
		end
	end
	
	return status
end

local function standby_release(meta : __UDCInfo_Internal, record : UDCRecord)
	local sleep = record:Sleep()
	if sleep then
		meta._StandbyRegistry[record.Key] = nil
	end
end

local function write_to_wal_or_fs(meta : __UDCInfo_Internal, record : UDCRecord, now : number)
	local currentData = meta._DataCache[record.Key]
	if not currentData then
		return false
	end
	
	local clonedRecord = deepclone(currentData)
	clonedRecord.__version = (clonedRecord.__version or 0) + 1
	
	local data = deepclone(clonedRecord.__data)
	local thisOwnerId = record.Owner and record.Owner.UserId or 0
	
	local compressed, flag
	local found = false

	local existed = meta._CompressionStack[record.Key]

	if existed then
		if not existed.Dirty and record._LastCompressedData and record._LastFlagData then
			compressed, flag = record._LastCompressedData, record._LastFlagData
		else
			local ok, newCompressed, newFlag = pcall(Compressor.TryToCompress, data, EMERGENCY_COMPRESSION_LEVEL, meta.CompressionThreshold)

			if not ok then return false end

			compressed, flag = newCompressed, newFlag
		end
	else
		local ok, newCompressed, newFlag = pcall(Compressor.TryToCompress, data, EMERGENCY_COMPRESSION_LEVEL, meta.CompressionThreshold)
		if not ok then return false end

		compressed, flag = newCompressed, newFlag
	end
	
	local success, result
	meta._LockSessions:Do(record.Key, function()
		success, result = pcall(function()
			return meta._CurrentWALDataStore:UpdateAsync(record.Key, function(CurrentData)
				if CurrentData and CurrentData.__bounds and CurrentData.__bounds.id and CurrentData.__bounds.serverid then
					local id = CurrentData.__bounds.id
					local serverid = CurrentData.__bounds.serverid
					local lastHeartbeat = CurrentData.__bounds.lastheartbeat or 0

					local isStale = now - lastHeartbeat > meta.StaleServerClaimingTime
					local isCacheStale = now - (clonedRecord.__bounds and clonedRecord.__bounds.lastheartbeat or 0) > meta.StaleServerClaimingTime

					local isServerNotSameAsCache = clonedRecord.__bounds and clonedRecord.__bounds.serverid and clonedRecord.__bounds.serverid ~= serverid and clonedRecord.__bounds.serverid ~= ServerId and not isCacheStale
					local isOwnerNotSameAsCache = clonedRecord.__bounds and clonedRecord.__bounds.id and clonedRecord.__bounds.id ~= id and clonedRecord.__bounds.id ~= thisOwnerId

					local isDifferentServer = serverid and serverid ~= ServerId and not isStale
					local isDifferentOwner = id and id ~= thisOwnerId and not isStale

					if isServerNotSameAsCache or isOwnerNotSameAsCache then
						return nil
					end

					if isDifferentServer or isDifferentOwner then
						return nil
					end
				end

				CurrentData = CurrentData or clonedRecord

				if clonedRecord.__version and CurrentData and CurrentData.__version and clonedRecord.__version > (CurrentData.__version or 0) then
					CurrentData = clonedRecord
				end

				CurrentData.__data = compressed
				CurrentData.__flag = flag

				return CurrentData
			end)
		end)
	end)
	
	local result = success and result
	
	if result and not meta._ShutdownCalled then
		local isForcedSaveSuccess = pcall(record.ForceSave, record)
		local pendingSave = meta._SavePendingQueue[record.Key]
		
		if pendingSave then
			meta._SavePendingQueue[record.Key] = nil
		end
		
		if isForcedSaveSuccess then
			pcall(function() meta._CurrentWALDataStore:RemoveAsync(record.Key) end)
		end
	end
	
	return result
end

local function fallback_backup(meta : __UDCInfo_Internal, record : UDCRecord)
	if not meta.BackupEnabled then
		return nil
	end
	
	local thisOwnerId = record.Owner and record.Owner.UserId or 0
	local now = workspace:GetServerTimeNow()
	
	local success, result = pcall(function()
		return meta._CurrentDataStore:ListVersionsAsync(record.Key, Enum.SortDirection.Descending)
	end)
	
	if success and result then
		local lastData = result:GetCurrentPage()[1]
		if lastData == nil then return nil end
		
		local ok, backupData = pcall(function()
			return meta._CurrentDataStore:GetVersionAsync(record.Key, lastData.Version)
		end)
		
		if ok and backupData then
			return meta._CurrentDataStore:UpdateAsync(record.Key, function(CurrentData)
				if CurrentData and CurrentData.__bounds and CurrentData.__bounds.id and CurrentData.__bounds.serverid then
					local bounds = CurrentData.__bounds
					local id = CurrentData.__bounds.id
					local serverid = CurrentData.__bounds.serverid
					local lastHeartbeat = CurrentData.__bounds.lastheartbeat or 0

					local isStale = now - lastHeartbeat > meta.StaleServerClaimingTime

					local isDifferentOwner = thisOwnerId ~= id
					local isDifferentServer = serverid and serverid ~= ServerId and not isStale

					if isDifferentOwner or isDifferentServer then
						return nil
					end
				end
				
				CurrentData = CurrentData or backupData or deepclone(meta._CompressedBlueprint)

				if backupData and backupData.__version and backupData.__version > (CurrentData and CurrentData.__version or 0) then
					CurrentData = backupData
				end

				CurrentData.__bounds = {
					id = CurrentData.__bounds and CurrentData.__bounds.id or thisOwnerId,
					serverid = ServerId,
					since = CurrentData.__bounds and CurrentData.__bounds.since or now,
					lastheartbeat = now,
				}
				return CurrentData
			end)
		end
	end
	
	return nil
end

local function run_load_queue(meta : __UDCInfo_Internal)
	if meta._IsObtainingRunning or meta._ShutdownCalled then return end
	meta._IsObtainingRunning = true
	
	RunService.Heartbeat:Connect(function(_)
		if not meta.Enabled or not UDataComponent.Enabled or meta._ShutdownCalled then return end -- Preventing dead UDataComponent to do commands
		
		local obtain = meta._ObtainPendingQueue
		local perTick = meta.MaxDataObtainingPerTick

		while #obtain > 0 and meta._CurrentLoadWorkers < meta.MaxConcurrentLoadWorkers do
			local first = table.remove(obtain, 1)

			local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
			local obtainBudget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync)

			if budget < perTick or obtainBudget < 2 then
				break -- No budget left, stops current load request until next frame
			end

			if first.Meta and first.Meta.Owner and Players:GetPlayerByUserId(first.Meta.Owner.UserId) == nil then
				task.spawn(first.Thread, false, nil) -- Player left, cancel the load request
				continue
			end

			meta._CurrentLoadWorkers += 1 -- Workers in working
			task.spawn(function()
				local success, result = pcall(load_data, meta, first.Meta)

				if not success then -- Probably happened when the data is failed to be loaded, fallback to the backup
					success, result = pcall(fallback_backup, meta, first.Meta)
				end

				meta._CurrentLoadWorkers -= 1 -- Workers finised the work
				task.spawn(first.Thread, success, result) -- Continue the thread, regardless of the result
			end)
		end
	end)
end

local function run_save_queue(meta : __UDCInfo_Internal)
	if meta._IsSaveRunning or meta._ShutdownCalled then return end
	meta._IsSaveRunning = true
	
	RunService.Heartbeat:Connect(function(_)
		if not meta.Enabled or not UDataComponent.Enabled or meta._ShutdownCalled then return end -- Preventing dead UDataComponent to do commands
		
		local save = meta._SavePendingQueue
		local perTick = meta.MaxDataSavingPerTick
		
		while #save > 0 and meta._CurrentSaveWorkers < meta.MaxConcurrentSaveWorkers do
			local first = table.remove(save, 1)
			
			local saveBudget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
			
			if saveBudget < perTick then
				break -- No budget left, stops current save request until next frame
			end
			
			if first.Meta and first.Meta.Key and not meta._DataCache[first.Meta.Key] then
				task.spawn(first.Thread, false) -- Data is already unloaded, cancel the save request
				continue
			end
			
			meta._CurrentSaveWorkers += 1 -- Workers in working
			task.spawn(function()
				local success, err = pcall(save_data, meta, first.Meta)
				
				print(success, err)
				
				meta._CurrentSaveWorkers -= 1 -- Workers finised the work
				task.spawn(first.Thread, success) -- Continue the thread, regardless of the result
			end)
		end
	end)
end

local function run_compression_timer(meta : __UDCInfo_Internal)
	if meta._IsCompressionTimerRunning or meta._ShutdownCalled then return end
	meta._IsCompressionTimerRunning = true
	
	RunService.Heartbeat:Connect(function(_)
		if not meta.Enabled or not UDataComponent.Enabled or meta._ShutdownCalled then return end -- Preventing dead UDataComponent to do commands
		
		local now = workspace:GetServerTimeNow()
		for key, timer in pairs(meta._CompressionStack) do
			if timer.Record and timer.Tick and meta._DataCache[key] then
				if timer.Dirty and now - timer.Tick > meta.CompressionQueueCooldown then
					local success, compressed, flag = pcall(compare_and_compress, meta, meta._DataCache[key].__data)
					if success then
						timer.Record._LastCompressedData = compressed
						timer.Record._LastFlagData = flag
						
						timer.Dirty = false
						timer.Tick = now
					end
				end
			end
		end
	end)
end

local function set_standby_place(meta : __UDCInfo_Internal)
	if meta._StandbyReady or meta._ShutdownCalled then return end
	meta._StandbyReady = true
	
	Players.PlayerRemoving:Connect(function(Player)
		local userId = Player.UserId
		local now = workspace:GetServerTimeNow()
		
		for key, record in pairs(meta._StandbyRegistry) do
			local isPending = meta._SavePendingQueue[key]
			local sameOwner = record.Owner and record.Owner.UserId == userId
			
			if sameOwner then
				write_to_wal_or_fs(meta, record, now)
				standby_release(meta, record)
				break
			end
		end
	end)
	
	game:BindToClose(function()
		meta._ShutdownCalled = true
		
		local workerThreads = {}
		local working = { count = 0 }
		
		local now = workspace:GetServerTimeNow()
		
		for key, record in pairs(meta._StandbyRegistry) do
			table.insert(workerThreads, task.spawn(function(working)
				write_to_wal_or_fs(meta, record, now)
				standby_release(meta, record)
				
				working.count -= 1
			end, working))
			
			working.count += 1
		end
		
		local seconds = 0
		while #workerThreads > 0 and working.count > 0 and seconds < 25 do
			seconds += 1
			task.wait(1)
		end
	end)
end

local function enqueue_load(meta : __UDCInfo_Internal, record : UDCRecord)
	run_load_queue(meta) -- First-time run the load queue if it's not running
	
	local currentThread = coroutine.running()
	table.insert(meta._ObtainPendingQueue, {
		Meta = record,
		Thread = currentThread,
	})
	
	return coroutine.yield() -- Yield until the data is loaded, and returns the status and loaded data
end

local function enqueue_save(meta : __UDCInfo_Internal, record : UDCRecord)
	run_save_queue(meta) -- First-time run the save queue if it's not running
	
	local currentThread = coroutine.running()
	table.insert(meta._SavePendingQueue, {
		Meta = record,
		Thread = currentThread,
	})
	
	return coroutine.yield() -- Yield until the data is saved
end

local function push_compression_timer(meta : __UDCInfo_Internal, record : UDCRecord)
	run_compression_timer(meta) -- First-time run the compression timer if it's not running
	
	local now = workspace:GetServerTimeNow()

	local existed = meta._CompressionStack[record.Key]
	if existed then
		existed.Dirty = true
		return false
	end
	
	meta._CompressionStack[record.Key] = {
		Record = record,
		Tick = now,
		Dirty = true
	}
	
	return true
end

local function add_standby_record(meta : __UDCInfo_Internal, record : UDCRecord)
	set_standby_place(meta)
	
	if not meta._StandbyRegistry[record.Key] then
		meta._StandbyRegistry[record.Key] = record
		return true
	end
	
	return false
end

local function is_key_pending_load(meta : __UDCInfo_Internal, key : string)
	for _, pending in ipairs(meta._ObtainPendingQueue) do
		if pending.Meta and pending.Meta.Key == key then
			return true
		end
	end
	
	return false
end

local function is_key_pending_save(meta : __UDCInfo_Internal, key : string)
	for _, pending in ipairs(meta._SavePendingQueue) do
		if pending.Meta and pending.Meta.Key == key then
			return true
		end
	end
	
	return false
end

-- validator for data type checking
local function are_schemas_valid(meta : __UDCInfo_Internal, record : UDCRecord, data : {any})
	if not meta.ValidationEnabled then
		return true -- if validation service is dead, just allow
	end
	
	local key = record.Key
	local trackedSchemas = meta._TrackedSchemas[key]
	
	if not trackedSchemas then
		return true -- When the record isn't asked to be validated
	end
	
	for key, info in pairs(trackedSchemas) do
		local schema = info.Schema
		local penetration = info.Penetration
		
		if not schema or not penetration then
			continue -- just pass, if there are not informations about these from validators
		end
		
		local element = find_element(data, key, penetration) -- finding elements through nested ways
		
		if not element then
			continue -- if there is no key in the data, it's probably just a "safety-net"
		end
		
		if typeof(element) ~= schema then
			return false -- are invalid when there is even one data hasn't same type as validators
		end
	end
	
	return true -- are valid if all data's schemas suited
end

-- validator for data value clamping, automatic operations, void
local function clamp_values(meta : __UDCInfo_Internal, record : UDCRecord, data : {any})
	if not meta.ValidationEnabled then
		return -- no clamping when validation service is dead
	end
	
	local key = record.Key
	local trackedClamps = meta._TrackedClamps[key]
	
	if not trackedClamps then
		return -- When the record isn't asked to be clamped
	end
	
	for key, info in pairs(trackedClamps) do
		local min, max = info.Min, info.Max
		local penetration = info.Penetration
		
		if not min or not max or not penetration then
			continue -- just pass, if there is no these elements in validator
		end
		
		local element = find_element(data, key, penetration)
		if not element or typeof(element) ~= "number" then
			continue -- if there is no element that want to be clamped OR it's not a number
		end
		
		local clamp = math.clamp(element, min, max)
		local success = change_element(data, key, clamp, penetration)
		
		if not success then
			continue -- if there is no element that want to be clamped
		end
	end
end

-- validator for data value checking
local function are_datas_valid(meta : __UDCInfo_Internal, record : UDCRecord, data : {any})
	if not meta.ValidationEnabled then
		return true -- if validation service is dead, just allow
	end

	local key = record.Key
	local trackedValidations = meta._TrackedValidations[key]

	if not trackedValidations then
		return true -- When the record isn't asked to be validated
	end

	for key, info in pairs(trackedValidations) do
		local predicate = info.Predicate
		local penetration = info.Penetration
		
		if not predicate or not penetration then
			continue -- just pass, if there's no these elements in validator
		end
		
		local element = find_element(data, key, penetration)
		if not element then
			continue -- if there is no element that want to be validated
		end
		
		if not predicate(element) then
			return false -- if there is one data that is not valid or same as predicate, return false
		end
	end
	
	return true -- are valid if all data's validations matched
end

local function current_record(meta : __UDCInfo_Internal, key : number | string, owner : Player?)
	if meta._ActiveRecords[key] then
		return meta._ActiveRecords[key]
	end
	
	local record = {}
	record.Key = key -- This is the key of the record
	record.Owner = owner -- This is the owner of the record
	record.IsArchived = false -- This is to indicate if the record is archived or not
	record.Event = nil -- Utils of events for this record
	record.Validation = nil -- Utils to create validation for this record
	record.Swap = nil -- Utils to swap data with other record
	record.Messaging = nil -- Utils to Broadcasting to other servers
	record.Version = 0 -- This is the version of the data, it will be increased when the data is saved
	record.Data = nil -- This is the data of the record
	record.CurrentState = "Asleep"
	
	record._ReadyProgress = false -- This is to indicate if the record's ready in progress
	record._SleepProgress = false -- This is to indicate if the record's sleep in progress
	record._SaveProgress = false -- This is to indicate if the record's save in progress, where Save and Write shares this variable
	-- Because Write and Save are same, but have different roles in record commiting
	
	record._LastCompressedData = nil -- This is to store the last compressed data
	record._LastFlagData = nil -- This is to store the last flag data, of compression
	record._CompressionDirtyFlag = false -- This is to indicate if the record's data is dirty, meaning it hasn't been compressed yet
	
	-- State machines: Asleep -> WakingUp -> Ready -> Sleeping || Asleep
	-- Difference of Asleep and Sleeping, Asleep is when the data is loaded first time, meanwhile Sleeping is when the data is released and saved, but can be called by Awake again
	
	-- Clone of data template/blueprint	
	local function get_blueprint()
		return meta._CompressedBlueprint
	end
	
	-- Real flows usage:
	-- Awake() -> Ready() -> Standby() -> Save() -> Sleep() -> Record died
	-- In Standby(), it will automatically handle Save() and Sleep() when triggered, it could be player leaving or server shutdown
	
	-- Use Standby() if want the data releasing and saving data automaticaly by UDC
	-- Use Sleep() if you want to handle the data releasing and saving data manually
	-- Actually, Sleep() is already used inside of Standby()
	
	-- CAUTION: If you ever tried to access record.Data after releasing, like after Sleep() or Standby(). You will return nothing but nil, because the data already released and should be gone from this server session
	
	-- Should be called first, this is where the player's data record is awake and loaded
	-- In Awake, also checks if this server owns the data, it will check if current owner was this player
	-- SUSPENDING (YIELDABLE), where Awake waits for dequeue session until the data is loaded
	function record:Awake()
		if record.CurrentState ~= "Asleep" and record.CurrentState ~= "Sleeping" then
			return false
		end
		
		local success, result = enqueue_load(meta, record)
		
		if success and not result then
			record.CurrentState = "Sleeping"
			meta._UnreadyData[record.Key] = nil
			return false
		elseif success and result then
			record.CurrentState = "WakingUp"
			meta._UnreadyData[record.Key] = result
			return true
		end
		
		record.CurrentState = "Sleeping"
		meta._UnreadyData[record.Key] = nil
		return false
	end
	
	-- After the data record is awake, we need to make the data is actually ready to be used
	-- I made the data compressed into buffer to reduce the size of data
	-- Here we are, Ready() called to make a hard-checking and evaluating every security and data details
	-- Then the data will be decompressed and record.Data can be accessed to get the read data
	-- SUSPENDING (YIELDABLE), where Ready yields for checking every details until its done checking and applied to cache
	function record:Ready(FindingPlayerTimeout: number?)
		FindingPlayerTimeout = FindingPlayerTimeout or 10
		
		local function penalty()
			record._ReadyProgress = false
			
			record.CurrentState = "Sleeping"
			meta._UnreadyData[record.Key] = nil
		end
		
		if not UDataComponent.IsAlive() then
			return false
		end
		
		print("1")
				
		if not meta.Enabled or not UDataComponent.Enabled then
			return false
		end
		
		print("2")
				
		-- Whether the data is already waking up or not, if not, maybe cannot ready or already running
		if record.CurrentState ~= "WakingUp" then
			return false
		end
		
		print("3")
				
		if record._ReadyProgress then
			return false
		end
		
		print("4")
				
		record._ReadyProgress = true
		
		if meta._DataCache[record.Key] ~= nil then
			record.CurrentState = "Sleeping"
			return false
		end
		
		print("5")	
		
		local now = workspace:GetServerTimeNow()
		local unready = meta._UnreadyData[record.Key]
		
		-- Checking if the raw/unready data already loaded
		if not unready then
			record._ReadyProgress = false
			record.CurrentState = "Sleeping"
			return false
		end		
		
		print("6")	

		if meta._ActiveRecords[record.Key] then
			penalty()
			return false
		end
		
		print("7")	
				
		-- Checking if the was archived or not
		if record.IsArchived then
			penalty()
			return false
		end
		
		print("8")	
				
		-- Checking if essential elements of data are existing
		if not unready.__version or not unready.__bounds or not unready.__data or not unready.__flag then
			penalty()
			return false
		end
		
		print("9")	
				
		-- Checking if bound elements in the data are existed
		if not unready.__bounds or not unready.__bounds.id or not unready.__bounds.since or not unready.__bounds.serverid then
			penalty()
			return false
		end
		
		print("10")	
				
		-- Checking if the data is owned by this server
		if unready.__bounds.serverid ~= ServerId then
			penalty()
			return false
		end
		
		print("11")	
				
		-- Checking if the data is owned by this player
		if record.Owner and record.Owner.UserId ~= unready.__bounds.id then
			penalty()
			return false
		end
		
		print("12")	
				
		-- Checking if the data is still bound to this player
		local timeout = 60 * 60 * 24 * (meta.OwnershipExpiration or 1)
		if now - unready.__bounds.since > timeout then
			penalty()
			return false
		end
		
		print("13")	
				
		-- Checking if player is still in the server
		local playerFound = false
		while record.Owner and not playerFound do
			-- If the player is still in the server, then it's ready
			if Players:GetPlayerByUserId(record.Owner.UserId) ~= nil then
				playerFound = true
				-- If timeout is set, then it's not ready yet
			elseif workspace:GetServerTimeNow() - now > FindingPlayerTimeout then
				penalty()
				return false
			else
				task.wait(1)
			end
		end
		
		print("14")	
				
		local compressedData = unready.__data
		local flagData = unready.__flag -- 'C' means compressed, 'R' means raw/real
		
		local success, data = pcall(function()
			return Compressor.TryToDecompress(compressedData, flagData)
		end)
		
		-- Checking if the data is successfully decompressed
		if not success then
			warn(data)
			penalty()
			return false
		end
		
		print("15")	
				
		-- Checking if the data is a table
		if typeof(data) ~= "table" then
			penalty()
			return false
		end
		
		print("16")	
				
		-- Checking if the data size is not too big
		if Compressor.GetSize(data) > meta.MaxDecompressedSize then
			penalty()
			return false
		end
		
		print("17")	
				
		-- Reconcilate the data with the blueprint, to prevent data corruption or data loss
		reconcile(data, meta.DataBlueprint)
		
		-- Checking if all datas are valid, even one invalid will case unready condition for strict checking
		if not are_schemas_valid(meta, record, data) then
			penalty()
			return false
		end
		
		print("18")	
				
		-- Clamping all values with the validations, if the element was a number type
		clamp_values(meta, record, data)
		
		-- Checking if datas are actually same as their own predicates
		if not are_datas_valid(meta, record, data) then
			penalty()
			return false
		end
		
		print("19")	
				
		-- Apply the data to the cache
		record.Data = data -- Data is now ready to be used
		record.CurrentState = "Ready" -- Current state is ready to do things
		record.Version = meta._UnreadyData[record.Key].__version or 0 -- Set the version of this record to real data version
		
		meta._UnreadyData[record.Key] = nil -- Remove the unready data, because the data is ready
		
		meta._DataCache[record.Key] = unready -- Catch the record after filter
		meta._DataCache[record.Key].__data = data  -- Cache the real data after compression
		
		meta._ActiveRecords[record.Key] = record -- Add the record to active records, so developer can access the record
		
		record._ReadyProgress = false
		
		return true
	end
	
	function record:Standby()
		
	end
	
	-- Releasing the data from session, where this means this record has been fell asleep and cannot use the data anymore, unless you call Awake() to wake it up again
	function record:Sleep()
		if not meta.Enabled or not UDataComponent.Enabled then
			return false
		end
		
		if record._ReadyProgress then
			return false
		end
		
		if record._SleepProgress then
			return false
		end
		
		record._SleepProgress = true
		
		if record.CurrentState ~= "Ready" then
			record._SleepProgress = false
			return false
		end
		
		if record.Data == nil then
			record._SleepProgress = false
			return false
		end
		
		local now = workspace:GetServerTimeNow()
		local dataCache = meta._DataCache[record.Key]
		if not dataCache or not dataCache.__bounds then
			record._SleepProgress = false
			return false
		end
		
		-- Checking if the data is still pending to save
		while is_key_pending_save(meta, record.Key) do
			task.wait()
		end
		
		local thisOwnerId = record.Owner and record.Owner.UserId or 0		
		local success, result = pcall(function()
			return meta._CurrentDataStore:UpdateAsync(record.Key, function(CurrentData)
				if CurrentData and CurrentData.__bounds and CurrentData.__bounds.serverid and CurrentData.__bounds.lastheartbeat and CurrentData.__bounds.id then
					local isSameServer = CurrentData.__bounds.serverid == ServerId
					local isSameOwner = CurrentData.__bounds.id == thisOwnerId
					
					if isSameServer and isSameOwner then
						CurrentData.__bounds.serverid = nil
						CurrentData.__bounds.lastheartbeat = nil
						CurrentData.__bounds.id = nil
						CurrentData.__bounds.since = now
					end
					
					return CurrentData
				end
				
				return nil
			end)
		end)
		
		if success and result then
			record.Owner = nil
			record.Data = nil
			record.Version = 0
				
			record.CurrentState = "Asleep"
			record._SleepProgress = false
			
			meta._DataCache[record.Key] = nil
			meta._ActiveRecords[record.Key] = nil
			
			return true
		end
		
		return false
	end
	
	-- Reluctantly saving current data from the modification of .Data from record, but you can use another data to save
	-- Use SegmentIndex if you ever want to make cheaper data to save
	function record:Save(Data: any?, SegmentIndex: number?)
		if not meta.Enabled or not UDataComponent.Enabled then
			return false
		end
		
		print("1")
		
		if record._SaveProgress then
			return false
		end
		record._SaveProgress = true
		
		print("2")
		
		if record._SleepProgress then
			record._SaveProgress = false
			return false
		end
		
		print("3")
		
		if record._ReadyProgress then
			record._SaveProgress = false
			return false
		end
		
		print("4")
		
		if record.CurrentState ~= "Ready" then
			record._SaveProgress = false
			return false
		end
		
		print("5")
		
		local data = meta._DataCache[record.Key]
		if not data or not data.__data then
			record._SaveProgress = false
			return false
		end
		
		print("6")
		
		if record.Data == nil then
			record._SaveProgress = false
			return false
		end
		
		print("7")
		
		meta._LockSessions:Do(record.Key, function()
			local commitedData = Data or record.Data
			if SegmentIndex then
				data.__data[SegmentIndex] = commitedData
			else
				data.__data = commitedData
			end		
			
			record.Data = deepclone(data.__data)
		end)
		push_compression_timer(meta, record)
		
		local success = enqueue_save(meta, record)
		
		record._SaveProgress = false
		if success then
			return true
		end
		
		print("8")
		
		return false
	end
	
	-- Easy, safe way to modificate the data of this record
	-- Where Write() allows you to modificate the data safely with validation checking and compression operations
	function record:Write(WritingFunction: (CurrentData: any) -> ())
		if not meta.Enabled or not UDataComponent.Enabled then
			return false
		end
		
		local now = workspace:GetServerTimeNow()
		if meta._WriteTimestamp[record.Key] and now - meta._WriteTimestamp[record.Key] > meta.DataWritingCooldown then
			return false
		end
		
		if record._SaveProgress then
			return false
		end
		record._SaveProgress = true
		
		if record._SleepProgress then
			record._SaveProgress = false
			return false
		end
		
		if record._ReadyProgress then
			record._SaveProgress = false
			return false
		end
		
		if record.CurrentState ~= "Ready" then
			record._SaveProgress = false
			return false
		end
		
		local data = meta._DataCache[record.Key]
		if not data or not data.__data then
			record._SaveProgress = false
			return false
		end
		
		local customData = deepclone(data.__data)
		local success = pcall(WritingFunction, customData)
		
		if not success then
			record._SaveProgress = false
			return false
		end
		
		if not are_schemas_valid(meta, record, customData) then
			record._SaveProgress = false
			return false
		end
		
		clamp_values(meta, record, customData)
		
		if not are_datas_valid(meta, record, customData) then
			record._SaveProgress = false
			return false
		end
		
		meta._LockSessions:Do(record.Key, function()
			data.__data = customData
			record.Data = deepclone(customData)
		end)
		
		push_compression_timer(meta, record)
		
		local success = enqueue_save(meta, record)
		
		record._SaveProgress = false
		if success then
			meta._WriteTimestamp[record.Key] = now
			return true
		end
		
		return false
	end
	
	function record:ForceSave(Data: any?, SegmentIndex: number?)
		if not meta.Enabled or not UDataComponent.Enabled then
			return false
		end

		local now = workspace:GetServerTimeNow()
		if meta._WriteTimestamp[record.Key] and now - meta._WriteTimestamp[record.Key] > meta.DataWritingCooldown then
			return false
		end

		if record._SaveProgress then
			return false
		end
		record._SaveProgress = true

		if record._SleepProgress then
			record._SaveProgress = false
			return false
		end

		if record._ReadyProgress then
			record._SaveProgress = false
			return false
		end

		if record.CurrentState ~= "Ready" then
			record._SaveProgress = false
			return false
		end

		local data = meta._DataCache[record.Key]
		if not data or not data.__data then
			record._SaveProgress = false
			return false
		end

		if record.Data == nil then
			record._SaveProgress = false
			return false
		end
		
		local thisOwnerId = record.Owner and record.Owner.UserId or 0
		
		local isSuccess = false
		meta._LockSessions:Do(record.Key, function()
			local commitedData = Data or record.Data
			
			if SegmentIndex then
				data.__data[SegmentIndex] = commitedData
			else
				data.__data = commitedData
			end		
			
			local clonedRecord = deepclone(data)
			record.Data = deepclone(clonedRecord.__data)
						
			local compressed, flag
			local found = false

			local existed = meta._CompressionStack[record.Key]

			if existed then
				if not existed.Dirty and record._LastCompressedData and record._LastFlagData then
					compressed, flag = record._LastCompressedData, record._LastFlagData
				else
					local ok, newCompressed, newFlag = pcall(compare_and_compress, meta, clonedRecord.__data)

					if not ok then return false end

					compressed, flag = newCompressed, newFlag

					record._LastCompressedData = compressed
					record._LastFlagData = flag

					existed.Tick = now
					existed.Dirty = false
				end
			else
				local ok, newCompressed, newFlag = pcall(compare_and_compress, meta, clonedRecord.__data)
				if not ok then return false end

				compressed, flag = newCompressed, newFlag

				record._LastCompressedData = compressed
				record._LastFlagData = flag
			end
			
			clonedRecord.__version = (clonedRecord.__version or 0) + 1
			clonedRecord.__flag = flag
			
			record.Version = clonedRecord.__version
			
			local success, result = pcall(function()
				return meta._CurrentDataStore:UpdateAsync(record.Key, function(CurrentData)
					if CurrentData and CurrentData.__bounds and CurrentData.__bounds.id and CurrentData.__bounds.serverid and CurrentData.__bounds.lastheartbeat then
						local id = CurrentData.__bounds.id
						local serverid = CurrentData.__bounds.serverid
						local lastheartbeat = CurrentData.__bounds.lastheartbeat or 0
						
						local isStale = now - lastheartbeat > meta.StaleServerClaimingTime
						
						local isDifferentServer = serverid ~= ServerId and not isStale
						local isDifferentOwner = id ~= thisOwnerId
						
						local isCacheStale = now - (clonedRecord.__bounds and clonedRecord.__bounds.since or 0) > meta.StaleServerClaimingTime

						local isServerNotSameAsCache = clonedRecord.__bounds and clonedRecord.__bounds.serverid and clonedRecord.__bounds.serverid ~= ServerId and clonedRecord.__bounds.serverid ~= serverid and not isCacheStale
						local isOwnerNotSameAsCache = clonedRecord.__bounds and clonedRecord.__bounds.id and clonedRecord.__bounds.id ~= thisOwnerId and clonedRecord.__bounds.id ~= id
						
						if isServerNotSameAsCache or isOwnerNotSameAsCache then
							return nil
						end
						
						if isDifferentServer or isDifferentOwner then
							return nil
						end
					end
					
					CurrentData = CurrentData or clonedRecord or deepclone(meta._CompressedBlueprint)
					
					if clonedRecord.__version and CurrentData and clonedRecord.__version > (CurrentData.__vision or 0) then
						CurrentData = clonedRecord
					end
					
					CurrentData.__data = compressed
					return CurrentData
				end)
			end)
			
			isSuccess = success and result
		end)
		
		if isSuccess then
			local walSuccess, result = pcall(function() return meta._CurrentWALDataStore:GetAsync(record.Key) end)
			
			if walSuccess and result then
				pcall(function() meta._CurrentWALDataStore:RemoveAsync(record.Key) end)
			end
			
			if meta._SavePendingQueue[record.Key] then
				meta._SavePendingQueue[record.Key] = nil
			end
		end
		record._SaveProgress = false

		return isSuccess
	end
	
	function record:ForceWrite(WritingFunction: (CurrentData: any) -> ())
		
	end
	
	function record:Detach()
		
	end
	
	function record:Unarchive()
		
	end
	
	return record	
end

function UDataComponent.InDataInfo(DataStoreName: string, Scope: string?, Configurations: { [string]: any?}) : UDCInfo
	Scope = Scope or "global"
	Configurations = Configurations or {}
	
	local storageKey = DataStoreName .. "-" .. Scope
	local infoStorage = InfosStorage[storageKey] or {}
	
	local self = setmetatable(infoStorage, UDataComponent)
	
	self.Name = DataStoreName
	self.Scope = Scope
	
	self.Enabled = true
	self.ValidationEnabled = true
	self.CallbackEnabled = true
	self.WALEnabled = true
	self.DataWritingCooldown = 3
	self.MaxKeyLength = 50
	self.BackupEnabled = true
	self.DefaultBackupAttempts = 5
	self.DefaultBackupYieldDuration = 3
	self.StrictlyUnallowDetaching = true
	self.AutoSaveEnabled = true
	self.AutoSaveInterval = 300
	self.WALDataSuffix = "_wal"
	self.WALMaxEntries = 50
	self.OwnershipExpiration = 1 -- 1 Day
	self.SwappingEnabled = true
	self.SwappingCooldown = 5
	self.CacheCleaningEnabled = true
	self.CacheCleaningInterval = 300
	self.DataBlueprint = {}
	self.ErrorReasonNamespace = "UDataComponent"
	self.CompressionLevel = 10
	self.CompressionThreshold = 5 -- Threshold of 5 bytes from the overhead
	self.CompressionQueueCooldown = 30
	self.MaxDecompressedSize = 4194304 -- 4 MB - 1 Byte
	self.LocalDataNamespace = "LUDataComponent"
	self.MessagingEnabled = false
	self.MessagingNamespace = "UDCBroadcast"
	self.MessagingSendingCooldown = 5
	self.MessagingReceivingCooldown = 5
	self.MessagingLocalListeningCooldown = 5
	self.ArchivationEnabled = true
	self.ArchivationSuffix = "_archived"
	self.MaxDataSavingPerTick = 4
	self.MaxDataObtainingPerTick = 4
	self.MaxConcurrentSaveWorkers = 5
	self.MaxConcurrentLoadWorkers = 5
	self.StaleServerClaimingTime = 90
	
	local clone = deepclone(self.DataBlueprint)
	local compressedBp, flagBp = compare_and_compress(self, clone)
	
	-- Clone of data template/blueprint for the record
	self._CompressedBlueprint = {
		__version = 0, -- Seed of the version for the record
		__bounds = nil, -- Seed of bounding data for the record
		__data = compressedBp, -- buffer of the data, regardless was compressed or not
		__flag = flagBp -- Flag of the data, to indicate if the data was compressed or not, 'C' for compressed, 'R' or else for not
	}

	self._CurrentDataStore = DataStoreService:GetDataStore(DataStoreName, Scope)
	self._CurrentWALDataStore = DataStoreService:GetDataStore(DataStoreName..self.WALDataSuffix, Scope)
	self._CurrentArchivedDataStore = DataStoreService:GetDataStore(DataStoreName..self.ArchivationSuffix, Scope)	
	
	self._ActiveRecords = {} -- { [Key: string] = UDCRecord }
	self._WriteTimestamp = {} -- { [Key: string] = timestamp: number }
	self._SwapTimestamp = {} -- { [Key: string] = timestamp: number }
	self._AutosaveTimestamp = {} -- { [Key: string] = timestamp: number }
	self._SavePendingQueue = {} -- { [Key: string] = {Key, Data, WAL, Backup } }
	self._ObtainPendingQueue = {} -- { [Key: string] = {Key, Data, WAL, Backup } }
	self._UnreadyData = {} -- { [Key: string] = true }
	self._DataCache = {} -- { [Key: string] = Data: any }
	self._CompressionStack = {} -- { [Key: string] = {Record: UDCRecord, Tick: number} }
	self._StandbyRegistry = {} -- { [Key: string] = Record: UDCRecord }
	self._LockSessions = ScopedMutex.new(Mutex)
	self._LocalBroadcastListeners = {} -- { [Key: string] = { [ListenerId: string] = Listener: function } }

	self._ExclusiveTimerCalled = false
	self._ShutdownCalled = false
	self._ExclusiveSafetyCalled = false
	self._IsSaveRunning = false
	self._IsObtainingRunning = false
	self._IsCompressionTimerRunning = false
	self._CacheCleaningCalled = false
	self._StandbyReady = false
	
	self._CurrentLoadWorkers = 0
	self._CurrentSaveWorkers = 0

	self._TrackedValidations = {} -- { [Key] = { Member = ValidationFunction, ... } }
	self._TrackedSchemas = {} -- { [Key] = { Member = ValidationFunction, ... } }
	self._TrackedClamps = {} -- { [Key] = { Member = ValidationFunction, ... } }

	self._UDataComponentCallbacks = {
		OnReady = {},
		OnDataLoaded = {},
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
		OnLocalBroadcastListenerClosed = {}
	}

	self._UDataComponentDynamicCallbacks = {
		OnReady = {},
		OnDataLoaded = {},
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
	}

	if Configurations then
		for key, value in pairs(Configurations) do
			self[key] = value
		end
	end
	
	InfosStorage[storageKey] = self
	return self :: UDCInfo
end

function UDataComponent.IsAlive()
	local success, result = pcall(function()
		return ConnectionTest:UpdateAsync("TestConnection", function(oldData)
			return "Alive"
		end)
	end)
	
	return success and result == "Alive" and UDataComponent.Enabled
end

function UDataComponent:GetCurrentRecord(Key: number | string, OwnerOfThisData: Player?) : UDCRecord
	if typeof(Key) == "string" and #Key > self.MaxKeyLength then
		warn(string.format("[%s] : Key is too long", self.ErrorReasonNamespace))
		Key = string.sub(Key, 1, tonumber(self.MaxKeyLength))
	end
	
	return current_record(self, Key, OwnerOfThisData) :: UDCRecord
end

function UDataComponent:GetLocalRecord() : UDCRecord
	local locKey = self.LocalDataNamespace .. "@" .. self._DataStoreName
	
	return current_record(self, locKey, nil) :: UDCRecord
end

return UDataComponent :: UDataComponent
