type Request = {
  method: string,
  path: string,
  params: {[string]: string},
  headers: {[string]: string},
  body: string,
}

type ServeResponse = {
  status: number,
  headers: {[string]: string},
  body: string,
}

type Handler = (Request) -> string | ServeResponse

type ServeConfig = {
  hostname: string?,
  port: number?,
  handler: Handler,
}

type Server = {
  hostname: string,
  port: number,
  close: () -> (),
}

type serve = (Handler | ServeConfig) -> Server
