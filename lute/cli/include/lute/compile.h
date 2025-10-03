#pragma once

#include "Luau/FileUtils.h"

#include <filesystem>
#include <optional>

struct AppendedBytecodeResult
{
    bool found = false;
    std::string BytecodeData;
};

AppendedBytecodeResult checkForAppendedBytecode(const std::string& executablePath);

std::string getBinaryName(const std::string& target);
std::filesystem::path getCachePath(const std::string& version, const std::string& target);
bool downloadBinary(const std::string& url, const std::filesystem::path& outputPath);
std::optional<std::filesystem::path> ensureBinaryAvailable(const std::string& target);

int compileScript(const std::string& inputFilePath, const std::string& outputFilePath, const std::string& currentExecutablePath, const std::optional<std::string>& target = std::nullopt);
