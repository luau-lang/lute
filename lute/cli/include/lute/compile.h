#pragma once

#include "Luau/FileUtils.h"

struct AppendedBytecodeResult
{
    bool found = false;
    std::string BytecodeData;
};

AppendedBytecodeResult checkForAppendedBytecode();

int compileScript(const std::string& inputFilePath, const std::string& outputFilePath);
