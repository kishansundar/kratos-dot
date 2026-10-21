# BluetoothPanel

The Bluetooth popup from the bar's Bluetooth glyph: connected devices, paired devices, nearby devices while searching, and the adapter switch. Hidden entirely (and the bar glyph with it) when there is no adapter.

**Consumer provides:** adapter state (`Quickshell.Bluetooth` if present, else `bluetoothctl`): powered, discovering; devices with name, kind (audio / input / phone), paired, connected, battery %; connect / disconnect / pair / remove actions and pairing requests (passkey confirm).

**Layout**
1. Header — "Bluetooth" + ruler; adapter switch (circle + word) at the right.
2. **Connected** — filled circle, name, a small battery ruler (`miniMeter`, ink fill) with `mono` percent when reported, a kind glyph for audio (`headphones`). Selecting a row reveals text actions: disconnect, and for audio devices "audio output" (makes it the default sink).
3. **Paired** — ring, name, kind in `mono`. One click connects; the row shows "…" until it connects or `connectTimeout` passes (then the error glyph and "couldn't connect").
4. **Nearby** — only while searching: unpaired devices; unnamed ones as "no name" in `textFaint` after named ones. The eyebrow shows "searching …" with the remaining `scanTimeout`. Searching starts when the panel opens and stops when it closes or times out.
5. Footer — "stop searching" / "search again", and the adapter id in `mono` `textFaint`.

**Pairing** — a device asking to confirm a passkey expands its row: "Confirm this code on the device:" and the code in `display` (tabular, spaced in threes), **pair** (the one `accent`) and cancel. Passkey entry devices (keyboards) show the code to type instead.

- Battery under 20 %: an ink triangle before the percent, and "low" in the tooltip.
- Remove (unpair) is in the row's right-click menu and asks first.
