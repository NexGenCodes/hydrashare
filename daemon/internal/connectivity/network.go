package connectivity

import (
	"runtime"
)

var (
	isMeteredOverride bool
)

// SetMetered allows the frontend to manually signal if the connection is metered
func SetMetered(metered bool) {
	isMeteredOverride = metered
}

// IsMetered returns true if the current connection is likely metered (cellular).
func IsMetered() bool {
	// For cross-platform support:
	// On Mobile: Will be signaled by Flutter bridge
	// On Desktop: We assume unmetered unless user flags it.

	// Default placeholder logic:
	if runtime.GOOS == "android" || runtime.GOOS == "ios" {
		return isMeteredOverride
	}
	return isMeteredOverride
}

// GetBandwidthSuggestion returns a recommended throttle based on network type
func GetBandwidthSuggestion() int {
	if IsMetered() {
		return 500 // 500ms throttle (slow)
	}
	return 0 // No throttle
}
