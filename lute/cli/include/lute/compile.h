#pragma once

#include "lute/bundlevfs.h"
#include "lute/reporter.h"

#include "Luau/DenseHash.h"
#include "Luau/FileUtils.h"

#include <string_view>
#include <vector>

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
 *   [num_alias_entries: uint32_t]
 *   For each alias entry:
 *     [subtree_prefix_length: uint32_t]
 *     [subtree_prefix: char[subtree_prefix_length]]
 *     [alias_name_length: uint32_t]
 *     [alias_name: char[alias_name_length]]
 *     [alias_value_length: uint32_t]
 *     [alias_value: char[alias_value_length]]
 *   [num_config_entries: uint32_t]
 *   For each config entry:
 *     [path_length: uint32_t]
 *     [path_val: char[path_length]]
 *     [luaurc_length: uint32_t]
 *     [luaurc_contents: char[luaurc_length]]
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
    LuteExePayload(LuteReporter& reporter);
    void add(const std::string& bundlePath, const std::string& sourcePath);
    void setLuauConfig(const Luau::DenseHashMap<std::string, std::string>& configs);
    // Sets the package alias table that will be embedded in the bundle and
    // consulted by BundleVfs at runtime to resolve `@<dep>` requires inside
    // the produced executable.
    void setPackageAliases(std::vector<BundlePackageAlias> aliases);

    std::optional<LuteEncodeResult> encode();
    static std::optional<LuteDecodeResult> decode(const std::string_view binary, LuteReporter& reporter);

    std::string entryPointPath;
    Luau::DenseHashMap<std::string, std::string> filePathToBytecode{""}; // path -> bytecode
    Luau::DenseHashMap<std::string, std::string> luauConfigFiles{""};    // path -> config
    std::vector<BundlePackageAlias> packageAliases;                      // bundle-scoped package alias table

private:
    LuteReporter& reporter;
    bool parseFromDecompressedBundle(std::string_view decompressedBundle);
    std::vector<std::string> filePaths;
    Luau::DenseHashMap<std::string, std::string> sourceToBundlePath{""};
};

struct LuteDecodeResult
{
    LuteDecodeResult(LuteReporter& reporter);
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
    LuteExecutable(const std::string& luteRuntimePath, LuteReporter& reporter);

    bool create(const std::string& outputPath, LuteExePayload& payload);
    std::optional<LuteExePayload> extract();

    std::string executablePath;
    LuteReporter& reporter;
};
