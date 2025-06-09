#include "lute/compile.h"

#include "lute/options.h"
#include "uv.h"

#include <fstream>

const char MAGIC_FLAG[] = "LUTEBYTE";
const size_t MAGIC_FLAG_SIZE = sizeof(MAGIC_FLAG) - 1;
const size_t BYTECODE_SIZE_FIELD_SIZE = sizeof(uint64_t);

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

int compileScript(const std::string& inputFilePath, const std::string& outputFilePath, const std::string& currentExecutablePath)
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

    std::ifstream exeFile(currentExecutablePath, std::ios::binary | std::ios::ate);
    if (!exeFile)
    {
        fprintf(stderr, "Error opening current executable %s\n", currentExecutablePath.c_str());
        return 1;
    }
    std::streamsize exeSize = exeFile.tellg();
    exeFile.seekg(0, std::ios::beg);
    std::vector<char> exeBuffer(exeSize);
    if (!exeFile.read(exeBuffer.data(), exeSize))
    {
         fprintf(stderr, "Error reading current executable %s\n", currentExecutablePath.c_str());
         exeFile.close();
         return 1;
    }
    exeFile.close();

    std::ofstream outFile(outputFilePath, std::ios::binary | std::ios::trunc);
    if (!outFile) {
        fprintf(stderr, "Error creating output file %s\n", outputFilePath.c_str());
        return 1;
    }

    outFile.write(exeBuffer.data(), exeSize);

    uint64_t bytecodeSize = bytecode.size();
    outFile.write(bytecode.data(), bytecodeSize);

    outFile.write(reinterpret_cast<const char*>(&bytecodeSize), BYTECODE_SIZE_FIELD_SIZE);

    outFile.write(MAGIC_FLAG, MAGIC_FLAG_SIZE);

    if (!outFile.good())
    {
         fprintf(stderr, "Error writing to output file %s\n", outputFilePath.c_str());
         outFile.close();
         remove(outputFilePath.c_str());
         return 1;
    }

    outFile.close();

    printf("Successfully compiled %s to %s\n", inputFilePath.c_str(), outputFilePath.c_str());
#ifndef _WIN32
    chmod(outputFilePath.c_str(), S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
#endif

    return 0;
}
