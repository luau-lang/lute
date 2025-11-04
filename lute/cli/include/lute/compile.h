#pragma once

#include "Luau/DenseHash.h"
#include "Luau/FileUtils.h"

#include <string_view>

struct LuteDecodeResult;

struct LuteEncodeResult
{
    std::string payload;
    size_t bytesWritten = 0;
    size_t compressedPayloadSizeBytes = 0;
    size_t uncompressedPayloadSizeBytes = 0;
};

/**
 * Represents a bundle of compiled Luau files ready for injection.
 *
 * Uncompressed bundle format (before compression):
 *   For each file:
 *     [path_length: uint32_t]
 *     [path_string: char[path_length]]
 *     [bytecode_size: uint64_t]
 *     [bytecode_data: byte[bytecode_size]]
 *
 * Injectable payload format (after compression, what goes into executable):
 *   [compressed_bundle_data: byte[compressed_size]]
 *   [compressed_size: uint64_t]
 *   [uncompressed_size: uint64_t]
 *   [num_files: uint32_t]
 *   [entry_point_path_string: char[entry_point_path_length]]
 *   [entry_point_path_length: uint32_t]

 */
struct LuteExePayload
{
    LuteExePayload() = default;
    void add(const std::string& sourcePath, const std::string& bundlePath);

    std::optional<LuteEncodeResult> encode();
    static std::optional<LuteDecodeResult> decode(const std::string_view binary);

    std::string entryPointPath;
    Luau::DenseHashMap<std::string, std::string> filePathToBytecode{""}; // path -> bytecode

private:
    bool parseFromDecompressedBundle(std::string_view decompressedBundle);
    std::vector<std::string> filePaths;
    Luau::DenseHashMap<std::string, std::string> sourceToBundlePath{""};
};

struct LuteDecodeResult
{
    LuteExePayload payload;
    size_t bytesRead = 0;
    size_t compressedPayloadSizeBytes = 0;
    size_t uncompressedPayloadSizeBytes = 0;
};

/**
 * Manages creating and reading Lute executables with embedded bytecode bundles.
 *
 * Binary format (from end of file, reading backward):
 *   [lute runtime executable's bytes]
 *   [compressed bundle data]
 *   [compressed_size: uint64_t]
 *   [uncompressed_size: uint64_t]
 *   [num_files: uint32_t]
 *   [entry_point_path_string: char[entry_point_path_length]]
 *   [entry_point_path_length: uint32_t]
 *   [MAGIC_FLAG: "LUTEBYTE" (8 bytes)]
 */
struct LuteExecutable
{
    LuteExecutable(const std::string& luteRuntimePath);

    bool create(const std::string& outputPath, LuteExePayload& payload);
    std::optional<LuteExePayload> extract();

    std::string executablePath;
};
