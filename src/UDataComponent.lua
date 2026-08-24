local Compressor = {}

local EncodingService = game:GetService("EncodingService")
local HttpService = game:GetService("HttpService")

function Compressor.Compress(dataTable : {any}, level : number?)
	level = level or 10
	local json = HttpService:JSONEncode(dataTable)
	local buff = buffer.fromstring(json)
	
	local compress = EncodingService:CompressBuffer(buff, Enum.CompressionAlgorithm.Zstd, level)
	
	return compress
end

function Compressor.Decompress(buff: buffer)
	local decompress = EncodingService:DecompressBuffer(buff, Enum.CompressionAlgorithm.Zstd)
	
	local rawBuff = buffer.tostring(decompress)
	local json = HttpService:JSONDecode(rawBuff)
	
	return json
end

function Compressor.IsOverheadIfCompressed(dataTable : {any}, level : number?, thresHold : number?)
	level = level or 10
	thresHold = thresHold or 1

	local json = HttpService:JSONEncode(dataTable)
	local realBuff = buffer.fromstring(json)
	
	local compressedOne = Compressor.Compress(dataTable, level)
	
	local realSize = buffer.len(realBuff)
	local compressedSize = buffer.len(compressedOne)
	
	return compressedSize >= realSize + thresHold -- I would consider that even same byte sizes is also an overhead
end

function Compressor.TryToCompress(dataTable : {any}, level : number?, thresHold : number?)
	local isOverhead = Compressor.IsOverheadIfCompressed(dataTable, level, thresHold)
	
	if isOverhead then
		local json = HttpService:JSONEncode(dataTable)
		local buff = buffer.fromstring(json)
		
		return buff, "R" -- Real buffer
	else
		local compress = Compressor.Compress(dataTable, level)
		
		return compress, "C" -- Compressed buffer
	end
	
	
end

function Compressor.TryToDecompress(buff : buffer, flag : string) -- Flag is 'C' or 'R'
	local isCompressed = flag == "C" -- Compressed buffer?
	
	if isCompressed then
		local decompress = Compressor.Decompress(buff)
		
		return decompress
	else
		local rawBuff = buffer.tostring(buff)
		local json = HttpService:JSONDecode(rawBuff)
		
		return json
	end
end

function Compressor.GetSize(data : {any?}) -- Use decoded JSON 
	local json = HttpService:JSONEncode(data)
	local buff = buffer.fromstring(json)
	
	return buffer.len(buff)
end

return Compressor
