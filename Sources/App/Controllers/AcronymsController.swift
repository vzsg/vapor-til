/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Vapor
import Fluent
import Authentication

struct AcronymsController: RouteCollection {
  func boot(router: Router) throws {
    let acronymsRoutes = router.grouped("api", "acronyms")
    acronymsRoutes.get(use: wrapDispatch(getAllHandler))
    acronymsRoutes.get(Acronym.parameter, use: wrapDispatch(getHandler))
    acronymsRoutes.get("search", use: wrapDispatch(searchHandler))
    acronymsRoutes.get("first", use: wrapDispatch(getFirstHandler))
    acronymsRoutes.get("sorted", use: wrapDispatch(sortedHandler))
    acronymsRoutes.get(Acronym.parameter, "user", use: wrapDispatch(getUserHandler))
    acronymsRoutes.get(Acronym.parameter, "categories", use: wrapDispatch(getCategoriesHandler))

    let tokenAuthMiddleware = User.tokenAuthMiddleware()
    let guardAuthMiddleware = User.guardAuthMiddleware()
    let tokenAuthGroup = acronymsRoutes.grouped(tokenAuthMiddleware, guardAuthMiddleware)
    tokenAuthGroup.post(AcronymCreateData.self, use: wrapDispatch(createHandler))
    tokenAuthGroup.delete(Acronym.parameter, use: wrapDispatch(deleteHandler))
    tokenAuthGroup.put(Acronym.parameter, use: wrapDispatch(updateHandler))
    tokenAuthGroup.post(Acronym.parameter, "categories", Category.parameter, use: wrapDispatch(addCategoriesHandler))
    tokenAuthGroup.delete(Acronym.parameter, "categories", Category.parameter, use: wrapDispatch(removeCategoriesHandler))
  }

  func getAllHandler(_ req: Request) throws -> [Acronym] {
    return try Acronym.query(on: req)
      .all()
      .wait()
  }

  func createHandler(_ req: Request, data: AcronymCreateData) throws -> Acronym {
    let user = try req.requireAuthenticated(User.self)
    let acronym = try Acronym(short: data.short, long: data.long, userID: user.requireID())
    return try acronym.save(on: req).wait()
  }

  func getHandler(_ req: Request) throws -> Acronym {
    return try req.parameters.next(Acronym.self).wait()
  }

  func updateHandler(_ req: Request) throws -> Acronym {
    let acronym = try req.parameters.next(Acronym.self).wait()
    let updateData = try req.content.decode(AcronymCreateData.self).wait()

    acronym.short = updateData.short
    acronym.long = updateData.long
    let user = try req.requireAuthenticated(User.self)
    acronym.userID = try user.requireID()

    return try acronym.save(on: req).wait()
  }

  func deleteHandler(_ req: Request) throws -> HTTPStatus {
    let acronym = try req.parameters.next(Acronym.self).wait()
    try acronym.delete(on: req).wait()

    return .noContent
  }

  func searchHandler(_ req: Request) throws -> [Acronym] {
    guard let searchTerm = req.query[String.self, at: "term"] else {
      throw Abort(.badRequest)
    }


    return try Acronym.query(on: req).group(.or) { or in
      or.filter(\.short == searchTerm)
      or.filter(\.long == searchTerm)
    }.all().wait()
  }

  func getFirstHandler(_ req: Request) throws -> Acronym {
    guard let acronym = try Acronym.query(on: req).first().wait() else {
        throw Abort(.notFound)
    }

    return acronym
  }

  func sortedHandler(_ req: Request) throws -> [Acronym] {
    return try Acronym.query(on: req).sort(\.short, .ascending).all().wait()
  }

  func getUserHandler(_ req: Request) throws -> User.Public {
    let acronym = try req.parameters.next(Acronym.self).wait()

    return try acronym.user.get(on: req).wait()
      .convertToPublic()
  }

  func addCategoriesHandler(_ req: Request) throws -> HTTPStatus {
    let acronym = try req.parameters.next(Acronym.self).wait()
    let category = try req.parameters.next(Category.self).wait()

    _ = try acronym.categories.attach(category, on: req).wait()

    return .created
  }

  func getCategoriesHandler(_ req: Request) throws -> [Category] {
    let acronym = try req.parameters.next(Acronym.self).wait()
    return try acronym.categories.query(on: req).all().wait()
  }

  func removeCategoriesHandler(_ req: Request) throws -> HTTPStatus {
    let acronym = try req.parameters.next(Acronym.self).wait()
    let category = try req.parameters.next(Category.self).wait()

    _ = try acronym.categories.detach(category, on: req).wait()

    return .noContent
  }
}

struct AcronymCreateData: Content {
  let short: String
  let long: String
}
