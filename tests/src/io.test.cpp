#include "cliruntimefixture.h"
#include "doctest.h"

#include <cstdio>
#include <string>

#ifdef _WIN32
#include <io.h>
static int stdoutFd() { return _fileno(stdout); }
static int dupFd(int fd) { return _dup(fd); }
static void dup2Fd(int src, int dst) { _dup2(src, dst); }
static void closeFd(int fd) { _close(fd); }
static int fileFd(FILE* f) { return _fileno(f); }
#else
#include <unistd.h>
static int stdoutFd() { return STDOUT_FILENO; }
static int dupFd(int fd) { return dup(fd); }
static void dup2Fd(int src, int dst) { dup2(src, dst); }
static void closeFd(int fd) { close(fd); }
static int fileFd(FILE* f) { return fileno(f); }
#endif

// Redirects stdout to a temporary file for the duration of the test.
// Restores stdout on destruction.
struct StdoutCapture
{
    FILE* tmpf = nullptr;
    int savedFd = -1;

    StdoutCapture()
    {
        // Flush any pending output before redirecting so it goes to the real stdout
        fflush(stdout);

        tmpf = tmpfile();
        REQUIRE(tmpf != nullptr);
        savedFd = dupFd(stdoutFd());
        REQUIRE(savedFd != -1);
        dup2Fd(fileFd(tmpf), stdoutFd());
    }

    ~StdoutCapture()
    {
        fflush(stdout);
        dup2Fd(savedFd, stdoutFd());
        closeFd(savedFd);
        fclose(tmpf);
    }

    // Returns whatever has been flushed to the temp file so far
    std::string readFlushed()
    {
        rewind(tmpf);
        std::string result;
        char buf[256];
        size_t n;
        while ((n = fread(buf, 1, sizeof(buf), tmpf)) > 0)
            result.append(buf, n);
        return result;
    }
};

TEST_CASE_FIXTURE(CliRuntimeFixture, "io_flush_flushes_buffered_output")
{
    StdoutCapture cap;

    // Write to stdout without a newline — stays in the C stdio buffer
    fprintf(stdout, "buffered");

    // Verify it hasn't reached the file yet (still in the C stdio buffer)
    CHECK(cap.readFlushed() == "");

    // Flush via the Luau API
    bool ok = runCode(R"(
        local io = require("@lute/io")
        io.flush()
    )");
    CHECK(ok);
    CHECK(getReporter().getErrors().empty());

    // Now the buffered write should be visible in the file
    CHECK(cap.readFlushed() == "buffered");
}

TEST_CASE_FIXTURE(CliRuntimeFixture, "std_io_flush_flushes_buffered_output")
{
    StdoutCapture cap;

    fprintf(stdout, "std_buffered");
    CHECK(cap.readFlushed() == "");

    bool ok = runCode(R"(
        local io = require("@std/io")
        io.flush()
    )");
    CHECK(ok);
    CHECK(getReporter().getErrors().empty());

    CHECK(cap.readFlushed() == "std_buffered");
}
