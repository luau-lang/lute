#include <cstdlib>
#include <filesystem>

std::string findUserPath() {
	#ifdef _WIN32
	const auto userProfilePath = getenv("USERPROFILE");
	#elif
	const auto userProfilePath = "~";
	#endif
	
	return std::string(userProfilePath);
}

const std::string luteDirectoryPath() {
	return findUserPath().append("/.lute");
}

bool checkForLute() {
	auto luteDirectory = luteDirectoryPath();
	
	return std::filesystem::is_directory(luteDirectory);
}

void createLuteDirectory() {
	const auto luteDirectory = findUserPath().append("/.lute");
	
	if (!std::filesystem::exists(luteDirectory)) {
		std::filesystem::create_directory(luteDirectory);
	};
}

void createLuaurc() {
	
}

int writeTypeDefs() {
	
}