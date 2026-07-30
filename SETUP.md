# Getting Remli onto your iPhone

There is no Mac in this loop. GitHub's macOS servers build and sign the app, then hand it
to Apple, and it appears in TestFlight on your phone. You never touch Xcode.

There are four things only you can do, because they need your Apple and GitHub accounts.
Everything else is automated. Work through them in order — **step 1 takes the longest to
be approved, so start it first and do the rest while you wait.**

---

## 1. Enrol in the Apple Developer Program — $99/year

1. Go to <https://developer.apple.com/programs/enroll/>
2. Sign in with your Apple ID. Use the **same Apple ID that's on your iPhone**.
3. Enrol as an **Individual** (not Organization — Organization needs a D-U-N-S number and
   takes weeks).
4. Pay the $99.

> Apple verifies individual enrolments manually. It's usually a few hours but can take
> 24–48. You'll get an email. Nothing else here works until it's approved.

Once approved, find your **Team ID**: <https://developer.apple.com/account> → scroll to
**Membership details** → copy the 10-character **Team ID** (looks like `A1B2C3D4E5`).

---

## 2. Make the repository public

This is purely about build minutes. Private repos only get about 200 free macOS build
minutes a month; public repos get them free. Your ideas and data never live in this repo —
only the app's source code — so there's nothing sensitive in it.

1. Go to <https://github.com/chrisallenclark/Cued/settings>
2. Scroll to the very bottom, **Danger Zone** → **Change repository visibility**
3. Choose **Make public**, confirm.

While you're in Settings, you can also rename the repo to **Remli** if you like
(**Settings → General → Repository name**). GitHub redirects the old address automatically,
so nothing breaks.

---

## 3. Create an App Store Connect API key

This is what lets the build server sign the app and upload it without a Mac.

1. Go to <https://appstoreconnect.apple.com/access/integrations/api>
2. Click the **+** next to *Active* (Team Keys tab).
3. Name it `GitHub Actions`.
4. **Access role: `App Manager`.**

   > ⚠️ This one matters. A key with the `Developer` role logs in fine and then fails the
   > upload with a useless "unauthorized" error. It must be **App Manager**.

5. Click **Generate**, then **Download** the `.p8` file.

   > Apple lets you download it **once**. Save it somewhere safe.

6. From that same page note two values:
   - **Key ID** — next to the key you just made
   - **Issuer ID** — at the top of the page

---

## 4. Add four secrets to GitHub

Go to
<https://github.com/chrisallenclark/Cued/settings/secrets/actions>
and click **New repository secret** four times:

| Secret name | What to paste |
|---|---|
| `TEAM_ID` | The 10-character Team ID from step 1 |
| `ASC_KEY_ID` | The Key ID from step 3 |
| `ASC_ISSUER_ID` | The Issuer ID from step 3 |
| `ASC_KEY_P8` | The **entire contents** of the `.p8` file |

For `ASC_KEY_P8`: open the `.p8` in any text editor and copy **everything**, including the
`-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines. Paste the whole thing.
Multi-line is fine. Don't base64 it, don't strip the header lines.

---

## 5. Create the app record in App Store Connect

1. Go to <https://appstoreconnect.apple.com/apps> → **+** → **New App**
2. Fill in:
   - **Platform:** iOS
   - **Name:** `Remli` (if taken, try `Remli - Idea Capture`)
   - **Primary language:** English (U.S.)
   - **Bundle ID:** select `com.chrisallenclark.remli`

     > If it's not in the dropdown, register it first at
     > <https://developer.apple.com/account/resources/identifiers/list> → **+** →
     > **App IDs** → **App** → Description `Remli`, Bundle ID **Explicit**
     > `com.chrisallenclark.remli`.
   - **SKU:** `remli-001`
3. Create.

---

## 6. Install TestFlight on your iPhone

Get it from the App Store: <https://apps.apple.com/app/testflight/id899247664>

Sign in with the same Apple ID. Builds will show up here automatically.

---

## Then tell me, and I'll ship a build

Once steps 1–6 are done, say so and I'll trigger the release. You can also do it yourself:

**Actions** tab → **Release to TestFlight** → **Run workflow**.

The first build takes 10–15 minutes, plus another 5–15 while Apple processes it. Then it
appears in TestFlight and you tap Install.

---

## What each of these is actually for

- **Developer Program** — Apple won't let unsigned code run on a real iPhone. The $99 also
  buys a year-long app lifetime; the free tier expires apps every 7 days.
- **Public repo** — free macOS build minutes.
- **API key** — replaces the certificate wrangling a Mac would normally do.
- **App record** — gives the upload somewhere to land.
- **TestFlight** — the delivery mechanism. It's also how real App Store betas work, so
  nothing here is a hack.

Nothing in this setup sends your ideas anywhere. The app's intelligence runs on-device, and
your ideas sync only through your own iCloud account.
