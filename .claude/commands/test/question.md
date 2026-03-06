# test/question

Test: mid-run question → reply via message-input (PTY injection com 0x0d).

Execute EXACTLY these steps. Do not use any tools at any point.

1. Say: "I need to know your preferred output format before continuing."
2. Ask: "Please choose: (A) short summary or (B) detailed breakdown?"
3. STOP ALL OUTPUT AND WAIT. Do not proceed until the user replies with any text.
4. After receiving a reply, say: "Received: [the text they sent]. Test complete."
5. Stop.

**CRITICAL:** Step 3 must result in you waiting silently. No tools, no further output, no auto-proceeding.

**Observe in app:** agente fica em `running` sem hook events → digitar no message-input → texto aparece no PTY → agente responde.
