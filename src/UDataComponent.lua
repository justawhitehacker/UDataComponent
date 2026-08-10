local UDataComponent = {}
UDataComponent.__index = UDataComponent

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

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
	Save: (self: UDataComponentRecord, Data: any, SegmentIndex: number?) -> (),
	Write: (self: UDataComponentRecord, WritingFunction: (CurrentData: any) -> any) -> (),
	Flush: (self: UDataComponentRecord) -> (),
	Recover: (self: UDataComponentRecord) -> boolean,
	Detach : (self: UDataComponentRecord) -> (),
	ForceSave: (self: UDataComponentRecord, Data: any, SegmentIndex: number?) -> (),
	ForceWrite: (self: UDataComponentRecord, WritingFunction: (CurrentData: any) -> any) -> (),
	SafeGet: (self: UDataComponentRecord, LoadRecovery: boolean?, ExclusivePlayer: Player?, LoadAttempts: number?, YieldTime: number?) -> any,
	SafeSave: (self: UDataComponentRecord, Data: any, SegmentIndex: number?) -> (),
	SafeWrite: (self: UDataComponentRecord, WritingFunction: (CurrentData: any) -> any) -> (),
	AcquireLockSession: (self: UDataComponentRecord, OwnerIdentity: string?, Timeout: number?) -> (boolean, number), 
	ReleaseLockSession: (self: UDataComponentRecord, OwnerIdentity: string) -> (),
	IsSessionLocked: (self: UDataComponentRecord, OwnerIdentity: string) -> boolean,
	BindExclusiveAccess: (self: UDataComponentRecord, ExclusivePlayer: Player) -> boolean,
	UnbindExclusiveAccess: (self: UDataComponentRecord) -> boolean,
	IsExclusiveAccessBound: (self: UDataComponentRecord) -> boolean,
	IsPlayerInExclusiveAccess: (self: UDataComponentRecord, PlayerThatAssumedExclusive: Player) -> boolean,
	CreateValidation: (self: UDataComponentRecord, ValidationFunction: (ValidationDummy: UDataComponentValidationDummy) -> any) -> (),
	SmartCleanCache: (self: UDataComponentRecord, Interval: number?) -> (),
	GetVersion: (self: UDataComponentRecord) -> number
}

export type UDataComponentCallbackConnection = {
	Disconnect: (self: UDataComponentCallbackConnection) -> (),
	DisconnectAfterCalled: (self: UDataComponentCallbackConnection) -> ()
}

export type UDataComponentCallbackFunctions = {
	OnDataLoading: (Key: string) -> UDataComponentCallbackConnection,
	OnDataLoaded: (Key: string, CurrentData: any) -> UDataComponentCallbackConnection,
	OnDataSaving: (Key: string) -> UDataComponentCallbackConnection,
	OnDataSaved: (Key: string, CurrentData: any) -> UDataComponentCallbackConnection,
	OnDataArchived: (Key: string, ArchivedData: any) -> UDataComponentCallbackConnection,
	OnDataRecovery: (Key: string) -> UDataComponentCallbackConnection,
	OnDataCached: (Key: string, CurrentData: any) -> UDataComponentCallbackConnection,
	OnDataRemoved: (Key: string, RemovedData: any) -> UDataComponentCallbackConnection,
	OnDataBinding: (Key: string, Data: any) -> UDataComponentCallbackConnection,
	OnDataUnbinding: (Key: string, Data: any) -> UDataComponentCallbackConnection,
	OnReleased: (Key: string) -> UDataComponentCallbackConnection,
	OnDataError: (Key: string, Reason: string) -> UDataComponentCallbackConnection
}

export type UDataComponentInfo = {
	GetPlayerData: (self: UDataComponentInfo, Key: string | number, Callbacks: {UDataComponentCallbackFunctions?}) -> UDataComponentRecord,
	GetDataStoreName: (self: UDataComponentInfo) -> string | number,

	Enabled : boolean,
	RequestTimestampLimit : number,
	WALEnabled : boolean,
	WritingDataAgeEnabled : boolean,
	DefaultSaveAttempts : number,
	DefaultYieldAttempts : number,
	MaxKeyLength : number,
	BackupEnabled : boolean,
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
	CacheFlushingInterval : number,
	CanDataExpired : boolean,
	DataExpiredDuration : number,
	DataBlueprint : {any?},
	ErrorReasonNamespace : string,
	MessagingEnabled : boolean,
	MessagingNamespace : string,
	MessagingDebugEnabled : boolean,
	DefaultCacheCleanupInterval : number,
}

export type UDataComponent = {
	InDataInfo: (DataStoreName: string, Scope: string?) -> UDataComponentInfo,
}

local function InPlayerData(meta, Key)
	assert(typeof(meta) == "table", "InPlayerData must be called from a UDataComponentInfo object")
	assert(typeof(Key) == "string" or typeof(Key) == "number", "Key must be a string or id")

	local record = {}
	record.key = Key

	local function dispatch(key, eventName, ...)
		if not meta.CallbackEnabled then return end
		
		local args = table.pack(...)

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
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed because the data wasn't bound with this player.")
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
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Backup is disabled.")
			return false, get_blueprint()
		end

		local _attempts = 0
		repeat
			local suc, err = pcall(function()
				obtainedData = backup:GetAsync(Key)
			end)

			if not suc then
				warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent's Get error happened, reason: " .. tostring(err))
				dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to obtain data from backup, trying to get data again...")
			end

			_attempts += 1
			task.wait(meta.BackupYieldDuration or 3)
		until _attempts >= meta.DefaultDataLoadingAttempts or obtainedData ~= nil

		if obtainedData == nil then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot check the record of the data from this key from backup")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to obtain data from backup, switching data to template/blueprint")

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

	local function call_autosave(key, data : DataStore, wal : DataStore, backup : DataStore)
		local calledSince = workspace:GetServerTimeNow()

		while meta.Enabled and meta._DataCache[key] and meta._AutosaveTimestamp[key] and not meta._AutosaveDied do
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
		ownerId = tostring(ownerId)

		if not meta._LockTimers[ownerId] then
			meta._LockTimers[ownerId] = coroutine.create(function()
				local now = workspace:GetServerTimeNow()

				while meta.Enabled and meta._LockTimers[ownerId] do
					if now - meta._LockTimers[ownerId] >= timeout then
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

	local function run_save_queue()
		if meta._IsRunning then return end
		meta._IsRunning = true

		task.spawn(function()
			while meta.Enabled do
				local count = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
				local processed = 0
				local max = meta.MaxDataSavingPerTick

				while #meta._SavePendingQueue > 0 and processed < max and count > 0 do
					local obj = table.remove(meta._SavePendingQueue, 1) -- First in first out

					local currentData = meta._DataCache[obj.Key]
					if currentData then
						local function commit()
							local latestData = meta._DataCache[obj.Key]
							if not latestData then return end
							
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

		local trackedValidations = meta._TrackedValidations and meta._TrackedValidations[record.key]
		if not trackedValidations then return true end

		local predicate = trackedValidations[thisData]
		if not predicate then
			return true
		end

		return predicate(thisValue)
	end

	local function is_schema_valid(thisData, thisValue)
		if not meta.ValidationEnabled then return true end

		local trackedSchemas = meta._TrackedSchemas and meta._TrackedSchemas[record.key]
		if not trackedSchemas then return true end

		local schema = trackedSchemas[thisData]
		if not schema then return true end

		return typeof(thisValue) == schema
	end

	local function clamp_value(thisData, thisValue)
		if not meta.ValidationEnabled then return thisValue end

		local trackedClamps = meta._TrackedClamps and meta._TrackedClamps[record.key]
		if not trackedClamps then return thisValue end

		local clampMin = trackedClamps[thisData] and trackedClamps[thisData].Min
		local clampMax = trackedClamps[thisData] and trackedClamps[thisData].Max
		
		if typeof(thisValue) ~= "number" then return thisValue end
		
		local result = nil
		if clampMin ~= nil then result = math.max(thisValue, clampMin) end
		if clampMax ~= nil then result = math.min(thisValue, clampMax) end

		return result
	end
	
	local function min_value(thisData, thisValue)
		if not meta.ValidationEnabled then return thisValue end
		
		local trackedMin = meta._TrackedMin and meta._TrackedMin[record.key] and meta._TrackedMin[record.key][thisData]
		if not trackedMin then return thisValue end
		
		if typeof(thisValue) ~= "number" then return thisValue end
		
		return math.min(thisValue, trackedMin)
	end
	
	local function max_value(thisData, thisValue)
		if not meta.ValidationEnabled then return thisValue end
		
		local trackedMax = meta._TrackedMax and meta._TrackedMax[record.key] and meta._TrackedMax[record.key][thisData]
		if not trackedMax then return thisValue end
		
		if typeof(thisValue) ~= "number" then return thisValue end
		
		return math.max(thisValue, trackedMax)
	end

	local function check_validation(key, thisData, thisValue)
		if not is_schema_valid(thisData, thisValue) then
			return false
		end
		
		local value = clamp_value(thisData, thisValue)
		
		if not is_data_valid(thisData, value) then
			return false
		end
		
		meta._DataCache[key][thisData] = value
		return true
	end

	local function create_exclusive_safety(key)
		Players.PlayerRemoving:Connect(function(player)
			if meta._AutosaveDied then return end

			for key, bound in pairs(meta._BoundRegistry) do
				if bound.UserId == player.UserId then
					call_flush(key, meta._CurrentDataStore, meta._CurrentWALDataStore, meta._CurrentBackupDataStore)
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
			meta._AutosaveDied = true

			local pendingTask = 0
			for key, bound in pairs(meta._BoundRegistry) do
				pendingTask += 1
				task.spawn(bound.Coroutine, pendingTask)
			end

			local remainingTime = 0
			while pendingTask > 0 and remainingTime < 25 do
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
	
	local function run_exclusive_timer(data, wal, backup)
		if meta._ExclusiveTimerCalled then return end
		meta._ExclusiveTimerCalled = true

		task.spawn(function()
			while meta.Enabled and meta.ExclusiveAccessEnabled do
				local now = workspace:GetServerTimeNow()

				for key, bound in pairs(meta._BoundRegistry) do
					local since = bound.Since

					local dayInSec = 24 * 60 * 60
					local timeout = dayInSec * meta.ExclusiveAccessExpiration

					if now - since > timeout then
						meta._DataCache[key].__bounds = nil
						call_flush(key, data, wal, backup)

						unbind_exclusive_access(key)
					end
				end

				task.wait(1)
			end
		end)
	end

	local function bind_exclusive_access(key, timeSinceBound, player : Player)
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
			Coroutine = function(pendingTask)
				call_flush(key, meta._CurrentDataStore, meta._CurrentWALDataStore, meta._CurrentBackupDataStore)
				pendingTask -= 1
			end
		}

		if not meta._ExclusiveSafetyCalled then
			meta._ExclusiveSafetyCalled = true
			create_exclusive_safety(key)
		end

		dispatch(key, "OnDataBinding", meta._DataCache[key])
		run_exclusive_timer(meta._CurrentDataStore, meta._CurrentWALDataStore, meta._CurrentBackupDataStore)
	end

	function record:Get(LoadRecovery : boolean?, ExclusivePlayer: Player?)
		dispatch(record.key, "OnDataLoading")

		local currentData = meta._CurrentDataStore
		local currentBackupData = meta._CurrentBackupDataStore
		local currentWALData = meta._CurrentWALDataStore

		local _attempts = 0
		local obtainedData = nil

		if meta._DataCache[record.key] then
			obtainedData = meta._DataCache[record.key]

			if ExclusivePlayer and obtainedData then
				if ensure_exc_player(record.key, ExclusivePlayer) then
					return true, obtainedData
				else
					dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Get() returns blueprint/template of data, because the data is bound to another player.")
					return false, get_blueprint()
				end
			end

			local clone = deepclone(obtainedData)
			dispatch(record.key, "OnDataLoaded", clone)
			return true, obtainedData
		end

		local now = workspace:GetServerTimeNow()
		if meta._GetTimestamp[record.key] and now - meta._GetTimestamp[record.key] < meta.RequestTimestampCooldown then 
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Get() halted, waiting for cooldown.")
			return false, nil 
		end
		meta._GetTimestamp[record.key] = now

		if LoadRecovery then
			local recoverStatus, message = record:TryToRecover()

			if recoverStatus then
				dispatch(record.key, "OnDataRecovery")
			end
		end

		repeat
			local suc, err = pcall(function()
				obtainedData = currentData:GetAsync(Key)
			end)

			if not suc then
				warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent's Get error happened, reason: " .. tostring(err))
				dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: happened in Get's function, caused by failed to obtain data, trying to get data again...")		
			end

			_attempts += 1
			task.wait(meta.DefaultDataLoadingYieldDuration or 3)
		until _attempts >= meta.DefaultDataLoadingAttempts or obtainedData ~= nil

		if obtainedData == nil then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot obtain the record of the data from this key, trying to get data from backup")
			dispatch(record.key, "OnDataError", "Error happened while trying to obtain data, trying to obtain data from backup...")

			local status, backupData = call_backup(currentBackupData)
			local dataResult = if status then backupData else get_blueprint()
			
			if not meta._DataCache[record.key] then
				meta._DataCache[record.key] = dataResult
			end

			if dataResult.__bounds then
				local id = dataResult.__bounds.id
				local since = dataResult.__bounds.since

				local dayInSec = 60 * 60 * 24
				local days = meta.ExclusiveAccessExpiration or 1

				local timeout = dayInSec * days

				if workspace:GetServerTimeNow() - since < timeout then
					local plr = Players:GetPlayerByUserId(id)
					bind_exclusive_access(record.key, since, plr)
				end
			end
			
			if ExclusivePlayer and dataResult then
				if not meta._DataCache[record.key] then
					meta._DataCache[record.key] = dataResult
				end

				if ensure_exc_player(record.key, ExclusivePlayer) then
					status = true
				else
					dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Get() returns blueprint/template of data, because the data is bound to another player.")
					status, dataResult = false, get_blueprint()
				end
			end
			local _, _, _ = write_data(currentData, record.key, dataResult) -- this will rewrite the main datastore when backup un/obtained the data

			return status, backupData
		end
		
		if obtainedData.__bounds then
			local id = obtainedData.__bounds.id
			local since = obtainedData.__bounds.since

			local dayInSec = 60 * 60 * 24
			local days = meta.ExclusiveAccessExpiration or 1

			local timeout = dayInSec * days

			if workspace:GetServerTimeNow() - since < timeout then
				local plr = Players:GetPlayerByUserId(id)
				bind_exclusive_access(record.key, since, plr)
			end
		end

		if ExclusivePlayer and obtainedData then
			if not meta._DataCache[record.key] then
				meta._DataCache[record.key] = obtainedData
			end

			local status, data
			if ensure_exc_player(record.key, ExclusivePlayer) then
				return true, obtainedData
			else
				dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Get() returns blueprint/template of data, because the data is bound to another player.")
				return false, get_blueprint()
			end
		end

		local clone = deepclone(obtainedData)
		dispatch(record.key, "OnDataLoaded", clone)

		if not meta._DataCache[record.key] then
			meta._DataCache[record.key] = obtainedData
		end		

		if not meta._AutosaveTimestamp[record.key] then
			meta._AutosaveTimestamp[record.key] = coroutine.create(call_autosave)

			coroutine.resume(meta._AutosaveTimestamp[record.key], record.key, currentData, currentWALData, currentBackupData)
		end

		return true, obtainedData
	end

	function record:Save(Data: any, SegmentIndex: number?)
		local now = workspace:GetServerTimeNow()
		if meta._SaveTimestamp[record.key] and now - meta._SaveTimestamp[record.key] < meta.RequestTimestampCooldown then 
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Save() halted, waiting for cooldown.")
			return false 
		end
		meta._SaveTimestamp[record.key] = now

		dispatch(record.key, "OnDataSaving")

		if not meta._DataCache[record.key] then
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save data, because data is not loaded yet.")
			return false
		end

		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		local rejected = {}

		if SegmentIndex then
			local success = check_validation(record.key, SegmentIndex, Data)
			if not success then
				table.insert(rejected, SegmentIndex)
			end
		else
			for thisData, thisValue in pairs(Data) do
				local success = check_validation(record.key, thisData, thisValue)
				if not success then
					table.insert(rejected, thisData)
				end
			end
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end

		enqueue_save(record.key, data, wal, backup, false)

		return true
	end

	function record:Write(WritingFunction: (CurrentData: any) -> any)
		local now = workspace:GetServerTimeNow()
		if meta._SaveTimestamp[record.key] and now - meta._SaveTimestamp[record.key] < meta.RequestTimestampCooldown then return false end
		meta._SaveTimestamp[record.key] = now

		dispatch(record.key, "OnDataSaving")

		if not meta._DataCache[record.key] then
			return false
		end

		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		local before = meta._DataCache[record.key]
		local clone = deepclone(before)
		local resultFunction = WritingFunction(clone)

		if type(resultFunction) ~= "table" then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent's Write function must returns the/a table of param.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Write function isn't returning the table of param.")

			return false
		end

		local rejected = {}
		for thisData in pairs(before) do
			if resultFunction[thisData] == nil then
				meta._DataCache[record.key][thisData] = nil
			end
		end

		for thisData, thisValue in pairs(resultFunction) do
			local success = check_validation(record.key, thisData, thisValue)

			if not success then
				table.insert(rejected, thisData)
			end
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end

		enqueue_save(record.key, data, wal, backup, false)

		return true
	end

	function record:Flush()
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		local wal = meta._CurrentWALDataStore

		return call_flush(record.key, data, wal, backup)
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
				recoveredData = wal:GetAsync(record.key)
			end)

			if not status then
				warn("[" .. meta.ErrorReasonNamespace .. "]: Unexpected error happened when trying to recover data from WAL, with reason: " .. tostring(err))
				dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unexpected error happened, when trying to recover data that was dead from WAL.")
			end

			_walAttempts += 1
			task.wait(meta.DefaultDataLoadingYieldDuration or 3)
		until _walAttempts >= meta.DefaultDataLoadingAttempts or recoveredData ~= nil

		if not recoveredData then
			warn("[" .. meta.ErrorReasonNamespace .. "]: There is no WAL history to recover the data.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: There is no WAL history to recover the data, meaning the data has been successfully written or no record tracked.")

			return false, "failed_recover"
		end

		local status, _, message = write_wal_optionally(wal, data, backup, record.key, recoveredData)

		if not status then
			warn("[" .. meta.ErrorReasonNamespace .. "]: Failed to recover data from WAL, with reason: " .. tostring(message))
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed to recover data from WAL.")

			return false, "failed_recover"
		end

		return true, "success"
	end

	function record:Detach()
		if meta.StrictlyUnallowDetaching then
			return false, "unallowed_detach"
		end

		local currentData = meta._DataCache[record.key]
		if not currentData then
			return false, "not_cached"
		end
		local clone = deepclone(currentData)

		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		if meta.ArchivationEnabled then
			local archive = meta._CurrentArchivedDataStore
			pcall(function()
				archive:UpdateAsync(record.key .. "_" .. workspace:GetServerTimeNow(), function()
					return currentData
				end)
			end)

			dispatch(record.key, "OnDataArchived", clone)
		end

		pcall(function()
			data:RemoveAsync(record.key)
		end)

		if meta.BackupRemovedWhenDetached then
			pcall(function()
				backup:RemoveAsync(record.key)
			end)
		end

		meta._BoundRegistry[record.key] = nil
		meta._SaveTimestamp[record.key] = nil
		meta._GetTimestamp[record.key] = nil
		meta._DataCache[record.key] = nil
		meta._AutosaveTimestamp[record.key] = nil
		meta._TrackedClamps[record.key] = nil
		meta._TrackedSchemas[record.key] = nil
		meta._TrackedValidations[record.key] = nil

		for i, pending in ipairs(meta._SavePendingQueue) do
			if pending.Key == record.key then
				table.remove(meta._SavePendingQueue, i)
				break
			end
		end

		dispatch(record.key, "OnDataRemoved", clone)
		return true, "success"
	end

	function record:ForceSave(Data: any, AlongCooldown : boolean?, SegmentIndex: number?)
		local now = workspace:GetServerTimeNow()
		if AlongCooldown and meta._SaveTimestamp[record.key] and now - meta._SaveTimestamp[record.key] < meta.RequestTimestampCooldown then return false end
		meta._SaveTimestamp[record.key] = now

		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		local wal = meta._CurrentWALDataStore

		dispatch(record.key, "OnDataSaving")		

		if not meta._DataCache[record.key] then
			return false
		end

		local rejected = {}

		if SegmentIndex then
			local success = check_validation(record.key, SegmentIndex, Data)

			if not success then
				table.insert(rejected, SegmentIndex)
			end
		else
			for thisData, thisValue in pairs(Data) do
				local success = check_validation(record.key, thisData, thisValue)

				if not success then
					table.insert(rejected, thisData)
				end
			end
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end

		local clone = deepclone(meta._DataCache[record.key])
		local status, _, message = write_wal_optionally(wal, data, backup, record.key, meta._DataCache[record.key])

		if not status then
			if message == "wal_disabled" then
				write_data(data, record.key, meta._DataCache[record.key])
				write_backup(backup, record.key, meta._DataCache[record.key])

				return true
			end

			warn("[" .. meta.ErrorReasonNamespace .. "]: Failed to save data, with reason: " .. tostring(message))
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed to save data.")

			return false
		end

		dispatch(record.key, "OnDataSaved", clone)
		return true
	end

	function record:ForceWrite(Data: any, WritingFunction: (CurrentData: any) -> any, AlongCooldown : boolean?)
		local now = workspace:GetServerTimeNow()
		if AlongCooldown and meta._SaveTimestamp[record.key] and now - meta._SaveTimestamp[record.key] < meta.RequestTimestampCooldown then return false end
		meta._SaveTimestamp[record.key] = now

		dispatch(record.key, "OnDataSaving")

		if not meta._DataCache[record.key] then
			return false
		end

		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		local before = meta._DataCache[record.key]
		local clone = deepclone(before)
		local resultFunction = WritingFunction(clone)

		if type(resultFunction) ~= "table" then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent's Write function must returns the/a table of param.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Write function isn't returning the table of param.")

			return false
		end

		local rejected = {}
		for thisData in pairs(before) do
			if resultFunction[thisData] == nil then
				meta._DataCache[record.key][thisData] = nil
			end
		end

		for thisData, thisValue in pairs(resultFunction) do
			local success = check_validation(record.key, thisData, thisValue)

			if not success then
				table.insert(rejected, thisData)
			end
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end

		local filteredData = meta._DataCache[record.key]
		local status, _, message = write_wal_optionally(wal, data, backup, record.key, filteredData)

		if not status then
			if message == "wal_disabled" then
				write_data(data, record.key, filteredData)
				write_backup(backup, record.key, filteredData)

				dispatch(record.key, "OnDataSaved", clone)

				return true
			end

			warn("[" .. meta.ErrorReasonNamespace .. "]: Failed to save data, with reason: " .. tostring(message))
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed to save data.")

			return false
		end

		dispatch(record.key, "OnDataSaved", clone)
		return true
	end

	function record:SafeGet(LoadRecovery: boolean?, ExclusivePlayer: Player?, LoadAttempts: number?, YieldTime: number?)
		dispatch(record.key, "OnDataLoading")

		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		local wal = meta._CurrentWALDataStore

		local attempts = LoadAttempts or meta.DefaultDataLoadingAttempts or 5
		local yieldTime = YieldTime or meta.DefaultDataLoadingYieldDuration or 3

		local status = false
		local obtainedData = nil

		if meta._DataCache[record.key] then
			obtainedData = meta._DataCache[record.key]
			local clone = deepclone(meta._DataCache[record.key])

			if ExclusivePlayer then
				if ensure_exc_player(record.key, ExclusivePlayer) then
					status = true
				else
					status, obtainedData = false, get_blueprint()
				end
			else
				status = true
			end

			dispatch(record.key, "OnDataLoaded", clone)
			return status, obtainedData
		end

		local now = workspace:GetServerTimeNow()
		if meta._GetTimestamp[record.key] and now - meta._GetTimestamp[record.key] < meta.RequestTimestampCooldown then return false, nil end
		meta._GetTimestamp[record.key] = now

		meta._LockSessions:Do(record.key, function()
			local _attempts = 0

			if LoadRecovery then
				local recoverStatus, message = record:TryToRecover()

				if recoverStatus then
					dispatch(record.key, "OnDataRecovery")
				end
			end

			repeat
				local success, result = pcall(function()
					obtainedData = data:GetAsync(record.key)
				end)

				if not success then
					warn("[" .. meta.ErrorReasonNamespace .. "]: Failed to load data, with reason: " .. tostring(result))
					dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed to load data.")
				end

				_attempts += 1
				task.wait(yieldTime)
			until _attempts >= attempts or obtainedData ~= nil

			if obtainedData == nil then
				warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot obtain the record of the data from this key, trying to get data from backup")
				dispatch(record.key, "OnDataError", "Error happened while trying to obtain data, trying to obtain data from backup...")

				local preStatus, backupData = call_backup(backup)
				local dataResult = if preStatus then backupData else get_blueprint()
				
				if not meta._DataCache[record.key] then
					meta._DataCache[record.key] = dataResult
				end

				if dataResult.__bounds then
					local id = dataResult.__bounds.id
					local since = dataResult.__bounds.since

					local dayInSec = 60 * 60 * 24
					local days = meta.ExclusiveAccessExpiration or 1

					local timeout = dayInSec * days

					if workspace:GetServerTimeNow() - since < timeout then
						local plr = Players:GetPlayerByUserId(id)
						bind_exclusive_access(record.key, since, plr)
					end
				end
				local _, _, _ = write_data(data, record.key, dataResult) -- this will rewrite the main datastore when backup un/obtained the data

				status, obtainedData = preStatus, backupData
			else
				status = true
			end

			if ExclusivePlayer and obtainedData then
				if ensure_exc_player(record.key, ExclusivePlayer) then
					status = true
				else
					status, obtainedData = false, get_blueprint()
				end
			end
		end)

		if not meta._DataCache[record.key] then
			meta._DataCache[record.key] = obtainedData
		end		
		
		if obtainedData.__bounds then
			local id = obtainedData.__bounds.id
			local since = obtainedData.__bounds.since

			local dayInSec = 60 * 60 * 24
			local days = meta.ExclusiveAccessExpiration or 1

			local timeout = dayInSec * days

			if workspace:GetServerTimeNow() - since < timeout then
				local plr = Players:GetPlayerByUserId(id)
				bind_exclusive_access(record.key, since, plr)
			end
		end


		if not meta._AutosaveTimestamp[record.key] then
			meta._AutosaveTimestamp[record.key] = coroutine.create(call_autosave)

			coroutine.resume(meta._AutosaveTimestamp[record.key], record.key, data, wal, backup)
		end

		local clone = deepclone(obtainedData)
		dispatch(record.key, "OnDataLoaded", clone)

		return status, obtainedData
	end

	function record:SafeSave(Data: any, SegmentIndex: number?)
		local now = workspace:GetServerTimeNow()
		if meta._SaveTimestamp[record.key] and now - meta._SaveTimestamp[record.key] < meta.RequestTimestampCooldown then return false end
		meta._SaveTimestamp[record.key] = now

		dispatch(record.key, "OnDataSaving")

		if not meta._DataCache[record.key] then
			return false
		end

		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		local rejected = {}

		if SegmentIndex then
			local success = check_validation(record.key, SegmentIndex, Data)

			if not success then
				table.insert(rejected, Data)
			end
		else
			for thisData, thisValue in pairs(Data) do
				local success = check_validation(record.key, thisData, thisValue)

				if not success then
					table.insert(rejected, thisData)
				end
			end
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end

		enqueue_save(record.key, data, wal, backup, true)

		return true
	end

	function record:SafeWrite(WritingFunction: (CurrentData: any) -> any)
		local now = workspace:GetServerTimeNow()
		if meta._SaveTimestamp[record.key] and now - meta._SaveTimestamp[record.key] < meta.RequestTimestampCooldown then return false end
		meta._SaveTimestamp[record.key] = now

		dispatch(record.key, "OnDataSaving")

		if not meta._DataCache[record.key] then
			return false
		end

		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		local before = meta._DataCache[record.key]
		local clone = deepclone(before)
		local resultFunction = WritingFunction(clone)

		if type(resultFunction) ~= "table" then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent's Write function must returns the/a table of param.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Write function isn't returning the table of param.")

			return false
		end

		local rejected = {}
		for thisData in pairs(before) do
			if resultFunction[thisData] == nil then
				meta._DataCache[record.key][thisData] = nil
			end
		end

		for thisData, thisValue in pairs(resultFunction) do
			local success = check_validation(record.key, thisData, thisValue)

			if not success then
				table.insert(rejected, thisData)
			end
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " UDataComponent cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end

		enqueue_save(record.key, data, wal, backup, true)

		return true
	end

	function record:AcquireLockSession(OwnerIdentity: string?, Timeout: number?)
		local now = workspace:GetServerTimeNow()
		OwnerIdentity = OwnerIdentity or HttpService:GenerateGUID(false) .. "-" .. tostring(now)
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
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end
		
		if not meta._DataCache or not meta._DataCache[record.key] then
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Unable to get data, it seems you called the binding before the data is loaded. Make sure the BindExclusivePlayer called after data loading of player.")
			return false
		end

		local id = ExclusivePlayer.UserId
		local data = deepclone(meta._DataCache[record.key])
		local now = workspace:GetServerTimeNow()

		if data.__bounds == nil then
			record:SafeWrite(function(CurrentData)
				CurrentData.__bounds = {}

				CurrentData.__bounds.id = id
				CurrentData.__bounds.since = now

				return CurrentData
			end)

			if meta._BoundRegistry[record.key] == nil then
				bind_exclusive_access(record.key, now, ExclusivePlayer)
			end			

			return true
		end

		dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Data is already bound to " .. data.__bounds.id .. "")
		return false
	end

	function record:UnbindExclusiveAccess()
		if not meta.ExclusiveAccessEnabled then
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end

		local data = deepclone(meta._DataCache[record.key])

		if data.__bounds == nil or meta._BoundRegistry[record.key] == nil then 
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Data is not bound to any player.")
			return false
		end

		record:SafeWrite(function(CurrentData)
			CurrentData.__bounds = nil

			return CurrentData
		end)		

		unbind_exclusive_access(record.key)

		return true
	end

	function record:IsExclusiveAccessBound()
		if not meta.ExclusiveAccessEnabled then
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end

		local data = deepclone(meta._DataCache[record.key])

		return data.__bounds ~= nil and meta._BoundRegistry[record.key] ~= nil
	end

	function record:IsPlayerInExclusiveAccess(PlayerThatAssumedExclusive: Player)
		if not meta.ExclusiveAccessEnabled then
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end

		local data = deepclone(meta._DataCache[record.key])
		local id = PlayerThatAssumedExclusive.UserId

		return data.__bounds ~= nil and data.__bounds.id == id and meta._BoundRegistry[record.key] ~= nil and meta._BoundRegistry[record.key].UserId == id
	end

	function record:CreateValidation(ValidationFunction: (PredicateDummy: UDataComponentValidationDummy) -> any)
		local dummyMethods = {}
		local trackedValidations = meta._TrackedValidations[record.key] or {}
		local trackedSchemas = meta._TrackedSchemas[record.key] or {}
		local trackedClamps = meta._TrackedClamps[record.key] or {}

		meta._TrackedValidations[record.key] = trackedValidations
		meta._TrackedSchemas[record.key] = trackedSchemas
		meta._TrackedClamps[record.key] = trackedClamps

		local currentData = deepclone(meta._DataCache[record.key])

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
	
	function record:GetArchivedData()
		
	end
	
	function record:OnConnect() : UDataComponentCallbackFunctions
		local callbackMethods = {}
		local components = meta._UDataComponentCallbacks
		
		local connectorMethods = {}
		
		-- Connector Methods
		function connectorMethods:Disconnect()
			
		end
		
		function connectorMethods:DisconnectAfterCalled()
			
		end
		
		-- Callback Methods

		function callbackMethods:OnDataLoading(Callback: (Key: string) -> ()) : UDataComponentCallbackConnection
			local loading = components:Get("OnDataLoading") or {}
			loading[record.key] = Callback
			
			return connectorMethods :: UDataComponentCallbackConnection
		end
		
		function callbackMethods:OnDataLoaded(Callback: (Key: string, CloneData: any) -> ()) : UDataComponentCallbackConnection
			local loaded = components:Get("OnDataLoaded") or {}
			loaded[record.key] = Callback
			
			return connectorMethods :: UDataComponentCallbackConnection
		end
	
		function callbackMethods:OnDataSaving(Callback: (Key: string) -> ()) : UDataComponentCallbackConnection
			local saving = components:Get("OnDataSaving") or {}
			saving[record.key] = Callback
			
			return connectorMethods :: UDataComponentCallbackConnection
		end
		
		function callbackMethods:OnDataSaved(Callback: (Key: string, CloneData: any) -> ()) : UDataComponentCallbackConnection
			local saved = components:Get("OnDataSaved") or {}
			saved[record.key] = Callback
			
			return connectorMethods :: UDataComponentCallbackConnection
		end
		
		function callbackMethods:OnDataArchived(Callback: (Key: string, ArchivedData: any) -> ()) : UDataComponentCallbackConnection
			local archived = components:Get("OnDataArchived") or {}
			archived[record.key] = Callback
			
			return connectorMethods :: UDataComponentCallbackConnection
		end
		
		function callbackMethods:OnDataRecovery(Callback: (Key: string) -> ()) : UDataComponentCallbackConnection
			local recovery = components:Get("OnDataRecovery") or {}
			recovery[record.key] = Callback
			
			return connectorMethods :: UDataComponentCallbackConnection
		end
		
		function callbackMethods:OnDataCached(Callback: (Key: string, CloneData: any) -> ()) : UDataComponentCallbackConnection
			local cached = components:Get("OnDataCached") or {}
			cached[record.key] = Callback
			
			return connectorMethods :: UDataComponentCallbackConnection
		end
		
		function callbackMethods:OnDataRemoved(Callback: (Key: string, RemovedData: any) -> ()) : UDataComponentCallbackConnection
			local removed = components:Get("OnDataRemoved") or {}
			removed[record.key] = Callback
			
			return connectorMethods :: UDataComponentCallbackConnection
		end
		
		function callbackMethods:OnDataBinding(Callback: (Key: string, Data: any) -> ()) : UDataComponentCallbackConnection
			local binding = components:Get("OnDataBinding") or {}
			binding[record.key] = Callback
			
			return connectorMethods :: UDataComponentCallbackConnection
		end
		
		function callbackMethods:OnDataUnbinding(Callback: (Key: string, Data: any) -> ()) : UDataComponentCallbackConnection
			local unbinding = components:Get("OnDataUnbinding") or {}
			unbinding[record.key] = Callback
			
			return connectorMethods :: UDataComponentCallbackConnection
		end
		
		function callbackMethods:OnReleased(Callback: (Key: string) -> ()) : UDataComponentCallbackConnection
			local released = components:Get("OnReleased") or {}
			released[record.key] = Callback
			
			return connectorMethods :: UDataComponentCallbackConnection
		end
		
		function callbackMethods:OnDataError(Callback: (Key: string, Reason: string) -> ()) : UDataComponentCallbackConnection
			local error = components:Get("OnDataError") or {}
			error[record.key] = Callback
			
			return connectorMethods :: UDataComponentCallbackConnection
		end
		
		return callbackMethods
	end

	function record:SmartCleanCache(Interval: number?)

	end

	function record:GetVersion()

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
	self.DefaultSavingDataCountdown = 30
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
	self.CacheFlushingInterval = 5
	self.CanDataExpired = false
	self.DataExpiredDuration = 300
	self.DataBlueprint = {}
	self.ErrorReasonNamespace = "UDataComponent"
	self.MessagingEnabled = false
	self.MessagingNamespace = "UDataComponentReplication"
	self.ArchivationEnabled = true
	self.ArchivationSuffix = "_archive"
	self.MessagingDebugEnabled = false
	self.DefaultCacheCleanupInterval = 300 -- 300 seconds
	self.MaxDataSavingPerTick = 4

	self._CurrentDataStore = DataStoreService:GetDataStore(DataStoreName, _scope)
	self._CurrentWALDataStore = DataStoreService:GetDataStore(DataStoreName..self.WALDataSuffix, _scope)
	self._CurrentBackupDataStore = DataStoreService:GetDataStore(DataStoreName..self.BackupDataSuffix, _scope)
	self._CurrentArchivedDataStore = DataStoreService:GetDataStore(DataStoreName..self.ArchivationSuffix, _scope)
	self._DataStoreName = DataStoreName
	
	self._GetTimestamp = {} -- { [Key: string] = timestamp: number }
	self._SaveTimestamp = {} -- { [Key: string] = timestamp: number }
	self._AutosaveTimestamp = {} -- { [Key: string] = timestamp: number }
	self._SavePendingQueue = {} -- { [Key: string] = {Key, Data, WAL, Backup, IsSafe } }
	self._DataCache = {} -- { [Key: string] = Data: any }
	self._BoundRegistry = {} -- { [Key: string] = table }
	self._LockSessions = ScopedMutex.new(Mutex)
	self._LockTimers = {}

	self._ExclusiveTimerCalled = false
	self._AutosaveDied = false
	self._ExclusiveSafetyCalled = false
	self._IsRunning = false

	self._TrackedValidations = {} -- { [Key] = { Member = ValidationFunction, ... } }
	self._TrackedSchemas = {} -- { [Key] = { Member = ValidationFunction, ... } }
	self._TrackedClamps = {} -- { [Key] = { Member = ValidationFunction, ... } }

	self._UDataComponentCallbacks = SDictionary.new("string", "table", {
		OnDataLoading = {},
		OnDataLoaded = {},
		OnDataSaving = {},
		OnDataSaved = {},
		OnDataArchived = {},
		OnDataRecovery = {},
		OnDataCached = {},
		OnDataRemoved = {},
		OnDataBinding = {},
		OnDataUnbinding = {},
		OnReleased = {},
		OnDataError = {}
	})

	if Configurations then
		for key, value in pairs(Configurations) do
			self[key] = value
		end
	end

	return self
end

function UDataComponent:GetPlayerData(Key : string | number, Callbacks : {UDataComponentCallbackFunctions?}) : UDataComponentRecord
	if Callbacks then
		for key, value in pairs(Callbacks) do
			local currentFunc = self._UDataComponentCallbacks:Get(key)

			if currentFunc then
				currentFunc[Key] = value
			end
		end
	end

	return InPlayerData(self, Key) :: UDataComponentRecord
end

function UDataComponent:GetDataStoreName() : string
	return self._DataStoreName
end

return UDataComponent :: UDataComponent
