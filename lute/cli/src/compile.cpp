#include "lute/compile.h"

#include "Luau/Compiler.h"
#include "Luau/FileUtils.h"
#include "lute/options.h"
#include "uv.h"
#include <zlib.h>
#include <fstream>
#include <filesystem>
#include <cstring>

namespace fs = std::filesystem;
const char MAGIC_FLAG[] = "LUTEBYTE";
const size_t MAGIC_FLAG_SIZE = sizeof(MAGIC_FLAG) - 1;

void LuteEncodeResult::setError(PayloadEncodeStatus status, std::string errMessage)
{
    this->status.emplace(status);
    this->errMessage.emplace(std::move(errMessage));
}

void LuteDecodeResult::setError(PayloadDecodeStatus status, std::string errMessage)
{
    this->status.emplace(status);
    this->errMessage.emplace(std::move(errMessage));
}

LuteExePayload::LuteExePayload()
{
}

bool LuteExePayload::add(const std::string& luauFilePath)
{
    // First file added becomes the entry point
    if (filePaths.empty())
    {
        entryPointPath = luauFilePath;
    }

    filePaths.push_back(luauFilePath);
    return true;
}

void LuteExePayload::encode(LuteEncodeResult& result)
{
    // Step 1: Build uncompressed bytecode bundle
    // Format: For each file, append [path_len][path][bytecode_size][bytecode]
    std::string uncompressedBundle;
    for (const auto& filePath : filePaths)
    {
        // Read source file from disk
        std::optional<std::string> source = readFile(filePath);
        if (!source)
        {
            result.setError(PayloadEncodeStatus::FileNotFound, "Error opening file " + filePath);
            return;
        }

        // Compile Luau source to bytecode
        std::string bytecode = Luau::compile(*source, copts());
        if (bytecode.empty())
        {
            result.setError(PayloadEncodeStatus::BytecodeCompilationFailed, "Error compiling " + filePath + " to bytecode.");
            return;
        }

        filePathToBytecode[filePath] = bytecode;

        // Append path_length field (uint32_t, 4 bytes)
        uint32_t pathLength = static_cast<uint32_t>(filePath.size());
        uncompressedBundle.append(reinterpret_cast<const char*>(&pathLength), sizeof(uint32_t));

        // Append path_string field (variable length)
        uncompressedBundle.append(filePath);

        // Append bytecode_size field (uint64_t, 8 bytes)
        uint64_t bytecodeSize = bytecode.size();
        uncompressedBundle.append(reinterpret_cast<const char*>(&bytecodeSize), sizeof(uint64_t));

        // Append bytecode_data field (variable length)
        uncompressedBundle.append(bytecode);
    }

    // Step 2: Compress the bundled bytecode using zlib
    uLong uncompressedSize = uncompressedBundle.size();

    // Calculate maximum possible compressed size
    uLong compressedSize = compressBound(uncompressedSize);
    std::vector<Bytef> compressedData(compressedSize);

    // Compress with maximum compression level
    int compressResult = compress2(
        compressedData.data(),           // destination buffer
        &compressedSize,                 // in/out: buffer size / actual compressed size
        reinterpret_cast<const Bytef*>(uncompressedBundle.data()),  // source data
        uncompressedSize,                // source size
        Z_BEST_COMPRESSION               // compression level (9)
    );

    if (compressResult != Z_OK)
    {
        result.setError(PayloadEncodeStatus::BytecodeCompressionFailed, "Error compressing bundle: zlib error" + std::to_string(compressResult));
        return;
    }
    result.payload.clear();
    size_t totalBytes = compressedSize            // Size of compressed data
                        + sizeof(uint64_t)        // Length of compressed data (uint64_t)
                        + sizeof(uint64_t)        // Lengths of uncompressed data (uint64_t)
                        + sizeof(uint32_t)        // Number of modules(files) in the bundle (uint32_t)
                        + entryPointPath.length() // Module entry point path length
                        + sizeof(uint32_t)        // Length of entry point field
                        + MAGIC_FLAG_SIZE;        // LUTEBYTE - the magic flag that tells us to decode the bundled modules
    result.payload.reserve(totalBytes);
    // Append compressed_data field (variable length, compressedSize bytes)
    result.payload.append(reinterpret_cast<const char*>(compressedData.data()), compressedSize);

    // Append compressed_size field (uint64_t, 8 bytes)
    uint64_t compressedSizeField = compressedSize;
    result.payload.append(reinterpret_cast<const char*>(&compressedSizeField), sizeof(uint64_t));

    // Append uncompressed_size field (uint64_t, 8 bytes)
    uint64_t uncompressedSizeField = uncompressedSize;
    result.payload.append(reinterpret_cast<const char*>(&uncompressedSizeField), sizeof(uint64_t));

    // Append num_files field (uint32_t, 4 bytes)
    uint32_t numFiles = static_cast<uint32_t>(filePaths.size());
    result.payload.append(reinterpret_cast<const char*>(&numFiles), sizeof(uint32_t));

    // Append entry_point_path_string field (variable length)
    result.payload.append(entryPointPath);

    // Append entry_point_path_length field (uint32_t, 4 bytes)
    uint32_t entryPointPathLength = static_cast<uint32_t>(entryPointPath.size());
    result.payload.append(reinterpret_cast<const char*>(&entryPointPathLength), sizeof(uint32_t));

    // Step 4: Append the LUTE BYTE
    result.payload.append(MAGIC_FLAG, MAGIC_FLAG_SIZE);

    result.bytesWritten = result.payload.size();
    result.compressedPayloadSizeBytes = compressedSize;
    result.uncompressedPayloadSizeBytes = uncompressedSize;
    
    result.status = PayloadEncodeStatus::Ok;
    return;
}

void LuteExePayload::decode(const std::string_view binary, LuteDecodeResult& result)
{
    filePathToBytecode.clear();

    // Check minimum size for magic flag
    if (binary.size() < MAGIC_FLAG_SIZE + sizeof(uint32_t))
    {
        result.setError(PayloadDecodeStatus::PayloadTooSmall, "Payload is too small to contain valid data");
        return;
    }

    // Check for LUTEBYTE magic flag at the end
    size_t magicOffset = binary.size() - MAGIC_FLAG_SIZE;
    if (memcmp(binary.data() + magicOffset, MAGIC_FLAG, MAGIC_FLAG_SIZE) != 0)
    {
        result.setError(PayloadDecodeStatus::MagicFlagNotFound, "LUTEBYTE magic flag not found at end of payload");
        return;
    }


    // Read metadata from end: [entry_point_path_length][entry_point_path][num_files][uncompressed_size][compressed_size][compressed_data]...[LUTEBYTE]
    size_t pos = binary.size() - MAGIC_FLAG_SIZE;

    // Read entry_point_path_length
    if (pos < sizeof(uint32_t))
    {
        result.setError(PayloadDecodeStatus::IncompleteMetadata, "Incomplete entry point path length field");
        return;
    }
    pos -= sizeof(uint32_t);
    uint32_t entryPointPathLength;
    memcpy(&entryPointPathLength, binary.data() + pos, sizeof(uint32_t));

    // Read entry_point_path
    if (pos < entryPointPathLength)
    {
        result.setError(PayloadDecodeStatus::IncompleteMetadata, "Incomplete entry point path field");
        return;
    }
    pos -= entryPointPathLength;
    entryPointPath = std::string(binary.data() + pos, entryPointPathLength);

    // Read num_files
    if (pos < sizeof(uint32_t))
    {
        result.setError(PayloadDecodeStatus::IncompleteMetadata, "Incomplete num files field");
        return;
    }
    pos -= sizeof(uint32_t);
    uint32_t numFiles;
    memcpy(&numFiles, binary.data() + pos, sizeof(uint32_t));

    // Read uncompressed_size
    if (pos < sizeof(uint64_t))
    {
        result.setError(PayloadDecodeStatus::IncompleteMetadata, "Incomplete uncompressed size field");
        return;
    }
    pos -= sizeof(uint64_t);
    uint64_t uncompressedSize;
    memcpy(&uncompressedSize, binary.data() + pos, sizeof(uint64_t));

    // Read compressed_size
    if (pos < sizeof(uint64_t))
    {
        result.setError(PayloadDecodeStatus::IncompleteMetadata, "Incomplete compressed size field");
        return;
    }
    pos -= sizeof(uint64_t);
    uint64_t compressedSize;
    memcpy(&compressedSize, binary.data() + pos, sizeof(uint64_t));

    // Read compressed data
    if (pos < compressedSize)
    {
        result.setError(PayloadDecodeStatus::IncompleteMetadata, "Incomplete compressed data");
        return;
    }
    pos -= compressedSize;

    // Decompress the bundle
    std::vector<Bytef> uncompressedData(uncompressedSize);
    uLongf actualUncompressedSize = uncompressedSize;
    int zlibResult = uncompress(
        uncompressedData.data(),
        &actualUncompressedSize,
        reinterpret_cast<const Bytef*>(binary.data() + pos),
        compressedSize
    );

    if (zlibResult != Z_OK)
    {
        result.setError(PayloadDecodeStatus::DecompressionFailed, "Decompression failed: zlib error " + std::to_string(zlibResult));
        return;
    }

    // Parse the decompressed bundle
    std::string decompressedBundle(reinterpret_cast<char*>(uncompressedData.data()), actualUncompressedSize);
    if (!parseFromDecompressedBundle(decompressedBundle))
    {
        result.setError(PayloadDecodeStatus::BundleParsingFailed, "Failed to parse decompressed bundle");
        return;
    }

    // Populate result metrics
    result.bytesRead = binary.size();
    result.compressedPayloadSizeBytes = compressedSize;
    result.uncompressedPayloadSizeBytes = actualUncompressedSize;
    result.status = PayloadDecodeStatus::Ok;
}

bool LuteExePayload::parseFromDecompressedBundle(const std::string& decompressedBundle)
{
    size_t offset = 0;
    filePathToBytecode.clear();

    while (offset < decompressedBundle.size())
    {
        // Read path length
        if (offset + sizeof(uint32_t) > decompressedBundle.size())
        {
            fprintf(stderr, "Invalid bundle: incomplete path length field\n");
            return false;
        }

        uint32_t pathLength;
        memcpy(&pathLength, decompressedBundle.data() + offset, sizeof(uint32_t));
        offset += sizeof(uint32_t);

        // Read path string
        if (offset + pathLength > decompressedBundle.size())
        {
            fprintf(stderr, "Invalid bundle: incomplete path string\n");
            return false;
        }

        std::string filePath(decompressedBundle.data() + offset, pathLength);
        offset += pathLength;

        // Read bytecode size
        if (offset + sizeof(uint64_t) > decompressedBundle.size())
        {
            fprintf(stderr, "Invalid bundle: incomplete bytecode size field\n");
            return false;
        }

        uint64_t bytecodeSize;
        memcpy(&bytecodeSize, decompressedBundle.data() + offset, sizeof(uint64_t));
        offset += sizeof(uint64_t);

        // Read bytecode
        if (offset + bytecodeSize > decompressedBundle.size())
        {
            fprintf(stderr, "Invalid bundle: incomplete bytecode data\n");
            return false;
        }

        std::string bytecode(decompressedBundle.data() + offset, bytecodeSize);
        offset += bytecodeSize;

        // Store in map
        filePathToBytecode[filePath] = bytecode;
    }

    return true;
}

LuteExecutable::LuteExecutable(const std::string& luteRuntimePath)
    : executablePath(luteRuntimePath)
{
}

bool LuteExecutable::create(std::string& outputPath, LuteExePayload& payload)
{
    // Encode the payload
    LuteEncodeResult encodeResult;
    payload.encode(encodeResult);

    if (encodeResult.status != PayloadEncodeStatus::Ok)
    {
        fprintf(stderr, "Error encoding payload: %s\n", encodeResult.errMessage.value_or("Unknown error").c_str());
        return false;
    }

    // Read the executable binary
    std::ifstream exeFile(executablePath, std::ios::binary | std::ios::ate);
    if (!exeFile)
    {
        fprintf(stderr, "Error opening executable %s\n", executablePath.c_str());
        return false;
    }

    std::streamsize exeSize = exeFile.tellg();
    exeFile.seekg(0, std::ios::beg);
    std::vector<char> exeBuffer(exeSize);
    if (!exeFile.read(exeBuffer.data(), exeSize))
    {
        fprintf(stderr, "Error reading executable %s\n", executablePath.c_str());
        exeFile.close();
        return false;
    }
    exeFile.close();

    // Write to output file
    std::ofstream outFile(outputPath, std::ios::binary | std::ios::trunc);
    if (!outFile)
    {
        fprintf(stderr, "Error creating output file %s\n", outputPath.c_str());
        return false;
    }

    // Write executable
    outFile.write(exeBuffer.data(), exeSize);

    // Write encoded payload
    outFile.write(encodeResult.payload.data(), encodeResult.payload.size());

    if (!outFile.good())
    {
        fprintf(stderr, "Error writing to output file %s\n", outputPath.c_str());
        outFile.close();
        remove(outputPath.c_str());
        return false;
    }

    outFile.close();

#ifndef _WIN32
    chmod(outputPath.c_str(), S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
#endif

    return true;
}

std::optional<LuteExePayload> LuteExecutable::extract()
{
    if (!fs::is_regular_file(executablePath))
    {
        return std::nullopt;
    }

    std::ifstream exeFile(executablePath, std::ios::binary | std::ios::ate);

    if (!exeFile)
    {
        return std::nullopt;
    }

    // Get file size
    std::streampos fileSize = exeFile.tellg();
    if (fileSize < 0)
    {
        exeFile.close();
        return std::nullopt;
    }

    // Read entire file
    exeFile.seekg(0, std::ios::beg);
    std::vector<char> fileData(fileSize);
    if (!exeFile.read(fileData.data(), fileSize))
    {
        exeFile.close();
        return std::nullopt;
    }
    exeFile.close();

    // Early check for LUTEBYTE magic flag before attempting decode
    if (fileData.size() < MAGIC_FLAG_SIZE)
    {
        return std::nullopt;
    }

    size_t magicOffset = fileData.size() - MAGIC_FLAG_SIZE;
    if (memcmp(fileData.data() + magicOffset, MAGIC_FLAG, MAGIC_FLAG_SIZE) != 0)
    {
        return std::nullopt;
    }


    // Decode the payload
    LuteExePayload payload;
    LuteDecodeResult decodeResult;
    payload.decode(std::string_view(fileData.data(), fileData.size()), decodeResult);

    if (decodeResult.status != PayloadDecodeStatus::Ok)
    {
        return std::nullopt;
    }
    return payload;
}

