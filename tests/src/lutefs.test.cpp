#include "lute/fileutils.h"

#include "Luau/FileUtils.h"

#include <string>

#include "cliruntimefixture.h"
#include "doctest.h"
#include "luteprojectroot.h"

TEST_CASE_FIXTURE(CliRuntimeFixture, "fs_open_write_read_close")
{
    std::string testFile = "./tmp/lute_test_file.txt";
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string localTmpDir = joinPaths(luteProjectRoot, "./tmp");

    // Clean up any existing file
    Lute::removeFile(testFile);
    Lute::createDirectories(localTmpDir);
    runCode(
        R"(
        local fs = require("@lute/fs")
        local path = ")" +
        testFile + R"("

        -- Open file for writing
        local h = fs.open(path, "w+")

        -- Write some data
        fs.write(h, "Hello, World!")

        -- Close the file
        fs.close(h)

        -- Open file for reading
        local hr = fs.open(path, "r")
        assert(hr ~= nil, "File handle for reading should not be nil")

        -- Read the data
        local content = fs.read(hr)
        local correctness = content == "Hello, World!"

        -- Close the read handle
        fs.close(hr)

        report(content)
        report(correctness)
    )"
    );

    CHECK(getReporter().getOutputs()[0] == "Hello, World!");
    CHECK(getReporter().getOutputs()[1] == "true");

    // Clean up
    Lute::removeFile(testFile);
    Lute::removeDirectory(localTmpDir);
}
