#pragma once

#include "lute/common.h"

#include "Luau/Variant.h"

#include <string>
#include <utility>

namespace Lute
{

template<typename T, typename E = std::string>
class Result
{
public:
    static Result success(T value)
    {
        return Result(std::move(value));
    }

    static Result failure(E error)
    {
        return Result(std::move(error));
    }

    bool ok() const
    {
        return storage.template get_if<T>() != nullptr;
    }

    const T& value() const
    {
        const T* v = storage.template get_if<T>();
        LUTE_ASSERT(v);
        return *v;
    }

    const E& error() const
    {
        const E* e = storage.template get_if<E>();
        LUTE_ASSERT(e);
        return *e;
    }

private:
    explicit Result(Luau::Variant<T, E> storage)
        : storage(std::move(storage))
    {
    }

    Luau::Variant<T, E> storage;
};

} // namespace Lute
