--[[
Created by RaihanMan18

Profiles:
Creator Name: @RaihanMan18 (Raihan Naufal Azmi)
Creation Name: UDataComponent v2.0
Integrity: Secure data with ownership and server session locking, with strong runtime data-checking with mutexes and queue
Team: Solo Creator
License: MIT License
Language: Luau
Version: 2.0

Last Update: Aug 25 2026

SOME INFORMATION USE I OR ME, IT'S REFERENCING TO MYSELF (Raihan), AND
SOME INFORMATION MENTION "UDC", IT'S REFERENCING TO SELF-AUTOMATIC SYSTEM OF THIS MODULE (UDataComponent)

Notes!

UDataComponent is an Essential module.
You can't change the absolute things from UDataComponent and its module,
like what it's operating internally, you should understand or adapted to what UDC handles for you.

When you tried to change ownership of a record, it may cause a corrupt both in data and this module's consistency.
Yes, you can use "Enter()", etc. for ownership transfer. BUT, it's not a recommended method, even though I created that methods, just for specific purposes.
Meanwhile, you can just use Sleep() method to release the ownership. And anoother server can safely claim the record.

API Public Cores that you can use in flexible way (for beginner, advanced, etc):

- Awake() -- Pulling the player's record, and make it "waking up" from sleep, while start to claiming the ownership of this record to current server

- Ready(FindingPlayerTimeout: number = 10) -- Preparing the player's record with deep and strict checking, this is where the data of record decompressed, reconciled, validated, and prepared to record.Data

- Standby() -- Automatically release the record with sleep, while safely save the current data of record that modified from record.Data, both for server shutdown or normal player leaving

- record.Data -- This is where you can access the data of player's record as read-only. But in condition, the data is ready

- Save(Data: any = record.Data, SegmentIndex: number nil) -- Save the whole data, and you can specify the segment index to save the data to that segment.

- Write(WritingFunction: (CurrentData: any)) -- Write the current data of the record safely, meanwhile this is a best choice for modifying the data with validations, 

Sleep() -- Manual core

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
3. When ServerB tries to claim a record that has been claimed by ServerA, before shutdown/stale time or stopped heartbeat (because no activity from the record), it cannot claim the record
4. But, when the record from ServerA is died, it can be claimed by ServerB as long as the heartbeat is dead
5. When two servers, ServerA and ServerB, both tries to Awake() the same record at the same time, it will be handled gracefully, and only one of them will be able to claim
6. When a player hopped from ServerA to ServerB, and the record from ServerA has been ready and released, ServerB allowed to claim the record from ServerA

Result of Multi Server Testing: SUCCESS

E. WAL Testing
1. When there is a WAL entry, it will be applied to the data, but before that, the version of WAL and remaining Main Data will be compared
2. When WAL entry's version is newer than the remaining Main Data, it will be applied to the data, otherwise, it will be ignored
3. After WAL entry is applied, the entry will be removed
4. Even WAL entry didn't get removed after applied its entry to Main Data, it won't be a problem, because it will be removed after the next update and still returns the data
5. When shutdown or player removing, the data will be written into WAL first, and the emergency compression with specific level applied gracefully, but if the entry was just for player leaving and not
	server shutdowning, the entry just replaced by ForceSave and the entry of WAL removed
	
Result of WAL Testing: SUCCESS

F. Compression Testing
1. When the data is small, and overhead detected, it just applied the raw/real buffer data into the data of record
2. Otherwise, when the data is big/so big, and no overhead detected, it will be compressed and applied into the data of record
3. Consistent flag that indicates the compression of data type, 'C' means compressed, 'R' means real/uncompressed/raw
4. Consistent decompressing by check the flag of record when preparing, if 'C' will be decompressed, 'R' will be applied to record explicitly
5. When a compression stack was compressed and the data was proceed to save, but its in same compression or compressed by the compressor stack, it would use the same compression would rather than generate a new one
6. Consistent compression, not following the same compression at first write. But a new one, from compressor stack or a new one

Result of Compression Testing: SUCCESS

G. Concurrency Testing
1. Burst Awake() after joined within 20 calls, didn't crash and budget is saved as much as possible
2. Burst Awake() within 15 calls with max load concurrent worker within 3 workers, handled the load data gracefully and maximally 3 or less workers of each working
3. Grace operations of datastore budget, when trying to load the record, without create too much requests to the datastore
4. When the player is leaving meanwhile the record processing to save the data, it won't commit into datastore
5. Calling 100 records, with just save concurrent workers as much as 10. Can commit all records into datastore without any overlaps each keys
6. Mutexes work, when two thread tries to Write for same record. Those functions able to save the data, one thread save the data meanwhile another data waits. and then the waited thread operates

Result of Concurrency Testing: SUCCESS

H. Standby testing
1. Standby() easily saving the data of record and released, both from PlayerLeaving or server shutdown
2. Server shutdown handles all active records that in standby, saving then releasing.
3. Easily handles all 150 player's records when server shutdown, and roughly maximum as 200 records could be handled too
4. Easily saving 200 players when shutdown, with heavy data and compression

Result of Standby Testing: SUCCESS

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

local ServerId = _G.__UDC_MOCK_SERVERID or game.JobId
local PlaceId = game.PlaceId

local ConnectionTest = DataStoreService:GetDataStore("ConnectionTest-" .. PlaceId)

local EMERGENCY_COMPRESSION_LEVEL = 0

local InfosStorage = {}

UDataComponent.Enabled = true

-- State Machines:
--[[
	"Asleep" -> where the record is not owned by any server or remaining untouched, or the data has been unarchived
	"WakingUp" -> where the record is claimed by a server, but not ready to be used yet
	"Ready" -> where the record is ready to be used
	"Running" -> where the record is proceed to saving the data, and return to Ready again after saving process stopped
	"Sleeping" -> where the record is failed to be ready, so the record fall asleep again, but in condition that data has been loaded but unready
	"Died" -> where the record is getting detached/removed/archived, along the release
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
	
	some other things
	__password : string (COMING SOON)
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
	ViewCurrentRecord: (UDCInfo: UDCInfo, Key: number | string, Version: string?) -> UDCRecord,
	-- This is where you can view the record of player's data, also showing owner and version
	-- @param: Key: number | string -> Key of the record of this player
	-- @param: Version: string? -> Version of the record of this player, if not specified, the latest version will be viewed
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
	MessagingExpiration : number, -- Duration for the broadcast to expire
	MessagingMaxPacketSize : number, -- Maximum size for the broadcast message
	MessagingSendingCooldown : number, -- Cooldown for sending the broadcast informations
	MessagingReceivingCooldown : number, -- Cooldown for listening the broadcast messages
	MessagingLocalListeningCooldown : number, -- Cooldown for listening the local broadcast messages
	ArchivationEnabled : boolean, -- If this UDataComponent's info allowed to use archivation, where the data will be moved to the archived data store after detaching
	ArchivationSuffix : string, -- Suffixed to the DataStore name for the archived data,
	MaxDataSavingPerTick : number, -- Maximum data saving per tick in FIFO queue,
	MaxDataObtainingPerTick : number, -- Maximum data obtaining per tick in FIFO queue,
	MaxConcurrentLoadWorkers : number, -- Maximum concurrent load workers
	MaxConcurrentSaveWorkers : number, -- Maximum concurrent save workers
	MaxConcurrentAutosaveWorkers : number, -- Maximum concurrent autosave workers
	MaxStandbyWorkers : number, -- Maximum concurrent workers in standby when trying to commit data when shutdown
	StaleServerClaimingTime : number, -- Duration for the server to claim the data of other server
	ShutdownSecondsToken : number, -- Duration for the shutdown seconds remaining to prevent data loss
}

-- info level helper for internal...
export type __UDCInfo_Internal = {
	Name: string, -- Name of the data store from this info
	Scope: string, -- Scope of the data store from this info

	GetCurrentRecord: (UDCInfo: UDCInfo, Key: number | string, OwnerOfThisData: Player) -> UDCRecord,
	-- This is where the record of player's data is obtained:
	-- @param: Key: number | string -> Key of the record of this player
	-- @param: OwnerOfThisData: Player -> Player who owns this data, prevent other servers or other player to obtain or commit the data
	ViewCurrentRecord: (UDCInfo: UDCInfo, Key: number | string) -> UDCReadOnlyRecord,
	-- This is where you can view the record of player's data, also showing owner and version
	-- @param: Key: number | string -> Key of the record of this player
	GetLocalRecord: (UDCInfo: UDCInfo) -> UDCRecord,
	-- This is where the record of local data is obtained
	-- You can say, in UDC, local data is just "global data of this data store" or "global record"
	ViewLocalRecord: (UDCInfo: UDCInfo) -> UDCReadOnlyRecord,
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
	_BroadcastPendingQueue : { any? },
	_UnreadyData : { any? },
	_DataCache : { any? },
	_CompressionStack : { any? },
	_StandbyRegistry : { any? },
	_DirtySave : { any? },
	_LockSessions : any,
	_BroadcastingTimestamps : { any? },
	_LocalBroadcastListeners : { any? },

	_ExclusiveTimerCalled : boolean,
	_ShutdownCalled : boolean,
	_ExclusiveSafetyCalled : boolean,
	_IsSaveRunning : boolean,
	_IsObtainingRunning : boolean,
	_IsCompressionTimerRunning : boolean,
	_CacheCleaningCalled : boolean,
	_StandbyReady : boolean,
	_RecordBroadcastCalled : boolean,
	_BroadcastQueueRunning : boolean,
	
	_CurrentLoadWorkers : number,
	_CurrentSaveWorkers : number,
	_CurrentAutoSaveWorkers : number,

	_TrackedValidations : { any? },
	_TrackedSchemas : { any? },
	_TrackedClamps : { any? },

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
	MessagingExpiration : number, -- Duration for the broadcast to expire
	MessagingMaxPacketSize : number, -- Maximum size for the broadcast packet, in bytes
	MessagingSendingCooldown : number, -- Cooldown for sending the broadcast informations
	MessagingReceivingCooldown : number, -- Cooldown for listening the broadcast messages
	MessagingLocalListeningCooldown : number, -- Cooldown for listening the local broadcast messages
	ArchivationEnabled : boolean, -- If this UDataComponent's info allowed to use archivation, where the data will be moved to the archived data store after detaching
	ArchivationSuffix : string, -- Suffixed to the DataStore name for the archived data,
	MaxDataSavingPerTick : number, -- Maximum data saving per tick in FIFO queue,
	MaxDataObtainingPerTick : number, -- Maximum data obtaining per tick in FIFO queue,
	MaxConcurrentSaveWorkers : number, -- Maximum concurrent save workers
	MaxConcurrentLoadWorkers : number, -- Maximum concurrent load workers
	MaxConcurrentAutosaveWorkers : number, -- Maximum concurrent autosave workers
	MaxStandbyWorkers : number, -- Maximum concurrent workers in standby when trying to commit data when shutdown
	StaleServerClaimingTime : number, -- Duration for the server to claim the data if the owner is unknown
	ShutdownSecondsToken : number, -- Duration for the shutdown seconds token, where the server will not save the data after this duration
}

-- Record level, where the data record is accessed here
export type UDCRecord = {
	Key: number | string, -- Key of this data
	Owner: Player?, -- Player who owns this record
	IsArchived: boolean, -- If this record was detached and archived
	Event: UDCEvent, -- Utils for the events
	Validation: UDCValidation, -- Utils for the validation
	Swap: UDCSwap, -- Utils for the swap
	Broadcasting: UDCBroadcasting, -- Utils for the messaging
	Version: number, -- Version of this data
	Data: any?, -- Loaded Data that has been loaded, this is a clone from the actual data/cache, where this must be a read-only member
	CurrentState: string, -- Current state of this data, can be: "Asleep", "WakingUp", "Ready", "Running", "Sleeping", "Died"
	
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
	
	Save: (UDCRecord: UDCRecord, Data: any, SegmentIndex: number?) -> boolean, -- (Suspending) this is saving data where the data must be an over-all data, which is the previous record that haven't been edited also must be saved too, will pushed into save pending queue then changed the read data
	-- @param Data: any? -- Custom data to commit, or saving whole data.
	-- @param SegmentIndex: number? -- Where the current data is contained in an index to
	-- @return boolean -- Status of the saving data, true if success, but true in here isn't meaning the data is actually commited
	
	Write: (UDCRecord: UDCRecord, WritingFunction: (CurrentData: any) -> ()) -> boolean, -- (Suspending) this is how you can save the data with partial update, where you don't need to commit all data to write when you just need one or two or more datas to edit
	-- @param WritingFunction: (CurrentData: any) -> () -- Function that used as Write session over the data
	-- @return boolean -- Status of the writing data, true if success, but true in here isn't meaning the data is actually commited
	
	ForceSave: (UDCRecord: UDCRecord, Data: any, SegmentIndex: number?) -> boolean, -- (Suspending) same as record:Save(...), but this will commit into datastore immediately
	-- @param Data: any -- Data to commit
	-- @param SegmentIndex: number? -- Where the current data is contained in an index to
	-- @return boolean -- Status of the saving data, true if success
	
	COMINGSOON_Enter: (UDCRecord: UDCRecord, Password: string) -> boolean, -- (Suspending) that tries to enter into the record with password of record that tried be entered with
	-- This will steal the data from the previous owner, and will be locked for current server session.
	-- @important -- When you use this function to steal the record ownership, make sure you're also release the session after used the record. So, the original owner can use its record back
	-- @param Password: string -- Password for stealer record to enter into the desired record, the password is held by original owner
	-- @return boolean -- Status of the entering the record, true if success
	
	COMINGSOON_GenerateLogin: (UDCRecord: UDCRecord, ThisRecordPassword: string) -> boolean, -- (Suspending) makes a password for this record, where "stealer" server needs to input this password before could enter into the record by another server session
	-- GenerateLogin also acts as "this record can be stolen" or "open source" to another server or another record, without generating login with this. Current Record guaranteed to be safe from session stealing
	-- @important -- Generating login would cause this record to be corrupted when some servers that tried to steal session of this record, use this carefully and always to release the data after steal the ownership 
	-- @param ThisRecordPassword: string -- Key or password for this record to be stolen with
	-- @return boolean -- Status if the record is successfully generated the login and allowed to be stolen
	
	COMINGSOON_DestroyLogin: (UDCRecord: UDCRecord, Password: string) -> boolean, -- (Suspending) destroy the password and login session of this record, so other servers can't enter or steal this record
	-- @important -- When you tried to destroy the login session of this record, meanwhile the stealer was from another server, you can't do it, you can only destroy the login session by original server
	-- @important -- You can only release the record from original server, not server that stole the record
	-- @param Password: string -- Safety key before destroying the login session of this record
	-- @return boolean -- Status of the destroying the login session, true if success

	ForceWrite: (UDCRecord: UDCRecord, WritingFunction: (CurrentData: any) -> ()) -> boolean, -- (Suspending) same as record:Write(...), but this will commit into datastore immediately
	-- @param WritingFunction: (CurrentData: any) -> () -- Function that used as Write session over the data
	-- @return boolean -- Status of the writing data, true if success
	
	Detach: (UDCRecord: UDCRecord) -> boolean, -- (Suspending) DANGEROUS, this will destroy/erase the record data from datastore and cache, but if archivation is true, the data will be archived
	-- @return boolean -- Status of the erasing the data, true if successfully detached/removed the data
	
	Unarchive: (UDCRecord: UDCRecord) -> boolean, -- (Suspending) Call the removed data from datastore, where the data will be immediately written into cache
	-- @return boolean -- Status of the unarchiving data, true if success
	
	IsRecorded: (UDCRecord: UDCRecord) -> boolean, -- Check if the record is still exist in datastore
	-- @return boolean -- True if the record is still exist in datastore
}

export type UDCEvent = {
	OnReleased: (UDCEvent: UDCEvent, Callback: (Key: string | number) -> any) -> UDCEventConnector,
	-- happened when the record is released, actually happened by Sleep() call or Standby() triggers
	OnReady: (UDCEvent: UDCEvent, Callback: (Key: string | number) -> any) -> UDCEventConnector,
	-- happened when the record is ready to be used, actually happened by Ready()
	OnSaved: (UDCEvent: UDCEvent, Callback: (Key: string | number) -> any) -> UDCEventConnector,
	-- happened when the record is saved, actually happened when the data of record finally commited to datastore
	OnLoaded: (UDCEvent: UDCEvent, Callback: (Key: string | number) -> any) -> UDCEventConnector,
	-- happened when the record is loaded, actually happened by Awake()
	OnStandby: (UDCEvent: UDCEvent, Callback: (Key: string | number) -> any) -> UDCEventConnector,
	-- happened when the record is on standby action, actually happened by Standby()
	OnAutoSaved: (UDCEvent: UDCEvent, Callback: (Key: string | number) -> any) -> UDCEventConnector,
	-- happened when the record is being commited automatically by autosave, happened every autosave interval kicks in
	OnArchived: (UDCEvent: UDCEvent, Callback: (Key: string | number) -> any) -> UDCEventConnector,
	-- happened when the record is being detached or archived or removed, happened by Detach()
	OnUnarchived: (UDCEvent: UDCEvent, Callback: (Key: string | number) -> any) -> UDCEventConnector,
	-- happened when the record is finally unarchived, happened by Unarchive()
	
	OnWrite: (UDCEvent: UDCEvent, Callback: (Key: string | number) -> any) -> UDCEventConnector,
	-- happened when the data of the record has been modified before commited, actually happened by Write() or Save() or Force*()
	
	OnBroadcastSent: (UDCEvent: UDCEvent, Callback: (Key: string | number) -> any) -> UDCEventConnector,
	-- happened when the record is sent to other server with messaging, actually happened by BroadcastCurrentData()
	OnBroadcastReceived: (UDCEvent: UDCEvent, Callback: (Key: string | number, BroadcastPacket: UDCBroadcastingPacket) -> any) -> UDCEventConnector,
	-- happened when the record is received from other server by messaging, this is where you can receive the broadcast packet from a broadcaster server
	
	OnRecordBroadcastReceived: (UDCEvent: UDCEvent, Callback: (Key: string | number, BroadcasterKey: string | number, BroadcastPacket: UDCBroadcastingPacket) -> any) -> UDCEventConnector,
	-- happened when a record broadcasting to another record in another server, this is where you can receive the record's broadcasting data
	
	OnError: (UDCEvent: UDCEvent, Callback: (Key: string | number, Error: string) -> any) -> UDCEventConnector,
	-- happened when the record is having error in message
	OnDataFiltered: (UDCEvent: UDCEvent, Callback: (Key: string | number, FilteredData: string | number) -> any) -> UDCEventConnector,
	-- happened when the record is getting filtered by validation, happened when loaded or Write()
	
	OnOwnershipExpired: (UDCEvent: UDCEvent, Callback: (Key: string | number) -> any) -> UDCEventConnector,
	-- happened when the ownership of this record expired when preparing
}

export type UDCValidation = {
	AddPredicate: (UDCValidation: UDCValidation, ThisData: string | number, Predicate: (ThisValue: any) -> (), Penetration: number?) -> (),
	-- Adding validation function where current data must be operating on the exact predicate, if not, the data is invalid to operate
	-- @param ThisData: string | number -- Data name or index of data
	-- @param Predicate: (ThisValue: any) -> () -- Validation function, ThisValue is the value of the data
	-- @param Penetration: number? -- Penetration level, default is 1, penetration means that step's access of data if the record was having same data name/index
	
	-- For Penetration, 1 does mean that when there is two same data name, like Data = { Data = ... }. It will access Data's data with table value, when you set it to 2, it will access Data's data inside through
	
	RemovePredicate: (UDCValidation: UDCValidation, ThisData: string | number, PenetrationIndex: number?) -> (),
	-- Removing predicate function of validation
	-- @param ThisData: string | number -- Data name or index of data
	-- @param PenetrationIndex: number? -- Default is 1, removing the validation tag of current data in record
	
	RemoveAllPredicates: (UDCValidation: UDCValidation) -> (),
	-- Removing all predicate function of validation
	
	AddSchema: (UDCValidation: UDCValidation, ThisData: string | number, Schema: string, Penetration: number?) -> (),
	-- Adding schema/type to validate the data, if the data is not match the schema, it will be invalid
	-- @param ThisData: string | number -- Data name or index of data
	-- @param Schema: string -- String that will be used for checking the data type
	-- @param Penetration: number? -- Penetration level, default is 1, penetration means that step's access of data if the record was having same data name/index
	
	RemoveSchema: (UDCValidation: UDCValidation, ThisData: string | number, PenetrationIndex: number?) -> (),
	-- Removing schema of current data in record
	-- @param ThisData: string | number -- Data name or index of data
	-- @param PenetrationIndex: number? -- Default is 1, removing the validation tag of current data in record
	
	RemoveAllSchemas: (UDCValidation: UDCValidation) -> (),
	-- Removing all schema of validation
	
	AddClamp: (UDCValidation: UDCValidation, ThisData: string | number, Min: number?, Max: number?, Penetration: number?) -> (),
	-- Adding clamp to validate the data, if the data is out of bound, it will be clamped through min or max
	-- @param ThisData: string | number -- Data name or index of data
	-- @param Min: number? -- Minimum value of the data
	-- @param Max: number? -- Maximum value of the data
	-- @param Penetration: number? -- Penetration level, default is 1, penetration means that step's access of data if the record was having same data nam
	
	-- If you want to set Min function to the data, just set Max to nil, same methods if you set Max instead

	RemoveClamp: (UDCValidation: UDCValidation, ThisData: string | number, PenetrationIndex: number?) -> (),
	-- Removing clamp of current data in record
	-- @param ThisData: string | number -- Data name or index of data
	-- @param PenetrationIndex: number? -- Default is 1, removing the validation tag of current data in record
	
	RemoveAllClamps: (UDCValidation: UDCValidation) -> (),
	-- Removing all clamps of validation
}

export type UDCSwap = {
	
}

export type UDCBroadcasting = {
	BroadcastCurrentData: (UDCBroadcasting: UDCBroadcasting, OtherThings: any?) -> boolean,
	-- Global broadcasting the data to all servers
	WaitForBroadcastPacket: (UDCBroadcasting: UDCBroadcasting, Timeout: number?) -> UDCBroadcastingPacket,
	-- (ULTIMATELY SUSPENDING) Waiting for global broadcast packet from other server
	SendLocalBroadcast: (UDCBroadcasting: UDCBroadcasting, ChannelName: string, OtherThings: any?) -> boolean,
	-- Sending local broadcast to other server that listening on the channel
	ListenToLocalBroadcast: (UDCBroadcasting: UDCBroadcasting, ChannelName: string, Listener: (BroadcastPacket: UDCBroadcastingPacket) -> any) -> UDCEventConnector,
	-- Listening for local broadcast from other server
	SendBroadcastToRecord: (UDCBroadcasting: UDCBroadcasting, TargetKey: string | number, OtherThings: any) -> boolean
	-- Sending broadcast to specific record in other server
}

export type UDCBroadcastingPacket = {
	BroadcasterKey: string | number, -- record's key who broadcasted
	BroadcasterData: any, -- record's data of broadcaster
	BroadcasterServerId: string, -- broadcaster record's current server id 
	BroadcasterOwnerId: number, -- the owner id of the record
	BroadcastTime: number,	 -- timestamp of broadcasting
	OtherThings: any?, -- other things you want to send with the broadcast
}

export type UDCEventConnector = {
	Wait: (self: UDCEventConnector) -> any,
	Disconnect: (self: UDCEventConnector) -> (),
	DisconnectAfterCalled: (self: UDCEventConnector) -> (),
}

export type UDCReadOnlyRecord = {
	Version: number,
	Owner: Player?,
	Data: { any? },
}

-- finding the index of standby registry
local function find_standby_index(meta : __UDCInfo_Internal, key)
	for i, v in ipairs(meta._StandbyRegistry) do
		if v.Key == key then
			return i
		end
	end
end

-- automatic compression, by checking if there is an overhead if compressed or not
local function compare_and_compress(meta : __UDCInfo_Internal, data : { any? })
	local buff, flag = Compressor.TryToCompress(data, meta.CompressionLevel, meta.CompressionThreshold)

	return buff, flag
end

local function compare_broadcast_payload(meta : __UDCInfo_Internal, rawData : any)
	local success, encoded = pcall(HttpService.JSONEncode, HttpService, rawData)
	if not success then return nil, nil, "failed" end

	if #encoded <= meta.MessagingMaxPacketSize then
		return encoded, "R", nil
	end

	local success, compressed, flag = pcall(compare_and_compress, meta, rawData)
	if success and compressed and flag and #compressed <= meta.MessagingMaxPacketSize then
		return compressed, flag, nil
	end

	return nil, nil, "oversized"
end

local function can_send_broadcast(meta : __UDCInfo_Internal)
	local now = workspace:GetServerTimeNow()
	local timestamps = meta._BroadcastingTimestamps

	while #timestamps > 0 and now - timestamps[1] > 60 do
		table.remove(timestamps, 1)
	end

	local limit = math.min(150 + (#Players:GetPlayers() * 10), 250)
	return #timestamps < limit
end

local function record_broadcast_sent(meta : __UDCInfo_Internal)
	table.insert(meta._BroadcastingTimestamps, workspace:GetServerTimeNow())
end

-- for deepcloning table
local function deepclone(tab, seen)
	if typeof(tab) ~= "table" then
		return tab
	end
	local newTab = seen or {}
	
	for k, v in pairs(tab) do
		if newTab[k] == nil then
			newTab[k] = v
		elseif typeof(v) == "table" and typeof(newTab[k]) == "table" then
			newTab[k] = deepclone(v, seen)
		end
	end
	
	return newTab
end

-- for deepcloning then deepfreezing table
local function deepfreeze(tab, frozen)
	frozen = frozen or {}
	if typeof(tab) ~= "table" then
		return tab
	end
	
	local copy = frozen[tab] or {}
	
	for k, v in pairs(tab) do
		if typeof(v) == "table" then
			copy[k] = deepfreeze(v, frozen)
		else
			copy[k] = v
		end
	end
	
	table.freeze(copy)
	return copy
end

-- to call event
local function dispatch(meta : __UDCInfo_Internal, record : UDCRecord, eventName : string, ...)
	if not meta.CallbackEnabled then
		return
	end
	
	local args = table.pack(...)
	local ucallbacks = meta._UDataComponentDynamicCallbacks[eventName]
	if not ucallbacks then return end
	
	local dynamicCallbacks = ucallbacks[record.Key]
	if not dynamicCallbacks then return end

	if dynamicCallbacks then
		local matched = {}
		for key, cb in pairs(dynamicCallbacks) do
			table.insert(matched, cb)
		end

		for _, cb in pairs(matched) do
			task.spawn(function()
				local success, result = pcall(cb, record.Key, table.unpack(args))
				if not success then
					local format = string.format("[UDataComponent-InternalErr(%s-%s)]: %s", record.Key, eventName, result)
					warn(format)
				end
			end)
		end
	end
end

-- to call specific, OnError event, with message
local function throw(meta : __UDCInfo_Internal, record : UDCRecord, message : string)
	if message == "" or not message then
		message = "No message"
	end
	
	local namespace = "[" .. meta.ErrorReasonNamespace .. "]: "
	dispatch(meta, record, "OnError", namespace .. message)
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
	
	local xresult = success and result
	
	-- Checking if the result is success and has a valid data, and WAL entry is existed
	if xresult and entry then
		-- Remove the WAL entry after successfully commiting the data
		pcall(function()  
			meta._CurrentWALDataStore:RemoveAsync(record.Key)
		end)
	end
	
	return result
end

local function save_data(meta : __UDCInfo_Internal, record : UDCRecord)
	record.CurrentState = "Running"

	local now = workspace:GetServerTimeNow()
	local thisOwnerId = record.Owner and record.Owner.UserId or 0
	
	local dataCache = meta._DataCache[record.Key]
	if not dataCache then 
		record.CurrentState = "Ready"
		throw(meta, record, "Data is not loaded yet to saving operation, please load the record first.")
		return false 
	end
	
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
				record.CurrentState = "Ready"
				throw(meta, record, "Failed to compress the data of record when trying to save. Reason: " .. tostring(newCompressed))
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
		if not ok then 
			record.CurrentState = "Ready"
			throw(meta, record, "Failed to compress the data of record when trying to save. Reason: " .. tostring(newCompressed))
			return false 
		end

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
				CurrentData.__bounds.since = now
				return CurrentData
			end)
		end)
	end)
	
	local result = success and result
	if result then
		local dirtySave = meta._DirtySave[record.Key]
		if dirtySave then
			meta._DirtySave[record.Key] = nil
		end
		
		dispatch(meta, record, "OnSaved")
	end
	record.CurrentState = "Ready"
	
	return result
end

local function write_to_wal_or_fs(meta : __UDCInfo_Internal, record : UDCRecord, now : number)
	local currentData = meta._DataCache[record.Key]
	if not currentData then
		throw(meta, record, "Data is not loaded yet to be saved automatically.")
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

			if not ok then 
				throw(meta, record, "Failed to compress the data of record when trying to write the record in standby operation. Reason: " .. tostring(newCompressed))
				return false 
			end

			compressed, flag = newCompressed, newFlag
		end
	else
		local ok, newCompressed, newFlag = pcall(Compressor.TryToCompress, data, EMERGENCY_COMPRESSION_LEVEL, meta.CompressionThreshold)
		if not ok then 
			throw(meta, record, "Failed to compress the data of record when trying to write the record in standby operation. Reason: " .. tostring(newCompressed))
			return false 
		end

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
					local isDifferentOwner = id and id ~= thisOwnerId

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
				
				CurrentData.__bounds.serverid = nil
				CurrentData.__bounds.lastheartbeat = nil
				CurrentData.__bounds.since = now

				return CurrentData
			end)
		end)
	end)
	
	local xresult = success and result
	
	if xresult and not meta._ShutdownCalled then
		local isForcedSaveSuccess, saveResult = pcall(record.ForceSave, record, data)
		
		local index = 0
		for i, pending in ipairs(meta._SavePendingQueue) do
			if pending.Meta and pending.Meta.Key == record.Key then
				index = i
				break
			end
		end
		
		if index then
			table.remove(meta._SavePendingQueue, index)
		end
		
		if isForcedSaveSuccess and saveResult then
			pcall(function() meta._CurrentWALDataStore:RemoveAsync(record.Key) end)
			pcall(record.Sleep, record)
		end
		
		dispatch(meta, record, "OnSaved")
		record.CurrentState = "Asleep"
	end
	
	return xresult
end

local function fallback_backup(meta : __UDCInfo_Internal, record : UDCRecord)
	if not meta.BackupEnabled then
		throw(meta, record, "Backup is disabled")
		return nil
	end
	
	local thisOwnerId = record.Owner and record.Owner.UserId or 0
	local now = workspace:GetServerTimeNow()
	
	local success, result = pcall(function()
		return meta._CurrentDataStore:ListVersionsAsync(record.Key, Enum.SortDirection.Descending)
	end)
	
	if success and result then
		local lastData = result:GetCurrentPage()[1]
		if lastData == nil then 
			throw(meta, record, "There is no backup data obtained, it seems the data is lost after 30 days or something...")
			return nil 
		end
		
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
	
	throw(meta, record, "Unable to get the backup of data")
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
				throw(meta, first.Meta, "Owner of this record left the game")
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
			
			if first.Meta and first.Meta.Owner and first.Meta.Key and not meta._DataCache[first.Meta.Key] and Players:GetPlayerByUserId(first.Meta.Owner.UserId) == nil then
				throw(meta, first.Meta, "Owner of this record left the game")
				task.spawn(first.Thread, false) -- Data is already unloaded, cancel the save request
				continue
			end
			
			meta._CurrentSaveWorkers += 1 -- Workers in working
			task.spawn(function()
				local success, err = pcall(save_data, meta, first.Meta)
				
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
		
		if meta._ShutdownCalled then return end -- Preventing dead UDataComponent to do commands
		
		for i, info in ipairs(meta._StandbyRegistry) do
			local sameOwner = info.Record and info.Record.Owner and info.Record.Owner.UserId == userId
			
			if sameOwner then
				write_to_wal_or_fs(meta, info.Record, now)
				pcall(info.Record.Sleep, info.Record)
				
				table.remove(meta._StandbyRegistry, i)
				break
			end
		end
	end)
	
	game:BindToClose(function()
		meta._ShutdownCalled = true
		
		local dirty = {}
		local normals = {}
		for _, info in ipairs(meta._StandbyRegistry) do
			if info and info.Record and info.Key and meta._DataCache[info.Key] then
				if meta._DirtySave[info.Key] then
					table.insert(dirty, info)
					continue
				end
				
				table.insert(normals, info)
			end
		end
		meta._StandbyRegistry = {}
		
		local working = { Workers = 0 }
		
		local now = workspace:GetServerTimeNow()
		local stopped = false
		
		while (#dirty > 0 or #normals > 0) and not stopped do
			if workspace:GetServerTimeNow() - now > meta.ShutdownSecondsToken then
				stopped = true
				break
			end
						
			while (#dirty > 0 or #normals > 0) and working.Workers < meta.MaxStandbyWorkers do
				local updateBudget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
				if updateBudget < 1 then break end
				
				local item = table.remove(dirty, 1)
				if item then
					working.Workers += 1
					task.spawn(function()
						pcall(write_to_wal_or_fs, meta, item.Record, now)
						working.Workers -= 1
					end)
				end
				
				local normal = table.remove(normals, 1)
				if normal then
					working.Workers += 1
					task.spawn(function()
						pcall(normal.Record.Sleep, normal.Record)
						working.Workers -= 1
					end)
				end
			end
			
			task.wait()
		end
	end)
end

-- just to remember, autosave in UDC saving the dirty record that still in queue
-- so, when your Save/Write request was still in queue and the record is dirty, but autosave interval hits, it will automatically saved seperatedly instead
local function run_autosave(meta : __UDCInfo_Internal)
	if meta._AutosaveCalled or meta._ShutdownCalled then return end
	meta._AutosaveCalled = true
	
	RunService.Heartbeat:Connect(function()
		if not meta.Enabled or not UDataComponent.Enabled or meta._ShutdownCalled then return end
		
		local now = workspace:GetServerTimeNow()
		local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
		
		while budget > 0 and meta._CurrentAutoSaveWorkers < meta.MaxConcurrentAutosaveWorkers and not meta._ShutdownCalled do
			local dirty = {}
			for key, info in pairs(meta._AutosaveTimestamp) do
				if info and info.Record and info.Timestamp and now - info.Timestamp > meta.AutoSaveInterval and meta._DirtySave[key] and meta._DataCache[key] and not meta._ShutdownCalled then
					table.insert(dirty, info.Record)					
				end
			end
			
			if #dirty == 0 then break end
			
			for _, record in ipairs(dirty) do
				local currentBudget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) -- refresh the budget
				if currentBudget <= 0 then break end
				
				local cache = meta._DataCache[record.Key]
				if not cache then 
					throw(meta, record, "Record is not loaded to get autosaved by UDC, please load the record first.")
					continue 
				end
				
				local data = deepclone(cache.__data)

				meta._CurrentAutoSaveWorkers += 1
				task.spawn(function()	
					pcall(record.ForceSave, record, data)
					
					meta._CurrentAutoSaveWorkers -= 1
					meta._AutosaveTimestamp[record.Key].Timestamp = workspace:GetServerTimeNow() -- Reset the timestamp to prevent multiple saves, and must be the newest timestamp after saving
					
					dispatch(meta, record, "OnAutoSaved")
				end)
			end
		end
	end)
end

local function run_broadcast_queue(meta : __UDCInfo_Internal)
	if meta._BroadcastQueueRunning or meta._ShutdownCalled then return end
	meta._BroadcastQueueRunning = true
	
	RunService.Heartbeat:Connect(function() 
		while #meta._BroadcastPendingQueue > 0 and can_send_broadcast(meta) and meta.MessagingEnabled and not meta._ShutdownCalled do
			local item = table.remove(meta._BroadcastPendingQueue, 1)
			if not item then continue end
			
			if item.Target then
				item.Packet.__target = item.Target
			end
			
			local successCompressed, compressed, flag = pcall(compare_broadcast_payload, meta, item.Packet)
			if not successCompressed then 
				throw(meta, item.Record, "Unable to broadcast packet, reason: " .. tostring(compressed))
				continue 
			end
			
			local deliver = {}
			deliver.__data = compressed
			deliver.__flag = flag
			
			local success, err = pcall(function()
				return MessagingService:PublishAsync(item.Channel, deliver)
			end)
			
			record_broadcast_sent(meta)
			
			if success then
				dispatch(meta, item.Record, "OnBroadcastSent")
			else
				throw(meta, item.Record, "Unable to broadcast packet, reason: " .. tostring(err))
			end
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
	
	local find = find_standby_index(meta, record.Key)
	if not find then
		table.insert(meta._StandbyRegistry, { Record = record, Key = record.Key })
		return true
	end
	
	return false
end

local function push_to_autosave(meta : __UDCInfo_Internal, record : UDCRecord)
	run_autosave(meta)
	
	local now = workspace:GetServerTimeNow()
	if not meta._AutosaveTimestamp[record.Key] then
		meta._AutosaveTimestamp[record.Key] = { Record = record, Timestamp = now }
		return true
	end
	
	return false
end


local function enqueue_broadcast(meta : __UDCInfo_Internal, record : UDCRecord, channel : string, packet : any, targetKey : string? | number?)
	if not meta.MessagingEnabled then
		return
	end
	
	run_broadcast_queue(meta) -- First-time run the broadcast queue if it's not running

	table.insert(meta._BroadcastPendingQueue, {
		Channel = channel,
		Packet = packet,
		Record = record,
		Target = targetKey,
	})
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
		
		if not schema then
			continue
		end
		
		if not penetration then
			penetration = 1 -- default penetration
		end
		
		local element = find_element(data, key, penetration) -- finding elements through nested ways
		
		if not element then
			continue -- if there is no key in the data, it's probably just a "safety-net"
		end
		
		if typeof(element) ~= schema then
			dispatch(meta, record, "OnDataFiltered", key)
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
		
		if not penetration then
			penetration = 1 -- default penetration
		end
		
		local element = find_element(data, key, penetration)
		if not element or typeof(element) ~= "number" then
			continue -- if there is no element that want to be clamped OR it's not a number
		end
		
		local filtered
		if min and not max then filtered = math.max(element, min)
		elseif not min and max then filtered = math.min(element, max)
		elseif min and max then filtered = math.clamp(element, min, max)
		else 
			filtered = element
		end
		
		local success = change_element(data, key, filtered, penetration)
		
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
		
		if not predicate then
			continue -- just pass, if there's no these elements in validator
		end
		
		if not penetration then
			penetration = 1 -- default penetration
		end
		
		local element = find_element(data, key, penetration)
		if not element then
			continue -- if there is no element that want to be validated
		end
		
		if not predicate(element) then
			dispatch(meta, record, "OnDataFiltered", key)
			return false -- if there is one data that is not valid or same as predicate, return false
		end
	end
	
	return true -- are valid if all data's validations matched
end

local function create_validation_class(meta : __UDCInfo_Internal, record : UDCRecord): UDCValidation
	local validations = {}
	
	local trackedPredicates = meta._TrackedValidations and meta._TrackedValidations[record.Key] or {}
	local trackedSchemas = meta._TrackedSchemas and meta._TrackedSchemas[record.Key] or {}
	local trackedClamps = meta._TrackedClamps and meta._TrackedClamps and meta._TrackedClamps[record.Key] or {}
	
	function validations:AddPredicate(ThisData: string | number, Predicate: (ThisValue: any) -> boolean, Penetration: number?)
		Penetration = Penetration or 1 -- default penetration
		
		trackedPredicates[ThisData] = {Predicate = Predicate, Penetration = Penetration}
	end
	
	function validations:RemovePredicate(ThisData: string | number, PenetrationIndex: number?)
		PenetrationIndex = PenetrationIndex or 1 -- default penetration
		
		trackedPredicates[ThisData] = nil
	end
	
	function validations:RemoveAllPredicates()
		trackedPredicates = {}
	end
	
	function validations:AddSchema(ThisData: string | number, Schema: string, Penetration: number?)
		Penetration = Penetration or 1 -- default penetration
		
		trackedSchemas[ThisData] = {Schema = Schema, Penetration = Penetration}
	end
	
	function validations:RemoveSchema(ThisData: string | number, PenetrationIndex: number?)
		PenetrationIndex = PenetrationIndex or 1 -- default penetration
		
		trackedSchemas[ThisData] = nil
	end
	
	function validations:RemoveAllSchemas()
		trackedSchemas = {}
	end
	
	function validations:AddClamp(ThisData: string | number, Min: number?, Max: number?, Penetration: number?)
		Penetration = Penetration or 1 -- default penetration
		
		trackedClamps[ThisData] = {Min = Min, Max = Max, Penetration = Penetration}
	end
	
	function validations:RemoveClamp(ThisData: string | number, PenetrationIndex: number?)
		PenetrationIndex = PenetrationIndex or 1 -- default penetration
		
		trackedClamps[ThisData] = nil
	end
	
	function validations:RemoveAllClamps()
		trackedClamps = {}		
	end
	
	meta._TrackedValidations[record.Key] = trackedPredicates
	meta._TrackedSchemas[record.Key] = trackedSchemas
	meta._TrackedClamps[record.Key] = trackedClamps
	
	return validations :: UDCValidation
end

local function create_event_class(meta : __UDCInfo_Internal, record : UDCRecord): UDCEvent
	local events = {}
	local listenerTypes = meta._UDataComponentDynamicCallbacks
	
	local function registerCallback(CallbackType: string, Callback: any)
		local listener = listenerTypes[CallbackType] or {}
		listener[record.Key] = listener[record.Key] or {}
		
		local id = HttpService:GenerateGUID(false)
		listener[record.Key][id] = Callback
		
		local connectors = {}
		local disconnected = false
		
		function connectors:Disconnect()
			if disconnected then return end
			disconnected = true
			
			listener[record.Key][id] = nil
		end
		
		function connectors:DisconnectAfterCalled()
			if disconnected then return end
			
			local original = Callback
			listener[record.Key][id] = function(...)
				local ok, err = pcall(original, ...)
				connectors:Disconnect()
				
				if not ok then
					error(err)
				end
			end
		end
		
		function connectors:IsConnected()
			return listener[record.Key] and listener[record.Key][id]
		end
		
		function connectors:Wait()
			if disconnected then return end
			
			local currentThread = coroutine.running()
			listener[record.Key][id] = function(...)
				local args = table.pack(...)
				
				local success, err = pcall(Callback, table.unpack(args, 1, args.n))
				task.spawn(currentThread, table.unpack(args, 1, args.n))
				
				if not success then
					error(err)
				end
			end
			
			return coroutine.yield()
		end
		
		return connectors :: UDCEventConnector
	end
	
	function events:OnReleased(Callback: (Key: string | number) -> any)
		return registerCallback("OnReleased", Callback)
	end
	
	function events:OnReady(Callback: (Key: string | number) -> any)
		return registerCallback("OnReady", Callback)
	end
	
	function events:OnSaved(Callback: (Key: string | number) -> any)
		return registerCallback("OnSaved", Callback)
	end
	
	function events:OnLoaded(Callback: (Key: string | number) -> any)
		return registerCallback("OnLoaded", Callback)
	end
	
	function events:OnStandby(Callback: (Key: string | number) -> any)
		return registerCallback("OnStandby", Callback)
	end
	
	function events:OnAutoSaved(Callback: (Key: string | number) -> any)
		return registerCallback("OnAutoSaved", Callback)
	end
	
	function events:OnArchived(Callback: (Key: string | number) -> any)
		return registerCallback("OnArchived", Callback)
	end
	
	function events:OnUnarchived(Callback: (Key: string | number) -> any)
		return registerCallback("OnUnarchived", Callback)
	end
	
	function events:OnWrite(Callback: (Key: string | number, OldData: any, NewData: any) -> any)
		return registerCallback("OnWrite", Callback)
	end
	
	function events:OnBroadcastSent(Callback: (Key: string | number) -> any)
		return registerCallback("OnBroadcastSent", Callback)
	end
	
	function events:OnBroadcastReceived(Callback: (Key: string | number, BroadcastPacket: UDCBroadcastingPacket) -> any)
		return registerCallback("OnBroadcastReceived", Callback)
	end
	
	function events:OnRecordBroadcastReceived(Callback: (Key: string | number, BroadcasterKey: string | number, BroadcastPacket: UDCBroadcastingPacket) -> any)
		return registerCallback("OnRecordBroadcastReceived", Callback)
	end
	
	function events:OnError(Callback: (Key: string | number, Error: string) -> any)
		return registerCallback("OnError", Callback)
	end
	
	function events:OnDataFiltered(Callback: (Key: string | number, FilteredData: any) -> any)
		return registerCallback("OnDataFiltered", Callback)
	end
	
	function events:OnOwnershipExpired(Callback: (Key: string | number) -> any)
		return registerCallback("OnOwnershipExpired", Callback)
	end
	
	return events :: UDCEvent
end

local function set_broadcast_record_subscriber(meta : __UDCInfo_Internal, recordName : string, globalName : string)
	if not meta.MessagingEnabled or meta._RecordBroadcastCalled then return end
	meta._RecordBroadcastCalled = true
	
	local recordBroadcastName = meta.MessagingNamespace .. "-" .. recordName
	local globalBroadcastName = meta.MessagingNamespace .. "-" .. globalName
	
	local recordBrSuccess, recordBrErr = pcall(function()
		return MessagingService:SubscribeAsync(recordBroadcastName, function(message)
			local rawData = message.Data
			if not rawData then return end
			
			local compressedData = rawData.__data
			local flag = rawData.__flag
			if not compressedData or not flag then return end
			
			local success, data = pcall(Compressor.TryToDecompress, compressedData, flag)
			if not success then return end
			
			if data and data.BroadcasterServerId == ServerId then 
				return 
			end
						
			local timestamp = data.BroadcastTime or 0
			local key = data.BroadcasterKey or 0
			local ownerId = data.BroadcasterOwnerId or 0
			
			local target = data.__target
			if target and target == key then return end
			
			local record = meta._ActiveRecords[target]		
			if not record then return end
			
			if workspace:GetServerTimeNow() - timestamp > meta.MessagingExpiration then 
				throw(meta, record, "Received broadcast packet is expired or invalid.")
				return 
			end
			
			local broadcasterData = data.BroadcasterData
			if not broadcasterData then 
				throw(meta, record, "Anonymous record data is missing.")
				return 
			end		
			
			local packet = deepfreeze({
				BroadcasterKey = key,
				BroadcasterData = broadcasterData,
				BroadcasterServerId = data.BroadcasterServerId,
				BroadcasterOwnerId = data.BroadcasterOwnerId,
				BroadcastTime = timestamp,
				OtherThings = data.OtherThings or {}
			})
			dispatch(meta, record, "OnRecordBroadcastReceived", key, packet)
		end)
	end)
	
	if not recordBrSuccess then
		warn("[UDataComponent-InternalErr]: " .. recordBrErr)
		return
	end
	
	local globalBrSuccess, globalBrErr = pcall(function()
		return MessagingService:SubscribeAsync(globalBroadcastName, function(message)
			local rawData = message.Data
			if not rawData then return end

			local compressedData = rawData.__data
			local flag = rawData.__flag
			if not compressedData or not flag then return end

			local success, data = pcall(Compressor.TryToDecompress, compressedData, flag)
			if not success then return end
			
			if data and data.BroadcasterServerId == ServerId then 
				return 
			end
			
			local timestamp = data.BroadcastTime or 0
			local key = data.BroadcasterKey or 0
			local ownerId = data.BroadcasterOwnerId or 0
			
			if workspace:GetServerTimeNow() - timestamp > meta.MessagingExpiration then return end
			
			local broadcasterData = data.BroadcasterData
			if not broadcasterData then return end
			
			local packet = deepfreeze({
				BroadcasterKey = key,
				BroadcasterData = broadcasterData,
				BroadcasterServerId = data.BroadcasterServerId,
				BroadcasterOwnerId = data.BroadcasterOwnerId,
				BroadcastTime = timestamp,
				OtherThings = data.OtherThings or {}
			})
			for _, record in pairs(meta._ActiveRecords) do
				dispatch(meta, record, "OnRecordBroadcastReceived", packet)
			end
		end)
	end)
	
	if not globalBrSuccess then
		warn("[UDataComponent-InternalErr]: " .. globalBrErr)
	end
end

local function create_broadcasting_class(meta : __UDCInfo_Internal, record : UDCRecord, recordBroadcastSuffix: string, globalBroadcastSuffix: string)
	local broadcasting = {}
	
	-- in UDC's Broadcasting, there are three types of broadcasting:
	-- 1. Global Broadcasting -- this is where current record broadcasting globally to all servers
	-- 2. Record Broadcasting -- this is where current record broadcasting to specific record from other server
	-- 3. Local Broadcasting -- this is where current record broadcasting to other servers that listening to the same channel
	
	local recordBroadcastName = meta.MessagingNamespace .. "-" .. recordBroadcastSuffix
	local globalBroadcastName = meta.MessagingNamespace .. "-" .. globalBroadcastSuffix
	
	function broadcasting:BroadcastCurrentData(OtherThings: any?)
		if not meta.MessagingEnabled then
			throw(meta, record, "Messaging is disabled.")
			return false
		end
		
		local data = meta._DataCache[record.Key]
		if not data then
			throw(meta, record, "Data is not loaded.")
			return false
		end
		
		local finishedData = deepclone(data.__data)
		
		local timestamp = workspace:GetServerTimeNow()
		local ownerId = record.Owner and record.Owner.UserId or 0
		local key = record.Key
		
		local packet = {
			BroadcasterKey = key,
			BroadcasterData = finishedData,
			BroadcasterServerId = ServerId,
			BroadcasterOwnerId = ownerId,
			BroadcastTime = timestamp,
			OtherThings = OtherThings or {}
		}
		
		local success, err = pcall(enqueue_broadcast, meta, record, globalBroadcastName, packet)
		
		return success
	end
	
	function broadcasting:WaitForBroadcastPacket(Timeout: number?) : UDCBroadcastingPacket
		Timeout = Timeout or 50
		local currentThread = coroutine.running()
		
		local connection
		local called = false
		
		local success, err = pcall(function()
			connection = MessagingService:SubscribeAsync(globalBroadcastName, function(message)
				if called then return end
				called = true
				
				local data = message.Data
				if not data then return end
				
				local flag = data.__flag
				local compressedData = data.__data
				if not compressedData or not flag then return end
				
				local success, data = pcall(Compressor.TryToDecompress, compressedData, flag)
				if not success then return end
				
				if data.BroadcasterServerId == ServerId then return end
				if workspace:GetServerTimeNow() - data.BroadcastTime > Timeout then return end
				
				local finishedData = deepclone(data)
				
				task.spawn(currentThread, finishedData)
				connection:Disconnect()
			end)
		end)
		
		if not success then
			throw(meta, record, "Error while waiting for broadcast packet: " .. err)
			return nil
		end
		
		local timeoutSpawn = task.delay(Timeout, function()
			if called then return end
			called = true

			if connection then connection:Disconnect() end
			task.spawn(currentThread, nil)
		end)
		
		local result = coroutine.yield()
		if timeoutSpawn then task.cancel(timeoutSpawn) end
		
		return result :: UDCBroadcastingPacket
	end
	
	function broadcasting:SendLocalBroadcast(ChannelName: string, OtherThings: any?)
		
	end
	
	function broadcasting:ListenToLocalBroadcast(ChannelName: string, Listener: (BroadcastPacket: UDCBroadcastingPacket) -> any)
		
	end
	
	function broadcasting:SendBroadcastToRecord(TargetKey: string | number, OtherThings: any?)
		if not meta.MessagingEnabled then
			throw(meta, record, "Messaging is disabled.")
			return false
		end
		
		local data = meta._DataCache[record.Key]
		if not data then
			throw(meta, record, "Data is not loaded.")
			return false
		end
		
		local finishedData = deepclone(data.__data)
		
		local timestamp = workspace:GetServerTimeNow()
		local ownerId = record.Owner and record.Owner.UserId or 0
		local key = record.Key
		
		local packet = {
			BroadcasterKey = key,
			BroadcasterData = finishedData,
			BroadcasterServerId = ServerId,
			BroadcasterOwnerId = ownerId,
			BroadcastTime = timestamp,
			OtherThings = OtherThings or {}
		}
		
		local success, err = pcall(enqueue_broadcast, meta, record, recordBroadcastName, packet, TargetKey)
		
		return success
	end
	
	return broadcasting
end

local function current_record(meta : __UDCInfo_Internal, key : number | string, owner : Player?)
	if meta._ActiveRecords[key] then
		return meta._ActiveRecords[key]
	end
	
	local recordBroadcastSuffix = "RecordBroadcast" -- broadcast suffix along with the namespace, where this is used for record broadcasting
	local globalBroadcastSuffix = "GlobalBroadcast" -- broadcast suffix along with the namespace, where this is used for global broadcasting
	
	local record = {}
	record.Key = key -- This is the key of the record
	record.Owner = owner -- This is the owner of the record
	record.IsArchived = false -- This is to indicate if the record is archived or not
	record.Event = create_event_class(meta, record) -- Utils of events for this record
	record.Validation = create_validation_class(meta, record) -- Utils to create validation for this record
	record.Swap = nil -- (COMING SOON!) Utils to swap data with other record
	record.Broadcasting = create_broadcasting_class(meta, record, recordBroadcastSuffix, globalBroadcastSuffix) -- Utils to Broadcasting to other servers
	record.Version = 0 -- This is the version of the data, it will be increased when the data is saved
	record.Data = nil -- This is the data of the record
	record.CurrentState = "Asleep"
	
	record._AwakeProgress = false -- This is to indicate if the record's awake in progress
	record._ReadyProgress = false -- This is to indicate if the record's ready in progress
	record._SleepProgress = false -- This is to indicate if the record's sleep in progress
	record._SaveProgress = false -- This is to indicate if the record's save in progress, where Save and Write shares this variable	
	-- Because Write and Save are same, but have different roles in record commiting
	record._ArchivingProgress = false -- This is to indicate if the record's archiving in progress
	record._UnarchivingProgress = false -- This is to indicate if the record's unarchiving in progress
	record._CurrentlyStandby = false -- This is to indicate if the record is currently in standby mode
	
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
		if meta._UnreadyData[record.Key] then
			throw(meta, record, "Record is already awoken, it seems you're trying to awake the record twice. Just call Ready() instead to make the record ready to be used.")
			return false
		end
		
		if meta._AwakeProgress then
			throw(meta, record, "Record is in progress to awake...")
			return false
		end
		
		if record.CurrentState ~= "Asleep" and record.CurrentState ~= "Sleeping" then
			throw(meta, record, "Record is not in Asleep or Sleeping state, it seems you're trying to awake the record when it's already at different state.")
			return false
		end
		meta._AwakeProgress = true
				
		local success, result = enqueue_load(meta, record)
		local overallResult = false
				
		if success and result then
			record.CurrentState = "WakingUp"
			meta._UnreadyData[record.Key] = result
			
			dispatch(meta, record, "OnLoaded")
			
			overallResult = true
		else 
			record.CurrentState = "Sleeping"
			meta._UnreadyData[record.Key] = nil
			
			throw(meta, record, "Failed to awake the record.")
			
			overallResult = false
		end
		meta._AwakeProgress = false
		
		return overallResult
	end
	
	-- After the data record is awake, we need to make the data is actually ready to be used
	-- I made the data compressed into buffer to reduce the size of data
	-- Here we are, Ready() called to make a hard-checking and evaluating every security and data details
	-- Then the data will be decompressed and record.Data can be accessed to get the read data
	-- SUSPENDING (YIELDABLE), where Ready yields for checking every details until its done checking and applied to cache
	function record:Ready(FindingPlayerTimeout: number?)
		FindingPlayerTimeout = FindingPlayerTimeout or 10
		
		local function penalty(msg)
			record._ReadyProgress = false
			
			record.CurrentState = "Sleeping"
			meta._UnreadyData[record.Key] = nil
			
			throw(meta, record, msg)
		end
		
		if not UDataComponent.IsAlive() then
			throw(meta, record, "UDataComponent is not alive.")
			return false
		end
				
		if meta._ShutdownCalled then
			throw(meta, record, "The server is progress to shutdown.")
			return false
		end
				
		if not meta.Enabled or not UDataComponent.Enabled then
			throw(meta, record, "UDataComponent is not enabled.")
			return false
		end
						
		-- Whether the data is already waking up or not, if not, maybe cannot ready or already running
		if record.CurrentState ~= "WakingUp" then
			throw(meta, record, "Record is current in Ready state, meaning the record has been loaded. You can't call Ready() twice or more.")
			return false
		end
						
		if record._ReadyProgress then
			throw(meta, record, "Record is already in progress to ready...")
			return false
		end
						
		record._ReadyProgress = true
		
		if meta._DataCache[record.Key] ~= nil then
			throw(meta, record, "Record is already ready.")
			record.CurrentState = "Sleeping"
			return false
		end
				
		local now = workspace:GetServerTimeNow()
		local unready = meta._UnreadyData[record.Key]
		
		-- Checking if the raw/unready data already loaded
		if not unready then
			record._ReadyProgress = false
			record.CurrentState = "Sleeping"
			throw(meta, record, "Record is not waking up yet, make sure this record has called Awake() before preparing to get ready.")
			return false
		end		
		
		if meta._ActiveRecords[record.Key] then
			penalty("Record is already active and ready.")
			return false
		end
						
		-- Checking if the was archived or not
		if record.IsArchived then
			penalty("Record is being archived in this session.")
			return false
		end
						
		-- Checking if essential elements of data are existing
		if not unready.__version or not unready.__bounds or not unready.__data or not unready.__flag then
			penalty("Missing record's elements, internal error.")
			return false
		end
						
		-- Checking if bound elements in the data are existed
		if not unready.__bounds or not unready.__bounds.id or not unready.__bounds.since or not unready.__bounds.serverid then
			penalty("Missing bounds, internal error.")
			return false
		end
								
		-- Checking if the data is owned by this server
		if unready.__bounds.serverid ~= ServerId then
			penalty("This record is not being owned by this server, unable to get ready.")
			return false
		end
						
		-- Checking if the data is owned by this player
		if record.Owner and record.Owner.UserId ~= unready.__bounds.id then
			penalty("This record is not belong to current owner, unable to get ready.")
			return false
		end
						
		-- Checking if the data is still bound to this player
		local timeout = 60 * 60 * 24 * (meta.OwnershipExpiration or 1)
		if now - unready.__bounds.since > timeout then
			penalty("Record binding is already expired for this owner, you should refresh the ownership expiration of this record.")
			dispatch(meta, record, "OnOwnershipExpired")
			return false
		end
										
		-- Checking if player is still in the server
		local playerFound = false
		while record.Owner and not playerFound do
			-- If the player is still in the server, then it's ready
			if Players:GetPlayerByUserId(record.Owner.UserId) ~= nil then
				playerFound = true
				-- If timeout is set, then it's not ready yet
			elseif workspace:GetServerTimeNow() - now > FindingPlayerTimeout then
				penalty("This record is not ready, the player is not found from this server.")
				return false
			else
				task.wait(1)
			end
		end
						
		local compressedData = unready.__data
		local flagData = unready.__flag -- 'C' means compressed, 'R' means raw/real
		
		local success, data = pcall(function()
			return Compressor.TryToDecompress(compressedData, flagData)
		end)
		
		-- Checking if the data is successfully decompressed
		if not success then
			warn(data)
			penalty("This record is not ready, the data is corrupted.")
			return false
		end
								
		-- Checking if the data is a table
		if typeof(data) ~= "table" then
			penalty("The data is not a table.")
			return false
		end
						
		-- Checking if the data size is not too big
		if Compressor.GetSize(data) > meta.MaxDecompressedSize then
			penalty("Data's size of this record is full.")
			return false
		end
						
		-- Reconcilate the data with the blueprint, to prevent data corruption or data loss
		reconcile(data, meta.DataBlueprint)
		
		-- Checking if all datas are valid, even one invalid will case unready condition for strict checking
		if not are_schemas_valid(meta, record, data) then
			penalty("The data is not valid after validation. Because a data is not having valid data-type.")
			return false
		end
						
		-- Clamping all values with the validations, if the element was a number type
		clamp_values(meta, record, data)
		
		-- Checking if datas are actually same as their own predicates
		if not are_datas_valid(meta, record, data) then
			penalty("The data is not valid after validation. Because a data is not valid to operate in a predicate.")
			return false
		end
				
		-- Apply the data to the cache
		record.Data = deepfreeze(data) -- Data is now ready to be used, as read-only table
		record.CurrentState = "Ready" -- Current state is ready to do things
		record.Version = meta._UnreadyData[record.Key].__version or 0 -- Set the version of this record to real data version
		
		meta._UnreadyData[record.Key] = nil -- Remove the unready data, because the data is ready
		
		meta._DataCache[record.Key] = unready -- Catch the record after filter
		meta._DataCache[record.Key].__data = data  -- Cache the real data after compression
		
		meta._ActiveRecords[record.Key] = record -- Add the record to active records, so developer can access the record
		
		push_to_autosave(meta, record)
		set_broadcast_record_subscriber(meta, recordBroadcastSuffix, globalBroadcastSuffix) -- first time Ready initialized, broadcast subscriber will be set
		
		record._ReadyProgress = false
		
		dispatch(meta, record, "OnReady")
		
		return true
	end
	
	function record:Standby()
		if not meta.Enabled or not UDataComponent.Enabled then
			throw(meta, record, "UDataComponent is disabled.")
			return false
		end
		
		if record.CurrentState ~= "Ready" then
			throw(meta, record, "This record is not ready to standby.")
			return false
		end
		
		if record._CurrentlyStandby then
			throw(meta, record, "This record is already in standby.")
			return false
		end
		
		if record._ReadyProgress then
			throw(meta, record, "This record is in ready progress, unable to override current record's state process.")
			return false
		end
		
		if record._SleepProgress then
			throw(meta, record, "This record is in sleep progress, unable to override current record's state process.")
			return false
		end
		
		if record._SaveProgress then
			throw(meta, record, "This record is in save progress, unable to override current record's state process.")
			return false
		end
		
		if meta._DataCache[record.Key] == nil then
			throw(meta, record, "It seems the record hadn't been loaded yet, unable to standby.")
			return false
		end
		
		local success = add_standby_record(meta, record)
		
		if success then
			dispatch(meta, record, "OnStandby")
		end
		
		return success
	end
	
	-- Releasing the data from session, where this means this record has been fell asleep and cannot use the data anymore, unless you call Awake() to wake it up again
	function record:Sleep()
		if not meta.Enabled or not UDataComponent.Enabled then
			throw(meta, record, "UDataComponent is not enabled.")
			return false
		end
		
		while record.CurrentState == "Running" do
			task.wait()
		end
		
		if record._ReadyProgress then
			throw(meta, record, "This record is in ready progress, unable to override current record's state process.")
			return false
		end
		
		if record._SaveProgress then
			throw(meta, record, "This record is in save progress, unable to override current record's state process.")
			return false
		end
		
		if record._SleepProgress then
			throw(meta, record, "This record is in sleep progress, unable to override current record's state process.")
			return false
		end
		
		record._SleepProgress = true
		
		if record.CurrentState ~= "Ready" then
			record._SleepProgress = false
			throw(meta, record, "This record is currently not ready, unable to get sleep once.")
			return false
		end

		local now = workspace:GetServerTimeNow()
		local dataCache = meta._DataCache[record.Key]
		if not dataCache or not dataCache.__bounds then
			record._SleepProgress = false
			throw(meta, record, "It seems this record hadn't been loaded yet, please load to sleep.")
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
						CurrentData.__bounds.since = now
					end
					
					return CurrentData
				end
				
				return nil
			end)
		end)
		
		record._SleepProgress = false
		if success and result then
			meta._ActiveRecords[record.Key] = nil
			meta._DataCache[record.Key] = nil
			meta._WriteTimestamp[record.Key] = nil
			meta._SwapTimestamp[record.Key] = nil
			meta._AutosaveTimestamp[record.Key] = nil
			meta._CompressionStack[record.Key] = nil
			meta._LocalBroadcastListeners[record.Key] = nil
			meta._DirtySave[record.Key] = nil

			meta._TrackedClamps[record.Key] = nil
			meta._TrackedSchemas[record.Key] = nil
			meta._TrackedValidations[record.Key] = nil

			record.Data = nil
			record.Owner = nil
			record.Version = 0
			record.CurrentState = "Asleep"	
			
			local find = find_standby_index(meta, record.Key)
			if find then
				table.remove(meta._StandbyRegistry, find)
			end
			
			dispatch(meta, record, "OnReleased")
			return true
		end
		
		throw(meta, record, "Failed to release the record.")
		return false
	end
	
	-- Trying to steal or enter into this record by another owner
	-- Password makes sure that the stealer owner is actually trying to have current record from the current owner
	-- IMPORANT: This function will not work if the record is not ready, also this function would cause you a DEAD SESSION if not released with Sleep() or automatic trigger by Standby() after use the record
	-- Original owner will lost its record if the record have been successfully entered/stolen by another owner
	function record:COMINGSOON_Enter(Password: string) -- COMING SOON
		
	end
	
	function record:COMINGSOON_GenerateLogin(ThisRecordPassword: string) -- COMING SOON
		
	end
	
	function record:COMINGSOON_DestroyLogin(Password: string) -- COMING SOON
		
	end
	
	-- Saving the custom data or edited-whole data into record, as waiting for its queue turn
	-- Use SegmentIndex if you ever want to make cheaper data to save
	-----------------------------------------------------------------------------------
	-- Just remember, Save() didn't check the validations of the data before commit
	-- We know that with Ready(), everything will be validated before the record state checked to ready, and you can't trigger fast-compression to compress the data when modifying the data
	-- But, don't you think that you can make a "safety-first" with Write() that validates the data before commited to the data store?
	-- Because, when you tried to load and ready, but some datas are not valid, you can't obtain it
	-- So, I would recommend you to use Write() when your data wants more secure, particularly to validates the data first before commit
	-- Use Save() for manual control, but beware of what you did
	function record:Save(Data: any, SegmentIndex: number?)
		if not meta.Enabled or not UDataComponent.Enabled then
			throw(meta, record, "UDataComponent is not enabled")
			return false
		end
		
		while record._SaveProgress do
			task.wait()
		end
		record._SaveProgress = true
				
		if record._SleepProgress then
			throw(meta, record, "This record is in sleep progress, unable to override current record's state process.")
			record._SaveProgress = false
			return false
		end
				
		if record._ReadyProgress then
			throw(meta, record, "This record is in ready progress, unable to override current record's state process.")
			record._SaveProgress = false
			return false
		end
				
		if record.CurrentState ~= "Ready" then
			throw(meta, record, "This record is currently not ready or prepared to do Save() operations. Please call Ready()")
			record._SaveProgress = false
			return false
		end
				
		local data = meta._DataCache[record.Key]
		if not data or not data.__data then
			throw(meta, record, "The data of this record is not loaded.")
			record._SaveProgress = false
			return false
		end
		
		if Data == nil then
			throw(meta, record, "Data parameter in Save() is nil")
			record._SaveProgress = false
			return false
		end
		
		local oldData = deepclone(data.__data)
		local newData
		
		meta._LockSessions:Do(record.Key, function()
			if SegmentIndex then
				data.__data[SegmentIndex] = Data
			else
				data.__data = Data
			end		
			
			newData = deepclone(data.__data)			
			record.Data = deepfreeze(data.__data)
			meta._DirtySave[record.Key] = true
		end)
		push_compression_timer(meta, record)
		
		local success = enqueue_save(meta, record)
		
		record._SaveProgress = false
		if success then
			dispatch(meta, record, "OnWrite", oldData, newData)
			return true
		end
		
		throw(meta, record, "Failed to push data to save in this record.")
		return false
	end
	
	-- Easy, safe way to modificate the data of this record
	-- Where Write() allows you to modificate the data safely with validation checking and compression operations
	function record:Write(WritingFunction: (CurrentData: any) -> ())
		if not meta.Enabled or not UDataComponent.Enabled then
			throw(meta, record, "UDataComponent is not enabled")
			return false
		end
		
		local now = workspace:GetServerTimeNow()
		if meta._WriteTimestamp[record.Key] and now - meta._WriteTimestamp[record.Key] < meta.DataWritingCooldown then
			-- dont give warning in this session
			-- this is just a safety step
			return false
		end
		meta._WriteTimestamp[record.Key] = now

		while record._SaveProgress do
			task.wait()
		end
		record._SaveProgress = true
		
		if record._SleepProgress then
			throw(meta, record, "This record is in sleep progress, unable to override current record's state process.")
			record._SaveProgress = false
			return false
		end
		
		if record._ReadyProgress then
			throw(meta, record, "This record is in ready progress, unable to override current record's state process.")
			record._SaveProgress = false
			return false
		end
		
		if record.CurrentState ~= "Ready" then
			throw(meta, record, "This record is currently not ready or prepared to do Write() operations. Please call Ready()")
			record._SaveProgress = false
			return false
		end
		
		local data = meta._DataCache[record.Key]
		if not data or not data.__data then
			throw(meta, record, "Data of this record is not loaded yet.")
			record._SaveProgress = false
			return false
		end
		
		local success 
		local customData = deepclone(data.__data) -- use deep-cloned table, so that the main data can't be changed, to prevent some "malicious" or "accident" data modifications
		local oldData = deepclone(data.__data)
		local newData
		meta._LockSessions:Do(record.Key, function()
			success = pcall(WritingFunction, customData) -- this function returns nothing, but change the data safely
			
			if not success then
				return
			end

			-- schema validations, when data types are valid
			if not are_schemas_valid(meta, record, customData) then
				success = false
				return
			end

			-- clamp values that is a number
			clamp_values(meta, record, customData)

			-- predicate validations, this is where your data "must operate in this case"
			if not are_datas_valid(meta, record, customData) then
				success = false
				return
			end

			data.__data = customData
			newData = deepclone(customData)
			record.Data = deepfreeze(customData)
			
			meta._DirtySave[record.Key] = true
		end)
		
		if not success then
			throw(meta, record, "Something error happened when writing data.")
			record._SaveProgress = false
			return false
		end
		
		push_compression_timer(meta, record)
		
		local success = enqueue_save(meta, record)
		
		record._SaveProgress = false
		if success then
			dispatch(meta, record, "OnWrite", oldData, newData)
			return true
		end
		
		return false
	end
	
	-- Same as Save() but the data is commiting explicitly into datastore
	-- Use it for immediate saving operations, ex. Player Leaving or Manual Trading
	-- However, Standby() has given you a service for saving data automatically, with this ForceSave()
	-- But you can use it anyway, the explicit data commiting is still in Mutex lock to prevent race conditions
	function record:ForceSave(Data: any, SegmentIndex: number?)
		if not meta.Enabled or not UDataComponent.Enabled then
			throw(meta, record, "UDataComponent is not enabled.")
			return false
		end
		
		while record.CurrentState == "Running" do
			task.wait()
		end
		
		local now = workspace:GetServerTimeNow()
		while record._SaveProgress do
			task.wait()
		end
		record._SaveProgress = true

		if record._SleepProgress then
			throw(meta, record, "This record is in sleep progress, unable to override current record's state process.")
			record._SaveProgress = false
			return false
		end

		if record._ReadyProgress then
			throw(meta, record, "This record is in ready progress, unable to override current record's state process.")
			record._SaveProgress = false
			return false
		end

		if record.CurrentState ~= "Ready" then
			throw(meta, record, "This record is currently not ready or prepared to do ForceSave() operations. Please call Ready()")
			record._SaveProgress = false
			return false
		end

		local data = meta._DataCache[record.Key]
		if not data or not data.__data then
			throw(meta, record, "Data of this record is not loaded yet.")
			record._SaveProgress = false
			return false
		end
		
		if Data == nil then
			throw(meta, record, "Data parameter in ForceSave() is nil")
			record._SaveProgress = false
			return false
		end
		record.CurrentState = "Running"
		
		local thisOwnerId = record.Owner and record.Owner.UserId or 0
		
		local oldData = deepclone(data.__data)
		local newData
		
		local isSuccess = false
		meta._LockSessions:Do(record.Key, function()			
			if SegmentIndex then
				data.__data[SegmentIndex] = Data
			else
				data.__data = Data
			end		
			
			local clonedRecord = deepclone(data)
			
			newData = deepclone(data.__data)
			record.Data = deepfreeze(data.__data)
						
			local compressed, flag
			local found = false

			local existed = meta._CompressionStack[record.Key]

			if existed then
				if not existed.Dirty and record._LastCompressedData and record._LastFlagData then
					compressed, flag = record._LastCompressedData, record._LastFlagData
				else
					local ok, newCompressed, newFlag = pcall(compare_and_compress, meta, clonedRecord.__data)

					if not ok then 
						throw(meta, record, "Failed to compare and compress the data in record.")
						return false 
					end

					compressed, flag = newCompressed, newFlag

					record._LastCompressedData = compressed
					record._LastFlagData = flag

					existed.Tick = now
					existed.Dirty = false
				end
			else
				local ok, newCompressed, newFlag = pcall(compare_and_compress, meta, clonedRecord.__data)
				if not ok then 
					throw(meta, record, "Failed to compare and compress the data in record.")
					return false 
				end

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
						
						local isDifferentServer = serverid and serverid ~= ServerId and not isStale
						local isDifferentOwner = id and id ~= thisOwnerId
						
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
					
					if clonedRecord.__version and CurrentData and clonedRecord.__version > (CurrentData.__version or 0) then
						CurrentData = clonedRecord
					end
					
					CurrentData.__data = compressed
					CurrentData.__bounds.lastheartbeat = now
					CurrentData.__bounds.since = now
					return CurrentData
				end)
			end)
			
			isSuccess = success and result
		end)
		
		record._SaveProgress = false
		record.CurrentState = "Ready"
		if isSuccess then
			local walSuccess, result = pcall(function() return meta._CurrentWALDataStore:GetAsync(record.Key) end)
			
			if walSuccess and result then
				pcall(function() meta._CurrentWALDataStore:RemoveAsync(record.Key) end)
			end
			
			local index = 0
			for i, pending in ipairs(meta._SavePendingQueue) do
				if pending.Meta and pending.Meta.Key == record.Key then
					index = i
					break
				end
			end
			
			if index then
				table.remove(meta._SavePendingQueue, index)
			end
			
			local dirty = meta._DirtySave[record.Key]
			if dirty then
				meta._DirtySave[record.Key] = nil
			end
			
			dispatch(meta, record, "OnWrite", oldData, newData)
			
			return true
		end
		
		throw(meta, record, "Failed to force save the data in record.")
		return false
	end
	
	function record:ForceWrite(WritingFunction: (CurrentData: any) -> ())
		if not meta.Enabled or not UDataComponent.Enabled then
			throw(meta, record, "UDataComponent is not enabled.")
			return false
		end
		
		while record.CurrentState == "Running" do
			task.wait()
		end
		 
		local now = workspace:GetServerTimeNow()
		if record.CurrentState ~= "Ready" then
			throw(meta, record, "This record is currently not ready or prepared to do ForceWrite() operations. Please call Ready()")
			return false
		end
		
		while record._SaveProgress do
			task.wait()
		end
		record._SaveProgress = true
		
		if record._ReadyProgress then
			throw(meta, record, "This record is in ready progress, unable to override current record's state process.")
			record._SaveProgress = false
			return false
		end
		
		if record._SleepProgress then
			throw(meta, record, "This record is in sleep progress, unable to override current record's state process.")
			record._SaveProgress = false
			return false
		end
		
		local data = meta._DataCache[record.Key]
		if not data or not data.__data then
			throw(meta, record, "Data of this record is not loaded yet.")
			record._SaveProgress = false
			return false
		end
		record.CurrentState = "Running"
		
		local thisOwnerId = record.Owner and record.Owner.UserId or 0
		
		local clonedRecord = deepclone(data)
		local clonedData = deepclone(clonedRecord.__data)
		
		local oldData = deepclone(data.__data)
		local newData
		
		local isSuccess = false
		meta._LockSessions:Do(record.Key, function()
			local success = pcall(WritingFunction, clonedData)

			if not success then
				throw(meta, record, "Failed to write the data in record.")
				return false
			end

			if not are_schemas_valid(meta, record, clonedData) then
				return false
			end

			clamp_values(meta, record, clonedData)

			if not are_datas_valid(meta, record, clonedData) then
				return false
			end
			
			data.__data = clonedData
			newData = deepclone(clonedData)
			record.Data = deepfreeze(clonedData)
			
			local compressed, flag
			local found = false

			local existed = meta._CompressionStack[record.Key]

			if existed then
				if not existed.Dirty and record._LastCompressedData and record._LastFlagData then
					compressed, flag = record._LastCompressedData, record._LastFlagData
				else
					local ok, newCompressed, newFlag = pcall(compare_and_compress, meta, clonedData)

					if not ok then 
						throw(meta, record, "Failed to compare and compress the data in record.")
						return false 
					end

					compressed, flag = newCompressed, newFlag

					record._LastCompressedData = compressed
					record._LastFlagData = flag

					existed.Tick = now
					existed.Dirty = false
				end
			else
				local ok, newCompressed, newFlag = pcall(compare_and_compress, meta, clonedData)
				if not ok then 
					throw(meta, record, "Failed to compare and compress the data in record.")
					return false 
				end

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

					if clonedRecord.__version and CurrentData and clonedRecord.__version > (CurrentData.__version or 0) then
						CurrentData = clonedRecord
					end

					CurrentData.__data = compressed
					CurrentData.__bounds.lastheartbeat = now
					CurrentData.__bounds.since = now
					return CurrentData
				end)
			end)
			
			isSuccess = success and result
		end)
		
		record._SaveProgress = false
		record.CurrentState = "Ready"
		
		if isSuccess then
			local walSuccess, result = pcall(function() return meta._CurrentWALDataStore:GetAsync(record.Key) end)

			if walSuccess and result then
				pcall(function() meta._CurrentWALDataStore:RemoveAsync(record.Key) end)
			end
			
			local index = 0
			for i, pending in ipairs(meta._SavePendingQueue) do
				if pending.Meta and pending.Meta.Key == record.Key then
					index = i
					break
				end
			end
			
			if index then
				table.remove(meta._SavePendingQueue, index)
			end
			
			local dirty = meta._DirtySave[record.Key]
			if dirty then
				meta._DirtySave[record.Key] = nil
			end
			
			dispatch(meta, record, "OnWrite", oldData, newData)
			return true
		end
		
		throw(meta, record, "Failed to write the data of record.")
		return false
	end
	
	-- Removing the record of this player
	-- Where after this function called, nothing in the record could be used, because have been garbaged
	-- Meanwhile, the record isn't actually destroy, instead it's archived
	-- Whether you want to get the record back, you can use Unarchive() where recovering the archived record back into the player
	-- But, in one condition, this function is actually destructive and dangerous. Make sure you're always thinking about what will happened when a record is archived
	-- 
	function record:Detach()
		if not meta.Enabled or not UDataComponent.Enabled then
			throw(meta, record, "UDataComponent is not enabled.")
			return false
		end
		
		while record.CurrentState == "Running" do
			task.wait()
		end
		
		local now = workspace:GetServerTimeNow()
		if not meta.ArchivationEnabled then
			throw(meta, record, "Archivation is not enabled.")
			return false
		end
		
		if meta.StrictlyUnallowDetaching then
			throw(meta, record, "Detaching is not allowed in this mode.")
			return false
		end
		
		if record.CurrentState ~= "Ready" then
			throw(meta, record, "This record is currently not ready or prepared to do Detach() operations. Please call Ready()")
			return false
		end
		
		if record.CurrentState == "Died" then
			throw(meta, record, "This record is currently died. You can't do any operations on this record.")
			return false
		end
		
		if record._ReadyProgress then
			throw(meta, record, "This record is in ready progress, unable to override current record's state process.")
			return false
		end
		
		if record._SaveProgress then
			throw(meta, record, "This record is in save progress, unable to override current record's state process.")
			return false
		end
		
		if record._ArchivingProgress then
			throw(meta, record, "This record is in archiving progress, unable to override current record's state process.")
			return false
		end
		record._ArchivingProgress = true
		
		local data = meta._DataCache[record.Key]
		if not data then
			throw(meta, record, "This record is not loaded yet.")
			record._ArchivingProgress = false
			return false
		end
		
		for i, pending in ipairs(meta._SavePendingQueue) do
			if pending.Meta and pending.Meta.Key == record.Key then
				table.remove(meta._SavePendingQueue, i)
				break
			end
		end
		
		local success, result = pcall(function()
			return meta._CurrentDataStore:RemoveAsync(record.Key)
		end)
		
		if not success then
			throw(meta, record, "Failed to remove data from data store. " .. tostring(result))
			record._ArchivingProgress = false
			return false
		end
		
		local thisOwnerId = record.Owner and record.Owner.UserId or 0
		
		meta._ActiveRecords[record.Key] = nil
		meta._DataCache[record.Key] = nil
		meta._WriteTimestamp[record.Key] = nil
		meta._SwapTimestamp[record.Key] = nil
		meta._AutosaveTimestamp[record.Key] = nil
		meta._CompressionStack[record.Key] = nil
		meta._LocalBroadcastListeners[record.Key] = nil
		meta._DirtySave[record.Key] = nil

		meta._TrackedClamps[record.Key] = nil
		meta._TrackedSchemas[record.Key] = nil
		meta._TrackedValidations[record.Key] = nil

		record.Data = nil
		record.Owner = nil
		record.Version = 0
		record.CurrentState = "Died"		
		
		if meta.ArchivationEnabled and success and result then
			local isArchived = false

			while not isArchived do
				local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)

				if budget > 0 then
					local archSuccess, archResult = pcall(function()
						return meta._CurrentArchivedDataStore:UpdateAsync(record.Key, function(CurrentData)
							if CurrentData and CurrentData.__bounds and CurrentData.__bounds.serverid and CurrentData.__bounds.id and CurrentData.__bounds.lastheartbeat then
								local bounds = CurrentData.__bounds
								local id = CurrentData.__bounds.id
								local serverid = CurrentData.__bounds.serverid
								local lastheartbeat = CurrentData.__bounds.lastheartbeat or 0

								local isStale = now - lastheartbeat > meta.StaleServerClaimingTime
								local isCacheStale = now - (result.__bounds and result.__bounds.lastheartbeat or 0) > meta.StaleServerClaimingTime

								local isDifferentServer = serverid and serverid ~= ServerId and not isStale
								local isDifferentOwner = id and id ~= thisOwnerId
								
								local isCacheServerDifferent = result.__bounds and result.__bounds.serverid and result.__bounds.serverid ~= serverid and result.__bounds.serverid ~= ServerId and not isCacheStale
								local isCacheDifferentOwner = result.__bounds and result.__bounds.id and result.__bounds.id ~= id and result.__bounds.id ~= thisOwnerId
								
								if isDifferentOwner or isDifferentServer or isCacheServerDifferent or isCacheDifferentOwner then
									return nil
								end
							end
							
							CurrentData = result
							CurrentData.__bounds = {
								id = thisOwnerId,
								since = now,
							}
							return CurrentData
						end)
					end)
					
					if archSuccess and archResult then
						isArchived = true
						record.IsArchived = true
						record._ArchivingProgress = false

						local find = find_standby_index(meta, record.Key)
						if find then
							table.remove(meta._StandbyRegistry, find)
						end
						
						dispatch(meta, record, "OnArchived")
						return true
					end
				end
				
				task.wait()
			end
		end
		record._ArchivingProgress = false
		throw(meta, record, "Fatal error while trying to archive the record.")

		return false
	end
	
	function record:Unarchive()
		if not meta.Enabled or not UDataComponent.Enabled then
			throw(meta, record, "UDataComponent is not enabled.")
			return false
		end
		
		local now = workspace:GetServerTimeNow()
		if not meta.ArchivationEnabled then
			throw(meta, record, "Archivation is not enabled.")
			return false
		end
		
		if record.CurrentState ~= "Asleep" and record.CurrentState ~= "Died" then
			throw(meta, record, "Record is not currently asleep or died.")
			return false
		end
		
		if record._ReadyProgress then
			throw(meta, record, "This record is in ready progress, unable to override current record's state process.")
			return false
		end

		if record._SaveProgress then
			throw(meta, record, "This record is in save progress, unable to override current record's state process.")
			return false
		end

		if record._ArchivingProgress then
			throw(meta, record, "This record is in archiving progress, unable to override current record's state process.")
			return false
		end
		
		if record._UnarchivingProgress then
			throw(meta, record, "This record is in unarchiving progress, unable to override current record's state process.")
			return false
		end
		record._UnarchivingProgress = true
		
		local success, unarchivedData = pcall(function()
			return meta._CurrentArchivedDataStore:GetAsync(record.Key)
		end)
		
		if not success then
			throw(meta, record, "Failed to get archived record from data store. " .. tostring(unarchivedData))
			record._UnarchivingProgress = false
			return false
		end
		
		local thisOwnerId = record.Owner and record.Owner.UserId or 0
		if success and unarchivedData then
			while meta.Enabled and UDataComponent.Enabled do
				local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
				
				if budget > 0 then
					local unarchSuccess, unarchResult = pcall(function()
						return meta._CurrentDataStore:UpdateAsync(record.Key, function(CurrentData)
							if CurrentData and CurrentData.__bounds and CurrentData.__bounds.id and unarchivedData.__bounds and unarchivedData.__bounds.id then
								local id = CurrentData.__bounds.id
								local archiveId = unarchivedData.__bounds.id
								
								if id ~= archiveId or id ~= thisOwnerId or archiveId ~= thisOwnerId then
									return nil
								end
							end
							
							CurrentData = unarchivedData
							
							CurrentData.__bounds = {
								id = CurrentData.__bounds and CurrentData.__bounds.id or thisOwnerId,
								since = CurrentData.__bounds and CurrentData.__bounds.since or now,
							}
							return CurrentData
						end)
					end)
					
					if unarchSuccess and unarchResult then
						record._UnarchivingProgress = false
						
						record.CurrentState = "Asleep"
						record.IsArchived = false
						
						pcall(function()
							meta._CurrentArchivedDataStore:RemoveAsync(record.Key)
						end)
						
						dispatch(meta, record, "OnUnarchived")
						return true
					end
				end
				
				task.wait()
			end
		end
		record._UnarchivingProgress = false
		throw(meta, record, "Failed to unarchive data.")
		
		return false
	end
	
	function record:IsRecorded()
		return meta._ActiveRecords[record.Key] ~= nil and record.Data ~= nil and meta._DataCache[record.Key] ~= nil
	end
	
	return record	
end

function UDataComponent.InDataInfo(DataStoreName: string, Scope: string?, Configurations: { [string]: any?}) : UDCInfo
	Scope = Scope or "global"
	Configurations = Configurations or {}
	
	local storageKey = DataStoreName .. "-" .. Scope
	if InfosStorage[storageKey] then
		return InfosStorage[storageKey]
	end
	
	local self = setmetatable({}, UDataComponent)
	
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
	self.MessagingExpiration = 10 -- 10 seconds
	self.MessagingMaxPacketSize = 900 -- 900 bytes
	self.MessagingSendingCooldown = 5
	self.MessagingReceivingCooldown = 5
	self.MessagingLocalListeningCooldown = 5
	self.ArchivationEnabled = true
	self.ArchivationSuffix = "_archived"
	self.MaxDataSavingPerTick = 4
	self.MaxDataObtainingPerTick = 4
	self.MaxConcurrentSaveWorkers = 5
	self.MaxConcurrentLoadWorkers = 5
	self.MaxConcurrentAutosaveWorkers = 5
	self.MaxStandbyWorkers = 10
	self.StaleServerClaimingTime = 90
	self.ShutdownSecondsToken = 25
	
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
	self._SavePendingQueue = {} -- { {Meta: UDCRecord, Thread: thread} }
	self._ObtainPendingQueue = {} -- { {Meta: UDCRecord, Thread: thread} }
	self._BroadcastPendingQueue = {} -- { [Key] = { Packet: any, HasTarget: boolean }
	self._UnreadyData = {} -- { [Key: string] = true }
	self._DataCache = {} -- { [Key: string] = Data: any }
	self._CompressionStack = {} -- { [Key: string] = {Record: UDCRecord, Tick: number} }
	self._StandbyRegistry = {} -- { {Record, Key} }
	self._DirtySave = {} -- { [Key: string] = true }
	self._LockSessions = ScopedMutex.new(Mutex)
	self._BroadcastingTimestamps = {} -- { [Key: string] = timestamp: number }
	self._LocalBroadcastListeners = {} -- { [Key: string] = { [ListenerId: string] = Listener: function } }

	self._ShutdownCalled = false
	self._ExclusiveSafetyCalled = false
	self._IsSaveRunning = false
	self._IsObtainingRunning = false
	self._IsCompressionTimerRunning = false
	self._CacheCleaningCalled = false
	self._StandbyReady = false
	self._AutosaveCalled = false
	self._RecordBroadcastCalled = false
	self._BroadcastQueueRunning = false
	
	self._CurrentLoadWorkers = 0
	self._CurrentSaveWorkers = 0
	self._CurrentAutoSaveWorkers = 0

	self._TrackedValidations = {} -- { [Key] = { Predicate = ValidationFunction, Penetration = number or 1 } }
	self._TrackedSchemas = {} -- { [Key] = { Schema = string, Penetration = number or 1 } }
	self._TrackedClamps = {} -- { [Key] = { Min = number?, Max = number?, Penetration = number or 1 } }

	self._UDataComponentDynamicCallbacks = {
		OnReleased = {},
		OnReady = {},
		OnSaved = {},
		OnLoaded = {},
		OnStandby = {},
		OnAutoSaved = {},
		OnArchived = {},
		OnUnarchived = {},

		OnWrite = {},

		OnBroadcastSent = {},
		OnBroadcastReceived = {},

		OnRecordBroadcastReceived = {},

		OnError = {},
		OnDataFiltered = {},
		
		OnOwnershipExpired = {}
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

function UDataComponent:ViewCurrentRecord(Key: number | string, Version: string?) : UDCRecord
	if typeof(Key) == "string" and #Key > self.MaxKeyLength then
		warn(string.format("[%s] : Key is too long", self.ErrorReasonNamespace))
		Key = string.sub(Key, 1, tonumber(self.MaxKeyLength))
	end
	
	local ResultData
	if Version then
		local success, result = pcall(function()
			return self._CurrentDataStore:GetVersionAsync(Key, Version)
		end)
		
		if success and result then ResultData = result else return nil end
	else
		local success, result = pcall(function()
			return self._CurrentDataStore:GetAsync(Key)
		end)
		
		if success and result then ResultData = result else return nil end
	end
	
	local success, decompressed = pcall(Compressor.TryToDecompress, ResultData and ResultData.__data, ResultData and ResultData.__flag)
	
	if not success then
		return nil
	end
	
	local plr = Players:GetPlayerByUserId(ResultData and ResultData.__bounds and ResultData.__bounds.id)
	
	return deepfreeze({ Version = ResultData and ResultData.__version or 0, Owner = plr or nil, Data = decompressed })
end

function UDataComponent:GetLocalRecord() : UDCRecord
	local locKey = self.LocalDataNamespace .. "@" .. self._DataStoreName
	
	return current_record(self, locKey, nil) :: UDCRecord
end

return UDataComponent :: UDataComponent
