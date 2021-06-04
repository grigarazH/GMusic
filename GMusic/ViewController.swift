//
//  ViewController.swift
//  GMusic
//
//  Created by Григорий Сухотин on 26.04.2021.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import Network

class ViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var emailTF: UITextField!
    @IBOutlet weak var passwordTF: UITextField!
    @IBOutlet weak var stackView: UIStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                self.emailTF.delegate = self
                self.passwordTF.delegate = self
                let auth = Auth.auth()
                GIDSignIn.sharedInstance()?.presentingViewController = self
                if let user = auth.currentUser {
                    self.performSegue(withIdentifier: "loginToMainAppSegue", sender: self)
                }
                let facebookButton = FBLoginButton()
                facebookButton.setAttributedTitle(NSAttributedString(string: "Войти через Facebook"), for: .normal)
                let googleSignInButton = GIDSignInButton()
                self.stackView.insertArrangedSubview(facebookButton, at: 2)
                self.stackView.insertArrangedSubview(googleSignInButton, at: 3)
                
                NotificationCenter.default.addObserver(forName: NSNotification.Name("GoogleSignIn"), object: nil, queue: OperationQueue.main) { notification in
                    self.performSegue(withIdentifier: "loginToMainAppSegue", sender: self)
                }
                
                
                NotificationCenter.default.addObserver(forName: .AccessTokenDidChange, object: nil, queue: OperationQueue.main) { notification in
                    let auth = Auth.auth()
                    guard let tokenString = AccessToken.current?.tokenString else {return}
                    auth.signIn(with: FacebookAuthProvider.credential(withAccessToken: tokenString)) { result, error in
                        if error == nil{
                        print("success")
                            self.performSegue(withIdentifier: "loginToMainAppSegue", sender: self)
                        }else{
                            print("error")
                        }
                    }
                    
                }
            }else{
                self.performSegue(withIdentifier: "authToOfflineLibrarySegue", sender: self)
            }
        }
        let queue = DispatchQueue.main
        monitor.start(queue: queue)
    }

    @IBAction func loginButtonClick(_ sender: UIButton) {
        let auth = Auth.auth()
        guard let email = emailTF.text else {
            return}
        guard let password = passwordTF.text else {
            return}
        auth.signIn(withEmail: email, password: password) { result, error in
            guard let result = result else {
                let loginAlertController = UIAlertController(title: "Ошибка", message: "Неверный E-mail или пароль", preferredStyle: .alert)
                loginAlertController.addAction(UIAlertAction(title: "ОК", style: .default))
                self.present(loginAlertController, animated: true)
                return
            }
            self.performSegue(withIdentifier: "loginToMainAppSegue", sender: self)
        }
    }
    @IBAction func unwind(unwindSegue: UIStoryboardSegue) {
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return true
    }
}

