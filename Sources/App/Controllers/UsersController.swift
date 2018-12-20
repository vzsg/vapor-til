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
import Crypto

struct UsersController: RouteCollection {
  func boot(router: Router) throws {
    let usersRoute = router.grouped("api", "users")
    usersRoute.get(use: wrapDispatch(getAllHandler))
    usersRoute.get(User.parameter, use: wrapDispatch(getHandler))
    usersRoute.get(User.parameter, "acronyms", use: wrapDispatch(getAcronymsHandler))
    let basicAuthMiddleware = User.basicAuthMiddleware(using: BCryptDigest())
    let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
    basicAuthGroup.post("login", use: wrapDispatch(loginHandler))

    let tokenAuthMiddleware = User.tokenAuthMiddleware()
    let guardAuthMiddleware = User.guardAuthMiddleware()
    let tokenAuthGroup = usersRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
    tokenAuthGroup.post(User.self, use: wrapDispatch(createHandler))
  }

  func createHandler(_ req: Request, user: User) throws -> User.Public {
    user.password = try BCrypt.hash(user.password)
    return try user.save(on: req).wait().convertToPublic()
  }

  func getAllHandler(_ req: Request) throws -> [User.Public] {
    return try User.query(on: req).decode(data: User.Public.self).all().wait()
  }

  func getHandler(_ req: Request) throws -> User.Public {
    return try req.parameters.next(User.self).wait().convertToPublic()
  }

  func getAcronymsHandler(_ req: Request) throws -> [Acronym] {
    let user = try req.parameters.next(User.self).wait()
    return try user.acronyms.query(on: req).all().wait()
  }

  func loginHandler(_ req: Request) throws -> Token {
    let user = try req.requireAuthenticated(User.self)
    let token = try Token.generate(for: user)
    return try token.save(on: req).wait()
  }
}

