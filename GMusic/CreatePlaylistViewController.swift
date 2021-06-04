//
//  CreatePlaylistViewController.swift
//  GMusic
//
//  Created by Григорий Сухотин on 27.05.2021.
//

import UIKit
import FirebaseDatabase
import FirebaseAuth

class CreatePlaylistViewController: UIViewController {
    

    @IBOutlet weak var nameTextField: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func createPlaylistButtonClick(_ sender: Any) {
        let database = Database.database()
        let auth = Auth.auth()
        database.reference(withPath: "users").child(auth.currentUser!.uid).child("playlists").observeSingleEvent(of: .value) { snapshot in
            var playlists: [MusicPlaylist] = []
            if let playlistDict = snapshot.value as? [NSDictionary] {
                playlists = playlistDict.map({ playlist in
                    return MusicPlaylist(dict: playlist)
                })
                database.reference(withPath: "users").child(auth.currentUser!.uid).child("playlists").child("\(playlists.count)").setValue(["provider":"custom", "name": self.nameTextField.text!, "artist": "", "imageUrl": "", "tracksUrl": "users/\(auth.currentUser!.uid)/playlists/\(playlists.count)/tracks"])
            }
        }
    }
    
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
