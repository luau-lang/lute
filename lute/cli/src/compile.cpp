#include "lute/compile.h"

#include "lute/options.h"
#include "uv.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <optional>
#include <string>
#include <system_error>
#include <vector>

#include <curl/curl.h>
#include <zlib.h>

#ifndef _WIN32
#include <sys/stat.h>
#endif

const char MAGIC_FLAG[] = "LUTEBYTE";
const size_t MAGIC_FLAG_SIZE = sizeof(MAGIC_FLAG) - 1;
const size_t BYTECODE_SIZE_FIELD_SIZE = sizeof(uint64_t);

namespace
{

constexpr const char* kReleaseVersion = "0.1.0-nightly.20251003";
constexpr const char* kDownloadBaseUrl = "https://github.com/luau-lang/lute/releases/download/";
constexpr size_t kZipCommentMax = 0xFFFF;

struct CurlGlobalInit
{
    CurlGlobalInit()
    {
        curl_global_init(CURL_GLOBAL_DEFAULT);
    }

    ~CurlGlobalInit()
    {
        curl_global_cleanup();
    }
};

void ensureCurlInitialized()
{
    static CurlGlobalInit init;
    (void)init;
}

size_t curlWriteCallback(void* contents, size_t size, size_t nmemb, void* userp)
{
    std::ofstream* out = static_cast<std::ofstream*>(userp);
    const size_t total = size * nmemb;

    out->write(static_cast<const char*>(contents), total);
    if (!out->good())
        return 0;

    return total;
}

uint16_t readLE16(const uint8_t* data)
{
    return static_cast<uint16_t>(data[0] | (data[1] << 8));
}

uint32_t readLE32(const uint8_t* data)
{
    return static_cast<uint32_t>(data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24));
}

std::string deduceTargetFromOutput(const std::filesystem::path& outputPath)
{
    std::string name = outputPath.filename().string();

    const std::string prefix = "lute-";
    if (name.rfind(prefix, 0) == 0)
        name = name.substr(prefix.size());

    const std::string exeExt = ".exe";
    if (name.size() > exeExt.size() && name.compare(name.size() - exeExt.size(), exeExt.size(), exeExt) == 0)
        name = name.substr(0, name.size() - exeExt.size());

    return name;
}

bool extractBinaryFromZip(const std::filesystem::path& zipPath, const std::filesystem::path& outputPath)
{
    constexpr uint32_t kLocalHeaderSignature = 0x04034b50;
    constexpr uint32_t kCentralHeaderSignature = 0x02014b50;
    constexpr uint32_t kEndOfCentralDirSignature = 0x06054b50;

    std::ifstream input(zipPath, std::ios::binary);
    if (!input)
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    std::vector<uint8_t> buffer((std::istreambuf_iterator<char>(input)), std::istreambuf_iterator<char>());
    input.close();

    if (buffer.size() < 22)
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    size_t minSearch = buffer.size() > (kZipCommentMax + 22) ? buffer.size() - (kZipCommentMax + 22) : 0;
    size_t pos = buffer.size() - 22;
    bool foundEocd = false;
    size_t eocdIndex = 0;

    while (true)
    {
        if (pos + 4 <= buffer.size() && readLE32(buffer.data() + pos) == kEndOfCentralDirSignature)
        {
            foundEocd = true;
            eocdIndex = pos;
            break;
        }

        if (pos == minSearch)
            break;

        if (pos == 0)
            break;

        --pos;
    }

    if (!foundEocd)
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    if (eocdIndex + 22 > buffer.size())
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    const uint8_t* eocd = buffer.data() + eocdIndex;
    uint16_t totalEntries = readLE16(eocd + 10);
    uint32_t centralDirectoryOffset = readLE32(eocd + 16);

    if (centralDirectoryOffset + 46 > buffer.size())
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    struct ZipEntry
    {
        std::string name;
        uint16_t compressionMethod = 0;
        uint32_t compressedSize = 0;
        uint32_t uncompressedSize = 0;
        uint32_t localHeaderOffset = 0;
    };

    std::vector<ZipEntry> entries;
    entries.reserve(totalEntries);

    size_t currentOffset = centralDirectoryOffset;
    for (uint16_t i = 0; i < totalEntries; ++i)
    {
        if (currentOffset + 46 > buffer.size())
        {
            fprintf(stderr, "Failed to extract binary from downloaded archive\n");
            return false;
        }

        const uint8_t* centralHeader = buffer.data() + currentOffset;
        if (readLE32(centralHeader) != kCentralHeaderSignature)
        {
            fprintf(stderr, "Failed to extract binary from downloaded archive\n");
            return false;
        }

        uint16_t fileNameLength = readLE16(centralHeader + 28);
        uint16_t extraFieldLength = readLE16(centralHeader + 30);
        uint16_t fileCommentLength = readLE16(centralHeader + 32);

        if (currentOffset + 46 + fileNameLength > buffer.size())
        {
            fprintf(stderr, "Failed to extract binary from downloaded archive\n");
            return false;
        }

        ZipEntry entry;
        entry.compressionMethod = readLE16(centralHeader + 10);
        entry.compressedSize = readLE32(centralHeader + 20);
        entry.uncompressedSize = readLE32(centralHeader + 24);
        entry.localHeaderOffset = readLE32(centralHeader + 42);
        entry.name.assign(reinterpret_cast<const char*>(centralHeader + 46), fileNameLength);

        entries.push_back(entry);

        currentOffset += 46 + fileNameLength + extraFieldLength + fileCommentLength;
        if (currentOffset > buffer.size())
        {
            fprintf(stderr, "Failed to extract binary from downloaded archive\n");
            return false;
        }
    }

    if (entries.empty())
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    std::string desiredName = outputPath.filename().string();
    auto matchEntry = std::find_if(entries.begin(), entries.end(), [&](const ZipEntry& entry) {
        return entry.name == desiredName;
    });

    if (matchEntry == entries.end())
    {
        matchEntry = std::find_if(entries.begin(), entries.end(), [](const ZipEntry& entry) {
            return !entry.name.empty() && entry.name.back() != '/';
        });
    }

    if (matchEntry == entries.end())
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    const ZipEntry& entry = *matchEntry;

    if (entry.name.empty() || entry.name.back() == '/')
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    if (entry.localHeaderOffset + 30 > buffer.size())
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    const uint8_t* localHeader = buffer.data() + entry.localHeaderOffset;
    if (readLE32(localHeader) != kLocalHeaderSignature)
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    uint16_t localNameLength = readLE16(localHeader + 26);
    uint16_t localExtraLength = readLE16(localHeader + 28);

    size_t dataOffset = entry.localHeaderOffset + 30 + localNameLength + localExtraLength;
    if (dataOffset > buffer.size())
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    if (dataOffset + entry.compressedSize > buffer.size())
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    const uint8_t* compressedData = buffer.data() + dataOffset;

    std::vector<uint8_t> decompressed;
    if (entry.compressionMethod == 0)
    {
        decompressed.assign(compressedData, compressedData + entry.compressedSize);
    }
    else if (entry.compressionMethod == 8)
    {
        decompressed.resize(entry.uncompressedSize);

        z_stream stream{};
        stream.next_in = const_cast<Bytef*>(compressedData);
        stream.avail_in = entry.compressedSize;
        stream.next_out = reinterpret_cast<Bytef*>(decompressed.data());
        stream.avail_out = entry.uncompressedSize;

        if (inflateInit2(&stream, -MAX_WBITS) != Z_OK)
        {
            fprintf(stderr, "Failed to extract binary from downloaded archive\n");
            return false;
        }

        int status = inflate(&stream, Z_FINISH);
        inflateEnd(&stream);

        if (status != Z_STREAM_END)
        {
            fprintf(stderr, "Failed to extract binary from downloaded archive\n");
            return false;
        }
    }
    else
    {
        fprintf(stderr, "Failed to extract binary from downloaded archive\n");
        return false;
    }

    std::ofstream output(outputPath, std::ios::binary | std::ios::trunc);
    if (!output)
    {
        fprintf(stderr, "Permission denied writing to cache\n");
        return false;
    }

    output.write(reinterpret_cast<const char*>(decompressed.data()), decompressed.size());
    if (!output.good())
    {
        fprintf(stderr, "Permission denied writing to cache\n");
        return false;
    }

    output.close();
    return true;
}

} // namespace

std::string getBinaryName(const std::string& target)
{
    if (target == "windows-x86_64")
        return "lute-windows-x86_64.exe";

    return "lute-" + target;
}

std::filesystem::path getCachePath(const std::string& version, const std::string& target)
{
    std::filesystem::path base;

#ifdef _WIN32
    const char* localAppData = std::getenv("LOCALAPPDATA");
    if (localAppData && *localAppData)
        base = std::filesystem::path(localAppData);
    else
        base = std::filesystem::temp_directory_path();
#else
    const char* xdgCacheHome = std::getenv("XDG_CACHE_HOME");
    if (xdgCacheHome && *xdgCacheHome)
        base = std::filesystem::path(xdgCacheHome);
    else
    {
        const char* home = std::getenv("HOME");
        if (!home || !*home)
        {
            fprintf(stderr, "Unable to create cache directory\n");
            return {};
        }
        base = std::filesystem::path(home) / ".cache";
    }
#endif

    base /= "lute";
    base /= "compile-binaries";

    std::filesystem::path versionDir = base / version;

    std::error_code ec;
    std::filesystem::create_directories(versionDir, ec);
    if (ec)
    {
        fprintf(stderr, "Unable to create cache directory\n");
        return {};
    }

    return versionDir / getBinaryName(target);
}

bool downloadBinary(const std::string& url, const std::filesystem::path& outputPath)
{
    ensureCurlInitialized();

    std::filesystem::path tempPath = outputPath;
    tempPath += ".download";

    std::ofstream tempStream(tempPath, std::ios::binary | std::ios::trunc);
    if (!tempStream)
    {
        fprintf(stderr, "Permission denied writing to cache\n");
        return false;
    }

    CURL* curl = curl_easy_init();
    if (!curl)
    {
        fprintf(stderr, "Failed to download binary for target %s\n", deduceTargetFromOutput(outputPath).c_str());
        return false;
    }

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_FAILONERROR, 1L);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curlWriteCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &tempStream);

    CURLcode res = curl_easy_perform(curl);
    long responseCode = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &responseCode);

    tempStream.flush();
    tempStream.close();

    std::string targetName = deduceTargetFromOutput(outputPath);

    if (res != CURLE_OK)
    {
        if (res == CURLE_HTTP_RETURNED_ERROR && responseCode == 404)
            fprintf(stderr, "Binary not available for target %s version %s\n", targetName.c_str(), kReleaseVersion);
        else if (res == CURLE_HTTP_RETURNED_ERROR)
            fprintf(stderr, "Failed to download binary for target %s\n", targetName.c_str());
        else if (res == CURLE_COULDNT_RESOLVE_HOST || res == CURLE_COULDNT_CONNECT)
            fprintf(stderr, "Unable to download binary: No network connection\n");
        else
            fprintf(stderr, "Failed to download binary for target %s\n", targetName.c_str());

        curl_easy_cleanup(curl);

        std::error_code cleanupEc;
        std::filesystem::remove(tempPath, cleanupEc);
        return false;
    }

    curl_easy_cleanup(curl);

    if (!extractBinaryFromZip(tempPath, outputPath))
    {
        std::error_code cleanupEc;
        std::filesystem::remove(tempPath, cleanupEc);
        std::filesystem::remove(outputPath, cleanupEc);
        return false;
    }

    std::error_code removeEc;
    std::filesystem::remove(tempPath, removeEc);

#ifndef _WIN32
    std::error_code permEc;
    std::filesystem::permissions(outputPath,
        std::filesystem::perms::owner_all |
        std::filesystem::perms::group_read |
        std::filesystem::perms::group_exec |
        std::filesystem::perms::others_read |
        std::filesystem::perms::others_exec,
        permEc);
#endif

    return true;
}

std::optional<std::filesystem::path> ensureBinaryAvailable(const std::string& target)
{
    std::filesystem::path cacheBinary = getCachePath(kReleaseVersion, target);
    if (cacheBinary.empty())
        return std::nullopt;

    std::error_code ec;
    if (std::filesystem::exists(cacheBinary, ec) && !ec)
    {
        printf("Using cached binary for target %s\n", target.c_str());
        return cacheBinary;
    }

    std::string url = std::string(kDownloadBaseUrl) + kReleaseVersion + "/lute-" + target + ".zip";
    printf("Downloading binary for target %s...\n", target.c_str());
    if (!downloadBinary(url, cacheBinary))
        return std::nullopt;

    return cacheBinary;
}

AppendedBytecodeResult checkForAppendedBytecode(const std::string& executablePath)
{
    AppendedBytecodeResult result;
    std::ifstream exeFile(executablePath, std::ios::binary | std::ios::ate);
    if (!exeFile)
    {
        return result;
    }

    std::streampos fileSize = exeFile.tellg();
    if (fileSize < static_cast<std::streampos>(MAGIC_FLAG_SIZE + BYTECODE_SIZE_FIELD_SIZE))
    {
        exeFile.close();
        return result;
    }

    std::vector<char> flagBuffer(MAGIC_FLAG_SIZE);
    exeFile.seekg(fileSize - static_cast<std::streampos>(MAGIC_FLAG_SIZE));
    exeFile.read(flagBuffer.data(), MAGIC_FLAG_SIZE);

    if (memcmp(flagBuffer.data(), MAGIC_FLAG, MAGIC_FLAG_SIZE) != 0)
    {
        exeFile.close();
        return result;
    }

    uint64_t BytecodeSize;
    exeFile.seekg(fileSize - static_cast<std::streampos>(MAGIC_FLAG_SIZE + BYTECODE_SIZE_FIELD_SIZE));
    exeFile.read(reinterpret_cast<char*>(&BytecodeSize), BYTECODE_SIZE_FIELD_SIZE);

    if (fileSize < static_cast<std::streampos>(MAGIC_FLAG_SIZE + BYTECODE_SIZE_FIELD_SIZE + BytecodeSize)) {
        fprintf(stderr, "Warning: Found magic flag but file size inconsistent.\n");
        exeFile.close();
        return result;
    }

    result.BytecodeData.resize(BytecodeSize);
    exeFile.seekg(fileSize - static_cast<std::streampos>(MAGIC_FLAG_SIZE + BYTECODE_SIZE_FIELD_SIZE + BytecodeSize));
    exeFile.read(&result.BytecodeData[0], BytecodeSize);

    exeFile.close();
    result.found = true;
    return result;
}

int compileScript(const std::string& inputFilePath, const std::string& outputFilePath, const std::string& currentExecutablePath, const std::optional<std::string>& target)
{
    std::optional<std::string> source = readFile(inputFilePath);
    if (!source)
    {
        fprintf(stderr, "Error opening input file %s\n", inputFilePath.c_str());
        return 1;
    }

    std::string bytecode = Luau::compile(*source, copts());
    if (bytecode.empty())
    {
        fprintf(stderr, "Error compiling %s to bytecode.\n", inputFilePath.c_str());
        return 1;
    }

    std::filesystem::path baseExecutable = currentExecutablePath;
    if (target)
    {
        std::optional<std::filesystem::path> cached = ensureBinaryAvailable(*target);
        if (!cached)
            return 1;
        baseExecutable = *cached;
    }

    std::filesystem::path outputPath = outputFilePath;
    std::string templateExtension = baseExecutable.extension().string();
    if (!templateExtension.empty())
        outputPath.replace_extension(templateExtension);

    std::string finalOutputPath = outputPath.string();

    std::ifstream exeFile(baseExecutable, std::ios::binary | std::ios::ate);
    if (!exeFile)
    {
        fprintf(stderr, "Error opening template executable %s\n", baseExecutable.string().c_str());
        return 1;
    }
    std::streamsize exeSize = exeFile.tellg();
    exeFile.seekg(0, std::ios::beg);
    std::vector<char> exeBuffer(exeSize);
    if (!exeFile.read(exeBuffer.data(), exeSize))
    {
         fprintf(stderr, "Error reading template executable %s\n", baseExecutable.string().c_str());
         exeFile.close();
         return 1;
    }
    exeFile.close();

    std::ofstream outFile(finalOutputPath, std::ios::binary | std::ios::trunc);
    if (!outFile) {
        fprintf(stderr, "Error creating output file %s\n", finalOutputPath.c_str());
        return 1;
    }

    outFile.write(exeBuffer.data(), exeSize);

    uint64_t bytecodeSize = bytecode.size();
    outFile.write(bytecode.data(), bytecodeSize);

    outFile.write(reinterpret_cast<const char*>(&bytecodeSize), BYTECODE_SIZE_FIELD_SIZE);

    outFile.write(MAGIC_FLAG, MAGIC_FLAG_SIZE);

    if (!outFile.good())
    {
         fprintf(stderr, "Error writing to output file %s\n", finalOutputPath.c_str());
         outFile.close();
         remove(finalOutputPath.c_str());
         return 1;
    }

    outFile.close();

    printf("Successfully compiled %s to %s\n", inputFilePath.c_str(), finalOutputPath.c_str());
#ifndef _WIN32
    chmod(finalOutputPath.c_str(), S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
#endif

    return 0;
}
