import Vapor
import Dispatch

private let queue = DispatchQueue(label: "dispatched_route_queue", attributes: .concurrent)

func wrapDispatch<T>(_ closure: @escaping (Request) throws -> T) -> (Request) -> Future<T> {
  return { request in
    let promise = request.eventLoop.newPromise(T.self)

    queue.async {
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

func wrapDispatch<T, U>(_ closure: @escaping (Request, U) throws -> T) -> (Request, U) -> Future<T> {
  return { request, param in
    let promise = request.eventLoop.newPromise(T.self)

    queue.async {
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
