//
//  SceneDelegate.swift
//  GMusic
//
//  Created by Григорий Сухотин on 26.04.2021.
//

import UIKit
import FBSDKCoreKit
import GoogleSignIn
import MediaPlayer
import AVFoundation

class SceneDelegate: UIResponder, UIWindowSceneDelegate{
    
    
    let SpotifyClientID = "35c1dbc001224063a401b53ad72c3b6c"
    let SpotifyRedirectURL = URL(string: "gmusic://callback")!
    
    public var accessToken = ""
    
    var playlist: MusicPlaylist?
    var currentTrackId = 0
    var musicTrack: MusicTrack?
    var musicSourceViewController: UIViewController?
    var isAvPlayerPlaying = false
    
    lazy var configuration = SPTConfiguration(
      clientID: SpotifyClientID,
      redirectURL: SpotifyRedirectURL
    )
    
    lazy var appRemote: SPTAppRemote = {
      let appRemote = SPTAppRemote(configuration: self.configuration, logLevel: .debug)
      appRemote.connectionParameters.accessToken = self.accessToken
      return appRemote
    }()
    
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }

        let parameters = appRemote.authorizationParameters(from: url);

        if let access_token = parameters?[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = access_token
            self.accessToken = access_token
        } else if let error_description = parameters?[SPTAppRemoteErrorDescriptionKey] {
            // Show the error
        }
        GIDSignIn.sharedInstance().handle(url)
        ApplicationDelegate.shared.application(
                UIApplication.shared,
                open: url,
                sourceApplication: nil,
                annotation: [UIApplication.OpenURLOptionsKey.annotation]
            )

    }


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        window?.tintColor = UIColor(named: "AccentColor")
        
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }
    

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        if let _ = self.appRemote.connectionParameters.accessToken {
            self.appRemote.connect()
        }
        if isAvPlayerPlaying{
            let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo!
        guard let musicSourceViewController = musicSourceViewController else {return}
            guard let musicTrack = musicTrack else {return}
            if let songSearchViewController = musicSourceViewController as? SongSearchViewController {
                songSearchViewController.position = Int((nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as! Double) * 1000)
                songSearchViewController.trackProgressView.progress = Float(songSearchViewController.position)/Float(musicTrack.duration)
                let playerRate = nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as! Double
                if playerRate == 1.0 {
                    songSearchViewController.isPaused = false
                    songSearchViewController.playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                }else{
                    songSearchViewController.isPaused = true
                    songSearchViewController.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                }
            }
            if let libraryViewController = musicSourceViewController as? LibraryViewController {
                libraryViewController.position = Int((nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as! Double) * 1000)
                libraryViewController.trackProgressVIew.progress = Float(libraryViewController.position)/Float(musicTrack.duration)
                let playerRate = nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as! Double
                if playerRate == 1.0 {
                    libraryViewController.isPaused = false
                    libraryViewController.playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                }else{
                    libraryViewController.isPaused = true
                    libraryViewController.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                }
            }
            if let playlistViewController = musicSourceViewController as? PlaylistViewController {
                playlistViewController.position = Int((nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as! Double) * 1000)
                playlistViewController.trackProgressBar.progress = Float(playlistViewController.position)/Float(playlist!.tracks[currentTrackId].duration)
                playlistViewController.currentTrackId = currentTrackId
                let playerRate = nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as! Double
                if playerRate == 1.0 {
                    playlistViewController.isPaused = false
                    playlistViewController.trackPlayButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                }else{
                    playlistViewController.isPaused = true
                    playlistViewController.trackPlayButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                }
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        if self.appRemote.isConnected {
            self.appRemote.disconnect()
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        
    }
    

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

}

