# ceng-407-408-2025-2026-Social-Emotional-Well-being-Assistant
Social & Emotional Well-being Assistant

## Don't Forget To Create and Activate Virtual Environment
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt

npm install

## Community chatroom (Socket.IO)

### Steps to connect with `client.js`
1. **Install Node.js (LTS)**
   - Download/install from https://nodejs.org
   - Verify in PowerShell:
     - `node -v`
     - `npm -v`

2. **Get the chat client files**
   - cd Into folder with these files in it:
     - `client.js`
     - `package.json`
     - `package-lock.json`

3. **Install dependencies**
   - With PowerShell in that folder run:
     - `npm install`

4. **Run the client and connect to the Railway server**
   - Option A (pass URL as an argument):
     - `node client.js https://sewa-community-chatroom-production.up.railway.app`
   - Option B (set an environment variable):
     - `$env:SERVER_URL="https://sewa-community-chatroom-production.up.railway.app"`
     - `node client.js`

5. **Join a room and chat**
   - When prompted, enter a room name.
   - Commands:
     - `/join <room>` switch/join a room
     - `/leave` leave current room
     - `/quit` exit