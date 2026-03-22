//
//  AdManager.swift
//  Fauna
//
//  Manages rewarded ads (e.g. "Watch ad to double coins").
//  Currently uses a simulated ad flow. Replace the marked section
//  with real Google Mobile Ads SDK calls once integrated.
//

import Foundation
import SwiftUI

// TODO: Import Google Mobile Ads SDK when integrated:
// import GoogleMobileAds

@MainActor
final class AdManager: ObservableObject {
    static let shared = AdManager()
    
    /// Whether a rewarded ad is ready to show.
    @Published private(set) var isRewardedAdLoaded = true  // Simulated — always ready
    
    /// Whether an ad is currently being presented.
    @Published private(set) var isShowingAd = false
    
    private init() {
        // TODO: Initialize Google Mobile Ads SDK:
        // GADMobileAds.sharedInstance().start(completionHandler: nil)
        loadRewardedAd()
    }
    
    // MARK: - Load
    
    /// Pre-loads a rewarded ad so it's ready when the user taps "Double Coins".
    func loadRewardedAd() {
        // TODO: Replace with real ad loading:
        // GADRewardedAd.load(withAdUnitID: "ca-app-pub-XXXXX/YYYYY",
        //                    request: GADRequest()) { [weak self] ad, error in
        //     DispatchQueue.main.async {
        //         self?.rewardedAd = ad
        //         self?.isRewardedAdLoaded = (ad != nil)
        //     }
        // }
        isRewardedAdLoaded = true
        print("📺 AdManager: Rewarded ad loaded (simulated)")
    }
    
    // MARK: - Show
    
    /// Presents a rewarded ad. Calls `completion(true)` when the user
    /// earns the reward, or `completion(false)` on failure / dismissal.
    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        guard isRewardedAdLoaded, !isShowingAd else {
            completion(false)
            return
        }
        
        isShowingAd = true
        
        // TODO: Replace this simulated block with real ad presentation:
        // guard let rootVC = UIApplication.shared.connectedScenes
        //     .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
        //     .first else {
        //         isShowingAd = false
        //         completion(false)
        //         return
        //     }
        // rewardedAd?.present(fromRootViewController: rootVC) { [weak self] in
        //     self?.isShowingAd = false
        //     self?.loadRewardedAd()   // Pre-load next ad
        //     completion(true)
        // }
        
        // --- Simulated ad: brief delay then reward ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isShowingAd = false
            self?.isRewardedAdLoaded = false
            completion(true)
            print("📺 AdManager: Rewarded ad completed (simulated)")
            // Pre-load next ad
            self?.loadRewardedAd()
        }
    }
}
