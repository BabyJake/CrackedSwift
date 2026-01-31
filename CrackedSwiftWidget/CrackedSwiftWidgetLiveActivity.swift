//
//  CrackedSwiftWidgetLiveActivity.swift
//  CrackedSwiftWidget
//
//  Created for Live Activities support.
//

/*
import ActivityKit
import WidgetKit
import SwiftUI

struct CrackedSwiftWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            // Lock Screen/Banner UI
            VStack {
                HStack {
                    Image(context.attributes.eggImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading) {
                        Text("Hatching \(context.attributes.eggName)")
                            .font(.headline)
                        Text(context.state.isRunning ? "Incubating..." : "Paused")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(timerInterval: Date()...Date().addingTimeInterval(context.state.timeRemaining), countsDown: true)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                }
                .padding()
                
                ProgressView(value: context.state.progress, total: 1.0)
                    .tint(Color.orange)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(context.attributes.eggImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                        Text(context.attributes.eggName)
                            .font(.caption)
                            .bold()
                    }
                    .padding(.leading)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...Date().addingTimeInterval(context.state.timeRemaining), countsDown: true)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .padding(.trailing)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack {
                        ProgressView(value: context.state.progress, total: 1.0)
                            .tint(Color.orange)
                        
                        Text(context.state.isRunning ? "Keep going!" : "Timer Paused")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal)
                }
                
            } compactLeading: {
                HStack {
                    Image(context.attributes.eggImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
            } compactTrailing: {
                Text(timerInterval: Date()...Date().addingTimeInterval(context.state.timeRemaining), countsDown: true)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.orange)
            } minimal: {
                Image(context.attributes.eggImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }
            .widgetURL(URL(string: "crackedswift://timer"))
            .keylineTint(Color.orange)
        }
    }
}
*/
