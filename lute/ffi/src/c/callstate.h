#pragma once

#include <csetjmp>
#include <functional>
#include <vector>

class CallState
{
public:
    ~CallState()
    {
        for (const auto& callback : callbacks)
        {
            callback();
        }
    }

    template<typename T, typename... Args>
    T* create(Args&&... args)
    {
        T* ptr = new T(std::forward<Args>(args)...);

        callbacks.push_back(
            [ptr]()
            {
                delete ptr;
            }
        );

        return ptr;
    }

    std::jmp_buf errorBuffer;
private:
    std::vector<std::function<void()>> callbacks;
};
