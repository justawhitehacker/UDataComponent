-- UDataComponent.lua
-- UDataComponent-v2.0

-- I decided to refactor, but also created a new one
-- I probably still stealing some features from the previous version into here
-- That'd cut some many times instead imagining a new-massive module features
local UDataComponent = {}
UDataComponent.__index = UDataComponent

-- Standard UDataComponent level
export type UDataComponent = {
	InDataInfo: (DataStoreName: string, Scope: string?, Configurations: {[string]: any}?) -> UDCInfo,
}

-- Info level, where UDataComponent see the configurations
export type UDCInfo = {
	Name: string, -- Name of the data store from this info
	Scope: string, -- Scope of the data store from this info
	
	GetCurrentRecord: (UDCInfo: UDCInfo, Key: number | string, OwnerOfThisData: Player?) -> UDCRecord,
	-- This is where the record of player's data is obtained:
	-- @param: Key: number | string -> Key of the record of this player
	-- @param: OwnerOfThisData: Player -> Player who owns this data, prevent other servers or other player to obtain or commit the data
	GetLocalRecord: (UDCInfo: UDCInfo) -> UDCRecord,
	-- This is where the record of local data is obtained
	-- You can say, in UDC, local data is just "global data of this data store" or "global record"
	
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
	LocalDataNamespace : string, -- Namespace for the local record level
	MessagingEnabled : boolean, -- If this UDataComponent's info allowed to use messaging across servers, called Broadcasting
	MessagingNamespace : string, -- Namespace for the Broadcast channel for each server
	MessagingCooldown : number, -- Cooldown for receive the broadcast informations
	MessagingSendingCooldown : number, -- Cooldown for sending the broadcast informations
	MessagingReceivingCooldown : number, -- Cooldown for listening the broadcast messages
	MessagingLocalListeningCooldown : number, -- Cooldown for listening the local broadcast messages
	ArchivationEnabled : boolean, -- If this UDataComponent's info allowed to use archivation, where the data will be moved to the archived data store after detaching
	ArchivationSuffix : string, -- Suffixed to the DataStore name for the archived data
}

-- Record level, where the data record is accessed here
export type UDCRecord = {
	Key: number | string, -- Key of this data
	Owner: Player?, -- Player who owns this record
	IsArchived: boolean, -- If this record was detached and archived
	Event: UDCEvent, -- Utils for the events
	Validation: UDCValidation, -- Utils for the validation
	Version: number, -- Version of this data
	Data: any?, -- Loaded Data that has been loaded, this is a clone from the actual data/cache, where this must be a read member
	
	-- These are two Write functions, with two types too: Normal and Force
	-- Normal is when you writing the data with cooldown and lock, especially when the data is pending into queue to be commited
	-- Force is when you don't care about the cooldown and lock, and will be commited immediately
	
	-- For safe writing data session, use Normal, and for immediate case, use Force
	-- For normal, before even the commiting, it will be cached 
	
	LoadRecordData: (UDCRecord: UDCRecord) -> boolean, -- (Suspending) IMPORTANT POINT, this load the record from the datastore, and must be called when player is joing the experience
	Ready: (UDCRecord: UDCRecord) -> boolean, -- (Suspending) IMPORANT POINT, this must be called before the data can be used, where UDC is evaluating everything fromn the data and ownership, before the data can be used
	Save: (UDCRecord: UDCRecord, Data: any, SegmentIndex: number?) -> boolean, -- (Suspending) this is saving data where the data must be an over-all data, which is the previous recored that haven't been edited also must be saved too, will pushed into save pending queue then changed the read data
	-- @param Data: any -- Data to commit
	-- @param SegmentIndex: number? -- Where the current data is contained in an index to
	-- @return boolean -- Status of the saving data, true if success
	Write: (UDCRecord: UDCRecord, WritingFunction: (CurrentData: any) -> ()) -> boolean, -- (Suspending) this is how you can save the data with partial update, where you don't need to commit all data to write when you just need one or two or more datas to edit
	-- @param WritingFunction: (CurrentData: any) -> () -- Function that used as Write session over the data
	-- @return boolean -- Status of the writing data, true if success
}

export type UDCEvent = {
	
}

export type UDCValidation = {
	
}

return UDataComponent
