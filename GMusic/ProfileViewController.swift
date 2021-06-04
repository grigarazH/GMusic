//
//  ProfileViewController.swift
//  GMusic
//
//  Created by Григорий Сухотин on 31.05.2021.
//

import UIKit
import FirebaseDatabase
import FirebaseAuth
import FBSDKLoginKit

class ProfileViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    let availableAccounts = ["spotify","jamendo"]
    var connectedAccounts: [String] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        let database = Database.database()
        let auth = Auth.auth()
        database.reference(withPath: "users").child(auth.currentUser!.uid).child("accounts").observe(.value) { snapshot in
            if !snapshot.exists() {
                return
            }else{
                self.connectedAccounts = []
                for child in snapshot.children {
                    let childSnapshot = child as! DataSnapshot
                    let value = childSnapshot.value as! String
                    self.connectedAccounts.append(value)
                }
                self.tableView.reloadData()
            }
        }
    }
    @IBAction func exitButtonClick(_ sender: Any) {
        let auth = Auth.auth()
        
        do {
            if Profile.current != nil {
                LoginManager().logOut()
            }
            try auth.signOut()
            performSegue(withIdentifier: "unwindFromProfileToLogin", sender: self)
        }catch {
            print("signout error")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        guard let sceneDelegate = view?.window?.windowScene?.delegate as? SceneDelegate else {return}
        sceneDelegate.appRemote.delegate = self
    }

}


extension ProfileViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableAccounts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "profileCell") as! ProfileTableViewCell
        cell.accountName.text = availableAccounts[indexPath.row].capitalizingFirstLetter()
        if connectedAccounts.contains(availableAccounts[indexPath.row]) {
            cell.accountStatus.text = "Подключен"
            cell.accountStatus.textColor = .green
            cell.accountButton.setTitle("Отключить", for: .normal)
            cell.accountAction = {
                self.connectedAccounts.remove(at: indexPath.row)
                let database = Database.database()
                let auth = Auth.auth()
                database.reference(withPath: "users").child(auth.currentUser!.uid).child("accounts").setValue(self.connectedAccounts)
                tableView.reloadData()
            }
        }else{
            cell.accountStatus.text = "Не подключен"
            cell.accountStatus.textColor = .red
            cell.accountButton.setTitle("Подключить", for: .normal)
            cell.accountAction = {
                if self.availableAccounts[indexPath.row] == "spotify" {
                    guard let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate else {return}
                    if sceneDelegate.appRemote.authorizeAndPlayURI("") {
                        sceneDelegate.appRemote.playerAPI!.pause()
                        sceneDelegate.appRemote.userAPI!.fetchCapabilities { capabilities, error in
                            guard let capabilities = capabilities as? SPTAppRemoteUserCapabilities else {return}
                            if capabilities.canPlayOnDemand {
                                self.connectedAccounts.append(self.availableAccounts[indexPath.row])
                                let database = Database.database()
                                let auth = Auth.auth()
                                database.reference(withPath: "users").child(auth.currentUser!.uid).child("accounts").setValue(self.connectedAccounts)
                                tableView.reloadData()
                            }else{
                                let noSubscribeAlertDialog = UIAlertController(title: "Ошибка", message: "Отсутствует подписка на Spotify", preferredStyle: .alert)
                                noSubscribeAlertDialog.addAction(UIAlertAction(title: "ОК", style: .default))
                                self.present(noSubscribeAlertDialog, animated: true)
                            }
                        }
                    }else {
                        let noSpotifyAlertDialog = UIAlertController(title: "Ошибка", message: "Spotify не обнаружен. Откройте App Store и скачайте Spotify", preferredStyle: .alert)
                        noSpotifyAlertDialog.addAction(UIAlertAction(title: "ОК", style: .default))
                        self.present(noSpotifyAlertDialog, animated: true)
                    }
                    
                }else{
                    self.connectedAccounts.append(self.availableAccounts[indexPath.row])
                    let database = Database.database()
                    let auth = Auth.auth()
                    database.reference(withPath: "users").child(auth.currentUser!.uid).child("accounts").setValue(self.connectedAccounts)
                    tableView.reloadData()
                }
            }
        }
        return cell
    }
}

extension ProfileViewController: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("connected")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("failed to connect")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("disconect")
    }
    
    
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}
