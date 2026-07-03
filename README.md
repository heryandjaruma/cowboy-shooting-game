# 🤠 High Noon

*A fast-paced local multiplayer cowboy duel built for iOS.*

High Noon recreates the tension of a classic western quick draw using your iPhone as the revolver. Pair with another nearby player, wait through an unpredictable countdown, and draw only when the signal arrives. React too slowly and you'll lose the duel—react too early, and you might be the one paying the price.

Designed around short play sessions, High Noon aims to be something two friends can launch anywhere, and simply enjoy for a minute.

---

## Gameplay

A typical duel lasts less than a minute.

1. Connect to another nearby player.
2. Enter the lobby and ready up.
3. A synchronized countdown begins.
4. The final **"DRAW!"** call is intentionally delayed by a random amount of time.
5. Both devices vibrate simultaneously using Core Haptics.
6. Players fire using the device's volume button.
7. The fastest reaction wins the round.

The random delay prevents players from simply memorizing the countdown rhythm, creating the tense anticipation found in classic western duels.

---

## Features

* 🤝 Local multiplayer matchmaking
* ⏱️ Synchronized countdown and clock synchronization
* 📳 Haptic draw signal
* 🔫 Volume button shooting mechanic
* 🏆 Automatic winner determination

---

## Technology Stack

| Technology        | Purpose                      |
| ----------------- | ---------------------------- |
| SwiftUI           | User interface               |
| SpriteKit         | Gameplay and rendering       |
| Network Framework | Local multiplayer networking |
| Bonjour           | Nearby device discovery      |
| Core Haptics      | Draw and impact feedback     |

Networking is built on Apple's **Network Framework** (`NWListener`, `NWBrowser`, `NWConnection`, and `NWParameters`).

Rather than choosing between Wi-Fi or Bluetooth directly, the framework allows iOS to negotiate the best available local transport automatically, providing a seamless local multiplayer experience.

---

## Running the Project

### Requirements

* Xcode
* iOS device (recommended)
* Two nearby iPhones for multiplayer testing

Because the gameplay relies on local networking, haptics, and hardware input, testing on physical devices is strongly recommended.

Future releases are planned for TestFlight once the prototype reaches a stable milestone.

---

## License

This project is currently **proprietary**.

All rights reserved. The source code is provided for evaluation and educational purposes only and may not be copied, redistributed, or used without permission from the authors.
