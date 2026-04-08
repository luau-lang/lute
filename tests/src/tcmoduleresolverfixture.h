#pragma once

#include "lute/tcmoduleresolver.h"

#include "Luau/Ast.h"
#include "Luau/FileResolver.h"
#include "Luau/TypeCheckLimits.h"

#include "lutefixture.h"

#include <string>

class TCModuleResolverFixture : public LuteFixture
{
public:
    TCModuleResolverFixture();

    Luau::LuteTypeCheckModuleResolver resolver;
    Luau::ModuleInfo context;
    Luau::TypeCheckLimits limits;
};
