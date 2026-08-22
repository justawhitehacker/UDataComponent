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

local InfosStorage = {}

UDataComponent.Enabled = true

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
	DefaultDataLoadingAttempts : number, --  Strictly gives some attempts to data loading when tries to load the data
	DefaultDataLoadingYieldDuration : number, -- Yield duration between each attempt of load the data
	DefaultDataSavingAttempts : number, -- Strictly gives some attempts to save the data when tries to saving data
	DefaultDataSavingYieldDuration : number, -- Yield duration between each attempt of saving data
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

	_SaveTimestamp : { any? },
	_SwapTimestamp : { any? },
	_AutosaveTimestamp : { any? },
	_SavePendingQueue : { any? },
	_ObtainPendingQueue : { any? },
	_DataCache : { any? },
	_BoundRegistry : { any? },
	_LockSessions : any,
	_LocalBroadcastListeners : { any? },

	_ExclusiveTimerCalled : boolean,
	_ShutdownCalled : boolean,
	_ExclusiveSafetyCalled : boolean,
	_IsSaveRunning : boolean,
	_IsObtainingRunning : boolean,
	_CacheCleaningCalled : boolean,
	
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
	DefaultDataLoadingAttempts : number, --  Strictly gives some attempts to data loading when tries to load the data
	DefaultDataLoadingYieldDuration : number, -- Yield duration between each attempt of load the data
	DefaultDataSavingAttempts : number, -- Strictly gives some attempts to save the data when tries to saving data
	DefaultDataSavingYieldDuration : number, -- Yield duration between each attempt of saving data
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
	Ready: (UDCRecord: UDCRecord, TimeoutFindPlayer: number?) -> boolean, -- (Suspending) IMPORANT POINT, this must be called before the data can be used, where UDC is evaluating everything fromn the data and ownership, before the data can be used
	-- @return boolean -- Status when the data of this player is ready after evaluating and hard-checking, if true the data is ready to be used
	Standby: (UDCRecord: UDCRecord) -> boolean, -- (Suspending) IMPORTANT POINT, this will be called automatically when player is leaving the experience, or server shutdown, where the data will be saved and released, must be called after the record is ready, which after "Ready()" returns true. 
												-- This will use WAL to save data, to prevent request "Boom", and will easily and automatically recovered by UDC from Awake()
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

local function dispatch(record, eventName, ...)
	local args = table.pack(...)
	
end

local function throw(record, message)
	
end

local function load_data(meta : __UDCInfo_Internal, record : UDCRecord)
	local entry
	local ok, result = pcall(function() return meta._CurrentWALDataStore:GetAsync(record.Key) end)
	if meta.WALEnabled and ok then
		entry = result
	end

	local thisOwnerId = record.Owner and record.Owner.UserId or 0
	local now = workspace:GetServerTimeNow()
	local attempts = 0

	local success, result = pcall(function()
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

			CurrentData = CurrentData or deepclone(meta.DataBlueprint)

			if entry and entry.__version and entry.__version > (CurrentData.__version or 0) then
				CurrentData = entry
			end

			CurrentData.__bounds = {
				id = CurrentData.__bounds and CurrentData.__bounds.id,
				serverid = ServerId,
				since = CurrentData.__bounds and CurrentData.__bounds.since,
				lastheartbeat = now,
			}
			return CurrentData
		end)
	end)

	if success and result and entry then
		meta._CurrentWALDataStore:RemoveAsync(record.Key)
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

				if backupData and backupData.__version and backupData.__version > (CurrentData.__version or 0) then
					CurrentData = backupData
				end

				CurrentData.__bounds = {
					id = CurrentData.__bounds and CurrentData.__bounds.id,
					serverid = ServerId,
					since = CurrentData.__bounds and CurrentData.__bounds.since,
					lastheartbeat = now,
				}
				return CurrentData
			end)
		end
	end
	
	return nil
end

local function run_load_queue(meta : __UDCInfo_Internal)
	if meta._IsObtainingRunning then return end
	meta._IsObtainingRunning = true
	
	RunService.Heartbeat:Connect(function(_)
		if meta.Enabled and UDataComponent.Enabled then
			local obtain = meta._ObtainPendingQueue

			local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
			local obtainBudget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync)
			local perTick = meta.MaxDataObtainingPerTick

			if budget >= perTick and obtainBudget >= 2 and #obtain > 0 and meta._CurrentLoadWorkers <= meta.MaxConcurrentLoadWorkers then -- If there is no budget, then don't run the queue
				local first = table.remove(obtain, 1)
				
				if first.Meta.Owner and Players:GetPlayerByUserId(first.Meta.Owner.UserId) == nil then
					task.spawn(first.Thread, false, nil)
					return
				end
				
				meta._CurrentLoadWorkers += 1
				task.spawn(function()
					local success, result = pcall(load_data, meta, first.Meta)
					
					if not success then -- Probably happened when the data is failed to be loaded, fallback to the backup
						success, result = pcall(fallback_backup, meta, first.Meta)
					end
					
					meta._CurrentLoadWorkers -= 1
					task.spawn(first.Thread, success, result)
				end)
			end
		end
	end)
end

local function enqueue_load(meta : __UDCInfo_Internal, record : UDCRecord)
	run_load_queue(meta)
	
	local currentThread = coroutine.running()
	table.insert(meta._ObtainPendingQueue, {
		Meta = record,
		Thread = currentThread,
	})
	
	return coroutine.yield()
end

local function current_record(meta : __UDCInfo_Internal, key : number | string, owner : Player?)
	local record = {}
	record.Key = key
	record.Owner = owner
	record.IsArchived = false
	record.Event = nil
	record.Validation = nil
	record.Swap = nil
	record.Messaging = nil
	record.Version = 0
	record.Data = nil
	
	local function get_blueprint()
		return deepclone(meta.DataBlueprint)
	end
	
	-- Should be called first, this is where the player's data record is awake and loaded
	-- In Awake, also checks if this server owns the data, it will check if current owner was this player
	function record:Awake()
		local success, result = enqueue_load(meta, record)
		
		if not success then -- Probably happened when the data is failed to be loaded, fallback to the backup
			
		elseif success and not result then -- Probably happened when the data is not owner of current player OR this record is not belong to this server
			
		elseif success and result then -- Data is successfully loaded, whether it's actual data or blueprint
			
		end
	end
	
	function record:Ready(TimeoutFindPlayer: number?)
		
	end
	
	function record:Standby()
		
	end
	
	function record:Save(Data: any?, SegmentIndex: number?)
		
	end
	
	function record:Write(WritingFunction: (CurrentData: any) -> ())
		
	end
	
	function record:ForceSave(Data: any?, SegmentIndex: number?)
		
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
	
	local self = setmetatable(InfosStorage, UDataComponent)
	
	self.Name = DataStoreName
	self.Scope = Scope
	
	self.Enabled = true
	self.ValidationEnabled = true
	self.CallbackEnabled = true
	self.DefaultDataLoadingAttempts = 5
	self.DefaultDataLoadingYieldDuration = 3
	self.WALEnabled = true
	self.DefaultDataSavingAttempts = 5
	self.DefaultDataSavingYieldDuration = 3
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

	self._CurrentDataStore = DataStoreService:GetDataStore(DataStoreName, Scope)
	self._CurrentWALDataStore = DataStoreService:GetDataStore(DataStoreName..self.WALDataSuffix, Scope)
	self._CurrentArchivedDataStore = DataStoreService:GetDataStore(DataStoreName..self.ArchivationSuffix, Scope)

	self._SaveTimestamp = {} -- { [Key: string] = timestamp: number }
	self._SwapTimestamp = {} -- { [Key: string] = timestamp: number }
	self._AutosaveTimestamp = {} -- { [Key: string] = timestamp: number }
	self._SavePendingQueue = {} -- { [Key: string] = {Key, Data, WAL, Backup } }
	self._ObtainPendingQueue = {} -- { [Key: string] = {Key, Data, WAL, Backup } }
	self._UnreadyData = {} -- { [Key: string] = true }
	self._DataCache = {} -- { [Key: string] = Data: any }
	self._BoundRegistry = {} -- { [Key: string] = table }
	self._LockSessions = ScopedMutex.new(Mutex)
	self._LocalBroadcastListeners = {} -- { [Key: string] = { [ListenerId: string] = Listener: function } }

	self._ExclusiveTimerCalled = false
	self._ShutdownCalled = false
	self._ExclusiveSafetyCalled = false
	self._IsSaveRunning = false
	self._IsObtainingRunning = false
	self._CacheCleaningCalled = false
	
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
