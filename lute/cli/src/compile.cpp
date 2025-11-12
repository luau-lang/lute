#include "lute/compile.h"

#include "lute/options.h"
#include "lute/process.h"

#include "uv.h"
#include "zlib.h"

#include <cstring>
#include <fstream>
#include <string>
#include <type_traits>

#ifndef _WIN32
#include <sys/stat.h>
#endif

const char MAGIC_FLAG[] = "LUTEBYTE";
const size_t MAGIC_FLAG_SIZE = sizeof(MAGIC_FLAG) - 1;

LuteExePayload::LuteExePayload(LuteReporter& reporter)
    : reporter(reporter)
{
}

void LuteExePayload::add(const std::string& bundlePath, const std::string& sourcePath)
{
    // First file added becomes the entry point
    if (filePaths.empty())
        entryPointPath = bundlePath;

    // Store the source path for reading files
    filePaths.push_back(sourcePath);

    // Map source path to bundle path
    sourceToBundlePath[sourcePath] = bundlePath;
}

std::optional<LuteEncodeResult> LuteExePayload::encode()
{
    // Encoding an empty payload is an error
    if (filePaths.empty())
    {
        reporter.reportError("Encode failed: No files added to payload");
        return std::nullopt;
    }

    LuteEncodeResult result;
    // Step 1: Build uncompressed bytecode bundle
    // Format: For each file, append [path_len][path][bytecode_size][bytecode]
    std::string uncompressedBundle;
    for (const auto& sourcePath : filePaths)
    {
        // Get the bundle path (rooted path for the bundle)
        const std::string* bundlePathPtr = sourceToBundlePath.find(sourcePath);
        const std::string& bundlePath = bundlePathPtr ? *bundlePathPtr : sourcePath;

        // Read source file from disk using absolute source path
        std::optional<std::string> source = readFile(sourcePath);
        if (!source)
        {
            reporter.formatError("Encode failed: Could not read file '%s'\n", sourcePath.c_str());
            return std::nullopt;
        }

        // Compile Luau source to bytecode
        std::string bytecode = Luau::compile(*source, copts());
        if (bytecode.empty())
        {
            reporter.formatError("Encode failed: Could not compile file '%s' to bytecode", sourcePath.c_str());
            return std::nullopt;
        }

        // Store bytecode with bundle path (rooted path)
        filePathToBytecode[bundlePath] = bytecode;

        // Append path_length field (uint32_t, 4 bytes) - use bundle path
        uint32_t pathLength = static_cast<uint32_t>(bundlePath.size());
        uncompressedBundle.append(reinterpret_cast<const char*>(&pathLength), sizeof(uint32_t));

        // Append path_string field (variable length) - use bundle path
        uncompressedBundle.append(bundlePath);

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
        compressedData.data(),                                     // destination buffer
        &compressedSize,                                           // in/out: buffer size / actual compressed size
        reinterpret_cast<const Bytef*>(uncompressedBundle.data()), // source data
        uncompressedSize,                                          // source size
        Z_BEST_COMPRESSION                                         // compression level (9)
    );

    if (compressResult != Z_OK)
    {
        reporter.formatError("Encode failed: Compression error (zlib error %d)", compressResult);
        return std::nullopt;
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
    // Step 3: Append the metadata needed
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

    return result;
}

std::optional<LuteDecodeResult> LuteExePayload::decode(const std::string_view binary, LuteReporter& reporter)
{
    LuteDecodeResult result{reporter};
    result.payload.filePathToBytecode.clear();

    // Check minimum size for magic flag
    if (binary.size() < MAGIC_FLAG_SIZE + sizeof(uint32_t))
    {
        reporter.formatError("Decode failed: Binary too small (%zu bytes) to contain valid payload", binary.size());
        return std::nullopt;
    }

    // Check for LUTEBYTE magic flag at the end
    size_t magicOffset = binary.size() - MAGIC_FLAG_SIZE;
    if (memcmp(binary.data() + magicOffset, MAGIC_FLAG, MAGIC_FLAG_SIZE) != 0)
    {
        reporter.reportError("Decode failed: LUTEBYTE magic flag not found");
        return std::nullopt;
    }

    // Helper to read fixed-size values backwards
    auto readValue = [&binary, &reporter](size_t& pos, const char* fieldName, auto& value) -> bool
    {
        // We need this because the auto& parameter acts like a generic and we would like to strip out the & here
        using T = std::decay_t<decltype(value)>;
        if (pos < sizeof(T))
        {
            reporter.formatError("Decode failed: Incomplete %s field", fieldName);
            return false;
        }
        pos -= sizeof(T);
        memcpy(&value, binary.data() + pos, sizeof(T));
        return true;
    };

    // Helper to read variable-length bytes backwards
    auto readBytes = [&binary, &reporter](size_t& pos, size_t length, const char* fieldName) -> std::optional<std::string>
    {
        if (pos < length)
        {
            reporter.formatError("Decode failed: Incomplete %s field", fieldName);
            return std::nullopt;
        }
        pos -= length;
        return std::string(binary.data() + pos, length);
    };

    // Read metadata from LUTEBYTE back to entry_point_path_length:
    // [entry_point_path_length][entry_point_path][num_files][uncompressed_size][compressed_size][compressed_data]...[LUTEBYTE]
    size_t pos = binary.size() - MAGIC_FLAG_SIZE;

    // Read entry_point_path_length
    uint32_t entryPointPathLength;
    if (!readValue(pos, "entry_point_path_length", entryPointPathLength))
        return std::nullopt;

    // Read entry_point_path
    auto entryPointPath = readBytes(pos, entryPointPathLength, "entry_point_path");
    if (!entryPointPath)
        return std::nullopt;
    result.payload.entryPointPath = *entryPointPath;

    // Read num_files
    uint32_t numFiles;
    if (!readValue(pos, "num_files", numFiles))
        return std::nullopt;

    // Read uncompressed_size
    uint64_t uncompressedSize;
    if (!readValue(pos, "uncompressed_size", uncompressedSize))
        return std::nullopt;

    // Read compressed_size
    uint64_t compressedSize;
    if (!readValue(pos, "compressed_size", compressedSize))
        return std::nullopt;

    // Read compressed data
    if (pos < compressedSize)
    {
        reporter.formatError("Decode failed: Incomplete compressed data (expected %llu bytes)", static_cast<unsigned long long>(compressedSize));
        return std::nullopt;
    }
    pos -= compressedSize;

    // Decompress the bundle
    std::vector<Bytef> uncompressedData(uncompressedSize);
    uLongf actualUncompressedSize = uncompressedSize;
    int zlibResult =
        uncompress(uncompressedData.data(), &actualUncompressedSize, reinterpret_cast<const Bytef*>(binary.data() + pos), compressedSize);

    if (zlibResult != Z_OK)
    {
        reporter.formatError("Decode failed: Decompression error (zlib error %d)", zlibResult);
        return std::nullopt;
    }

    // Parse the decompressed bundle
    std::string_view decompressedBundle(reinterpret_cast<const char*>(uncompressedData.data()), actualUncompressedSize);
    if (!result.payload.parseFromDecompressedBundle(decompressedBundle))
    {
        reporter.reportError("Decode failed: Failed to parse decompressed bundle");
        return std::nullopt;
    }

    // Validate that the number of parsed files matches the metadata
    if (result.payload.filePathToBytecode.size() != numFiles)
    {
        reporter.formatError("Decode failed: Expected %u files but parsed %zu", numFiles, result.payload.filePathToBytecode.size());
        return std::nullopt;
    }

    // Populate result metrics
    result.bytesRead = binary.size();
    result.compressedPayloadSizeBytes = compressedSize;
    result.uncompressedPayloadSizeBytes = actualUncompressedSize;
    return result;
}

bool LuteExePayload::parseFromDecompressedBundle(std::string_view decompressedBundle)
{
    size_t offset = 0;
    filePathToBytecode.clear();

    while (offset < decompressedBundle.size())
    {
        // Read path length
        if (offset + sizeof(uint32_t) > decompressedBundle.size())
        {
            reporter.reportError("Invalid bundle: incomplete path length field");
            return false;
        }

        uint32_t pathLength;
        memcpy(&pathLength, decompressedBundle.data() + offset, sizeof(uint32_t));
        offset += sizeof(uint32_t);

        // Read path string
        if (offset + pathLength > decompressedBundle.size())
        {
            reporter.reportError("Invalid bundle: incomplete path string");
            return false;
        }

        std::string filePath(decompressedBundle.data() + offset, pathLength);
        offset += pathLength;

        // Read bytecode size
        if (offset + sizeof(uint64_t) > decompressedBundle.size())
        {
            reporter.reportError("Invalid bundle: incomplete bytecode size field");
            return false;
        }

        uint64_t bytecodeSize;
        memcpy(&bytecodeSize, decompressedBundle.data() + offset, sizeof(uint64_t));
        offset += sizeof(uint64_t);

        // Read bytecode
        if (offset + bytecodeSize > decompressedBundle.size())
        {
            reporter.reportError("Invalid bundle: incomplete bytecode data");
            return false;
        }

        std::string bytecode(decompressedBundle.data() + offset, bytecodeSize);
        offset += bytecodeSize;

        // Store in map
        filePathToBytecode[filePath] = bytecode;
    }

    return true;
}

LuteDecodeResult::LuteDecodeResult(LuteReporter& reporter)
    : payload(reporter)
{
}

LuteExecutable::LuteExecutable(const std::string& luteRuntimePath, LuteReporter& reporter)
    : executablePath(luteRuntimePath)
    , reporter(reporter)
{
}

bool LuteExecutable::create(const std::string& outputPath, LuteExePayload& payload)
{
    // Read the current executable (lute runtime)
    std::ifstream sourceExe(executablePath, std::ios::binary | std::ios::ate);
    if (!sourceExe)
    {
        reporter.formatError("Error: Failed to read executable '%s'", executablePath.c_str());
        return false;
    }

    std::streampos exeSize = sourceExe.tellg();
    if (exeSize < 0)
        return false;

    sourceExe.seekg(0, std::ios::beg);
    std::vector<char> exeData(exeSize);
    if (!sourceExe.read(exeData.data(), exeSize))
        return false;

    // Encode the payload
    std::optional<LuteEncodeResult> encodeResult = payload.encode();

    if (!encodeResult)
    {
        reporter.reportError("Error: Failed to encode payload");
        return false;
    }

    // Write output file: executable + payload
    std::ofstream outputFile(outputPath, std::ios::binary);
    if (!outputFile)
    {
        reporter.formatError("Error: Failed to create output file '%s'", outputPath.c_str());
        return false;
    }

    // Write original executable
    outputFile.write(exeData.data(), exeData.size());

    // Write encoded payload
    outputFile.write(encodeResult->payload.data(), encodeResult->payload.size());

    // Set executable permissions (using libuv's permission constants)
#ifndef _WIN32
    chmod(outputPath.c_str(), S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
#endif

    return true;
}

std::optional<LuteExePayload> LuteExecutable::extract()
{
    if (isDirectory(executablePath))
        return std::nullopt;

    std::ifstream exeFile(executablePath, std::ios::binary | std::ios::ate);

    if (!exeFile)
        return std::nullopt;

    // Get file size
    std::streampos fileSize = exeFile.tellg();
    if (fileSize < 0)
        return std::nullopt;

    // Early check: validate LUTEBYTE magic flag at end before reading entire file
    if (fileSize < static_cast<std::streampos>(MAGIC_FLAG_SIZE))
        return std::nullopt;

    exeFile.seekg(-static_cast<std::streamoff>(MAGIC_FLAG_SIZE), std::ios::end);
    char magicBuffer[MAGIC_FLAG_SIZE];
    if (!exeFile.read(magicBuffer, MAGIC_FLAG_SIZE))
        return std::nullopt;

    if (memcmp(magicBuffer, MAGIC_FLAG, MAGIC_FLAG_SIZE) != 0)
        return std::nullopt;

    // Magic flag found, now read entire file
    exeFile.seekg(0, std::ios::beg);
    std::vector<char> fileData(fileSize);
    if (!exeFile.read(fileData.data(), fileSize))
        return std::nullopt;

    // Decode the payload
    std::optional<LuteDecodeResult> decodedPayload = LuteExePayload::decode(std::string_view(fileData.data(), fileData.size()), reporter);
    if (!decodedPayload)
        return std::nullopt;

    return decodedPayload->payload;
}
