#include "Luau/FileUtils.h"
#include "doctest.h"
#include "lute/compile.h"
#include "luteprojectroot.h"

#include <fstream>
#include <string>
#include <vector>

TEST_CASE("compile_roundtrip_encode_decode")
{
    // Get the test file path
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/compile/main.luau");

    // Create payload and encode it
    LuteExePayload originalPayload;
    CHECK(originalPayload.add(testFilePath));

    LuteEncodeResult encodeResult;
    originalPayload.encode(encodeResult);

    // Verify encoding succeeded
    REQUIRE(encodeResult.status == PayloadEncodeStatus::Ok);
    REQUIRE(!encodeResult.errMessage.has_value());

    // Store original metrics
    size_t originalBytesWritten = encodeResult.bytesWritten;
    size_t originalCompressedSize = encodeResult.compressedPayloadSizeBytes;
    size_t originalUncompressedSize = encodeResult.uncompressedPayloadSizeBytes;

    // Decode the payload
    LuteExePayload decodedPayload;
    LuteDecodeResult decodeResult;
    decodedPayload.decode(encodeResult.payload, decodeResult);

    // Verify decoding succeeded
    CHECK(decodeResult.status == PayloadDecodeStatus::Ok);
    CHECK(!decodeResult.errMessage.has_value());

    // Verify sizes match
    CHECK(decodeResult.bytesRead == originalBytesWritten);
    CHECK(decodeResult.compressedPayloadSizeBytes == originalCompressedSize);
    CHECK(decodeResult.uncompressedPayloadSizeBytes == originalUncompressedSize);

    // Verify entry point matches
    CHECK(decodedPayload.entryPointPath == originalPayload.entryPointPath);

    // Verify number of modules matches
    CHECK(decodedPayload.filePathToBytecode.size() == originalPayload.filePathToBytecode.size());

    // Verify each module's bytecode matches
    for (const auto& [path, bytecode] : originalPayload.filePathToBytecode)
    {
        auto it = decodedPayload.filePathToBytecode.find(path);
        REQUIRE(it != decodedPayload.filePathToBytecode.end());
        CHECK(it->second == bytecode);
    }
}
