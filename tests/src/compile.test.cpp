#include "lute/compile.h"

#include "lute/climain.h"

#include "Luau/FileUtils.h"

#include <cstring>
#include <fstream>
#include <memory>
#include <string>
#include <vector>

#include "doctest.h"
#include "lutefixture.h"
#include "luteprojectroot.h"

TEST_CASE_FIXTURE(LuteFixture, "lutepayload_single_file_roundtrip")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    // Create payload and add file
    LuteExePayload originalPayload{getReporter()};
    originalPayload.add(testFilePath, testFilePath);

    // Add luaurc config
    Luau::DenseHashMap<std::string, std::string> configs{""};
    configs[".luaurc"] = "{\"aliases\":{\"example\":\"./dep\"}}";
    originalPayload.setLuauConfig(configs);

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
    auto decodeResult = LuteExePayload::decode(encodeResult->payload, getReporter());
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

    // Verify luaurc config was preserved
    REQUIRE(decodeResult->payload.luauConfigFiles.size() == 1);
    auto configIt = decodeResult->payload.luauConfigFiles.find(".luaurc");
    REQUIRE(configIt != nullptr);
    CHECK(configIt->find("aliases") != std::string::npos);
}

TEST_CASE_FIXTURE(LuteFixture, "lutepayload_multiple_files_roundtrip")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();

    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");

    std::vector<std::string> testFiles = {
        joinPaths(testDir, "main.luau"), joinPaths(testDir, "utils.luau"), joinPaths(testDir, "lib/helper.luau"), joinPaths(testDir, "shared.luau")
    };

    // Create payload with multiple files
    LuteExePayload originalPayload{getReporter()};
    for (const auto& file : testFiles)
    {
        originalPayload.add(file, file);
    }

    // Add luaurc config
    Luau::DenseHashMap<std::string, std::string> configs{""};
    configs[".luaurc"] = "{\"aliases\":{\"example\":\"./dep\"}}";
    originalPayload.setLuauConfig(configs);

    // First file should be the entry point
    CHECK(originalPayload.entryPointPath == testFiles[0]);

    auto encodeResult = originalPayload.encode();
    REQUIRE(encodeResult.has_value());
    REQUIRE(!encodeResult->payload.empty());

    auto decodeResult = LuteExePayload::decode(encodeResult->payload, getReporter());
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

    // Verify luaurc config was preserved
    REQUIRE(decodeResult->payload.luauConfigFiles.size() == 1);
    auto configIt = decodeResult->payload.luauConfigFiles.find(".luaurc");
    REQUIRE(configIt != nullptr);
    CHECK(configIt->find("aliases") != std::string::npos);
}

TEST_CASE_FIXTURE(LuteFixture, "lutepayload_invalid_magic_flag")
{
    // Create a payload with invalid magic flag
    std::string invalidPayload = "INVALID_";
    invalidPayload.append(100, 'X'); // Add some data

    auto decodeResult = LuteExePayload::decode(invalidPayload, getReporter());
    CHECK(!decodeResult.has_value());
}

TEST_CASE_FIXTURE(LuteFixture, "lutepayload_too_small_payload")
{
    // Payload smaller than minimum size
    std::string tinyPayload = "TINY";

    auto decodeResult = LuteExePayload::decode(tinyPayload, getReporter());
    CHECK(!decodeResult.has_value());
}

TEST_CASE_FIXTURE(LuteFixture, "lutepayload_corrupted_metadata")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    // Create valid payload
    LuteExePayload originalPayload{getReporter()};
    originalPayload.add(testFilePath, testFilePath);
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
    auto decodeResult = LuteExePayload::decode(corruptedPayload, getReporter());
    // Should either fail or produce different results
    if (decodeResult.has_value())
    {
        // If it doesn't fail outright, the data should be corrupted
        CHECK(decodeResult->payload.entryPointPath != originalPayload.entryPointPath);
    }
}

TEST_CASE_FIXTURE(LuteFixture, "lutepayload_entry_point_is_first_added")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");

    std::string firstFile = joinPaths(testDir, "main.luau");
    std::string secondFile = joinPaths(testDir, "utils.luau");

    LuteExePayload payload{getReporter()};
    payload.add(firstFile, firstFile);
    payload.add(secondFile, secondFile);

    // Entry point should be the first file added
    CHECK(payload.entryPointPath == firstFile);
}

TEST_CASE_FIXTURE(LuteFixture, "lutepayload_nonexistent_file")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string nonExistentFile = joinPaths(luteProjectRoot, "tests/src/this_file_does_not_exist.luau");

    LuteExePayload payload{getReporter()};
    payload.add(nonExistentFile, nonExistentFile);

    // Encoding should fail because file doesn't exist
    auto encodeResult = payload.encode();
    CHECK(!encodeResult.has_value());
}

TEST_CASE_FIXTURE(LuteFixture, "lutepayload_empty_payload")
{
    // Create payload without adding any files
    LuteExePayload emptyPayload{getReporter()};
    CHECK(emptyPayload.entryPointPath.empty());

    // Encoding an empty payload should fail
    auto encodeResult = emptyPayload.encode();
    CHECK(!encodeResult.has_value());
}

TEST_CASE_FIXTURE(LuteFixture, "lutepayload_compression_effectiveness")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    LuteExePayload payload{getReporter()};
    payload.add(testFilePath, testFilePath);

    auto encodeResult = payload.encode();
    REQUIRE(encodeResult.has_value());

    // Verify that compression is actually reducing size
    // compressed should be smaller than uncompressed (barring any weird edge cases)
    CHECK(encodeResult->compressedPayloadSizeBytes <= encodeResult->uncompressedPayloadSizeBytes);

    // Verify the total payload includes overhead for metadata
    // Total = compressed data + metadata (sizes, counts, paths, magic flag)
    CHECK(encodeResult->bytesWritten >= encodeResult->compressedPayloadSizeBytes);
}

TEST_CASE_FIXTURE(LuteFixture, "lutepayload_bytecode_integrity")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    // Create two separate payloads with the same file
    LuteExePayload payload1{getReporter()};
    payload1.add(testFilePath, testFilePath);
    auto encode1 = payload1.encode();
    REQUIRE(encode1.has_value());

    LuteExePayload payload2{getReporter()};
    payload2.add(testFilePath, testFilePath);
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

TEST_CASE_FIXTURE(LuteFixture, "lutepayload_validates_numfiles_metadata")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    // Create and encode a valid payload
    LuteExePayload payload{getReporter()};
    payload.add(testFilePath, testFilePath);
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
    auto decodeResult = LuteExePayload::decode(corruptedPayload, getReporter());
    CHECK(!decodeResult.has_value());
}

TEST_CASE_FIXTURE(LuteFixture, "luteexecutable_single_file_roundtrip")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    // Create a temporary dummy executable as the base runtime
    std::string dummyExePath = joinPaths(luteProjectRoot, "tests/temp_dummy_exe");
    {
        std::ofstream dummyExe(dummyExePath, std::ios::binary);
        REQUIRE(dummyExe.is_open());
        // Write some dummy data to simulate an executable
        std::string dummyContent = "FAKE_EXECUTABLE_HEADER_DATA";
        dummyExe.write(dummyContent.data(), dummyContent.size());
        dummyExe.close();
    }

    // Create payload with a test file
    LuteExePayload originalPayload{getReporter()};
    originalPayload.add(testFilePath, testFilePath);

    // Add luaurc config
    Luau::DenseHashMap<std::string, std::string> configs{""};
    configs[".luaurc"] = "{\"aliases\":{\"example\":\"./dep\"}}";
    originalPayload.setLuauConfig(configs);

    // Create LuteExecutable and write it out
    std::string outputExePath = joinPaths(luteProjectRoot, "tests/temp_output_exe");
    LuteExecutable executable{dummyExePath, getReporter()};

    bool createSuccess = executable.create(outputExePath, originalPayload);
    REQUIRE(createSuccess);

    // Verify output file was created
    std::ifstream checkFile(outputExePath, std::ios::binary);
    REQUIRE(checkFile.is_open());
    checkFile.close();

    // Extract the payload from the created executable
    LuteExecutable readExecutable{outputExePath, getReporter()};
    auto extractedPayload = readExecutable.extract();
    REQUIRE(extractedPayload.has_value());

    // Verify entry point matches
    CHECK(extractedPayload->entryPointPath == originalPayload.entryPointPath);

    // Verify the file count matches
    REQUIRE(extractedPayload->filePathToBytecode.size() == 1);

    // Verify bytecode matches
    auto originalBytecodeIt = originalPayload.filePathToBytecode.find(testFilePath);
    auto extractedBytecodeIt = extractedPayload->filePathToBytecode.find(testFilePath);
    REQUIRE(originalBytecodeIt != nullptr);
    REQUIRE(extractedBytecodeIt != nullptr);
    CHECK(*originalBytecodeIt == *extractedBytecodeIt);

    // Verify luaurc config was preserved
    REQUIRE(extractedPayload->luauConfigFiles.size() == 1);
    auto configIt = extractedPayload->luauConfigFiles.find(".luaurc");
    REQUIRE(configIt != nullptr);
    CHECK(configIt->find("aliases") != std::string::npos);

    // Clean up temporary files
    std::remove(dummyExePath.c_str());
    std::remove(outputExePath.c_str());
}

TEST_CASE_FIXTURE(LuteFixture, "luteexecutable_multiple_files_roundtrip")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");

    std::vector<std::string> testFiles = {
        joinPaths(testDir, "main.luau"), joinPaths(testDir, "utils.luau"), joinPaths(testDir, "lib/helper.luau"), joinPaths(testDir, "shared.luau")
    };

    // Create a temporary dummy executable
    std::string dummyExePath = joinPaths(luteProjectRoot, "tests/temp_dummy_exe_multi");
    {
        std::ofstream dummyExe(dummyExePath, std::ios::binary);
        REQUIRE(dummyExe.is_open());
        std::string dummyContent = "FAKE_EXECUTABLE_WITH_LONGER_HEADER_TO_TEST_MULTI_FILE";
        dummyExe.write(dummyContent.data(), dummyContent.size());
        dummyExe.close();
    }

    // Create payload with multiple files
    LuteExePayload originalPayload{getReporter()};
    for (const auto& file : testFiles)
    {
        originalPayload.add(file, file);
    }

    // Add luaurc config
    Luau::DenseHashMap<std::string, std::string> configs{""};
    configs[".luaurc"] = "{\"aliases\":{\"example\":\"./dep\"}}";
    originalPayload.setLuauConfig(configs);

    // First file should be the entry point
    CHECK(originalPayload.entryPointPath == testFiles[0]);

    // Create the executable
    std::string outputExePath = joinPaths(luteProjectRoot, "tests/temp_output_exe_multi");
    LuteExecutable executable{dummyExePath, getReporter()};

    bool createSuccess = executable.create(outputExePath, originalPayload);
    REQUIRE(createSuccess);

    // Extract the payload
    LuteExecutable readExecutable{outputExePath, getReporter()};
    auto extractedPayload = readExecutable.extract();
    REQUIRE(extractedPayload.has_value());

    // Verify entry point
    CHECK(extractedPayload->entryPointPath == testFiles[0]);

    // Verify all files are present
    REQUIRE(extractedPayload->filePathToBytecode.size() == testFiles.size());

    // Verify each file's bytecode matches
    for (const auto& file : testFiles)
    {
        auto extractedIt = extractedPayload->filePathToBytecode.find(file);
        REQUIRE(extractedIt != nullptr);

        auto originalIt = originalPayload.filePathToBytecode.find(file);
        REQUIRE(originalIt != nullptr);

        CHECK(*extractedIt == *originalIt);
    }

    // Verify luaurc config was preserved
    REQUIRE(extractedPayload->luauConfigFiles.size() == 1);
    auto configIt = extractedPayload->luauConfigFiles.find(".luaurc");
    REQUIRE(configIt != nullptr);
    CHECK(configIt->find("aliases") != std::string::npos);

    // Clean up
    std::remove(dummyExePath.c_str());
    std::remove(outputExePath.c_str());
}

TEST_CASE_FIXTURE(LuteFixture, "luteexecutable_extract_from_plain_executable")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();

    // Create a plain executable without any embedded payload
    std::string plainExePath = joinPaths(luteProjectRoot, "tests/temp_plain_exe");
    {
        std::ofstream plainExe(plainExePath, std::ios::binary);
        REQUIRE(plainExe.is_open());
        std::string content = "PLAIN_EXECUTABLE_NO_PAYLOAD";
        plainExe.write(content.data(), content.size());
        plainExe.close();
    }

    // Attempt to extract - should return nullopt since there's no payload
    LuteExecutable executable{plainExePath, getReporter()};
    auto extractedPayload = executable.extract();
    CHECK(!extractedPayload.has_value());

    // Clean up
    std::remove(plainExePath.c_str());
}

TEST_CASE_FIXTURE(LuteFixture, "luteexecutable_extract_preserves_original_executable")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    // Create dummy executable with specific content
    std::string dummyExePath = joinPaths(luteProjectRoot, "tests/temp_dummy_exe_preserve");
    std::string originalExeContent = "ORIGINAL_EXE_CONTENT_12345";
    {
        std::ofstream dummyExe(dummyExePath, std::ios::binary);
        REQUIRE(dummyExe.is_open());
        dummyExe.write(originalExeContent.data(), originalExeContent.size());
        dummyExe.close();
    }

    // Create payload and executable
    LuteExePayload payload{getReporter()};
    payload.add(testFilePath, testFilePath);

    std::string outputExePath = joinPaths(luteProjectRoot, "tests/temp_output_exe_preserve");
    LuteExecutable executable{dummyExePath, getReporter()};
    bool createSuccess = executable.create(outputExePath, payload);
    REQUIRE(createSuccess);

    // Read the output file and verify the original executable content is at the beginning
    std::ifstream outputFile(outputExePath, std::ios::binary);
    REQUIRE(outputFile.is_open());

    std::vector<char> buffer(originalExeContent.size());
    outputFile.read(buffer.data(), buffer.size());
    outputFile.close();

    std::string extractedPrefix(buffer.begin(), buffer.end());
    CHECK(extractedPrefix == originalExeContent);

    // Clean up
    std::remove(dummyExePath.c_str());
    std::remove(outputExePath.c_str());
}

TEST_CASE_FIXTURE(LuteFixture, "compile_command_e2e")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();

    // Use a simple test file that prints something we can verify
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/main.luau");

    // Create a temporary output path for the compiled executable
    std::string outputExePath = joinPaths(luteProjectRoot, "tests/temp_compiled_e2e");
#ifdef _WIN32
    outputExePath += ".exe";
#endif

    // Build argv for cliMain: ["lute", "compile", <testFilePath>, "--output", <outputExePath>]
    char executablePlaceholder[] = "lute";
    char compileCommand[] = "compile";
    char outputFlag[] = "--output";

    std::vector<char*> argv = {executablePlaceholder, compileCommand, testFilePath.data(), outputFlag, outputExePath.data()};

    // Run the compile command
    int compileResult = cliMain(argv.size(), argv.data(), getReporter());
    REQUIRE(compileResult == 0);

    // Verify the output file was created
    std::ifstream checkFile(outputExePath, std::ios::binary);
    REQUIRE(checkFile.is_open());
    checkFile.close();

    // Now run the compiled executable to verify it works
    std::vector<char*> runArgv = {outputExePath.data()};
    int runResult = cliMain(runArgv.size(), runArgv.data(), getReporter());
    CHECK(runResult == 0);

    // Clean up
    std::remove(outputExePath.c_str());
}
