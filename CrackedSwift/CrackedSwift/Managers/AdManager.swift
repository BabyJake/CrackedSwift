//
//  AdManager.swift
//  Fauna
//
//  Manages rewarded ads (e.g. "Watch ad to double coins").
//  TODO: Implement with Google Mobile Ads SDK before enabling ads.
//  Currently stubbed out for App Store submission.
//

import Foundation
import SwiftUI

// TODO: Import Google Mobile Ads SDK when integrated:
// import GoogleMobileAds

@MainActor
final class AdManager: ObservableObject {
    static let shared = AdManager()

    /// Whether a rewarded ad is ready to show - always false until ads are implemented.
    @Published private(set) var isRewardedAdLoaded = false

    /// Whether an ad is currently being presented.
    @Published private(set) var isShowingAd = false

    private init() {
        // TODO: Initialize Google Mobile Ads SDK when ready:
        // GADMobileAds.sharedInstance().start(completionHandler: nil)
        // loadRewardedAd()
    }

    // MARK: - Load

    func loadRewardedAd() {
        // TODO: Implement real ad loading
    }

    // MARK: - Show

    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        // Ads not yet implemented - always fail gracefully
        completion(false)
    }
}
