# Euro-Office Ecosystem Architecture & Data Flow

This document details the service architecture and data lifecycle within the Euro-Office development environment. It is designed to guide new developers in understanding how backend, storage, and frontend services interact.

## 1. Service Topology (Docker Compose)

The local development environment deploys an infrastructure composed of three main layers that interact through an internal virtual network:

| Docker Service | Core Technology | Primary Responsibility | External Access |
| :--- | :--- | :--- | :--- |
| `nextcloud` | PHP / Apache / SQLite | Storage provider (WebDAV/WOPI Host) and user authentication. | `http://localhost:8081` |
| `eo` (DocumentServer) | Node.js / C++ / Nginx | Modular editing server. Processes, converts, and distributes documents. | `http://localhost:8080` |
| `onlyoffice` (Optional) | Docker Image Stable | Reference instance used for comparative regression testing. | `http://localhost:8082` |

---

## 2. Global Data Flow (Lifecycle of an Editing Session)

The exchange of information between the file storage (Nextcloud) and the web editor (DocumentServer) is performed asynchronously using a token and callback scheme:

```
[ Nextcloud UI ] --(1. Generates JWT)--> [ User Browser ]
         ^                                         |
         | (4. HTTP POST Callback)                 | (2. Loads Scripts)
         |                                         v
[ Storage Server ] <====(3. Downloads File)====> [ DocumentServer (eo) ]
```

### Step 1: Initialization and JWT Security
When a user opens a document (`.docx`, `.xlsx`, `.pptx`) in the Nextcloud interface:
1. The Nextcloud connector intercepts the request and generates a secure **JWT (JSON Web Token)** signed with a shared secret key (`EO_JWT_SECRET`).
2. This token contains user permissions (read/write), file metadata, and the return `CallbackUrl`.
3. Nextcloud renders an `iframe` pointing to the `eo` server (`http://localhost:8080/apps/documenteditor/...`), passing the JWT as an authentication parameter.

### Step 2: Structure and Interface Loading
1. The user's browser requests static assets for the editor from the `eo` service.
2. The internal Nginx web server inside the container serves the user interface modules (`web-apps`) and the logical execution engine (`sdkjs`).

### Step 3: Real-Time Co-editing Session
1. The DocumentServer backend uses the JWT token to securely download the original binary file from the Nextcloud server.
2. The internal conversion service deconstructs the file in memory into an ordered sequence of structural changes (*changesets*).
3. If multiple users edit the same document, modifications are transmitted bi-directionally via **WebSockets (Socket.io)** through the `server/docservice` service. Edits are temporarily saved in an internal Redis database to guarantee real-time collaborative editing without disk latency.

### Step 4: Session Closure and Persistence (Saving)
1. When the last user closes the editor tab, DocumentServer triggers a 10-second grace timer.
2. The `server/converter` service takes the original file and applies the sum of all accumulated *changesets* from the session, packaging it back into its native binary format (e.g., Open XML).
3. DocumentServer makes an asynchronous HTTP POST request sending the new binary file to the `CallbackUrl` provided by Nextcloud in Step 1.
4. Nextcloud receives the payload, validates its origin, and updates the file in its storage, registering a new file version.

---

## 3. Developer Intervention Guide

To modify the system behavior, locate the appropriate repository based on the nature of your task:
* If you need to change saving logic, persistence, or user connection rooms, you must work in the **`server`** repository.
* If you need to alter the document's response to logical commands or create text formatting functions, you must work in the **`sdkjs`** repository.
* If you need to add visual elements, tabs, or buttons to the toolbar, you must work in the **`web-apps`** repository.