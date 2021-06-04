//
//  SelectPlaylistTableViewController.swift
//  GMusic
//
//  Created by Григорий Сухотин on 27.05.2021.
//

import UIKit
import FirebaseDatabase
import FirebaseAuth

class SelectPlaylistTableViewController: UITableViewController {
    var playlists: [MusicPlaylist] = []
    var track: MusicTrack?
    var keys: [String] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        let database = Database.database()
        let auth = Auth.auth()
        database.reference(withPath: "users").child(auth.currentUser!.uid).child("playlists").observe(.value) { snapshot in
            for child in snapshot.children {
                let childSnapshot = child as! DataSnapshot
                let data = childSnapshot.value as! NSDictionary
                let playlist = MusicPlaylist(dict: data)
                if playlist.provider == "custom" {
                    self.playlists.append(playlist)
                    self.keys.append(childSnapshot.key)
                }
            }
            self.tableView.reloadData()
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return playlists.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "trackSearchCell") as! MusicTableViewCell
        cell.trackNameLabel.text = playlists[indexPath.row].name
        cell.trackArtistLabel.text = ""
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let track = track else {return}
        let database = Database.database()
        let auth = Auth.auth()
        database.reference(withPath: "users").child(auth.currentUser!.uid).child("playlists").child(keys[indexPath.row]).child("tracks").observeSingleEvent(of: .value) { snapshot in
            var tracks: [NSDictionary] = []
            if snapshot.exists() {
                tracks = snapshot.value as! [NSDictionary]
            }
            database.reference(withPath: "users").child(auth.currentUser!.uid).child("playlists").child(self.keys[indexPath.row]).child("tracks").child("\(tracks.count)").setValue(track.dict())
            self.dismiss(animated: true)
        }
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
