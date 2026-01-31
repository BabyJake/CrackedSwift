# TestFlight Distribution Guide

After distributing your build from Xcode, here's how to share it with testers:

## Step 1: Wait for Processing

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Sign in with your Apple Developer account
3. Select your **CrackedSwift** app
4. Click on **TestFlight** in the left sidebar
5. Your build will appear under **iOS Builds** - it may take **10-30 minutes** to process

**Status indicators:**
- ⏳ **Processing** - Build is being processed (wait)
- ✅ **Ready to Test** - Build is ready to share
- ⚠️ **Missing Compliance** - May need export compliance info

---

## Step 2: Add Testers

### Option A: Internal Testers (Up to 100 users)

**Best for:** Quick testing with your team

1. In TestFlight, go to **Internal Testing** tab
2. Click **+** to add internal testers
3. Enter their **Apple ID email addresses**
4. They must be added to your App Store Connect team first:
   - Go to **Users and Access** in App Store Connect
   - Click **+** to invite them
   - Assign them **App Manager** or **Developer** role

### Option B: External Testers (Up to 10,000 users)

**Best for:** Public beta testing

1. In TestFlight, go to **External Testing** tab
2. Click **+** to create a new group (or use existing)
3. Select your build
4. Add testers:
   - Enter **Apple ID email addresses**, OR
   - Share a **public link** (if enabled)

**Note:** External testing requires:
- App Review (first time only, takes 24-48 hours)
- Export compliance information
- Privacy policy URL (if your app collects data)

---

## Step 3: Share with Testers

### For Internal Testers:

1. Testers will receive an **email invitation** automatically
2. They need to:
   - Install **TestFlight app** from App Store (if not already installed)
   - Open the email and tap **View in TestFlight**
   - Or open TestFlight app and accept the invitation

### For External Testers:

**Method 1: Email Invitation**
- Testers receive email automatically
- They tap **View in TestFlight** in the email

**Method 2: Public Link** (if enabled)
1. In External Testing group, enable **Public Link**
2. Share the link with testers
3. They open it on their iPhone/iPad to install

---

## Step 4: Testers Install the App

Testers need to:

1. **Install TestFlight** from App Store (if not already installed)
2. **Accept the invitation** (via email or TestFlight app)
3. **Tap "Install"** next to your app in TestFlight
4. The app will install like a normal app

---

## Quick Checklist

- [ ] Build uploaded and processing in App Store Connect
- [ ] Build status shows "Ready to Test"
- [ ] Added testers (Internal or External)
- [ ] Testers have TestFlight app installed
- [ ] Testers received invitation email
- [ ] Export compliance completed (if required)

---

## Common Issues

### "Build is Processing"
- **Wait 10-30 minutes** - Apple needs to process the build
- Check back in App Store Connect

### "Missing Export Compliance"
- Go to your build in TestFlight
- Click **Provide Export Compliance Information**
- Answer the questions (usually "No" for most apps)

### "Tester Not Receiving Email"
- Check spam folder
- Verify email address is correct
- Make sure tester has TestFlight app installed
- Tester can manually check TestFlight app for pending invitations

### "External Testing Requires Review"
- First external build needs App Review (24-48 hours)
- After approval, subsequent builds are instant
- Internal testing doesn't require review

---

## Direct Links

- **App Store Connect**: https://appstoreconnect.apple.com
- **TestFlight App**: https://apps.apple.com/app/testflight/id899247664

---

## Pro Tips

1. **Internal Testing** is faster - no review needed
2. **External Testing** is better for larger groups
3. You can have **multiple groups** with different builds
4. Testers can provide **feedback** directly in TestFlight
5. You'll see **crash reports** and **usage analytics** in App Store Connect

---

## Next Steps After Distribution

1. ✅ Build uploaded (you just did this!)
2. ⏳ Wait for processing (10-30 min)
3. ➕ Add testers
4. 📧 Testers receive invitation
5. 📱 Testers install via TestFlight
6. 🧪 Start testing!
