package mesh

import (
	"fmt"
)

// HardwareSignal represents a request to the frontend to toggle hardware radios
type HardwareSignal struct {
	Type     string // WIFI_DIRECT, BLUETOOTH, USB_RNDIS
	Enabled  bool
	SSID     string // For WiFi Direct
	Password string // For WiFi Direct
	PIN      string // For Bluetooth
}

// PrepareWiFiDirect prepares a signaling payload for the Flutter frontend
func (o *Orchestrator) PrepareWiFiDirect(ssid, password string) {
	fmt.Printf("📡 Signaling Frontend: Enable WiFi Direct (SSID: %s)\n", ssid)
	if o.Emitter != nil {
		o.Emitter.Emit(HardwareSignal{
			Type:     "WIFI_DIRECT",
			Enabled:  true,
			SSID:     ssid,
			Password: password,
		})
	}
}

// PrepareBluetoothPairing signals the frontend to enter BT pairing mode
func (o *Orchestrator) PrepareBluetoothPairing(pin string) {
	fmt.Printf("📡 Signaling Frontend: Start Bluetooth Pairing (PIN: %s)\n", pin)
	if o.Emitter != nil {
		o.Emitter.Emit(HardwareSignal{
			Type:    "BLUETOOTH",
			Enabled: true,
			PIN:     pin,
		})
	}
}

// PrepareUSBRNDIS signals the frontend to enable USB Tethering/RNDIS
func (o *Orchestrator) PrepareUSBRNDIS() {
	fmt.Println("📡 Signaling Frontend: Enable USB RNDIS/Tethering")
	if o.Emitter != nil {
		o.Emitter.Emit(HardwareSignal{
			Type:    "USB_RNDIS",
			Enabled: true,
		})
	}
}
