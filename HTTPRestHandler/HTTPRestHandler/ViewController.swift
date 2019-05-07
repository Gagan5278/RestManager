//
//  ViewController.swift
//  HTTPRestHandler
//
//  Created by Gagan Vishal on 2019/05/03.
//  Copyright © 2019 Gagan Vishal. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    let rest = RestManager()
    override func viewDidLoad() {
        super.viewDidLoad()
        print("PLease check ViewController file for detail use of REST library.")
    }

    @IBAction func getRequestCall(_ sender: Any) {
        guard let url = URL(string: "https://itunes.apple.com/lookup?amgArtistId=468749,5723&entity=song&limit=5&sort=recent") else { return }
        rest.makeRequest(toURL: url, withHttpMethod: .get) { (results) in
            //guard let response = results.response else { return }  just use one line code or add below code
            if results.error != nil || results.response == nil {
                
            }
            else //obejct found
            {
                if results.isFileFromServer { //we get file from server
                    
                }
                else{ //we get JSON from server
                    print("Object are :\(String(describing: results.object))")
                }
            }
        }
    }
    
    @IBAction func postRequestCall(_ sender: Any) {
        print("***********$$$$$$$$$$$$ Add your POST serice URL here $$$$$$$$$$$$***********")
        guard let url = URL(string: "https://yourpostserviceUrl") else { return }
        rest.requestHttpHeaders.add(forKey: "Content-Type", value: "application/json")
        rest.httpBodyParameters.add(forKey: "name", value: "John")
        rest.httpBodyParameters.add(forKey: "job", value: "Developer")
        rest.makeRequest(toURL: url, withHttpMethod: .post) { (results) in
            guard let response = results.response else { return }
            if response.httpStatusCode == 201 {
                let data = results.object
                print(data!)
            }
        }
    }
    
    //MARK:- Get file from server
    @IBAction func downloadFileFromServer(_ sender: UIButton) {
        guard let url = URL(string: "https://is5-ssl.mzstatic.com/image/thumb/Music124/v4/05/59/c1/0559c1d7-2800-7c1e-9620-04063cd96ea5/source/100x100bb.jpg") else { return }
        rest.makeRequest(toURL: url, withHttpMethod: .get) { (results) in
            if results.error != nil || results.response == nil {
                print("error found)")
            }
            else
            {
                if results.isFileFromServer {
                    DispatchQueue.main.async {
                        sender.setBackgroundImage(UIImage(data: results.object as! Data), for: .normal)
                    }
                }
            }
        }
    }
    
    //MARK:- Adding query parameters to call service.
    /*
     Adding query parameters to the request
   */

    func getUsersList() {
        guard let url = URL(string: "https://reqres.in/api/users") else { return }
        // The following will make RestManager create the following URL:
        // https://reqres.in/api/users?page=2
        rest.urlQueryParameters.add(forKey: "page", value: "2")
        rest.makeRequest(toURL: url, withHttpMethod: .get) { (results) in
        }
    }
    
    //MARK:- Checking HTTP Status Code
    func getHTTPStatusCode() {
        guard let url = URL(string: "YOUR_URL") else { return }
        rest.makeRequest(toURL: url, withHttpMethod: .get) { (results) in
            if let response = results.response {
                if response.httpStatusCode != 200 {
                    print("\nRequest failed with HTTP status code", response.httpStatusCode, "\n")
                }
            }
        }
    }
}

