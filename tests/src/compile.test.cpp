#include "Luau/FileUtils.h"
#include "doctest.h"
#include "lute/compile.h"
#include "luteprojectroot.h"

#include <cstring>
#include <fstream>
#include <string>
#include <vector>

TEST_CASE("lutepayload_single_file_roundtrip")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    // Create payload and add file
    LuteExePayload originalPayload;
    originalPayload.add(testFilePath);

    // Encode
    auto encodeResult = originalPayload.encode();
    REQUIRE(encodeResult.has_value());
    REQUIRE(encodeResult->bytesWritten > 0);
    REQUIRE(encodeResult->compressedPayloadSizeBytes > 0);
    REQUIRE(encodeResult->uncompressedPayloadSizeBytes > 0);
    REQUIRE(!encodeResult->payload.empty());

    // Verify compression is working (compressed should be smaller than uncompressed)
    CHECK(encodeResult->compressedPayloadSizeBytes <= encodeResult->uncompressedPayloadSizeBytes);

    // Decode
    auto decodeResult = LuteExePayload::decode(encodeResult->payload);
    REQUIRE(decodeResult.has_value());

    // Verify metrics match
    CHECK(decodeResult->bytesRead == encodeResult->bytesWritten);
    CHECK(decodeResult->compressedPayloadSizeBytes == encodeResult->compressedPayloadSizeBytes);
    CHECK(decodeResult->uncompressedPayloadSizeBytes == encodeResult->uncompressedPayloadSizeBytes);

    // Verify entry point
    CHECK(decodeResult->payload.entryPointPath == testFilePath);
    CHECK(decodeResult->payload.entryPointPath == originalPayload.entryPointPath);

    // Verify bytecode map has one entry
    REQUIRE(decodeResult->payload.filePathToBytecode.size() == 1);

    // Verify bytecode matches
    auto it = decodeResult->payload.filePathToBytecode.find(testFilePath);
    REQUIRE(it != nullptr);
    auto originalIt = originalPayload.filePathToBytecode.find(testFilePath);
    REQUIRE(originalIt != nullptr);
    CHECK(*it == *originalIt);
}

TEST_CASE("lutepayload_multiple_files_roundtrip")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();

    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");

    std::vector<std::string> testFiles = {
        joinPaths(testDir, "main.luau"),
        joinPaths(testDir, "utils.luau"),
        joinPaths(testDir, "lib/helper.luau"),
        joinPaths(testDir, "shared.luau")
    };

    // Create payload with multiple files
    LuteExePayload originalPayload;
    for (const auto& file : testFiles)
    {
        originalPayload.add(file);
    }

    // First file should be the entry point
    CHECK(originalPayload.entryPointPath == testFiles[0]);

    auto encodeResult = originalPayload.encode();
    REQUIRE(encodeResult.has_value());
    REQUIRE(!encodeResult->payload.empty());

    auto decodeResult = LuteExePayload::decode(encodeResult->payload);
    REQUIRE(decodeResult.has_value());

    // Verify entry point
    CHECK(decodeResult->payload.entryPointPath == testFiles[0]);

    // Verify all files are present
    REQUIRE(decodeResult->payload.filePathToBytecode.size() == testFiles.size());

    for (const auto& file : testFiles)
    {
        auto decodedIt = decodeResult->payload.filePathToBytecode.find(file);
        REQUIRE(decodedIt != nullptr);

        auto originalIt = originalPayload.filePathToBytecode.find(file);
        REQUIRE(originalIt != nullptr);

        // Verify bytecode matches
        CHECK(*decodedIt == *originalIt);
    }
}

TEST_CASE("lutepayload_invalid_magic_flag")
{
    // Create a payload with invalid magic flag
    std::string invalidPayload = "INVALID_";
    invalidPayload.append(100, 'X'); // Add some data

    auto decodeResult = LuteExePayload::decode(invalidPayload);
    CHECK(!decodeResult.has_value());
}

TEST_CASE("lutepayload_too_small_payload")
{
    // Payload smaller than minimum size
    std::string tinyPayload = "TINY";

    auto decodeResult = LuteExePayload::decode(tinyPayload);
    CHECK(!decodeResult.has_value());
}

TEST_CASE("lutepayload_corrupted_metadata")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    // Create valid payload
    LuteExePayload originalPayload;
    originalPayload.add(testFilePath);
    auto encodeResult = originalPayload.encode();
    REQUIRE(encodeResult.has_value());

    // Corrupt the payload by modifying bytes near the end (metadata area)
    std::string corruptedPayload = encodeResult->payload;
    size_t corruptPos = corruptedPayload.size() - 20;
    if (corruptPos < corruptedPayload.size())
    {
        corruptedPayload[corruptPos] = ~corruptedPayload[corruptPos];
        corruptedPayload[corruptPos + 1] = ~corruptedPayload[corruptPos + 1];
    }

    // Attempt to decode corrupted payload
    auto decodeResult = LuteExePayload::decode(corruptedPayload);
    // Should either fail or produce different results
    if (decodeResult.has_value())
    {
        // If it doesn't fail outright, the data should be corrupted
        CHECK(decodeResult->payload.entryPointPath != originalPayload.entryPointPath);
    }
}

TEST_CASE("lutepayload_entry_point_is_first_added")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");

    std::string firstFile = joinPaths(testDir, "main.luau");
    std::string secondFile = joinPaths(testDir, "utils.luau");

    LuteExePayload payload;
    payload.add(firstFile);
    payload.add(secondFile);

    // Entry point should be the first file added
    CHECK(payload.entryPointPath == firstFile);
}

TEST_CASE("lutepayload_nonexistent_file")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string nonExistentFile = joinPaths(luteProjectRoot, "tests/src/this_file_does_not_exist.luau");

    LuteExePayload payload;
    payload.add(nonExistentFile);

    // Encoding should fail because file doesn't exist
    auto encodeResult = payload.encode();
    CHECK(!encodeResult.has_value());
}

TEST_CASE("lutepayload_empty_payload")
{
    // Create payload without adding any files
    LuteExePayload emptyPayload;
    CHECK(emptyPayload.entryPointPath.empty());

    // Encoding an empty payload should fail
    auto encodeResult = emptyPayload.encode();
    CHECK(!encodeResult.has_value());
}

TEST_CASE("lutepayload_compression_effectiveness")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    LuteExePayload payload;
    payload.add(testFilePath);

    auto encodeResult = payload.encode();
    REQUIRE(encodeResult.has_value());

    // Verify that compression is actually reducing size
    // compressed should be smaller than uncompressed (barring any weird edge cases)
    CHECK(encodeResult->compressedPayloadSizeBytes <= encodeResult->uncompressedPayloadSizeBytes);

    // Verify the total payload includes overhead for metadata
    // Total = compressed data + metadata (sizes, counts, paths, magic flag)
    CHECK(encodeResult->bytesWritten >= encodeResult->compressedPayloadSizeBytes);
}

TEST_CASE("lutepayload_bytecode_integrity")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    // Create two separate payloads with the same file
    LuteExePayload payload1;
    payload1.add(testFilePath);
    auto encode1 = payload1.encode();
    REQUIRE(encode1.has_value());

    LuteExePayload payload2;
    payload2.add(testFilePath);
    auto encode2 = payload2.encode();
    REQUIRE(encode2.has_value());

    // The bytecode for the same file should be identical
    auto it1 = payload1.filePathToBytecode.find(testFilePath);
    auto it2 = payload2.filePathToBytecode.find(testFilePath);
    REQUIRE(it1 != nullptr);
    REQUIRE(it2 != nullptr);
    CHECK(*it1 == *it2);

    // The encoded payloads should be identical (deterministic encoding)
    CHECK(encode1->payload == encode2->payload);
}

TEST_CASE("lutepayload_validates_numfiles_metadata")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    // Create and encode a valid payload
    LuteExePayload payload;
    payload.add(testFilePath);
    auto encodeResult = payload.encode();
    REQUIRE(encodeResult.has_value());

    // Corrupt the numFiles field (located before entry point path)
    // Format: [...][compressed_size][uncompressed_size][num_files][entry_point_path][entry_point_path_length][LUTEBYTE]
    std::string corruptedPayload = encodeResult->payload;

    // Find the numFiles field: 8 bytes (magic) + 4 bytes (entry path len) + entry path len + 4 bytes (num_files)
    size_t magicSize = 8; // "LUTEBYTE"

    // Read entry point path length from the correct position
    size_t entryPathLenPos = corruptedPayload.size() - magicSize - sizeof(uint32_t);
    uint32_t entryPathLen;
    memcpy(&entryPathLen, corruptedPayload.data() + entryPathLenPos, sizeof(uint32_t));

    // numFiles is right before the entry point path
    size_t numFilesPos = corruptedPayload.size() - magicSize - sizeof(uint32_t) - entryPathLen - sizeof(uint32_t);

    // Change numFiles from 1 to 99
    uint32_t fakeNumFiles = 99;
    memcpy(corruptedPayload.data() + numFilesPos, &fakeNumFiles, sizeof(uint32_t));

    // Decoding should fail due to numFiles mismatch
    auto decodeResult = LuteExePayload::decode(corruptedPayload);
    CHECK(!decodeResult.has_value());
}
