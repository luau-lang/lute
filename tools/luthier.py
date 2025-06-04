#!/usr/bin/env python3

import argparse
import os
import tomllib # minimum python 3.11
import subprocess as sp
import sys

from os import path
from hashlib import blake2b

cwd = os.getcwd()

def gitVersion():
    gitVersionString = sp.check_output(['git', '--version'])
    gitVersion = gitVersionString.decode('utf-8').strip().split()[2]
    components = gitVersion.split('.')
    return { 'major': int(components[0]), 'minor': int(components[1]), 'patch': int(components[2]) }

gitVersionInfo = gitVersion()

class ReportableError(Exception):
    """This error object is used to indicate an error should be reported to the user
       without a full stack trace."""
    pass

isMsys = any(sys.platform.startswith(x) for x in ('msys', 'cygwin'))
isWindows = isMsys or sys.platform.startswith('win32')
isMac = sys.platform.startswith('darwin')
isLinux = sys.platform.startswith('linux')
isUnix = not isWindows

targetMap = {
    'lute': {
        'exeName': 'lute/cli/lute',
    },
    'Lute.CLI': {
        'exeName': 'lute/cli/lute',
    },
    'Lute.Test': {
        'exeName': 'tests/lute-tests',
    },
}

argParser = argparse.ArgumentParser(description='crafting a lute!', formatter_class=argparse.RawDescriptionHelpFormatter)

argParser.add_argument(
    'subcommand', help='command to execute',
    metavar="CMD",
    choices=['configure', 'tune', 'build', 'craft', 'run', 'play', 'fetch'],
)

argParser.add_argument(
    'target', help='the thing to build or run',
    metavar="TARGET",
    default="lute",
    choices=targetMap.keys(),
)

argParser.add_argument(
    '-v', '--verbose', dest='verbose', action='store_true',
    help='show verbose compile output'
)

argParser.add_argument(
    '--config', dest='config', action='store',
    choices=['debug', 'release'],
    default='debug',
    help='configuration (default is debug)'
)

argParser.add_argument(
    '--clean', dest='clean', action='store_true',
    help='perform a clean build'
)

argParser.add_argument(
    '--which', '-w', dest='which', action='store_true',
    help='print out the path to the compiled binary and exit'
)

argParser.add_argument(
    '--cxx-compiler', dest='cxx_compiler', action='store',
    help='C++ compiler to use',
)

argParser.add_argument(
    '--c-compiler', dest='c_compiler', action='store',
    help='C compiler to use',
)

if not isWindows and not isMac and not isLinux:
    raise ReportableError('Unknown platform ' + sys.platform)

argParser.epilog = """
valid subcommands:
  * fetch
  * configure (or tune)
  * build (or craft)
  * run (or play)

"""
argParser.epilog += 'valid targets:\n  * ' + '\n  * '.join(sorted(targetMap.keys()))
argParser.epilog += """

note: this script optionally supports the 'argcomplete' module (if installed) to provide
tab completion of command line arguments.  see the documentation for argcomplete for
more setup instructions.
"""

def getSourceRoot():
    cwd = os.getcwd()

    while True:
        if path.isfile(path.join(cwd, '.LUTE_SENTINEL')):
            return cwd

        (newcwd, _) = path.split(cwd)
        if newcwd == cwd:
            break

        cwd = newcwd

    if 'LUTE_ROOT_DIR' in os.environ:
        return os.environ['LUTE_ROOT_DIR']

    raise ReportableError(
        'Could not locate lute project root.  Your cwd must be in your lute checkout, or the LUTE_ROOT_DIR environment variable must be set.')

def cygpath(path):
    if isMsys:
        return sp.check_output(['cygpath', '-u', path]).strip()
    else:
        return path

def winpath(path):
    if isMsys:
        return sp.check_output(['cygpath', '-wa', path]).strip()
    else:
        return path

def getExeName(target):
    baseName = targetMap[target].get('exeName', target)
    assert(baseName)
    ext = '.exe' if isWindows else ''
    return baseName + ext

def getCompiler(args):
    if isMac:
        return 'xcode'
    else:
        return 'vs2022'

def getConfig(args):
    return args.config

def getProjectPath(args):
    buildDir = "build"

    config = getConfig(args).lower()

    if isLinux:
        return os.path.join(buildDir, config)
    else:
        return os.path.join(buildDir, getCompiler(args), config)

def projectPathExists(args):
    projectPath = getProjectPath(args)

    return path.isdir(projectPath)

def getStdLibHash():
    restoredPath = os.getcwd()
    os.chdir(os.path.join(getSourceRoot(), 'lute/std/libs'))

    hasher = blake2b()
    for dirpath, _, filenames in os.walk('.'):
        for filename in sorted(filenames):
            filepath = os.path.join(dirpath, filename)
            hasher.update(filepath.encode('utf-8'))
            with open(filepath, 'rb') as f:
                while chunk := f.read(1024):
                    hasher.update(chunk)

    os.chdir(restoredPath)
    return hasher.hexdigest()

def isGeneratedStdLibUpToDate():
    hashFile = os.path.join(getSourceRoot(), 'lute/std/src/generated/hash.txt')

    if not os.path.isfile(hashFile):
        return False

    with open(hashFile, 'r') as f:
        lines = f.readlines()
        assert(len(lines) == 1)
        actual = lines[0]
        expected = getStdLibHash()
        return actual == expected

    return False

def generateStdLibFilesIfNeeded():
    restoredPath = os.getcwd()

    os.chdir(os.path.join(getSourceRoot(), 'lute/std'))
    os.makedirs("src/generated", exist_ok=True)

    if (isGeneratedStdLibUpToDate()):
        os.chdir(restoredPath)
        return
    else:
        print("Generating code for @std libraries, files are out of date.")

    with open("src/generated/modules.cpp", "w") as cpp:
        cpp.writelines([
            "// This file is auto-generated by luthier.py. Do not edit.\n",
            "// Instead, you should modify the source files in `std/libs`.\n"
            "\n",
            '#include "modules.h"\n',
            "\n",
            "constexpr std::pair<std::string_view, std::string_view> lutestdlib[] = {\n",
        ])

    os.chdir("./libs")

    numItems = 0
    for dirpath, dirnames, filenames in os.walk("."):
        for dirname in dirnames:
            path = os.path.join(dirpath, dirname).replace("\\", "/")
            aliasedPath = path.replace("./", "@std/", 1)

            with open("../src/generated/modules.cpp", "a") as cpp:
                cpp.write("\n    {\"" + aliasedPath + "\", \"#directory\"},\n")
                numItems += 1

        for filename in filenames:
            path = os.path.join(dirpath, filename).replace("\\", "/")
            aliasedPath = path.replace("./", "@std/", 1)

            with open(path, "r") as script:
                lines = script.readlines()

            with open("../src/generated/modules.cpp", "a") as cpp:
                cpp.write("\n    {\"" + aliasedPath + "\", R\"(")

                for line in lines:
                    cpp.write(line)

                cpp.writelines(")\"},\n")
                numItems += 1

    with open("../src/generated/modules.cpp", "a") as cpp:
        cpp.write("};\n")

    with open("../src/generated/modules.h", "w") as header:
        header.writelines([
            "// This file is auto-generated by luthier.py. Do not edit.\n",
            "#pragma once\n",
            "\n",
            "#include <string_view>\n",
            "#include <utility>\n",
            "\n",
            f"extern const std::pair<std::string_view, std::string_view> lutestdlib[{numItems}];\n",
        ])

    with open("../src/generated/hash.txt", "w") as hash:
        hash.write(getStdLibHash())

    os.chdir(restoredPath)

def getCliCommandsHash():
    restoredPath = os.getcwd()
    os.chdir(os.path.join(getSourceRoot(), 'lute/cli/commands'))

    hasher = blake2b()
    for dirpath, _, filenames in os.walk('.'):
        for filename in sorted(filenames):
            filepath = os.path.join(dirpath, filename)
            hasher.update(filepath.encode('utf-8'))
            with open(filepath, 'rb') as f:
                while chunk := f.read(1024):
                    hasher.update(chunk)

    os.chdir(restoredPath)
    return hasher.hexdigest()

def isGeneratedCliCommandsUpToDate():
    hashFile = os.path.join(getSourceRoot(), 'lute/cli/generated/hash.txt')

    if not os.path.isfile(hashFile):
        return False

    with open(hashFile, 'r') as f:
        lines = f.readlines()
        assert(len(lines) == 1)
        actual = lines[0]
        expected = getCliCommandsHash()
        return actual == expected

    return False

def generateCliCommandsFilesIfNeeded():
    restoredPath = os.getcwd()

    os.chdir(os.path.join(getSourceRoot(), 'lute/cli'))
    os.makedirs("generated", exist_ok=True)

    if (isGeneratedCliCommandsUpToDate()):
        os.chdir(restoredPath)
        return
    else:
        print("Generating code for CLI commands, files are out of date.")

    with open("generated/commands.cpp", "w") as cpp:
        cpp.writelines([
            "// This file is auto-generated by luthier.py. Do not edit.\n",
            "// Instead, you should modify the source files in `cli/commands`.\n"
            "\n",
            '#include "commands.h"\n',
            "\n",
            "constexpr std::pair<std::string_view, std::string_view> luteclicommands[] = {\n",
        ])

    os.chdir("./commands")

    numItems = 0
    for dirpath, dirnames, filenames in os.walk("."):
        for dirname in dirnames:
            path = os.path.join(dirpath, dirname).replace("\\", "/")
            if "generated" in path:
                continue

            aliasedPath = path.replace("./", "@cli/", 1)

            with open("../generated/commands.cpp", "a") as cpp:
                cpp.write("\n    {\"" + aliasedPath + "\", \"#directory\"},\n")
                numItems += 1

        for filename in filenames:
            path = os.path.join(dirpath, filename).replace("\\", "/")
            if "generated" in path:
                continue

            aliasedPath = path.replace("./", "@cli/", 1)

            with open(path, "r") as script:
                lines = script.readlines()

            with open("../generated/commands.cpp", "a") as cpp:
                cpp.write("\n    {\"" + aliasedPath + "\", R\"(")

                for line in lines:
                    cpp.write(line)

                cpp.writelines(")\"},\n")
                numItems += 1

    with open("../generated/commands.cpp", "a") as cpp:
        cpp.write("};\n")

    with open("../generated/commands.h", "w") as header:
        header.writelines([
            "// This file is auto-generated by luthier.py. Do not edit.\n",
            "#pragma once\n",
            "\n",
            "#include <string_view>\n",
            "#include <utility>\n",
            "\n",
            f"extern const std::pair<std::string_view, std::string_view> luteclicommands[{numItems}];\n",
        ])

    with open("../generated/hash.txt", "w") as hash:
        hash.write(getCliCommandsHash())

    os.chdir(restoredPath)

def generateFilesIfNeeded():
    generateStdLibFilesIfNeeded()
    generateCliCommandsFilesIfNeeded()

def getExePath(args):
    target = args.target

    exeName = getExeName(target)
    config = getConfig(args)

    buildDir = "build"

    if isWindows or isMac:
        return os.path.join(
            buildDir,
            getCompiler(args),
            config.lower(),
            exeName
        )
    else: # Mac/Linux Ninja
        return os.path.join(
            buildDir,
            config.lower(),
            exeName
        )

def exeExists(args):
    exePath = getExePath(args)

    return path.isfile(exePath)

def call(*args):
    print('>', ' '.join(map(str, args[0])), file=sys.stderr)
    sys.stderr.flush()

    # If we're running native win32 Python from within an msys bash session,
    # the TEMP environment variable will muck up the compile.  We need to unset it.
    env = os.environ.copy()
    if 'TEMP' in env or 'TMP' in env:
        del env['TEMP']
        del env['TMP']

    if isMsys:
        # We don't want cmake to stumble across msys python.
        env['PATH'] = cygpath('/c/Python27').decode() + os.pathsep + env['PATH']

    return sp.call(*args, env=env)

def build(args):
    exeName = getExeName(args.target)
    projectPath = getProjectPath(args)

    if args.clean:
        call(['ninja', '-C', projectPath, 'clean'])

    cmd = [
        'ninja',
        '-C',
        projectPath,
        exeName
    ]

    return call(cmd)

def getConfigureArguments(args):
    "Returns a list of arguments to pass to configure.py based on the command line arguments provided"
    projectPath = getProjectPath(args)

    config = getConfig(args).lower()
    if config == "debug":
        config = "Debug"
    elif config == "release":
        config = "Release"

    if args.clean:
        call(['rm', '-rf', projectPath])

    configArgs = [
        '-G=Ninja',
        '-B ' + projectPath,
        '-DCMAKE_BUILD_TYPE=' + config,
        '-DCMAKE_EXPORT_COMPILE_COMMANDS=1',
    ]

    if args.cxx_compiler:
        configArgs.append('-DCMAKE_CXX_COMPILER=' + args.cxx_compiler)

    if args.c_compiler:
        configArgs.append('-DCMAKE_C_COMPILER=' + args.c_compiler)

    return configArgs

def readTuneFile(path):
    with open(path, 'rb') as fp:
        return tomllib.load(fp)

def fetchDependency(dependencyInfo):
    dependency = dependencyInfo['dependency']

    if not dependency:
        raise ReportableError('tune file does not have a dependency table')
    if not dependency.get('remote') or not dependency.get('branch'):
        raise ReportableError('Invalid dependency info in tune file: must have `remote` and `branch` fields')

    # if the directory already exists, update that directory to `branch`
    if os.path.isdir(os.path.join('extern', dependency['name'])):
        os.chdir(os.path.join('extern', dependency['name']))
        check(call(['git', 'fetch', '--depth=1', 'origin', dependency['revision']]))
        result = call(['git', 'checkout', dependency['revision']])
        os.chdir(getSourceRoot())
        return result

    if (gitVersionInfo['major'], gitVersionInfo['minor']) >= (2, 49):
        # if it doesn't exist, we'll do a shallow clone
        return call(['git', 'clone', '--depth=1', '--revision', dependency['revision'], dependency['remote'], "extern/" + dependency['name']])
    else:
        # if it doesn't exist, we'll do a shallow clone
        return call(['git', 'clone', '--depth=1', '--branch', dependency['branch'], dependency['remote'], "extern/" + dependency['name']])

def fetchDependencies(args):
    for _, _, files in os.walk('extern'):
        for file in files:
            if file.endswith('.tune'):
                dependencyInfo = readTuneFile(os.path.join('extern', file))
                check(fetchDependency(dependencyInfo))

    return 0

def configure(args):
    """Runs any necessary configuration steps to generate build files"""
    cmd = [
        "cmake",
    ] + getConfigureArguments(args)

    # fetchDependencies is too slow.
    # check(fetchDependencies(args))
    return call(cmd)

def check(exitCode):
    if exitCode != 0:
        sys.exit(exitCode)

def run(args, unparsed):
    command = unparsed[:]
    command.insert(0, os.path.abspath(getExePath(args)))

    os.chdir(cwd)

    return call(command)

def main(argv):
    (args, unparsed) = argParser.parse_known_args(argv)
    unparsed = list(u for u in unparsed if u != '--')

    os.chdir(getSourceRoot())

    if args.which:
        print(os.path.abspath(getExePath(args)))
        sys.exit(0)

    subcommand = args.subcommand

    if subcommand == "fetch":
        return fetchDependencies(args)
    elif subcommand == "configure" or subcommand == "tune":
        generateFilesIfNeeded()
        return configure(args)
    elif subcommand == "build" or subcommand == "craft":
        generateFilesIfNeeded()
        # auto configure if it's not already happened
        if not projectPathExists(args):
            check(configure(args))
        return build(args)
    elif subcommand == "run" or subcommand == "play":
        generateFilesIfNeeded()
        # auto configure if it's not already happened
        if not projectPathExists(args):
            check(configure(args))

        if not exeExists(args) or args.clean:
            check(build(args))

        return run(args, unparsed)


if __name__ == '__main__':
    # Add tab completion via argcomplete if the module is available
    try:
        import argcomplete
        argcomplete.autocomplete(argParser)
    except:
        pass

    try:
        sys.exit(main(sys.argv[1:]))
    except ReportableError as e:
        print(f'Error: {e}')
