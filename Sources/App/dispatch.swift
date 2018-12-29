import Vapor
import Dispatch

func dispatch<T>(_ closure: @escaping (Request) throws -> T) -> (Request) -> Future<T> {
  return { request in
    let promise = request.eventLoop.newPromise(T.self)

    DispatchQueue.global().async {
      do {
        let result = try closure(request)
        promise.succeed(result: result)
      } catch {
        promise.fail(error: error)
      }
    }

    return promise.futureResult
  }
}

func dispatch<T, U>(_ closure: @escaping (Request, U) throws -> T) -> (Request, U) -> Future<T> {
  return { request, param in
    let promise = request.eventLoop.newPromise(T.self)

    DispatchQueue.global().async {
      do {
        let result = try closure(request, param)
        promise.succeed(result: result)
      } catch {
        promise.fail(error: error)
      }
    }

    return promise.futureResult
  }
}
