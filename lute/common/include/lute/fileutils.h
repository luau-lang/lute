// This file is part of the Lute programming language and is licensed under MIT License
#pragma once

#include <string>

namespace Lute
{

// Open a file with platform-specific handling (wfopen on Windows, fopen elsewhere)
FILE* openFile(const std::string& path, const char* mode);

// Write string content to a file
bool writeFile(const std::string& path, const std::string& content);

// Create a directory (non-recursive)
bool createDirectory(const std::string& path);

// Create directories recursively (equivalent to mkdir -p)
bool createDirectories(const std::string& path);

// Remove a file
bool removeFile(const std::string& path);

// Remove a directory (must be empty)
bool removeDirectory(const std::string& path);

bool isDirectory(const std::string& path);

// Get the name of a file without its extension
std::string getFilenameWithoutExtension(const std::string& path);

} // namespace Lute
