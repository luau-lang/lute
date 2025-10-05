#pragma once

#include <string>
#include <vector>
#include <map>
#include <optional>


enum class PayloadEncodeStatus
{
    Ok,
    FileNotFound,
    BytecodeCompilationFailed,
    BytecodeCompressionFailed,

};

enum class PayloadDecodeStatus
{
    Ok,
    PayloadTooSmall,
    MagicFlagNotFound,
    IncompleteMetadata,
    DecompressionFailed,
    BundleParsingFailed,
};

struct LuteEncodeResult
{
    std::string payload;
    std::optional<std::string> errMessage = std::nullopt;
    std::optional<PayloadEncodeStatus> status;
    size_t bytesWritten = 0;
    size_t compressedPayloadSizeBytes = 0;
    size_t uncompressedPayloadSizeBytes = 0;
    void setError(PayloadEncodeStatus status, std::string errMessage);
};

struct LuteDecodeResult
{
    std::optional<std::string> errMessage = std::nullopt;
    std::optional<PayloadDecodeStatus> status;
    size_t bytesRead = 0;
    size_t compressedPayloadSizeBytes = 0;
    size_t uncompressedPayloadSizeBytes = 0;
    void setError(PayloadDecodeStatus status, std::string errMessage);
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
    LuteExePayload();

    bool add(const std::string& luauFilePath);

    void encode(LuteEncodeResult& result);
    void encode(LuteEncodeResult&& result) = delete;

    void decode(const std::string_view binary, LuteDecodeResult& result);
    void decode(const std::string_view binary, LuteDecodeResult&& result) = delete;

    std::string entryPointPath;
    std::vector<std::string> filePaths;
    std::map<std::string, std::string> filePathToBytecode; // path -> bytecode

private:
    bool parseFromDecompressedBundle(const std::string& decompressedBundle);
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

    bool create(std::string& outputPath, LuteExePayload& payload);
    std::optional<LuteExePayload> extract();

    std::string executablePath;
    std::string compressedBundleData;
};

