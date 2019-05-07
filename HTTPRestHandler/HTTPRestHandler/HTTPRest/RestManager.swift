//
//  RestManager.swift
//  HTTPRestHandler
//  Content: -
//  Created by Gagan Vishal on 2019/05/03.
//  Copyright © 2019 Gagan Vishal. All rights reserved.
//

import Foundation

class RestManager: NSObject {
    //
    var requestHttpHeaders = RestEntity()
    var urlQueryParameters = RestEntity()
    var httpBodyParameters = RestEntity()
    //payload data
    var httpBody: Data?
    //Request timeout time. Reset as per requirement. Default is 60 seconds
    var kDefaultRequestTimeout = 60 as TimeInterval
    /// **NOTE:** If running on iOS 9.0+ then ensure to configure `App Transport Security` appropriately.  if there is any SSL request then make it true in service call
    public var acceptSelfSignedCertificate = false
    
    //MARK:- Private function to add query to ulr
    private func addURLQueryParameters(toURL url: URL) -> URL {
        if urlQueryParameters.totalItems() > 0{
            guard  var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {return url} //URLComponents allows to deal with url and its each part. URLComponents has a prperty name as 'queryItems' which is by default nil
            var queryItems = [URLQueryItem]()
            for (key, value) in urlQueryParameters.allValues() {
                let item = URLQueryItem(name: key, value: value)
                queryItems.append(item)
            }
            //aassign all query items in URLComponents
            urlComponents.queryItems = queryItems
            
            //check for url
            guard let updatedURL = urlComponents.url else {return url}
            return updatedURL
        }
        return url
    }
    
    //MARK:- A privae function to handle data type object in request body
    private func getHttpBody() -> Data?{
        guard let contentType = requestHttpHeaders.value(forKey: "Content-Type") else {return nil}
        
        if contentType.contains("application/json") {
            return try? JSONSerialization.data(withJSONObject: self.httpBodyParameters.allValues(), options: [.prettyPrinted,.sortedKeys])
        } else if contentType.contains("application/x-www-form-urlencoded") {
            let bodyString = httpBodyParameters.allValues().map { "\($0)=\(String(describing: $1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)))" }.joined(separator: "&")
            return bodyString.data(using: .utf8)
        } else {
            return httpBody
        }
    }
    
    //MARK:- Prepare request
    private func prepareRequest(withURL url: URL?, httpBody: Data?, httpMethod:HTTPMethod) -> URLRequest? {
        guard let url = url else { return nil }
        //create  a URL Request
        var request = URLRequest(url: url)
        // assign request method
        request.httpMethod = httpMethod.rawValue
        //add headers to request
        for (header, value) in requestHttpHeaders.allValues() {
           request.setValue(value, forHTTPHeaderField: header)
        }
        //assign request body here
        request.httpBody = httpBody
        //return
        return request
    }
    
    //MARK:- Public method to accept request
    /*
     To ensure that, we’ll perform all actions asynchronously in a background thread, so the main thread remains free to be used by the app
    */
    public func makeRequest(toURL url: URL, withHttpMethod httpMethod: HTTPMethod, completion: @escaping (_ results: Result) -> Void){
        //userInitiated value as the quality of service (“qos”) parameter will give priority to our task against other tasks that are being executed in the background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            //1.
            let targetURL = self?.addURLQueryParameters(toURL: url)
            //2.
            let httpBody = self?.getHttpBody()
            //3.
            guard let request = self?.prepareRequest(withURL: targetURL, httpBody: httpBody, httpMethod: httpMethod) else {
                completion(Result(withError: CustomError.failedToCreateRequest))
                return
            }
            
            //create session configuraion
            let sessionConfiguration = URLSessionConfiguration.default
            //set  request timeout here
            sessionConfiguration.timeoutIntervalForRequest = (self?.kDefaultRequestTimeout)!
            //session
            let urlSessoin = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
            //data task ans resume it
            urlSessoin.dataTask(with: request, completionHandler: { (data, response, error) in
                completion(Result(withData: data, response: Response(fromURLResponse: response), error: error))
            }).resume()
        }
    }
}

//MARK:- RestManager extension
extension RestManager {
    //add an enum with all request method that we have to send to server
    enum HTTPMethod: String {
        case get
        case post
        case put
        case patch
        case delete
    }
    
    //add an entity which will be used to create payload for a request. These are used
    //1. HTTP headers
    //2. URLQuery Parameters
    //3. HTTP Body parameters
    struct RestEntity {
        private var values: [String: String] = [:]
        //add values in
        mutating func add(forKey key: String, value: String) {
             values[key] = value
        }
        //get value for a key
        func value(forKey key: String) -> String?
        {
            return values[key]
        }
        //get all values
        func allValues() -> [String: String]{
            return values
        }
        //get count
        func totalItems() -> Int {
            return values.count
        }
    }
    
    //RESPONSE
    /*
        from server response we get
        1. A numeric http status
        2. an Header which is optional
        3. Response body from server
    */
    
    struct  Response {
        var response: URLResponse?  // keep the actual response object. This object does not contain the actual data returned from server.
        var httpStatusCode: Int = 0 //The status code that represents the outcome of the request. 0 an indication that no HTTP status code could be determined.
        var headers = RestEntity()  //An instance of the RestEntity struct
        
        //custom init
        init(fromURLResponse response: URLResponse?) {
            guard let response = response else {return} //if response is nil the return from here
            self.response = response
            self.httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0 //if status code is not available from response that means something is wrong and assign it to '0'
            //check for header
            if let headers = (response as? HTTPURLResponse)?.allHeaderFields {
                for (key, value) in headers {
                    self.headers.add(forKey: "\(key)", value: "\(value)")
                }
            }
        }
    }
    
    //RESULT
    /*
     from a service call we get Data, error and response(Response struct we will built). Please note that all properties in this struct are optional as they may or may not exist in result.
     Result from server a result may be
     1. Actual data coming from server when out request is successful
     2. any potential error might come there
    */
    
    struct  Result {
        var object: AnyObject?
        var response: Response?
        var error: Error?
        //var to check if file is returnig from response
        var isFileFromServer = false
        
        //init
        init(withData data: Data?, response: Response?, error: Error?)
        {
            if data != nil && data!.count > 0 {
                if checkFileMimeType(data: data!)
                {
                    self.isFileFromServer = true
                    self.object =  data as AnyObject? //here we can use filemanager object as well to hold reference of file after converting data into file.
                }
                else{
                    self.isFileFromServer = false
                    self.object = data?.value()
                }
            }
            self.response = response
            self.error = error
        }
        
        //create another init with error. There might be cases when request cant be successful for e.g. there is no internet
        init(withError error: Error)
        {
            self.error = error
        }
        
        //MARK- Check if file type
        private func checkFileMimeType(data: Data) -> Bool {
            var b: UInt8 = 0
            data.copyBytes(to: &b, count: 1)
            switch b {
            case 0xFF:
                return true//"image/jpeg"
            case 0x89:
                return true//"image/png"
            case 0x47:
                return true // "image/gif"
            case 0x4D, 0x49:
                return true//"image/tiff"
            case 0x25:
                return true//"application/pdf"
            case 0xD0:
                return true//"application/vnd"
            case 0x46:
                return true//"text/plain"
            default:
                return false//"application/octet-stream"
            }
        }
    }
    
    //an error can be generated from URLResponse & URLRequset. So below enum handle the case when error gerarated from URLRequest
    enum CustomError: Error {
        case failedToCreateRequest
    }
}

//URL Session Delegates
extension RestManager : URLSessionDelegate
{
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.previousFailureCount > 0 {
            completionHandler(Foundation.URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
        } else if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

//Extension for CustomError
extension RestManager.CustomError: LocalizedError {
    public var localizedDescription: String {
        switch self {
        case .failedToCreateRequest: return NSLocalizedString("Unable to create the URLRequest object", comment: "")
        }
    }
}

//Convert Data into a NSObject
extension Data {
    func value()-> AnyObject?
    {
        do{
            return try JSONSerialization.jsonObject(with: self, options: .allowFragments) as AnyObject
        }
        catch {
            print("error in DATA is : \(error)")
            return  error as AnyObject
        }
    }
}
