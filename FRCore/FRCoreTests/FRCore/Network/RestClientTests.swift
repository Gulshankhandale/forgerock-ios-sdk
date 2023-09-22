//
//  RestClientTests.swift
//  FRCoreTests
//
//  Copyright (c) 2020-2023 ForgeRock. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest

class RestClientTests: FRBaseTestCase {

    override func setUp() {
        super.setUp()
        self.shouldLoadMockResponses = false
    }
    
    
    /// Tests to invoke API request with invalid URLRequest or Request object
    func test_01_test_invalid_request_obj() {
        
        let request = Request(url: "invalid_request", method: .GET)
        let expectation = self.expectation(description: "GET request should fail with invalid Request object: \(request.debugDescription)")
        
        var response:[String: Any]?, urlResponse: URLResponse?, error: NetworkError?
        
        RestClient.shared.invoke(request: request) { (result) in
            switch result {
            case .success(let requestResponse, let requestUrlResponse):
                response = requestResponse
                urlResponse = requestUrlResponse
                expectation.fulfill()
                break
            case .failure(let requestError):                
                error = requestError as? NetworkError
                expectation.fulfill()
                break
            }
        }
        waitForExpectations(timeout: 60, handler: nil)
        
        XCTAssertNil(response)
        XCTAssertNil(urlResponse)
        
        guard let _ = error else {
            XCTFail()
            return
        }
        switch error {
        case .invalidRequest(_):
            break
        default:
            XCTFail("RestClient failed with unexpected reason")
            break
        }
    }
    
    func test_02_test_200_get_request() {
        
        let request = Request(url: "https://httpbin.org/get", method: .GET)
        let expectation = self.expectation(description: "GET request: \(request.debugDescription)")
        
        var response:[String: Any]?, urlResponse: URLResponse?, error: NetworkError?
        
        RestClient.shared.invoke(request: request) { (result) in
            switch result {
            case .success(let requestResponse, let requestUrlResponse):
                response = requestResponse
                urlResponse = requestUrlResponse
                expectation.fulfill()
                break
            case .failure(let requestError):
                
                error = requestError as? NetworkError
                expectation.fulfill()
                break
            }
        }
        waitForExpectations(timeout: 60, handler: nil)
        
        XCTAssertNotNil(response)
        XCTAssertNotNil(urlResponse)
        XCTAssertNil(error)
    }
    
    
    func test_03_test_invalid_response_image() {
           
       let request = Request(url: "https://httpbin.org/image", method: .GET, headers: ["accept":"image/webp"])
       let expectation = self.expectation(description: "GET request: \(request.debugDescription)")
       
       var response:[String: Any]?, urlResponse: URLResponse?, error: NetworkError?
       
       RestClient.shared.invoke(request: request) { (result) in
           switch result {
           case .success(let requestResponse, let requestUrlResponse):
               response = requestResponse
               urlResponse = requestUrlResponse
               expectation.fulfill()
               break
           case .failure(let requestError):
               
               error = requestError as? NetworkError
               expectation.fulfill()
               break
           }
       }
       waitForExpectations(timeout: 60, handler: nil)
       
       XCTAssertNil(response)
       XCTAssertNil(urlResponse)
       
       guard let networkError = error else {
           XCTFail("Erorr was returned as nil while expecting invalid response error")
           return
       }
       
       switch networkError {
       case .invalidResponseDataType:
           break
       default:
           XCTFail("Request failed with unexpected error while expecting invalid response data type error")
           break
       }
    }
    
    
    func test_04_test_cache_control() {
        
        let request = Request(url: "https://httpbin.org/get", method: .GET)
        let expectation = self.expectation(description: "GET request: \(request.debugDescription)")
        
        let urlRequest = request.build()!
        let urlCache = RestClient.shared._urlSession?.configuration.urlCache
        urlCache?.removeCachedResponse(for: urlRequest)
        
        var response:[String: Any]?, urlResponse: URLResponse?, error: NetworkError?
        
        RestClient.shared.invoke(request: request) { (result) in
            switch result {
            case .success(let requestResponse, let requestUrlResponse):
                response = requestResponse
                urlResponse = requestUrlResponse
                expectation.fulfill()
                break
            case .failure(let requestError):
                
                error = requestError as? NetworkError
                expectation.fulfill()
                break
            }
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        
        XCTAssertNotNil(response)
        XCTAssertNotNil(urlResponse)
        XCTAssertNil(error)
        
        XCTAssertNil(urlCache?.cachedResponse(for: urlRequest))
        
        if let headers = response?["headers"] as? [String: String],
           let cacheControl = headers["Cache-Control"] {
            XCTAssertEqual(cacheControl, "no-store")
        } else {
            XCTFail("Unable to extract Cache-Control from response header")
        }
        
    }
}

