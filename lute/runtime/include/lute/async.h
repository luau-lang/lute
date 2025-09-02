#pragma once

template<typename T>
class UVAsyncOperation
{
public:
    UVAsyncOperation()
        : req{}
    {
        req.data = this;
    }

    virtual ~UVAsyncOperation()
    {
        uv_fs_req_cleanup(&req);
    }

    virtual void callback() = 0;

    T* getRequest()
    {
        return &req;
    }

    static void uv_async_callback(T* req)
    {
        auto* operation = static_cast<UVAsyncOperation*>(req->data);

        operation->callback();
    }

private:
    T req;
};